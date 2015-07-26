import tables

type
  ParserThunk[T] = object
    case isValue: bool
    of true:
      value: T
    of false:
      # TODO: args
      func: (proc(): T)

type
  ArgDefType* = enum
    adtValue
    adtSuite
    adtMoreArgs
    adtCommand

  ArgDef* = ref object
    name*: string
    required*: bool
    case typ*: ArgDefType
    of adtValue: discard
    of {adtSuite, adtCommand}:
      suiteDef*: ParserThunk[SuiteDef]
    of adtMoreArgs:
      args*: ParserThunk[ArgsDef]

  ArgsDef* = seq[ArgDef]

  SuiteDef* = ref object
    commands: Table[string, ArgsDef]
