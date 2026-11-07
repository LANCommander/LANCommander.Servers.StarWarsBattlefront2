# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Star Wars: Battlefront II Game Server" \
      org.opencontainers.image.description="Dedicated server for Star Wars: Battlefront II (2005), running BattlefrontII.exe /autonet dedicated under Wine" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="Star Wars: Battlefront II" \
      app.lancommander.server.external-id.hq="691840ef-5303-4bd9-bca6-c0d292839b4a" \
      app.lancommander.server.external-id.igdb="142" \
      app.lancommander.server.external-id.steam="6060" \
      app.lancommander.server.external-id.gog="1421404701"

# ----------------------------
# Server settings
#   - The game files are not downloadable; put a Star Wars: Battlefront II install (the folder that
#     holds GameData/) in /config/Server, or set SWBF2_ARCHIVE_URL to a zip of one
#   - Built for the v1.1 release with GameSpy-era networking (GOG's pre-Galaxy build); clients must
#     run the same build
#   - SWBF2_MAPS: semicolon-separated "map [n1 n2]" entries, e.g. "cor1c_con; kas2g_ctf"
# ----------------------------
ENV SWBF2_ARCHIVE_URL="" \
    SWBF2_SERVER_NAME="Star Wars Battlefront II Server" \
    SWBF2_PASSWORD="" \
    SWBF2_ADMIN_PASSWORD="" \
    SWBF2_MAX_PLAYERS="32" \
    SWBF2_MIN_PLAYERS="1" \
    SWBF2_BOTS="8" \
    SWBF2_DIFFICULTY="2" \
    SWBF2_HEROES="true" \
    SWBF2_TEAM_DAMAGE="true" \
    SWBF2_AUTO_AIM="true" \
    SWBF2_SIDE_SELECT="false" \
    SWBF2_RANDOMIZE="false" \
    SWBF2_SPAWN_INVINCIBILITY="5" \
    SWBF2_TPS="30" \
    SWBF2_THROTTLE="2048" \
    SWBF2_MAPS="cor1c_con; kas2g_con; geo1c_con; hot1g_con; mus1c_con; tat2g_con; nab2c_con; yav1g_con; myg1c_con; end1g_con" \
    SWBF2_EXTRA_ARGS="" \
    WINE_XVFB="false" \
    START_EXE="/usr/local/bin/swbf2-server" \
    START_ARGS=""

COPY Scripts/swbf2-server /usr/local/bin/swbf2-server
RUN chmod +x /usr/local/bin/swbf2-server

COPY Hooks/ "${BASE_HOOKS}/"

# 3658/udp: game (fixed, the game has no port option on the command line)
# 3656/udp: LAN server browser (clients broadcast a query, the server answers by broadcast)
EXPOSE 3658/udp 3656/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
