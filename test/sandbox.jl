
using HeadlessChromium

# HeadlessChromium.chromiumHandle
# HeadlessChromium.chromiumHandle.inchan
# isopen(HeadlessChromium.chromiumHandle.inchan)

event(resp) = info(resp, prefix="event : ")

@time tg2 = Target("file://C:/temp/VegaLite plot.html", event)

# send(HeadlessChromium.chromiumHandle, "Browser.getVersion")

send(tg2, "Page.enable")

send(tg2, "Page.printToPDF", format="A4") do resp
    open("c:/temp/sandbox2.pdf", "w") do io
        write(io, base64decode(resp["result"]["data"]))
    end
end

send(tg2, "Page.captureScreenshot", format="png") do resp
    open("c:/temp/sandbox4.png", "w") do io
        write(io, base64decode(resp["result"]["data"]))
    end
end

send(tg2, "DOM.enable")


send(tg2, "DOM.getDocument")

resp = send(tg2, "DOM.performSearch", query=".marks")
resp["result"]["resultCount"] == 0 && error("plot not found")
resp["result"]["resultCount"] > 1 && error("plot not located")
sid = resp["result"]["searchId"]

resp = send(tg2, "DOM.getSearchResults", searchId=sid, fromIndex=0, toIndex=1)
length(resp["result"]["nodeIds"]) != 1 && error("inconsistent number of plot node Ids")
pid = resp["result"]["nodeIds"][1]
(pid == 0) && error("node not found")

resp = send(tg2, "DOM.getBoxModel", nodeId=pid)
quad = resp["result"]["model"]["content"]
vp = Dict(:x => quad[1], :y => quad[2],
          :width  => quad[3] - quad[1] + 1,
          :height => quad[6] - quad[2] + 1,
          :scale => 1.0)

send(tg2, "Page.captureScreenshot", format="png", clip=vp) do resp
    open("c:/temp/sandbox5.box.png", "w") do io
        write(io, base64decode(resp["result"]["data"]))
    end
end


###################################################################

send(tg2, "DOM.getOuterHTML", nodeId=10)


send(tg2, "DOM.getBoxModel", nodeId=15)


send(tg2, "DOM.querySelector", nodeId=37, selector=".marks")

tg = tg2

send(tg2, "Schema.getDomains")
send(tg2, "DOM.getDocument") do resp
    rootId = resp["result"]["root"]["nodeId"])
    send(tg2, "DOM.querySelector", nodeId=rootId, selector=".marks") do resp
        println()
    end
end

ans = ""
send(tg2, "DOM.getDocument") do resp
    global ans = resp["result"]
end



doc = Dict{String,Any}(Pair{String,Any}("id", 1),Pair{String,Any}("result", Dict{String,Any}(Pair{String,Any}("root", Dict{String,Any}(Pair{String,Any}("localName", ""),Pair{String,Any}("backendNodeId", 2),Pair{String,Any}("childNodeCount", 1),Pair{String,Any}("children", Any[Dict{String,Any}(Pair{String,Any}("parentId", 14),Pair{String,Any}("localName", "html"),Pair{String,Any}("backendNodeId", 4),Pair{String,Any}("childNodeCount", 2),Pair{String,Any}("children", Any[Dict{String,Any}(Pair{String,Any}("parentId", 15),Pair{String,Any}("nodeId", 16),Pair{String,Any}("nodeName", "HEAD"),Pair{String,Any}("localName", "head"),Pair{String,Any}("nodeValue", ""),Pair{String,Any}("childNodeCount", 7),Pair{String,Any}("attributes", Any[]),Pair{String,Any}("nodeType", 1),Pair{String,Any}("backendNodeId", 5)), Dict{String,Any}(Pair{String,Any}("parentId", 15),Pair{String,Any}("nodeId", 17),Pair{String,Any}("nodeName", "BODY"),Pair{String,Any}("localName", "body"),Pair{String,Any}("nodeValue", ""),Pair{String,Any}("childNodeCount", 3),Pair{String,Any}("attributes", Any["style", "cursor: default;"]),Pair{String,Any}("nodeType", 1),Pair{String,Any}("backendNodeId", 6))]),Pair{String,Any}("nodeId", 15),Pair{String,Any}("nodeName", "HTML"),Pair{String,Any}("frameId", "(3CE9B44BD323BDFE63CCD8ED69F2DA88)"),Pair{String,Any}("nodeValue", ""),Pair{String,Any}("attributes", Any[]),Pair{String,Any}("nodeType", 1))]),Pair{String,Any}("nodeId",
14),Pair{String,Any}("nodeName", "#document"),Pair{String,Any}("baseURL", "file:///C:/temp/VegaLite%20plot.html"),Pair{String,Any}("documentURL", "file:///C:/temp/VegaLite%20plot.html"),Pair{String,Any}("xmlVersion", ""),Pair{String,Any}("nodeValue", ""),Pair{String,Any}("nodeType", 9))))))

doc["result"]

send(tg2, "Page.captureScreenshot", format="jpeg") do resp
    open("c:/temp/sandbox2.jpg", "w") do io
        write(io, base64decode(resp["result"]["data"]))
    end
end


send(tg2, "Page.getLayoutMetrics")



tg3 = Target("file://C:/temp/VegaLite plot.html", evt -> info(evt, prefix="EVENT :"))

send(tg3, "DOM.getBoxModel", nodeId=15)



###  docs


Page.printToPDF
#
Print page as PDF. EXPERIMENTAL

PARAMETERS

landscape
boolean
Paper orientation. Defaults to false.

displayHeaderFooter
boolean
Display header and footer. Defaults to false.

printBackground
boolean
Print background graphics. Defaults to false.

scale
number
Scale of the webpage rendering. Defaults to 1.

paperWidth
number
Paper width in inches. Defaults to 8.5 inches.

paperHeight
number
Paper height in inches. Defaults to 11 inches.

marginTop
number
Top margin in inches. Defaults to 1cm (~0.4 inches).

marginBottom
number
Bottom margin in inches. Defaults to 1cm (~0.4 inches).

marginLeft
number
Left margin in inches. Defaults to 1cm (~0.4 inches).

marginRight
number
Right margin in inches. Defaults to 1cm (~0.4 inches).

pageRanges
string
Paper ranges to print, e.g., '1-5, 8, 11-13'. Defaults to the empty string, which means print all pages.

ignoreInvalidPageRanges
boolean
Whether to silently ignore invalid but successfully parsed page ranges, such as '3-2'. Defaults to false.

RETURN OBJECT
data
string
Base64-encoded pdf data.


Page.captureScreenshot
#
Capture page screenshot. EXPERIMENTAL

PARAMETERS

format
string
Image compression format (defaults to png). Allowed values: jpeg, png.

quality
integer
Compression quality from range [0..100] (jpeg only).

clip
Viewport
Capture the screenshot of a given region only. EXPERIMENTAL

fromSurface
boolean
Capture the screenshot from the surface, rather than the view. Defaults to true. EXPERIMENTAL

RETURN OBJECT
data
string
Base64-encoded image data.
