# broked key reference

Every key broked understands, by mode. `n·` marks commands that accept a
numeric count prefix (`5j`, `3dd`, `12G`, …).

## NORMAL mode

### Motion

| Key | Action |
|---|---|
| `h` `j` `k` `l`, arrows | n· left / down / up / right |
| `w` | n· start of next word (wraps to next line) |
| `b` | n· start of previous word (wraps) |
| `e` | n· end of word (wraps) |
| `0`, Home | column 0 |
| `^` | first non-blank character |
| `$`, End | end of line |
| `gg` | first line (`5gg` → line 5) |
| `G` | last line (`5G` → line 5) |
| `Ctrl-D` / `Ctrl-U` | half page down / up |
| PgDn / PgUp | full page down / up |

Vertical motion keeps the *desired column* (vim's curswant): `$` then `j j`
hugs each line's end; crossing a short line and coming back restores the
column.

### Operators + motions

`d` (delete), `c` (change: delete then insert), and `y` (yank) combine with a
charwise motion: `w b e $ 0 ^ h l`. Counts apply to the motion (`2dw`). The
range never crosses the starting line; linewise `dj`/`dk` are not supported
(use counts with `dd` or visual mode). As in vim, `cw` on a word behaves like
`ce` — it does not eat the trailing whitespace.

| Key | Action |
|---|---|
| `dw` `de` `db` `d$` `d0` `d^` `dl` `dh` | delete over the motion |
| `cw` `ce` `cb` `c$` … | change over the motion (lands in insert mode) |
| `yw` `ye` `yb` `y$` … | yank over the motion |
| `dd` / `cc` / `yy` | n· delete / change / yank whole line(s) (linewise) |
| `D` / `C` | delete / change to end of line |

### Editing

| Key | Action |
|---|---|
| `x`, Delete | n· delete char under cursor (into register, charwise) |
| `X` | n· delete char before cursor |
| `p` / `P` | paste register after/below // before/above the cursor |
| `r<c>` | replace char under cursor with `<c>` |
| `J` | n· join next line onto this one with a single space |
| `u` | undo (snapshot per command / per insert session) |

### Mode changes

| Key | Action |
|---|---|
| `i` / `I` | insert at cursor / at first non-blank |
| `a` / `A` | insert after cursor / at end of line |
| `o` / `O` | open a new line below / above |
| `v` / `V` | charwise / linewise visual mode |
| `:` | ex command line |
| `/` | search prompt |
| `ZZ` | save and quit |
| `Ctrl-L` | re-read terminal size and redraw |
| `Ctrl-C` | hint: `Type :q<Enter> to quit` |

### Search

| Key | Action |
|---|---|
| `/text` Enter | jump to next occurrence (wraps around the buffer) |
| `/` Enter | repeat last search |
| `n` / `N` | next / previous match |

## VISUAL mode

`v` selects charwise (the cursor char is included), `V` selects whole lines.
The selection is drawn in inverse video; all NORMAL-mode motions (with
counts, including `gg`/`G`) extend it.

| Key | Action |
|---|---|
| motions | extend the selection |
| `o` | swap cursor and anchor |
| `d` / `x` | delete the selection (into the register) |
| `y` | yank the selection; cursor returns to its start |
| `c` / `s` | change: delete the selection and enter insert mode |
| `v` | charwise: exit · linewise: switch to charwise |
| `V` | linewise: exit · charwise: switch to linewise |
| `ESC`, `Ctrl-C` | back to NORMAL mode |

A cross-line charwise selection deletes/yanks *fragments* — `p`/`P` of such a
register splices the fragments back around the cursor, so a visual delete is
exactly restored by `P` at the same spot.

## INSERT mode

| Key | Action |
|---|---|
| printable keys, Tab | insert at cursor (tabs render at 8-col stops) |
| Enter | split the line at the cursor |
| Backspace | delete left; at column 0, join onto the previous line |
| Delete | delete char under cursor |
| arrows, Home, End | move without leaving insert mode |
| `ESC`, `Ctrl-C` | back to NORMAL (cursor steps left, like vim) |

## COMMAND mode (`:`)

| Command | Action |
|---|---|
| `:w` | write the buffer |
| `:w <path>` | write to `<path>` and adopt it as the file name |
| `:q` | quit (refuses if there are unsaved changes) |
| `:q!` | quit, discarding changes |
| `:wq`, `:x` | write and quit |
| `:<line>` | jump to line number |
| `:$` | jump to the last line |

Backspace edits the command; backspacing past empty or `ESC` cancels.

## Not implemented (on purpose, for now)

Redo, text objects (`diw`, `ci(`…), linewise operator+motion (`dj`, `dk`),
registers beyond the single unnamed one, `.` repeat, marks, macros.
