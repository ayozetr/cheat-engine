#!/bin/bash
# Push the source tree to the Mint VM and rebuild the Linux target.
VM=ayoze@BUILD_HOST
PW='***REMOVED***'
SRC="/home/ayoze/dev/cheat-engine/Cheat Engine/"
DST="/home/ayoze/ce-port/Cheat Engine/"

# Everything, not just Pascal: main.lua and defines.lua have to be next to the
# executable or InitializeLuaScripts bails out before it reads autorun, and the
# translations and images are needed just as much.
#
# No --delete of any kind. liblinux/ holds the Lua build made on the VM and has
# no counterpart here, and an earlier --delete-excluded quietly stripped every
# .lua from the remote tree, which took a while to notice.
sshpass -p "$PW" rsync -a \
  --exclude='lib/' --exclude='.git/' \
  -e "ssh -o StrictHostKeyChecking=no" "$SRC" "$VM:$DST" || exit 1

sshpass -p "$PW" ssh -o StrictHostKeyChecking=no $VM \
  "cd '$DST' && timeout 2400 lazbuild --build-mode='Linux 64-Bit' cheatengine.lpi 2>&1 | grep -E 'Error|Fatal' | head -70"
