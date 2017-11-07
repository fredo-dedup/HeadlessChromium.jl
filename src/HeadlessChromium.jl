module HeadlessChromium

using HttpServer, WebSockets
import HTTP, URIParser, Mustache, JSON

import Base: send, close

export Target, TimeoutError, send, close, stopChromium

global const DEBUG = false

### Set the const pointing to the Chromium executable

depsjl = joinpath(dirname(@__FILE__), "..", "deps", "deps.jl")

isfile(depsjl) || error("""HeadlessChromium not properly installed.
Please run
   Pkg.build(\"HeadlessChromium\")""")

include(depsjl)


### Includes + global var 'chromiumHandle' definition

global chromiumHandle = nothing

include("communication.jl")
include("send.jl")
include("misc.jl")


end # module
