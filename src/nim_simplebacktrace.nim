# This is just an example to get you started. A typical library package
# exports the main API in this file. Note that you cannot rename this file
# but you can remove it if you wish.

import macros
import os
import strformat
import strutils
import nim_simplebacktrace/backtrace_api

{.passc:"-g3".}
{.passl:"-g3".}

template getPrefix():string =
  instantiationInfo(fullPaths=true).filename.splitFile.dir/"nim_simplebacktrace"
const prefix = getPrefix()

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
  let includes = prefix/"backtrace_utils"
  var cargs = &"-I {includes} -DHAVE_CONFIG_H -I. -funwind-tables"
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
    cargs.add &" -D BACKTRACE_XCOFF_SIZE={arch}"
  for file in files:
    let fpath = prefix/"libbacktrace"/file
    let fpath_lit = newLit fpath
    #echo "LIT ",fpath_lit.treeRepr
    let c = newCall(ident "compile",fpath_lit,newLit cargs)
    var p = newNimNode(nnkPragma,c)
    p.add c
    result.add p
  #echo "RES ",result.treeRepr

buildBacktrace()
#{.passl: "tmp/libbacktrace.a".}
{.passl: "-funwind-tables".}

proc defError(data:pointer,msg:cstring,errnum:cint):void {.cdecl.} = 
  echo &"BACKTRACE ERROR: {msg}"

#echo "PATH ",getAppFilename()

let backtrace_state = backtrace_create_state(getAppFilename().cstring,1,defError,nil)

proc getBacktrace():string =
  if backtrace_state==nil:
    return "BACKTRACE ERROR: backtrace is not initialized"
  type Val = string
  var data:Val
  let dataptr = data.addr.pointer
  proc cb(data: pointer; pc: uintptr_t; filename: cstring; lineno: cint; function: cstring): cint  {.cdecl.} =
    let data = cast[ptr Val](data)
    if filename.len>0 or function.len>0:
      data[].add &"{filename}({lineno}) {function}\n"
  proc e(data:pointer,msg:cstring,errnum:cint):void {.cdecl.} = 
    let data = cast[ptr Val](data)
    data[].add &"BACKTRACE ERROR {errnum}: {msg}"
  assert backtrace_state.backtrace_full(1,cb,e,dataptr)==0
  return data
  

proc add*(x, y: int): int =
  ## Adds two files together.
  echo getBacktrace()
  return x + y
