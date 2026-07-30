#!/bin/bash
# Push every source file to the Mint VM and rebuild the Linux target.
VM=ayoze@BUILD_HOST
PW='***REMOVED***'
SRC="/home/ayoze/dev/cheat-engine/Cheat Engine/"
DST="/home/ayoze/ce-port/Cheat Engine/"

sshpass -p "$PW" rsync -a --delete-excluded \
  --include='*/' --include='*.pas' --include='*.lfm' --include='*.lpi' --include='*.inc' --include='*.lpr' \
  --include='*.res' --include='*.rc' --include='*.lrs' --include='*.o' --include='*.a' \
  --exclude='*' \
  -e "ssh -o StrictHostKeyChecking=no" "$SRC" "$VM:$DST" || exit 1

sshpass -p "$PW" ssh -o StrictHostKeyChecking=no $VM \
  "cd '$DST' && timeout 2400 lazbuild --build-mode='Linux 64-Bit' cheatengine.lpi 2>&1 | grep -E 'Error|Fatal' | head -70"
