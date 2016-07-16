import netd/config, conf/defs

let dhcpServerCommands = SuiteDef(commands: @[
  cmd("addresses", @[valueArgDef(name="start"), valueArgDef(name="end")]),
  cmd("lease", @[valueArgDef(name="hwaddr"), valueArgDef(name="ip")]),
  cmd("nameserver", @[valueArgDef(name="address")]),
  cmd("router", @[valueArgDef(name="address")]),
  cmd("subnet", @[valueArgDef(name="mask")]),
])

addressDefCommands.commands.add cmd("dhcp_server", @[suiteArgDef(suiteDef=dhcpServerCommands)])
