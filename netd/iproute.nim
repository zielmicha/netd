# iproute2 cheatsheet: http://baturin.org/docs/iproute2
# netlink overview: http://1984.lsi.us.es/~pablo/docs/spae.pdf
import os, osproc, tables, strutils, posix, morelinux
import subprocess, commonnim
import netd/netlink

type
  NamespaceName* = string
  ## Location of a kernel interface.
  InterfaceName* = tuple[namespace: NamespaceName, name: string]

type NsRestoreData = tuple[mntFd: cint, netFd: cint, path: string]

const RootNamespace*: NamespaceName = "root"

proc nsNilToRoot*(name: string): NamespaceName =
  if name == nil:
    return RootNamespace
  else:
    return name

proc saveNamespace(): NsRestoreData =
  result.mntFd = saveNs(nsMnt)
  result.netFd = saveNs(nsNet)
  result.path = getCurrentDir()

proc enterNamespace(namespaceName: NamespaceName) =
  setNetNs(namespaceName)
  unshare(nsMnt)

proc restoreNamespace(data: NsRestoreData) =
  restoreNs(nsNet, data.netFd)
  restoreNs(nsMnt, data.mntFd)
  discard close(data.netFd)
  discard close(data.mntFd)
  setCurrentDir(data.path)

var currentNs {.threadvar.}: string

template inNamespace*(namespaceName: NamespaceName, body: stmt): stmt {.immediate.} =
  if currentNs == nil:
    currentNs = "root"

  let doEnter: bool = namespaceName != currentNs
  let prevNs = currentNs
  var restoreData: NsRestoreData
  if doEnter:
    restoreData = saveNamespace()

  try:
    if doEnter:
      currentNs = namespaceName
      enterNamespace(namespaceName)
    body
  finally:
    if doEnter:
      currentNs = prevNs
      restoreNamespace(restoreData)

proc listKernelInterfacesInNs*(namespaceName: NamespaceName): seq[InterfaceName] =
  result = @[]
  inNamespace namespaceName:
    for iface in getLinks():
      result.add((namespaceName, iface.name))

proc getLinkAlias*(name: InterfaceName): string =
  inNamespace name.namespace:
    return getLink(name.name).alias

proc listNamespaces*(): seq[NamespaceName] =
  var rootStat: Stat
  if lstat("/var/run/netns", rootStat) != 0:
    return

  result = @[]

  for kind, path in walkDir("/var/run/netns"):
    var myStat: Stat
    if lstat(path, myStat) != 0:
      continue
    if myStat.st_dev == rootStat.st_dev:
      # not mounted, not a valid namespace
      continue
    let name = path.splitPath().tail
    if name != nil:
      result.add name
    else:
      assert false

iterator listKernelInterfaces*(): InterfaceName =
  # TODO: also walk other namespaces
  for namespace in listNamespaces():
    for iface in listKernelInterfacesInNs(namespace):
      yield iface

proc sanitizeIfaceName(name: string): string =
  if name == nil:
    raise newException(ValueError, "nil")
  if "/" in name:
    raise newException(ValueError, "invalid argument %1" % [$name])
  return name

proc getMasterName*(interfaceName: InterfaceName): string =
  inNamespace interfaceName.namespace:
    let basePath = "/sys/class/net/" & sanitizeIfaceName(interfaceName.name) & "/brport"

    if not basePath.dirExists:
      return nil

    let brpath = readlink(basePath & "/bridge")
    return brpath.splitPath().tail

proc linkExists*(interfaceName: InterfaceName): bool =
  inNamespace interfaceName.namespace:
    for link in getLinks():
      if link.name == interfaceName.name:
        return true
    return false

proc getNlLink*(interfaceName: InterfaceName): NlLink =
  inNamespace interfaceName.namespace:
    return getLink(interfaceName.name)

proc callIp*(namespaceName: NamespaceName, args: openarray[string]) =
  inNamespace namespaceName:
    stdout.write "($1) " % namespaceName
    checkCall(args, echo=true)

proc sanitizeArg(val: string): string =
  if val == nil:
    raise newException(ValueError, "nil passed to iproute2 call")
  if val.startsWith("-"):
    raise newException(ValueError, "invalid argument %1" % [$val])
  val

proc namespaceName(name: string): string =
  if name == nil:
    return "root"
  else:
    return name

# Direct

proc ipLinkDel*(ifaceName: InterfaceName) =
  callIp(ifaceName.namespace, ["ip", "link", "del", "dev", sanitizeArg(ifaceName.name)])

proc ipLinkSet*(ifaceName: InterfaceName, attrs: Table[string, string]) =
  var cmd = @["ip", "link", "set", "dev", sanitizeArg(ifaceName.name)]
  for k, v in attrs:
    cmd.add(k)
    if v != nil:
      cmd.add(sanitizeArg(v))
  callIp(ifaceName.namespace, cmd)

proc ipLinkSet*(ifaceName: InterfaceName, attrs: openarray[(string, string)]) =
  ipLinkSet(ifaceName, attrs.toTable)

proc ipLinkUp*(ifaceName: InterfaceName) =
  callIp(ifaceName.namespace, ["ip", "link", "set", "dev", sanitizeArg(ifaceName.name), "up"])

proc ipLinkDown*(ifaceName: InterfaceName) =
  callIp(ifaceName.namespace, ["ip", "link", "set", "dev", sanitizeArg(ifaceName.name), "down"])

proc ipLinkAdd*(ifaceName: InterfaceName, typ: string, args: openarray[string] = @[]) =
  callIp(ifaceName.namespace, @["ip", "link", "add", "dev", sanitizeArg(ifaceName.name), "type", typ] & @args)

proc ipLinkAddVlan*(ifaceName: InterfaceName, typ: string, id: string, parent: string) =
  callIp(ifaceName.namespace, @["ip", "link", "add", "dev", sanitizeArg(ifaceName.name), "link", parent, "type", typ, "id", id])

proc ipLinkAddVeth*(namespaceName: NamespaceName, leftName: string, rightName: string) =
  callIp(namespaceName, ["ip", "link", "add", "dev", sanitizeArg(leftName), "type", "veth", "peer", "name", rightName])

proc ipAddrFlush*(ifaceName: InterfaceName) =
  callIp(ifaceName.namespace, ["ip", "addr", "flush", "dev", sanitizeArg(ifaceName.name)])

proc ipAddrAdd*(ifaceName: InterfaceName, address: string, peerAddress: string = nil) =
  var cmd = @["ip", "addr", "add", "dev", sanitizeArg(ifaceName.name), sanitizeArg(address)]
  if peerAddress != nil:
    cmd &= @["peer", sanitizeArg(peerAddress)]
  callIp(ifaceName.namespace, cmd)

proc ipRouteAddDefault*(namespace: NamespaceName, via: string) =
  # FIXME: what about namespace?
  callIp(namespace, ["ip", "route", "add", "default", "via", sanitizeArg(via)])

proc ipNetnsCreate*(name: string) =
  callIp(RootNamespace, ["ip", "netns", "add", sanitizeArg(name)])

proc ipTunTapAdd*(ifaceName: InterfaceName, mode="tun") =
  callIp(ifaceName.namespace, ["ip", "tuntap", "add", "dev", sanitizeArg(ifaceName.name), "mode", sanitizeArg(mode)])

proc iwLinkDel*(ifaceName: InterfaceName) =
  callIp(ifaceName.namespace, ["iw", "dev", sanitizeArg(ifaceName.name), "del"])

proc iwInterfaceAdd*(ifaceName: InterfaceName, target: InterfaceName) =
  callIp(ifaceName.namespace, ["iw", "dev", sanitizeArg(ifaceName.name), "interface", "add", target.name, "type", "ibss"])

proc iwSetType*(ifaceName: InterfaceName, kind: string) =
  callIp(ifaceName.namespace, ["iw", "dev", sanitizeArg(ifaceName.name), "set", "type", sanitizeArg(kind)])

proc iwIbssJoin*(ifaceName: InterfaceName, ssid: string, freq: int) =
  callIp(ifaceName.namespace, ["iw", "dev", sanitizeArg(ifaceName.name), "ibss", "join", sanitizeArg(ssid), $freq])

proc iwIbssLeave*(ifaceName: InterfaceName) =
  callIp(ifaceName.namespace, ["iw", "dev", sanitizeArg(ifaceName.name), "ibss", "leave"])

proc iwMeshJoin*(ifaceName: InterfaceName, ssid: string, freq: int) =
  callIp(ifaceName.namespace, ["iw", "dev", sanitizeArg(ifaceName.name), "mesh", "join", sanitizeArg(ssid), "freq", $freq])

proc iwMeshLeave*(ifaceName: InterfaceName) =
  callIp(ifaceName.namespace, ["iw", "dev", sanitizeArg(ifaceName.name), "mesh", "leave"])

proc createRootNamespace*() =
  let nsFile = "/var/run/netns/root"
  writeFile(nsFile, "")
  checkCall(["mount", "--bind", "/proc/self/ns/net", nsFile], echo=true)

# "High-level"

proc rename*(ifaceName: InterfaceName, name: string, namespace: string) =
  var attrs = initTable[string, string]()
  if name != nil:
    attrs["name"] = name

  attrs["netns"] = namespaceName(namespace)

  ipLinkSet(ifaceName, attrs)
