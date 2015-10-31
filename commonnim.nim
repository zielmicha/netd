
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

proc unpackSeq3*[T](args: T): auto =
  assert args.len == 3
  return (args[0], args[1], args[2])

# urandom

const hexLetters = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f']

proc encodeHex(s: string): string =
  result = ""
  result.setLen(s.len * 2)
  for i in 0..s.len-1:
    var a = ord(s[i]) shr 4
    var b = ord(s[i]) and ord(0x0f)
    result[i * 2] = hexLetters[a]
    result[i * 2 + 1] = hexLetters[b]

proc urandom*(len: int): string =
  var f = open("/dev/urandom")
  defer: f.close
  result = ""
  result.setLen(len)
  let actualRead = f.readBuffer(result.cstring, len)
  if actualRead != len:
    raise newException(IOError, "cannot read random bytes")

proc hexUrandom*(len: int): string =
  urandom(len).encodeHex
