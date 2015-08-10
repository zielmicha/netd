import posix, os

var CLONE_NEWNET {.importc, header:"<sched.h>".}: cint
var CLONE_NEWNS {.importc, header:"<sched.h>".}: cint
var O_CLOEXEC {.importc, header:"<sched.h>".}: cint
var MNT_DETACH {.importc, header:"<sys/mount.h>".}: cint
var MS_SLAVE {.importc, header:"<sys/mount.h>".}: culong
var MS_REC {.importc, header:"<sys/mount.h>".}: culong

proc setns(fd: cint, nstype: cint): cint {.importc, header:"<sched.h>".}
proc unshareC(flags: cint): cint {.importc: "unshare", header:"<sched.h>".}

proc mount(source: cstring, target: cstring, filesystemtype: cstring,
           mountflags: culong, data: pointer): cint {.importc, header:"<sys/mount.h>"}
proc umount2(target: cstring, flags: cint): cint {.importc, header:"<sys/mount.h>"}

proc readlink*(path: string): string =
  var buf: array[512, char]
  if readlink(path, buf, sizeof(buf)) < 0:
    raiseOSError(osLastError())
  return $buf

type NsType* = enum
  nsNet
  nsMnt

proc cloneConst(nsType: NsType): cint =
  case nsType
  of nsNet: return CLONE_NEWNET
  of nsMnt: return CLONE_NEWNS

proc name(nsType: NsType): string =
  case nsType
  of nsNet: return "net"
  of nsMnt: return "mnt"

proc saveNs*(nsType: NsType): cint =
  let fd = posix.open("/proc/self/ns/" & nsType.name, O_RDONLY or O_CLOEXEC)
  if fd < 0:
    raiseOSError(osLastError())
  return fd

proc restoreNs*(nsType: NsType, fd: cint) =
  if setns(fd, nsType.cloneConst) < 0:
    raiseOSError(osLastError())
  discard fd.close

proc unshare*(nsType: NsType) =
  if unshareC(nsType.cloneConst) < 0:
    raiseOSError(osLastError())

proc setNetNs*(targetName: string) =
  let netPath = "/var/run/netns/" & targetName
  let netns = posix.open(netPath, O_RDONLY or O_CLOEXEC);
  if netns < 0:
    raiseOSError(osLastError())

  if setns(netns, CLONE_NEWNET) < 0:
    raiseOSError(osLastError())

proc remountSys*() =
  # from iproute2
  # Don't let any mounts propagate back to the parent
  if mount("", "/", "none", MS_SLAVE or MS_REC, nil) != 0:
    raiseOSError(osLastError())
  # Mount a version of /sys that describes the network namespace
  if umount2("/sys", MNT_DETACH) < 0:
    raiseOSError(osLastError())
  if mount("none", "/sys", "sysfs", 0.culong, nil) < 0:
    raiseOSError(osLastError())
