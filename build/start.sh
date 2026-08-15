#!/bin/bash
# Set Valheim specific environment variables
export LD_LIBRARY_PATH=./linux64:$LD_LIBRARY_PATH
export SteamAppId=892970

# When this image is run using the Helm chart, the Helm chart creates files containing environment variables
# with server configuration and the rcon password. These environment variables are exported to the current shell
# if those files exist.
if [[ -n "${CONFIG_FILE_PATH}" ]]; then
  if [[ -f "${CONFIG_FILE_PATH}" ]]; then
    set -a; source "${CONFIG_FILE_PATH}"; set +a
  else
    echo "SECRET_FILE_PATH is set, but file with environment variables at ${CONFIG_FILE_PATH} does not exit"
    exit 1
  fi
fi

if [[ -n "${SECRET_FILE_PATH}" ]]; then
  if [[ -f "${SECRET_FILE_PATH}" ]]; then
    set -a; source "${SECRET_FILE_PATH}"; set +a
  else
    echo "SECRET_FILE_PATH is set, but file with environment variables at ${SECRET_FILE_PATH} does not exit"
    exit 1
  fi
fi

# Expand environment variables in arguments which are specified by the Helm chart
EXPANDED_ARGS=()
for ARG in "$@"; do
  EXPANDED_ARGS+=("$(printf '%s' "$ARG" | envsubst)")
done
set -- "${EXPANDED_ARGS[@]}"

# Run Valheim dedicated server in the background so this script can forward shutdown signals to it.
# Kubernetes and Docker send SIGTERM on shutdown, but the Valheim server only saves the world and
# exits cleanly on SIGINT. Without this handler bash would die on SIGTERM without signalling the
# server at all, which then gets SIGKILLed as soon as PID 1 is gone: no shutdown save, and a torn
# world file when the kill lands while the server is writing one.
terminate() {
  kill -INT "${SERVER_PID}" 2>/dev/null
}
trap terminate INT TERM

# Enable job control. Without it bash starts background jobs with SIGINT set to SIG_IGN, so the
# server would inherit an ignored SIGINT and our shutdown signal below would have no effect.
set -m

./valheim_server.x86_64 "$@" &
SERVER_PID=$!

set +m

# A trapped signal makes wait return immediately with 128+signum, so keep waiting until the server
# process is really gone to pick up its actual exit code.
while true; do
  wait "${SERVER_PID}"
  EXIT_CODE=$?
  kill -0 "${SERVER_PID}" 2>/dev/null || break
done

exit "${EXIT_CODE}"
