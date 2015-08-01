import strutils

type NodeType* = enum
  ntString
  ntBracketed
  ntComment
  ntWhitespace
  ntColon
  ntSemicolon
  ntComma

const unmeaningfulNodeTypes = {ntComment, ntWhitespace}

type Node* = ref object {.acyclic.}
  originalValue*: string
  offset*: int

  case typ*: NodeType
  of ntString:
    value*: string
  of ntBracketed:
    children*: seq[Node]
  else: discard

type ValueType* = enum
  vtList
  vtString
  vtDict

type LitteredItem* = ref object {.inheritable.}
  junkBefore*: seq[Node]
  junkAfter*: seq[Node]

type Value* =  ref object {.acyclic.} of LitteredItem
  case typ*: ValueType
  of vtList:
    listItems: seq[Value]
  of vtString:
    originalValue: string
  of vtDict:
    dictItems: seq[tuple[key: Value, value: Value]]

type
  ArgType* = enum
    aCommand
    aSuite
    aValue

  Arg* = object
    case typ*: ArgType
    of aCommand:
      command*: Command
    of aSuite:
      suite*: Suite
    of aValue:
      value*: Value

  Command* = ref object {.acyclic.} of LitteredItem
    name*: string
    args*: seq[Arg]

  Suite* = ref object of LitteredItem
    commands*: seq[Command]

proc `$`*(n: Node): string =
  case n.typ:
  of ntBracketed:
    "ntBracketed '$1' $2" % [n.originalValue, $n.children]
  else:
    "$1 [$2]" % [$n.typ, n.originalValue]

proc stringValue*(n: Value): string =
  let originalValue = n.originalValue
  # TODO: implement parsing
  originalValue
