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
### Image, storage, and server settings
The chart defaults to the `pfeiffermax/valheim-dedicated-server:latest` image. Set
`image.repository`, `image.tag`, and `image.pullPolicy` to select another image or pin a release.
The server listens on UDP `valheimDedicatedServer.port` (default `2456`) and the following port
(`2457` by default) for queries. Both ports are exposed by the headless Service and each
instance's Service. Each instance Service defaults to `LoadBalancer`; choose another Kubernetes
Service type or configure its metadata under that instance's `service` values. Set
`service.externalTrafficPolicy` to `Local` when preserving client source addresses is needed and
the load balancer supports it; omit it or set it to `null` to leave Kubernetes' default behavior.

Each StatefulSet replica gets its own `ReadWriteOnce` save volume. Set
`valheimDedicatedServer.volumeStorageSize` to change the requested size (default `1Gi`). The chart
does not define a storage class, so the cluster's default StorageClass is used. Storage class and
other PVC settings can be customized by editing the chart templates.

By default, the chart creates a Kubernetes Secret containing each instance's password. To use a
pre-created Secret instead, set `valheimDedicatedServer.existingSecret` to its name. The Secret
must contain one key per pod, named `<release-and-chart-name>-<ordinal>` (for example,
`valheim-0` for release `valheim`), and each key's value must be shell assignments such as
`password="your-password"`. The chart mounts the key matching each pod name as its password file.
When using the built-in Secret, password changes alone do not trigger a rollout; restart the
StatefulSet after changing a password.

The chart also accepts standard scheduling and pod settings: `imagePullSecrets`, `podAnnotations`,
`podLabels`, `nodeSelector`, `tolerations`, and `affinity`. `startupProbe` and `livenessProbe` tune
the UDP health checks. Probe fields are passed through to Kubernetes as configured in
`values.yaml`.

### Security Context
As the `pfeiffermax/valheim-dedicated-server` image runs the Valheim server with an unprivileged user since V2.0.0,
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
Start with [values.yaml](values.yaml) when configuring instances: Helm replaces the entire
`instances` list, so include the remaining settings when using the partial examples below.
```yaml
# You can choose to run multiple instances of Valheim dedicated servers here.
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

`service.externalTrafficPolicy` is optional; omit it or set it to `null` to leave it unset.

### World modifiers
Set optional modifier and checkbox key defaults under `valheimDedicatedServer`, then override or
extend them per server under each `instances` entry. Presets are configured per instance. By
default, no world modifier arguments are passed.

```yaml
valheimDedicatedServer:
  modifiers:
    raids: less
  setKeys:
    - nomap

instances:
  - name: "ValheimServer"
    preset: hard
    modifiers:
      raids: none
    setKeys:
      - nomap
```

For this instance, the chart passes `-preset hard -modifier raids none -setkey nomap`. A preset
overwrites previous modifiers, so the chart always places it before individual modifiers and
checkbox keys. Per-instance modifiers override matching defaults, and checkbox keys are combined
with the defaults. Each option can also be used independently. The chart schema rejects unknown
preset names, modifier names or values, and checkbox keys.

Valid presets are `normal`, `casual`, `easy`, `hard`, `hardcore`, `immersive`, and `hammer`.

| Modifier | Valid values |
| --- | --- |
| `combat` | `veryeasy`, `easy`, `hard`, `veryhard` |
| `deathpenalty` | `casual`, `veryeasy`, `easy`, `hard`, `hardcore` |
| `resources` | `muchless`, `less`, `more`, `muchmore`, `most` |
| `raids` | `none`, `muchless`, `less`, `more`, `muchmore` |
| `portals` | `casual`, `hard`, `veryhard` |

Valid `setKeys` entries are `nobuildcost`, `playerevents`, `passivemobs`, and `nomap`.

### Player lists
Optionally manage `adminlist.txt`, `bannedlist.txt`, and `permittedlist.txt` through Helm:

```yaml
instances:
  - name: "ValheimServer"
    # Include the remaining instance settings from values.yaml.
    adminList:
      - "Steam_384239847998"
    bannedList: []
    permittedList: null
  - name: "ValheimServer2"
    # Include the remaining instance settings from values.yaml.
    adminList: []
    bannedList: null
    permittedList:
      - "ANOTHER_PLAYER_ID"
```

Each entry is a quoted player ID, written on its own line. Use the ID format expected by your
server version, as described in the [Valheim dedicated server guide](https://www.valheimgame.com/support/a-guide-to-dedicated-servers/).
Each instance has its own list contents. Use `[]` when an instance needs an empty managed list and
`null`/omit the field when its file should remain unmanaged.
Because StatefulSet pods share volume mount definitions, a given list must be managed for every
instance or unmanaged for every instance; Helm rejects mixed configurations for the same list.

Each list defaults to `null`, leaving its file on the save volume unmanaged. An empty list (`[]`)
mounts an empty file. A populated list mounts the specified entries. A nonempty permitted list
restricts access to those players, so include everyone who should be able to join.

Configured files are stored in a separate player-list ConfigMap and mounted read-only into
`/srv/valheim/saves` using `subPathExpr` to select files by Pod name. Manage them through Helm;
in-game ban/unban commands cannot persist changes to a Helm-managed banned list.
Changes to the generated ConfigMap, including world modifiers and player lists, trigger a rollout
of all instances so they receive the new settings. Password-only changes do not affect this
checksum; restart the StatefulSet after updating passwords.

Mounting a list hides any existing file of the same name on the save volume without overwriting
it. Setting the value back to `null` removes the mount and exposes that underlying file again.

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

Helm-managed player lists live in the ConfigMap, so the helper Pod's volume archive does not
include those mounted files. Copy the `adminList`, `bannedList`, and `permittedList` values to
the target release as well; files of the same names in the archive may be older, unmanaged copies.

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
