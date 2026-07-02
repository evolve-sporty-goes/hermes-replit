#!/bin/bash
(
cd 
curl -sL "https://github.com/windtf/wireproxy/releases/latest/download/wireproxy_linux_amd64.tar.gz" | tar xz && chmod +x ~/wireproxy 
)
cat > ~/wireproxy.conf <<'mEOF'
[Interface]
PrivateKey = gOCDqyj4jMGJPnykTSjLoDAXjd6bD0XBPc+VwRwIE0w=
Address = 10.2.0.2/32
DNS = 10.2.0.1
[Peer]
PublicKey = VZghTYxgyeiYtJ8HcBRaOFRnRjqSoNYmHVSoOQLz3gA=
Endpoint = 149.88.18.238:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
[Socks5]
BindAddress = 127.0.0.1:40000
mEOF
cat > ~/wireproxy40001.conf <<'mEOF'
[Interface]
PrivateKey = mJmUDNywLjLmlrp+aXok4zdUu1F0tTrqnvlsNpqZFU4=
Address = 10.2.0.2/32, 2a07:b944::2:2/128
DNS = 10.2.0.1, 2a07:b944::2:1
[Peer]
# US-FREE#101
PublicKey = R0RqfuJtC/XoV7AoVJLE4Mut7awnOfdaAOyupja9HXk=
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 149.88.18.233:51820
PersistentKeepalive = 25
[Socks5]
BindAddress = 127.0.0.1:40001
mEOF

cat > ~/wireproxy40002.conf <<'mEOF'
[Interface]
PrivateKey = OLVWs2QhnuWqhzXpL8aunLQqwN12Jz8BFZTJ71c5G2s=
Address = 10.2.0.2/32, 2a07:b944::2:2/128
DNS = 10.2.0.1, 2a07:b944::2:1

[Peer]
# CA-FREE#13
PublicKey = KiCvg9+bh7/ssQDALW3uXSTLaURS3mgZdi/O9CxlFXo=
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 79.127.254.65:51820
PersistentKeepalive = 25

[Socks5]
BindAddress = 127.0.0.1:40002
mEOF



~/wireproxy -c ~/wireproxy.conf &
~/wireproxy -c ~/wireproxy40001.conf &
~/wireproxy -c ~/wireproxy40002.conf &
#sleep 3 && curl --socks5 127.0.0.1:40001 https://api.ipify.org