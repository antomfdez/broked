# broked

**broked** — *broken editor* — is a terminal code editor with vim keybindings,
written entirely in [brokm](https://github.com/antomfdez/brokm). Modal editing
(normal, insert, visual, command), operator+motion combos (`dw`, `cw`, `d$`…),
counts, registers, undo, search, an ex command line, line numbers, and syntax
highlighting for `.bk` files.

```sh
brokm broked.bk file.bk            # run from source (needs BROKM_HOME)
brokm build broked.bk -o broked    # AOT-compile to a standalone binary
./broked file.bk
```

## Requirements

- [brokm](https://github.com/antomfdez/brokm) installed (`sh install.sh`), with
  `BROKM_HOME` set so the `std/*.bk` includes resolve.
- A POSIX terminal with `stty` and `dd` (macOS / Linux). brokm has no native
  raw-tty API, so broked drives the terminal through them (see *How it works*).

Docs: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — how it works inside ·
[docs/KEYMAP.md](docs/KEYMAP.md) — full key reference.

## Keybindings

### Normal mode

| Keys | Action |
|---|---|
| `h j k l`, arrows | move (with counts: `5j`) |
| `w` / `b` / `e` | next word / back word / end of word |
| `0` / `^` / `$` | line start / first non-blank / line end |
| `gg` / `G` / `5G` | first line / last line / line 5 |
| `Ctrl-D` / `Ctrl-U` | half page down / up (PgUp/PgDn too) |
| `i I a A o O` | enter insert mode (at, bol, after, eol, below, above) |
| `x` / `X` | delete char under / before cursor |
| `d` `c` `y` + motion | operate over `w b e $ 0 ^ h l` (e.g. `dw`, `cw`, `d$`, `2dw`) |
| `dd` / `cc` / `yy` | delete / change / yank line(s) |
| `D` / `C` | delete / change to end of line |
| `v` / `V` | charwise / linewise visual mode (`d x y c`, `o` swaps ends) |
| `p` / `P` | paste after / before |
| `r<c>` | replace char |
| `J` | join with next line |
| `u` | undo |
| `/text` then `n` / `N` | search forward, repeat / reverse |
| `:` | ex command line |
| `ZZ` | save and quit |
| `Ctrl-L` | re-read terminal size and redraw |

### Ex commands

`:w`, `:w <path>`, `:q`, `:q!`, `:wq`, `:x`, `:<line>`, `:$`

### Insert mode

Printable keys, Tab, Enter, Backspace (joins at column 0), Delete, arrows,
Home/End. `ESC` (or `Ctrl-C`) returns to normal mode.

## Tests

A headless suite drives the key dispatcher with no terminal attached:

```sh
BROKM_HOME=path/to/brokm brokm tests/test.bk    # 159 passed, 0 failed
```

## How it works

brokm has no raw-terminal natives, so the terminal layer (`term.bk`) is built
from the scripting stdlib:

- **Raw mode**: `Shell("stty raw -echo < /dev/tty")`.
- **Key input**: one byte at a time with `ShellStr("dd if=/dev/tty bs=1 count=1")`.
  After an `ESC`, a `stty min 0 time 1` + `dd bs=8` read distinguishes a bare
  Escape from arrow/Home/End/PgUp/PgDn sequences by timeout.
- **Frame flushing**: brokm's `ShellStr` flushes stdout before launching its
  child, so each rendered frame (built as one string, printed once) reaches the
  screen exactly when the editor blocks for the next key.
- **Rendering**: ANSI escapes — home + per-line clear (`ESC[K`), an inverted
  status bar, a dim line-number gutter, absolute cursor parking. Tabs expand at
  8-column stops with kilo-style cx→rx mapping.
- **Buffers**: an array of immutable line strings. brokm arrays grow but never
  shrink, so structural edits build new arrays; undo snapshots are shallow
  copies (cheap, since strings are immutable).

## Files

| File | Role |
|---|---|
| `broked.bk` | entry point and main loop |
| `term.bk` | raw mode, key decoding, ANSI helpers |
| `buffer.bk` | line-array text buffer, load/save |
| `editor.bk` | `Ed` state, clamping, scrolling, undo, motions, search |
| `normal.bk` | NORMAL mode: operators (d/c/y + motion), counts, registers |
| `visual.bk` | VISUAL mode: charwise/linewise selections |
| `insert.bk` | INSERT mode |
| `exline.bk` | `:` commands and `/` search prompt |
| `render.bk` | frame drawing |
| `hl.bk` | `.bk` syntax highlighting |
| `dispatch.bk` | mode → handler routing (shared with tests) |
| `tests/test.bk` | headless test suite |

## Known limitations

- One process spawn per keypress (the `dd` read) — fine interactively, but
  don't pipe a novel into it.
- No redo, no text objects (`diw`, `ci(`…), no marks, macros, or `.` repeat.
  Charwise operators (`dw` etc.) stay on the current line; `dj`-style linewise
  combos are not supported (use `2dd` or visual mode).
- Highlighting is per-line and stateless: multi-line `/* */` comments are not
  colored, and a token clipped by horizontal scroll loses its color.
- If brokm itself crashes mid-session the terminal stays raw — run `stty sane`.
