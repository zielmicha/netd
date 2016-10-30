import netd/core, netd/link, netd/iproute, netd/processmanager, netd/common
import conf/ast
import commonnim, strutils, options, os, morelinux, securehash

type
  ZeroTierPlugin* = ref object of Plugin
    processManager: ProcessManager

include netd/zerotierconfig

proc create*(t: typedesc[ZeroTierPlugin], manager: NetworkManager): ZeroTierPlugin =
  new(result)
  result.manager = manager
  result.processManager = newProcessManager()

proc getPublicFromSecret(key: string): string =
  return key.split(":")[0..2].join(":")

proc getIdentityFromSecret(key: string): string =
  return key.split(":")[0]

proc getIdentity(command: Command): string =
  let config = command.args[1].suite
  return getIdentityFromSecret(config.singleValue("secret").stringValue)

proc getHomePath(identity: string): string =
  return RunPath / ("zerotier-" & sanitizePathComponent(identity))

proc makeLinkConfig(identity: string, command: Command): ManagedInterfaceWithConfig =
  let id = command.args[0].stringValue
  let body = command.args[1].suite

  let abstractName = "zt." & identity & "." & id
  let newName = getRename(abstractName, body)
  let managedInterface = ManagedInterface(
    kernelName: newName.name,
    namespaceName: newName.namespace,
    isSynthetic: true,
    abstractName: abstractName
  )

  return (iface: managedInterface, config: body)

proc gatherInterfacesWithConfigs(self: ZeroTierPlugin): ManagedInterfaceWithConfigSeq =
  result = @[]
  let configRoot = self.manager.config

  for topCommand in configRoot.commandsWithName("zerotier"):
    let identity = getIdentity(topCommand)

    for command in topCommand.args[1].suite.commandsWithName("network"):
      result.add(makeLinkConfig(identity, command))

method gatherInterfaces*(self: ZeroTierPlugin): seq[ManagedInterface] =
  self.getPlugin(LinkManager).gatherInterfacesRecursive(self.gatherInterfacesWithConfigs)

proc createSymlinkIfNeeded(dest: string, src: string) =
  if not symlinkExists(dest):
    createSymlink(dest=dest, src=src)

proc setupInstance(self: ZeroTierPlugin, identity: string, config: Suite) =
  let secret = config.singleValue("secret").stringValue
  var namespace = config.singleValue("namespace").stringValue
  if namespace == nil: namespace = "root"
  var port = config.singleValue("port", required=false).stringValue
  if port == nil: port = "9993"

  let baseDir = getHomePath(identity)
  let cacheDir = CachePath / ("zerotier-" & sanitizePathComponent(identity))

  for dir in [baseDir, cacheDir, cacheDir / "iddb", cacheDir / "networks", baseDir / "networks"]:
    createDir(dir, 0o700)

  writeFile(baseDir / "identity.secret", secret)
  writeFile(baseDir / "identity.public", getPublicFromSecret(secret))
  createSymlinkIfNeeded(dest=baseDir / "iddb.d", src=cacheDir / "iddb")
  createSymlinkIfNeeded(dest=baseDir / "networks.d", src=cacheDir / "networks")

  var state: seq[string] = @[]
  var networkIds: seq[string] = @[]
  var deviceNames: seq[string] = @[]

  var i = 0
  for networkCmd in config.commandsWithName("network"):
    let id = sanitizePathComponent(networkCmd.args[0].stringValue)
    networkIds.add id
    let networkConfig = networkCmd.args[1].suite
    let allowManaged = networkConfig.singleCommand("managed", required=false) != nil
    let allowGlobal = networkConfig.singleCommand("global", required=false) != nil

    let localConfName = id & ".local.conf"
    createSymlinkIfNeeded(dest=cacheDir / "networks" / localConfName, src=baseDir / "networks" / localConfName)

    let localConf = ("allowManaged=" & $allowManaged & "\L" &
      "allowGlobal=" & $allowGlobal & "\L" &
      "allowDefault=" & $allowGlobal & "\L")
    state.add(id & "\L" & localConf)
    writeFile(baseDir / "networks" / localConfName, localConf)

    let confName = cacheDir / "networks" / (id & ".conf")
    if not fileExists(confName): writeFile(confName, "")

    deviceNames.add("zt." & identity & "." & ($i))
    i += 1

  var deviceMap = ""
  for i in 0..<deviceNames.len:
    deviceMap &= networkIds[i] & "=" & deviceNames[i] & "\L"
  writeFile(baseDir / "devicemap", deviceMap)

  for kind, path in walkDir(cacheDir / "networks"):
    if path.endsWith(".conf") and path.len == 21:
      let id = path.splitPath.tail[0..15]
      if id notin networkIds:
        removeFile(path)

  let started = self.processManager.pokeProcess(key=identity,
                                                cmd= @["zerotier-one", "-p" & port, baseDir],
                                                namespace=namespace,
                                                usertag= $secureHash($state))

  if started:
    for deviceName in deviceNames:
      waitForLink((namespace, deviceName))

    var i = 0
    for networkCmd in config.commandsWithName("network"):
      let id = networkIds[i]
      let oldName: InterfaceName = (namespace, deviceNames[i])
      let (iface, config) = makeLinkConfig(identity, networkCmd)
      ipLinkDown(oldName)
      applyRename(oldName, iface.interfaceName)

      self.getPlugin(LinkManager).configureInterfaceAll(iface, config)
      i += 1

method configureInterfaceAdress*(self: ZeroTierPlugin, iface: ManagedInterface, config: Suite): bool =
  # does ZT autoconfigure address on this interface?
  let managed = config.hasCommandWithName("managed") and iface.abstractName.startsWith("zt.")
  if managed:
    ipLinkUp(iface.interfaceName)
  return managed

method setupInterfaces*(self: ZeroTierPlugin) =
  let configRoot = self.manager.config

  for topCommand in configRoot.commandsWithName("zerotier"):
    let identity = getIdentity(topCommand)
    self.setupInstance(
      identity=identity,
      config=topCommand.args[1].suite
    )

method afterSetupInterfaces*(self: ZeroTierPlugin) =
  self.processManager.teardownNotPoked()

method exit*(self: ZeroTierPlugin) =
  self.processManager.exit()
