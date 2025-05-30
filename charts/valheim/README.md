# Valheim Helm Chart
A [Helm chart](https://helm.sh/) for running a Valheim dedicated server.

## Installation
If you want to run Valheim on a bare metal Kubernetes cluster, I recommend reading
[my blog post](https://max-pfeiffer.github.io/blog/hosting-game-servers-on-bare-metal-kubernetes-with-kube-vip.html)
about that topic.

### Helm
Currently, you can run a single server instance with each Helm installation. The installation is done as follows:
```shell
$ helm repo add rust https://max-pfeiffer.github.io/rust-game-server-docker
$ helm install rust rust/rust --values your_values.yaml --namespace yournamespace 
```

### Argo CD
I recommend deploying and running the Valheim dedicated server with [Argo CD](https://argoproj.github.io/cd/). This way
you have a declarative installation of your server. It's very easy to manage and update it that way.
A big plus is also the [Argo CD Image Updater](https://github.com/argoproj-labs/argocd-image-updater). This tool can
monitor the [Valheim Docker Image](https://hub.docker.com/r/pfeiffermax/valheim-dedicated-server) and will update your
Valheim installation automatically when a new image is released.

## Configuration options
### Resources
Make sure to get the resource specs right. You will need at least two CPU cores and 2GB of RAM.
[Using 4GB of RAM is recommended](https://valheim.fandom.com/wiki/Dedicated_servers#Requirements):
```yaml
resources:
  limits:
    cpu: 3
    memory: 5Gi
  requests:
    cpu: 2
    memory: 4Gi
```
Especially RAM is quite critical as Kubernetes is evicting/kills the Pod when it overshoots that resource limit. So
you want to check your monitoring and adjust `resource.limits.memory` when you see that happening. It's generally a
good idea to set the limit a bit higher than what you think the Valheim server will request.

### Startup Probe
Valheim server startup is rather slow. This is mainly due to generating the world. So you might need to raise the
`failureThreshold` when you see the startup probe failing. Multiply `periodSeconds` with `failureThreshold` to get
the maximum time for startup. These settings did work for me:
```yaml
startupProbe:
  periodSeconds: 10
  failureThreshold: 100
```

### Valheim server config
Tweak the Valheim server config to your liking. 
```yaml
valheimDedicatedServer:
  # Name of your server that will be visible in the Server list.
  # You can use just one single string without any spaces as this is specified as command line option.
  name: "ValheimServer"
  # A World with the name entered will be created. You may also choose an already existing World by entering its name.
  world: "NewWorld"
  # Server password
  password: "supersecret"
  # Port which you want the server to communicate with. Valheim uses the specified Port AND specified Port+1.
  # Default Ports are 2456-2457.
  port: 2456
  # Set the visibility of your server. 1 is default and will make the server visible in the browser.
  # Set it to 0 to make the server invisible and only joinable via the ‘Join IP’-button.
  public: "1"
  # Runs the Server on the Crossplay backend (PlayFab), which lets users from any platform join.
  # If you set it to false, the Steam backend is used, which means only Steam users can see and join the Server.
  crossPlay: false
  # How often the world will save in seconds.
  saveInterval: "1800"
  # Sets how many automatic backups will be kept. The first is the ‘short’ backup length,
  # and the rest are the ‘long’ backup length.
  # By default that means one backup that is 2 hours old, and 3 backups that are 12 hours apart.
  backups: "4"
  # Sets the interval between the first automatic backups.
  backupShort: "7200"
  # Sets the interval between the subsequent automatic backups.
  backupLong: "43200"
  # Size of the volume the server uses for its saves directory.
  volumeStorageSize: "1Gi"
```