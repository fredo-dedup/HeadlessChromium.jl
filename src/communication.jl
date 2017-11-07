
abstract type AbstractTarget end

struct Target <: AbstractTarget
  chromiumWebSocket::URIParser.URI    # websocket server for the target
  targetId::String                    # target id in chromium
end

struct Chromium <: AbstractTarget
  chromiumWebSocket::URIParser.URI    # websocket server for the target
  targetId::String                    # target id in chromium
  server::HttpServer.Server  # julia websocket server
  cprocess::Base.Process     # Headless Chromium process
  outchan::Channel{String}   # Channel for outgoing messages
  inchan::Channel            # Channel for received messages
  chromiumport::Int        # Chromium websocket port
  juliaport::Int           # Julia websocket port
  id2callbacks::Dict         # command callbacks (by command id)
  ws2callbacks::Dict         # event callbacks (by ws uri)
end


"""
    `dispatcher()`

Dispatches messages received from Chromium.
"""
function dispatcher()
  for m in chromiumHandle.inchan
    msg = JSON.parse(m)
    DEBUG && info("received $msg")

    # Command result
    if haskey(msg, "id")
      if haskey(chromiumHandle.id2callbacks, msg["id"])
        cb = chromiumHandle.id2callbacks[msg["id"]] # resp callback
        isa(cb, Function) && try Base.invokelatest(cb, msg) end
        delete!(chromiumHandle.id2callbacks, msg["id"])
      else
        warn("undispatchable command result : $msg")
      end

    # Event
    elseif haskey(msg, "method") # likely an event, forward to the event callback
      if ismatch(r"/([^/]*)$", msg["origin"])
        targetId = match(r"/([^/]*)$", msg["origin"]).captures[1]
        if haskey(chromiumHandle.ws2callbacks, targetId)
          ecb = chromiumHandle.ws2callbacks[targetId]
          isa(ecb, Function) && try Base.invokelatest(ecb, msg) end
        else
          warn("undispatchable event : $msg")
        end
      else
        warn("undispatchable event : $msg")
      end

    else
      warn("received msg that is neither a command result nor an event : $msg")
    end
  end
  println("exiting listening loop")
end


"""
    `startChromium(outchan::Channel, inchan::Channel, port::Int)`

Starts the chromium process and connects the websockets.
"""
function startChromium()
  # launch julia websocket server
  jport   = findfreeport()
  inchan  = Channel(100) # Channel for inbound messages
  outchan = Channel{String}(100) # Channel for outbound messages
  server  = launchServer(outchan, inchan, jport) # launch ws server

  # launch chromium
  intpath = createPage(jport)

  chproc = nothing

  global chromiumHandle =
    try
      cport = findfreeport(9225)
      opt1, opt2, opt3 = "--headless", "--disable-gpu", "--remote-debugging-port=$cport"
      chproc = spawn(`$chromium $opt1 $opt2 $opt3 "file://$intpath"`)

      # connect ws proxy page to chrome devtools interface
      resp = retry(HTTP.get, delays=[1,2,5,10])("http://localhost:$cport/json")
      tdemp = JSON.parse(String(resp.body.buffer))
      pdict = findfirst(d -> haskey(d,"type") && d["type"]=="page", tdemp)
      pdict == 0 && error("")
      wsuri = tdemp[pdict]["webSocketDebuggerUrl"]

      put!(outchan, JSON.json(Dict(:command => "connect", :uri => wsuri)))

      Chromium(URIParser.URI(wsuri), tdemp[pdict]["id"],
               server, chproc, outchan, inchan,
               cport, jport,
               Dict(), Dict())

    catch e
      isopen(inchan) && close(inchan)
      isopen(outchan) && close(outchan)
      (chproc!=nothing) && process_running(chproc) && kill(chproc)
      error("could not establish connection to chromium, $e")
    end

  # async loop listening to received messages and dispatching them
  @async dispatcher()

  chromiumHandle
end


"""
    `stopChromium()`

Stops the chromium process & the Julia websocket server, closes the channels.
"""
function stopChromium()
  kill(chromiumHandle.cprocess)
  close(chromiumHandle.outchan)
  close(chromiumHandle.inchan)
  close(chromiumHandle.server)
  global chromiumHandle = nothing
end


"""
    `Target(url::String) -> Target`

Opens a new Chromium 'target', i.e. the page at the given url.
"""
function Target(url::String, eventCallback::Union{Void,Function}=nothing)
  if isa(chromiumHandle, Void)
    startChromium()
    sleep(3) # FIXME : do better than a timed delay
  end

  resp = send(chromiumHandle, "Target.createTarget", url=url)
  targetId = resp["result"]["targetId"]
  targetws = "ws://localhost:$(chromiumHandle.chromiumport)/devtools/page/$targetId"

  put!(chromiumHandle.outchan, JSON.json(Dict(:command => "connect", :uri => targetws)))

  # register callback for events
  chromiumHandle.ws2callbacks[targetId] = eventCallback

  nt = Target(URIParser.URI(targetws), targetId)
  # finalizer(nt, close) # close page, remove event callback # mutable objects only
  nt
end


"""
    `close(tgt::Target)`

Closes the target, and frees up associated ressources.
"""
function close(tgt::Target)
  send(chromiumHandle, "Target.closeTarget", targetId=tgt.targetId)
  delete!(chromiumHandle.ws2callbacks, tgt.chromiumWebSocket)
end
