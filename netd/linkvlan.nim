import conf/ast, netd/core, netd/link, netd/iproute
import strutils, options, collections/random
include netd/linkvlanconfig

type
 LinkVlanPlugin* = ref object of Plugin

proc create*(t: typedesc[LinkVlanPlugin], manager: NetworkManager): LinkVlanPlugin =
  new(result)
  result.manager = manager

proc gatherSubinterfacesWithConfigs*(self: LinkVlanPlugin, config: Suite, abstractParentName: string): ManagedInterfaceWithConfigSeq =
  result = @[]

  for command in config.commands:
    if command.name == "vlan":
      let num = command.args[0].intValue
      let subconfig = command.args[1].suite

      var iface = ManagedInterface(
        abstractName: abstractParentName & ".vlan-" & ($num),
        isSynthetic: true,
      )

      let newName = getRename(iface.abstractName, subconfig)
      iface.kernelName = newName.name
      iface.namespaceName = newName.namespace

      result.add((iface, subconfig))

method gatherSubinterfaces*(self: LinkVlanPlugin, config: Suite, abstractParentName: string): seq[ManagedInterface] =
  self.getPlugin(LinkManager).gatherInterfacesRecursive(self.gatherSubinterfacesWithConfigs(config, abstractParentName))

method configureInterface*(self: LinkVlanPlugin, parentIface: ManagedInterface, parentConfig: Suite) =
  let interfaces = self.getPlugin(LinkManager).listLivingInterfaces()

  for p in self.gatherSubinterfacesWithConfigs(parentConfig, parentIface.abstractName):
    let (iface, config) = p
    let existingIface = findLivingInterface(interfaces, iface.abstractName)
    let num = iface.abstractName.split("-")[^1] # ...

    if existingIface.isSome:
      applyRename(existingIface.get, iface.interfaceName)
    else:
      let tmpName: InterfaceName = (parentIface.namespaceName, "vlan" & hexUrandom(4))
      ipLinkAddVlan(tmpName, "vlan", id=num, parent=parentIface.kernelName)
      applyRename(tmpName, iface.interfaceName)

    writeAliasProperties(iface.interfaceName, makeAliasProperties(isSynthetic=iface.isSynthetic, abstractName=iface.abstractName))

    self.getPlugin(LinkManager).configureInterfaceAll(iface, config)
