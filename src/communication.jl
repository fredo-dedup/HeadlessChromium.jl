
"""
launchServer(outchan::Channel, inchan::Channel, port::Int)

Starts the WebSocket server that will send and receive messages from the
proxy page.
"""
function launchServer(outchan::Channel, inchan::Channel, port::Int)
  wsh = WebSocketHandler() do req,client

    @async begin  # listening loop
      while isopen(client) && isopen(inchan)
        try
          msg = String(read(client))
          put!(inchan, msg)
        catch e
          warn("error in reception loop : $e")
        end
      end
      println("exiting reception loop (port $port)")
    end

    # outgoing message loop
    println("starting outgoing loop")
    for m in outchan
      println("sending $m")
      try
        write(client, m)
      catch e
      end
    end

    println("exiting server outgoing loop (port $port)")
  end

  handler = HttpHandler() do req, res
    rsp = Response(100)
    rsp.headers["Access-Control-Allow-Origin"] = "http://localhost:8080"
    rsp.headers["Access-Control-Allow-Credentials"] = "true"
    rsp
  end

  server = Server(handler, wsh)
  @async run(server, port)
  server
end



struct Target
  socketURI::URIParser.URI
end

struct Chromium
  server::HttpServer.Server  #
  cprocess::Base.Process     # Headless Chromium process
  outchan::Channel{String}   # Channel for outgoing messages
  inchan::Channel            # Channel for received messages
  chromiumport::Int64        # Chromium websocket port
  juliaport::Int64           # Julia websocket port
  pending::Dict{Int64, Union{Void,Function}} # callbacks
  mainTarget::Target         # websocket url of the main chromium page
end


"""
Chromium(outchan::Channel, inchan::Channel, port::Int)

Starts or restarts the chromium process and connects the websockets.
"""
function Chromium()
  # launch julia websocket server
  jport   = findfreeport()
  inchan  = Channel(100) # Channel for inbound messages
  outchan = Channel{String}(100) # Channel for outbound messages
  server  = launchServer(outchan, inchan, jport) # launch ws server

  # launch chromium
  intpath = createPage(jport)
  # run(`cmd /c start $intpath`) ; run(`xdg-open $intpath`)

  chproc = nothing

  newchromium =
    try
      cport = findfreeport(9225)
      opt1, opt2, opt3 = "--headless", "--disable-gpu", "--remote-debugging-port=$cport"
      chproc = spawn(`$chromium $opt1 $opt2 $opt3 "file://$intpath"`)

      # connect intermediary to chrome devtools interface
      resp = retry(HTTP.get, delays=[1,2,5,10])("http://localhost:$cport/json")
      tdemp = JSON.parse(String(resp.body.buffer))
      pdict = findfirst(d -> haskey(d,"type") && d["type"]=="page", tdemp)
      pdict == 0 && error("beuh..")
      wsuri = tdemp[pdict]["webSocketDebuggerUrl"]

      put!(outchan, JSON.json(Dict(:command => "connect", :uri => wsuri)))

      Chromium(server, chproc, outchan, inchan,
               cport, jport,
               Dict{Int64, Function}(),
               Target(URIParser.URI(wsuri)) )
    catch e
      isopen(inchan) && close(inchan)
      isopen(outchan) && close(outchan)
      process_running(chproc) && kill(chproc)
      error("could not establish connection to chromium, $e")
    end

  # async loop listening to received messages and dispatching them
  @async begin
    for m in inchan
      msg = JSON.parse(m)
      println("received $msg")
      if haskey(msg, "id")
        if haskey(newchromium.pending, msg["id"])
          cbk = newchromium.pending[msg["id"]] # resp callback
          isa(cbk, Void) || cbk(msg)
          delete!(newchromium.pending, msg["id"])
        else
          warn("undispatchable msg : $msg")
        end
      else
        info("event : $msg")
      end
    end
    println("closing listen loop")
  end

  newchromium
end

# function close(chro::Chromium)
#   kill(chro.cprocess)
#   close(chro.outchan)
#   close(chro.inchan)
#   close(chro.server)
#   foreach(close, values(chro.pending))
# end



"""
Target(url::String)

Opens a new Chromium 'target', i.e. the page at the given url.
"""
function Target(url::String)
  if isa(chromiumHandle, Void)
    global chromiumHandle = Chromium()
  end

  gotresp = Condition()
  send(chromiumHandle, "Target.createTarget", url=url) do resp
    targetId = resp["result"]["targetId"]
    targetws = "ws://localhost:$(chromiumHandle.chromiumport)/devtools/page/$targetId"

    put!(chromiumHandle.outchan,
         JSON.json(Dict(:command => "connect", :uri => targetws)))
    notify(gotresp, targetws)
  end

  Target(URIParser.URI(wait(gotresp)))
end

suri = URIParser.URI("ws://localhost:9225/devtools/page/qg546gf")
@sprintf("%s", suri)

function send(callback::Union{Function,Void},
              tgt::Target, method::String ; args...)
  command_id = length(chromiumHandle.pending) == 0 ? 1 :
                  maximum(keys(chromiumHandle.pending)) + 1

  stringuri = @sprintf("%s", tgt.socketURI)
  msg = Dict{Any,Any}( t[1] => t[2] for t in args )
  wrappermsg = Dict("command" => "send",
                    "session" => stringuri,
                    "payload" => Dict(:id => command_id,
                                      :method => method,
                                      :params => msg))

  chromiumHandle.pending[command_id] = callback

  put!(chromiumHandle.outchan, JSON.json(wrappermsg))
  nothing
end


# chromium version
send(callback::Union{Function,Void},
     ch::Chromium, method::String ; args...) =
  send(callback, ch.mainTarget, method ; args...)

# no callback version
send(tgt::Union{Target, Chromium}, method::String ; args...) =
    send(nothing, tgt, method ; args...)
