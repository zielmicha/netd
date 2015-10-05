import netd/link, netd/config, conf/defs

# Bridge

let bridgeCommands = SuiteDef(commands: @[
  cmd("ports", multiValueArgDef())
], includeSuites: @[linkCommands])

mainCommands.commands.add cmd("bridge", @[valueArgDef(name="abstractName"), suiteArgDef(suiteDef=bridgeCommands)])
