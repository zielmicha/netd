import collections, morelinux, posix, os

const AF_NETLINK = 16

const
  NETLINK_ROUTE = 0
  NETLINK_NFLOG = 5
  NETLINK_NETFILTER = 12

type
  nlmsghdr = object
    len: uint32
    kind: uint16
    flags: uint16
    seqNum: uint32
    pid: uint32

  ifinfomsg = object
    family: uint8
    pad: uint8
    kind: uint16
    index: int32
    flags: uint32
    change: uint32

  rtattr_hdr = object
    len: uint16
    kind: uint16

  sockaddr_nl = object
    nl_family: uint16
    nl_pad: uint16
    nl_pid: uint32
    nl_groups: uint32

const
  RTM_BASE = 16
  RTM_NEWLINK = 16
  RTM_DELLINK = 17
  RTM_GETLINK = 18
  RTM_SETLINK = 19
  RTM_NEWADDR = 20
  RTM_DELADDR = 21
  RTM_GETADDR = 22
  RTM_NEWROUTE = 24
  RTM_DELROUTE = 25
  RTM_GETROUTE = 26
  RTM_NEWNEIGH = 28
  RTM_DELNEIGH = 29
  RTM_GETNEIGH = 30
  RTM_NEWRULE = 32
  RTM_DELRULE = 33
  RTM_GETRULE = 34
  RTM_NEWQDISC = 36
  RTM_DELQDISC = 37
  RTM_GETQDISC = 38
  RTM_NEWTCLASS = 40
  RTM_DELTCLASS = 41
  RTM_GETTCLASS = 42
  RTM_NEWTFILTER = 44
  RTM_DELTFILTER = 45
  RTM_GETTFILTER = 46
  RTM_NEWACTION = 48
  RTM_DELACTION = 49
  RTM_GETACTION = 50
  RTM_NEWPREFIX = 52
  RTM_GETMULTICAST = 58
  RTM_GETANYCAST = 62
  RTM_NEWNEIGHTBL = 64
  RTM_GETNEIGHTBL = 66
  RTM_SETNEIGHTBL = 67
  RTM_NEWNDUSEROPT = 68
  RTM_NEWADDRLABEL = 72
  RTM_DELADDRLABEL = 73
  RTM_GETADDRLABEL = 74
  RTM_GETDCB = 78
  RTM_SETDCB = 79
  RTM_NEWNETCONF = 80
  RTM_GETNETCONF = 82
  RTM_NEWMDB = 84
  RTM_DELMDB = 85
  RTM_GETMDB = 86
  RTM_NEWNSID = 88
  RTM_DELNSID = 89
  RTM_GETNSID = 90

const
  IFLA_UNSPEC = 0
  IFLA_ADDRESS = 1
  IFLA_BROADCAST = 2
  IFLA_IFNAME = 3
  IFLA_MTU = 4
  IFLA_LINK = 5
  IFLA_QDISC = 6
  IFLA_STATS = 7
  IFLA_COST = 8
  IFLA_PRIORITY = 9
  IFLA_MASTER = 10
  IFLA_WIRELESS = 11
  IFLA_PROTINFO = 12
  IFLA_TXQLEN = 13
  IFLA_MAP = 14
  IFLA_WEIGHT = 15
  IFLA_OPERSTATE = 16
  IFLA_LINKMODE = 17
  IFLA_LINKINFO = 18
  IFLA_NET_NS_PID = 19
  IFLA_IFALIAS = 20
  IFLA_NUM_VF = 21
  IFLA_VFINFO_LIST = 22
  IFLA_STATS64 = 23
  IFLA_VF_PORTS = 24
  IFLA_PORT_SELF = 25
  IFLA_AF_SPEC = 26
  IFLA_GROUP = 27
  IFLA_NET_NS_FD = 28
  IFLA_EXT_MASK = 29
  IFLA_PROMISCUITY = 30
  IFLA_NUM_TX_QUEUES = 31
  IFLA_NUM_RX_QUEUES = 32
  IFLA_CARRIER = 33
  IFLA_PHYS_PORT_ID = 34
  IFLA_CARRIER_CHANGES = 35
  IFLA_PHYS_SWITCH_ID = 36
  IFLA_LINK_NETNSID = 37
  IFLA_PHYS_PORT_NAME = 38
  IFLA_PROTO_DOWN = 39

const
  IFLA_INFO_UNSPEC = 0
  IFLA_INFO_KIND = 1
  IFLA_INFO_DATA = 2
  IFLA_INFO_XSTATS = 3
  IFLA_INFO_SLAVE_KIND = 4
  IFLA_INFO_SLAVE_DATA = 5
  IFLA_INFO_MAX = 6

const
  NLM_F_REQUEST = 1
  NLM_F_ACK = 4
  NLM_F_MATCH = 0x200
  NLM_F_ROOT = 0x100

const
  NLMSG_NOOP = 1
  NLMSG_ERROR = 2
  NLMSG_DONE = 3
  NLMSG_OVERRUN = 4

const RTA_ALIGNTO = 4

proc rtaAlign(len: int): int =
  return (len + RTA_ALIGNTO - 1) and (not (RTA_ALIGNTO - 1))

proc unpackRtAttrs(data: string): seq[RtAttr] =
  result = @[]
  var i = 0
  while i < data.len:
    let hdr = unpackStruct(data[i..<i+sizeof(rtattr_hdr)], rtattr_hdr)
    result.add(RtAttr(kind: hdr.kind, data: data[i+4..<i+hdr.len.int]))
    i += rtaAlign(hdr.len.int)

proc readResponse(sock: SocketHandle, bulk=false): seq[string] =
  var buffer = newString(4096)
  result = @[]
  var stop = false

  while not stop:
    let v = recv(sock, addr buffer[0], buffer.len, 0)
    if v < 0:
      raiseOSError(osLastError())

    var i = 0
    while i + sizeof(nlmsghdr) <= v:
      let response = unpackStruct(buffer[i..<i+sizeof(nlmsghdr)], nlmsghdr)

      if response.kind == NLMSG_ERROR:
        raise newException(ValueError, "Netlink returned error")

      if response.kind == NLMSG_DONE:
        stop = true
        break

      result.add(buffer[i + sizeof(nlmsghdr)..<(i + response.len.int - sizeof(nlmsghdr))])
      i += rtaAlign(response.len.int)

      if not bulk:
        stop = true
        break

proc makeMessage(kind: uint16, bulk: bool, body: string): string =
  var hdr: nlmsghdr
  hdr.len = sizeof(ifinfomsg).uint32 + body.len.uint32
  hdr.kind = kind
  if bulk:
    hdr.flags = NLM_F_MATCH or NLM_F_ROOT or NLM_F_REQUEST
  else:
    hdr.flags = NLM_F_REQUEST
  hdr.seqNum = 0
  hdr.pid = 0

  return packStruct(hdr) & body

proc sendMessage(kind: cint, msg: string): SocketHandle =
  let sock = socket(AF_NETLINK, SOCK_DGRAM, kind)
  if sock.int < 0:
    raiseOSError(osLastError())

  var address = sockaddr_nl(nl_family: AF_NETLINK, nl_pid: getpid().uint32, nl_groups: 0)
  if bindSocket(sock, cast[ptr SockAddr](addr address), Socklen(sizeof address)) < 0:
    discard close(sock)
    raiseOSError(osLastError())

  if send(sock, unsafeAddr msg[0], msg.len, 0) < 0:
    discard close(sock)
    raiseOSError(osLastError())

  return sock
