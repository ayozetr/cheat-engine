#!/bin/bash
# Push the source tree to the build machine and rebuild the Linux target.
#
# Point it at your own box:
#   export CE_VM=user@host          (default below)
#   export CE_VM_PASS=...           only if you want sshpass; otherwise use keys
#   export CE_VM_PATH=/path/to/checkout
CE_VM="${CE_VM:-ayoze@BUILD_HOST}"
CE_VM_PATH="${CE_VM_PATH:-/home/ayoze/ce-port}"
SRC="$(cd "$(dirname "$0")" && pwd)/Cheat Engine/"
DST="$CE_VM_PATH/Cheat Engine/"

# with a password set, go through sshpass; otherwise plain ssh and your key
if [ -n "$CE_VM_PASS" ]; then
  RUN=(sshpass -p "$CE_VM_PASS")
else
  RUN=()
fi
SSH="ssh -o StrictHostKeyChecking=no"

# Everything, not just Pascal: main.lua and defines.lua have to sit next to the
# executable or InitializeLuaScripts exits before it reads the autorun folder,
# and the translations and images are needed just as much.
#
# No --delete of any kind. liblinux/ holds the Lua build made on the build
# machine and has no counterpart here, and an earlier --delete-excluded quietly
# stripped every .lua from the remote tree, which took a while to notice.
"${RUN[@]}" rsync -a \
  --exclude='lib/' --exclude='.git/' \
  -e "$SSH" "$SRC" "$CE_VM:$DST" || exit 1

"${RUN[@]}" $SSH "$CE_VM" \
  "cd '$DST' && timeout 2400 lazbuild --build-mode='Linux 64-Bit' cheatengine.lpi 2>&1 | grep -E 'Error|Fatal' | head -70"
