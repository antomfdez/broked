# broked architecture

How a vim-style editor works when the implementation language has no
raw-terminal API, no first-class functions, and arrays that never shrink.

## Module map

```
broked.bk            entry point: load file, raw mode, main loop
  ├── dispatch.bk    mode -> handler routing (shared with the tests)
  │     ├── editor.bk   Ed state class + shared helpers (motions, undo, search)
  │     ├── normal.bk   NORMAL mode: operators (d/c/y + motion), counts, registers
  │     ├── visual.bk   VISUAL mode: charwise/linewise selections
  │     ├── insert.bk   INSERT mode
  │     └── exline.bk   ":" ex commands and "/" search prompt
  └── render.bk      frame drawing
        ├── term.bk     raw mode, key decoding, ANSI helpers
        └── hl.bk       .bk syntax highlighting
buffer.bk            line-array text buffer, load/save (used by editor.bk)
tests/test.bk        headless suite driving EdKey/EdFeed
```

brokm `#include` is textual, include-once, one flat namespace — so every
public name is prefixed (`Ed*`, `Term*`, `Buf*`, `Lines*`, `Render*`, `Hl*`)
and the include graph is a DAG with `editor.bk` at the center.

## The main loop

```c
while (!e.quit) {
  EdScroll(e);              // rowoff/coloff follow the cursor
  EdDraw(e);                // build one frame string, Print() it
  I64 k = TermReadKey();    // blocks; flushes the frame first (see below)
  EdKey(e, k);              // route to the active mode's handler
}
```

## Terminal I/O without terminal natives

brokm's scripting natives are `Shell` (exit status) and `ShellStr` (captured
stdout). `term.bk` builds everything from those:

- **Raw mode**: `Shell("stty raw -echo < /dev/tty")`; `stty sane` on exit.
- **One key**: `ShellStr("dd if=/dev/tty bs=1 count=1 2>/dev/null")` — one
  byte per keypress, one process per keypress. Slow in principle, invisible
  interactively.
- **ESC disambiguation**: a lone `ESC` byte and the first byte of an arrow
  key sequence are identical. After reading `ESC`, broked switches the tty to
  `min 0 time 1` (return whatever arrives within 0.1 s), reads up to 8 bytes,
  restores `min 1 time 0`, and maps `[A`/`[B`/`[3~`/… to key constants
  (`K_UP`, `K_DEL`, …). An empty follow-up read means the user pressed Escape.
- **Frame flushing** — the load-bearing detail: brokm's `Print` does *not*
  flush stdout, but `ShellStr` calls `fflush(stdout)` before `popen` (to keep
  parent/child output ordered). So the frame printed by `EdDraw` reaches the
  screen exactly when `TermReadKey` blocks for input. No flush native needed.

Keys are plain `I64`s: printable ASCII as-is, control codes (13, 27, 127, …)
as-is, decoded sequences as constants ≥ 1000. That makes the whole editor
drivable from tests as `EdFeed(e, "gg2ddp")`.

## Buffer and editing model

The buffer is `U0[] lines` — an array of brokm strings. Two language facts
shape every edit:

- **Strings are immutable** (and interned): editing a line means building a
  new string — `Substr(left) + insert + Substr(right)` — and assigning it
  back to `lines[cy]`.
- **Arrays grow but never shrink** (`Append` only): deleting a line means
  building a new array (`LinesRemoveAt`) and reassigning `e.lines`. O(n) per
  structural edit, irrelevant at editor scale.

`buffer.bk` keeps these as four primitives (`LineInsertStr`,
`LineRemoveRange`, `LinesInsertAt`, `LinesRemoveAt`) plus `BufLoad`/`BufSave`
(CRLF-tolerant, trailing-newline round-trip safe).

## Editor state

One `Ed` class instance holds everything: buffer, cursor (`cx`/`cy` in
character space), `wantx` (vim's curswant, so `j` through a short line
remembers the column), scroll offsets, mode, pending operator, count,
yank register (+ linewise flag), undo stack, search pattern, status message.

State machines instead of callbacks (brokm has no first-class functions):

- **Counts**: digits accumulate in `e.count`; every handler reads
  `rep = max(1, count)` and clears it.
- **Operators** (`d`/`c`/`y`): the first key sets `e.pending`; the second is
  either the doubled form (`dd`/`cc`/`yy`, linewise) or a charwise motion
  resolved by `EdOpMotion` — it runs the real motion code against the live
  cursor, captures the endpoint, restores the cursor, and applies the
  operator to the resulting range. Motions briefly run with insert-mode
  clamping so a range can reach one past EOL (`dw` on the last word). The
  same pending machinery handles `gg`, `r<c>`, and `ZZ`.
- **Visual mode** keeps an anchor (`vx`/`vy`, plus a linewise flag); the
  cursor moves with the shared `EdMotionKey` (also used by NORMAL mode), and
  operators act on the normalized anchor..cursor range. A cross-line
  charwise selection yanks *fragments* — first-line tail, whole middle
  lines, last-line head — which paste splices back around the cursor.
- **The command line** is just a mode: `:`/`/` switch to `M_CMD`, printable
  keys append to `e.cmd`, Enter executes, ESC cancels. The renderer shows
  `e.cmd` in the message line and parks the cursor there.

## Undo

Snapshot-based: every mutating command (and each insert-mode *session*)
pushes `[ArrCopy(lines), cx, cy]`. Shallow copy is correct *because* strings
are immutable — only the array spine is duplicated. `u` pops and restores a
copy (so re-editing never aliases a stored snapshot). The stack array never
shrinks (it can't); `undolen` tracks the live top and slots are overwritten
in place.

## Rendering

Full redraw per keypress, kilo-style, flicker-free without clearing:

1. hide cursor, cursor home
2. per text row: dim line-number gutter, the visible slice of the line
   (tabs expanded at 8-column stops), optional highlighting, `ESC[K`
3. inverted status bar (mode, file, `[+]`, position), message line
4. park the cursor with absolute `ESC[row;colH`, show cursor

The cursor column uses a cx→rx map (`EdRxOf`) so tabs render correctly.
Highlight escapes are zero-width and injected *after* horizontal clipping,
so they never disturb geometry. The frame is one string, printed once.
In visual mode, rows intersecting the selection get inverse video over the
selected rx range instead of syntax colors (mixing both would shift the
byte offsets the selection math relies on).

`hl.bk` is a stateless per-line scanner: `//` comments, string/char literals
(escape-aware), numbers, keyword/type lookup via brokm maps. Stateless means
multi-line `/* */` isn't colored — a deliberate trade for simplicity.

## Testing

`tests/test.bk` includes `dispatch.bk` + `render.bk` but never calls
`TermReadKey`/`EdDraw`, so it runs with no terminal at a fixed 24×80. Tests
feed key strings through `EdFeed` and assert buffer/cursor/mode/register
state, plus pure-function checks for buffer primitives, rx mapping, status
bar, selection rendering, and highlighting. 159 assertions; non-zero exit on
failure. The suite is grouped into a handful of large test functions rather
than one per feature — see the constant-pool constraint below.

Two things are only verifiable live and are smoke-tested through a pty
(`script(1)` + delayed keystrokes): the stty/dd input path and frame
flushing.

## brokm constraints that shaped the code

| Constraint | Consequence |
|---|---|
| no raw-tty natives | `stty`/`dd` terminal layer |
| `Print` doesn't flush | rely on `ShellStr`'s pre-`popen` flush |
| no first-class functions | if-chain dispatch + `pending` state machine |
| arrays never shrink | rebuild-on-delete, `undolen` top-of-stack index |
| immutable interned strings | splice-by-Substr edits, cheap undo snapshots |
| one flat namespace | `Ed*`/`Term*`/`Buf*` prefixes, DAG includes |
| methods can't span files | `Ed` is data-only; behavior is free functions |
| no `\e` escape in strings | `Chr(27)` everywhere ANSI is built |
| constant-pool limits | the *top-level* chunk holds one constant per declared function (plus global names and literals); broked once hit brokm's one-byte 256-constant ceiling, which is why trivial single-caller helpers are inlined and the test suite uses a few large functions instead of one per feature. brokm has since gained wide (16-bit) constant opcodes, so the real ceiling is now 65536 |
