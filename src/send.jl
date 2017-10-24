"""
send(callback::Union{Function,Void}, tgt::Target, method::String ; args...)

Asynchronous version of `send`, returns immediatly. When Chromium responds,
the `callback` function is called with the response as parameter.
"""
function send(callback::Union{Function,Void},
              tgt::AbstractTarget, method::String ; args...)
  command_id = length(chromiumHandle.id2callbacks) == 0 ? 1 :
                  maximum(keys(chromiumHandle.id2callbacks)) + 1

  stringuri = @sprintf("%s", tgt.chromiumWebSocket)
  msg = Dict{Any,Any}( t[1] => t[2] for t in args )
  wrappermsg = Dict("command" => "send",
                    "session" => stringuri,
                    "payload" => Dict(:id => command_id,
                                      :method => method,
                                      :params => msg))

  chromiumHandle.id2callbacks[command_id] = callback

  put!(chromiumHandle.outchan, JSON.json(wrappermsg))
  nothing
end



type TimeoutError <: Exception end

"""
send(tgt::Target, method::String ; args...)

Synchronous version of `send`, returns only when Chromium responds. The keyword
argument `timeout` (default 5 sec) controls how much time we should wait for
Chromium to respond before raising a TimeoutError.
"""
function send(tgt::AbstractTarget, method::String ; timeout=5, args...)
  endcond = Condition()

  Timer(t -> notify(endcond, TimeoutError()), timeout)

  send(tgt, method; args...) do resp
    ret = if haskey(resp, "error")
            ErrorException(resp["error"]["message"])
          else
            resp
          end
    notify(endcond, ret)
  end

  ret = wait(endcond)
  isa(ret, Exception) && throw(ret)
  ret
end
