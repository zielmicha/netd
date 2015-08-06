import netd/core
import conf/ast
import commonnim

type
  ManagedDevice* = object
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
    ## Synthetic devices will be deleted when they are orophaned by their plugin.
    ## Stored in 'alias' as 'isSynthetic'

  LinkManager* = ref object of Plugin
    manager: NetworkManager
    managedDevices: seq[ManagedDevice]

proc create*(t: typedesc[LinkManager], manager: NetworkManager): LinkManager =
  new(result)
  result.manager = manager

method gatherInterfaces*(plugin: Plugin): seq[ManagedDevice] =
  ## Plugin should read configuration and return `ManagedDevice`s
  ## for all network interfaces that would be created from that
  ## configuration.
  ##
  ## All synethetic devices that are not returned by some plugin
  ## will be deleted.
  @[]

method configureInterfaces*(plugin: Plugin) =
  ## Here plugin should configure and (if neccessary) create
  ## devices it promised to create in gatherInterfaces.

method gatherSubinterfaces*(manager: LinkManager, config: Suite): seq[ManagedDevice]

proc gatherAllSubinterfaces*(manager: LinkManager, config: Suite): seq[ManagedDevice] =
