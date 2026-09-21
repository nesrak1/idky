# nako's waffle engine for snes

A simple engine for the SNES. It was originally made as a platformer engine for the 2025 SNES gamejam (High Branch), but later repurposed for IDKY/IHYT. For more info about the game itself, please see the `planning` folder.

The code in this engine has some... interesting decisions. I am not a professional SNES game developer! Read below to understand what they are and how to make your experience less bad.

## to build

Subject to change. Build process is not super smooth yet, just enough to have things working.

- Have ca65/ld65 on your path
- Have superfamiconv in the tools folder (0.12.0-beta4 or newer)
- Install ortools for Python (`pip install ortools`)
- Run `make`

## project structure

Excluding `.inc`s paired with `.s` for obvious reasons.

```
├── assetgen (temporary build directory for assets)
│   └── all_assets.s (list of all assets that were compiled)
├── assets (assets go here)
│   └── index.py (list of all assets to be compiled)
├── build (temporary build directory for code)
├── docs (docs)
├── readme.md (you are here!)
├── src (all human-written assembly goes here)
│   ├── ihyt (ihyt specific game code)
│   │   ├── main_pf.s (entrypoint for plaformer mode)
│   │   ├── main_vn.s (entrypoint for VN mode)
│   │   ├── pf_asc_macros.inc (platformer's ASC script macros)
│   │   ├── pf_asc.s (platformer's ASC code)
│   │   ├── pf_npc.s (platformer's NPC/entity code)
│   │   ├── vn_char.s (VN's character sprite code)
│   │   └── vn_text.s (VN's char text/VWF code)
│   ├── root (top-level code, start here)
│   │   ├── header.s (rom header)
│   │   ├── reset.s (rom reset starts here)
│   │   └── variables.s (master variables list)
│   └── waffle
│       ├── wf_macros.inc (simplified asm instruction macros)
│       ├── wf_regs.inc (SNES hardware register defines)
│       └── wf_video.inc (PPU related macros)
└── tools
```

## extension

This project was developed in VS Code with a modified version of the
`ca65 Macro Assembler Language Support` extension.

## annotations (two semicolons)

All annotations are in the format `;; [annotation] params`.

You can write annotation params on multiple lines, assuming the next line begins with
`;; ` and does not start with a new annotation in square brackets. For specifically
inputs, outputs, and kills, you can write `?` to denote that they are unknown. This is
effectively the same as not writing the annotations altogether.

---

```asm
;; [assume] A16, XY16
```

Assume register sizes before the function is called. By default, A is 8 is XY is 16.
Use this if the register sizes are required to be different from the defaults.

```asm
;; [inputs] X: comment 1, Y: comment 2, A: comment 3, MEM0: comment 4, MEM1: comment 5
;; [outputs] none
```

The inputs and outputs to a function. For `X`, `Y`, and `A` registers, write `X`, `Y`,
and `A`. For other values stored in memory (usually in DP), use label names.
The comment field is optional. If not provided, do not use a colon. If there are no
inputs or outputs, write `none` alone. If the inputs are on a macro, use `m0`, `m1`, ...

Currently the project is inconsistent on this. Will need to be cleaned up sometime...

```asm
;; [desc] Some description
```

A description of what the function does and how it works.

```asm
;; [kills] A, X, Y
```

The list of registers that are clobbered when this function exits. Registers are written
altogether with no commas or spaces. If there are no clobbered registers, write `none`
alone (although this is unlikely).

```asm
;; [noreturn]
```

Marks that the function never returns, usually because of an infinite loop.

```asm
;; [inlined]
```

Marks that a function is "inlined". This really just means "behave like a regular
`.proc FunctionName`/`.endproc` but using `.macro FunctionName`/`.endmacro` instead.
You can use `inlinedcall FunctionName` to make it appear as if there is a "call"
happening rather than just inlining the function, but this is optional.

---

To prevent accidental annotation usage, regular comments should always be a single
semicolon followed by a space:

```asm
; my comment
```

If you want to use more semicolons, put them after the space:

```asm
; ;;;;;;;;;;;;;;;;;;;;
```

## comments

Typically, comments never have capitalized first letters in sentences. Short phrases
typically do not have periods, while longer sentences that wrap multiple lines do
have periods at the end.

There are certain phrases that appear in my code regularly (including out of this
specific project!) that are searchable:

- "todo: ~~~" - todo, self explanatory
- "note: ~~~" - something important to note?
- "please don't ~~~" - dangerous: no guardrails on this function/table
- "; + ~~~" - `stz` sets two variables at once because it is in 16-bit mode
- "; ..." - when standalone, means a repeat of the above comment(s)

## registers

The registers are renamed from the "official" names you'll see on the snesdev wiki.
I grabbed `wf_regs.inc` off of some GitHub repo I'm pretty sure doesn't exist anymore.
If you are looking up something on the wiki, it's probably best to search the register
by address rather than by name.

## nako tips

### change entry point

The different "modes" the game can be in should be placed in `ihyt`. You can change
which one is the initial entry point by modifying where `root/reset.s`'s jump goes.

## assembly tips

Always import `wf_macros.inc` and probably `wf_regs.inc`. For many other tasks, look
through the other `wf_xxx.inc` scripts to see if they apply to what you're doing.

### scratch variables

Inevitably, you will need to read/write more than 3 registers. This is where scratch
"registers" come in. There are six 16-bit scratch registers, `VScw0` to `VScw5` and four
8-bit scratch registers, `VScb0` to `VScb3`. Do not assume the values will remain the
same between function calls unless the function description says otherwise.

They are also often used for additional arguments into a function that needs more than
what you can do with just `A`, `X`, and `Y`. Typically, you start at the highest possible
temp value so that you don't accidentally overwrite the caller's own usage of them.

### variable memory usage

If you need more scratch variables than are available, you should probably create new
variables dedicated to whatever your task is. If the task is simple and used frequently,
put them in the `ZEROPAGE`. If they are used somewhat frequently but not very big, put
them in LORAM's non-zeropage space (aka `BSSLO`). If values are large but not used very
frequently at all (for example, only during load), place them in HIRAM (`BSSHI`).

For reference:

- `ZEROPAGE`: bytes `$000000-$0000FF` (dp, very fast)
- `BSSLO`: bytes `$000100-$001FFF` (absolute, fast)
- `BSSHI0`: bytes `$7E2000-$7EFFFF` (far, slow unless DMA)
- `BSSHI1`: bytes `$7F0000-$7FFFFF` (far, slow unless DMA)

### register size switching

Switch `A` registers with `A16` and `A8`/`A8Zero` macros. Switch `X`/`Y` registers with
`XY16` and `XY8` macros. `A8Zero` is usually preferred unless you know you don't need it.
It zeroes the A register out, including the upper byte of `A` before switching `A` to its
8-bit variant. Make sure `A` is the 16-bit variant first, otherwise this won't work.
It is also suggested to always provide them for macros, since macros often are more likely
to expect a different register size configuration than functions.

If `DP` is not set to 0, you can clear `A` by calling `AZeroSafe`, or only the top half
by calling `AZeroUpperSafe` (faster). You should use `a:` to address zeropage regions
during this time.

By default, everything is assumed to be `A8`/`XY16`. When creating a function where
register sizes are assumed to be different from `A8`/`XY16`, you should manually set
`.a8`/`.a16` and `.i8`/`.i16` before the function and restore the defaults (`.a8` and
`.i16`) after the function.

### normal add and sub

Included in `wf_macros.inc` is `.macpack generic` meaning `add` and `sub` are "imported"
from ca65. Unless you know you can use `adc` and `sbc`, you should always try to use the
`add` and `sub` pseudo instructions. These clear/set carry and then do `adc`/`sbc`.

## nako's suggested dev reference

- 65816
    - https://undisbeliever.net/snesdev/65816-opcodes.html
    - https://novasquirrel.github.io/SnesInstructionCycleTool
    - https://cc65.github.io/doc/ca65.html
- Memory map
    - https://snes.nesdev.org/wiki/Memory_map
    - https://novasquirrel.github.io/SnesVRAMPlanner (see `planning/memory-maps`)
- Graphics
    - https://snes.nesdev.org/wiki/Backgrounds
    - https://snes.nesdev.org/wiki/Sprites
- Registers
    - https://snes.nesdev.org/wiki/MMIO_registers
    - https://snes.nesdev.org/wiki/PPU_registers
    - https://snes.nesdev.org/wiki/DMA_registers
