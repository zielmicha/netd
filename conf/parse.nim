import conf/ast

type ParserState* = ref object
  nodes: seq[Node]
  pos: int
