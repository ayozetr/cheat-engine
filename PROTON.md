# Using this build on Linux, through Proton

For Windows games, the native Linux port in `LINUX-PORT.md` is the wrong tool.
Run the Windows build under the same Wine prefix as the game instead. You keep
the whole program — debugger, Auto Assembler, code injection — and you get the
redesigned interface with it.

## Why, in one paragraph

A game launched through Proton is a Windows process living inside a Wine
prefix. Cheat Engine running natively on Linux sees it as an ordinary Linux
process: it can read and write its memory, but the module list, the PE headers
and the debug API it expects are not there. Cheat Engine running *inside the
same prefix* sees a normal Windows process, and Wine implements
`ReadProcessMemory`, `VirtualAllocEx` and the debug API on its behalf. Same
program, same prefix, everything works.

## Steam games

Install `protontricks` — it exists to run an arbitrary executable inside a
specific game's prefix:

```
sudo apt install protontricks         # or: flatpak install com.github.Matoking.protontricks
```

Find the game's app id:

```
protontricks -l
```

Unpack this build somewhere convenient, say `~/cheatengine/`.

Start the game and let it reach the main menu. Then, in another terminal:

```
protontricks-launch --appid 220 ~/cheatengine/cheatengine-x86_64.exe
```

(`220` is Half-Life 2; use your own.) Cheat Engine opens inside that prefix,
and its process list shows the game.

### Without protontricks

Same thing by hand. Proton needs two variables to know which prefix to use:

```
export STEAM_COMPAT_CLIENT_INSTALL_PATH=~/.steam/steam
export STEAM_COMPAT_DATA_PATH=~/.steam/steam/steamapps/compatdata/220
"~/.steam/steam/steamapps/common/Proton - Experimental/proton" run \
    ~/cheatengine/cheatengine-x86_64.exe
```

Use the same Proton version the game runs with, or the prefix may get upgraded
under you.

## Non-Steam games under plain Wine

Simpler — just make sure the prefix matches:

```
WINEPREFIX=~/.wine-mygame wine ~/cheatengine/cheatengine-x86_64.exe
```

## What will not work under Wine

- **The kernel driver (DBK).** It is a real Windows kernel module and Wine has
  no kernel to load it into. Leave the kernel-mode options off; the user-mode
  debugger covers ordinary work.
- **DBVM.** It is a hypervisor. Not happening here.
- Anything that leans on undocumented Windows internals may be flaky. If
  something misbehaves, try the VEH debugger before assuming the game is at
  fault.

Scanning, pointer scanning, the memory viewer, the disassembler, breakpoints
and Auto Assembler are all ordinary user-mode work and are what people actually
use under Wine.

## Which build for which game

Match the architecture: the 64-bit executable for a 64-bit game, the 32-bit one
for a 32-bit game. A mismatch shows the process but reads nothing sensible.

## Honestly: not verified here

I have not run this build under Wine myself, so the steps above are the
established way of doing it rather than something I watched work. The parts I
did verify are in `LINUX-PORT.md`, and they concern the native port, not this.
If you try it and something is off, the first two things to check are that the
prefix really is the game's and that the architectures match.

## And the native port?

Still worth having, for a narrower job: native Linux processes, where you want
to scan and edit values without dragging Wine into it. It cannot debug or
inject yet. `LINUX-PORT.md` says exactly where it stands.

For attaching to native Linux processes with the full program, upstream's own
answer is `Cheat Engine/ceserver/` — it runs natively here with ptrace and
debug registers, and Cheat Engine connects to it over the network. That is a
better foundation than the port for anything needing a debugger.
