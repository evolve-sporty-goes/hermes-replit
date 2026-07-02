#!/bin/bash
curl -sL "https://github.com/windtf/wireproxy/releases/latest/download/wireproxy_linux_amd64.tar.gz" | tar xz && chmod +x ~/wireproxy
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
~/wireproxy -c ~/wireproxy.conf & sleep 3 && curl --socks5 127.0.0.1:40000 https://api.ipify.org