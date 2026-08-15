# Valheim Helm Chart
A [Helm chart](https://helm.sh/) for running a Valheim dedicated server. Since v1.0.0 this Helm chart supports running multiple
server instances using one StatefulSet. 

## Installation
If you want to run Valheim on a bare metal Kubernetes cluster, I recommend reading
[my blog post](https://max-pfeiffer.github.io/blog/hosting-game-servers-on-bare-metal-kubernetes-with-kube-vip.html)
about that topic.

### Helm
You can run multiple server instance with each Helm installation. Please be aware that with a StatefulSet Kubernetes
starts additional instances only after the first instance is in ready state. And Valheim server startup is slow,
so it might take a while until your Valheim server fleet is up and running completely.
It might better suit your needs to install multiple StatefulSets with separate Helm releases.

The installation is done as follows:
```shell
$ helm repo add valheim https://max-pfeiffer.github.io/valheim-dedicated-server-docker-helm
$ helm install valheim valheim/valheim --values your_values.yaml --namespace yournamespace 
```

### Argo CD
I recommend deploying and running the Valheim dedicated server with [Argo CD](https://argoproj.github.io/cd/). This way
you have a declarative installation of your server. It's very easy to manage and update it that way.
A big plus is also the [Argo CD Image Updater](https://github.com/argoproj-labs/argocd-image-updater). This tool can
monitor the [Valheim Docker Image](https://hub.docker.com/r/pfeiffermax/valheim-dedicated-server) and will update your
Valheim installation automatically when a new image is released.

## Configuration options
### Security Context
As the `pfeiffermax/valheim-dedicated-server` image runs the Rust server with an unprivileged user since V2.0.0,
secure default values for `podSecurityContext` and `securityContext` were added.
```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 10001
  runAsGroup: 10001
  fsGroup: 10001
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  seccompProfile:
    type: RuntimeDefault
```
If that doesn't suit your needs, just override these defaults.

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

### Graceful shutdown
When a Pod is stopped, Kubernetes sends `SIGTERM` and then waits `terminationGracePeriodSeconds`
before killing the container with `SIGKILL`. The Valheim server uses that window to save the world,
and a `SIGKILL` landing in the middle of a save can corrupt your world files. The Kubernetes default
of 30 seconds is on the short side for a large world, so this chart defaults to a more generous
value:
```yaml
terminationGracePeriodSeconds: 300
```
This costs you nothing in the normal case: the Pod terminates as soon as the server process exits.
Raise it further if you run a very large world and see saves being cut short in the Pod logs.

Note that graceful shutdown depends on the entrypoint of the `pfeiffermax/valheim-dedicated-server`
image forwarding the shutdown signal to the server process. Images published before that was
implemented let the server be killed without saving, no matter how long the grace period is.

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
Tweak the Valheim server config to your liking. You can add a list of server to `instances`. Please be aware that the
configuration of resources and ports are shared by these instances.
```yaml
# You can choose to run multiple instances of Rust dedicated servers here.
# For a new instance add another entry to this list.
instances:
    # Name of your server that will be visible in the Server list.
    # You can use just one single string without any spaces as this is specified as command line option.
  - name: "ValheimServer"
    # A World with the name entered will be created. You may also choose an already existing World by entering its name.
    world: "NewWorld"
    # Server password
    # ATTENTION: needs to be at least 5 characters long, otherwise the server startup fails!
    password: "supersecret"
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
    # By default, that means one backup that is 2 hours old, and 3 backups that are 12 hours apart.
    backups: "4"
    # Sets the interval between the first automatic backups.
    backupShort: "7200"
    # Sets the interval between the subsequent automatic backups.
    backupLong: "43200"
    # Pod specific service
    service:
      type: LoadBalancer
      externalTrafficPolicy: Cluster
      metadata:
        annotations: {}
```

## Migrating save games to another cluster
The server keeps its save games in `/srv/valheim/saves`, which is backed by a PersistentVolumeClaim
created from the `volumeClaimTemplates` of the StatefulSet. The claims are named
`saves-directory-<statefulset>-<ordinal>`, so a release named `valheim` has its first instance's
saves in `saves-directory-valheim-0`. Migrating a world to another cluster means copying the
contents of that volume.

### 1. Stop the server
Never copy save games out of a running server. Valheim writes a world save by creating a new file
and renaming it into place, so a copy taken mid-save can catch a `.db` and `.fwl` file that do not
belong to the same save generation. Kick your players, then scale the StatefulSet down and wait
until the Pod is really gone:
```shell
$ kubectl --context=source-cluster -n yournamespace scale statefulset valheim --replicas=0
$ kubectl --context=source-cluster -n yournamespace wait --for=delete pod/valheim-0 --timeout=300s
```
With a graceful shutdown the server saves the world on the way out. Watch the Pod logs while it
terminates to confirm the save completed.

If you deploy with Argo CD, suspend auto-sync first. The StatefulSet uses
`replicas: {{ len .Values.instances }}`, so a sync would scale the server back up in the middle of
your migration.

### 2. Mount the volume with a helper Pod
The claim uses the `ReadWriteOnce` access mode, so it can only be attached to one node at a time.
With the server scaled down, attach it to a small helper Pod instead. Run it with the same user,
group and `fsGroup` as the server, otherwise the restored files end up with an ownership the
server cannot write to:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: saves-shuttle
spec:
  securityContext:
    runAsUser: 10001
    runAsGroup: 10001
    fsGroup: 10001
  containers:
    - name: shell
      image: busybox:1.37
      command: ["sleep", "infinity"]
      volumeMounts:
        - name: saves
          mountPath: /srv/valheim/saves
  volumes:
    - name: saves
      persistentVolumeClaim:
        claimName: saves-directory-valheim-0
```
On the target cluster, install the chart first so the StatefulSet creates the claim, then scale it
down to zero and delete the freshly generated world before restoring. Otherwise you end up mixing a
new world into the one you are migrating.

### 3. Copy the save games
Stream the whole directory from one cluster to the other with `tar`:
```shell
$ kubectl --context=source-cluster -n yournamespace exec saves-shuttle -- tar -C /srv/valheim/saves -cf - . \
  | kubectl --context=target-cluster -n yournamespace exec -i saves-shuttle -- tar -C /srv/valheim/saves -xf -
```
It is worth writing the archive to your machine first, as that gives you something to roll back to:
```shell
$ kubectl --context=source-cluster -n yournamespace exec saves-shuttle -- tar -C /srv/valheim/saves -cf - . > valheim-saves.tar
```
Always copy the entire save directory, not just the world file. Next to the `.db` file holding the
world data there is a `.fwl` file with the world metadata and seed, and the two only work as a
matching pair. The directory also holds the `.old` copies, the automatic backups produced by your
`backups`, `backupShort` and `backupLong` settings, and the `adminlist.txt`, `bannedlist.txt` and
`permittedlist.txt` files.

### 4. Verify before starting the server
Compare the checksums on both sides:
```shell
$ kubectl --context=target-cluster -n yournamespace exec saves-shuttle -- \
  sh -c 'cd /srv/valheim/saves && find . -type f | sort | xargs sha256sum'
```
Check that `instances[].world` in the values of the target installation matches the name of the
world file you copied. A mismatch is not an error: the server happily generates a brand new world
and leaves your migrated save untouched on the volume.

Then delete the helper Pods and scale the target StatefulSet up again.

### Avoiding corrupted save games
* Never run two servers on the same world. This is the biggest risk during a migration: once the
  target is live, the source must stay scaled down or be uninstalled, and Argo CD auto-sync must
  stay suspended until you do.
* Never copy save games from a running server, see step 1.
* Keep the `.db` and `.fwl` files of a world together.
* Give the server enough time to save on shutdown, see [Graceful shutdown](#graceful-shutdown).
* Restore the files with the UID and GID the server runs as.
* Keep your `valheim-saves.tar` until players have confirmed the migrated world is intact.