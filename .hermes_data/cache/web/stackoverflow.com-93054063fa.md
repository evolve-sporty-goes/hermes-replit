The 2026 Annual Developer Survey is live—
[take the Survey today!](https://take.survey.stackoverflow.co/jfe/form/SV_4GHunpL3IfJ3rRc?utm_medium=referral&utm_source=stackoverflow-community&utm_campaign=dev-survey-2026&utm_content=announcement-banner)

[dismiss](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line# "dismiss")

##### Collectives™ on Stack Overflow

Find centralized, trusted content and collaborate around the technologies you use most.

[Learn more about Collectives](https://stackoverflow.com/collectives)

**Stack Internal**

Knowledge at work

Bring the best of human thought and AI automation together at your work.

[Explore Stack Internal](https://stackoverflow.co/internal/?utm_medium=referral&utm_source=stackoverflow-community&utm_campaign=side-bar&utm_content=explore-teams-compact-popover)

# [firefox proxy settings via command line](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line)

[Ask Question](https://stackoverflow.com/questions/ask)

Asked17 years, 1 month ago

Modified [2 years, 6 months ago](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line?lastactivity "2023-12-23 10:01:27Z")

Viewed
167k times


This question shows research effort; it is useful and clear

48

This question does not show any research effort; it is unclear or not useful

Save this question.

[Timeline](https://stackoverflow.com/posts/843340/timeline)

Show activity on this post.

How do I change Firefox Proxy settings via command line on windows xp/2k?

Thanks

- [firefox](https://stackoverflow.com/questions/tagged/firefox "show questions tagged 'firefox'")
- [command-line](https://stackoverflow.com/questions/tagged/command-line "show questions tagged 'command-line'")

[Share](https://stackoverflow.com/q/843340)

Share a link to this question

Copy link [CC BY-SA 2.5](https://creativecommons.org/licenses/by-sa/2.5/ "The current license for this post: CC BY-SA 2.5")

Short permalink to this question

[Improve this question](https://stackoverflow.com/posts/843340/edit "")

Follow



Follow this question to receive notifications

[edited Sep 9, 2009 at 19:08](https://stackoverflow.com/posts/843340/revisions "show all edits to this post")

[![Guss's user avatar](https://www.gravatar.com/avatar/21a10c379a9dfc3284a4a75edb933745?s=64&d=identicon&r=PG)](https://stackoverflow.com/users/53538/guss)

[Guss](https://stackoverflow.com/users/53538/guss)

32.9k2020 gold badges118118 silver badges143143 bronze badges

asked May 9, 2009 at 13:35

[![bluegene's user avatar](https://www.gravatar.com/avatar/775325d3860ad6d03b8add6afb9e0757?s=64&d=identicon&r=PG)](https://stackoverflow.com/users/1175964/bluegene)

[bluegene](https://stackoverflow.com/users/1175964/bluegene)

5,79788 gold badges2929 silver badges1818 bronze badges

1

- Does the requirement for XP or 2K remain, or should that be removed?



beedell.roke\_julian\_lockhart


–
[beedell.roke\_julian\_lockhart](https://stackoverflow.com/users/9731176/beedell-roke-julian-lockhart "393 reputation")



2025-01-23 16:35:53 +00:00

[CommentedJan 23, 2025 at 16:35](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line#comment139990165_843340)


[Add a comment](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line# "Use comments to ask for more information or suggest improvements. Avoid answering questions in comments.") \| [Expand to show all comments on this post](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line# "Expand to show all comments on this post")

## 18 Answers 18

Sorted by:
[Reset to default](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line?answertab=scoredesc#tab-top)

Highest score (default)

Trending (recent votes count more)

Date modified (newest first)

Date created (oldest first)


This answer is useful

19

This answer is not useful

Save this answer.

Loading when this answer was accepted…

[Timeline](https://stackoverflow.com/posts/843366/timeline)

Show activity on this post.

The proxy setting is stored in the user's `prefs.js` file in their Firefox profile.

The path to the Firefox profile directory and the file is:

```
%APPDATA%\Mozilla\Firefox\Profiles\7b9ja6xv.default\prefs.js
```

where "`7b9ja6xv`" is a random string. However, the directory of the default profile always ends in ".default". Most of the time there will be only one profile anyway.

Setting you are after are named "`network.proxy.http`" and "`network.proxy.http_port`".

Now it depends on what technology you are able/prepared to use to change the file.

P.S.: If this is about changing the proxy settings of a group of users via the logon script or similar, I recommend looking into the possibility of using the automatic proxy discovery ( [WPAD](http://en.wikipedia.org/wiki/Web_Proxy_Autodiscovery_Protocol)) mechanism. You would never have to change proxy configuration on a user machine again.

[Share](https://stackoverflow.com/a/843366)

Share a link to this answer

Copy link [CC BY-SA 2.5](https://creativecommons.org/licenses/by-sa/2.5/ "The current license for this post: CC BY-SA 2.5")

Short permalink to this answer

[Improve this answer](https://stackoverflow.com/posts/843366/edit "")

Follow



Follow this answer to receive notifications

answered May 9, 2009 at 13:51

[![Tomalak's user avatar](https://www.gravatar.com/avatar/0ada184c98bf9073d15b2dc815be0170?s=64&d=identicon&r=PG)](https://stackoverflow.com/users/18771/tomalak)

[Tomalak](https://stackoverflow.com/users/18771/tomalak)

340k6868 gold badges548548 silver badges636636 bronze badges

Sign up to request clarification or add additional context in comments.


## 1 Comment

Add a comment

[![](https://i.sstatic.net/SSEmv.jpg?s=64)](https://stackoverflow.com/users/594137/samuel-harmer)

Samuel Harmer

[Samuel Harmer](https://stackoverflow.com/users/594137/samuel-harmer) [Over a year ago](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line#comment38508425_843366)

Even with WPAD you need to change `network.proxy.type`. See my answer [below](http://stackoverflow.com/a/24807333/594137).

2014-07-17T15:59:10.923Z+00:00

0

Reply

- Copy link

This answer is useful

10

This answer is not useful

Save this answer.

Loading when this answer was accepted…

[Timeline](https://stackoverflow.com/posts/843364/timeline)

Show activity on this post.

I don't think you can. What you can do, however, is create different profiles for each proxy setting, and use the following command to switch between profiles when running Firefox:

```
firefox -no-remote -P <profilename>
```

[Share](https://stackoverflow.com/a/843364)

Share a link to this answer

Copy link [CC BY-SA 2.5](https://creativecommons.org/licenses/by-sa/2.5/ "The current license for this post: CC BY-SA 2.5")

Short permalink to this answer

[Improve this answer](https://stackoverflow.com/posts/843364/edit "")

Follow



Follow this answer to receive notifications

answered May 9, 2009 at 13:50

[![Ayman Hourieh's user avatar](https://www.gravatar.com/avatar/9430c2f290372174f5c818a318e14ed8?s=64&d=identicon&r=PG)](https://stackoverflow.com/users/40005/ayman-hourieh)

[Ayman Hourieh](https://stackoverflow.com/users/40005/ayman-hourieh)

140k2323 gold badges149149 silver badges116116 bronze badges

## Comments

Add a comment

This answer is useful

10

This answer is not useful

Save this answer.

Loading when this answer was accepted…

[Timeline](https://stackoverflow.com/posts/2509088/timeline)

Show activity on this post.

Just wanted to post the code in a cleaner format... originally posted by sam3344920

```
cd /D "%APPDATA%\Mozilla\Firefox\Profiles"
cd *.default
set ffile=%cd%
echo user_pref("network.proxy.http", "148.233.229.235 ");>>"%ffile%\prefs.js"
echo user_pref("network.proxy.http_port", 3128);>>"%ffile%\prefs.js"
echo user_pref("network.proxy.type", 1);>>"%ffile%\prefs.js"
set ffile=
cd %windir%
```

* * *

If someone wants to **remove** the proxy settings, here is some code that will do that for you.

```
cd /D "%APPDATA%\Mozilla\Firefox\Profiles"
cd *.default
set ffile=%cd%
type "%ffile%\prefs.js" | findstr /v "user_pref("network.proxy.type", 1);" >"%ffile%\prefs_.js"
rename "%ffile%\prefs.js" "prefs__.js"
rename "%ffile%\prefs_.js" "prefs.js"
del "%ffile%\prefs__.js"
set ffile=
cd %windir%
```

**Explanation:** The code goes and finds the perfs.js file. Then looks within it to find the line _"user\_pref("network.proxy.type", 1);"_. If it finds it, it deletes the file with the /v parameter. The reason I added the rename and delete lines is because I couldn't find a way to overwrite the file once I had removed the proxy line. I'm sure there is a more _efficient/safer_ way of doing this...

[Share](https://stackoverflow.com/a/2509088)

Share a link to this answer

Copy link [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/ "The current license for this post: CC BY-SA 4.0")

Short permalink to this answer

[Improve this answer](https://stackoverflow.com/posts/2509088/edit "")

Follow



Follow this answer to receive notifications

[edited Dec 31, 2020 at 20:05](https://stackoverflow.com/posts/2509088/revisions "show all edits to this post")

community wiki


[2 revs, 2 users 98%](https://stackoverflow.com/posts/2509088/revisions "show revision history for this post") [xBoarder](https://stackoverflow.com/users/300902)

## 2 Comments

Add a comment

[![](https://www.gravatar.com/avatar/4370a05bf8c61b236548f70380eb8230?s=48&d=identicon&r=PG)](https://stackoverflow.com/users/25782/martin)

Martin

[Martin](https://stackoverflow.com/users/25782/martin) [Over a year ago](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line#comment46473376_2509088)

I never knew that something like `cd *.default*` is possible -- Even better: `pushd %APPDATA%\Mozilla\Firefox\Profiles\*.default*` works too.

2015-03-18T13:37:38.983Z+00:00

3

Reply

- Copy link

[![](https://i.sstatic.net/i5Yge.png?s=64)](https://stackoverflow.com/users/2480481/m3nda)

m3nda

[m3nda](https://stackoverflow.com/users/2480481/m3nda) [Over a year ago](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line#comment75311616_2509088)

@xBoarder What you do when you need the string available to sed again, is to just comment it. Add more, don't remove. ie: `user_pref("network.proxy.type", 1);`. Also, instead of remove you can just set `network.proxy.type` to direct connection.

2017-05-24T00:28:06.483Z+00:00

0

Reply

- Copy link

This answer is useful

5

This answer is not useful

Save this answer.

Loading when this answer was accepted…

[Timeline](https://stackoverflow.com/posts/1049895/timeline)

Show activity on this post.

The easiest way to do this is to configure your Firefox to use a PAC with a file URL, and then change the file URL from the line command before you start Firefox.

This is the easiest way. You don't have to write a script that remembers what path to prefs.js is (which might change over time).

You configure your profile once, and then you edit the external file whenever you want.

[Share](https://stackoverflow.com/a/1049895)

Share a link to this answer

Copy link [CC BY-SA 2.5](https://creativecommons.org/licenses/by-sa/2.5/ "The current license for this post: CC BY-SA 2.5")

Short permalink to this answer

[Improve this answer](https://stackoverflow.com/posts/1049895/edit "")

Follow



Follow this answer to receive notifications

answered Jun 26, 2009 at 15:52

[![benc's user avatar](https://www.gravatar.com/avatar/f3bfbe6f862c6a104cc9196c1270fe10?s=64&d=identicon&r=PG)](https://stackoverflow.com/users/2910/benc)

[benc](https://stackoverflow.com/users/2910/benc)

2,11855 gold badges3535 silver badges4444 bronze badges

## 5 Comments

Add a comment

[![](https://i.sstatic.net/i5Yge.png?s=64)](https://stackoverflow.com/users/2480481/m3nda)

m3nda

[m3nda](https://stackoverflow.com/users/2480481/m3nda) [Over a year ago](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line#comment45927647_1049895)

change the file URL from the line command before you start Firefox -> Please explain yourself or put a code example.

2015-03-03T09:55:50.89Z+00:00

5

Reply

- Copy link

user4466350

user4466350 [Over a year ago](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line#comment108356418_1049895)

Can you further detail what is a PAC file and what should be done. I am also interested into how to start a new web session. I dont want that firefox ignores the new process because it is already running and open a new tab instead.

2020-04-16T12:46:48.607Z+00:00

0

Reply

- Copy link

[![](https://www.gravatar.com/avatar/f3bfbe6f862c6a104cc9196c1270fe10?s=48&d=identicon&r=PG)](https://stackoverflow.com/users/2910/benc)

benc

[benc](https://stackoverflow.com/users/2910/benc) [Over a year ago](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line#comment108412783_1049895)

This question is so old, I'll put my response in comments: Save the PAC file you want to disk. Then view it in the browser, this will force the creation of a correct file URL in the location bar. Copy this value, go to your browser proxy preferences, select PAC file, and paste in that URL (rather than using a more standard `http:` or `https:` URL.

2020-04-18T00:07:40.683Z+00:00

0

Reply

- Copy link

[![](https://www.gravatar.com/avatar/f3bfbe6f862c6a104cc9196c1270fe10?s=48&d=identicon&r=PG)](https://stackoverflow.com/users/2910/benc)

benc

[benc](https://stackoverflow.com/users/2910/benc) [Over a year ago](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line#comment108412799_1049895)

re: what is a PAC file -> [developer.mozilla.org/en-US/docs/Web/HTTP/…](https://developer.mozilla.org/en-US/docs/Web/HTTP/Proxy_servers_and_tunneling/Proxy_Auto-Configuration_(PAC)_file)

2020-04-18T00:08:53.33Z+00:00

0

Reply

- Copy link

[![](https://www.gravatar.com/avatar/f3bfbe6f862c6a104cc9196c1270fe10?s=48&d=identicon&r=PG)](https://stackoverflow.com/users/2910/benc)

benc

[benc](https://stackoverflow.com/users/2910/benc) [Over a year ago](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line#comment108412803_1049895)

re: web session -> should that be a different question?

2020-04-18T00:09:17.037Z+00:00

0

Reply

- Copy link

Add a comment

This answer is useful

3

This answer is not useful

Save this answer.

Loading when this answer was accepted…

[Timeline](https://stackoverflow.com/posts/2518406/timeline)

Show activity on this post.

> cd /D
> "%APPDATA%\\Mozilla\\Firefox\\Profiles"
> cd \*.default set ffile=%cd% echo
> user\_pref("network.proxy.http",
> "%1");>>"%ffile%\\prefs.js" echo
> user\_pref("network.proxy.http\_port",
> 3128);>>"%ffile%\\prefs.js" echo
> user\_pref("network.proxy.type",
> 1);>>"%ffile%\\prefs.js" set ffile= cd
> %windir%

This is nice ! Thanks for writing this. I needed this exact piece of code for Windows. My goal was to do this by learning to do it with Linux first and then learn the Windows shell which I was not happy about having to do so you saved me some time!

My Linux version is at the bottom of this post. I've been experimenting with which file to insert the prefs into. It seems picky. First I tried in ~/.mozilla/firefox/\*.default/prefs.js but it didn't load very well. The about:config screen never showed my changes. Currently I've been trying to edit the actual Firefox defaults file. If someone has the knowledge off the top of their head could they rewrite the Windows code to only add the lines if they're not already in there? I have no idead how to do sed/awk stuff in Windows without installing Cygwin first.

The only change I was able to make to the Windows scripts is above in the quoted part. I change the IP to %1 so when you call the script from the command line you can give it an option instead of having to change the file.

```
#!/bin/bash
version="`firefox -v | awk '{print substr($3,1,3)}'`"
echo $version " is the version."
# Insert an ip into firefox for the proxy if there isn't one
if
! grep network.proxy.http /etc/firefox-$version/pref/firefox.js
  then echo 'pref("network.proxy.http", "'"$1"'")";' >> /etc/firefox-$version/pref/firefox.js
fi

# Even if there is change it to what we want
sed -i s/^.*network.proxy.http\".*$/'pref("network.proxy.http", "'"$1"')";'/  /etc/firefox-$version/pref/firefox.js

# Set the port
if ! grep network.proxy.http_port /etc/firefox-$version/pref/firefox.js
  then echo 'pref("network.proxy.http_port", 9980);' >> /etc/firefox-$version/pref/firefox.js
  else sed -i s/^.*network.proxy.http_port.*$/'pref("network.proxy.http_port", 9980);'/ /etc/firefox-$version/pref/firefox.js
fi

# Turn on the proxy
if ! grep network.proxy.type  /etc/firefox-$version/pref/firefox.js
  then echo 'pref("network.proxy.type", 1);' >> /etc/firefox-$version/pref/firefox.js
  else sed -i s/^.*network.proxy.type.*$/'pref("network.proxy.type", 1)";'/ /etc/firefox-$version/pref/firefox.js
fi
```

[Share](https://stackoverflow.com/a/2518406)

Share a link to this answer

Copy link [CC BY-SA 2.5](https://creativecommons.org/licenses/by-sa/2.5/ "The current license for this post: CC BY-SA 2.5")

Short permalink to this answer

[Improve this answer](https://stackoverflow.com/posts/2518406/edit "")

Follow



Follow this answer to receive notifications

answered Mar 25, 2010 at 18:43

[![johnny2k's user avatar](https://www.gravatar.com/avatar/82054f07237b57545420f7b8b20feb37?s=64&d=identicon&r=PG)](https://stackoverflow.com/users/301992/johnny2k)

[johnny2k](https://stackoverflow.com/users/301992/johnny2k)

5311 silver badge55 bronze badges

## 4 Comments

Add a comment

[![](https://i.sstatic.net/i5Yge.png?s=64)](https://stackoverflow.com/users/2480481/m3nda)

m3nda

[m3nda](https://stackoverflow.com/users/2480481/m3nda) [Over a year ago](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line#comment75311656_2518406)

sed rocks. To avoid that, there's an Firefox extension that allows firefox to get global variable `http_proxy=http://localhost:8080` in example. You don't need to `export`, just to prepend it to comand. In example Chrome works out of the box using `http_proxy=http://some-proxy-ip:port chrome httpbin.org/ip`. I don't know why is that not handled by firefox.

2017-05-24T00:31:12.003Z+00:00

0

Reply

- Copy link

[![](https://i.sstatic.net/i5Yge.png?s=64)](https://stackoverflow.com/users/2480481/m3nda)

m3nda

[m3nda](https://stackoverflow.com/users/2480481/m3nda) [Over a year ago](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line#comment75311692_2518406)

Adding few $@ arguments to that script will perform ok, also to support other than just default proxy file :-)

2017-05-24T00:33:50.91Z+00:00

0

Reply

- Copy link

[![](https://www.gravatar.com/avatar/8e9da6a355863beeaa5994f8ed098be5?s=48&d=identicon&r=PG)](https://stackoverflow.com/users/236610/rick-van-der-zwet)

Rick van der Zwet

[Rick van der Zwet](https://stackoverflow.com/users/236610/rick-van-der-zwet) [Over a year ago](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line#comment86804631_2518406)

@erm3nda could you specify the extension you are referring too?

2018-04-18T08:20:44.487Z+00:00

0

Reply

- Copy link

[![](https://i.sstatic.net/i5Yge.png?s=64)](https://stackoverflow.com/users/2480481/m3nda)

m3nda

[m3nda](https://stackoverflow.com/users/2480481/m3nda) [Over a year ago](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line#comment86828684_2518406)

@RickvanderZwet The extension is using environment variables. Here it is: [addons.mozilla.org/es/firefox/addon/environment-proxy](https://addons.mozilla.org/es/firefox/addon/environment-proxy/). I didn't check if it's supported with the new and standard extensions.

2018-04-18T18:17:13.573Z+00:00

0

Reply

- Copy link

Add a comment

This answer is useful

3

This answer is not useful

Save this answer.

Loading when this answer was accepted…

[Timeline](https://stackoverflow.com/posts/30152218/timeline)

Show activity on this post.

```
it working perfect.

cd /D "%APPDATA%\Mozilla\Firefox\Profiles"
cd *.default
set ffile=%cd%
echo user_pref("network.proxy.ftp", "YOUR_PROXY_SERVER"); >>prefs.js
echo user_pref("network.proxy.ftp_port", YOUR_PROXY_PORT); >>prefs.js
echo user_pref("network.proxy.http", "YOUR_PROXY_SERVER"); >>prefs.js
echo user_pref("network.proxy.http_port", YOUR_PROXY_PORT); >>prefs.js
echo user_pref("network.proxy.share_proxy_settings", true); >>prefs.js
echo user_pref("network.proxy.socks", "YOUR_PROXY_SERVER"); >>prefs.js
echo user_pref("network.proxy.socks_port", YOUR_PROXY_PORT); >>prefs.js
echo user_pref("network.proxy.ssl", "YOUR_PROXY_SERVER"); >>prefs.js
echo user_pref("network.proxy.ssl_port", YOUR_PROXY_PORT); >>prefs.js
echo user_pref("network.proxy.type", 1); >>prefs.js
set ffile=
cd %windir%
```

[Share](https://stackoverflow.com/a/30152218)

Share a link to this answer

Copy link [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/ "The current license for this post: CC BY-SA 3.0")

Short permalink to this answer

[Improve this answer](https://stackoverflow.com/posts/30152218/edit "")

Follow



Follow this answer to receive notifications

answered May 10, 2015 at 13:51

[![user220579's user avatar](https://www.gravatar.com/avatar/d569984b519616383ca587dd6ad254c0?s=64&d=identicon&r=PG&f=y&so-version=2)](https://stackoverflow.com/users/4884457/user220579)

[user220579](https://stackoverflow.com/users/4884457/user220579)

3122 bronze badges

## Comments

Add a comment

This answer is useful

2

This answer is not useful

Save this answer.

Loading when this answer was accepted…

[Timeline](https://stackoverflow.com/posts/33047138/timeline)

Show activity on this post.

I needed to set an additional option to allow SSO passthrough to our intranet site. I added some code to an example above.

```
pushd "%APPDATA%\Mozilla\Firefox\Profiles\*.default"
echo user_pref("network.proxy.type", 4);>>prefs.js
echo user_pref("network.automatic-ntlm-auth.trusted-uris","site.domain.com, sites.domain.com");>>prefs.js
popd
```

[Share](https://stackoverflow.com/a/33047138)

Share a link to this answer

Copy link [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/ "The current license for this post: CC BY-SA 3.0")

Short permalink to this answer

[Improve this answer](https://stackoverflow.com/posts/33047138/edit "")

Follow



Follow this answer to receive notifications

answered Oct 9, 2015 at 21:02

[![Matt Hill's user avatar](https://www.gravatar.com/avatar/7b1b97c0c2d797a5d5090dc5fd8e6d01?s=64&d=identicon&r=PG&f=y&so-version=2)](https://stackoverflow.com/users/3976403/matt-hill)

[Matt Hill](https://stackoverflow.com/users/3976403/matt-hill)

4666 bronze badges

## Comments

Add a comment

This answer is useful

2

This answer is not useful

Save this answer.

Loading when this answer was accepted…

[Timeline](https://stackoverflow.com/posts/55147773/timeline)

Show activity on this post.

user.js is better for customizations as you can include only the lines you want to manipulate, i.e. instead of find-replace you can just overwrite the entire file. Also, prefs.js (at least on Firefox 65.0.1 for Mac) starts with a warning:

```javascript
Copy
// DO NOT EDIT THIS FILE.
//
// If you make changes to this file while the application is running,
// the changes will be overwritten when the application exits.
//
// To change a preference value, you can either:
// - modify it via the UI (e.g. via about:config in the browser); or
// - set it within a user.js file in your profile.
```

In my case, user.js didn't exist, so I created it and included the line to switch between "No proxy" and "Manual proxy configuration" (I'm using only one SOCKS proxy all the time, so no need to change port number or any other details, just flip 0 to 1 in the following line):

`user_pref("network.proxy.type", 1);`

I ended up with a bash script that I placed at /usr/local/bin/firefox:

```bash
Copy
#!/bin/bash
if [ $# -eq 0 ]; then
  echo 'user_pref("network.proxy.type", 0);' > ~/Library/Application\ Support/Firefox/Profiles/t5rvw47o.default/user.js
  open -a Firefox
else
  case $1 in
    vpn)
      echo 'user_pref("network.proxy.type", 1);' > ~/Library/Application\ Support/Firefox/Profiles/t5rvw47o.default/user.js
      open -a Firefox
  esac
fi
```

To use it, I make sure no Firefox is running and then run `firefox` to have a straight connection and `firefox vpn` to use proxy.

[Share](https://stackoverflow.com/a/55147773)

Share a link to this answer

Copy link [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/ "The current license for this post: CC BY-SA 4.0")

Short permalink to this answer

[Improve this answer](https://stackoverflow.com/posts/55147773/edit "")

Follow



Follow this answer to receive notifications

answered Mar 13, 2019 at 17:17

[![Koit Saarevet's user avatar](https://i.sstatic.net/WzFkW.png?s=64)](https://stackoverflow.com/users/3137513/koit-saarevet)

[Koit Saarevet](https://stackoverflow.com/users/3137513/koit-saarevet)

4133 bronze badges

## Comments

Add a comment

This answer is useful

2

This answer is not useful

Save this answer.

Loading when this answer was accepted…

[Timeline](https://stackoverflow.com/posts/56684680/timeline)

Show activity on this post.

This is the final compiled solution which worked for me... Tried and tested...

# Steps to Change Proxy settings in Mozilla Firefox via cmd in Windows

1. cd /D "%APPDATA%\\Mozilla\\Firefox\\Profiles"
2. cd \*.default

# To Replace Already Present Proxy Settings with User-defined ones

3. powershell -Command "(gc prefs.js) -replace 'user\_pref(\\"network.proxy.http\\", \\" _already present IP_\\")\\;', 'user\_pref(\\"network.proxy.http\\", \\" _your http proxy ip_\\");' \| Set-Content prefs.js"
4. powershell -Command "(gc prefs.js) -replace 'user\_pref(\\"network.proxy.http\_port\\", _already present port_)\\;', 'user\_pref(\\"network.proxy.http\_port\\", _your http proxy port_);' \| Set-Content prefs.js"
5. powershell -Command "(gc prefs.js) -replace 'user\_pref(\\"network.proxy.share\_proxy\_settings\\", _already present value_)\\;', 'user\_pref(\\"network.proxy.share\_proxy\_settings\\", _true_);' \| Set-Content prefs.js"
6. powershell -Command "(gc prefs.js) -replace 'user\_pref(\\"network.proxy.type\\", _already present value_)\\;', 'user\_pref(\\"network.proxy.type\\", _1_);' \| Set-Content prefs.js"


# 0 - No Proxy



# 1 - Manual Proxy Configuration



# 4 - Auto detect Proxy Settings



# 5 - Use System Settings(default)

7. cd %windir%


# To Check Already Present Proxy Settings

8. cd C:\\Users\\{username}\\AppData\\Roaming\\Mozilla\\Firefox\\Profiles\\sat2m7dr.default\
9. find /i "network.proxy" prefs.js

# To Start Firefox from CMD using your defined proxy settings

12. cd C:\\Program Files\
13. cd "Mozilla Firefox"
14. firefox.exe -ProfileManager
15. Select default from the list (default-release is selected by default) and click ok.

NOTE: You may not have to run step 14 again. Instead you can directly run firefox.exe

[Share](https://stackoverflow.com/a/56684680)

Share a link to this answer

Copy link [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/ "The current license for this post: CC BY-SA 4.0")

Short permalink to this answer

[Improve this answer](https://stackoverflow.com/posts/56684680/edit "")

Follow



Follow this answer to receive notifications

[edited Oct 4, 2019 at 8:54](https://stackoverflow.com/posts/56684680/revisions "show all edits to this post")

answered Jun 20, 2019 at 11:08

[![Aditya Bhadalkar's user avatar](https://lh5.googleusercontent.com/-F7S9on855jM/AAAAAAAAAAI/AAAAAAAAAAA/ACHi3reFqKV9JzIpc1yuWY_cM6NUJOqYzg/mo/s64-rj/photo.jpg)](https://stackoverflow.com/users/11662490/aditya-bhadalkar)

[Aditya Bhadalkar](https://stackoverflow.com/users/11662490/aditya-bhadalkar)

2133 bronze badges

## Comments

Add a comment

This answer is useful

2

This answer is not useful

Save this answer.

Loading when this answer was accepted…

[Timeline](https://stackoverflow.com/posts/16886518/timeline)

Show activity on this post.

You can easily launch Firefox from the command line with a proxy server using the -proxy-server option.

This works on Mac, Windows and Linux.

```
path_to_firefox/firefox.exe -proxy-server %proxy_URL%
```

Mac Example:

```
/Applications/Firefox.app/Contents/MacOS/firefox -proxy-server proxy.example.com
```

[Share](https://stackoverflow.com/a/16886518)

Share a link to this answer

Copy link [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/ "The current license for this post: CC BY-SA 4.0")

Short permalink to this answer

[Improve this answer](https://stackoverflow.com/posts/16886518/edit "")

Follow



Follow this answer to receive notifications

[edited Dec 21, 2023 at 21:15](https://stackoverflow.com/posts/16886518/revisions "show all edits to this post")

[![ZahraVanguard's user avatar](https://www.gravatar.com/avatar/b7e32738d8bc0bde2aa5af40b6f8d498?s=64&d=identicon&r=PG)](https://stackoverflow.com/users/18515436/zahravanguard)

[ZahraVanguard](https://stackoverflow.com/users/18515436/zahravanguard)

74922 gold badges77 silver badges1515 bronze badges

answered Jun 2, 2013 at 19:35

[![user2445796's user avatar](https://www.gravatar.com/avatar/9b62264a1daa235e24d0bdaf105be3bd?s=64&d=identicon&r=PG)](https://stackoverflow.com/users/2445796/user2445796)

[user2445796](https://stackoverflow.com/users/2445796/user2445796)

3711 bronze badge

## 3 Comments

Add a comment

[![](https://i.sstatic.net/5DqYq.jpg?s=64)](https://stackoverflow.com/users/126229/ericlaw)

EricLaw

[EricLaw](https://stackoverflow.com/users/126229/ericlaw) [Over a year ago](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line#comment25882262_16886518)

This is not a documented option and doesn't work in Linux at least.

2013-07-19T16:18:53.11Z+00:00

3

Reply

- Copy link

[![](https://i.sstatic.net/i5Yge.png?s=64)](https://stackoverflow.com/users/2480481/m3nda)

m3nda

[m3nda](https://stackoverflow.com/users/2480481/m3nda) [Over a year ago](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line#comment84948684_16886518)

@EricLaw There's an extension to tell Firefox to read `http_proxy` env variable, so you can simply chain it by `http_proxy="http://midomain:port" firefox google.com` as example. Finally, you can make use of gsettings package, which let you set anything "globally" using `gsettings set org.gnome.system.proxy`. See here ( [dpaste.com/3BE8YK1](http://dpaste.com/3BE8YK1)) a full example extracted from Fiddler's attach.script for Linux.

2018-02-25T08:42:24.57Z+00:00

0

Reply

- Copy link

[![](https://www.gravatar.com/avatar/ab0ca099294787a7c548d109822438cb?s=48&d=identicon&r=PG&f=y&so-version=2)](https://stackoverflow.com/users/30273494/butwhole)

butwhole

[butwhole](https://stackoverflow.com/users/30273494/butwhole) [Over a year ago](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line#comment140335120_16886518)

i know this is an old answer, just saying it does not work in 2025 (on windows).

2025-04-15T02:23:35.503Z+00:00

0

Reply

- Copy link

Add a comment

This answer is useful

1

This answer is not useful

Save this answer.

Loading when this answer was accepted…

[Timeline](https://stackoverflow.com/posts/24807333/timeline)

Show activity on this post.

All the other answers here explain how to program your proxy settings into Firefox which is what [WPAD](http://en.wikipedia.org/wiki/Web_Proxy_Autodiscovery_Protocol) was invented to do. If you have WPAD configured then just tell Firefox to use it to auto-detect its settings, as you would in the GUI.

![Connection Settings](https://i.sstatic.net/DE266.png)

To do this from a cmd file or command line:

```
pushd "%APPDATA%\Mozilla\Firefox\Profiles\*.default"
echo user_pref("network.proxy.type", 4);>>prefs.js
popd
```

_This of course requires you to have WPAD configured and working correctly. Also I believe `prefs.js` won't exist until you've run Firefox once._

[Share](https://stackoverflow.com/a/24807333)

Share a link to this answer

Copy link [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/ "The current license for this post: CC BY-SA 3.0")

Short permalink to this answer

[Improve this answer](https://stackoverflow.com/posts/24807333/edit "")

Follow



Follow this answer to receive notifications

[edited May 19, 2015 at 20:50](https://stackoverflow.com/posts/24807333/revisions "show all edits to this post")

[![Martin's user avatar](https://www.gravatar.com/avatar/4370a05bf8c61b236548f70380eb8230?s=64&d=identicon&r=PG)](https://stackoverflow.com/users/25782/martin)

[Martin](https://stackoverflow.com/users/25782/martin)

10.9k1414 gold badges6262 silver badges7070 bronze badges

answered Jul 17, 2014 at 15:11

[![Samuel Harmer's user avatar](https://i.sstatic.net/SSEmv.jpg?s=64)](https://stackoverflow.com/users/594137/samuel-harmer)

[Samuel Harmer](https://stackoverflow.com/users/594137/samuel-harmer)

4,44055 gold badges3939 silver badges6868 bronze badges

## Comments

Add a comment

This answer is useful

1

This answer is not useful

Save this answer.

Loading when this answer was accepted…

[Timeline](https://stackoverflow.com/posts/32916668/timeline)

Show activity on this post.

I found a better way to do this with powershell under windows (but really only because I was looking for a way to script changing the user agent string, not muck about with proxies).

```
function set-uas
{
    Param
    (
            [string]$UAS = "Default"
    )

    $FirefoxPrefs = "C:\Users\Admin\AppData\Roaming\Mozilla\Firefox\Profiles\*.default\prefs.js"

    if ($UAS -eq "Default")
    {
        $fileinfo = type $FirefoxPrefs
        $fileinfo = $fileinfo | findstr /v "general.appname.override"
        $fileinfo = $fileinfo | findstr /v "general.appversion.override"
        $fileinfo = $fileinfo | findstr /v "general.platform.override"
        $fileinfo = $fileinfo | findstr /v "general.useragent.appName"
        $fileinfo = $fileinfo | findstr /v "general.useragent.override"
        $fileinfo = $fileinfo | findstr /v "general.useragent.vendor"
        $fileinfo = $fileinfo | findstr /v "general.useragent.vendorSub"
        $fileinfo += "user_pref(`"useragentswitcher.import.overwrite`", false);`n"
        $fileinfo += "user_pref(`"useragentswitcher.menu.hide`", false);`n"
        $fileinfo += "user_pref(`"useragentswitcher.reset.onclose`", false);`n"
        $fileinfo | Out-File -FilePath $FirefoxPrefs -Encoding ASCII
    }
    else
    {
        set-uas Default
    }

    if ($UAS -eq "iphone")
    {
        $fileinfo = ""
        $fileinfo += "user_pref(`"general.appname.override`", `"Netscape`");`n"
        $fileinfo += "user_pref(`"general.appversion.override`", `"5.0 (iPhone; U; CPU iPhone OS 3_0 like Mac OS X; en-us) AppleWebKit/528.18 (KHTML, like Gecko) Version/4.0 Mobile/7A341 Safari/528.16`");`n"
        $fileinfo += "user_pref(`"general.platform.override`", `"iPhone`");`n"
        $fileinfo += "user_pref(`"general.useragent.appName`", `"Mozilla`");`n"
        $fileinfo += "user_pref(`"general.useragent.override`", `"Mozilla/5.0 (iPhone; U; CPU iPhone OS 3_0 like Mac OS X; en-us) AppleWebKit/528.18 (KHTML, like Gecko) Version/4.0 Mobile/7A341 Safari/528.16`");`n"
        $fileinfo += "user_pref(`"general.useragent.vendor`", `"Apple Computer, Inc.`");`n"
        $fileinfo += "user_pref(`"general.useragent.vendorSub`", `"`");`n"
        $fileinfo += "user_pref(`"useragentswitcher.reset.onclose`", false);`n"
        $fileinfo | Out-File -FilePath $FirefoxPrefs -Encoding ASCII -Append
    }
    elseif ($UAS -eq "lumia")
    {
        $fileinfo = ""
        $fileinfo += "user_pref(`"general.appname.override`", `"Netscape`");`n"
        $fileinfo += "user_pref(`"general.appversion.override`", `"9.80 (Windows Phone; Opera Mini/9.0.0/37.6652; U; en) Presto/2.12.423 Version/12.16`");`n"
        $fileinfo += "user_pref(`"general.platform.override`", `"Nokia`");`n"
        $fileinfo += "user_pref(`"general.useragent.appName`", `"Mozilla`");`n"
        $fileinfo += "user_pref(`"general.useragent.override`", `"Opera/9.80 (Windows Phone; Opera Mini/9.0.0/37.6652; U; en) Presto/2.12.423 Version/12.16`");`n"
        $fileinfo += "user_pref(`"general.useragent.vendor`", `"Microsoft`");`n"
        $fileinfo += "user_pref(`"general.useragent.vendorSub`", `"`");`n"
        $fileinfo += "user_pref(`"useragentswitcher.reset.onclose`", false);`n"
        $fileinfo | Out-File -FilePath $FirefoxPrefs -Encoding ASCII -Append
    }
}
```

I have the firefox plugin "useragentswitcher" also installed, and have not tested this without it.

I also have set "user\_pref("useragentswitcher.reset.onclose", false);"

\[EDIT\] I've revised my code, it was occasionally outputting some bad character or something. For some reason this is detected by firefox as a corrupt profile, and the entire profile was discarded, and refreshed with a default profile.

Also, credit where credit is due: this code is loosely based off of what xBoarder posted in his response to sam3344920 ( [https://stackoverflow.com/a/2509088/5403057](https://stackoverflow.com/a/2509088/5403057)). Also, I was able to fix the encoding bug with help from a post from Phoenix14830 ( [https://stackoverflow.com/a/32080395/5403057](https://stackoverflow.com/a/32080395/5403057))

\[Edit2\] Added support for setting the UAS to lumia. This is actually using an Opera mobile UAS, because I still wanted bing to work, and if you use the regular lumia UAS www.bing.com redirects to bing://?%^&\* which firefox doesn't know how to process

[Share](https://stackoverflow.com/a/32916668)

Share a link to this answer

Copy link [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/ "The current license for this post: CC BY-SA 3.0")

Short permalink to this answer

[Improve this answer](https://stackoverflow.com/posts/32916668/edit "")

Follow



Follow this answer to receive notifications

[edited May 23, 2017 at 12:24](https://stackoverflow.com/posts/32916668/revisions "show all edits to this post")

[![Community's user avatar](https://www.gravatar.com/avatar/a007be5a61f6aa8f3e85ae2fc18dd66e?s=64&d=identicon&r=PG)](https://stackoverflow.com/users/-1/community)

[Community](https://stackoverflow.com/users/-1/community) Bot

111 silver badge

answered Oct 2, 2015 at 22:19

[![GarThor's user avatar](https://www.gravatar.com/avatar/e8e6e388a2eeaf71fae72bf209a7b365?s=64&d=identicon&r=PG&f=y&so-version=2)](https://stackoverflow.com/users/5403057/garthor)

[GarThor](https://stackoverflow.com/users/5403057/garthor)

5155 bronze badges

## 1 Comment

Add a comment

[![](https://www.gravatar.com/avatar/e8e6e388a2eeaf71fae72bf209a7b365?s=48&d=identicon&r=PG&f=y&so-version=2)](https://stackoverflow.com/users/5403057/garthor)

GarThor

[GarThor](https://stackoverflow.com/users/5403057/garthor) [Over a year ago](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line#comment53661703_32916668)

hmm... now it seems to be adding a bunch of null's between characters for some strange reason... o\_0

2015-10-02T22:48:37.5Z+00:00

0

Reply

- Copy link

This answer is useful

0

This answer is not useful

Save this answer.

Loading when this answer was accepted…

[Timeline](https://stackoverflow.com/posts/843362/timeline)

Show activity on this post.

I don't think there is a direct way to set the proxy (on Windows).

You could however install an add-on like FoxyProxy, create several configurations for different proxies and prior to starting FireFox move the appropriate configuration to the correct folder in your FireFox profile (using a batch file).

[Share](https://stackoverflow.com/a/843362)

Share a link to this answer

Copy link [CC BY-SA 2.5](https://creativecommons.org/licenses/by-sa/2.5/ "The current license for this post: CC BY-SA 2.5")

Short permalink to this answer

[Improve this answer](https://stackoverflow.com/posts/843362/edit "")

Follow



Follow this answer to receive notifications

answered May 9, 2009 at 13:48

[![Dirk Vollmar's user avatar](https://www.gravatar.com/avatar/ab9833194869e7f99d6e388f4aee76c1?s=64&d=identicon&r=PG)](https://stackoverflow.com/users/40347/dirk-vollmar)

[Dirk Vollmar](https://stackoverflow.com/users/40347/dirk-vollmar)

177k5353 gold badges262262 silver badges318318 bronze badges

## Comments

Add a comment

This answer is useful

0

This answer is not useful

Save this answer.

Loading when this answer was accepted…

[Timeline](https://stackoverflow.com/posts/12872453/timeline)

Show activity on this post.

```
@echo off
color 1F

cd /D "%APPDATA%\Mozilla\Firefox\Profiles"
cd *.default
set ffile=%cd%
cd %ffile%
echo user_pref("network.proxy.http", "192.168.1.235 ");>>"prefs.js"
echo user_pref("network.proxy.http_port", 80);>>"prefs.js"
echo user_pref("network.proxy.type", 1);>>"prefs.js"
set ffile=
cd %windir%
```

[Share](https://stackoverflow.com/a/12872453)

Share a link to this answer

Copy link [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/ "The current license for this post: CC BY-SA 3.0")

Short permalink to this answer

[Improve this answer](https://stackoverflow.com/posts/12872453/edit "")

Follow



Follow this answer to receive notifications

[edited Nov 2, 2012 at 23:41](https://stackoverflow.com/posts/12872453/revisions "show all edits to this post")

answered Oct 13, 2012 at 10:59

[![Logan78's user avatar](https://www.gravatar.com/avatar/fe0132dac71151dcead12bace677a403?s=64&d=identicon&r=PG)](https://stackoverflow.com/users/1743236/logan78)

[Logan78](https://stackoverflow.com/users/1743236/logan78)

3122 bronze badges

## 2 Comments

Add a comment

[![](https://i.sstatic.net/obGLo.jpg?s=64)](https://stackoverflow.com/users/578843/styxxy)

Styxxy

[Styxxy](https://stackoverflow.com/users/578843/styxxy) [Over a year ago](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line#comment17426006_12872453)

Some explanation what you do here might be quite helpful.

2012-10-13T11:07:02.563Z+00:00

0

Reply

- Copy link

[![](https://www.gravatar.com/avatar/58f9ad7e897c4bb5e642b9ae6d895c71?s=48&d=identicon&r=PG)](https://stackoverflow.com/users/471232/massimo)

Massimo

[Massimo](https://stackoverflow.com/users/471232/massimo) [Over a year ago](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line#comment19462040_12872453)

I like to grok CD \*.default, but I suggest to ECHO the three lines on the file user.js : Firefox on start read and merge user.js into prefs.js ( so we don't edit the master configuration file ).

2012-12-28T22:26:25.53Z+00:00

0

Reply

- Copy link

This answer is useful

0

This answer is not useful

Save this answer.

Loading when this answer was accepted…

[Timeline](https://stackoverflow.com/posts/1237256/timeline)

Show activity on this post.

Thank very much, I find the answers in this website.

Here I refer to the production of a cmd file

by minimo

```
cd /D "%APPDATA%\Mozilla\Firefox\Profiles"
cd *.default
set ffile=%cd%
echo user_pref("network.proxy.http", "192.168.1.235 ");>>"%ffile%\prefs.js"
echo user_pref("network.proxy.http_port", 80);>>"%ffile%\prefs.js"
echo user_pref("network.proxy.type", 1);>>"%ffile%\prefs.js"
set ffile=
cd %windir%
```

[Share](https://stackoverflow.com/a/1237256)

Share a link to this answer

Copy link [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/ "The current license for this post: CC BY-SA 3.0")

Short permalink to this answer

[Improve this answer](https://stackoverflow.com/posts/1237256/edit "")

Follow



Follow this answer to receive notifications

[edited Jan 8, 2013 at 9:27](https://stackoverflow.com/posts/1237256/revisions "show all edits to this post")

[![Community's user avatar](https://www.gravatar.com/avatar/a007be5a61f6aa8f3e85ae2fc18dd66e?s=64&d=identicon&r=PG)](https://stackoverflow.com/users/-1/community)

[Community](https://stackoverflow.com/users/-1/community) Bot

111 silver badge

answered Aug 6, 2009 at 6:29

sam3344920


## 1 Comment

Add a comment

sam3344920

sam3344920 [Over a year ago](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line#comment1063212_1237256)

Thank very much, I find the answers in this website. Here I refer to the production of a cmd file by minimo cd /D "%APPDATA%\\Mozilla\\Firefox\\Profiles" cd \*.default set ffile=%cd% echo user\_pref("network.proxy.http", "148.233.229.235 ");>>"%ffile%\\prefs.js" echo user\_pref("network.proxy.http\_port", 3128);>>"%ffile%\\prefs.js" echo user\_pref("network.proxy.type", 1);>>"%ffile%\\prefs.js" set ffile= cd %windir%

2009-08-06T06:30:45.567Z+00:00

0

Reply

- Copy link

This answer is useful

0

This answer is not useful

Save this answer.

Loading when this answer was accepted…

[Timeline](https://stackoverflow.com/posts/14574615/timeline)

Show activity on this post.

for the latest firefox you must change

```
cd *.default
```

to

```
cd *.default*
```

[Share](https://stackoverflow.com/a/14574615)

Share a link to this answer

Copy link [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/ "The current license for this post: CC BY-SA 3.0")

Short permalink to this answer

[Improve this answer](https://stackoverflow.com/posts/14574615/edit "")

Follow



Follow this answer to receive notifications

answered Jan 29, 2013 at 2:17

[![Goon's user avatar](https://www.gravatar.com/avatar/b0375eabad00b3b02f554e99a36c0efb?s=64&d=identicon&r=PG)](https://stackoverflow.com/users/2020159/goon)

[Goon](https://stackoverflow.com/users/2020159/goon)

911 bronze badge

## Comments

Add a comment

This answer is useful

0

This answer is not useful

Save this answer.

Loading when this answer was accepted…

[Timeline](https://stackoverflow.com/posts/11761036/timeline)

Show activity on this post.

You could also use this Powershell script I wrote to do just this, and all other Firefox settings as well.

[https://bitbucket.org/remyservices/powershell-firefoxpref/wiki/Home](https://bitbucket.org/remyservices/powershell-firefoxpref/wiki/Home)

Using this you could easily manage Firefox using computer startup and user logon scripts. See the wiki page for directions on how to use it.

[Share](https://stackoverflow.com/a/11761036)

Share a link to this answer

Copy link [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/ "The current license for this post: CC BY-SA 3.0")

Short permalink to this answer

[Improve this answer](https://stackoverflow.com/posts/11761036/edit "")

Follow



Follow this answer to receive notifications

[edited Oct 7, 2015 at 18:08](https://stackoverflow.com/posts/11761036/revisions "show all edits to this post")

[![Nate Barbettini's user avatar](https://i.sstatic.net/ETGIY.jpg?s=64)](https://stackoverflow.com/users/3191599/nate-barbettini)

[Nate Barbettini](https://stackoverflow.com/users/3191599/nate-barbettini)

54.2k2828 gold badges137137 silver badges153153 bronze badges

answered Aug 1, 2012 at 14:05

[![David Remy's user avatar](https://www.gravatar.com/avatar/5bfb9dfbf0c1fa8a028c672fc5959b37?s=64&d=identicon&r=PG)](https://stackoverflow.com/users/448486/david-remy)

[David Remy](https://stackoverflow.com/users/448486/david-remy)

10111 silver badge22 bronze badges

## 1 Comment

Add a comment

[![](https://i.sstatic.net/7eG9T.png?s=64)](https://stackoverflow.com/users/675721/codebling)

Codebling

[Codebling](https://stackoverflow.com/users/675721/codebling) [Over a year ago](https://stackoverflow.com/questions/843340/firefox-proxy-settings-via-command-line#comment125358098_11761036)

404..is there an updated link?

2022-01-30T01:21:45.227Z+00:00

0

Reply

- Copy link

This answer is useful

-2

This answer is not useful

Save this answer.

Loading when this answer was accepted…

[Timeline](https://stackoverflow.com/posts/55661999/timeline)

Show activity on this post.

Hello I got the Perfect cod use this code

```
cd /D "%APPDATA%\Mozilla\Firefox\Profiles"

cd *.default

set ffile=%cd%

echo user_pref("network.proxy.http", "127.0.0.1"); >>prefs.js

echo user_pref("network.proxy.http_port", 8080); >>prefs.js

set ffile=

cd %windir
```

[Share](https://stackoverflow.com/a/55661999)

Share a link to this answer

Copy link [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/ "The current license for this post: CC BY-SA 4.0")

Short permalink to this answer

[Improve this answer](https://stackoverflow.com/posts/55661999/edit "")

Follow



Follow this answer to receive notifications

[edited Dec 23, 2023 at 10:01](https://stackoverflow.com/posts/55661999/revisions "show all edits to this post")

[![ZahraVanguard's user avatar](https://www.gravatar.com/avatar/b7e32738d8bc0bde2aa5af40b6f8d498?s=64&d=identicon&r=PG)](https://stackoverflow.com/users/18515436/zahravanguard)

[ZahraVanguard](https://stackoverflow.com/users/18515436/zahravanguard)

74922 gold badges77 silver badges1515 bronze badges

answered Apr 13, 2019 at 4:25

[![Banna's user avatar](https://www.gravatar.com/avatar/fde65b8cc73ad73b42529708049b988e?s=64&d=identicon&r=PG&f=y&so-version=2)](https://stackoverflow.com/users/11354526/banna)

[Banna](https://stackoverflow.com/users/11354526/banna)

1

## Comments

Add a comment

## Your Answer

**Reminder:** Answers generated by AI tools are not allowed due to Stack Overflow's [artificial intelligence policy](https://stackoverflow.com/help/gen-ai-policy)

Draft saved

Draft discarded

### Sign up or [log in](https://stackoverflow.com/users/login?ssrc=question_page&returnurl=https%3a%2f%2fstackoverflow.com%2fquestions%2f843340%2ffirefox-proxy-settings-via-command-line%23new-answer)

Sign up using Google


Sign up using Email and Password


Submit

### Post as a guest

Name

Email

Required, but never shown

Post Your Answer

Discard


By clicking “Post Your Answer”, you agree to our [terms of service](https://stackoverflow.com/legal/terms-of-service/public) and acknowledge you have read our [privacy policy](https://stackoverflow.com/legal/privacy-policy).


Start asking to get answers

Find the answer to your question by asking.

[Ask question](https://stackoverflow.com/questions/ask)

Explore related questions

- [firefox](https://stackoverflow.com/questions/tagged/firefox "show questions tagged 'firefox'")
- [command-line](https://stackoverflow.com/questions/tagged/command-line "show questions tagged 'command-line'")

See similar questions with these tags.