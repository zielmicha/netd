import netd/config, conf/defs

let baseWirelessCommands = SuiteDef(commands: @[
  cmd("ssid", singleValueArgDef()),
  cmd("freq", singleValueArgDef()),
  cmd("passphrase", singleValueArgDef())
], includeSuites: @[linkCommands])

let apWirelessCommands = SuiteDef(commands: @[
  cmd("key_mgmt", singleValueArgDef()),
], includeSuites: @[baseWirelessCommands])

let stationNetworkWirelessCommands = SuiteDef(commands: @[
  cmd("key_mgmt", singleValueArgDef()),
  cmd("anonymous_identity", singleValueArgDef()),
  cmd("identity", singleValueArgDef()),
  cmd("phase2", singleValueArgDef()),
  cmd("eap", singleValueArgDef()),
  cmd("password", singleValueArgDef()),
  cmd("domain_suffix_match", singleValueArgDef()),
  cmd("ca_cert", singleValueArgDef()), # TODO: file
], includeSuites: @[baseWirelessCommands])

let stationWirelessCommands = SuiteDef(commands: @[
  cmd("name", singleValueArgDef()),
  cmd("network", @[suiteArgDef(suiteDef=stationNetworkWirelessCommands)]),
])

addressDefCommands.commands.add cmd("wireless_station", @[valueArgDef(name="name"), suiteArgDef(suiteDef=stationWirelessCommands)])
addressDefCommands.commands.add cmd("wireless_adhoc", @[valueArgDef(name="name"), suiteArgDef(suiteDef=baseWirelessCommands)])
addressDefCommands.commands.add cmd("wireless_ap", @[valueArgDef(name="name"), suiteArgDef(suiteDef=apWirelessCommands)])
addressDefCommands.commands.add cmd("wireless_mesh", @[valueArgDef(name="name"), suiteArgDef(suiteDef=baseWirelessCommands)])
