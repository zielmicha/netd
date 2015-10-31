import netd/core, netd/link, netd/iproute, netd/processmanager
import conf/ast, commonnim, strutils, options

type
  OpenVpnPtpPlugin* = ref object of Plugin
    processManager: ProcessManager

include netd/openvpnptpconfig

proc create*(t: typedesc[OpenVpnPtpPlugin], manager: NetworkManager): OpenVpnPtpPlugin =
  new(result)
  result.manager = manager
  result.processManager = newProcessManager()

proc gatherInterfacesWithConfigs(self: OpenVpnPtpPlugin): ManagedInterfaceWithConfigSeq =
  result = @[]
  let configRoot = self.manager.config

  for topCommand in configRoot.commandsWithName("openvpn_ptp"):
    result.add(makeDefaultLinkConfig(topCommand))

method gatherInterfaces*(self: OpenVpnPtpPlugin): seq[ManagedInterface] =
  self.getPlugin(LinkManager).gatherInterfacesRecursive(self.gatherInterfacesWithConfigs)

proc setupInterface(self: OpenVpnPtpPlugin, iface: ManagedInterface, config: Suite) =
  let key = config.singleValue("key").stringValue # TODO: manage files with confd
  let listenCmd = config.singleCommand("listen", required=false)
  let connectCmd = config.singleCommand("connect", required=false)

  if listenCmd != nil and connectCmd != nil:
    raise newConfError(listenCmd, "both 'listen' and 'connect' directives found")

  if listenCmd == nil and connectCmd == nil:
    raise newConfError(config, "neither 'listen' nor 'connect' directives found")

  var cmd = @["openvpn", "--route-noexec", "--ifconfig-noexec"]

  cmd &= @["--secret", key] # TODO: changing key content won't cause reload
  cmd &= @["--dev-type", "tun"]
  cmd &= @["--dev", iface.kernelName]

  let isServer = listenCmd != nil

  # TODO: we should give an option to bind to IP of other interface

  let (protoS, hostS, portS) = (if isServer: listenCmd else: connectCmd).args.unpackSeq3
  let (proto, host, port) = (protoS.value.stringValue, hostS.value.stringValue, portS.value.stringValue)

  let isTcp = proto == "tcp"
  if not isTcp and proto != "udp":
    raise newConfError((if isServer: listenCmd else: connectCmd), "invalid protocol $1" % [proto])

  if isServer:
    cmd &= @["--proto", if isTcp: "tcp-server" else: "udp"]
    cmd &= @["--local", host]
    cmd &= @["--port", port]
  else:
    cmd &= @["--proto", if isTcp: "tcp-client" else: "udp"]
    cmd &= @["--remote", host, port]

  self.processManager.pokeProcess(key=iface.abstractName,
                                  cmd= cmd,
                                  env= {"abstractName": iface.abstractName},
                                  namespace=iface.namespaceName)


method setupInterfaces*(self: OpenVpnPtpPlugin) =
  let interfaces = self.getPlugin(LinkManager).listLivingInterfaces()

  for v in self.gatherInterfacesWithConfigs():
    let (iface, config) = v
    let existing = findLivingInterface(interfaces, iface.abstractName)
    if existing.isNone:
      ipTunTapAdd(iface.interfaceName)
    else:
      applyRename(existing.get, iface.interfaceName)

    writeAliasProperties(iface.interfaceName,
                         makeAliasProperties(isSynthetic=true, abstractName=iface.abstractName))

    self.setupInterface(iface, config)

    self.getPlugin(LinkManager).configureInterfaceAll(iface, config)
