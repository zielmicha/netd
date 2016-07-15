import netd/config, conf/defs

# Bridge

let iptablesCommands = SuiteDef(commands: @[
  cmd("append_to", @[valueArgDef(name="name")]),
  cmd("prepend_to", @[valueArgDef(name="name")]),
  cmd("rule", multiValueArgDef()),
])

mainCommands.commands.add cmd("iptables",
                              @[valueArgDef(name="table"),
                                valueArgDef(name="chain"),
                                suiteArgDef(suiteDef=iptablesCommands)])
