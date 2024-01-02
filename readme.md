# Synology Container

## Stack Deploy Order

1. portainer: Allow to deploy subsequent stacks from GitHub
2. adguard: Provide DNS
3. traefik: Set up Reverse Proxy
4. databases: needed as backend for other containers
5. Authentik: Authentication, and middleware.
**Now reverse proxying will start working as middleware is published**

## Networks
|Name|Subnet|Gateway|Used by stack|Defined in|
|-|-|-|-|-|
|authentik|172.19.2.0/24|172.19.2.1|authentik</br>databases|databases|
|database|172.19.0.0/24|172.19.0.1|databases|
|frontend|172.18.0.0/16|172.18.0.1|adguard</br>codeserver</br>databases</br>portainer</br>traefik|portainer|
|homeassistant|172.19.1.0/24|172.19.1.1|databases</br>home-assistant|databases|
|macvlan *|192.168.1.0/24|192.168.1.1|adguard</br>traefik|adguard|

**\* Macvlan network - IP Range: 192.168.1.48/28**
