import conf/exceptions

type TokenType* = enum
  ttWhitespace
  ttString
  ttComment
  ttBracketOpen
  ttBracketClose
  ttColon
  ttSemicolon
  ttComma

type Token* = object
  startOffset*: int
  endOffset*: int
  typ*: TokenType

const whitespace = {' ', '\t', '\L', '\r'}
const mergableTokens = {ttString, ttWhitespace}

proc tokenizeConf*(data: string): seq[Token] =
  var preresult: seq[Token] = @[]
  var pos = 0

  proc consumeChar(error: string = nil): char {.discardable.} =
    if pos >= data.len:
      raise newException(TokenizeError, "EOF while parsing " & error)
    result = data[pos]
    pos += 1

  while pos < data.len:
    let ch = consumeChar()
    var token: Token
    token.startOffset = pos - 1
    case ch:
    of {'\"', '\''}:
      token.typ = ttString
      let orgCh = ch
      while true:
        let ch = consumeChar("string")
        if ch == orgCh:
          token.endOffset = pos
          break
        elif ch == '\\':
          consumeChar("string")
    of '#':
      token.typ = ttComment
      while pos < data.len:
        let ch = consumeChar()
        if ch in {'\L', '\r'}:
          break
    of {'(', '[', '{'}:
      token.typ = ttBracketOpen
    of {')', ']', '}'}:
      token.typ = ttBracketOpen
    of ';':
      token.typ = ttSemicolon
    of ':':
      token.typ = ttColon
    of ',':
      token.typ = ttComma
    of whitespace:
      token.typ = ttWhitespace
    else:
      token.typ = ttString

    token.endOffset = pos
    preresult.add token

  result = @[]
  for token in preresult:
    if result.len != 0 and token.typ in mergableTokens and result[^1].typ == token.typ:
      result[^1].endOffset = token.endOffset
    else:
      result.add token

when isMainModule:
  echo tokenize(readFile("examples/things.conf"))
