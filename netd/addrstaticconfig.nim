import netd/config, conf/defs

let staticAdressingCommands = SuiteDef(commands: @[
  cmd("address", singleValueArgDef()),
  cmd("gateway", singleValueArgDef()),
  cmd("peer_address", singleValueArgDef()),
], includeSuites: @[baseAdressingCommands])

addressDefCommands.commands.add cmd("static", @[suiteArgDef(suiteDef=staticAdressingCommands)])
