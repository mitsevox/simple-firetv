# Insignia Fire TV debloat plan

Device: AFTDCT31 ("duckie"), Fire OS 7.7.1.7 (Android 9), 246 system + 13 user packages.
Nothing has been removed yet. Every removal uses `pm uninstall -k --user 0` and can be undone with
`adb shell cmd package install-existing <pkg>`.

## Remove: ads, tracking, promos

| Package | What it is |
|---|---|
| com.amazon.tv.acr | Automatic Content Recognition: fingerprints what's on screen, including HDMI inputs |
| com.amazon.ftvads.deeplinking | Home-screen ad click-through handling |
| com.amazon.hybridadidservice | Advertising ID service |
| com.amazon.kso.blackbird | "Special offers" ad delivery |
| com.amazon.sneakpeek | Autoplay previews in the banner |
| com.amazon.media.recommendations | Recommendation rows |
| com.amazon.shoptv.client | Amazon shopping on TV |
| com.amazon.shoptv.firetv.client | Amazon shopping on TV |
| com.amazon.minitv.android.app | Amazon miniTV (ad-supported video) |
| com.amazon.gamehub | Games hub |
| com.amazon.bueller.photos | Amazon Photos |
| com.amazon.tv.democontent.provider | Demo/sample content |
| com.amazon.storm.lightning.tutorial | Tutorial |
| com.amazon.tmm.tutorial | Tutorial |
| com.amazon.tv.csapp | In-TV help app |
| com.amazon.tv.releasenotes | "What's new" popups |
| com.amazon.hedwig | Push notifications |
| com.amazon.device.metrics | Telemetry |
| com.amazon.tv.fw.metrics | Telemetry |
| com.amazon.wirelessmetrics.service | Telemetry |
| com.amazon.perfcollection | Telemetry |
| com.amazon.perfc | Telemetry |
| com.amazon.device.crashmanager | Crash reports to Amazon |
| com.amazon.device.logmanager | Log upload |
| com.amazon.dp.logger | Log upload |
| com.amazon.neo.minerva.logcat | Log upload |

## Maybe: your call

| Package | Trade-off |
|---|---|
| com.amazon.device.software.ota, .ota.override, com.amazon.tv.forcedotaupdater.v2 | Stops updates that re-add bloat, but also stops security fixes |
| com.amazon.tv.easyupgrade | Upgrade prompts |
| com.amazon.cloud9 | Silk browser |
| com.amazon.tv.website_launcher | Web "app" tiles (possibly the News tile) |
| com.amazon.tv.alexaalerts, com.amazon.tv.alexanotifications | Alexa alerts (keep if you use Alexa) |
| com.amazon.bueller.music | Amazon Music |
| com.amazon.venezia | Amazon Appstore: removing it breaks installing and updating apps |
| com.amazon.ftv.screensaver | Amazon screensaver |

## Never touch

Launcher and home (com.amazon.tv.launcher, com.amazon.firehomestarter), settings
(com.amazon.tv.settings.*, com.android.settings), system UI, HDMI/live TV inputs
(com.amazon.tv.livetv, com.amazon.franktvinput, com.mediatek.*), Bluetooth and remotes
(com.android.bluetooth, com.amazon.fireinputdevices, com.amazon.device.bluetooth*), keyboard
(com.amazon.tv.ime), account/identity (com.amazon.dcp*, com.amazon.identity.*), WebView, all
com.android.providers.*, and setup (com.amazon.tv.oobe).

## Notes

- Tubi isn't installed: its tile is a paid promotion drawn by the launcher. DNS blocking is what affects that.
- Jellyfin is already installed, so a Jellyfin-first launcher setup is an option.
