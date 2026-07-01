[Skip to content](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a#start-of-content)

[Gist Homepage ](https://gist.github.com/)

Search Gists

Search Gists

[Gist Homepage ](https://gist.github.com/)

[Sign in](https://gist.github.com/auth/github?return_to=https%3A%2F%2Fgist.github.com%2Ffusetim%2F1a1ee1bdf821a45361f346e9c7f41e5a) [Sign up](https://gist.github.com/join?return_to=https%3A%2F%2Fgist.github.com%2Ffusetim%2F1a1ee1bdf821a45361f346e9c7f41e5a&source=header-gist)

You signed in with another tab or window. [Reload](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a) to refresh your session.You signed out in another tab or window. [Reload](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a) to refresh your session.You switched accounts on another tab or window. [Reload](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a) to refresh your session.Dismiss alert

{{ message }}

Instantly share code, notes, and snippets.


[![@fusetim](https://avatars.githubusercontent.com/u/62183512?s=64&v=4)](https://gist.github.com/fusetim)

# [fusetim](https://gist.github.com/fusetim)/ **[protonvpn-wireguard-generator.py](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a)**

Last active
2 months agoMay 5, 2026 12:44

Show Gist options

- [Download ZIP](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a/archive/c8877cc8a226f09f9c80d90c135be807228352cf.zip)

- [Star62(62)](https://gist.github.com/login?return_to=https%3A%2F%2Fgist.github.com%2Ffusetim%2F1a1ee1bdf821a45361f346e9c7f41e5a) You must be signed in to star a gist
- [Fork10(10)](https://gist.github.com/login?return_to=https%3A%2F%2Fgist.github.com%2Ffusetim%2F1a1ee1bdf821a45361f346e9c7f41e5a) You must be signed in to fork a gist

- Embed








# Select an option





























  - Embed
    Embed this gist in your website.
  - Share
    Copy sharable link for this gist.
  - Clone via HTTPS
    Clone using the web URL.

## No results found

[Learn more about clone URLs](https://docs.github.com/articles/which-remote-url-should-i-use)

Clone this repository at &lt;script src=&quot;https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a.js&quot;&gt;&lt;/script&gt;

- Save fusetim/1a1ee1bdf821a45361f346e9c7f41e5a to your computer and use it in GitHub Desktop.

Embed

# Select an option

- Embed
Embed this gist in your website.
- Share
Copy sharable link for this gist.
- Clone via HTTPS
Clone using the web URL.

## No results found

[Learn more about clone URLs](https://docs.github.com/articles/which-remote-url-should-i-use)

Clone this repository at &lt;script src=&quot;https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a.js&quot;&gt;&lt;/script&gt;

Save fusetim/1a1ee1bdf821a45361f346e9c7f41e5a to your computer and use it in GitHub Desktop.

[Download ZIP](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a/archive/c8877cc8a226f09f9c80d90c135be807228352cf.zip)

Generate lots of Wireguard configuration for your ProtonVPN Account.


[Raw](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a/raw/c8877cc8a226f09f9c80d90c135be807228352cf/protonvpn-wireguard-generator.py)

[**protonvpn-wireguard-generator.py**](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a#file-protonvpn-wireguard-generator-py)

This file contains hidden or bidirectional Unicode text that may be interpreted or compiled differently than what appears below. To review, open the file in an editor that reveals hidden Unicode characters.
[Learn more about bidirectional Unicode characters](https://github.co/hiddenchars)

[Show hidden characters](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a)

|     |     |
| --- | --- |
|  | importhttp.client |
|  | importhttp.cookies |
|  | importjson |
|  | importbase64 |
|  | importhashlib |
|  | fromcryptography.hazmat.primitivesimportserialization |
|  | fromcryptography.hazmat.primitives.asymmetricimportx25519 |
|  | fromcryptography.hazmat.primitives.asymmetricimportec |
|  | fromcryptography.hazmat.primitivesimporthashes |
|  |  |
|  | """ |
|  | Copyright - FuseTim 2024 |
|  |  |
|  | This code is dual-licensed under both the MIT License and the Apache License 2.0. |
|  |  |
|  | You may choose either license to govern your use of this code. |
|  |  |
|  | MIT License: |
|  | https://opensource.org/licenses/MIT |
|  |  |
|  | Apache License 2.0: |
|  | https://www.apache.org/licenses/LICENSE-2.0 |
|  |  |
|  | By contributing to this project, you agree that your contributions will be licensed under |
|  | both the MIT License and the Apache License 2.0. |
|  | """ |
|  |  |
|  | ###################################################################################### |
|  |  |
|  | \# Credentials (found in Headers and Cookies) |
|  | auth\_server="------"\# See \`x-pm-uid\` header |
|  | auth\_token="------"\# See \`AUTH-<x-pm-uid>\` cookie |
|  | session\_id="------"\# See \`Session-Id\` cookie |
|  | web\_app\_version="web-vpn-settings@5.0.2.0"\# See \`x-pm-appversion\` header |
|  |  |
|  | \# Settings |
|  | prefix="PREFIX"\# Prefix is used for config file and name in ProtonVPN Dashboard |
|  | output\_dir="./" |
|  | selected\_countries= \["CH"\] |
|  | selected\_tier=2\# 0 = Free, 2 = Plus |
|  | selected\_features= \[ \] \# Features that a server should have ("P2P", "TOR", "SecureCore", "XOR", etc) or not ("-P2P", etc) |
|  | max\_servers=2\# Maximum of generated config |
|  | listing\_only=False\# Do not generate config, just list available servers with previous selectors |
|  |  |
|  | config\_features= { |
|  | "SafeMode": False, |
|  | "SplitTCP": True, |
|  | "PortForwarding": True, |
|  | "RandomNAT": False, |
|  | "NetShieldLevel": 0, \# 0, 1 or 2 |
|  | }; |
|  | ###################################################################################### |
|  |  |
|  | \# Contants |
|  | connection=http.client.HTTPSConnection("account.protonvpn.com") |
|  | C=http.cookies.SimpleCookie() |
|  | C\["AUTH-"+auth\_server\] =auth\_token |
|  | C\["Session-Id"\] =session\_id |
|  | headers= { |
|  | "x-pm-appversion": web\_app\_version, |
|  | "x-pm-uid": auth\_server, |
|  | "Accept": "application/vnd.protonmail.v1+json", |
|  | "Cookie": C.output(attrs=\[\],header="", sep="; ") |
|  | } |
|  |  |
|  |  |
|  | defgenerateKeys(): |
|  | """Generate a client key-pair using the API. Could be generated offline but need more work...""" |
|  | print("Generating key-pair...") |
|  | connection.request("GET", "/api/vpn/v1/certificate/key/EC", headers=headers) |
|  | response=connection.getresponse() |
|  | print("Status: {} and reason: {}".format(response.status, response.reason)) |
|  | resp=json.loads(response.read().decode()) |
|  | priv=resp\["PrivateKey"\].split("\\n")\[1\] |
|  | pub=resp\["PublicKey"\].split("\\n")\[1\] |
|  | print("Key generated:") |
|  | print("priv:", priv) |
|  | print("pub:", pub) |
|  | return \[resp\["PrivateKey"\], pub, priv\] |
|  |  |
|  |  |
|  | defgetPubPEM(priv): |
|  | """Return the Public key as string without headers""" |
|  | returnpriv\[1\] |
|  |  |
|  | defgetPrivPEM(priv): |
|  | """Return the Private key as PKCS#8 without headers""" |
|  | returnpriv\[2\] |
|  |  |
|  | defgetPrivx25519(priv): |
|  | """Return the x25519 base64-encoded private key, to be used in Wireguard config.""" |
|  | hash\_\_=hashlib.sha512(base64.b64decode(priv\[2\])\[-32:\]).digest() |
|  | hash\_=list(hash\_\_)\[:32\] |
|  | hash\_\[0\] &=0xf8 |
|  | hash\_\[31\] &=0x7f |
|  | hash\_\[31\] \|=0x40 |
|  | new\_priv=base64.b64encode(bytes(hash\_)).decode() |
|  | returnnew\_priv |
|  |  |
|  |  |
|  | defregisterConfig(server, priv): |
|  | """Register a Wireguard configuration and return its raw response.""" |
|  | h=headers.copy() |
|  | h\["Content-Type"\]="application/json" |
|  | print("Registering Config for server", server\["Name"\],"...") |
|  | body= { |
|  | "ClientPublicKey": getPubPEM(priv), |
|  | "Mode": "persistent", |
|  | "DeviceName": prefix+"-"+server\["Name"\], |
|  | "Features": { |
|  | "peerName": server\["Name"\], |
|  | "peerIp": server\["Servers"\]\[0\]\["EntryIP"\], |
|  | "peerPublicKey": server\["Servers"\]\[0\]\["X25519PublicKey"\], |
|  | "platform": "Windows", |
|  | \# You can add features there (PortForwarding, SplitTCP, ModerateNAT |
|  | \# See https://github.com/ProtonMail/WebClients/blob/8b5035d6f848b76d005814fca260bb616e83a4b2/packages/components/containers/vpn/WireGuardConfigurationSection/feature.ts#L53 |
|  | "SafeMode": config\_features\["SafeMode"\], |
|  | "SplitTCP": config\_features\["SplitTCP"\], |
|  | "PortForwarding": config\_features\["PortForwarding"\] ifserver\["Features"\] &4==4elseFalse, |
|  | "RandomNAT": config\_features\["RandomNAT"\], |
|  | "NetShieldLevel": config\_features\["NetShieldLevel"\], \# 0, 1 or 2 |
|  | } |
|  | } |
|  | connection.request("POST", "/api/vpn/v1/certificate", body=json.dumps(body), headers=h) |
|  | response=connection.getresponse() |
|  | print("Status: {} and reason: {}".format(response.status, response.reason)) |
|  | resp=json.loads(response.read().decode()) |
|  | print(resp) |
|  | returnresp |
|  |  |
|  | defgenerateConfig(priv, register): |
|  | """Generate a Wireguard config using the ProtonVPN API answer.""" |
|  | conf="""\[Interface\] |
|  | \# Key for {prefix} |
|  | PrivateKey = {priv} |
|  | Address = 10.2.0.2/32 |
|  | DNS = 10.2.0.1 |
|  |  |
|  | \[Peer\] |
|  | \# {server\_name} |
|  | PublicKey = {server\_pub} |
|  | AllowedIPs = 0.0.0.0/0 |
|  | Endpoint = {server\_endpoint}:51820 |
|  | """.format(prefix=prefix, priv=getPrivx25519(priv), server\_name=register\["Features"\]\["peerName"\], server\_pub=register\["Features"\]\["peerPublicKey"\], server\_endpoint=register\["Features"\]\["peerIp"\]) |
|  | returnconf |
|  |  |
|  |  |
|  | defwrite\_config\_to\_disk(name, conf): |
|  | f=open(output\_dir+"/"+name+".conf", "w") |
|  | f.write(conf) |
|  | f.close() |
|  |  |
|  |  |
|  | \# VPN Listings |
|  |  |
|  | connection.request("GET", "/api/vpn/logicals", headers=headers) |
|  | response=connection.getresponse() |
|  | print("Status: {} and reason: {}".format(response.status, response.reason)) |
|  |  |
|  | servers=json.loads(response.read().decode())\["LogicalServers"\] |
|  |  |
|  | forsinservers: |
|  | feat= \[ |\
|  | "SecureCore"ifs\["Features"\] &1==1else"-SecureCore", |\
|  | "TOR"ifs\["Features"\] &2==2else"-TOR", |\
|  | "P2P"ifs\["Features"\] &4==4else"-P2P", |\
|  | "XOR"ifs\["Features"\] &8==8else"-XOR", |\
|  | "IPv6"ifs\["Features"\] &16==16else"-IPv6" |\
|  | \] |
|  | if (nots\["EntryCountry"\] inselected\_countriesandnots\["ExitCountry"\] inselected\_countries) ors\["Tier"\] !=selected\_tier: |
|  | continue |
|  | iflen(list(filter(lambdasf: not (sfinfeat), selected\_features))) >0: |
|  | continue |
|  | print("\- Server", s\["Name"\]) |
|  | print(" \> ID:", s\["ID"\]) |
|  | print(" \> EntryCountry:", s\["EntryCountry"\]) |
|  | print(" \> ExitCountry:", s\["ExitCountry"\]) |
|  | print(" \> Tier:", s\["Tier"\]) |
|  | print(" \> Features:") |
|  | print(" \- SecureCore:", "Y"ifs\["Features"\] &1==1else"N") |
|  | print(" \- Tor:", "Y"ifs\["Features"\] &2==2else"N") |
|  | print(" \- P2P:", "Y"ifs\["Features"\] &4==4else"N") |
|  | print(" \- XOR:", "Y"ifs\["Features"\] &8==8else"N") |
|  | print(" \- IPv6:", "Y"ifs\["Features"\] &16==16else"N") |
|  | print(" \> Score:", s\["Score"\]) |
|  | print(" \> Load:", s\["Load"\]) |
|  | print(" \> Status:", s\["Status"\]) |
|  | print(" \> Instance:") |
|  | foriins\["Servers"\]: |
|  | print(" \- Instance n°",i\["Label"\],":", i\["ID"\]) |
|  | print(" \> EntryIP:", i\["EntryIP"\]) |
|  | print(" \> ExitIP:", i\["ExitIP"\]) |
|  | print(" \> Domain:", i\["Domain"\]) |
|  | print(" \> X25519PublicKey:", i\["X25519PublicKey"\]) |
|  | ifnotlisting\_only: |
|  | keys=generateKeys() |
|  | reg=registerConfig(s, keys) |
|  | config=generateConfig(keys, reg) |
|  | write\_config\_to\_disk(reg\["DeviceName"\], config) |
|  | max\_servers-=1 |
|  | if (max\_servers<=0): |
|  | break |
|  |  |
|  | connection.close() |

Load earlier comments...

[![@fusetim](https://avatars.githubusercontent.com/u/62183512?s=80&v=4)](https://gist.github.com/fusetim)

### **[fusetim](https://gist.github.com/fusetim)**     commented    [on Nov 11, 2022Nov 11, 2022](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=4366139\#gistcomment-4366139)•   edited      Loading          \#\#\# Uh oh!        There was an error while loading. [Please reload this page](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a).


Copy link


Copy Markdown

Author

Revision 2, config generator has been successfully working up to this day.

These configs, used with a working NAT-PMP client can allow Port Forwarding! Up to this day, there is no issue to use port-forwarding with ProtonVPN.

Note:

- `natpmpc` is not working due to some incompatibilities with ProtonVPN NAT-PMP implementation.
- `py-natpmp` (cf [Github](https://github.com/yimingliu/py-natpmp)) is a working client (but not maintained).
- Deluge and QBittorrent internal NAT-PMP clients can work sometimes : opening port in both UDP and TCP is not supported by ProtonVPN NAT-PMP implementation, therefore sometimes it is just closing one and the other repeatedly to accept the other protocol.
- Qbittorrent & NATPMP: [Docker Mod](https://github.com/fusetim/external_natpmp_qbittorrent), [docker compose script](https://gist.github.com/h3xcat/10c4d5e80bf3f05be2c81a74a424b06a)
- ProtonVPN headers (Auth) can be found on the page: [https://account.proton.me/api/core/v4/events/latest](https://account.proton.me/api/core/v4/events/latest)

[![@dlecan](https://avatars.githubusercontent.com/u/586631?s=80&v=4)](https://gist.github.com/dlecan)

### **[dlecan](https://gist.github.com/dlecan)**     commented    [on Dec 15, 2022Dec 15, 2022](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=4403867\#gistcomment-4403867)


Copy link


Copy Markdown

Do you know a working bittorrent client with this configuration?

Can you explain how to use this script ?

Before each connection? Once an for all?

Do you know if such an algorithm could work for OpenVPN as well?

[![@fusetim](https://avatars.githubusercontent.com/u/62183512?s=80&v=4)](https://gist.github.com/fusetim)

### **[fusetim](https://gist.github.com/fusetim)**     commented    [on Dec 16, 2022Dec 16, 2022](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=4404598\#gistcomment-4404598)


Copy link


Copy Markdown

Author

> Do you know a working bittorrent client with this configuration?
>
> Can you explain how to use this script ? Before each connection? Once an for all?
>
> Do you know if such an algorithm could work for OpenVPN as well?

1. I am not aware of bittorrent client that works entirely from scratch with this.
2. The script should be run one time and then you just have to use the generated config. These configs expire after one year, so you might need to run this script again or renew the config using the official ProtonVPN dashboard.
3. I'm not aware of that. But clearly Wireguard is more easy to make this work. Someone interested by a similar OpenVPN config generator might found the useful information from official client source code.

[![@fusetim](https://avatars.githubusercontent.com/u/62183512?s=80&v=4)](https://gist.github.com/fusetim)

### **[fusetim](https://gist.github.com/fusetim)**     commented    [on Dec 18, 2022Dec 18, 2022](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=4406660\#gistcomment-4406660)•   edited      Loading          \#\#\# Uh oh!        There was an error while loading. [Please reload this page](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a).


Copy link


Copy Markdown

Author

Note: NAT-PMP (Port Forwarding) configs are now availables in the official ProtonVPN dashboard!

Weirdly the option is available for free tier accounts too.

[![@pvanryn](https://avatars.githubusercontent.com/u/1633790?s=80&v=4)](https://gist.github.com/pvanryn)

### **[pvanryn](https://gist.github.com/pvanryn)**     commented    [on Jan 2, 2023Jan 2, 2023](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=4421301\#gistcomment-4421301)


Copy link


Copy Markdown

I've been reading your posts on reddit. So if I create a wireguard config with port forwarding enabled, how do I know which port is open (Linux) ? If I do sudo wg-quick up wg0, I get:

interface: wg0

public key: redacted

private key: (hidden)

listening port: 44781

fwmark: 0xca6c

Listening port does not seem to correspond to port forward.

[![@fusetim](https://avatars.githubusercontent.com/u/62183512?s=80&v=4)](https://gist.github.com/fusetim)

### **[fusetim](https://gist.github.com/fusetim)**     commented    [on Jan 3, 2023Jan 3, 2023](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=4422185\#gistcomment-4422185)   via email


Copy link


Copy Markdown

Author

Re: fusetim/protonvpn-wireguard-generator.py

You need a NATPMP client running to request a port mapping while the VPN tunnel is active. Le 02/01/2023, 17:28 pvanryn \*\*\*@\*\*\*.\*\*\*> a écrit:

[@pvanryn](https://github.com/pvanryn) commented on this gist.

I've been reading your posts on reddit. So if I create a wireguard config with port forwarding enabled, how do I know which port is open (Linux) ? If I do sudo wg-quick up wg0, I get:
interface: wg0public key: redactedprivate key: (hidden)listening port: 44781fwmark: 0xca6c
Listening port does not seem to correspond to port forward.
—Reply to this email directly, view it on GitHub or unsubscribe.You are receiving this email because you authored the thread.
Triage notifications on the go with GitHub Mobile for iOS or Android.



[![@JackRoublard](https://avatars.githubusercontent.com/u/111562374?s=80&v=4)](https://gist.github.com/JackRoublard)

### **[JackRoublard](https://gist.github.com/JackRoublard)**     commented    [on Jan 17, 2023Jan 17, 2023](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=4439772\#gistcomment-4439772)


Copy link


Copy Markdown

> Note: NAT-PMP (Port Forwarding) configs are now availables in the official ProtonVPN dashboard! Weirdly the option is available for free tier accounts too.

Hi, Thanks for your work ! I've stumbled here thanks to reddit while also trying to setup port forwarding with proton wireguard/openvpn. Do you reckon that the feature has (mistakenly?) been made available to free-tier users ? Given that the official website states it's a windows-only/paid-only feature (which is at least half false/outdated), I have a faint hope that it is the case.

However, I've been trying both \[wg-quick + official proton config files\] and \[networkmanager openvpn "+pmp" in the username field\] techniques but my natpmp clients keep saying the gateway is not compatible. So far I have tried :

- natpmpc
- py-natpmp
- nmap --script=nat-pmp-info ( [https://nmap.org/nsedoc/scripts/nat-pmp-info.html](https://nmap.org/nsedoc/scripts/nat-pmp-info.html))

(The third one actually doesn't say the gateway is incompatible but I'm not sure I'm using it correctly, hence my question.)

Is there a surefire way to find out which port has supposedly been made available by proton upon connection ? So far every natpmp client i've tried just asks for an input port, which I don't have (although, like [@pvanryn](https://github.com/pvanryn), I initially thought that it was the listening port given by wg-quick upon connection, since it changes with every connection and seems randomized as it should. However, external port-checkers keep saying it's closed so I'm guessing this is probably wrong.)

[![@fusetim](https://avatars.githubusercontent.com/u/62183512?s=80&v=4)](https://gist.github.com/fusetim)

### **[fusetim](https://gist.github.com/fusetim)**     commented    [on Jan 17, 2023Jan 17, 2023](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=4439848\#gistcomment-4439848)•   edited      Loading          \#\#\# Uh oh!        There was an error while loading. [Please reload this page](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a).


Copy link


Copy Markdown

Author

> > Note: NAT-PMP (Port Forwarding) configs are now availables in the official ProtonVPN dashboard! Weirdly the option is available for free tier accounts too.
>
> Hi, Thanks for your work ! I've stumbled here thanks to reddit while also trying to setup port forwarding with proton wireguard/openvpn. Do you reckon that the feature has (mistakenly?) been made available to free-tier users ? Given that the official website states it's a windows-only/paid-only feature (which is at least half false/outdated), I have a faint hope that it is the case.
>
> However, I've been trying both \[wg-quick + official proton config files\] and \[networkmanager openvpn "+pmp" in the username field\] techniques but my natpmp clients keep saying the gateway is not compatible. So far I have tried :
>
> ```
> * natpmpc
>
> * py-natpmp
>
> * nmap --script=nat-pmp-info (https://nmap.org/nsedoc/scripts/nat-pmp-info.html)
> ```
>
> (The third one actually doesn't say the gateway is incompatible but I'm not sure I'm using it correctly, hence my question.)
>
> Is there a surefire way to find out which port has supposedly been made available by proton upon connection ? So far every natpmp client i've tried just asks for an input port, which I don't have (although, like [@pvanryn](https://github.com/pvanryn), I initially thought that it was the listening port given by wg-quick upon connection, since it changes with every connection and seems randomized as it should. However, external port-checkers keep saying it's closed so I'm guessing this is probably wrong.)

The feature is available when generating a wireguard config, nonetheless, in theory to really use NAT-PMP you need to be connected to a P2P servers thus the free servers cannot be used for Port forwarding.

I don't think this will change in the future.

The Nmap script only provide part of the NATPMP protocol which features a way to discover the external IP of the server, but this script can not reserve a port for you. But if it displayed the correct address (a ProtonVPN one) then you should be able to request a port mapping.

Note that you might need to specify the gateway address (most likely 10.2.0.1 -- see the wireguard config, and replace the last digit of the address field by 1) as it might try to get a port from your own router (which might provide this feature).

The input port that needed is in reality not important because ProtonVPN use a special NATPMP gateway. Nonetheless, using 0 as input port will ask for a random port to be forwarded.

Finally yes, the mapped port is completely different from your wireguard listening port.

[![@JackRoublard](https://avatars.githubusercontent.com/u/111562374?s=80&v=4)](https://gist.github.com/JackRoublard)

### **[JackRoublard](https://gist.github.com/JackRoublard)**     commented    [on Jan 20, 2023Jan 20, 2023](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=4443985\#gistcomment-4443985)•   edited      Loading          \#\#\# Uh oh!        There was an error while loading. [Please reload this page](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a).


Copy link


Copy Markdown

Thank you for the detailed reply. You're probably right about them having distinct features implemented on different types of server.

> The Nmap script only provide part of the NATPMP protocol which features a way to discover the external IP of the server, but this script can not reserve a port for you. But if it displayed the correct address (a ProtonVPN one) then you should be able to request a port mapping.

I am aware that the nmap script does not do the actual port mapping, as there is [another one](https://nmap.org/nsedoc/scripts/nat-pmp-mapport.html) for that purpose. However, interestingly enough after fiddling with the nmap command parameters I managed to get the following listing :

```
PORT     STATE  SERVICE
53/tcp       open     domain
4443/tcp   open     pharos
4446/tcp   open     n1-fwp
```

Guessing "fwp" could stand for " **f** or **w** ard **p** ort, I tried to actually map the port in question :

`sudo nmap -p <listening_port> --script=nat-pmp-mapport 10.2.0.1 --script-args='op=map,pubport=4446,privport=25565,protocol=tcp'`

But to no avail.

[![@quantum77](https://avatars.githubusercontent.com/u/35746122?s=80&v=4)](https://gist.github.com/quantum77)

### **[quantum77](https://gist.github.com/quantum77)**     commented    [on Feb 22, 2023Feb 23, 2023](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=4480606\#gistcomment-4480606)•   edited      Loading          \#\#\# Uh oh!        There was an error while loading. [Please reload this page](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a).


Copy link


Copy Markdown

\# python /home/bill/bin/natpmp\_client.py -g 10.2.0.1 -u -l 60 34741 34741

PortMapResponse: version 0, opcode 129 (129), result 0, ssec 488668, private\_port 34741, public port 46912, lifetime 60

\# python /home/bill/bin/natpmp\_client.py -g 10.2.0.1 -u -l 60 57342 57342

PortMapResponse: version 0, opcode 129 (129), result 0, ssec 488136, private\_port 57342, public port 38508, lifetime 60

\# python /home/bill/bin/natpmp\_client.py -g 10.2.0.1 -u -l 60 34741 34741

PortMapResponse: version 0, opcode 129 (129), result 0, ssec 488668, private\_port 34741, public port 46912, lifetime 60

I can't get a fixed outside port. How can anyone contact me if the outside port is always changing? Same problem with natpmpc.

Is there a NATPMP client which actually woks?

[![@fusetim](https://avatars.githubusercontent.com/u/62183512?s=80&v=4)](https://gist.github.com/fusetim)

### **[fusetim](https://gist.github.com/fusetim)**     commented    [on Feb 23, 2023Feb 23, 2023](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=4481050\#gistcomment-4481050)


Copy link


Copy Markdown

Author

It seems it worked as expected, the port you got were 46912 (for 1/3) and 38508. But please note that you cannot choose the port you get and that you should renew the port mapping at least every 60s (using the port you got previously).

Actually the first time you want a port, you should try to use port 0 (as internal and external) and then renew the port with the given one.

Also checkout this new documentation : [https://protonvpn.com/support/port-forwarding-manual-setup/](https://protonvpn.com/support/port-forwarding-manual-setup/)

[![@pvanryn](https://avatars.githubusercontent.com/u/1633790?s=80&v=4)](https://gist.github.com/pvanryn)

### **[pvanryn](https://gist.github.com/pvanryn)**     commented    [on Feb 23, 2023Feb 23, 2023](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=4481330\#gistcomment-4481330)•   edited by fusetim      Loading          \#\#\# Uh oh!        There was an error while loading. [Please reload this page](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a).


Copy link


Copy Markdown

> I can't get a fixed outside port. How can anyone contact me if the outside port is always changing? Same problem with natpmpc.

See script [here](https://www.reddit.com/r/ProtonVPN/comments/10owypt/successful_port_forward_on_debian_wdietpi_using/)

**\[OP Edit\]:** This script suffers from the same limitations.

[![@thibaultmol](https://avatars.githubusercontent.com/u/1010226?s=80&v=4)](https://gist.github.com/thibaultmol)

### **[thibaultmol](https://gist.github.com/thibaultmol)**     commented    [on Jun 26, 2023Jun 26, 2023](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=4611067\#gistcomment-4611067)


Copy link


Copy Markdown

I suggest putting in the readme that you can find those headers in the request with the url ' [https://account.proton.me/api/core/v4/events/latest](https://account.proton.me/api/core/v4/events/latest)'

[![@Lenni-builder](https://avatars.githubusercontent.com/u/87639068?s=80&v=4)](https://gist.github.com/Lenni-builder)

### **[Lenni-builder](https://gist.github.com/Lenni-builder)**     commented    [on Jun 15, 2024Jun 15, 2024](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=5089762\#gistcomment-5089762)


Copy link


Copy Markdown

Please add a license so people can legally fork it. I think adding it as a comment to the code is the best way to do it for a script like this.

(Without a license it's under copyright, so it's essentially like proprietary software but with the source code you aren't allowed to do much with being public)

[![@fusetim](https://avatars.githubusercontent.com/u/62183512?s=80&v=4)](https://gist.github.com/fusetim)

### **[fusetim](https://gist.github.com/fusetim)**     commented    [on Jun 15, 2024Jun 15, 2024](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=5089829\#gistcomment-5089829)


Copy link


Copy Markdown

Author

> Please add a license so people can legally fork it. I think adding it as a comment to the code is the best way to do it for a script like this. (Without a license it's under copyright, so it's essentially like proprietary software but with the source code you aren't allowed to do much with being public)

Your wishes have been granted, this code is officially licensed under MIT & Apache 2.0, even though I never intended to particularly protect this piece of code. I hope this can help you ;)

[![@tiimk](https://avatars.githubusercontent.com/u/9601105?s=80&v=4)](https://gist.github.com/tiimk)

### **[tiimk](https://gist.github.com/tiimk)**     commented    [on Jun 30, 2024Jun 30, 2024](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=5106655\#gistcomment-5106655)•   edited      Loading          \#\#\# Uh oh!        There was an error while loading. [Please reload this page](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a).


Copy link


Copy Markdown

I have made some small modifications to this and figure I would share back here. I added in the ability to choose local cities as well. So instead of generating a batch of US servers I can generate US-NY and US-VA for example. I also added in a sleep timer since I was running in to issues of generating too many configs.

As well I added in a simple extend argument to renew any configs to help futureproof. python script.py -extend will do as such. Same 1 minute sleep on that.

As well there is an additional script for anyone who would like to work as a possible "auto" connect for best server available from proton using wireguard. I would recommend importing all the configs to wireguard just to be able to control it from the app if needed. but not required.

[https://gist.github.com/tiimk/56e88a6e5d47157dedf40e2761683cf1](https://gist.github.com/tiimk/56e88a6e5d47157dedf40e2761683cf1)

If using the connect script you can run it and it will choose the best, run it again and it will choose the second best if already connected to the best. or run python connectscript.py -location=US-NY to only connect to the best server in US-NY. This will only connect to servers you have configs made for so may need some time to generate enough configs to get a wide variety.

[![@fusetim](https://avatars.githubusercontent.com/u/62183512?s=80&v=4)](https://gist.github.com/fusetim)

### **[fusetim](https://gist.github.com/fusetim)**     commented    [on Jun 30, 2024Jun 30, 2024](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=5106750\#gistcomment-5106750)


Copy link


Copy Markdown

Author

👍 Cool additions, thank you for sharing this with everyone.

[![@executed](https://avatars.githubusercontent.com/u/36827253?s=80&v=4)](https://gist.github.com/executed)

### **[executed](https://gist.github.com/executed)**     commented    [on Mar 12, 2025Mar 12, 2025](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=5488763\#gistcomment-5488763)


Copy link


Copy Markdown

Hello guys. So you just insert auth\_token once and then it auto-renews when expired?

I saw that fusetim mentioned it's a year or so, is it possible to extend it even more automatically?

[![@fusetim](https://avatars.githubusercontent.com/u/62183512?s=80&v=4)](https://gist.github.com/fusetim)

### **[fusetim](https://gist.github.com/fusetim)**     commented    [on Mar 14, 2025Mar 14, 2025](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=5494125\#gistcomment-5494125)


Copy link


Copy Markdown

Author

> Hello guys. So you just insert auth\_token once and then it auto-renews when expired? I saw that fusetim mentioned it's a year or so, is it possible to extend it even more automatically?

The auth\_token is not automatically refreshed, the current state of this script requires you to either replace all the generated WireGuard configs with a new set of configs or use the official dashboard to extend the validity of the existing configurations.

While it is possible to extend the existing configurations using the official dashboard, this script does not (it could probably be automated). Moreover, it is not possible to extend a configuration for more than one year.

[![@executed](https://avatars.githubusercontent.com/u/36827253?s=80&v=4)](https://gist.github.com/executed)

### **[executed](https://gist.github.com/executed)**     commented    [on Mar 14, 2025Mar 15, 2025](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=5495274\#gistcomment-5495274)


Copy link


Copy Markdown

[@fusetim](https://github.com/fusetim) thank you for you response.

I did something similar to pull least loaded Proton server in particular country and auto-start OpenVPN app with it.

The problem is x-pm-uid/auth\_token/session\_id are expired after 24h - I think you mean certificates are expired after a year.

I think I'll need to additionally come up with headless chromium deamon to login and save the x-pm-uid/auth\_token/session\_id every 24 hours.

[![@fusetim](https://avatars.githubusercontent.com/u/62183512?s=80&v=4)](https://gist.github.com/fusetim)

### **[fusetim](https://gist.github.com/fusetim)**     commented    [on Mar 15, 2025Mar 15, 2025](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=5495412\#gistcomment-5495412)


Copy link


Copy Markdown

Author

[@executed](https://github.com/executed) That is correct, the auth\_token/session\_ID expire after 24h. Using a headless browser to do the login would probably be the easiest way to make it works. You could also try to refresh the token before it expires but you would need to find the particular endpoint for that.

### Uh oh!

There was an error while loading. [Please reload this page](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a).

[![@executed](https://avatars.githubusercontent.com/u/36827253?s=80&v=4)](https://gist.github.com/executed)

### **[executed](https://gist.github.com/executed)**     commented    [on Apr 3, 2025Apr 4, 2025](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=5526670\#gistcomment-5526670)•   edited      Loading          \#\#\# Uh oh!        There was an error while loading. [Please reload this page](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a).


Copy link


Copy Markdown

lol, was debugging Proton frontend logic and came here once again, looks like I was not the only one debugging it :)

Thank you for previous response though! Haven't noticed it.

Indeed I was able to login through headless browser using playwright + firefox. Can share Python script if someone will be interested.

P.S. Found out that the lower the Score field of server in logicals API call - the better.

Sorry, something went wrong.


### Uh oh!

There was an error while loading. [Please reload this page](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a).

[![@torms](https://avatars.githubusercontent.com/u/8841885?s=80&v=4)](https://gist.github.com/torms)

### **[torms](https://gist.github.com/torms)**     commented    [on Apr 17, 2025Apr 17, 2025](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=5545385\#gistcomment-5545385)•   edited      Loading          \#\#\# Uh oh!        There was an error while loading. [Please reload this page](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a).


Copy link


Copy Markdown

[@executed](https://github.com/executed)

> Indeed I was able to login through headless browser using playwright + firefox. Can share Python script if someone will be interested.

pls do

Sorry, something went wrong.


### Uh oh!

There was an error while loading. [Please reload this page](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a).

[![@executed](https://avatars.githubusercontent.com/u/36827253?s=80&v=4)](https://gist.github.com/executed)

### **[executed](https://gist.github.com/executed)**     commented    [on Apr 17, 2025Apr 18, 2025](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=5545667\#gistcomment-5545667)


Copy link


Copy Markdown

[@torms](https://github.com/torms)

App Server Script: [https://gist.github.com/executed/32f8d248a3d703d0fcf3fa7fd4add990](https://gist.github.com/executed/32f8d248a3d703d0fcf3fa7fd4add990)

Docker-compose: [https://gist.github.com/executed/8c91c03c4ea6cc705534c48dd90a97c4](https://gist.github.com/executed/8c91c03c4ea6cc705534c48dd90a97c4)

Sorry, something went wrong.


### Uh oh!

There was an error while loading. [Please reload this page](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a).

[![@weiluntong](https://avatars.githubusercontent.com/u/33438645?s=80&v=4)](https://gist.github.com/weiluntong)

### **[weiluntong](https://gist.github.com/weiluntong)**     commented    [on Apr 23, 2025Apr 23, 2025](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=5551988\#gistcomment-5551988)


Copy link


Copy Markdown

Very neat idea going with headless. I personally just want to get every free server as a config to rotate through, and since the configs don't expire for a year, I figured the 24 hour authentication tokens weren't really a problem. I got rate limited to hell though, so I made some adjustments, I really just added a couple of decorators to monkey patch the existing code without having to modify it. One decorator to naively wait 10 seconds before attempting a request, and another to check if the response code was successful, and if not, to just throw an exception which will quit the application because it's not handled, instead of trying to process it and failing.

```
#!/usr/bin/env python3

import base64
import hashlib
import http.client
import http.cookies
import json
import time
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric import x25519
from functools import wraps
from math import inf as oo

"""
Copyright - FuseTim 2024

This code is dual-licensed under both the MIT License and the Apache License 2.0.

You may choose either license to govern your use of this code.

MIT License:
https://opensource.org/licenses/MIT

Apache License 2.0:
https://www.apache.org/licenses/LICENSE-2.0

By contributing to this project, you agree that your contributions will be licensed under
both the MIT License and the Apache License 2.0.
"""

######################################################################################

# Credentials (found in Headers and Cookies)
auth_server = "------" # See `x-pm-uid` header
auth_token  = "------" # See `AUTH-<x-pm-uid>` cookie
session_id  = "------" # See `Session-Id` cookie
web_app_version = "web-vpn-settings@5.0.2.0" # See `x-pm-appversion` header

# Settings
prefix = "PREFIX" # Prefix is used for config file and name in ProtonVPN Dashboard
output_dir = "./"
selected_countries = ["JP", "NL", "PL", "RO", "US"]
selected_tier = 0 # 0 = Free, 2 = Plus
selected_features = [ ] # Features that a server should have ("P2P", "TOR", "SecureCore", "XOR", etc) or not ("-P2P", etc)
max_servers = oo # Maximum of generated config
listing_only = False # Do not generate config, just list available servers with previous selectors

config_features = {
    "SafeMode": False,
    "SplitTCP": True,
    "PortForwarding": True,
    "RandomNAT": False,
    "NetShieldLevel": 0, # 0, 1 or 2
};
######################################################################################

# Decorators
def enforce_fixed_delay(seconds):
    def decorator(func):
        @wraps(func)
        def wrapped(*args, **kwargs):
            time.sleep(seconds)
            return func(*args, **kwargs)
        return wrapped
    return decorator

def enforce_success_status(func):
    def wrapped(*args, **kwargs):
        response = func(*args, **kwargs)
        responseString = "Status: {} and reason: {}".format(response.status, response.reason)
        if response.status != 200:
            raise Exception(responseString)

        print(responseString)
        return response
    return wrapped

# Contants
connection = http.client.HTTPSConnection("account.protonvpn.com")
connection.request = enforce_fixed_delay(10)(connection.request)
connection.getresponse = enforce_success_status(connection.getresponse)
C = http.cookies.SimpleCookie()
C["AUTH-"+auth_server] = auth_token
C["Session-Id"] = session_id
headers = {
    "x-pm-appversion": web_app_version,
    "x-pm-uid": auth_server,
    "Accept": "application/vnd.protonmail.v1+json",
    "Cookie": C.output(attrs=[],header="", sep="; ")
}

def generateKeys():
    """Generate a client key-pair using the API. Could be generated offline but need more work..."""
    print("Generating key-pair...")
    connection.request("GET", "/api/vpn/v1/certificate/key/EC", headers=headers)
    response = connection.getresponse()
    resp = json.loads(response.read().decode())
    priv = resp["PrivateKey"].split("\n")[1]
    pub = resp["PublicKey"].split("\n")[1]
    print("Key generated:")
    print("priv:", priv)
    print("pub:", pub)
    return [resp["PrivateKey"], pub, priv]

def getPubPEM(priv):
    """Return the Public key as string without headers"""
    return priv[1]

def getPrivPEM(priv):
    """Return the Private key as PKCS#8 without headers"""
    return priv[2]

def getPrivx25519(priv):
    """Return the x25519 base64-encoded private key, to be used in Wireguard config."""
    hash__ = hashlib.sha512(base64.b64decode(priv[2])[-32:]).digest()
    hash_ = list(hash__)[:32]
    hash_[0] &= 0xf8
    hash_[31] &= 0x7f
    hash_[31] |= 0x40
    new_priv = base64.b64encode(bytes(hash_)).decode()
    return new_priv

def registerConfig(server, priv):
    """Register a Wireguard configuration and return its raw response."""
    h = headers.copy()
    h["Content-Type"]= "application/json"
    print("Registering Config for server", server["Name"],"...")
    body = {
        "ClientPublicKey": getPubPEM(priv),
        "Mode": "persistent",
        "DeviceName": prefix+"-"+server["Name"],
        "Features": {
                "peerName": server["Name"],
                "peerIp": server["Servers"][0]["EntryIP"],
                "peerPublicKey": server["Servers"][0]["X25519PublicKey"],
                "platform": "Windows",
                # You can add features there (PortForwarding, SplitTCP, ModerateNAT
                # See https://github.com/ProtonMail/WebClients/blob/8b5035d6f848b76d005814fca260bb616e83a4b2/packages/components/containers/vpn/WireGuardConfigurationSection/feature.ts#L53
                "SafeMode": config_features["SafeMode"],
                "SplitTCP": config_features["SplitTCP"],
                "PortForwarding": config_features["PortForwarding"] if server["Features"] & 4 == 4 else False,
                "RandomNAT": config_features["RandomNAT"],
                "NetShieldLevel": config_features["NetShieldLevel"], # 0, 1 or 2
        }
    }
    connection.request("POST", "/api/vpn/v1/certificate", body=json.dumps(body), headers=h)
    response = connection.getresponse()
    resp = json.loads(response.read().decode())
    print(resp)
    return resp

def generateConfig(priv, register):
    """Generate a Wireguard config using the ProtonVPN API answer."""
    conf = """[Interface]
# Key for {prefix}
PrivateKey = {priv}
Address = 10.2.0.2/32
DNS = 10.2.0.1

[Peer]
# {server_name}
PublicKey = {server_pub}
AllowedIPs = 0.0.0.0/0
Endpoint = {server_endpoint}:51820
    """.format(prefix=prefix, priv=getPrivx25519(priv), server_name=register["Features"]["peerName"], server_pub=register["Features"]["peerPublicKey"], server_endpoint=register["Features"]["peerIp"])
    return conf

def write_config_to_disk(name, conf):
    f = open(output_dir+"/"+name+".conf", "w")
    f.write(conf)
    f.close()

# VPN Listings

connection.request("GET", "/api/vpn/logicals", headers=headers)
response = connection.getresponse()

servers = json.loads(response.read().decode())["LogicalServers"]

for s in servers:
    feat = [\
    "SecureCore" if s["Features"] & 1 == 1 else "-SecureCore",\
    "TOR" if s["Features"] & 2 == 2 else "-TOR",\
    "P2P" if s["Features"] & 4 == 4 else "-P2P",\
    "XOR" if s["Features"] & 8 == 8 else "-XOR",\
    "IPv6" if s["Features"] & 16 == 16 else "-IPv6"\
    ]
    if (not s["EntryCountry"] in selected_countries and not s["ExitCountry"] in selected_countries) or s["Tier"] != selected_tier:
        continue
    if len(list(filter(lambda sf: not (sf in feat), selected_features))) > 0:
        continue
    print("- Server", s["Name"])
    print("  > ID:", s["ID"])
    print("  > EntryCountry:", s["EntryCountry"])
    print("  > ExitCountry:", s["ExitCountry"])
    print("  > Tier:", s["Tier"])
    print("  > Features:")
    print("      - SecureCore:", "Y" if s["Features"] & 1 == 1 else "N")
    print("      - Tor:", "Y" if s["Features"] & 2 == 2 else "N")
    print("      - P2P:", "Y" if s["Features"] & 4 == 4 else "N")
    print("      - XOR:", "Y" if s["Features"] & 8 == 8 else "N")
    print("      - IPv6:", "Y" if s["Features"] & 16 == 16 else "N")
    print("  > Score:", s["Score"])
    print("  > Load:", s["Load"])
    print("  > Status:", s["Status"])
    print("  > Instance:")
    for i in s["Servers"]:
        print("    - Instance n°",i["Label"],":", i["ID"])
        print("      > EntryIP:", i["EntryIP"])
        print("      > ExitIP:", i["ExitIP"])
        print("      > Domain:", i["Domain"])
        print("      > X25519PublicKey:", i["X25519PublicKey"])
    if not listing_only:
        keys = generateKeys()
        reg = registerConfig(s, keys)
        config = generateConfig(keys, reg)
        write_config_to_disk(reg["DeviceName"], config)
        max_servers-=1
    if (max_servers <= 0):
        break

connection.close()
```

Sorry, something went wrong.


### Uh oh!

There was an error while loading. [Please reload this page](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a).

[![@gavine99](https://avatars.githubusercontent.com/u/63904295?s=80&v=4)](https://gist.github.com/gavine99)

### **[gavine99](https://gist.github.com/gavine99)**     commented    [on May 14, 2025May 15, 2025](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=5580692\#gistcomment-5580692)


Copy link


Copy Markdown

[@fusetim](https://github.com/fusetim) thanks for this script which i used a while back.

i've developed a python script that uses proton's public code to authenticate and access api's and fully automates rather than using headless browsers.

it was originally based on [https://github.com/elfkuzco/protonvpn-wireguard-config-downloader](https://github.com/elfkuzco/protonvpn-wireguard-config-downloader).

it's at [https://gist.github.com/gavine99/30b429f784328e632cc5ac0ecc5725f8](https://gist.github.com/gavine99/30b429f784328e632cc5ac0ecc5725f8) and includes instructions at the top for putting it together.

it has a bunch of cmdline options. -h to see full help.

i'm not a python dev but i'm happy to receive feedback or pr's.

Sorry, something went wrong.


### Uh oh!

There was an error while loading. [Please reload this page](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a).

[![@peterjumper](https://avatars.githubusercontent.com/u/58781837?s=80&v=4)](https://gist.github.com/peterjumper)

### **[peterjumper](https://gist.github.com/peterjumper)**     commented    [on Sep 4, 2025Sep 4, 2025](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=5746536\#gistcomment-5746536)


Copy link


Copy Markdown

thanks for your info and effort

Sorry, something went wrong.


### Uh oh!

There was an error while loading. [Please reload this page](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a).

[![@sputnick-dev](https://avatars.githubusercontent.com/u/367413?s=80&v=4)](https://gist.github.com/sputnick-dev)

### **[sputnick-dev](https://gist.github.com/sputnick-dev)**     commented    [on Sep 9, 2025Sep 9, 2025](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=5752533\#gistcomment-5752533)


Copy link


Copy Markdown

> i'm not a python dev but i'm happy to receive feedback or pr's.

You made a very great job! GG

Sorry, something went wrong.


### Uh oh!

There was an error while loading. [Please reload this page](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a).

[![@catthou](https://avatars.githubusercontent.com/u/5198243?s=80&v=4)](https://gist.github.com/catthou)

### **[catthou](https://gist.github.com/catthou)**     commented    [on Oct 4, 2025Oct 5, 2025](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=5787467\#gistcomment-5787467)•   edited      Loading          \#\#\# Uh oh!        There was an error while loading. [Please reload this page](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a).


Copy link


Copy Markdown

Does this still work? ~~I'm having trouble finding the necessary header data to fill out the settings.~~ Chromium is weird about when and how it shows some things...

Can I leave the countries blank to generate for all of them or do I have to manually fill it out with every country?

Sorry, something went wrong.


### Uh oh!

There was an error while loading. [Please reload this page](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a).

[![@neovimium](https://avatars.githubusercontent.com/u/202007550?s=80&v=4)](https://gist.github.com/neovimium)

### **[neovimium](https://gist.github.com/neovimium)**     commented    [on Jan 23Jan 24, 2026](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a?permalink_comment_id=5953441\#gistcomment-5953441)


Copy link


Copy Markdown

Made this a while ago.

[https://github.com/neovimium/protonvpn-keygen](https://github.com/neovimium/protonvpn-keygen)

Pretty cool read if you're into cryptography, but also applies to this.

Sorry, something went wrong.


### Uh oh!

There was an error while loading. [Please reload this page](https://gist.github.com/fusetim/1a1ee1bdf821a45361f346e9c7f41e5a).

[Sign up for free](https://gist.github.com/join?source=comment-gist) **to join this conversation on GitHub**.
Already have an account?
[Sign in to comment](https://gist.github.com/login?return_to=https%3A%2F%2Fgist.github.com%2Ffusetim%2F1a1ee1bdf821a45361f346e9c7f41e5a)

You can’t perform that action at this time.