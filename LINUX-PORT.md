# Linux port — working notes

Where the native Linux build stands, and how to pick it up again.

**Looking to actually use Cheat Engine on Linux?** Read `PROTON.md` first. For
Windows games this port is the wrong tool: running the Windows build inside the
game's own Wine prefix keeps the debugger and the Auto Assembler, which this
port does not have. What follows is about the native port itself.

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

A Linux Mint box with Lazarus 3.0 and FPC 3.2.2. The helper scripts take it
from the environment, so point them wherever you build:

```
export CE_VM=user@host
export CE_VM_PATH=/path/to/checkout    # holds "Cheat Engine/"
export CE_VM_PASS=...                  # only if you are not using ssh keys
```

Note the space in `Cheat Engine`: `scp` chokes on it, which is why the file
sync goes through `rsync` and the single-file helper moves through `/tmp`.

## The loop

Edit locally in your checkout, then:

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

**It reads and writes another process's memory.** That is the whole point of
the program, and it works:

```
openProcess -> true
readInteger -> 1234567
readBytes -> 87 D6 12 00
writeInteger -> true
readInteger after -> 7654321
enumMemoryRegions -> 31
```

and the target process itself started reporting the new value, so the write
really landed. `tools/` holds the target and the script; see `tools/README.md`.

Also confirmed:

- The main window comes up complete — menus, address list, scan panel, memory
  scan options.
- The process list is populated from `/proc`: 330 processes, twice in a row,
  with correct names. That is `CreateToolhelp32Snapshot` -> `Process32First`/
  `Next` -> `NewKernelHandler` -> the list box.
- `autorun` runs, so Lua scripting works.
- The Spanish translation loads: the first-run dialog offers *No / Sí*.

### It needs root, and that is the kernel's doing

Ubuntu and Mint set `kernel.yama.ptrace_scope = 1`, which limits
`process_vm_readv` to descendants of the calling process. Run as an ordinary
user, `openProcess` succeeds and then every read returns nil and every write
false — which reads like a broken port but is policy. Upstream's own Linux
build asks for root for the same reason.

### Driving the UI headlessly

The VM's own screen is usually locked, so use a virtual display. A window
manager is required — without one focus never settles and clicks land
unpredictably, which cost me a good while:

```
Xvfb :77 -screen 0 1400x900x24 &
DISPLAY=:77 openbox &
DISPLAY=:77 ./cheatengine-x86_64 &
DISPLAY=:77 import -window root /tmp/shot.png
```

`CE_APILOG=<file>` makes `linuxmemoryapi` trace what it is asked for. Off
unless set. It writes straight to the file because stderr is buffered when
redirected, which cost me a couple of confusing runs where the log looked
empty.

For a crash, `gdb -q -batch -ex run -ex 'bt 25' ./cheatengine-x86_64` is worth
reaching for early — it is what found the recursion described below in one go.

## Known broken

- **Several shipped autorun scripts fail**, because they pull in libraries that
  only exist as Windows DLLs — `lfs` (LuaFileSystem) is the obvious one. Each
  failure used to raise a modal dialog, and a modal dialog per broken script
  blocks startup outright, so on Linux the error is now reported through
  `CE_APILOG` and the loader carries on. `javaclass.lua` was a different case:
  it wrote `require([[autorun\javaClassEditor]])`, and a backslash is just a
  character in a path here, so that one is fixed properly.
- Kernel thread names show up mangled (`kworker/R-rcu_gp` as `R-rcu_gp`).
  That is `ExtractFilename` in `processlist.pas` treating the `/` as a path
  separator. Cosmetic, and only affects processes that cannot be opened anyway.
- The debugger does nothing. `SuspendThread`, `GetThreadContext` and the
  `VirtualProtectEx` family all report failure, because they need a
  ptrace-stopped tracee and none of that is written. Scanning and editing do
  not go through them.

### Not confirmed

I earlier wrote that switching tabs in the process list empties it and blamed
the gtk2 `OnChange`. I could not reproduce that once a window manager was
running, and the original evidence came from clicks made without one, which I
later found land unpredictably. Treat it as unverified rather than as a known
bug: check it by hand before spending time on it.

## What is left

- Confirm or dismiss the tab behaviour described above.
- `SuspendThread`, `GetThreadContext` and the `VirtualProtectEx` family report
  failure rather than working. They need a ptrace-stopped tracee, so the
  debugger will not do anything useful until that is written. Scanning and
  editing do not depend on it.
- `modernfonts` and `modernabout` are still Windows only, so the Linux build
  gets the stock LCL look rather than the redesign.
- `-gl` is still in the build mode for readable stack traces, which is why the
  binary is 93 MB. Take it out for a release build.
- Then: AppImage. It will need `liblinux/liblua5.3.so` bundled alongside; the
  `$ORIGIN` rpath already points at it.

## Branch

`linux-port`, on top of the UI redesign work.
