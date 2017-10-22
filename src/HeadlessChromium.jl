module HeadlessChromium


depsjl = joinpath(dirname(@__FILE__), "..", "deps", "deps.jl")

isfile(depsjl) ? include(depsjl) : error("HeadlessChromium not properly ",
    "installed. Please run\nPkg.build(\"HeadlessChromium\")")

# package code goes here

end # module
