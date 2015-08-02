import conf/defs, conf/parse, conf/ast, conf/exceptions

# Link suite

let linkCommands = SuiteDef(commands: @[
  ("name", singleValueArgDef(help="rename after link creation").valueThunk),
  ("namespace", singleValueArgDef().valueThunk),
  ("bridge_with", singleValueArgDef().valueThunk),
  ("bridge_master", emptyArgDef().valueThunk)
])

# Main suite

proc linkCmd(): ArgsDef

let mainCommands = SuiteDef(commands: @[
  ("namespace", singleValueArgDef(help="move to network namespace after link creation").valueThunk),
  ("link", linkCmd.funcThunk)
])

proc linkMatchDevCmd(): ArgsDef =
  @[valueArgDef(name="name")]

let linkMatchCommands = SuiteDef(commands: @[
  ("dev", linkMatchDevCmd.funcThunk),
])

proc linkCmd(): ArgsDef =
  @[suiteArgDef(name="link-type",
                suiteDef=linkMatchCommands.valueThunk,
                isCommand=true),
   suiteArgDef(name="body",
               suiteDef=linkCommands.valueThunk)]

when isMainModule:
  try:
    let ret = parse(stdin.readAll(), "stdin", mainCommands)
  except ConfError:
    (ref ConfError)(getCurrentException()).printError()
