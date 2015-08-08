
proc `&=`*[T](a: var seq[T], b: seq[T]) =
  for i in b:
    a.add(i)

proc flatten*[T](a: seq[seq[T]]): seq[T] =
  result = @[]
  for subseq in a:
    result &= subseq

proc readAllBuffer(file: File): string =
  result = ""
  const BufSize = 1024
  var buffer = newString(BufSize)
  while true:
    var bytesRead = readBuffer(file, addr(buffer[0]), BufSize)
    if bytesRead == BufSize:
      result.add(buffer)
    else:
      buffer.setLen(bytesRead)
      result.add(buffer)
      break

proc readFileSysfs*(filename: string): TaintedString =
  var f = open(filename)
  try:
    result = readAllBuffer(f).TaintedString
  finally:
    close(f)

# --- unpackSeq ---

type Pair[A, B] = tuple[first: A, second: B]

proc unpackSeq1*[T](args: T): auto =
  assert args.len == 1
  return args[0]

proc unpackSeq2*[T](args: T): auto =
  assert args.len == 2
  return (args[0], args[1])
