# Linux port — working notes

Where the Linux build stands, and how to pick it up again.

## The short version

Upstream Cheat Engine has never compiled on Linux. The published 7.7 Linux
binary is a native Qt6 ELF, but its sources were never released: releases and
tags stop at 7.5 (February 2023), the source ZIP contains no Pascal for it, and
none of the five active forks carry a Linux target. So this is a real port, not
a rebuild.

Two things had to happen:

1. **`linuxmemoryapi.pas`** — a compatibility unit standing in for the Windows
   API that `NewKernelHandler` and the rest of the tree call into. Verified
   working against live processes on the VM: memory read/write, region queries,
   and process/thread/module enumeration.
2. **Per unit Linux branches** — the tree's `uses` clauses only ever had
   `windows`, `darwin` and `jni` cases. Every unit reachable from the Linux
   build needs a fourth.

## The VM

```
sshpass -p '***REMOVED***' ssh ayoze@BUILD_HOST      # Linux Mint, Lazarus 3.0 + FPC 3.2.2
```

Repository lives at `~/ce-port`. Note the space in `Cheat Engine`: `scp` chokes
on it, so the helper scripts use `rsync`.

## The loop

Edit locally under `/home/ayoze/dev/cheat-engine/Cheat Engine`, then:

```
./sync-linux.sh          # rsync every source file, then rebuild, print errors
./build-linux.sh a.pas b.pas   # push only these files, then rebuild
```

`sync-linux.sh` is the one to use — it cannot leave the VM out of date.

A full build takes roughly six to twelve minutes, so run it in the background
and read the output file rather than waiting on it.

Build mode: `Linux 64-Bit` (item 12 in `cheatengine.lpi`, `TargetOS=linux`,
`TargetCPU=x86_64`, `-dLCLgtk2`). The six Windows modes are untouched.

## What compiles today

Essentially the whole tree. The heavyweights are through: `MainUnit` (11 500
lines), `LuaHandler` (17 400), `MemoryBrowserFormUnit`, `disassembler`,
`pointerscannerfrm`, `debughelper`, `autoassembler`, `tcclib`, and both
ultimap forms. Also `linuxmemoryapi`, `networkInterface`, `networkInterfaceApi`,
`plugin`, `pluginexports`, `symbolhandler`, `disassemblerarm`,
`disassemblerviewunit`, `pointerparser`, `PointerscanresultReader`,
`pointervaluelist`, `pointerscanworker`, `rescanhelper`, `savedscanhandler`,
`MemoryRecordUnit`, `memoryquery`, `memscan`, `ProcessWindowUnit`,
`processlist`, `PEInfounit`, `CEFuncProc`, `gdbserverdebuggerinterface`,
`networkdebuggerinterface`, `bigmemallochandler`, `mikmod`, `pagemap`,
`celazysocket`, `multilineinputqueryunit`, `SynHighlighterAA`, `DPIHelper`,
`LuaInternet`, `luaremotethread`, `luavirtualstringtree`, `StructuresFrm2`,
`frmThreadlistunit`, `frmMemoryViewExUnit`, `frmluaengineunit`, and the ~50
units whose `uses` order was corrected.

Build mode options ended up as `-dLCLgtk2 -dNESTEDSTRUCTURES`. `-dlaztrunk`
looked tempting — Lazarus 3's bundled VirtualTrees only exports
`TCustomVirtualStringTree` — but it also flips `AVL_Tree` for `laz_avl_Tree`,
which is backwards here. The VirtualTrees case is handled at the one call site
instead.

## Recurring problems, and how they were settled

**`uses` clause with no Linux case.** The commonest failure by far. Shape is
either `{$ifdef darwin} ... {$else} windows ... {$endif}` (Linux silently takes
the Windows branch) or a chain of `{$ifdef}` blocks with no fallthrough (Linux
gets no `uses` at all, and the compiler reports a syntax error at whatever
keyword follows). Fix: add an explicit
`{$if not defined(windows) and not defined(darwin)}` branch, modelled on the
darwin one minus `macport`/`MacTypes`/`macportdefines`.

**`linuxmemoryapi` listed after `newkernelhandler`.** Then its plain functions
shadow `NewKernelHandler`'s function-pointer variables, and code that does
`assigned(Process32First)` stops compiling. `linuxmemoryapi` must come first in
the clause. Corrected in 51 units.

**Missing `math`, `lcltype` and `LCLIntf`.** `min`/`max` live in `math`, the
`VK_*` constants and `DEFAULT_CHARSET` in `lcltype`, and `GetSystemMetrics` /
`GetForegroundWindow` in `LCLIntf`. On Windows all three arrived through the
`windows` unit, so the Linux branch has to name them.

Watch for duplicates: adding `math` where it is already in scope is an error,
not a warning, and "already in scope" includes the *implementation* section's
own `uses`. When sweeping this in bulk, check both clauses, and ignore any
`math` that sits inside a `{$ifdef windows}` or `{$ifdef darwin}` block — it is
not visible from here. Roughly a third of my bulk edits had to be reverted for
exactly this, one build cycle each.

**`TMessage`.** Does not exist outside Windows. `TLMessage` from `LMessages`
does, and on Windows `LMessages` defines `TLMessage = TMessage`, so switching
to `TLMessage` everywhere is correct on both. Done in seven units.

**Pascal is case insensitive.** `size_t = SIZE_T` and `BYTE = byte` are self
references, not aliases. Cost me three build cycles.

**`{$elseif}` only follows `{$if}`.** After `{$ifdef}` it has to be
`{$if defined(...)}`.

## Where it stands

**It builds, links and runs.** `bin/cheatengine-x86_64` is a 21 MB native ELF,
419 000 lines compiled. Started under X it stays up with no exceptions at all,
and the window manager reports the window as `WM_CLASS = "cheatengine-x86_64"`
with a dialog open.

### Getting there from a clean checkout

Two system packages:

```
sudo apt-get install libsqlite3-dev
```

Do **not** install `liblua5.3-dev`. Its `liblua5.3.so` sits in a search
directory that comes before ours, and it lacks the compatibility entry points
below. If it is already installed, remove it.

Build the Lua that ships in this repository, which is the same one the Windows
and mac builds use:

```
cd 'Cheat Engine/lua53/lua53/src'
gcc -O2 -fPIC -DLUA_USE_LINUX -DLUA_COMPAT_5_1 -c $(ls *.c | grep -vE '^(lua|luac|wmain)\.c$')
gcc -shared -Wl,-soname,liblua5.3.so -o liblua5.3.so *.o -lm -ldl
cp liblua5.3.so '<repo>/Cheat Engine/liblinux/'
```

`LUA_COMPAT_5_1` is what brings back `luaL_openlib`. `wmain.c` is Windows only.
The build mode points at `liblinux` with `-Flliblinux` and records
`-k-rpath='$ORIGIN/../liblinux'`, so the executable finds its own Lua at run
time without anything being installed system wide — which is what the AppImage
will need anyway.

Three of the Lua entry points could not be supplied by any build. `lua_setfenv`
and `lua_getfenv` were removed in 5.2, `luaL_findtable` is static in the
bundled `lauxlib.c`, and none of the three is called from Cheat Engine, so they
became ordinary Pascal stubs. `luaL_prepbuffer` and `luaL_loadbuffer` are
macros in 5.3 and now call `luaL_prepbuffsize` and `luaL_loadbufferx`. The
Windows `.def` exports neither of the originals either, so these were latent
bugs on every platform.

### Two things that cost real time

**Always build with `-B`.** An incremental build produces nonsense errors in
`MainUnit` about `TMemoryRecord` versus `TMemoryRecordHotkey`, and sometimes an
outright compiler crash. A clean build passes the same lines without a word. It
is stale `.ppu` state; when in doubt, `rm -rf lib/x86_64-linux` as well.

**`cthreads` has to be the first unit in the program.** The `UseCThreads`
guard in `cheatengine.lpr` never fires in this build mode, so without an
explicit Linux branch the binary dies immediately with runtime error 211.

### The last real bug

The first run crashed with an access violation before the main form appeared.
`NewKernelHandler` fills its function pointers from `GetProcAddress` on Windows
and from `macport` on darwin — there was no third branch, so on Linux every one
of them stayed nil and the first call through one went straight through a null
pointer. The Linux branch now wires them to `linuxmemoryapi`. Compiling was
never going to be enough on its own.

## What has actually been verified

It runs, and the memory layer works through the real UI, not just in isolation:

- The main window comes up complete — menus, address list, scan panel, memory
  scan options, the lot.
- The process list is populated from `/proc`: **330 processes, enumerated twice
  in a row**, with correct names (`sshd: ayoze [priv]`, `bash`, `diana`,
  `cheatengine-x86_64`). That exercises `CreateToolhelp32Snapshot` ->
  `Process32First`/`Next` -> `NewKernelHandler` -> the list box.
- The Spanish translation loads: the first-run dialog offers *No / Sí*.

Not yet exercised: opening a process from the UI, scanning, and editing a
value. Driving that through xdotool turned out to be slow and fragile, and it
is the obvious next thing to confirm.

### Driving the UI headlessly

The VM's own screen is usually locked, so use a virtual display. A window
manager is required — without one, focus never settles and clicks land
unpredictably:

```
Xvfb :77 -screen 0 1400x900x24 &
DISPLAY=:77 openbox &
DISPLAY=:77 ./cheatengine-x86_64 &
DISPLAY=:77 import -window root /tmp/shot.png
```

`CE_APILOG=/path/to/log` makes `linuxmemoryapi` trace what it is asked for —
snapshots taken, rows read, calls made. Off unless the variable is set. It
writes straight to the file because stderr is buffered when redirected, which
cost me a couple of confusing runs.

## Known broken

- **Switching tabs in the process list empties it.** The `TabHeader` change
  handler never fires under gtk2, so `getprocesslist` is not called again and
  the list is left cleared. The list is correct when the dialog first opens;
  only tab switching breaks it. This is an LCL event problem, not a memory
  layer one — the trace shows no snapshot is even requested.
- **The autorun folder is never read.** `InitializeLuaScripts` is reached and
  `noautorun` is false, but no `.lua` under `bin/autorun/` is opened — strace
  shows the directory is never touched. Not chased down yet. `UTF8ToWinCP` was
  removed from the path it passes to `lua_dofile`, since converting a UTF-8
  filename to a Windows codepage can only damage it, but that alone did not fix
  it.
- Kernel thread names show up mangled (`kworker/R-rcu_gp` as `R-rcu_gp`).
  That is `ExtractFilename` in `processlist.pas` treating the `/` as a path
  separator. Cosmetic, and only affects processes that cannot be opened anyway.

## What is left

- Attach to a process, scan for a value, edit it. A tiny target is already on
  the VM at `/tmp/diana.c` — it holds 1234567 in a global and sleeps, and
  prints its pid and the address on startup.
- The two broken things above: the tab handler and autorun.
- `SuspendThread`, `GetThreadContext` and the `VirtualProtectEx` family report
  failure rather than working. They need a ptrace-stopped tracee. The debugger
  will not do anything useful until then.
- `modernfonts` and `modernabout` are still Windows only, so the Linux build
  gets the stock LCL look rather than the redesign.
- `-gl` is still in the build mode for readable stack traces. Take it out for a
  release build.
- Then: AppImage.

## Branch

`linux-port`, on top of the UI redesign work.
