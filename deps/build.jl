using BinDeps
using Compat

import BinDeps: bindir, downloadsdir

@BinDeps.setup
chromium = library_dependency("chromium")


# Chromium revision to download
const revision = 511134

const googlehost = "https://storage.googleapis.com/chromium-browser-snapshots/"

const DOWNLOADS = Dict(
    "Linux-x86_64"   => ("Linux_x64/$revision/chrome-linux.zip", "chrome-linux/chrome"),
    "Darwin-x86_64"  => ("Mac/$revision/chrome-mac.zip",         ""),
    "Windows-x86_64" => ("Win_x64/$revision/chrome-win32.zip",   "chrome-win32/chrome.exe"),
    "Windows-i686"   => ("Win/$revision/chrome-win32.zip",       "chrome-win32/chrome.exe")
)

const SYSTEM = string(BinDeps.OSNAME, '-', Sys.ARCH)

if haskey(DOWNLOADS, SYSTEM)
    suburl, exename = DOWNLOADS[SYSTEM]
    durl = googlehost * suburl
else
    error("No precompiled binaries found for your system. Sorry...")
end

dwnlfile = joinpath(downloadsdir(chromium), "chromium.zip")
unzipdir = bindir(chromium)


run(@build_steps begin
  CreateDirectory(downloadsdir(chromium))
  FileDownloader(durl, dwnlfile)
  # CreateDirectory(bindir(chromium))
  FileUnpacker(dwnlfile, unzipdir, ".")
end)

### write deps.jl file
exepath = joinpath(dirname(@__FILE__),"usr/bin",exename)
open(joinpath(dirname(@__FILE__), "deps.jl"), "w") do io
    print(io, """
        const chromium = "$(escape_string(exepath))"
    """)
end
