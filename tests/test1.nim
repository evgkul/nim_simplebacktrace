# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest

import nim_simplebacktrace

proc tfun*(x, y: int): int =
  ## Adds two files together.
  #echo getBacktrace()
  proc tproc() =
    raise newException(Exception,"Test")
  try:
    tproc()
  except Exception as e:
    echo "STRACE ",e.getStackTrace()
  return x + y


test "can add":
  check tfun(5, 5) == 10
