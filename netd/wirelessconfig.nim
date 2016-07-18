import netd/config, conf/defs

let baseWirelessCommands = SuiteDef(commands: @[
  cmd("ssid", singleValueArgDef()),
  cmd("freq", singleValueArgDef()),
], includeSuites: @[linkCommands])

let apWirelessCommands = SuiteDef(commands: @[
  cmd("keymgmt", singleValueArgDef()),
  cmd("passphrase", singleValueArgDef()),
], includeSuites: @[baseWirelessCommands])

addressDefCommands.commands.add cmd("wireless_station", @[valueArgDef(name="name"), suiteArgDef(suiteDef=baseWirelessCommands)])
addressDefCommands.commands.add cmd("wireless_adhoc", @[valueArgDef(name="name"), suiteArgDef(suiteDef=baseWirelessCommands)])
addressDefCommands.commands.add cmd("wireless_ap", @[valueArgDef(name="name"), suiteArgDef(suiteDef=apWirelessCommands)])
