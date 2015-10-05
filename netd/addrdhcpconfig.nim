import netd/config, conf/defs

let dhcpCommands = SuiteDef(commands: @[],
                            includeSuites: @[baseAdressingCommands])

addressDefCommands.commands.add cmd("dhcp", @[suiteArgDef(suiteDef=dhcpCommands)])
