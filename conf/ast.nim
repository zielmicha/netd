
type NodeType* = enum
  ntString
  ntBracketed
  ntComment
  ntWhitespace
  ntColon
  ntSemicolon
  ntComma

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

type
  ItemOrJunk*[ITEM, JUNK] = object
    case isItem*: bool
    of true:
      item*: ITEM
    of false:
      junk*: JUNK

  LitteredSeq*[ITEM, JUNK] = object
    items*: seq[ItemOrJunk[ITEM, JUNK]]

type Value* = ref object {.acyclic.}
  case typ*: ValueType
  of vtList:
    listItems: LitteredSeq[Value, Node]
  of vtString:
    originalValue: string
  of vtDict:
    # in form: [key1, value1, key2, value2, ...]
    dictItems: LitteredSeq[Value, Node]
