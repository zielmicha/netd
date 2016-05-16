import netd/core, netd/link, netd/iproute
import conf/ast
import commonnim, options, tables, strutils, sequtils, future

type
  LinkBridgePlugin* = ref object of Plugin

include netd/linkbridgeconfig

proc create*(t: typedesc[LinkBridgePlugin], manager: NetworkManager): LinkBridgePlugin =
  new(result)
  result.manager = manager

proc gatherInterfacesWithConfigs(self: LinkBridgePlugin): ManagedInterfaceWithConfigSeq =
  result = @[]

  let configRoot = self.manager.config
  for topCommand in configRoot.commandsWithName("bridge"):
    result.add(makeDefaultLinkConfig(topCommand))

method gatherInterfaces*(self: LinkBridgePlugin): seq[ManagedInterface] =
  self.getPlugin(LinkManager).gatherInterfacesRecursive(self.gatherInterfacesWithConfigs)

proc getPorts(config: Suite): seq[string] =
  let portsCmd = config.singleCommand("ports", required=false)
  return portsCmd.args.map(a => a.stringValue)

method beforeSetupInterfaces*(self: LinkBridgePlugin) =
  for v in self.gatherInterfacesWithConfigs():
    let (iface, config) = v

    let ports = config.getPorts

    for potentialPort in listKernelInterfacesInNs(iface.namespaceName):
      let isCurrentlyPort = potentialPort.getMasterName() == iface.kernelName
      let shouldBePort = potentialPort.name in ports # TODO: handle abstract names
      if isCurrentlyPort and not shouldBePort:
        ipLinkSet(potentialPort, {"nomaster": nil.string})

method setupInterfaces*(self: LinkBridgePlugin) =
  let interfaces = self.getPlugin(LinkManager).listLivingInterfaces()

  for v in self.gatherInterfacesWithConfigs():
    let (iface, config) = v

    let interfaceName = iface.interfaceName
    let existing = interfaces.findLivingInterface(iface.abstractName)
    if existing.isNone:
      ipLinkAdd(interfaceName, "bridge")
    else:
      applyRename(existing.get, interfaceName)

    writeAliasProperties(interfaceName,
                         makeAliasProperties(isSynthetic=true, abstractName=iface.abstractName))

    self.getPlugin(LinkManager).configureInterfaceAll(iface, config)

method afterSetupInterfaces*(self: LinkBridgePlugin) =
  let interfaces = self.getPlugin(LinkManager).listLivingInterfaces()

  for v in self.gatherInterfacesWithConfigs():
    let (iface, config) = v
    let bridgeName = iface.interfaceName

    for port in config.getPorts:
      let interfaceNameOpt = findLivingInterface(interfaces, port)
      # if port name is not found, assume that
      let interfaceName = if interfaceNameOpt.isNone: (namespace: RootNamespace, name: port)
                          else: interfaceNameOpt.get

      if interfaceName.namespace != interfaceName.namespace:
        raise newConfError(config, "can't bridge port $1 ($3) to bridge $2 ($4) - they are in different namespaces" % [
          port, iface.abstractName, $interfaceName, $bridgeName])
      ipLinkSet(interfaceName, {"master": bridgeName.name})
