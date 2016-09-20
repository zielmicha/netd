import netd/config, conf/defs

addressDefCommands.commands.add cmd("vlan", @[valueArgDef(name="number", valueType=vtInt), suiteArgDef(suiteDef=linkCommands)])
