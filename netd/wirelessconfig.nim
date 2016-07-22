import netd/config, conf/defs

let baseWirelessCommands = SuiteDef(commands: @[
  cmd("ssid", singleValueArgDef()),
  cmd("freq", singleValueArgDef()),
  cmd("passphrase", singleValueArgDef())
], includeSuites: @[linkCommands])

let apWirelessCommands = SuiteDef(commands: @[
  cmd("keymgmt", singleValueArgDef()),
  cmd("passphrase", singleValueArgDef()),
], includeSuites: @[baseWirelessCommands])

let stationWirelessCommands = SuiteDef(commands: @[
  cmd("name", singleValueArgDef()),
  cmd("network", @[suiteArgDef(suiteDef=baseWirelessCommands)]),
  cmd("passphrase", singleValueArgDef()),
])

addressDefCommands.commands.add cmd("wireless_station", @[valueArgDef(name="name"), suiteArgDef(suiteDef=stationWirelessCommands)])
addressDefCommands.commands.add cmd("wireless_adhoc", @[valueArgDef(name="name"), suiteArgDef(suiteDef=baseWirelessCommands)])
addressDefCommands.commands.add cmd("wireless_ap", @[valueArgDef(name="name"), suiteArgDef(suiteDef=apWirelessCommands)])
addressDefCommands.commands.add cmd("wireless_mesh", @[valueArgDef(name="name"), suiteArgDef(suiteDef=baseWirelessCommands)])
