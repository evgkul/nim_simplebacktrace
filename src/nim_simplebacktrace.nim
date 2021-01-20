# This is just an example to get you started. A typical library package
# exports the main API in this file. Note that you cannot rename this file
# but you can remove it if you wish.

import macros
import os
import strformat
import strutils
import nim_simplebacktrace/backtrace_api
import system/stacktraces

{.passc:"-g3".}
{.passl:"-g3".}

template getPrefix():string =
  instantiationInfo(fullPaths=true).filename.splitFile.dir/"nim_simplebacktrace"
const prefix = getPrefix()
const OVERRIDE_BACKTRACE_SIZE {.strdefine.} = ""
const OVERRIDE_BACKTRACE_OS {.strdefine.} = ""
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
    let arch = if OVERRIDE_BACKTRACE_SIZE!="":
      OVERRIDE_BACKTRACE_SIZE
    elif list_64.contains hostCPU:
      "64"
    elif list_32.contains hostCPU:
      "32"
    else:
      error(&"Unknown CPU: {hostCPU}")
      ""
    let ftype = if OVERRIDE_BACKTRACE_OS!="":
      OVERRIDE_BACKTRACE_OS
    else:
      case hostOS:
      of "linux", "netbsd", "freebsd", "openbsd", "solaris", "aix": "elf"&arch
      of "windows": "pecoff"
      of "macosx": "macho"
      else:
        #error(&"Unknown OS: {hostOS}")
        "unknown"
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
  echo &"BACKTRACE ERROR {errnum}: {msg}"

#echo "PATH ",getAppFilename()

let backtrace_state = backtrace_create_state(getAppFilename().cstring,1,defError,nil)

proc getBacktrace*():string {.noinline,raises:[].}=
  if backtrace_state==nil:
    return "BACKTRACE ERROR: backtrace is not initialized"
  type Val = string
  var data:Val
  let dataptr = data.addr.pointer
  proc cb(data: pointer; pc: cuintptr_t; filename: cstring; lineno: cint; function: cstring): cint  {.cdecl.} =
    let data = cast[ptr Val](data)
    if filename.len>0 or function.len>0:
      #data[].add &"{filename}({lineno}) {function}\n"
      data[].add $filename & "(" & $lineno & ")" & $function & "\n"
  proc e(data:pointer,msg:cstring,errnum:cint):void {.cdecl.} = 
    let data = cast[ptr Val](data)
    data[].add "BACKTRACE ERROR " & $errnum & ": " & $msg & "\n" 
  let r = backtrace_state.backtrace_full(1,cb,e,dataptr)
  if r!=0:
    data.add "INVALID RETURN CODE: " & $r & "\n"
  return data
  
proc getProgramCounters*(maxLength: cint): seq[cuintptr_t] {.
    nimcall, gcsafe, locks: 0, raises: [], tags: [], noinline.} =
  #echo "COUNTERS ",maxLength
  type Val = seq[cuintptr_t]
  var data:Val
  if backtrace_state==nil:
    echo "BACKTRACE ERROR: backtrace is not initialized"
    return data
  proc e(data:pointer,msg:cstring,errnum:cint):void {.cdecl.} = 
    echo "BACKTRACE ERROR " & $errnum & ": " & $msg & "\n" 
  proc cb(data: pointer; pc: cuintptr_t): cint  {.cdecl.} =
    let d = cast[ptr Val](data)
    d[].add pc
  if data.len>maxLength.int:
    data.setLen maxLength.int
  discard backtrace_state.backtrace_simple(1,cb,e,data.addr.pointer)
  return data

when defined nimStackTraceOverride:
  proc getDebuggingInfoProc*(programCounters: seq[cuintptr_t], maxLength: cint): seq[StackTraceEntry] {.
    nimcall, gcsafe, locks: 0, raises: [], tags: [], noinline.} =
    #echo "GETINFO ",(programCounters,maxLength)
    type Val = seq[StackTraceEntry]
    var data:Val
    let dataptr = data.addr.pointer
    proc cb(data: pointer; pc: cuintptr_t; filename: cstring; lineno: cint; function: cstring): cint  {.cdecl.} =
      let data = cast[ptr Val](data)
      var entry:StackTraceEntry
      if filename.len>0 or function.len>0:
        #data[].add &"{filename}({lineno}) {function}\n"
        entry.programCounter = pc.uint
        entry.procnameStr = $function
        entry.filenameStr = $filename
        entry.procname = entry.procnameStr.cstring
        entry.filename = entry.filenameStr.cstring
        entry.line = lineno.int
        data[].add entry
    proc e(data:pointer,msg:cstring,errnum:cint):void {.cdecl.} = 
      let data = cast[ptr Val](data)
      echo "BACKTRACE ERROR " & $errnum & ": " & $msg & "\n" 
    for p in programCounters:
      if data.len<maxLength.int:
        discard backtrace_state.backtrace_pcinfo(p,cb,e,dataptr)
    return data

  registerStackTraceOverride getBacktrace
  registerStackTraceOverrideGetProgramCounters getProgramCounters
  registerStackTraceOverrideGetDebuggingInfo getDebuggingInfoProc

