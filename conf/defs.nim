import tables

type
  Supplier[T] = (proc(): T)

  ParserThunk[T] = object
    case isValue: bool
    of true:
      value: T
    of false:
      function: Supplier[T]
      # TODO: args

type
  ArgDefType* = enum
    adtValue
    adtSuite
    adtMoreArgs
    adtCommand

  ValueType* = enum
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
      valueType: ValueType
    of {adtSuite, adtCommand}:
      suiteDef*: ParserThunk[SuiteDef]
    of adtMoreArgs:
      args*: ParserThunk[ArgsDef]

  ArgsDef* = seq[ArgDef]

  SuiteDef* = ref object
    commands*: seq[tuple[name: string, def: ParserThunk[ArgsDef]]]

proc valueArgDef*(name: string, valueType: ValueType, required: bool=true, help: string=nil): ArgDef =
  new(result)
  result.typ = adtValue
  result.required = required
  result.help = help
  result.name = name
  result.valueType = valueType

proc suiteArgDef*(name: string, suiteDef: ParserThunk[SuiteDef], required: bool=true, help: string=nil, isCommand: bool=false): ArgDef =
  new(result)
  result.typ = if isCommand: adtCommand else: adtSuite
  result.required = required
  result.help = help
  result.name = name
  result.suiteDef = suiteDef

converter funcThunk*[T](function: (proc(): T)): ParserThunk[T] =
  result.isValue = false
  result.function = function

proc valueThunk*[T](val: T): ParserThunk[T] =
  result.isValue = true
  result.value = val

proc singleValueArgDef*(valueType=vtString, valueName="value", help: string=nil): ArgsDef =
  @[valueArgDef(name=valueName, valueType=valueType, help=help)]
