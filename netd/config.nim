import conf/defs, conf/parse, conf/ast, conf/exceptions

let routeTargets* = SuiteDef(commands: @[
  cmd("via", singleValueArgDef()),
  cmd("local", emptyArgDef()),
])

let baseAdressingCommands* = SuiteDef(commands: @[
  cmd("default", emptyArgDef()),
  cmd("route", @[
    valueArgDef(name="network"),
    suiteArgDef(name="target",
                suiteDef=routeTargets.valueThunk,
                isCommand=true),
  ])
])

# Address definition

let addressDefCommands* = SuiteDef(commands: @[])

# Main suite

let mainCommands* = SuiteDef(commands: @[
  cmd("namespace", singleValueArgDef().valueThunk),
])
