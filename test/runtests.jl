using HeadlessChromium
using Base.Test

# open dummy target ('about:'' page)

tg1 = Target("about:")
resp = send(HeadlessChromium.chromiumHandle, "Browser.getVersion")
# resp = send(tg1, "Browser.getVersion")

@test haskey(resp, "result")
@test haskey(resp["result"], "protocolVersion")
@test resp["result"]["protocolVersion"] == "1.2"

# open file target

src = joinpath(dirname(@__FILE__), "example.html")
tg2 = Target("file://$src")

plotfile = tempname()
send(tg2, "Page.printToPDF", format="A4") do resp
    open(plotfile, "w") do io
        write(io, base64decode(resp["result"]["data"]))
    end
end

@test isfile(plotfile)
@test stat(plotfile).size > 5000

# navigate to another URL

resp = send(tg2, "Page.navigate", url="https://www.yahoo.com")
@test haskey(resp, "result")

resp = send(tg2, "DOM.getDocument")
@test haskey(resp, "result")
@test haskey(resp["result"], "root")
@test haskey(resp["result"]["root"], "baseURL")
@test resp["result"]["root"]["baseURL"] == "https://www.yahoo.com/"

close(tg2)
