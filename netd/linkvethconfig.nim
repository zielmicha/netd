import netd/link, netd/config, conf/defs

let vethCommands = SuiteDef(commands: @[
  cmd("left", @[suiteArgDef(name="body", suiteDef=linkCommands.valueThunk)]),
  cmd("right", @[suiteArgDef(name="body", suiteDef=linkCommands.valueThunk)])
])

mainCommands.commands.add cmd("veth", @[
  valueArgDef(name="abstractName"),
  suiteArgDef(suiteDef=vethCommands)])
