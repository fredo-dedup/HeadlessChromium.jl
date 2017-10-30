using HeadlessChromium
using Base.Test

# open dummy target ('about:'' page)

tg1 = Target("about:")
sleep(5)
resp = send(tg1, "Browser.getVersion")

@test haskey(resp, "result")
@test haskey(resp["result"], "protocolVersion")
@test resp["result"]["protocolVersion"] == "1.2"

close(tg1)

# open file target

src = joinpath(dirname(@__FILE__), "example.html")
tg2 = Target("file://$src")
sleep(5)

plotfile = tempname()
send(tg2, "Page.printToPDF", format="A4") do resp
    open(plotfile, "w") do io
        write(io, base64decode(resp["result"]["data"]))
    end
end
sleep(5)  # give some time for isfile() to update

@test isfile(plotfile)
@test stat(plotfile).size > 5000

# navigate to another URL

resp = send(tg2, "Page.navigate", url="https://www.yahoo.com")
sleep(5)
@test haskey(resp, "result")

resp = send(tg2, "DOM.getDocument")
@test haskey(resp, "result")
@test haskey(resp["result"], "root")
@test haskey(resp["result"]["root"], "baseURL")

close(tg2)
