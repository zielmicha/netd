import netd/core
import conf/ast
import commonnim
import iproute

export iproute.InterfaceName

type
  ManagedInterface* = object
    abstractName: string ## Abstract device name
    ## Stored in 'alias' as 'abstractName'.
    ## In form:
    ##   deviceName.subdevieName.subsubDeviceName
    ## For example:
    ##   eth0 - simple ethernet device
    ##   eth0.vlan100 - 802.1q
    ##   eth0.vlan5.vlan100 - 802.1ad (QinQ)
    ##   wlan0.vap-foobar - virtual AP named foobar

    userName: string ## User device name (the one kernel uses)

    namespaceName: string ## Network namespace name

    isSynthetic: bool ## Was it created by netd?
    ## Synthetic interfaces will be deleted when they are orophaned by their plugin.
    ## Stored in 'alias' as 'isSynthetic'

  LinkManager* = ref object of Plugin
    manager: NetworkManager
    managedDevices: seq[ManagedInterface]

proc create*(t: typedesc[LinkManager], manager: NetworkManager): LinkManager =
  new(result)
  result.manager = manager

method gatherInterfaces*(plugin: Plugin): seq[ManagedInterface] =
  ## Plugin should read configuration and return `ManagedInterface`s
  ## for all network interfaces that would be created from that
  ## configuration.
  ##
  ## All synethetic devices that are not returned by some plugin
  ## will be deleted.
  @[]

method setupInterfaces*(plugin: Plugin) =
  ## Here plugin should configure and (if neccessary) create
  ## devices it promised to create in gatherInterfaces.

method gatherSubinterfaces*(plugin: Plugin, config: Suite): seq[ManagedInterface] =
  ## gatherInterfaces version for subinterfaces
  @[]

method configureInterface*(plugin: Plugin, iface: ManagedInterface, config: Suite) =
  ## Configure IPs and subinterfaces for given `ManagedInterface`
  discard

# Gathered for all plugins:

proc gatherSubinterfacesAll*(self: LinkManager, config: Suite): seq[ManagedInterface] =
  result = @[]
  for plugin in self.manager.iterPlugins:
    result &= plugin.gatherSubinterfaces(config)

proc configureInterfaceAll*(self: LinkManager, iface: ManagedInterface, config: Suite) =
  for plugin in self.manager.iterPlugins:
    plugin.configureInterface(iface, config)

proc interfaceName*(iface: ManagedInterface): InterfaceName =
  (namespace: iface.namespaceName, name: iface.userName)

include netd/linkimpl
