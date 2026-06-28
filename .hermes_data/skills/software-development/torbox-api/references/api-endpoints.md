# TorBox API Endpoints Reference

All endpoints at `https://api.torbox.app/v1/api/`

Auth: `Authorization: Bearer <supab...>`

## User
- `GET /user/me` — user info (plan, is_subscribed, premium_expires_at)
- `GET /user/subscriptions` — subscription list
- `GET /user/transactions` — transaction history
- `GET /user/referraldata` — referral data
- `GET /user/stats` — user statistics
- `GET /user/auth/device/start` — start device code auth
- `POST /user/auth/device/token` — body: `{device_code}`
- `POST /user/refreshtoken` — body: `{session_token}`
- `POST /user/getconfirmation` — get confirmation code
- `DELETE /user/deleteme` — delete account
- `POST /user/addreferral` — add referral

## Settings
- `GET /user/settings/searchengines` — list search engines
- `POST /user/settings/addsearchengines` — add search engine
- `POST /user/settings/modifysearchengines` — edit search engine
- `POST /user/settings/controlsearchengines` — control search engines
- `PUT /user/settings/editsettings` — edit general settings

## Torrents
- `POST /torrents/createtorrent` — create torrent
- `POST /torrents/asynccreatetorrent` — async create torrent
- `POST /torrents/controltorrent` — control torrent
- `POST /torrents/controlqueued` — control queued
- `POST /torrents/checkcached` — check cached torrent
- `POST /torrents/magnettofile` — magnet to file
- `POST /torrents/torrentinfo` — get torrent info
- `PUT /torrents/edittorrent` — edit torrent
- `GET /torrents/mylist` — list user torrents
- `GET /torrents/getqueued` — get queued
- `GET /torrents/exportdata` — export data
- `POST /torrents/requestdl` — request download

## Web Downloads
- `POST /webdl/createwebdownload` — create web download
- `POST /webdl/asynccreatewebdownload` — async create
- `POST /webdl/controlwebdownload` — control web download
- `POST /webdl/checkcached` — check cached
- `PUT /webdl/editwebdownload` — edit web download
- `GET /webdl/mylist` — list web downloads
- `GET /webdl/hosters` — list supported hosters
- `POST /webdl/requestdl` — request download

## Usenet
- `POST /usenet/createusenetdownload` — create usenet download
- `POST /usenet/asynccreateusenetdownload` — async create
- `POST /usenet/controlusenetdownload` — control usenet download
- `POST /usenet/checkcached` — check cached
- `PUT /usenet/editusenetdownload` — edit usenet download
- `GET /usenet/mylist` — list usenet downloads
- `GET /usenet/provider/account` — get usenet provider info
- `POST /usenet/provider/account/resetpw` — reset provider password
- `POST /usenet/requestdl` — request download

## RSS
- `POST /rss/addrss` — add RSS feed
- `POST /rss/controlrss` — control RSS feed
- `GET /rss/getfeeds` — get feeds
- `GET /rss/getfeeditems` — get feed items
- `POST /rss/modifyrss` — modify RSS feed

## Notifications
- `GET /notifications/mynotifications` — get notifications
- `POST /notifications/clear` — clear all
- `POST /notifications/clear/{id}` — clear specific
- `POST /notifications/test` — test notification

## Integration / OAuth
- `GET /integration/oauth/me` — get OAuth integrations
- `GET /integration/oauth/{provider}` — OAuth redirect
- `POST /integration/oauth/{provider}/callback` — OAuth callback
- `GET /integration/oauth/{provider}/success` — OAuth success
- `POST /integration/oauth/{provider}/register` — OAuth register
- `DELETE /integration/oauth/{provider}/unregister` — OAuth unregister

## Vendors
- `POST /vendors/register` — register vendor
- `POST /vendors/registeruser` — register user via vendor
- `GET /vendors/account` — get vendor account
- `GET /vendors/getaccounts` — get all vendor accounts
- `GET /vendors/getaccount` — get user vendor account
- `PUT /vendors/updateaccount` — update vendor account
- `DELETE /vendors/removeuser` — remove user
- `PATCH /vendors/refresh` — refresh vendor users

## Payments / Trial
- `POST /unifiedpayments/activatetrial` — activate 24hr free Pro trial. Body: `{"csrf_token": "..."}`. CSRF token is an httpOnly server-side session cookie set during browser login. **NOT obtainable via API-only (Supabase access_token) auth.** Tested: passing access_token/refresh_token as csrf_token → 422. No /csrf endpoint exists. Must use browser dashboard button click to activate.

## Other
- `GET /stats` — global stats
- `GET /stats/30days` — 30 day stats
- `GET /speedtest` — speed test
- `GET /changelogs/json` — changelog JSON
- `GET /changelogs/rss` — changelog RSS
- `POST /intercom/hash` — Intercom hash
- `STREAM /stream/createstream` — create stream
- `GET /stream/getstreamdata` — get stream data
- `GET /queued/getqueued` — get queued
- `POST /queued/controlqueued` — control queued
