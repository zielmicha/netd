# netd

netd is an advanced network manager for Linux desktops, servers and embedded systems.

It supports advanced configuration involving multiple interfaces, VPNs, network namespaces and much more. It currently is in early development stage, see [TODO](TODO.md) for missing features.

## installing netd

- Download and install Nim language [0.11.3-pre-bb2aa24c](https://users.atomshare.net/~zlmch/nim-0.11.3-pre-bb2aa24c.tar.xz).
- Compile netd: `nim c netd`


## running netd

| netd is not ready for production use yet! |
| ----------------------------------------- |

Run netd using provided example configuration:

    sudo bin/netd examples/dhcp.conf

Some example configurations create separate network manmespace and don't interact with your network connectivity.
