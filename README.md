# HeadlessChromium

[![Build Status](https://travis-ci.org/fredo-dedup/HeadlessChromium.jl.svg?branch=master)](https://travis-ci.org/fredo-dedup/HeadlessChromium.jl)

[![Coverage Status](https://coveralls.io/repos/fredo-dedup/HeadlessChromium.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/fredo-dedup/HeadlessChromium.jl?branch=master)

[![codecov.io](http://codecov.io/github/fredo-dedup/HeadlessChromium.jl/coverage.svg?branch=master)](http://codecov.io/github/fredo-dedup/HeadlessChromium.jl?branch=master)


This package is a Julia wrapper for the Google Chromium web browser. The Browser
is launched headless and can be controlled from Julia through the 'Chrome
DevTools Protocol'. The DOM can be explored, changed, captured to a pdf document,
input events can be simulated, etc.

Use this package to :
- scrape web sites, automate form filling
- test web applications
- capture screenshots

For a full documentation of the DevTools Protocol see :
https://chromedevtools.github.io/devtools-protocol/tot


Opening a new page (a 'target'):

```julia
using HeadlessChromium

myTarget = Target("about:") # open the 'about:' page
```

Sending a command to the page and waiting for the result:

```julia
resp = send(myTarget, "Browser.getVersion")
# resp is a dictionary representation of the JSON returned by Chromium
```

Sending a command to the page asynchronously (i.e. without waiting for
Chromium to respond):

```julia
plotfile = tempname() # output file
send(myTarget, "Page.printToPDF", format="A4") do resp
    open(plotfile, "w") do io
        write(io, base64decode(resp["result"]["data"]))
    end
end
```

Closing the target:

```julia
close(myTarget)
```
