nim c --os:windows --cpu:amd64 -o:tmp/test1.exe  --import:nim_simplebacktrace --stacktrace:off -d:nimStackTraceOverride -d:lineTrace:on --lineDir:on -d:mingw --gcc.exe:x86_64-w64-mingw32-gcc --gcc.linkerexe:x86_64-w64-mingw32-gcc tests/test1.nim