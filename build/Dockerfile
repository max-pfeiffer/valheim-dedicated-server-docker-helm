FROM steamcmd/steamcmd:debian-bookworm

# Install dependencies
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    libatomic1 \
    libpulse-dev \
    libpulse0 \
    netcat-traditional

WORKDIR /srv/valheim

RUN steamcmd +force_install_dir /srv/valheim +login anonymous +app_update 896660 validate +quit

COPY start.sh start.sh

RUN chmod +x start.sh

EXPOSE 2456/udp 2457/udp

ENTRYPOINT ["/srv/valheim/start.sh"]
