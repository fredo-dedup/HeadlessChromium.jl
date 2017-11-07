# HeadlessChromium

_A Julia wrapper for Chromium_


|Julia versions | master build | Coverage |
|:-------------:|:------------:|:--------:|
|[![HeadlessChromium](http://pkg.julialang.org/badges/HeadlessChromium_0.6.svg)](http://pkg.julialang.org/?pkg=HHeadlessChromium&ver=0.6) | [![Build Status](https://travis-ci.org/fredo-dedup/HeadlessChromium.jl.svg?branch=master)](https://travis-ci.org/fredo-dedup/HeadlessChromium.jl) [![Build status](https://ci.appveyor.com/api/projects/status/i73ux5hw69rn5c48/branch/master?svg=true)](https://ci.appveyor.com/project/fredo-dedup/headlesschromium-jl/branch/master) | [![Coverage Status](https://coveralls.io/repos/fredo-dedup/HeadlessChromium.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/fredo-dedup/HeadlessChromium.jl?branch=master) |



This package is a Julia wrapper for the Google Chromium web browser. The Browser
is launched headless and is controlled from Julia over the 'Chrome
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

Opening a new page, this time providing a callback function to capture events emitted.:

```julia
mycallback(resp) = info(resp, prefix="event : ") # will be called for each event

myTarget2 = Target("http://www.yahoo.com", mycallback)
```

Sending a command to the page and waiting for the result:

```julia
resp = send(myTarget, "Browser.getVersion")
# resp is a dictionary representation of the JSON returned by Chromium
```
The synchronous version of `send` accepts a timeout keyword argument (default=5)
specifying the number of seconds to wait before throwing a `TimeoutException`.


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

Closing Chromium (will be relaunched automatically on the next `Target()` call):

```julia
stopChromium()
```
