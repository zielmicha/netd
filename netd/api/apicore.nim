import dbus, tables
type NetNetworkosNetdCoreRemote* = object of DbusIfaceWrapper

proc get*(wrapperType: typedesc[NetNetworkosNetdCoreRemote], uniqueBus: UniqueBus, path: ObjectPath): NetNetworkosNetdCoreRemote =
  result.uniqueBus = uniqueBus
  result.path = path


proc LoadConfigAsync*(dbusIface: NetNetworkosNetdCoreRemote, config: string): PendingCall =
  let msg = makeCall(dbusIface.uniqueBus.uniqueName, dbusIface.path, "net.networkos.netd.Core", "LoadConfig")
  msg.append(config)
  return dbusIface.uniqueBus.bus.sendMessageWithReply(msg)

proc LoadConfigGetReply*(reply: Reply): void =
  reply.raiseIfError

proc LoadConfig*(dbusIface: NetNetworkosNetdCoreRemote, config: string): void =
  let reply = LoadConfigAsync(dbusIface, config).waitForReply()
  defer: reply.close()
  LoadConfigGetReply(reply)


proc ReloadAsync*(dbusIface: NetNetworkosNetdCoreRemote): PendingCall =
  let msg = makeCall(dbusIface.uniqueBus.uniqueName, dbusIface.path, "net.networkos.netd.Core", "Reload")
  return dbusIface.uniqueBus.bus.sendMessageWithReply(msg)

proc ReloadGetReply*(reply: Reply): void =
  reply.raiseIfError

proc Reload*(dbusIface: NetNetworkosNetdCoreRemote): void =
  let reply = ReloadAsync(dbusIface, ).waitForReply()
  defer: reply.close()
  ReloadGetReply(reply)


proc ExitAsync*(dbusIface: NetNetworkosNetdCoreRemote): PendingCall =
  let msg = makeCall(dbusIface.uniqueBus.uniqueName, dbusIface.path, "net.networkos.netd.Core", "Exit")
  return dbusIface.uniqueBus.bus.sendMessageWithReply(msg)

proc ExitGetReply*(reply: Reply): void =
  reply.raiseIfError

proc Exit*(dbusIface: NetNetworkosNetdCoreRemote): void =
  let reply = ExitAsync(dbusIface, ).waitForReply()
  defer: reply.close()
  ExitGetReply(reply)

