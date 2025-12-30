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

# Run Valheim dedicated server
./valheim_server.x86_64 "$@"
