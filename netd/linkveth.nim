import netd/core, netd/link, netd/iproute
import conf/ast
import options, commonnim

type
  LinkVethPlugin* = ref object of Plugin

proc create*(t: typedesc[LinkVethPlugin], manager: NetworkManager): LinkVethPlugin =
  new(result)
  result.manager = manager

type
  Veth = tuple[sides: seq[ManagedInterface], config: seq[Suite]]

proc gatherInterfacesWithConfigs(self: LinkVethPlugin): seq[Veth] =
  result = @[]

  let configRoot = self.manager.config
  for topCommand in configRoot.commandsWithName("veth"):
    let (matcherVal, bodyVal) = unpackSeq2(topCommand.args)
    let topIdent = matcherVal.stringValue
    let topBody = bodyVal.suite
    var sides: seq[ManagedInterface] = @[]
    var confs: seq[Suite] = @[]

    for side in ["left", "right"]:
      let body = topBody.singleCommand(side).args.unpackSeq1.suite
      let ident = topIdent & "." & side

      let newName = getRename(ident, body)
      let managedInterface = ManagedInterface(
        kernelName: newName.name,
        namespaceName: newName.namespace,
        isSynthetic: true,
        abstractName: ident
      )
      confs.add body
      sides.add managedInterface

    result.add((sides: sides, config: confs))

method gatherInterfaces*(self: LinkVethPlugin): seq[ManagedInterface] =
  result = @[]
  for v in self.gatherInterfacesWithConfigs():
    let (sides, config) = v
    for i in 0..1:
      result.add sides[i]
      result &= self.getPlugin(LinkManager).gatherSubinterfacesAll(config[i], sides[i].abstractName)

method setupInterfaces*(self: LinkVethPlugin) =
  let interfaces = self.getPlugin(LinkManager).listLivingInterfaces()

  for v in self.gatherInterfacesWithConfigs():
    let (sides, config) = v

    let livingSides = [0, 1].map(proc(i: int): auto =
      findLivingInterface(interfaces, sides[i].abstractName))

    let leftInterfaceName = sides[0].interfaceName
    let rightInterfaceName = sides[1].interfaceName

    # TODO: what if only one side exists?

    if not (livingSides[0].isSome and livingSides[1].isSome):
      # somehow only one side is detected, delete itx
      if livingSides[0].isSome or livingSides[1].isSome:
        let aliveSide = if livingSides[0].isSome: livingSides[0].get else: livingSides[1].get
        echo "only one side of veth detected: " & aliveSide.name
        ipLinkDel(aliveSide)

      let rightTmpName = "veth" & hexUrandom(4)
      ipLinkAddVeth(leftInterfaceName.namespace, leftInterfaceName.name, rightTmpName)
      writeAliasProperties(leftInterfaceName, makeAliasProperties(isSynthetic=true, abstractName=sides[0].abstractName))
      applyRename((namespace: leftInterfaceName.namespace, name: rightTmpName),
                  rightInterfaceName)
    else:
      applyRename(livingSides[0].get, leftInterfaceName)
      writeAliasProperties(leftInterfaceName, makeAliasProperties(isSynthetic=true, abstractName=sides[0].abstractName))
      applyRename(livingSides[1].get, rightInterfaceName)

    writeAliasProperties(rightInterfaceName, makeAliasProperties(isSynthetic=true, abstractName=sides[1].abstractName))

    for i in [0, 1]:
      self.getPlugin(LinkManager).configureInterfaceAll(sides[i], config[i])
