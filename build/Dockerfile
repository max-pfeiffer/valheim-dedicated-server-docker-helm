FROM steamcmd/steamcmd:debian-bookworm AS install-stage

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    libatomic1 \
    libpulse-dev \
    libpulse0 \
    ca-certificates

RUN steamcmd +force_install_dir /srv/valheim +login anonymous +app_update 896660 validate +quit

FROM debian:trixie-slim AS production-image

# Principle of least privilege: create a new user for running the application
RUN groupadd -g 10001 valheim && \
    useradd -r -u 10001 -g valheim --create-home valheim

# Install dependencies
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    libatomic1 \
    libpulse-dev \
    libpulse0 \
    ca-certificates \
    netcat-traditional \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /srv/valheim

COPY --from=install-stage --chown=valheim:valheim /srv/valheim /srv/valheim

COPY start.sh /srv/valheim/start.sh
RUN chmod +x /srv/valheim/start.sh

EXPOSE 2456/udp 2457/udp

# Use the unpriviledged user to run the application
USER 10001

ENTRYPOINT ["/srv/valheim/start.sh"]
