# Kakoune Config Guide

This repository is a personal Kakoune setup that turns Kakoune into a small IDE-like environment with language-aware workflows, async tool output, and custom editing/navigation commands.

## How It Starts

Primary entrypoint: `kakrc`.

At startup it:
- sets core hooks/options (filetype handling, formatting, cursorline/highlighters, prompt mappings, LSP integration),
- starts `kak-lsp` and enables per-filetype LSP windows,
- sources feature modules from this repo (`fifo.kak`, `cargo.kak`, `git.kak`, `ts.kak`, `odin.kak`, `snippet.kak`, `tasks.kak`, `http.kak`, `vue.kak`, etc.),
- loads bundled plugin code (`kaktree`, `fzf` modules),
- applies colors (`catppuccin_macchiato`) and UI defaults.

## Core Architecture

The config is organized around a few core ideas:

1. **User modes for commands**
   - Many features are exposed through `declare-user-mode` + `map`.
   - Common entrypoint is `map global user ...` (usually entered with `<space>` in Kakoune default conventions).

2. **Async command execution through FIFO**
   - `fifo.kak` defines `run-in-fifo`.
   - Tool commands (cargo, jest, tsc, gcc, odin, godot, grep-like flows) run asynchronously and stream output into dedicated buffers.
   - Past commands are persisted in `.kakoune-fifo.list` and can be rerun.

3. **Multi-client IDE layout**
   - `ide` commands in `kakrc` create/coordinate `main`, `tools`, and `docs` clients.
   - tmux-aware pane management (`zoom`, focus/select pane maps) is built in.
   - Many modules assume `toolsclient` for output and `jumpclient` for file jumps.

4. **Filetype-driven behavior**
   - Extensive hooks map filetypes to LSP servers (`servers.kak`) and formatter behavior.
   - Extra per-filetype UX is layered in (Vue commenting, tasks highlighting, cargo/jest error jumping, etc.).

## Important Modules

- `fifo.kak`
  - Async runner (`run-in-fifo`), command history viewer, rerun last command.
- `servers.kak`
  - `kak-lsp` server config per filetype.
- `cargo.kak`
  - Rust command mode and compiler error parsing/jumping.
- `ts.kak`, `jest.kak`
  - TypeScript/ESLint/Jest runners and jump-to-error behavior.
- `git.kak`
  - Git user mode, hunk/blame/permalink helpers, conflict navigation.
- `grep.kak`
  - Smart grep commands that reuse selection or prompt.
- `http.kak`
  - Parse HTTP request blocks and execute with `curl`, render JSON responses.
- `tasks.kak`
  - `.tasks` filetype with checkbox toggling and line highlighting.
- `snippet.kak`
  - Date/frontmatter/weekly/work-task templates.
- `buffer.kak`
  - Recent buffer tracking and quick switch mechanics.
- `harpoon.kak`
  - File mark system stored in `.meats`.
- `ls.kak`, `kaktree/`, `filetree.kak`
  - File navigation/tree views.
- `tab.kak`
  - Smart tab/indentation behavior and inferred tab width.
- `clipboard.kak`
  - Cross-platform clipboard integration (`kakboard-*`).

## Typical Key Entry Points

These are user-mode mappings that start larger workflows:

- `g` -> git mode
- `r` -> cargo mode
- `J` -> jest mode
- `t` -> TypeScript mode
- `S` -> timesheet mode
- `C` -> C/C++ mode
- `o` -> Odin mode
- `j` -> Jai mode
- `k` -> case conversion mode
- `y` -> yank mode
- `i` -> snippet mode
- `L` -> open `ls` explorer
- `T` -> show kaktree
- `H` -> run HTTP request block
- `R` -> rerun last FIFO command
- `F` -> open FIFO history file

## Runtime/State Files

This repo also stores local workflow data:

- `.kakoune-fifo.list`: history of async commands run through FIFO.
- `.meats`: harpoon-style marks (per git root).
- `.tasks`: task list files used by `tasks.kak`.

## External Dependencies

Expected tools vary by workflow, but commonly include:

- Core: `kak-lsp`, `rg`, `git`, `tmux`, `fzf`, `perl`, `curl`, `jq`
- JS/TS: `node`, `npx`, optionally `pnpm`, `eslint`, `tsc`, `jest`/`oxfmt`/`prettier`
- Rust/C: `cargo`, `gcc`, optional `bear`
- Other languages: `odin`, `jai`, `godot`
- Clipboard/browser helpers: `pbcopy`/`pbpaste` on macOS (or `xclip`/`xsel`/`wl-copy` on Linux)

## How To Extend

When adding a new feature module:

1. Create `<feature>.kak` in repo root (or plugin subdir).
2. Define a user mode and mappings (`declare-user-mode`, `map`).
3. If it runs external tools, prefer `run-in-fifo` for async output.
4. Add filetype hooks/highlighters for buffer-local behavior.
5. Source the file from `kakrc`.

This keeps new features consistent with how the rest of this config is structured.
