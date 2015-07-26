import conf/tokenize, conf/ast, conf/util, conf/exceptions
import strutils

proc endingBracket(starting: string): string =
  case starting
  of "(":
    return ")"
  of "[":
    return "]"
  of "{":
    return "}"
  of "START":
    return "EOF"
  else:
    assert false, $starting

const tokenTypeToNodeType = {
  ttWhitespace: ntWhitespace,
  ttString: ntString,
  ttComment: ntComment,
  ttColon: ntColon,
  ttSemicolon: ntSemicolon,
  ttComma: ntComma
}.enumTable(array[ttWhitespace..ttComma, NodeType])

proc preparse*(data: string): seq[Node] =
  var rootNode: Node
  new(rootNode)
  rootNode.typ = ntBracketed
  rootNode.children = @[]
  rootNode.originalValue = "START"
  var nodesStack: seq[Node] = @[rootNode]

  for token in tokenizeConf(data):
    var node: Node
    new(node)
    node.offset = token.startOffset
    node.originalValue = data[token.startOffset..token.endOffset-1]

    case token.typ
    of {ttWhitespace, ttString, ttComment, ttSemicolon, ttComma, ttColon}:
      node.typ = tokenTypeToNodeType[token.typ]
      nodesStack[^1].children.add node
    of ttBracketOpen:
      node.typ = ntBracketed
      node.children = @[]
      nodesStack[^1].children.add node
      nodesStack.add node
    of ttBracketClose:
      let expected = endingBracket(nodesStack[^1].originalValue)
      if expected != node.originalValue:
        raise newConfError(ParseError, data, node.offset,
                           "invalid closing bracket - expected $1, found $2" %
                             [expected, node.originalValue])
      else:
        discard nodesStack.pop

  if nodesStack.len != 1:
    raise newException(ParseError, "unclosed bracket $1" % nodesStack[^1].originalValue)

  return nodesStack[0].children
