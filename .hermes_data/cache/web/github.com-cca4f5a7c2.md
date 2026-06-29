[Skip to content](https://github.com/Lucrehulk/rust-cf-turnstile-bypass#start-of-content)

You signed in with another tab or window. [Reload](https://github.com/Lucrehulk/rust-cf-turnstile-bypass) to refresh your session.You signed out in another tab or window. [Reload](https://github.com/Lucrehulk/rust-cf-turnstile-bypass) to refresh your session.You switched accounts on another tab or window. [Reload](https://github.com/Lucrehulk/rust-cf-turnstile-bypass) to refresh your session.Dismiss alert

{{ message }}

[Lucrehulk](https://github.com/Lucrehulk)/ **[rust-cf-turnstile-bypass](https://github.com/Lucrehulk/rust-cf-turnstile-bypass)** Public

- [Notifications](https://github.com/login?return_to=%2FLucrehulk%2Frust-cf-turnstile-bypass) You must be signed in to change notification settings
- [Fork\\
0](https://github.com/login?return_to=%2FLucrehulk%2Frust-cf-turnstile-bypass)
- [Star\\
3](https://github.com/login?return_to=%2FLucrehulk%2Frust-cf-turnstile-bypass)


main

[**1** Branch](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/branches) [**0** Tags](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/tags)

[Go to Branches page](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/branches)[Go to Tags page](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/tags)

Go to file

Code

Open more actions menu

## Folders and files

| Name | Name | Last commit message | Last commit date |
| --- | --- | --- | --- |
| ## Latest commit<br>[![Lucrehulk](https://avatars.githubusercontent.com/u/97923189?v=4&size=40)](https://github.com/Lucrehulk)[Lucrehulk](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/commits?author=Lucrehulk)<br>[Update README.md](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/commit/72cc72ce8107082289b0a0477bf6bf6cd9a99f92)<br>3 days agoJun 26, 2026<br>[72cc72c](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/commit/72cc72ce8107082289b0a0477bf6bf6cd9a99f92) · 3 days agoJun 26, 2026<br>## History<br>[9 Commits](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/commits/main/) <br>Open commit details<br>[View commit history for this file.](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/commits/main/) 9 Commits |
| [rust-cf-turnstile-bypass](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/tree/main/rust-cf-turnstile-bypass "rust-cf-turnstile-bypass") | [rust-cf-turnstile-bypass](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/tree/main/rust-cf-turnstile-bypass "rust-cf-turnstile-bypass") | [Accidently kept an outdated version of index.js. Updated now to fix b…](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/commit/286a970ba25a0cf540c2e8c5dbb9ce91f4128aea "Accidently kept an outdated version of index.js. Updated now to fix byte structure on packet.") | 3 days agoJun 26, 2026 |
| [LICENSE](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/blob/main/LICENSE "LICENSE") | [LICENSE](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/blob/main/LICENSE "LICENSE") | [Add files via upload](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/commit/f9ad8b2552d138dc9d9e9c35784689e0a8329849 "Add files via upload") | 5 days agoJun 24, 2026 |
| [README.md](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/blob/main/README.md "README.md") | [README.md](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/blob/main/README.md "README.md") | [Update README.md](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/commit/72cc72ce8107082289b0a0477bf6bf6cd9a99f92 "Update README.md") | 3 days agoJun 26, 2026 |
| View all files |

## Repository files navigation

# rust-cf-turnstile-bypass

[Permalink: rust-cf-turnstile-bypass](https://github.com/Lucrehulk/rust-cf-turnstile-bypass#rust-cf-turnstile-bypass)

A proof-of-concept Cloudflare Turnstile bypass system built in Rust. Includes a token harvesting mechanism comprising a widget generator, a Turnstile checkbox clicker, and a token server for receiving and managing solved tokens. No API service required.

* * *

# Pros

[Permalink: Pros](https://github.com/Lucrehulk/rust-cf-turnstile-bypass#pros)

- No API service is required.
- Solver can effectively generate many tokens per minute, even without the use of an API service.
- Data is handled and already managed by a server that makes managing your haverested tokens easy.
- Method is generally effective when you know the website you want to apply it to beforehand.
- The method is relatively firm and not as easy to patch as other bypasses, as it relies on overriding pages to avoid any policies like CORs or any fingerprinting, and the checkbox identifier will work as long as Cloudflare does not drastically change the UI of the widget itself.
- Easy to use and setup, especially compared to certain other bypasses.

## Caveats

[Permalink: Caveats](https://github.com/Lucrehulk/rust-cf-turnstile-bypass#caveats)

- The solver is **not headless** — a GUI is required.
- The method relies on a browser with overrides enabled.
- Uses iframes to create multiple simultaneous solvers.
- Tunneling multiple proxies through each iframe is not supported. Do note this may potentially be added in the future if a feasible solution is found, though. For now, the only solution for multi-proxy support is to spawn multiple windows, and use a browser extension that enables per-window proxies (e.g. FoxyProxy).
- Designed for smaller-scale token harvesting, though the token server architecture does support larger-scale operations.
- Ineffective for general, random web-scraping. Knowing the websites it will be used on is most effective.

* * *

## How It Works

[Permalink: How It Works](https://github.com/Lucrehulk/rust-cf-turnstile-bypass#how-it-works)

The bypass is comprised of four main components:

1. **Token Harvester / Turnstile Widget Loader**
2. **Turnstile Widget Identifier & Clicker**
3. **Token Server**
4. **Extensions** (external utilities that aid our solving).

* * *

### 1\. Token Harvester / Turnstile Widget Loader

[Permalink: 1. Token Harvester / Turnstile Widget Loader](https://github.com/Lucrehulk/rust-cf-turnstile-bypass#1-token-harvester--turnstile-widget-loader)

The Token Harvester loads the Turnstile widget by spawning multiple iframe-based solvers, each pointing at a different Cloudflare site widget. Every solver iframe connects to the token server and forwards any solved tokens to it, and after forwarding a token it also resets the widget and begins solving for another token.

**Setup:**

1. **Configure the files.** Configuration is place in `index.html`:
   - Set `PRELOAD_IFRAMES` (the number of iframe solvers to load on page start), `TOKEN_SERVER_HOST` (your token server host, obviously), and `SITEKEY` (the website's Cloudflare sitekey).
2. **Apply as browser overrides.** Replace the target webpage's main HTML file with `index.html`, and its main JS script with `index.js`. If the site inlines its scripts, you can still override with `index.js` — since `index.html` is also overridden, it will be loaded as a script regardless. If this is not applicable due to say, tricky origin stuff or something of that sort, you can also of course inline the script into the index.html.


**Why overrides?**

Using overrides does require loading the actual page, but it sidesteps issues with CORS policies, TLS fingerprinting, and other browser/address analysis the target site may employ. Because the page loads normally and passes all standard security checks, our modified scripts can generate tokens cleanly without triggering those protections.

* * *

### 2\. Turnstile Clicker

[Permalink: 2. Turnstile Clicker](https://github.com/Lucrehulk/rust-cf-turnstile-bypass#2-turnstile-clicker)

The Turnstile Clicker automatically solves checkbox click challenges. Run the relevant `main.rs` file to start it. The clicker is **disabled by default** — press **F8** to toggle it on or off.

**Setup:**

Set the config values described in `main.rs`. That's all, aside from installing dependencies.

**How it works:**

The clicker identifies Cloudflare Turnstile checkboxes by analyzing pixel RGB values. It searches for pixels matching the characteristic grey ring border of the Turnstile checkbox. Once a candidate pixel is found, it performs a depth-first search (DFS) to verify the pixel forms a closed ring/loop. It then searches inward from all four sides to isolate the whitespace within the border — the actual clickable area. Finally, it dispatches OS-level input events to move the mouse to a point within that region and click.

> **Note:** The F8 toggle exists for good reason. The token harvester page is entirely black and contains nothing that should be falsely detected as a checkbox. However, other pages may produce false positives, so it's recommended to only enable the clicker when the solver page is active.

* * *

### 3\. Token Server

[Permalink: 3. Token Server](https://github.com/Lucrehulk/rust-cf-turnstile-bypass#3-token-server)

The Token Server doesn't participate in solving — it stores and manages the tokens produced by the harvester. Solver iframes forward their tokens here as they're solved.

**Setup:**

Set the `PORT`, and `PROXIES_LIST_LENGTH` values in the config. That's all, aside from dependencies.

**Packet & Protocol Structure:**

_Serverbound (client → server):_

| Header | Description |
| --- | --- |
| `0` | Incoming token + solver id from a sender. The server routes it to the registered receiver socket with the fewest acquired tokens (based on total acquired, not taking into account tokens that were already consumed). Structure: <0, ...sender\_id\_bytes (u32), ...token\_bytes>. |
| `1` | Register the sending socket as a receiver and initialize its receiver status. Send this packet when designing a system to actually allow your infrastructure to acquire the tokens. |
| `2` | Request the total token count. The server responds with the current count. |
| `3` | Request the solver\_idx. The server responds with this window's solver\_idx. Necessary for knowing which proxy solved a challenge in case there are IP checks in place. |

_Clientbound (server → client):_

| Description |
| --- |
| Incoming token + solver id delivered to a receiver. Structure: <...sender\_id\_bytes (u32), ...token\_bytes>. |
| Token count response. Sent directly to the requesting client as u64 LE bytes without a header, since that client only needs this single value and no additional packet types are currently required. |
| Solver\_idx response. Sent directly as u32 LE bytes to the requesting client. |

_Note these packets dote not have headers, as there is only one packet type sent to each endpoint._

* * *

### 4\. Extensions

[Permalink: 4. Extensions](https://github.com/Lucrehulk/rust-cf-turnstile-bypass#4-extensions)

I would recommend a few browser extensions to maximize solving potential:

1. A per-window, advanced browser proxy extension that allows fine-grained control over browser level proxies. A good example of this is FoxyProxy. A system that can rotate a proxy list upon window reload is most important to be compatible for multi-proxy solving with this architecture.
2. A WebRTC API spoofer or blocker. WebRTC can leak your real IP if not careful, so getting a good extension to block this is critical.
3. An advanced user-agent spoofer. This one isn't all that necessary, but if you're looking to maximize anonymity then you'll likely want one of these.

* * *

## Starting It Up

[Permalink: Starting It Up](https://github.com/Lucrehulk/rust-cf-turnstile-bypass#starting-it-up)

1. Start the **token server**.
2. Start your backend, token managing system.
3. Start the **auto-clicker**.
4. Open your **modified webpage**.
5. Press **F8** to enable the auto-clicker.
6. Watch it go.

* * *

## Future Plans (may not be done, but if major updates do occur to this project it will likely be these).

[Permalink: Future Plans (may not be done, but if major updates do occur to this project it will likely be these).](https://github.com/Lucrehulk/rust-cf-turnstile-bypass#future-plans-may-not-be-done-but-if-major-updates-do-occur-to-this-project-it-will-likely-be-these)

An automatic page-loader and harvester setup script may be created in order to aid with multi-proxy solving, as per page loads are currently needed for such.

If a feasible solution is found, a way to tunnel individual iframes (hence enhancing multi-proxy solving outside of just different tabs) may be implemented.

![image](https://private-user-images.githubusercontent.com/97923189/612513870-7e6c9bfb-e720-4c21-a8d6-88b699e5af88.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3ODI3NzI0OTcsIm5iZiI6MTc4Mjc3MjE5NywicGF0aCI6Ii85NzkyMzE4OS82MTI1MTM4NzAtN2U2YzliZmItZTcyMC00YzIxLWE4ZDYtODhiNjk5ZTVhZjg4LnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNjA2MjklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjYwNjI5VDIyMjk1N1omWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTM5Y2M0ZDU2NzY3ZGRmYjg1NDNjNjNmMjg3MTc4YWU1YjhhNjI2M2ZmNjVmNmFlMGI1ODVjMTk4YTgxMjY2ZGYmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0JnJlc3BvbnNlLWNvbnRlbnQtdHlwZT1pbWFnZSUyRnBuZyJ9.3zDlcNRwzti0mjqt4HmF0ogeqWPDZK447Vm5d-ciPjk)

## About

A proof-of-concept Cloudflare Turnstile bypass system built in Rust. Includes a token harvesting mechanism comprising a widget generator, a Turnstile checkbox clicker, and a token server for receiving and managing solved tokens. No API service required.


### Topics

[cloudflare](https://github.com/topics/cloudflare "Topic: cloudflare") [cloudflare-turnstile](https://github.com/topics/cloudflare-turnstile "Topic: cloudflare-turnstile") [cloudflare-turnstile-solver](https://github.com/topics/cloudflare-turnstile-solver "Topic: cloudflare-turnstile-solver") [cloudflare-turnstile-bypass](https://github.com/topics/cloudflare-turnstile-bypass "Topic: cloudflare-turnstile-bypass") [cloudflareturnstile](https://github.com/topics/cloudflareturnstile "Topic: cloudflareturnstile")

### Resources

[Readme](https://github.com/Lucrehulk/rust-cf-turnstile-bypass#readme-ov-file)

### License

[MIT license](https://github.com/Lucrehulk/rust-cf-turnstile-bypass#MIT-1-ov-file)

### Uh oh!

There was an error while loading. [Please reload this page](https://github.com/Lucrehulk/rust-cf-turnstile-bypass).

[Activity](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/activity)

### Stars

[**3**\\
stars](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/stargazers)

### Watchers

[**0**\\
watching](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/watchers)

### Forks

[**0**\\
forks](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/forks)

[Report repository](https://github.com/contact/report-content?content_url=https%3A%2F%2Fgithub.com%2FLucrehulk%2Frust-cf-turnstile-bypass&report=Lucrehulk+%28user%29)

## [Releases](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/releases)

No releases published

## [Packages\  0](https://github.com/users/Lucrehulk/packages?repo_name=rust-cf-turnstile-bypass)

No packages published

## [Contributors\  1](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/graphs/contributors)

- [![@Lucrehulk](https://avatars.githubusercontent.com/u/97923189?s=64&v=4)](https://github.com/Lucrehulk)[**Lucrehulk** Lucrehulk](https://github.com/Lucrehulk)

## Languages

- [Rust54.7%](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/search?l=rust)
- [HTML27.2%](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/search?l=html)
- [JavaScript18.1%](https://github.com/Lucrehulk/rust-cf-turnstile-bypass/search?l=javascript)

You can’t perform that action at this time.