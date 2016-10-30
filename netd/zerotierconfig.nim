import netd/link, netd/config, conf/defs

let zerotierNetwork = SuiteDef(commands: @[
  cmd("managed", @[]),
  cmd("global", @[]),
], includeSuites: @[linkCommands])

let zerotierCommand = SuiteDef(commands: @[
  cmd("secret", singleValueArgDef()),
  cmd("namespace", singleValueArgDef()),
  cmd("port", singleValueArgDef(help="ZeroTier port")),
  cmd("network", @[valueArgDef(name="name"),
                   suiteArgDef(name="body",
                               suiteDef=zerotierNetwork.valueThunk)]),
])

mainCommands.commands.add cmd("zerotier",
                              @[valueArgDef(name="id", help="ZeroTier network ID"),
                                suiteArgDef(name="body",
                                            suiteDef=zerotierCommand.valueThunk)])
