"""
findfreeport(port::Int64) -> String

Creates the proxy page attaching to the given WebSocket port (Julia side).
This page allows communication between Julia and the Chrome DevTools interface.
"""
function createPage(port::Int)
  tmppath = tempname() * ".html"

  open(tmppath, "w") do io
    Mustache.render(io, String(read(joinpath(@__DIR__, "wsproxy.html"))), port=port)
  end

  tmppath
end



"""
findfreeport([port_hint::Int64]) -> Int64

Finds the first available port on localhost.
"""
function findfreeport(porthint::Int64=5000)
    xport, sock = listenany(porthint)
    close(sock)
    Int(xport)
end
