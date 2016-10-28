
## implementation

* make sure that lo interface is up and has address
* raise ConfError if ipaddress is invalid
* handle abstract names in bridge ports
* handle bridge\_with and bridge\_master
* add type= field to alias properties + handle changing link types
* flush addresses on non-synthetic interfaces that were managed but now aren't
* before rename iface it need to be down
* make sure abstract names can be path components
* 802.11n/ac support (AP)
* we need to wait a bit after killing wpa_supplicant
* `netd reloadconfig` somehow leaks tty to the daemon (???)

## features

* openvpn server/client
* CJDNS peer + tunnel
* multilink client
* configure forwading
* [optional] resolvconf integration
* switch support (portgroup)
* gvpe
* zerotier
* IPv6!!!
* routing
    * interface `route host/mask local;`, `route host/mask via router;`, `route default via router;`
    * `default;`
    * global `route host/mask via router;`
* http proxy? (autonginx like)

## high level interface

* bridge: route_parent (setup masq)
* easy internet sharing (as in MacOSX)
