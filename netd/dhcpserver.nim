import reactor/ipaddress
import netd/core, netd/processmanager, netd/iproute, netd/link
import conf/ast, securehash, os, strutils, collections, sequtils

include netd/dhcpserverconfig

type DhcpServerPlugin* = ref object of Plugin
  processManager: ProcessManager

proc create*(t: typedesc[DhcpServerPlugin], manager: NetworkManager): DhcpServerPlugin =
  new(result)
  result.manager = manager
  result.processManager = newProcessManager()

method configureInterfaceAdress*(self: DhcpServerPlugin, iface: ManagedInterface, config: Suite): bool =
  let dhcpConfigCmd = config.singleCommand("dhcp_server", required=false)

  if dhcpConfigCmd == nil:
    return false

  let dhcpConfig = dhcpConfigCmd.args[0].suite

  ipLinkUp(iface.interfaceName)

  var config = ""
  config &= "interface " & iface.kernelName & "\n"
  config &= "lease_file " & RunPath / ("udhcpd-leases-" & iface.abstractName) & "\n"

  let addresses = dhcpConfig.singleCommand("addresses")
  config &= "start " & addresses.args[0].stringValue & "\n"
  config &= "end " & addresses.args[1].stringValue & "\n"

  let nameservers = toSeq(dhcpConfig.commandsWithName("nameserver")).map(cmd => cmd.args[0].stringValue)
  if nameservers.len != 0:
    config &= "opt dns " & nameservers.join(" ") & "\n"

  for lease in dhcpConfig.commandsWithName("lease"):
    config &= "static_lease " & lease.args[0].stringValue & " " & lease.args[1].stringValue & "\n"

  let router = dhcpConfig.singleCommand("router", required=false)
  if router != nil:
    config &= "opt router " & router.args[0].stringValue & "\n"

  # TODO: infer subnet
  let subnet = dhcpConfig.singleCommand("subnet", required=true)
  let subnetAddr = makeMaskAddress4(subnet.args[0].stringValue.parseInt)
  config &= "opt subnet " & ($subnetAddr) & "\n"

  let configPath = RunPath / ("udhcpd-" & iface.abstractName & ".conf")
  writeFile(configPath, config)
  self.processManager.pokeProcess(key=iface.abstractName,
                                  cmd= @["busybox", "udhcpd", "-f", configPath],
                                  namespace=iface.namespaceName,
                                  usertag= $secureHash(config))

  return false

method afterSetupInterfaces*(self: DhcpServerPlugin) =
  self.processManager.teardownNotPoked()

method exit*(self: DhcpServerPlugin) =
  self.processManager.exit()
