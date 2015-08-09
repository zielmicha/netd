import conf/defs, conf/parse, conf/ast, conf/exceptions

# TODO: refactor to allow better plugin architecture

let baseAdressingCommands = SuiteDef(commands: @[
  cmd("default_route", emptyArgDef())
])

# Static addressing

let staticAdressingCommands = SuiteDef(commands: @[
  cmd("address", singleValueArgDef()),
  cmd("gateway", singleValueArgDef())
]) & baseAdressingCommands

# Address definition

let addressDefCommands = SuiteDef(commands: @[
  cmd("static", @[suiteArgDef(suiteDef=staticAdressingCommands)]),
])

# Link suite

let linkCommands = SuiteDef(commands: @[
  cmd("name", singleValueArgDef(help="rename after link creation")),
  cmd("namespace", singleValueArgDef(help="move to network namespace after link creation")),
  # cmd("bridge_with", singleValueArgDef()),
  # cmd("bridge_master", emptyArgDef())
]) & addressDefCommands

# Bridge

let bridgeCommands = SuiteDef(commands: @[
  cmd("ports", multiValueArgDef())
]) & linkCommands

# Veth

let vethCommands = SuiteDef(commands: @[
  cmd("left", @[suiteArgDef(name="body", suiteDef=linkCommands.valueThunk)]),
  cmd("right", @[suiteArgDef(name="body", suiteDef=linkCommands.valueThunk)])
])

# Main suite

proc linkCmd(): ArgsDef

let mainCommands* = SuiteDef(commands: @[
  cmd("namespace", singleValueArgDef().valueThunk),
  cmd("link", linkCmd.funcThunk),
  cmd("bridge", @[valueArgDef(name="abstractName"), suiteArgDef(suiteDef=bridgeCommands)]),
  cmd("veth", @[valueArgDef(name="abstractName"), suiteArgDef(suiteDef=vethCommands)]),
])

let linkMatchCommands = SuiteDef(commands: @[
  cmd("dev", @[valueArgDef(name="name")]),
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
    ret.echo
  except ConfError:
    (ref ConfError)(getCurrentException()).printError()
