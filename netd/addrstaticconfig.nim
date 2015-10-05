import netd/config, conf/defs

let staticAdressingCommands = SuiteDef(commands: @[
  cmd("address", singleValueArgDef()),
  cmd("gateway", singleValueArgDef())
], includeSuites: @[baseAdressingCommands])

addressDefCommands.commands.add cmd("static", @[suiteArgDef(suiteDef=staticAdressingCommands)])
