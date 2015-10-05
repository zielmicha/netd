import netd/config, conf/defs

# Link suite

let linkCommands* = SuiteDef(commands: @[
  cmd("name", singleValueArgDef(help="rename after link creation")),
  cmd("namespace", singleValueArgDef(help="move to network namespace after link creation")),
  # cmd("bridge_with", singleValueArgDef()),
  # cmd("bridge_master", emptyArgDef()),
], includeSuites: @[addressDefCommands])

