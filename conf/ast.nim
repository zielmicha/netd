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
const meaningfulNodeTypes* = {ntString, ntBracketed, ntColon, ntSemicolon, ntComma}

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
  offset*: int

type Value* =  ref object {.acyclic.} of LitteredItem
  case typ*: ValueType
  of vtList:
    listItems*: seq[Value]
  of vtString:
    originalValue*: string
  of vtDict:
    dictItems*: seq[tuple[key: Value, value: Value]]

type
  ArgType* = enum
    aCommand
    aSuite
    aValue

  Arg* = object {.acyclic.}
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

  Suite* = ref object {.acyclic.} of LitteredItem
    commands*: seq[Command]

proc makeSyntheticWhitespace*(data: string): Node =
  new(result)
  result.typ = ntWhitespace
  result.originalValue = data

proc makeArg*(val: Command): Arg =
  result.typ = aCommand
  result.command = val

proc makeArg*(val: Suite): Arg =
  result.typ = aSuite
  result.suite = val

proc makeArg*(val: Value): Arg =
  result.typ = aValue
  result.value = val

proc newLitteredItem*[T](item: var T, before: openarray[Node], after: openarray[Node], offset: int) =
  new(item)
  item.junkBefore = @before
  item.junkAfter = @after
  item.offset = offset

proc `$`*(n: Node): string =
  case n.typ:
  of ntBracketed:
    "ntBracketed '$1' $2" % [n.originalValue, $n.children]
  else:
    "$1 [$2]" % [$n.typ, n.originalValue]

proc stringValue*(n: Value): string =
  let originalValue = n.originalValue
  if originalValue[0] in {'"', '\''}:
    # TODO: better parsing
    return originalValue[1..^1]
  return originalValue

proc indent(t: string): string =
  t.replace("\L", "\L  ")

proc `$`*(val: Arg): string

proc `$`*(command: Command): string =
  "($1 $2)" % [command.name,
              command.args.map(`$`).join(" ")]

proc `$`*(suite: Suite): string =
  "{" & indent("\L" & suite.commands.map(`$`).join("\L")) & "\L}"

proc `$`*(value: Value): string =
  case value.typ:
  of vtString:
    return value.originalValue
  of vtList:
    return $value.listItems
  of vtDict:
    return $value.dictItems

proc `$`*(val: Arg): string =
  case val.typ:
  of aValue:
    $(val.value)
  of aSuite:
    $(val.suite)
  of aCommand:
    $(val.command)
