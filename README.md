# netd

netd is an advanced network manager for Linux desktops, servers and embedded systems.

It supports advanced configuration involving multiple interfaces, VPNs, network namespaces and much more. netd currently is in beta, some features are unstable (see _features_ section). Read more in [documentation](doc.org).

## features

- addressing:
  - static IP (`static`)
  - DHCP (`dhcp`)
- network namespaces
- iptables managements (`iptables`)
- DHCP server (`dhcp_server`)
- devices:
  - hardware/externally created devices (`link dev`)
  - bridge (`bridge`)
  - virtual ethernet (`veth`)
- VPN:
  - openvpn point-to-point links (`openvpn_ptp`)
- wireless:
  - client mode (unstable)
  - AP mode (unstable)
  - 802.11s mesh mode (unstable)
  - adhoc mode (unstable)

## installing netd

### on Ubuntu

```
curl https://repo.atomshare.net/key.asc | sudo apt-key add -
echo 'deb https://repo.atomshare.net/ common main' > /etc/apt/sources.list.d/atomshare.list
apt-get update
apt-get install -y netd
```

### building from source

- build netd: `./build.sh`
- install: `sudo ./install.sh`
- edit configuration: `sudo editor /etc/netd.conf`
- start: `sudo systemctl start netd`
