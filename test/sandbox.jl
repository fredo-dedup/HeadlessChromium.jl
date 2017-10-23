
using HeadlessChromium

tg1 = Target("C:/Users/frtestar/AppData/Local/Temp/jl_7F2A.tmp.html")

com = "D:\\frtestar\\.julia\\v0.6\\HeadlessChromium\\deps\\usr/bin\\chrome-win32/chrome.exe"

pr = spawn(`$com `)

typeof(pr)
methodswith(Base.Process)


process_running(pr)
ch = openChromium()
