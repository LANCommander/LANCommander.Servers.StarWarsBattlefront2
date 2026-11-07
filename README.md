# Star Wars: Battlefront II Server (Docker)

This repository provides a Dockerized **Star Wars: Battlefront II** (2005) dedicated server. The game has no Linux server: `BattlefrontII.exe` hosts one itself with `/autonet dedicated`, so the image runs the game's own executable headless under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers.WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs `BattlefrontII.exe /norender /nosound /lan /autonet dedicated` under Wine with no display. Once a map is loaded it uses about 15% of a core and 280 MB.
- Server name, passwords, bots, heroes, difficulty and the map rotation come from environment variables. Map codes are checked before the game starts.
- Hosts on the LAN, where the in-game LAN browser finds it. It doesn't register with GameSpy, whose master server is gone.
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  battlefront2:
    image: lancommander/starwarsbattlefront2:latest
    container_name: battlefront2

    ports:
      - "3658:3658/udp"
      - "3656:3656/udp"

    volumes:
      - ./config:/config

    environment:
      SWBF2_SERVER_NAME: "My Battlefront II Server"
      SWBF2_ADMIN_PASSWORD: "change-me"
      SWBF2_MAPS: "cor1c_con 250 250; kas2g_ctf; hot1g_hunt; mus1c_con"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The LAN browser works by broadcast, which doesn't cross Docker port mapping. Give the container its own LAN address (macvlan/ipvlan, or `network_mode: host`) so clients can find it. Behind port mapping, clients can't discover it in the LAN browser.

---

## Game Files

Star Wars: Battlefront II is retail software with no public download. Provide the game folder (the one that holds `GameData/BattlefrontII.exe`):

- copy it to `config/Server/`, **or**
- set `SWBF2_ARCHIVE_URL` to a zip of it (`GameData/` at the zip root or inside one top-level folder, e.g. a LANCommander archive). It is installed on first start, if `Server/GameData/BattlefrontII.exe` doesn't exist yet. Only `GameData/` is extracted, without its 4 GB of cutscenes (`data/_lvl_pc/movies`), which leaves about 4 GB. A `file://` URL is read in place; any other URL is downloaded to `/config` first.

The image is built and tested with the **GOG v1.1 build that still uses GameSpy networking** (`BattlefrontII.exe` sha256 `b90770c8…20b6c1`, with `goggame-1421404701.dll` and no `Galaxy.dll`). Clients must run the same build as the server. The 2017 Steam/GOG update moved multiplayer to Steam and GOG Galaxy and is a different network version.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Star Wars: Battlefront II install
    │   └── GameData/      #   BattlefrontII.exe, data/_lvl_pc/, addon/
    ├── Overlay/           # Your files, layered on top of Server/ (e.g. mod maps in GameData/addon/)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers.WINE#environment).

| Variable | Description | Default |
|----------|-------------|---------|
| `SWBF2_SERVER_NAME` | Server name in the LAN browser (`/gamename`) | `Star Wars Battlefront II Server` |
| `SWBF2_PASSWORD` | Join password (`/password`); empty for none | |
| `SWBF2_ADMIN_PASSWORD` | In-game admin password (`/adminpw`); empty for none | |
| `SWBF2_MAX_PLAYERS` | Player limit (`/playerlimit`) | `32` |
| `SWBF2_MIN_PLAYERS` | Players needed before a match starts (`/playercount`) | `1` |
| `SWBF2_BOTS` | AI units per team (`/bots`) | `8` |
| `SWBF2_DIFFICULTY` | AI difficulty (`/difficulty`): 1 easy, 2 medium, 3 hard | `2` |
| `SWBF2_HEROES` | Heroes and villains (`/heroes 1` or `/heroes 0`) | `true` |
| `SWBF2_TEAM_DAMAGE` | Friendly fire. `false` passes `/noteamdamage`. | `true` |
| `SWBF2_AUTO_AIM` | Aim assist. `false` passes `/noaim`. | `true` |
| `SWBF2_SIDE_SELECT` | Let players choose their side (`/sideselect`) | `false` |
| `SWBF2_RANDOMIZE` | Play the rotation in random order (`/randomize`) | `false` |
| `SWBF2_SPAWN_INVINCIBILITY` | Seconds of spawn invincibility (`/spawn`) | `5` |
| `SWBF2_TPS` | Server simulation rate (`/tps`) | `30` |
| `SWBF2_THROTTLE` | Upload bandwidth limit in kbit/s (`/throttle`) | `2048` |
| `SWBF2_MAPS` | Map rotation, see below | 10 Conquest maps, see below |
| `SWBF2_EXTRA_ARGS` | Raw arguments added before the map list | |
| `SWBF2_ARCHIVE_URL` | Zip of the game folder, used if `Server/GameData/BattlefrontII.exe` is missing | |
| `WINE_XVFB` | The server needs no display, so the image turns Xvfb off | `false` |

An empty variable leaves its flag off the command line, so the game uses its own default.

### Map rotation

`SWBF2_MAPS` is a `;`-separated list of `map` or `map n1 n2` entries. The two numbers are the reinforcement counts for the mission's two teams (for `cor1c_con 77 88`: CIS 77, Republic 88); without them the mission uses its own. The default is `cor1c_con; kas2g_con; geo1c_con; hot1g_con; mus1c_con; tat2g_con; nab2c_con; yav1g_con; myg1c_con; end1g_con`.

A code is `<world><n><era>_<mode>`. The era is `c` (Clone Wars) or `g` (Galactic Civil War). Modes are `con` (Conquest), `ctf` (2-flag CTF), `1flag` (1-flag CTF), `hunt` (Hunt), `eli` (Hero Assault), `xl` (XL Conquest), `uber` (Uber mode), and in space `ass` (Space Assault) and `cmn`.

| World | Codes |
|-------|-------|
| Coruscant: Jedi Temple | `cor1c_con` `cor1c_ctf` `cor1g_con` `cor1g_ctf` |
| Dagobah: Swamp | `dag1c_con` `dag1c_ctf` `dag1g_con` `dag1g_ctf` |
| Death Star: Interior | `dea1c_con` `dea1c_1flag` `dea1g_con` `dea1g_1flag` |
| Endor: Bunker | `end1g_con` `end1g_1flag` `end1g_hunt` |
| Felucia: Marshland | `fel1c_con` `fel1c_1flag` `fel1g_con` `fel1g_1flag` |
| Geonosis: Dust Plains | `geo1c_con` `geo1c_ctf` `geo1c_hunt` `geo1c_xl` |
| Hoth: Echo Base | `hot1g_con` `hot1g_1flag` `hot1g_hunt` `hot1g_uber` `hot1g_xl` |
| Kamino: Cloning Facility | `kam1c_con` `kam1c_1flag` `kam1g_con` `kam1g_1flag` |
| Kashyyyk: Beachhead | `kas2c_con` `kas2c_ctf` `kas2c_hunt` `kas2c_uber` `kas2c_xl` `kas2g_con` `kas2g_ctf` `kas2g_xl` |
| Mustafar: Refinery | `mus1c_con` `mus1c_ctf` `mus1g_con` `mus1g_ctf` |
| Mygeeto: War-Torn City | `myg1c_con` `myg1c_ctf` `myg1g_con` `myg1g_ctf` |
| Naboo: Theed | `nab2c_con` `nab2c_ctf` `nab2c_hunt` `nab2g_con` `nab2g_ctf` |
| Polis Massa: Medical Facility | `pol1c_con` `pol1c_ctf` `pol1g_con` `pol1g_ctf` |
| Tantive IV: Interior | `tan1c_con` `tan1c_1flag` `tan1g_con` `tan1g_1flag` |
| Tatooine: Mos Eisley | `tat2c_con` `tat2c_ctf` `tat2g_con` `tat2g_ctf` `tat2g_eli` `tat2g_hunt` |
| Tatooine: Jabba's Palace | `tat3c_con` `tat3c_1flag` `tat3g_con` `tat3g_1flag` |
| Utapau: Sinkhole | `uta1c_con` `uta1c_1flag` `uta1g_con` `uta1g_1flag` |
| Yavin 4: Temple | `yav1c_con` `yav1c_1flag` `yav1g_con` `yav1g_1flag` |
| Space | `spa1g_ass` `spa1g_1flag` `spa3c_ass` `spa3c_1flag` `spa6c_ass` `spa6c_1flag` `spa6c_cmn` `spa7c_ass` `spa7c_1flag` `spa7c_cmn` `spa8g_ass` `spa8g_1flag` `spa8g_cmn` `spa9g_ass` `spa9g_1flag` `spa9g_cmn` |

The codes are the multiplayer missions in the game's `mission.lvl`. The launcher refuses codes it doesn't know. A mod map works if an add-on in `GameData/addon/` (put it in `Overlay/GameData/addon/`) names its code; clients need the same mod.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/starwarsbattlefront2:local .
```

---

## License

Star Wars: Battlefront II and Wine are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
