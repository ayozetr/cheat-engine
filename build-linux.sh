#!/bin/bash
# Push only the named files, then rebuild. Faster than sync-linux.sh when you
# know exactly what you touched. Paths are relative to "Cheat Engine/".
#
#   ./build-linux.sh linuxmemoryapi.pas MainUnit.pas
#
# Same environment variables as sync-linux.sh.
CE_VM="${CE_VM:-ayoze@BUILD_HOST}"
CE_VM_PATH="${CE_VM_PATH:-/home/ayoze/ce-port}"
SRC="$(cd "$(dirname "$0")" && pwd)/Cheat Engine"
DST="$CE_VM_PATH/Cheat Engine"

if [ -n "$CE_VM_PASS" ]; then
  RUN=(sshpass -p "$CE_VM_PASS")
else
  RUN=()
fi
SSH="ssh -o StrictHostKeyChecking=no"

for f in "$@"; do
  # scp chokes on the space in "Cheat Engine", so the file lands in a temp name
  # and gets moved into place
  base=$(basename "$f")
  "${RUN[@]}" scp -o StrictHostKeyChecking=no "$SRC/$f" "$CE_VM:/tmp/$base" >/dev/null || exit 1
  "${RUN[@]}" $SSH "$CE_VM" "mv /tmp/$base '$DST/$f'" || exit 1
done

"${RUN[@]}" $SSH "$CE_VM" \
  "cd '$DST' && timeout 2400 lazbuild --build-mode='Linux 64-Bit' cheatengine.lpi 2>&1 | grep -E 'Error|Fatal' | head -70"
