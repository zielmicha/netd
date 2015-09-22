import dbus, dbus/def
import netd/core

type
  DbusCorePlugin* = ref object of Plugin
    bus*: Bus
    netdObject*: DbusObjectImpl

proc create*(t: typedesc[DbusCorePlugin], manager: NetworkManager): DbusCorePlugin =
  new(result)
  result.manager = manager

proc Reload*(self: DbusCorePlugin) =
  self.manager.reload()

proc Exit*(self: DbusCorePlugin) =
  self.manager.exit()

let coreDef = newInterfaceDef(DbusCorePlugin)
coreDef.addMethod(Reload, [], [])
coreDef.addMethod(Exit, [], [])

method dbusInit*(plugin: Plugin) =
  nil

method dbusInit(self: DbusCorePlugin) =
  self.netdObject.addInterface("net.networkos.netd.Core", coreDef, self)

proc init*(self: DbusCorePlugin, bus: Bus) =
  self.bus = bus
  self.netdObject = newObjectImpl(bus)

  enableIntrospection(self.netdObject)

  bus.requestName("net.networkos.netd")
  bus.registerObject("/net/networkos/netd".ObjectPath, self.netdObject)

  for plugin in self.manager.iterPlugins:
    plugin.dbusInit
