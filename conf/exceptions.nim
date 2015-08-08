import terminal, strutils

type
  ConfError* = object of ValueError
    data: string
    filename: string
    offset: int
    context: seq[string]
  TokenizeError* = object of ConfError
  ParseError* = object of ConfError
  SemanticError* = object of ConfError

var localErrorContext {.threadvar.}: seq[string]

proc newConfError*[T: ConfError](typ: typedesc[T], data: string, offset: int, msg: string, filename: string=nil): ref T =
  result = newException(T, msg)
  result.data = data
  result.offset = offset
  result.context = localErrorContext
  result.filename = filename

proc offsetInfo(data: string, offset: int): tuple[lineno: int, colno: int, line: string] =
  let prev = data[0..offset]
  result.lineno = prev.count('\L') + 1
  let lineStart = prev.rfind('\L') + 1
  var lineEnd = data.find('\L', lineStart)
  if lineEnd == -1:
    lineEnd = data.len - 1
  else:
    lineEnd -= 1
  result.colno = offset - lineStart
  result.line = data[lineStart..lineEnd]

proc printError*(error: ref ConfError) =
  let (lineno, colno, line) = offsetInfo(error.data, error.offset)
  setForegroundColor(fgWhite, bright=true)
  setStyle({styleBright})
  let filename = if error.filename == nil: "nil" else: error.filename
  write stdout, "$1($2, $3) " % [filename, $lineno, $colno]
  resetAttributes()
  setForegroundColor(fgRed)
  write stdout,  "Error: "
  resetAttributes()
  echo error.msg
  resetAttributes()
  if colno > 0:
    write stdout, "  "
    echo line
    setForegroundColor(fgGreen)
    echo ".." & (".".repeat(colno) & "^")
    resetAttributes()
