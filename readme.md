# Synology Container

##### Networks
|Name|Subnet|Gateway|Used by stack|
|-|-|-|-|
|frontend|172.18.0.0/16|172.18.0.1|databases|
|database|172.19.0.0/24|172.19.0.1|databases|
|homeassistant|172.19.1.0/24|172.19.1.1|databases, home-assistant|
|authentik|172.19.2.0/24|172.19.2.1|databases, authentik|
