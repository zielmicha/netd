# Easily run commands.
import osproc, strutils

type CalledProcessError* = object of IOError
  errorCode: int

proc call*(args: openarray[string], echo=false): int =
  let args = @args
  if echo:
    echo args.map(proc(s:string):string=quoteShellPosix(s)).join(" ")
  let process = startProcess(command=args[0], args=args[1..^1], options={poParentStreams, poUsePath})
  process.waitForExit

proc checkCall*(args: openarray[string], echo=false) =
  let ret = call(args, echo=echo)
  if ret != 0:
    let exc = newException(CalledProcessError, "called process returned status code $1" % [$ret])
    exc.errorCode = ret
    raise exc
