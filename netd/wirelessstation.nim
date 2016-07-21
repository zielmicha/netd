proc pathExists(p: string): bool =
  var s: Stat
  return stat(p, s) >= 0'i32

# Callback

method runMain*(plugin: WirelessPlugin, params: seq[string]): bool =
  if params[0] == "_wpa_callback":
    let idStr = os.getenv("WPA_ID_STR")
    let mode = params[2]

    let bus = getBus(DBUS_BUS_SYSTEM)
    let msg = makeCall("net.networkos.netd", ObjectPath("/net/networkos/netd"), "net.networkos.netd.Wireless", "Callback")
    msg.append(id_str)
    msg.append(mode)
    let reply = bus.sendMessageWithReply(msg).waitForReply
    defer: reply.close
    reply.raiseIfError

    return true
  else:
    return false

proc Callback(self: WirelessPlugin, id_str: string, mode: string) =
  let pos = id_str.find('/')
  let abstractName = id_str[0..<pos]
  let networkName = id_str[pos + 1..^1]
  var newValue: string = nil

  if mode == "CONNECTED":
    newValue = networkName
    echo "connected to network ", networkName
  else:
    newValue = nil
    echo abstractName, " disconnected"

  if newValue != self.activeNetworks.getOrDefault(abstractName):
    self.activeNetworks[abstractName] = newValue
    self.manager.reload()

let wirelessDef = newInterfaceDef(WirelessPlugin)
wirelessDef.addMethod(Callback, [("id_str", string), ("mode", string)], [])

method dbusInit*(self: WirelessPlugin) =
  self.getPlugin(DbusCorePlugin).netdObject.addInterface("net.networkos.netd.Wireless", wirelessDef, self)

# ----

proc stationSubinterface(self: WirelessPlugin, iface: ManagedInterface, config: Suite): Suite =
  let activeSsid = self.activeNetworks.getOrDefault(iface.abstractName)
  for networkCmd in config.commandsWithName("network"):
    let network = networkCmd.args[0].suite
    let ssid = network.singleValue("ssid").stringValue
    if ssid == activeSsid:
      return network
  return nil

proc configureStation(self: WirelessPlugin, iface: ManagedInterface, config: Suite) =
  # 1. Configure network if connected to any
  let activeConfig = self.stationSubinterface(iface, config)
  if activeConfig != nil:
    self.getPlugin(LinkManager).configureInterfaceAll(iface, activeConfig)

  # 2. Setup wpa_supplicant
  let controlPath = RunPath / "wpa-supplicant-" & iface.abstractName & ".sock"
  let configPath = RunPath / "wpa-supplicant-" & iface.abstractName & ".conf"

  let notifyScript = RunPath / "wpa-supplicant-notify.sh"
  if not fileExists(notifyScript):
    writeFile(notifyScript, "#!/bin/sh\n" & getAppDir() & "/netd _wpa_callback \"$1\" \"$2\"")
    discard chmod(notifyScript, 0o700)

  var configStr = ""
  configStr &= "ap_scan=1\n"
  configStr &= "fast_reauth=1\n"
  configStr &= "ctrl_interface=" & controlPath & "\n"

  let sockPath = controlPath / iface.kernelName
  writeFile(configPath, configStr)

  let started = self.processManager.pokeProcess(
    key="supplicant-" & iface.abstractName,
    cmd= @["wpa_supplicant",
           "-i", iface.kernelName,
           "-c", configPath],
    namespace=iface.namespaceName)

  for networkCmd in config.commandsWithName("network"):
    # TODO: quoting
    let network = networkCmd.args[0].suite
    let ssid = network.singleValue("ssid").stringValue
    let id_str = iface.abstractName & "/" & ssid
    configStr &= "network={\n"
    configStr &= "  id_str=\"" & id_str & "\"\n"
    configStr &= "  ssid=\"" & ssid & "\"\n"
    let passphrase = network.singleValue("passphrase", required=false).stringValue
    if passphrase != nil:
      configStr &= "  psk=\"" & passphrase & "\"\n"
    configStr &= "}\n"

  # wait until wpa_supplicant starts
  if started:
    var timeout = 50
    while not pathExists(sockPath):
      sleep(timeout)
      timeout *= 2

  # make sure notification process is running
  self.processManager.pokeProcess(
    key="cli-" & iface.abstractName,
    cmd= @["wpa_cli",
           "-p", controlPath,
           "-a", notifyScript],
    namespace=iface.namespaceName)

  # write new configuration and reload wpa_supplicant
  writeFile(configPath, configStr)

  if started or self.lastConfigHash.getOrDefault(iface.abstractName) != secureHash(configStr):
    checkCall(@["wpa_cli", "-p", controlPath, "reconfigure"])
    self.lastConfigHash[iface.abstractName] = secureHash(configStr)
