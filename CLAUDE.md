# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

Two independently released artifacts for running a [Valheim](https://www.valheimgame.com/) dedicated
server:

* the `pfeiffermax/valheim-dedicated-server` Docker image (`build/`)
* the `valheim` Helm chart for Kubernetes (`charts/valheim/`)

The Python code is **build tooling only** — nothing in `build/` ships inside the image except
`start.sh` and the `Dockerfile`. That is why `pyproject.toml` sets `[tool.uv] package = false`:
uv manages the environment the scripts run in and never installs the project itself.

## Commands

Dependencies are managed with [uv](https://docs.astral.sh/uv/); `uv.lock` is committed.

```shell
uv sync                                            # dev setup, includes the dev group
uv run pre-commit run -a                           # lint + format (ruff), what CI runs
uv run pytest                                      # test suite
uv run pytest tests/test_image_build.py::test_image_build --cov build
helm lint charts/valheim                           # chart lint, what CI runs
uv run python -m build.publish                     # build + push the image (see below)
```

CI installs with `uv sync --locked`, so `uv.lock` has to be regenerated (and committed) in the
same change whenever `pyproject.toml` dependencies move. The image publishing job runs
`--no-dev`, so anything `build/` imports belongs in `[project] dependencies`, not the dev group.

`pytest` needs a running Docker daemon: the single test starts a local registry with
testcontainers, runs the real `build.publish` CLI against it and builds the actual image, so it
takes minutes and pulls the Valheim server from Steam.

`build.publish` takes its options from environment variables (`DOCKER_HUB_USERNAME`,
`DOCKER_HUB_TOKEN`, `REGISTRY`, `PUBLISH_MANUALLY`) or the equivalent `--flags`.

## Image versioning: driven by the Steam build ID

There is no semver for the image. `build/utils.py` logs into Steam anonymously, reads the `public`
branch build ID of app `896660`, and tags the image `build-<build_id>` plus `latest`. Before
building, `tag_exists()` queries the Docker Hub tags API and the nightly workflow
(`publish.yaml`, cron 01:15) skips the build when a tag for the current build ID already exists.
`PUBLISH_MANUALLY=1` (also `publish-manual.yaml`, `workflow_dispatch`) overrides that check.

Note `tag_exists()` only inspects the first page of Docker Hub tags.

## How the chart and the image entrypoint fit together

This is the part that spans several files. The chart never passes real values as container args:

1. `statefulset.yaml` passes literal placeholders — `-name "$name"`, `-world "$world"`,
   `-password "$password"`, and a bare `"$crossPlay"` — and sets `CONFIG_FILE_PATH` /
   `SECRET_FILE_PATH` to `/srv/valheim/{config,secret}/$(POD_NAME)`.
2. `configmap.yaml` renders one env-file entry per entry in `.Values.instances`, keyed by the pod
   name (`<fullname>-<ordinal>`), skipping `password` and `service`. `crossPlay: true` becomes
   `crossPlay=-crossplay`, false becomes an empty value that expands to nothing.
   `secret.yaml` does the same for the password (skipped when `existingSecret` is set).
3. `start.sh` sources both files into the environment and runs every argument through `envsubst`.

Consequences when changing things:

* A new per-instance setting means touching `values.yaml`, the exclusion list in `configmap.yaml`,
  and the `args` in `statefulset.yaml` — a value in the ConfigMap alone does nothing.
* Instances are StatefulSet replicas (`replicas: {{ len .Values.instances }}`), so ordering of the
  `instances` list is significant: reordering re-points pods at other instances' config and volumes.
* Ports, resources and probes are shared by all instances; only `service` and the server settings
  are per instance.

`services.yaml` renders one headless service plus a per-pod service selected via
`statefulset.kubernetes.io/pod-name`, so each instance gets its own LoadBalancer IP.

## start.sh signal handling

Kubernetes and Docker send `SIGTERM`, but the Valheim server only saves the world and exits
cleanly on `SIGINT`. `start.sh` runs the server in the background, traps `TERM`/`INT` and forwards
`SIGINT`, enables job control (`set -m`) so the background job does not inherit an ignored
`SIGINT`, and loops on `wait` because a trapped signal makes `wait` return early. Breaking any of
these means no shutdown save and a torn world file. `terminationGracePeriodSeconds` defaults to
300 in the chart for the same reason.

## Releases

* **Python project / image tooling**: release-please on push to `main`, ignoring `charts/**`.
  Version lives in `pyproject.toml` and `.release-please-manifest.json` — do not bump it by hand.
  Requires conventional commit messages.
* **Helm chart**: `helm/chart-releaser-action` on push to `main` touching `charts/**`. It releases
  whatever `version:` is in `Chart.yaml`, so bump that manually in the same PR as chart changes.
  `appVersion` stays `"latest"` since the image tracks Steam builds.

Renovate only runs the `pep621` manager (`pyproject.toml` plus `uv.lock`); the Docker base images
in `build/Dockerfile` (`steamcmd/steamcmd`, `debian:trixie-slim`), the GitHub Actions and the uv
version pinned in `.github/actions/setup-environment/action.yaml` are updated by hand.

## Conventions

Ruff with `select = ["F", "E", "W", "I", "D", "UP", "ASYNC", "RUF"]` and pep257 docstrings — every
module and function needs a docstring; existing ones use the `:param:` / `:return:` style.
`charts` and `examples` are excluded.

The image runs as uid/gid 10001 (`valheim`). Anything writing into `/srv/valheim` — init
containers, volume restores, helper pods — has to match that ownership, see the migration section
in `charts/valheim/README.md`.
