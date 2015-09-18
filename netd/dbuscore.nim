import dbus
import netd/core

type
  DbusCorePlugin* = ref object of Plugin
    bus*: Bus

proc create*(t: typedesc[DbusCorePlugin], manager: NetworkManager): DbusCorePlugin =
  new(result)
  result.manager = manager


proc init*(plugin: DbusCorePlugin, bus: Bus) =
  bus.requestName("net.networkos.netd")

  # TODO
  proc callback(kind: IncomingMessageType, messsage: IncomingMessage): bool =
    echo kind, " ", messsage.name, " ", messsage.interfaceName
    return false

  bus.registerObject("/net/networkos/netd".ObjectPath, callback)
