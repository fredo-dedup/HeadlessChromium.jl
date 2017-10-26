using BinDeps
using Compat

import BinDeps: bindir, downloadsdir

@BinDeps.setup

chromium = library_dependency("chromium")

baseurl = "https://www.googleapis.com/download/storage/v1/b/chromium-browser-snapshots/o"

const DOWNLOADS = Dict(
    "Linux-x86_64"   => ("Linux_x64", 510671, "chrome-linux.zip", 1508572738025450, "chrome-linux/chrome"),
    "Linux-i686"     => ("Linux",     362086, "chrome-linux.zip", 1458337367735000, "chrome-linux/chrome"),
    "Darwin-x86_64"  => ("Mac",       510671, "chrome-mac.zip",   1508574413132225, ""),
    "Windows-x86_64" => ("Win_x64",   510671, "chrome-win32.zip", 1508574560935391, "chrome-win32/chrome.exe"),
    "Windows-i686"   => ("Win",       510670, "chrome-win32.zip", 1508573404310752, "chrome-win32/chrome.exe")
)

const SYSTEM = string(BinDeps.OSNAME, '-', Sys.ARCH)

if haskey(DOWNLOADS, SYSTEM)
    fold, ver, zipname, gennum, exename = DOWNLOADS[SYSTEM]
    durl = baseurl * "/$(fold)%2F$(ver)%2F$(zipname)?generation=$(gennum)&alt=media"
else
    error("No precompiled binaries found for your system. Sorry...")
end

dwnlfile = joinpath(downloadsdir(chromium), "chromium.zip")
unzipdir = bindir(chromium)

# println(join([fold, ver, zipname, gennum, exename], " "), "===", dwnlfile, "===", unzipdir)

run(@build_steps begin
  CreateDirectory(downloadsdir(chromium))
  FileDownloader(durl, dwnlfile)
  # CreateDirectory(bindir(chromium))
  FileUnpacker(dwnlfile, unzipdir, ".")
end)

### write deps.jl file
#
# exename = "chrome-win32/chrome.exe"
# exepath = escape_string(joinpath(dirname(@__FILE__),"usr/bin",exename))
#
# "$(joinpath(dirname(@__FILE__),"usr/bin",exename))"

exepath = joinpath(dirname(@__FILE__),"usr/bin",exename)
open(joinpath(dirname(@__FILE__), "deps.jl"), "w") do io
    print(io, """
        const chromium = "$(escape_string(exepath))"
    """)
end
