# Bugs

## generic

* [optional] resolvconf integration
* renaming interfaces in cycles (foo -> bar, bar -> foo) probably breaks
* make sure that lo interface is up and has address
* raise ConfError if ipaddress is invalid
* add type= field to alias properties + handle changing link types (or prefix abstract names?)
* automatically shorten abstract names when making kernel names
* flush addresses on non-synthetic interfaces that were managed but now aren't
* before rename iface it need to be down
* make sure abstract names can be path components
* `netd reloadconfig` somehow leaks tty to the daemon (???)

## bridge

* handle abstract names in bridge ports
* handle bridge\_with and bridge\_master

## wireless

* 802.11n/ac support (AP)
* reconnect when network changed

## zerotier

* ZT can't handle renamed interfaces

# TODO

## mesh

* 802.11s + authsae
* cjdns

## high level interface

* bridge: route_parent (setup masq)
* easy internet sharing (as in MacOSX)

## other

* MTU!
* IPsec
* traffic shaping
* openvpn server/client
* CJDNS peer + tunnel
* multilink client
* gvpe
* IPv6!!!
* http reverse proxy? (autonginx like)
* 3G/4G support

* switch support (portgroup)
* enable/disable forwading
* listen for interface creation events and reload
