## implementation

* make sure that lo interface is up and has address
* raise ConfError if ipaddress is invalid
* remove IP addresses when there are no addressing sections
* handle abstract names in bridge ports
* handle bridge\_with and bridge\_master
* add type= field to alias properties + handle changing link types
* flush addresses on non-synthetic interfaces that were managed but now aren't
* before rename iface it need to be down

## features

* wireless client
* dhcp server
* wireless AP
* openvpn server/client
* CJDNS peer + tunnel
* multilink client
