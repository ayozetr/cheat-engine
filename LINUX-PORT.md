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

## Where it stopped

**Every unit compiles**, `cheatengine.lpr` included. The build reaches the
linker. What is left is a linking problem, not a porting one.

Two of them were just missing packages, now installed on the VM:

```
sudo apt-get install liblua5.3-dev libsqlite3-dev
```

The one that remains is real. `lua/lua.pas` and `lua/lauxlib.pas` declare four
Lua 5.1 era entry points against `liblua5.3.so`:

```
lua_setfenv   luaL_openlib   luaL_findtable   luaL_prepbuffer
```

Stock Lua 5.3 does not export them. On Windows this never surfaced because
Cheat Engine ships its own `lua53-64.dll`; here FPC's `external <soname>`
becomes a hard undefined reference and `ld` refuses.

The fix is to build the copy already in the repository —
`Cheat Engine/lua53/lua53/src`, which has `luaL_openlib` and `luaL_findtable`
patched back in — as `liblua5.3.so`, with `LUA_COMPAT_MODULE` defined, and put
it where the linker looks. `lua_setfenv` is absent even there and was removed
outright in 5.3, so it needs either a stub or the call sites conditioned out.
Check what the Windows DLL actually exports before deciding which.

### One build trap

An incremental build dies with an internal compiler error:

```
An unhandled exception occurred at $00000000004C7C5E: EAccessViolation
MainUnit.pas(4133,68) Error: (1026) Compilation raised exception internally
```

A clean build gets past the same line without complaint, so it is stale
incremental state, not the source. When it appears, rebuild:

```
lazbuild -B --build-mode='Linux 64-Bit' cheatengine.lpi
```

## What is left

- Sort out the Lua library, above. That is the only thing between here and an
  ELF binary.
- `modernfonts` and `modernabout` are still Windows only (`AddFontResourceEx`,
  `ShellExecute`). They need conditioning before the redesign shows up on
  Linux. Until then the Linux build gets the stock LCL look: `betterControls`
  is almost entirely inside `{$ifdef windows}`, so outside Windows the LCL
  supplies `TButton` and `TForm` and nothing breaks — it just is not styled.
- The DBVM entry points (`ReadPhysicalMemory`, `GetCR3`, the whole `dbk32`
  tree) have no Linux equivalent and should stay behind `{$ifdef windows}`.
  Same for `VEHDebugger`, `WindowsDebugger`, `xinput`, `windows7taskbar`,
  `betterdllsearchpath`, `luaJit`, and the rest of the 24 units that have no
  Linux-visible `uses` — they are Windows-only by nature and simply must not be
  reached from the Linux build.
- Once it links: run it, see how far the UI gets, then decide about the
  AppImage.

## Branch

`linux-port`, on top of the UI redesign work.
