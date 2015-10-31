import netd/link, netd/config, conf/defs

let openvpnPtpCommand = SuiteDef(commands: @[
  cmd("listen", @[
    valueArgDef(name="protocol"),
    valueArgDef(name="address"),
    valueArgDef(name="port", valueType=vtInt)
  ]),
  cmd("connect", @[
    valueArgDef(name="protocol"),
    valueArgDef(name="address"),
    valueArgDef(name="port", valueType=vtInt)
  ]),
  cmd("key", singleValueArgDef(valueName="filename")),
], includeSuites: @[linkCommands])


mainCommands.commands.add cmd("openvpn_ptp",
                              @[valueArgDef(name="name"),
                                suiteArgDef(name="body",
                                            suiteDef=openvpnPtpCommand.valueThunk)])
