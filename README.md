<h1 align="center">Cheat Engine — UI Redesign</h1>

<p align="center">
  A fork of <a href="https://github.com/cheat-engine/cheat-engine">Cheat Engine</a>
  with a reworked interface and a complete Spanish translation.
</p>

---

## What this is

Cheat Engine works, but it looks its age. Its `.lfm` forms were laid out with
Windows XP metrics — 470 controls are 15 pixels high, 423 are 19, all at 8pt —
and the toolbar still ships the bitmap icons it had twenty years ago.

This fork does not touch the scan engine, the debugger, or anything else that
makes Cheat Engine work. It changes how it looks.

| | |
|---|---|
| **Interface** | Rounded buttons and group boxes, a dark palette, an accent color on active controls |
| **Icons** | 191 line-art icons across seven image lists, replacing the XP era bitmaps |
| **Typography** | Inter for the interface, JetBrains Mono for addresses and disassembly |
| **Metrics** | Larger controls, real spacing, forms that scale with the font |
| **Spanish** | 4136 strings, the interface fully translated |
| **Languages** | 12 bundled instead of 6, all rebuilt against a common template |

Everything can be turned off from the command line to compare against the
original — see [Switches](#switches).

## How it works

Cheat Engine ships a unit called `betterControls` that shadows the LCL control
classes (`TButton = class(TNewButton)` and so on), so adding it to a unit's
`uses` swaps every control for a custom-drawn one. 236 units already import it.

That is the hook this fork builds on. Four units sit next to it:

| Unit | What it does |
|---|---|
| `modernui` | Walks the control tree of every form: fonts, heights, spacing, palette |
| `modernicons` | Replaces image list icons at runtime from PNGs on disk |
| `modernfonts` | Registers the bundled fonts for this process only |
| `modernabout` | Rebuilds the layout of the About dialog |

No `.lfm` file is rewritten. Forms are adjusted once they exist, which is what
makes a change in a handful of files reach all 164 of them.

One find worth mentioning: `globalCustomDraw` is declared in
`bettercontrols.pas` and **never assigned anywhere**, so `csCustomPaint` was
never set and `DefaultCustomPaint` never ran. Every color and border in
`betterControls` was dead code, with Windows painting the controls instead.
Turning it on is what makes the rest possible.

## Building

Needs the exact versions Cheat Engine asks for. Newer ones do not work without
patching.

1. Install **Lazarus 2.2.2 with FPC 3.2.2**, then the i386 cross compiler:
   - `lazarus-2.2.2-fpc-3.2.2-win64.exe`
   - `lazarus-2.2.2-fpc-3.2.2-cross-i386-win32-win64.exe`
2. Build:

```
lazbuild.exe --build-mode="Release 64-Bit" "Cheat Engine/cheatengine.lpi"
```

`laz.virtualtreeview_package` comes with Lazarus; nothing else needs
installing. The result is `Cheat Engine/bin/cheatengine-x86_64.exe` — around
420,000 lines in under a minute.

If the compiler dies with an internal error (`EListError`, `Internal error
200611031`), it is stale incremental state. Build with `-B`.

### What a build needs alongside it

The executable reads three folders at runtime. Without them it still runs, but
falls back to the Windows fonts and the original icons:

```
bin/            the executable
bin/languages/  translations
fonts/          Inter and JetBrains Mono
images/modern/  the icon set
```

## Switches

Pass these on the command line to disable parts of the redesign:

| Switch | Effect |
|---|---|
| `NOMODERNUI` | Original metrics and fonts |
| `NOROUNDING` | Square corners |
| `NOCUSTOMDRAW` | Native Windows painting |
| `NOSCALEFORMS` | No form scaling |
| `NOMODERNICONS` | Original icons |
| `NOMODERNABOUT` | Original About dialog |
| `NOBUNDLEDFONTS` | Segoe UI and Consolas |
| `--LANG es_ES` | Force a language |

## Translations

The Spanish pack on cheatengine.org only translates the tutorial, so the
interface stayed in English. This one is built from `cl_CL`, which covers 99%
but is written without accents and carries real mistakes (`Fast Scan` as
"1erEscaneo", `Not` as "Nada"), with the accents restored and 809 strings
reviewed by hand.

Every other pack came from a different Cheat Engine version, so their message
ids matched neither each other nor the binary: `pt_BR` shipped 2530 entries and
`ja_JP` 4686. `normalize-po.py` rebuilds each one against a common template,
keeping what it already had, which recovered around 900 strings each in German,
Japanese, Chinese and Russian.

French, Chinese Traditional, Korean and Polish are still well short of
complete. Their main windows are translated; the rest falls back to English,
which is what gettext does when a string is missing.

## About Linux

There is no Linux build here, and there cannot be one from this source tree:
`cheatengine.lpi` declares four build targets, all `win32`/`win64`, and the
code carries 1314 `{$ifdef windows}` blocks against zero for Linux.

Cheat Engine **does** have a native Linux build — 7.7 on the official site is an
ELF linked against Qt6, not a Wine wrapper. But its source has not been
published: this repository is still at 7.5, with no commits since April 2025 and
no tag past 7.5. Until that source appears, this fork is Windows only.

The translations are plain `.po` files, so they can be dropped into the official
Linux build's `languages/` folder on their own.

## Credits

- **Cheat Engine** by Dark Byte and its contributors — everything this fork
  builds on
- Icons drawn for this fork in the style of [Lucide](https://lucide.dev)
- [Inter](https://rsms.me/inter/) by Rasmus Andersson, SIL Open Font License
- [JetBrains Mono](https://www.jetbrains.com/lp/mono/), SIL Open Font License
- Spanish translation derived from the `cl_CL` community pack

Interface redesign by **ayozetr**.

## Licensing

Read this before redistributing anything from here.

**Upstream Cheat Engine declares no license.** There is no license file in the
repository, no statement in its README, and no license field on GitHub. Without
one, the default is that the authors reserve all rights: nobody has an implicit
right to redistribute it or to publish derivative works.

A fork cannot fix that by adding a license file. Picking one here would mean
relicensing someone else's work, which is not ours to do. So this fork declares
no project-wide license and inherits the situation as it stands.

What can be said about the individual pieces:

| Part | Terms |
|---|---|
| Upstream Cheat Engine code | No declared license; all rights reserved by its authors |
| Some units within it (`cetranslator`, `LuaSyntax`, `SynHighlighter*`) | Carry GPL / LGPL / MPL headers of their own |
| Third-party components (`tcclib`, `lua`, `distorm`) | Ship their own license files |
| Inter and JetBrains Mono | SIL Open Font License, see `Cheat Engine/fonts/` |
| The icons and the four `modern*` units added here | Written for this fork |

If you plan to publish builds, the honest summary is that upstream's terms are
undefined, so the safe reading is that redistribution needs Dark Byte's
permission. Ask first.
