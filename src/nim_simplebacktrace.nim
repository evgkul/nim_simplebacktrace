# This is just an example to get you started. A typical library package
# exports the main API in this file. Note that you cannot rename this file
# but you can remove it if you wish.

import macros
import os
import strformat

macro buildBacktrace() =
  var files = @[
    "atomic.c",
    "dwarf.c",
    "fileline.c",
    "posix.c",
    "print.c",
    "sort.c",
    "state.c",
    "backtrace.c",
    "simple.c",
    "elf.c",
    "mmapio.c",
    "mmap.c",
  ]
  result = newStmtList()
  var cargs = "-I backtrace_utils -D HAVE_SYNC_FUNCTIONS"
  block:
    let list_64 = @["alpha", "powerpc64", "powerpc64el", "sparc", "amd64", "arm64", "mips64", "mips64el", "riscv64"]
    let list_32 = @["i386", "powerpc", "mips", "mipsel", "arm"]
    let arch = if list_64.contains hostCPU:
      "64"
    elif list_32.contains hostCPU:
      "32"
    else:
      error(&"Unknown CPU: {hostCPU}")
      ""
    let ftype = case hostOS:
      of "linux", "netbsd", "freebsd", "openbsd", "solaris", "aix": "elf"&arch
      of "windows": "pecoff"
      of "macosx": "macho"
      else:
        error(&"Unknown OS: {hostOS}")
        ""
    if ftype=="pecoff":
      files.add "pecoff.c"
    cargs.add &" -D BACKTRACE_ELF_SIZE={arch}"
  for file in files:
    let fpath = "lib/libbacktrace"/file
    let fpath_lit = newLit fpath
    #echo "LIT ",fpath_lit.treeRepr
    let c = newCall(ident "compile",fpath_lit,newLit cargs)
    var p = newNimNode(nnkPragma,c)
    p.add c
    result.add p
  #echo "RES ",result.treeRepr

buildBacktrace()

type BacktraceState* = distinct pointer
type backtrace_error_callback = proc(data:pointer,msg:cstring,errnum:cint):void {.cdecl.}
proc backtrace_create_state(filename:cstring,threaded:cint,error_callback:backtrace_error_callback,data:pointer):BacktraceState {.importc.}

let backtrace_state = backtrace_create_state(getAppFilename().cstring,1,proc(data:pointer,msg:cstring,errnum:cint):void {.cdecl.} = raise newException(Exception,&"BACKTRACE ERROR: {msg}"),nil)

proc add*(x, y: int): int =
  ## Adds two files together.
  return x + y
