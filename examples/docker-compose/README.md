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

## Automated Server Updates
When [Iron Gate Studios](https://irongate.se/) releases a Valheim update, you need to update your Valheim server as
well. So you need a new, updated Valheim dedicated server image.

As the docker compose file uses the `latest` tag for the Valheim server image, the only thing you need to do is
stopping/removing and creating/starting the container with docker compose. Docker then pulls the up-to-date Valheim
server image and starts the server. And you are done with your server update. :smiley: 

For instance, you can automate this with a cron job. Check out [valheim-server-update.sh](valheim-server-update.sh),
which is a simple script you can add as a daily job to your `/etc/crontab`. That way you ensure your server is always
up to date. 
