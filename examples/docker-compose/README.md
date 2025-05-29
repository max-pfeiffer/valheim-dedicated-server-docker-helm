# Simple Docker Compose example
This example contains a simple docker compose file for running the Valheim server on your machine (MacOS, Windows, Linux).

It demonstrates the usage of a [Docker Volume](https://docs.docker.com/storage/volumes/) to persist the Valheim server data.

## Usage
Clone the repo and start the Valheim server:
```shell
git clone https://github.com/max-pfeiffer/valheim-dedicated-server-docker-helm.git
cd valheim-dedicated-server-docker-helm/examples/docker-compose
docker compose up -d
```
Stop the server:
```shell
docker compose down
```
And show the logs, option `-f` follows the logs:
```shell
docker compose logs -f
```
