# VideoSync

Synchronize video playback across multiple devices over a local Wi-Fi network.

© Tarmo Johannes — trmjhnns@gmail.com

Built with the [Qt Framework](https://qt.io) (Qt 6, QML, Qt Multimedia, Qt WebSockets).

---

## Features

- **Host / Guest roles** — one device acts as Host, the rest as Guests.
- **Automatic LAN discovery** — Guests auto-detect the Host via UDP broadcast; no manual IP entry required in most cases.
- **Drift correction** — playback rate is nudged (±5 %) when drift is small; hard seek is used when drift exceeds 500 ms.
- **Recent videos list** — quickly reload previously watched files.
- **Mute toggle** — silence audio independently on each device.
- **Video-only fullscreen** — double-tap the video area; single tap to play/pause.
- Cross-platform: **Android**, **iOS**, **Linux**, **macOS**, **Windows**.

---

## How to use

### Host device
1. Open VideoSync and switch the toggle to **Host**.
2. Load a video file via the drawer menu → **Load Video**.
3. Your local IP address is shown in the top bar.

### Guest devices
1. Keep the toggle on **Guest**.
2. Open the drawer and enter the Host's IP in the **Host IP** field (auto-filled if discovery succeeded), then tap **Connect**.
3. Load the same video file locally.
4. Press **Play** on any of the deivces — all devices follow.

### Controls
| Action | Result |
|---|---|
| Single tap on video | Play / Pause |
| Double tap on video | Toggle fullscreen |
| Seek slider | Seek (synced to all Guests) |
| 🔇 Mute button | Silence audio locally |

---

## Web version

The original `index.php` browser-based version synchronizes playback across browsers via PHP/WebSocket. Place it alongside your video files on a PHP 8 web server. One device selects **Host mode**, others scan the QR code to join.

Developed for video scores of [Gudmundur Steinn Gunnarson](https://gudmundursteinn.net/).

---

## Build

Requires **Qt 6.5+** with the following modules: `Quick`, `Multimedia`, `Network`, `WebSockets`.

```bash
cmake -S VideoSync -B build
cmake --build build
```

For Android and iOS, open the project in **Qt Creator** and use the corresponding kit.

---

## License

See [LICENSE](LICENSE).

The devices must be in one network with internet access.

[Demo](https://tarmo.uuu.ee/videosync/)

License: GNU General Public License (free to use and change, must be kept open source).

If you find it useful,  feel free to [buy me a coffee](https://ko-fi.com/tarmojohannes) 😊! 


[Tarmo Johannes](https://tarmo.uuu.ee/software/)
