import tables

type
  ParserThunk[T] = object
    case isValue: bool
    of true:
      value: T
    of false:
      function: (proc(): T {.closure.})
      # TODO: args

proc unwrap*[T](thunk: ParserThunk[T]): T =
  if thunk.isValue:
    return thunk.value
  else:
    return thunk.function()

type
  ArgDefType* = enum
    adtValue
    adtSuite
    adtMoreArgs
    adtCommand

  ValueDefType* = enum
    vtString
    vtInt
    vtDict
    vtSeq
    vtAny

  ArgDef* = ref object
    name*: string
    required*: bool
    help*: string
    case typ*: ArgDefType
    of adtValue:
      valueType: ValueDefType
    of {adtSuite, adtCommand}:
      suiteDef*: ParserThunk[SuiteDef]
    of adtMoreArgs:
      args*: ParserThunk[ArgsDef]

  ArgsDef* = seq[ArgDef]

  CmdDef* = tuple[name: string, def: ParserThunk[ArgsDef]]

  SuiteDef* = ref object
    commands*: seq[CmdDef]

proc valueArgDef*(name: string, valueType=vtString, required: bool=true, help: string=nil): ArgDef =
  new(result)
  result.typ = adtValue
  result.required = required
  result.help = help
  result.name = name
  result.valueType = valueType

proc suiteArgDef*(suiteDef: ParserThunk[SuiteDef], name="body", required: bool=true, help: string=nil, isCommand: bool=false): ArgDef =
  new(result)
  result.typ = if isCommand: adtCommand else: adtSuite
  result.required = required
  result.help = help
  result.name = name
  result.suiteDef = suiteDef

proc funcThunk*[T](function: (proc(): T)): ParserThunk[T] =
  result.isValue = false
  result.function = function

converter valueThunk*[T](val: T): ParserThunk[T] =
  result.isValue = true
  result.value = val

proc singleValueArgDef*(valueType=vtString, valueName="value", help: string=nil): ArgsDef =
  @[valueArgDef(name=valueName, valueType=valueType, help=help)]

proc singleSuiteArgDef*(suiteDef: ParserThunk[SuiteDef], valueName="body", help: string=nil): ArgsDef =
  @[suiteArgDef(suiteDef=suiteDef, name=valueName, help=help)]

proc emptyArgDef*(): ArgsDef =
  @[]

proc cmd*(name: string, def: ParserThunk[ArgsDef]): CmdDef =
  (name, def)

proc cmd*(name: string, def: ArgsDef): CmdDef =
  cmd(name, def.valueThunk)

proc `&`*(a: SuiteDef, b: SuiteDef): SuiteDef =
  SuiteDef(commands: a.commands & b.commands)
