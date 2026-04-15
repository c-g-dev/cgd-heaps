#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -h "${SCRIPT_PATH}" ]; do
  SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
  SCRIPT_PATH="$(readlink "${SCRIPT_PATH}")"
  if [[ "${SCRIPT_PATH}" != /* ]]; then
    SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_PATH}"
  fi
done

SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
LIB_PATH="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALL_DIR="${CGDHEAPS_BIN_DIR:-${HOME}/.local/bin}"
TARGET="${INSTALL_DIR}/cgdheaps"

if [ ! -f "${LIB_PATH}/cgdheaps.hl" ]; then
  echo "Could not locate cgdheaps.hl at ${LIB_PATH}." >&2
  exit 1
fi

mkdir -p "${INSTALL_DIR}"

LIB_PATH_ESCAPED="${LIB_PATH//\\/\\\\}"
LIB_PATH_ESCAPED="${LIB_PATH_ESCAPED//\"/\\\"}"

cat > "${TARGET}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

LIB_PATH="${LIB_PATH_ESCAPED}"

if [ ! -f "\${LIB_PATH}/cgdheaps.hl" ]; then
  echo "Could not locate cgdheaps.hl at \${LIB_PATH}." >&2
  exit 1
fi

export CGDHEAPS_CWD="\${PWD}"
export CGDHEAPS_LIB_ROOT="\${LIB_PATH}"
exec hl "\${LIB_PATH}/cgdheaps.hl" "\$@"
EOF

chmod +x "${TARGET}"

echo "Installed cgdheaps launcher to ${TARGET}"

if [[ ":${PATH}:" == *":${INSTALL_DIR}:"* ]]; then
  echo "PATH already includes ${INSTALL_DIR}"
  exit 0
fi

SHELL_RC="${CGDHEAPS_SHELL_RC:-${HOME}/.bashrc}"
if [ "${INSTALL_DIR}" = "${HOME}/.local/bin" ]; then
  PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
else
  PATH_LINE="export PATH=\"${INSTALL_DIR}:\$PATH\""
fi

PATH_LINE_PRESENT=0
if [ -f "${SHELL_RC}" ]; then
  while IFS= read -r line || [ -n "${line}" ]; do
    if [ "${line}" = "${PATH_LINE}" ]; then
      PATH_LINE_PRESENT=1
      break
    fi
  done < "${SHELL_RC}"
fi

if [ "${PATH_LINE_PRESENT}" -eq 0 ]; then
  printf "\n%s\n" "${PATH_LINE}" >> "${SHELL_RC}"
  echo "Added ${INSTALL_DIR} to PATH in ${SHELL_RC}"
else
  echo "PATH line already present in ${SHELL_RC}"
fi

echo "Open a new terminal, or run: source \"${SHELL_RC}\""
