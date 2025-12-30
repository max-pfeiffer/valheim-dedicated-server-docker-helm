FROM steamcmd/steamcmd:debian-trixie AS install-stage

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    libatomic1 \
    libpulse-dev \
    libpulse0

RUN steamcmd +force_install_dir /srv/valheim +login anonymous +app_update 896660 validate +quit

FROM debian:trixie-slim AS production-image

# Install dependencies
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    libatomic1 \
    libpulse-dev \
    libpulse0 \
    netcat-traditional \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /srv/valheim

COPY --from=install-stage /srv/valheim /srv/valheim

COPY start.sh /srv/valheim/start.sh
RUN chmod +x /srv/valheim/start.sh

EXPOSE 2456/udp 2457/udp

ENTRYPOINT ["/srv/valheim/start.sh"]
