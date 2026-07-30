# Linux smoke test

Proves the Linux port can actually read and write another process's memory,
end to end through Cheat Engine's own Lua API. No clicking involved.

## Running it

Build and start the target. It parks a known value in a global, writes its pid
and the address where they can be found, and prints the value once a second so
you can watch it change from the outside:

```
gcc -O0 -o /tmp/diana tools/smoketest-target.c
/tmp/diana > /tmp/diana.log &
```

Drop the script where Cheat Engine will pick it up, then start it:

```
cp tools/linux-smoketest.lua 'Cheat Engine/bin/autorun/'
cd 'Cheat Engine/bin' && sudo ./cheatengine-x86_64
```

Results land in `/tmp/ce-portcheck.log`.

## sudo is not optional

Ubuntu and Mint ship `kernel.yama.ptrace_scope = 1`, which limits
`process_vm_readv` to a process's own descendants. Without root every read
comes back nil and every write returns false, even though `openProcess`
succeeds — which makes it look like the port is broken when it is only the
kernel policy. Either run as root, as upstream's own Linux build does, or:

```
sudo sysctl -w kernel.yama.ptrace_scope=0
```

## What a good run looks like

```
target pid 28122 addr 5722322C7010
openProcess -> true
opened id -> 28122
readInteger -> 1234567
readBytes -> 87 D6 12 00
writeInteger -> true
readInteger after -> 7654321
enumMemoryRegions -> 31
== done ==
```

and `/tmp/diana.log` starts reporting `valor=7654321`, which is the target
itself confirming the write landed.
