import conf/tokenize, conf/ast, conf/util, conf/exceptions
import strutils

proc endingBracket(starting: char): char =
  case starting
  of '(':
    return ')'
  of '[':
    return ']'
  of '{':
    return '}'
  else:
    assert false

const tokenTypeToNodeType = {
  ttWhitespace: ntWhitespace,
  ttString: ntString,
  ttComment: ntComment,
  ttColon: ntColon,
  ttSemicolon: ntSemicolon,
  ttComma: ntComma
}.enumTable(array[ttWhitespace..ttComma, NodeType])

proc preparse*(data: string): seq[Node] =
  var nodesStack: seq[seq[Node]] = @[]
  nodesStack.add seq[Node](@[])
  var bracketTypeStack: seq[char] = @['-']

  for token in tokenizeConf(data):
    var node: Node
    new(node)
    node.offset = token.startOffset
    node.originalValue = data[token.startOffset..token.endOffset-1]

    case token.typ
    of {ttWhitespace, ttString, ttComment, ttSemicolon, ttComma, ttColon}:
      node.typ = tokenTypeToNodeType[token.typ]
    of ttBracketOpen:
      var newList: seq[Node] = @[]
      node.typ = ntBracketed
      node.children = newList
      nodesStack[^1].add node
      nodesStack.add newList
      bracketTypeStack.add endingBracket(node.originalValue[0])
    of ttBracketClose:
      if bracketTypeStack[^1] != node.originalValue[0]:
        raise newConfError(ParseError, data, node.offset,
                           "invalid closing bracket - expected $1, found $2" %
                             [$bracketTypeStack[^1], node.originalValue])
      else:
        discard nodesStack.pop
        discard bracketTypeStack.pop

  if bracketTypeStack.len != 1:
    raise newException(ParseError, "unclosed bracket $1" % $bracketTypeStack[^1])
