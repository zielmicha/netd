import netd/core
import conf/ast
import commonnim, tables, options
import iproute

export iproute.InterfaceName

type
  ManagedInterface* = object
    abstractName*: string ## Abstract device name
    ## Stored in 'alias' as 'abstractName'.
    ## In form:
    ##   deviceName.subdevieName.subsubDeviceName
    ## For example:
    ##   eth0 - simple ethernet device
    ##   eth0.vlan100 - 802.1q
    ##   eth0.vlan5.vlan100 - 802.1ad (QinQ)
    ##   wlan0.vif-foobar - virtual AP named foobar

    kernelName*: string ## User device name (the one kernel uses)

    namespaceName*: NamespaceName ## Network namespace name

    isSynthetic*: bool ## Was it created by netd?
    ## Synthetic interfaces will be deleted when they are orophaned by their plugin.
    ## Stored in 'alias' as 'isSynthetic'

  LinkManager* = ref object of Plugin
    managedDevices: seq[ManagedInterface]
    livingInterfacesCache: seq[LivingInterface]

  LivingInterface* = ManagedInterface

proc create*(t: typedesc[LinkManager], manager: NetworkManager): LinkManager =
  new(result)
  result.manager = manager

# Callbacks

method gatherInterfaces*(plugin: Plugin): seq[ManagedInterface] {.base.} =
  ## Plugin should read configuration and return `ManagedInterface`s
  ## for all network interfaces that would be created from that
  ## configuration.
  ##
  ## All synethetic devices that are not returned by some plugin
  ## will be deleted.
  @[]

method setupInterfaces*(plugin: Plugin) {.base.} =
  ## Here plugin should configure and (if neccessary) create
  ## devices it promised to create in gatherInterfaces.

method beforeSetupInterfaces*(plugin: Plugin) {.base.} =
  ## Called before all setupInterfaces

method afterSetupInterfaces*(plugin: Plugin) {.base.} =
  ## Called after all setupInterfaces

method gatherSubinterfaces*(plugin: Plugin, config: Suite, abstractParentName: string): seq[ManagedInterface] {.base.} =
  ## gatherInterfaces version for subinterfaces
  @[]

method configureInterface*(plugin: Plugin, iface: ManagedInterface, config: Suite) {.base.} =
  ## Configure misc and subinterfaces for given `ManagedInterface`

method cleanupInterface*(plugin: Plugin, iface: ManagedInterface, config: Suite) {.base.} =
  ## Perform potential cleanup actions on given interface.

# Gathered for all plugins:

proc gatherSubinterfacesAll*(self: LinkManager, config: Suite, abstractParentName: string): seq[ManagedInterface] =
  result = @[]
  for plugin in self.manager.iterPlugins:
    result &= plugin.gatherSubinterfaces(config, abstractParentName)

proc configureInterfaceAll*(self: LinkManager, iface: ManagedInterface, config: Suite) =
  for plugin in self.manager.iterPlugins:
    plugin.configureInterface(iface, config)

proc cleanupInterfaceAll*(self: LinkManager, iface: ManagedInterface, config: Suite) =
  for plugin in self.manager.iterPlugins:
    plugin.cleanupInterface(iface, config)

proc interfaceName*(iface: ManagedInterface): InterfaceName =
  (namespace: iface.namespaceName, name: iface.kernelName)

proc listLivingInterfaces*(self: LinkManager): seq[LivingInterface]
  ## Lists interfaces currently existing in the system

# Utilities for link types impl

proc isRootNamespace*(namespaceName: string): bool =
  namespaceName == nil or namespaceName == "root"

proc getRename*(identifier: string, suite: Suite): InterfaceName

proc applyRename*(interfaceName: InterfaceName, suite: Suite): InterfaceName
  ## Rename and move interface according to the suite.

proc applyRename*(interfaceName: InterfaceName, target: InterfaceName)

proc findLivingInterface*(interfaces: seq[LivingInterface], abstractName: string): Option[InterfaceName]

proc writeAliasProperties*(ifaceName: InterfaceName, prop: Table[string, string])

proc makeAliasProperties*(isSynthetic: bool, abstractName: string): Table[string, string] =
  {"isSynthetic": $isSynthetic, "abstractName": abstractName}.toTable

type
  ManagedInterfaceWithConfig* = tuple[iface: ManagedInterface, config: Suite]
  ManagedInterfaceWithConfigSeq* = seq[ManagedInterfaceWithConfig]

proc gatherInterfacesRecursive*(self: LinkManager, ifaces: ManagedInterfaceWithConfigSeq): seq[ManagedInterface] =
  result = @[]
  for v in ifaces:
    let (iface, config) = v
    result.add iface
    result &= self.gatherSubinterfacesAll(config, iface.abstractName)

proc makeDefaultLinkConfig*(topCommand: Command): ManagedInterfaceWithConfig =
  let (matcherVal, bodyVal) = unpackSeq2(topCommand.args)
  let ident = matcherVal.stringValue
  let body = bodyVal.suite

  let newName = getRename(ident, body)
  let managedInterface = ManagedInterface(
    kernelName: newName.name,
    namespaceName: newName.namespace,
    isSynthetic: true,
    abstractName: ident
  )

  return (iface: managedInterface, config: body)

include netd/linkconfig
include netd/linkimpl
