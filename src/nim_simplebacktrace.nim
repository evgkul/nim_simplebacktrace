# This is just an example to get you started. A typical library package
# exports the main API in this file. Note that you cannot rename this file
# but you can remove it if you wish.

import macros
import os

macro buildBacktrace() =
  let files = @[
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
    "pecoff.c",
  ]
  result = newStmtList()
  for file in files:
    let fpath = "lib/libbacktrace"/file
    let fpath_lit = newLit fpath
    echo "LIT ",fpath_lit.treeRepr
    let c = newCall(ident "compile",fpath_lit,newLit "-I backtrace_utils")
    var p = newNimNode(nnkPragma,c)
    p.add c
    result.add p
  echo "RES ",result.treeRepr

buildBacktrace()

proc add*(x, y: int): int =
  ## Adds two files together.
  return x + y
