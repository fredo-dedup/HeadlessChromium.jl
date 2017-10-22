###############################################################################
using HttpServer, WebSockets
import HTTP
using Mustache

import Base: send, close

###############################################################################

function createPage(port::Int)
  tmppath = tempname() * ".html"

  open(tmppath, "w") do io
    render(io, String(read(joinpath(@__DIR__, "wsproxy.html"))), port=port)
  end

  tmppath
end

# find an available port
function findfreeport(porthint::Int64=5000)
    xport, sock = listenany(porthint)
    close(sock)
    Int(xport)
end
# findfreeport(5000)


methodswith(WebSockets.WebSocket)
methodswith(Channel)

function launchServer(outchan::Channel, inchan::Channel, port::Int)
  wsh = WebSocketHandler() do req,client

    @async begin  # listening loop
      while isopen(client) && isopen(inchan)
          msg = try
                    String(read(client))
                catch e
                    "error"
                end

          put!(inchan, msg)
      end
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

    println("exiting send loop for port $port")
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

################################################################################

struct Chromium
  server::HttpServer.Server
  cprocess::Base.Process
  outchan::Channel{String} # Channel for outgoing messages
  inchan::Channel  # Channel for received messages
  chromiumport::Int64
  juliaport::Int64
  pending::Dict{Int64, Channel}
  uri::String
end

chpath = joinpath(@__DIR__,"../deps/downloads/chromium/chrome-linux/chrome")

function OpenChromium()

  # launch julia websocket server
  jport   = findfreeport()
  inchan  = Channel(100) # Channel for inbound messages
  outchan = Channel{String}(100) # Channel for outbound messages
  server  = launchServer(outchan, inchan, jport) # launch ws server

  # launch chromium
  intpath = createPage(jport)
  # run(`cmd /c start $intpath`)
  run(`xdg-open $intpath`)

  cport = findfreeport(9000)
  # chpath = joinpath("c:/homeware/Chromium/chrome-win32", "chrome.exe")
  opt1, opt2, opt3 = "--headless", "--disable-gpu", "--remote-debugging-port=$cport"
  # chproc = spawn(`$chpath $opt1 $opt2 $opt3 "file://$intpath"`)
  chproc = spawn(`$chromium $opt1 $opt2 $opt3 "http://www.yahoo.fr"`)

  # connect intermediary to chrome devtools interface
  resp = retry(HTTP.get, delays=[1,2,5,10])("http://localhost:$cport/json")
  tdemp = JSON.parse(String(resp.body.buffer))
  pdict = findfirst(d -> haskey(d,"type") && d["type"]=="page", tdemp)
  pdict == 0 && error("beuh..")
  wsuri = tdemp[pdict]["webSocketDebuggerUrl"]
  id = tdemp[pdict]["id"]

  put!(outchan, JSON.json(Dict(:command => "connect", :uri => wsuri)))

  # async loop listening to received messages and dispatching them
  pending = Dict{Int64, Channel}()

  @async begin
    for m in inchan
      msg = JSON.parse(m)
      println("received $msg")
      if haskey(msg, "id") && haskey(pending, msg["id"])
        put!(pending[msg["id"]], msg)
      else
        warn("undispatchable msg : $msg")
      end
    end
    println("closing listen loop")
  end

  Chromium(server, chproc, outchan, inchan,
           cport, jport, pending, wsuri)
end

function close(chro::Chromium)
  kill(chro.cprocess)
  close(chro.outchan)
  close(chro.inchan)
  close(chro.server)
  foreach(close, values(chro.pending))
end

################################################

struct Session
  chromium::Chromium
  uri::String
end

# sess = Session(mychro, mychro.uri)
# args = [(:method, "Browser.getVersion")]

function send(sess::Session, method::String ; args...)
  command_id = length(sess.chromium.pending) == 0 ? 1 :
                  maximum(keys(sess.chromium.pending)) + 1
  reception_channel = Channel(10)
  sess.chromium.pending[command_id] = reception_channel

  msg = Dict{Any,Any}( t[1] => t[2] for t in args )
  wrappermsg = Dict("command" => "send",
                    "session" => sess.uri,
                    "payload" => Dict(:id => command_id,
                                      :method => method,
                                      :params => msg))
  put!(sess.chromium.outchan, JSON.json(wrappermsg))
  reception_channel
end

send(chro::Chromium, method::String ; args...) =
    send(Session(chro, chro.uri), method ; args...)


################################################################################

mychro = OpenChromium()
# mychro2 = OpenChromium()
# close(mychro2)
# findfreeport()

close(mychro)

respch = send(mychro, "Browser.getVersion")
isready(respch)
take!(respch)


respch = send(mychro, method = "Target.setDiscoverTargets",
              params= Dict(:discover => true))
retry(ch -> (println("+") ; isready(ch) ? nothing : error("no response")), delays=[0.,1.,1.,1.])(respch)

isready(respch)
take!(respch)



respch = send(mychro, method = "Target.createTarget",
              params= Dict(:url => "file:///c:/temp/VegaLite plot.html"))
isready(respch)
take!(respch)




targetId = "024cef6d-588d-4594-8e95-89b69569c0c4"

url = "file:///c:/temp/VegaLite plot.html"
chro = mychro

function openSession(chro::Chromium, url::String)
  respch = send(chro, method = "Target.createTarget",
                      params = Dict(:url => url))

  retry(ch -> isready(ch) ? nothing : error("no response"),
        delays=[0.,1.,1.,1.])(respch)

  targetId = take!(respch)["result"]["targetId"]
  targetws = "ws://localhost:$(chro.chromiumport)/devtools/page/$targetId"
  put!(chro.outchan, JSON.json(Dict(:command => "connect", :uri => targetws)))

  Session(chro, targetws)
end

sess = openSession(mychro, "file:///c:/temp/VegaLite plot.html")


resp = send(sess, method="Page.printToPDF",
     params=Dict(:path => "c:/temp/essai.pdf", :format => "A4"))
isready(resp)
take!(resp)
