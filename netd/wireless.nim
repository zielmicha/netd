import subprocess, conf/ast, strutils, collections/random, os, tables, securehash
import netd/core, netd/processmanager, netd/link, netd/addr, netd/iproute

include netd/wirelessconfig

type
  WirelessType {.pure.} = enum
    adhoc
    ap
    station
  
  WirelessPlugin* = ref object of Plugin
    processManager: ProcessManager
    # TODO: use netlink API to query type instead of saving
    interfaceTypes: TableRef[string, WirelessType]
    previousInterfaceTypes: TableRef[string, WirelessType]

const allWirelessCommands = @["wireless_ap", "wireless_station", "wireless_adhoc"]

proc create*(t: typedesc[WirelessPlugin], manager: NetworkManager): WirelessPlugin =
  new(result)
  result.manager = manager
  result.processManager = newProcessManager()
  result.interfaceTypes = newTable[string, WirelessType]()
  result.previousInterfaceTypes = newTable[string, WirelessType]()

proc gatherSubinterfacesWithConfigs*(self: WirelessPlugin, config: Suite, abstractParentName: string): ManagedInterfaceWithConfigSeq =
  result = @[]

  for command in config.commands:
    if command.name in allWirelessCommands:
      let name = command.args[0].stringValue
      let config = command.args[1].suite

      var iface = ManagedInterface()
      if name == "default":
        iface.abstractName = abstractParentName
        iface.isSynthetic = false
      else:
        iface.abstractName = abstractParentName & "." & name
        iface.isSynthetic = true

      self.interfaceTypes[iface.abstractName] = toTable({
        "wireless_adhoc": WirelessType.adhoc,
        "wireless_station": WirelessType.station,
        "wireless_ap": WirelessType.ap,
        })[command.name]

      let newName = getRename(iface.abstractName, config)
      # TODO: moving to NS requires use of `iw phy`
      iface.kernelName = newName.name
      iface.namespaceName = newName.namespace

      if name != "default":
        result.add((iface, config))

method gatherSubinterfaces*(self: WirelessPlugin, config: Suite, abstractParentName: string): seq[ManagedInterface] =
  result = @[]
  for p in self.gatherSubinterfacesWithConfigs(config, abstractParentName):
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

method configureInterface*(self: WirelessPlugin, parentIface: ManagedInterface, parentConfig: Suite) =
  for p in self.gatherSubinterfacesWithConfigs(parentConfig, parentIface.abstractName):
    let (iface, config) = p
    let kind = self.interfaceTypes[iface.abstractName]

    if iface.abstractName notin self.interfaceTypes or kind != self.interfaceTypes[iface.abstractName]:
      ipLinkDown(iface.interfaceName)

      case kind:
        of WirelessType.adhoc:
          iwSetType(iface.interfaceName, "ibss")
        of WirelessType.ap:
          iwSetType(iface.interfaceName, "__ap")
        of WirelessType.station:
          iwSetType(iface.interfaceName, "managed")

      ipLinkUp(iface.interfaceName)

    case kind:
      of WirelessType.adhoc:
        try: # TODO
          iwIbssLeave(iface.interfaceName)
        except:
          discard

        iwIbssJoin(iface.interfaceName,
                   config.singleValue("ssid").stringValue,
                   config.singleValue("freq").intValue)
      of WirelessType.ap:
        self.configureAp(iface, config)
      of WirelessType.station:
        discard

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
