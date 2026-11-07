---
sidebar_label: Docker
---

# Star Wars: Battlefront II Docker Container

This Docker container runs a Star Wars: Battlefront II (2005) dedicated server. It is built on the WINE image. The game has no Linux server, so the container runs the game's own `BattlefrontII.exe /autonet dedicated` headless under Wine. The container doesn't download the game, so you provide the files.

## Quick Start

```yaml
services:
  battlefront2:
    image: lancommander/starwarsbattlefront2:latest
    container_name: battlefront2

    ports:
      - 3658:3658/udp
      - 3656:3656/udp

    volumes:
      - "/data/Servers/Star Wars Battlefront II/Conquest:/config"

    environment:
      SWBF2_SERVER_NAME: "My Battlefront II Server"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

Copy the game folder (the one with `GameData/BattlefrontII.exe`) into `Server/` before the first start. You can instead set `SWBF2_ARCHIVE_URL` to a zip of it.

Use the v1.1 build with GameSpy networking (GOG's build from before the 2017 update: `goggame-1421404701.dll` next to `BattlefrontII.exe`, no `Galaxy.dll`), and give players the same build.

## How It Starts

1. `PostInitialization/10-InitializeWinePrefix.ps1` (from the WINE image) creates the Wine prefix in `/config/wineprefix`.
2. `PostInitialization/20-InstallBattlefront2.ps1` checks for `Server/GameData/BattlefrontII.exe`. If it's missing and `SWBF2_ARCHIVE_URL` is set, the hook extracts `GameData/` (without `data/_lvl_pc/movies/`) into `Server/` and remounts the overlay. A `file://` archive is read in place; other URLs are downloaded to `/config` first.
3. `START_EXE` (`/usr/local/bin/swbf2-server`) checks the map codes in `SWBF2_MAPS`. It then runs `wine-run BattlefrontII.exe /norender /nosound /lan /autonet dedicated /gamename <name> ... <maps>` from `GameData/`.

The game writes nothing to stdout, so `docker logs` only shows the command line (passwords masked) and the rotation size:

```
Starting: BattlefrontII.exe /norender /nosound /lan /autonet dedicated /gamename LANCommander SWBF2 /playerlimit 32 ... /adminpw ****   cor1c_con 200 200 kas2g_ctf hot1g_hunt
Rotation: 3 map(s)
```

Loading a map takes about a minute and a half at over 100% CPU, and the server doesn't answer the LAN browser while it loads. Afterwards it idles at about 15% of a core.

### Why these flags

- `/autonet dedicated` makes the game host without a local player.
- `/norender` skips drawing frames, so the server needs no display. Rendering under Xvfb instead costs nearly two cores.
- `/lan` hosts on the LAN. Without it, the game registers with GameSpy's master server, which is gone; the host shows "Host registration failed".
- `/nosound` because there's no sound device.

The exe looks options up by a hash of their name, so they don't appear as strings in it. Others it accepts, untested here, can go in `SWBF2_EXTRA_ARGS`: `/bandwidth`, `/netregion`, `/hrunlock`, `/hrunlockvalue`, `/hrplayer`, `/hrteam`, `/hrrespawn`, `/pregametime`, `/disableaiautobalance`.

## Configuration Options

### Ports

- **3658/udp**: Game. Clients connect here and ping the server while it's listed.
- **3656/udp**: LAN browser. A client broadcasts a 13-byte query to 255.255.255.255:3656 and the server replies by broadcast.

Neither port can be set on the command line. Only one server can run per IP address: a second one moves its game port to 3659, which clients won't find.

To check that the server is up, send `00 ff ff 00 00 e3 47 5d 8c 01 10 00 00` to UDP 3656 on the server's IP, from a socket bound to port 3656; the reply is a broadcast to 3656 that starts `01 ff ff 00 00` and carries the server name, bit-packed.

### Environment Variables

See the [README](../README.md#environment-variables) for the table, the rotation format and the map codes.

### Hooks

| Hook | When |
|------|------|
| `PreInstallBattlefront2` / `PostInstallBattlefront2` | Around the game file check/install |
| `PreInitializeWinePrefix` / `PostInitializeWinePrefix` | Around Wine prefix creation (WINE image) |

Put `.ps1` scripts in `config/Scripts/Hooks/<HookName>/`.

## Troubleshooting

- **The container exits with an `SWBF2_MAPS:` message.** A map code is unknown or misspelled. Each world has only the eras and modes listed in the README, and the `_c` single-player campaign missions aren't accepted.
- **"Host registration failed".** `/lan` is missing, which can only happen with a custom `START_EXE`.
- **Clients don't see the server in the LAN list.** Discovery is a broadcast on 3656, which Docker port mapping doesn't forward. Use macvlan/ipvlan or host networking. Also check the client runs the same game build.
- **`docker stop` waits out its 10-second timeout.** The base image's entrypoint doesn't pass SIGTERM on to the server, so Docker kills it at the timeout. The game keeps no state, so nothing is lost.
- **Edits to `Overlay/` from the host while the container runs don't show up.** OverlayFS caches the upper directory. Restart the container, or edit through `Merged/` inside it (`docker exec`).
