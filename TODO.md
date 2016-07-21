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

## features

* wireless client
* openvpn server/client
* CJDNS peer + tunnel
* multilink client
