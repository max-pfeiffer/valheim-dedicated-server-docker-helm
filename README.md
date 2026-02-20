[![Poetry](https://img.shields.io/endpoint?url=https://python-poetry.org/badge/v0.json)](https://python-poetry.org/)
[![Ruff](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json)](https://github.com/astral-sh/ruff)
[![codecov](https://codecov.io/gh/max-pfeiffer/valheim-dedicated-server-docker-helm/graph/badge.svg?token=kP5LQLcpJi)](https://codecov.io/gh/max-pfeiffer/valheim-dedicated-server-docker-helm)
[![Code Quality](https://github.com/max-pfeiffer/valheim-dedicated-server-docker-helm/actions/workflows/code-quality.yaml/badge.svg)](https://github.com/max-pfeiffer/valheim-dedicated-server-docker-helm/actions/workflows/code-quality.yaml)
[![Publish Docker Image](https://github.com/max-pfeiffer/valheim-dedicated-server-docker-helm/actions/workflows/publish.yaml/badge.svg)](https://github.com/max-pfeiffer/valheim-dedicated-server-docker-helm/actions/workflows/publish.yaml)
[![Release Helm Charts](https://github.com/max-pfeiffer/valheim-dedicated-server-docker-helm/actions/workflows/helm-release.yaml/badge.svg)](https://github.com/max-pfeiffer/valheim-dedicated-server-docker-helm/actions/workflows/helm-release.yaml)
![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/pfeiffermax/valheim-dedicated-server?sort=semver)
![Docker Pulls](https://img.shields.io/docker/pulls/pfeiffermax/valheim-dedicated-server)

# Valheim Dedicated Server - Docker Image and Helm Chart
This Docker image provides a [Valheim](https://www.valheimgame.com/) dedicated game server.
You will find here also a [Helm Chart](https://helm.sh/) for running a Valheim dedicated server on [Kubernetes container orchestration system](https://kubernetes.io/).

My automation checks the [Valheim public branch](https://steamdb.info/app/896660/depots/?branch=public) every
night. If a new release was published by [Iron Gate Studios](https://irongate.se/), a new Docker image will be built
with this new version. Just use the `latest` tag and you will always have an up-to-date Docker image. No need to
manually run any server updates and mess around with your Docker image. It's that simple. :smiley:

Have a look at the [docker compose example](examples/docker-compose/compose.yaml) and
[its documentation](examples/docker-compose#automated-server-updates).
There you can see how a server update can be automated with a simple script.

Kudus to:
* [@jonakoudijs](https://github.com/jonakoudijs) for providing the [Steamcmd Docker image](https://github.com/steamcmd/docker) which is used here

**Docker Hub:** https://hub.docker.com/r/pfeiffermax/valheim-dedicated-server

**GitHub Repository:** https://github.com/max-pfeiffer/valheim-dedicated-server-docker-helm

## Usage
### Configuration
You can append all [Valheim console commands](https://www.valheimgame.com/support/a-guide-to-dedicated-servers/) as commands
when running `valheim_server.x86_64` binary. Use the regular syntax like `-name ValheimServer` or `-public 1`.

As the Valheim server is running in the Docker container as a stateless application, you want to have all stateful server
data (config, saves, etc.) stored in a [Docker volume](https://docs.docker.com/storage/volumes/)
which is persisted **outside** the container. This can be configured with `-savedir`: you can specify the
directory where this data is stored. You need to make sure that this directory is mounted on
a [Docker Volume](https://docs.docker.com/storage/volumes/).

This is especially important because you need to update the Valheim server image every month when
[Iron Gate Studios](https://irongate.se/) releases a new software update. When you use a
[Docker volume](https://docs.docker.com/storage/volumes/) to store the `-savedir`, all the data is still intact.

## IMPORTANT CHANGE SINCE V2.0.0 (build-21981590, 20.2.2026)
Since image version V2.0.0 the application is run with an unprivileged user and not with root user anymore. This was
done to improve the security of this image.
If you were persisting server identity with a Volume and start the Rust dedicated server using the new image (like
in the docker compose example), you will encounter problems starting your server. This happens because root user still
owns the files in that Volume and the new unprivileged user doesn't have permissions to access these files.

If you are using Docker please adjust the file ownership with this command:
```shell
docker exec -it -u root valheim-server chown -R valheim:valheim /srv/valheim
```
Please restart the Docker container afterwards. Your server should start up just fine.
`valheim-server` is the name of your container.

If you are using the Helm chart for running the Rust dedicated server on Kubernetes, just upgrade your Helm release
using chart version v1.1.0 or newer. This will fix file permissions in your Volume by applying the correct `fsGroup`
for the Pod security context.

### Docker Run
For testing purposes, you can fire up a Docker container like this:
```shell
docker run -it --publish 2456:2456/udp pfeiffermax/valheim-dedicated-server:latest -name ValheimServer -world NewWorld -password supersecret -public 0
```

### Docker Compose
Please have a look at the [docker compose example](examples/docker-compose/README.md).

## Helm chart
If you would like to run the Valheim server in your [Kubernetes](https://kubernetes.io/) cluster, I provide a
[Helm chart](https://helm.sh/) you could use: [https://max-pfeiffer.github.io/valheim-dedicated-server-docker-helm](https://max-pfeiffer.github.io/valheim-dedicated-server-docker-helm)

There is also [documentation available](charts/valheim/README.md) for that Helm chart.

If you want to run your Valheim server on bare metal Kubernetes, check out
[my blog article](https://max-pfeiffer.github.io/blog/hosting-game-servers-on-bare-metal-kubernetes-with-kube-vip.html)
on how to do that using [kube-vip](https://kube-vip.io/).

## Additional Information Sources
* [SteamDB](https://steamdb.info/app/896660/info/)
* [Official Valheim dedicated server guide](https://www.valheimgame.com/support/a-guide-to-dedicated-servers/)
* [Valheim dedictated server Fandom Wiki](https://valheim.fandom.com/wiki/Dedicated_servers)

## Other Game Server Projects
* [Rust dedicated server](https://github.com/max-pfeiffer/rust-game-server-docker)
