import strutils, unsigned

type
  Interface*[T] = tuple[address: T, mask: int]

  Ip6Address* = distinct array[16, uint8]
  Ip6Interface* = Interface[Ip6Interface]

  Ip4Address* = distinct array[4, uint8]
  Ip4Interface* = Interface[Ip4Interface]

  IpKind* = enum
    ip4, ip6

  IpAddress* = object
    case kind*: IpKind
    of ip4:
      ip4*: Ip4Address
    of ip6:
      ip6*: Ip6Address

  IpInterface* = Interface[IpAddress]

proc `[]`*(a: Ip4Address, index: int): uint8 = array[4, uint8](a)[index]
proc `[]`*(a: Ip6Address, index: int): uint8 = array[16, uint8](a)[index]

proc `$`*(a: Ip4Address): string =
  "$1.$2.$3.$4" % [$a[0], $a[1], $a[2], $a[3]]

proc `$`*(a: Ip6Address): string =
  var s = ""
  for i in 0..15:
    s.add a[i].int.toHex(4)
    if i != 15: s.add ":"

proc `$`*(a: IpAddress): string =
  case a.kind:
  of ip4: return $a.ip4
  of ip6: return $a.ip6

proc `$`*[T](a: Interface[T]): string =
  "$1/$2" % [$a.address, $a.mask]

proc addressBitLength(kind: IpKind): int =
  case kind:
  of ip4: return 32
  of ip6: return 128

proc parseAddress4(a: string): Ip4Address =
  let parts = a.split(".").map(proc(a: string): uint8 = parseInt(a).uint8)
  if parts.len != 4:
    raise newException(ValueError, "invalid IP4 address")
  [parts[0], parts[1], parts[2], parts[3]].Ip4Address

proc parseAddress*(a: string): IpAddress =
  result.kind = ip4
  result.ip4 = parseAddress4(a)

proc parseInterface*(a: string): IpInterface =
  let splt = a.split("/")
  let address = splt[0].parseAddress
  var length: int
  if splt.len == 1:
    length = address.kind.addressBitLength
  elif splt.len == 2:
    length = parseInt(splt[1])
  else:
    raise newException(ValueError, "invalid interface address")

  if length < 0 or length > address.kind.addressBitLength:
    raise newException(ValueError, "invalid interface mask")

  return (address: address, mask: length)
