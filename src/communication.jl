
abstract type AbstractTarget end

struct Target <: AbstractTarget
  chromiumWebSocket::URIParser.URI    # websocket server for the target
end

struct Chromium <: AbstractTarget
  chromiumWebSocket::URIParser.URI    # websocket server for the target
  # eventCallback::Union{Function,Void} # callback function for events
  server::HttpServer.Server  # julia websocket server
  cprocess::Base.Process     # Headless Chromium process
  outchan::Channel{String}   # Channel for outgoing messages
  inchan::Channel            # Channel for received messages
  chromiumport::Int64        # Chromium websocket port
  juliaport::Int64           # Julia websocket port
  id2callbacks::Dict         # command callbacks (by command id)
  ws2callbacks::Dict         # event callbacks (by ws uri)
end


"""
Chromium(outchan::Channel, inchan::Channel, port::Int)

Starts the chromium process and connects the websockets.
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

      Chromium(URIParser.URI(wsuri), # nothing,
               server, chproc, outchan, inchan,
               cport, jport,
               Dict(), Dict())
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
      info("received $msg")
      if haskey(msg, "id") # response to a command
        if haskey(newchromium.id2callbacks, msg["id"])
          cb = newchromium.id2callbacks[msg["id"]] # resp callback
          isa(cb, Function) && try Base.invokelatest(cb, msg) end
          delete!(newchromium.id2callbacks, msg["id"])
        else
          warn("undispatchable command result : $msg")
        end

      elseif haskey(msg, "method") # likely an event, forward to the event callback
        srcws = URIParser.URI(msg["origin"])
        if haskey(newchromium.ws2callbacks, srcws)
          ecb = newchromium.ws2callbacks[srcws]
          isa(ecb, Function) && try Base.invokelatest(ecb, msg) end
        else
          warn("undispatchable event : $msg")
        end

      else
        warn("received msg is neither a command result nor an event : $msg")
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
#   foreach(close, values(chro.id2callbacks))
# end


"""
Target(url::String)

Opens a new Chromium 'target', i.e. the page at the given url.
"""
function Target(url::String, eventCallback::Union{Void,Function}=nothing)
  if isa(chromiumHandle, Void)
    global chromiumHandle = Chromium()
    sleep(3)
  end

  resp = send(chromiumHandle, "Target.createTarget", url=url)
  targetId = resp["result"]["targetId"]
  targetws = "ws://localhost:$(chromiumHandle.chromiumport)/devtools/page/$targetId"

  put!(chromiumHandle.outchan, JSON.json(Dict(:command => "connect", :uri => targetws)))

  # register callback for events
  wsuri = URIParser.URI(targetws)
  chromiumHandle.ws2callbacks[wsuri] = eventCallback

  Target(wsuri)
end


"""
close(tgt::Target)

Closes the target, and frees up associated ressources.
"""
function close(tgt::Target)
  kill(chro.cprocess)
  close(chro.outchan)
  close(chro.inchan)
  close(chro.server)
  foreach(close, values(chro.pending))
end
