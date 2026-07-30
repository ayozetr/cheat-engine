#!/bin/bash
# Sync the given files to the Mint VM and rebuild the Linux target.
# Usage: build-linux.sh [file relative to "Cheat Engine/" ...]
VM=ayoze@BUILD_HOST
PW='***REMOVED***'
SRC="/home/ayoze/dev/cheat-engine/Cheat Engine"
DST='/home/ayoze/ce-port/Cheat Engine'

for f in "$@"; do
  base=$(basename "$f")
  sshpass -p "$PW" scp -o StrictHostKeyChecking=no "$SRC/$f" "$VM:~/tmp/$base" >/dev/null || exit 1
  sshpass -p "$PW" ssh -o StrictHostKeyChecking=no $VM "mv ~/tmp/$base '$DST/$f'" || exit 1
done

sshpass -p "$PW" ssh -o StrictHostKeyChecking=no $VM "cd '$DST' && timeout 2400 lazbuild --build-mode='Linux 64-Bit' cheatengine.lpi 2>&1 | grep -E 'Error|Fatal' | head -70"
