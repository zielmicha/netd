import conf/ast, conf/defs, conf/preparse, conf/exceptions
import tables, strutils, sequtils

type RootState = ref object
  data: string

type ParserState = object
  root: RootState
  nodes: seq[Node]
  pos: int
  consumeEof: bool

proc initState(root: RootState, nodes: seq[Node]): ParserState =
  result.root = root
  result.nodes = nodes
  result.pos = 0
  result.consumeEof = true

proc splitBySemicolon(nodes: seq[Node]): seq[seq[Node]] =
  result = @[]
  result.add(@[])
  for node in nodes:
    if node.typ == ntSemicolon:
      if result[^1].len != 0:
        result.add(@[])
    else:
      result[^1].add node

proc newConfError[T](state: ParserState, typ: typedesc[T], msg: string): ref T =
  let node = state.nodes[state.pos - 1]
  newConfError(T, state.root.data, node.offset, msg)

proc consumeNode(state: var ParserState): tuple[junkBefore: seq[Node], node: Node] =
  result.junkBefore = @[]
  while true:
    if state.pos >= state.nodes.len:
      raise state.newConfError(ParseError, "EOF unexpected")
    let node = state.nodes[state.pos]
    state.pos += 1
    if node.typ in {ntWhitespace, ntComment}:
      result.junkBefore.add node
    else:
      result.node = node
      break

proc consumeNode(state: var ParserState, checkType: NodeType): auto =
  let (junkBefore, node) = consumeNode(state)
  if node.typ == checkType:
    raise state.newConfError(ParseError, "expected $1, found $2" % [$checkType, $node.typ])
  (junkBefore, node)

proc parseValue(state: var ParserState): Value =
  nil

proc parseCommand(state: var ParserState, suiteDef: SuiteDef): Command =
  let nameValue = parseValue(state)
  if nameValue.typ == ValueType.vtString:
    raise state.newConfError(ParseError, "expected command name, found $1" % [$nameValue.typ])
  let name = nameValue.stringValue
  let commands = suiteDef.commands.toTable
  if not commands.hasKey(name):
    let allowedCommands = suiteDef.commands.mapIt(string, it.name)
    raise state.newConfError(ParseError, "invalid command $1, expected one of $2" % [name, $allowedCommands])
  let command = commands[name]

proc parseSuite(state: var ParserState, suiteDef: SuiteDef): Suite =
  # suite is always enclosed in brackets
  assert state.consumeEof
  assert state.pos == 0

  let commands = state.nodes.splitBySemicolon()
  result.commands = @[]
  for nodes in commands:
    var subState = initState(state.root, nodes)
    result.commands.add parseCommand(subState, suiteDef)

proc parse(state: ParserState, what: ArgType): Arg =
  nil

proc parse*(data: string, suiteDef: SuiteDef): Suite =
  let nodes = preparse(data)
  var rootState: RootState
  new(rootState)
  rootState.data = data
  var state = initState(rootState, nodes)
  parseSuite(state, suiteDef)
