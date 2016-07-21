# Most complete documentation for wpa_supplicant is example configuration file: https://w1.fi/cgit/hostap/plain/wpa_supplicant/wpa_supplicant.conf
import subprocess, conf/ast, strutils, collections/random, os, tables, securehash, options, posix
import netd/core, netd/processmanager, netd/link, netd/addr, netd/iproute, netd/main
import netd/dbuscore, dbus, dbus/def, dbus/lowlevel
include netd/wirelessconfig

type
  WirelessType {.pure.} = enum
    adhoc
    ap
    station
    mesh

  WirelessPlugin* = ref object of Plugin
    processManager: ProcessManager
    # TODO: use netlink API to query type instead of saving
    interfaceTypes: TableRef[string, WirelessType]
    previousInterfaceTypes: TableRef[string, WirelessType]

    # for station mode wpa_supplicant callback
    activeNetworks: TableRef[string, string]
    lastConfigHash: TableRef[string, SecureHash]

const allWirelessCommands = @["wireless_ap", "wireless_station", "wireless_adhoc", "wireless_mesh"]

proc create*(t: typedesc[WirelessPlugin], manager: NetworkManager): WirelessPlugin =
  new(result)
  result.manager = manager
  result.processManager = newProcessManager()
  result.interfaceTypes = newTable[string, WirelessType]()
  result.previousInterfaceTypes = newTable[string, WirelessType]()
  result.activeNetworks = newTable[string, string]()
  result.lastConfigHash = newTable[string, SecureHash]()

include netd/wirelessstation

proc gatherSubinterfacesWithConfigs*(self: WirelessPlugin, config: Suite, abstractParentName: string, publicIfaces: bool): ManagedInterfaceWithConfigSeq =
  result = @[]

  for command in config.commands:
    if command.name in allWirelessCommands:
      let name = command.args[0].stringValue
      var config = command.args[1].suite

      var iface = ManagedInterface()
      if name == "default":
        if publicIfaces:
          continue
        iface.abstractName = abstractParentName
        iface.isSynthetic = false
      else:
        iface.abstractName = abstractParentName & ".vif-" & name
        iface.isSynthetic = true

      self.interfaceTypes[iface.abstractName] = toTable({
        "wireless_adhoc": WirelessType.adhoc,
        "wireless_station": WirelessType.station,
        "wireless_ap": WirelessType.ap,
        "wireless_mesh": WirelessType.mesh,
        })[command.name]

      if publicIfaces:
        if command.name == "wireless_station":
          # In station mode, configure network only after connecting to network
          let newConfig = self.stationSubinterface(iface, config)
          if config != nil:
            config = newConfig

      let newName = getRename(iface.abstractName, config)
      # TODO: moving to NS requires use of `iw phy`
      iface.kernelName = newName.name
      iface.namespaceName = newName.namespace

      result.add((iface, config))

method gatherSubinterfaces*(self: WirelessPlugin, config: Suite, abstractParentName: string): seq[ManagedInterface] =
  result = @[]
  for p in self.gatherSubinterfacesWithConfigs(config, abstractParentName, publicIfaces=true):
    let (iface, config) = p
    result.add(iface)
    result &= self.getPlugin(LinkManager).gatherSubinterfacesAll(config, iface.abstractName)

proc configureAp(self: WirelessPlugin, iface: ManagedInterface, config: Suite) =
  var configStr = ""
  # FIXME: quoting
  configStr &= "interface=" & iface.kernelName & "\n"
  configStr &= "ssid=" & (config.singleValue("ssid").stringValue) & "\n"
  configStr &= "hw_mode=g\n" # TODO
  #configStr &= "ieee80211n=1\n"

  let keyMgmt = config.singleValue("keymgmt")
  case keyMgmt.stringValue:
    of "wpa2_psk":
      configStr &= "wpa=2\n"
      configStr &= "wpa_passphrase=" & config.singleValue("passphrase").stringValue & "\n"
    else:
      raise keyMgmt.newConfError("invalid keymgmt")

  let configPath = RunPath / ("hostapd-" & iface.abstractName & ".conf")
  writeFile(configPath, configStr)

  self.processManager.pokeProcess(key=iface.abstractName,
                                  cmd= @["hostapd", configPath],
                                  namespace=iface.namespaceName,
                                  usertag= $secureHash(configStr))


proc configureAdhoc(self: WirelessPlugin, iface: ManagedInterface, config: Suite) =
  ipLinkUp(iface.interfaceName)
  try: # TODO
    iwIbssLeave(iface.interfaceName)
  except:
    discard

  iwIbssJoin(iface.interfaceName,
             config.singleValue("ssid").stringValue,
             config.singleValue("freq").intValue)

proc configureMesh(self: WirelessPlugin, iface: ManagedInterface, config: Suite) =
  ipLinkUp(iface.interfaceName)
  try: # TODO
    iwMeshLeave(iface.interfaceName)
  except:
    discard

  iwMeshJoin(iface.interfaceName,
             config.singleValue("ssid").stringValue,
             config.singleValue("freq").intValue)

method configureInterface*(self: WirelessPlugin, parentIface: ManagedInterface, parentConfig: Suite) =
  let interfaces = self.getPlugin(LinkManager).listLivingInterfaces()

  for p in self.gatherSubinterfacesWithConfigs(parentConfig, parentIface.abstractName, publicIfaces=false):
    let (iface, config) = p
    let kind = self.interfaceTypes[iface.abstractName]

    let existingIface = findLivingInterface(interfaces, iface.abstractName)

    # TODO: handle renames of `default`
    if iface.isSynthetic:
      if existingIface.isSome:
        applyRename(existingIface.get, iface.interfaceName)
      else:
        iwInterfaceAdd(parentIface.interfaceName, iface.interfaceName)

    writeAliasProperties(iface.interfaceName, makeAliasProperties(isSynthetic=iface.isSynthetic, abstractName=iface.abstractName))

    if iface.abstractName notin self.previousInterfaceTypes or kind != self.previousInterfaceTypes[iface.abstractName] or not existingIface.isSome:
      ipLinkDown(iface.interfaceName)

      iwSetType(iface.interfaceName, toTable({
        WirelessType.adhoc: "ibss",
        WirelessType.ap: "__ap",
        WirelessType.mesh: "mp",
        WirelessType.station: "managed",
      })[kind])

    case kind:
      of WirelessType.adhoc:
        self.configureAdhoc(iface, config)
      of WirelessType.mesh:
        self.configureMesh(iface, config)
      of WirelessType.ap:
        self.configureAp(iface, config)
      of WirelessType.station:
        self.configureStation(iface, config)

    if kind != WirelessType.station:
      self.getPlugin(LinkManager).configureInterfaceAll(iface, config)

method afterSetupInterfaces*(self: WirelessPlugin) =
  self.previousInterfaceTypes = self.interfaceTypes
  self.interfaceTypes = newTable[string, WirelessType]()
  self.processManager.teardownNotPoked()

method configureInterfaceAdress*(self: WirelessPlugin, iface: ManagedInterface, config: Suite): bool =
  # if there are is `wireless_* default` section, pretend that the address is configured (as this section will care about it)
  for command in config.commands:
    if command.name in allWirelessCommands and command.args[0].stringValue == "default":
      return true

  return false
