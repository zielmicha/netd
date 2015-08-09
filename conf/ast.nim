import strutils, sequtils
import commonnim

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

type RootState* = ref object
  data*: string
  filename*: string

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
  rootState*: RootState

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

# Creation

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

proc newLitteredItem*[T](item: var T, before: openarray[Node], after: openarray[Node], offset: int, rootState: RootState) =
  new(item)
  item.junkBefore = @before
  item.junkAfter = @after
  item.offset = offset
  item.rootState = rootState

# Exceptions

import conf/exceptions

proc argToLitteredItem(arg: Arg): LitteredItem =
  case arg.typ
  of aCommand:
    return arg.command
  of aSuite:
    return arg.suite
  of aValue:
    return arg.value

proc newConfError*(item: LitteredItem, msg: string): ref SemanticError =
  newConfError(SemanticError, offset=item.offset, msg=msg, data=item.rootState.data, filename=item.rootState.filename)

proc newConfError*(item: Arg, msg: string): ref SemanticError =
  newConfError(item.argToLitteredItem, msg)

# To string

proc `$`*(n: Node): string =
  case n.typ:
  of ntBracketed:
    "ntBracketed '$1' $2" % [n.originalValue, $n.children]
  else:
    "$1 [$2]" % [$n.typ, n.originalValue]

proc stringValue*(n: Value): string =
  if n == nil: # enables common workflow with singleValue(required=false)
    return nil
  if n.typ != vtString:
    raise newConfError(n, "expected string found $1" % $n.typ)
  let originalValue = n.originalValue
  if originalValue[0] in {'"', '\''}:
    # TODO: better parsing
    return originalValue[1..^1]
  return originalValue

proc stringValue*(n: Arg): string =
  return n.value.stringValue

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

# Browsing

iterator commandsWithName*(suite: Suite, name: string): Command =
  for command in suite.commands:
    if command.name == name:
      yield command

proc hasCommandWithName*(suite: Suite, name: string): bool =
  for command in suite.commandsWithName(name):
    return true
  return false

proc singleCommand*(suite: Suite, name: string, required=true): Command =
  let s = toSeq(commandsWithName(suite, name))
  if len(s) == 0:
    if required:
      raise newConfError(suite, "required command $1 not found" % name)
    else:
      return nil
  if len(s) > 1:
    raise newConfError(s[1], "command $1 repeated $2 times, at most one instance is allowed" % [name, $len(s)])
  return s[0]

proc singleValue*(suite: Suite, name: string, required=true): Value =
  let cmd = singleCommand(suite, name, required)
  if cmd == nil:
    return nil
  else:
    return cmd.args.unpackSeq1.value
