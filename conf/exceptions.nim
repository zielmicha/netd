
type
  ConfError* = object of ValueError
    data: string
    filename: string
    offset: int
  TokenizeError* = object of ConfError
  ParseError* = object of ConfError

proc newConfError*[T: ConfError](typ: typedesc[T], data: string, offset: int, msg: string): ref T =
  result = newException(T, msg)
  result.data = data
  result.offset = offset
