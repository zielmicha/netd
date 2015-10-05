import netd/link, netd/config, conf/defs

let linkMatchCommands = SuiteDef(commands: @[
  cmd("dev", @[valueArgDef(name="name")]),
])

mainCommands.commands.add cmd("link",
                              @[suiteArgDef(name="link-type",
                                            suiteDef=linkMatchCommands.valueThunk,
                                            isCommand=true),
                                suiteArgDef(name="body",
                                            suiteDef=linkCommands.valueThunk)])
