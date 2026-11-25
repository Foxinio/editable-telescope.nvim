# editable-telescope.nvim

A small [Telescope](https://github.com/nvim-telescope/telescope.nvim) extension
whose file, grep and [ast-grep](https://ast-grep.github.io) pickers let you
change the search root without losing the current prompt. The grep and ast-grep
pickers also let you edit their command-line flags while they are open.

## Requirements

- Neovim
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [ripgrep](https://github.com/BurntSushi/ripgrep) for `live_grep`
- [ast-grep](https://ast-grep.github.io) (the `ast-grep` executable) for `ast_grep`

## Installation

With lazy.nvim:

```lua
{
  'foxinio/editable-telescope.nvim',
  dependencies = {
    'nvim-telescope/telescope.nvim',
  },
  config = function()
    require('telescope').setup({
      extensions = {
        editable = {
          remember_query = false,
          mappings = {
            change_root = '<C-s>',
            edit_args = '<C-a>',
            presets = '<C-b>',
          },
        },
      },
    })
    require('telescope').load_extension('editable')
  end,
}
```

## Usage

```vim
:Telescope editable find_files
:Telescope editable live_grep
:Telescope editable ast_grep
```

Or call the exported pickers from Lua:

```lua
require('telescope').extensions.editable.find_files()
require('telescope').extensions.editable.live_grep()
require('telescope').extensions.editable.ast_grep()
```

While a picker is open in insert or normal mode:

- `<C-s>` changes the search root.
- `<C-a>` edits `rg` arguments in `live_grep` and `ast-grep` arguments in
  `ast_grep`.
- `<C-b>` opens a small window with [presets](#presets) (saved searches, think
  *b*ookmarks) for the picker.

The keys can be changed under `extensions.editable.mappings` in Telescope's
setup, as shown in the installation example.

Set `extensions.editable.remember_query = true` to restore the last query for
`find_files`, `live_grep` and `ast_grep` separately, including after selection or cancellation.
Normal and all-files variants share their picker's query; clearing the prompt
remembers an empty query. An explicit `default_text` (including `""`) takes
precedence. Only queries are remembered during the current Neovim session:
roots and flags are not saved, and nothing persists across restarts.

Both pickers accept Telescope picker options:

```lua
require('telescope').extensions.editable.find_files({
  hidden = true,
  no_ignore = true,
})
```

## ast-grep

`ast_grep` runs `ast-grep run --pattern=<prompt>` on every prompt change, so the
prompt is a structural pattern such as `foo($A)` or `if err != nil { $$$ }`.
Results look like `live_grep` results (same path display, quickfix and grep
previewer), but the preview highlights the whole matched node, including
multi-line matches. Each entry also carries the decoded ast-grep result as
`entry.match` (meta variables, language, byte offsets) for custom actions.

Besides the usual Telescope picker options it accepts:

| Option            | Meaning                                                                                  |
| ----------------- | ---------------------------------------------------------------------------------------- |
| `lang`            | Pattern language passed as `--lang`. `true` uses the filetype of the buffer you opened the picker from. Without it ast-grep infers the language from each file's extension. |
| `command`         | Executable, `ast-grep` by default (`sg` is `newgrp` on many Linux systems).            |
| `hidden`          | Adds `--no-ignore hidden`.                                                               |
| `no_ignore`       | Adds `--no-ignore` for `dot`, `exclude`, `global`, `parent` and `vcs`, like `rg --no-ignore`. |
| `globs`           | List of `--globs` values.                                                                |
| `search_dirs`     | Paths to search, relative to the root.                                                   |
| `additional_args` | Extra flags (table or `function(opts)`), placed before the edited ones.                  |

```lua
vim.keymap.set('n', '<leader>sa', function()
  require('telescope').extensions.editable.ast_grep({ lang = true })
end, { desc = '[S]earch [A]ST in current language' })
```

Edited flags (`<C-a>`) are appended last, so `--strictness relaxed`,
`--globs '!tests/**'` or `--selector call_expression` work as expected. A language
given there (`-l rust`, `--lang=rust`) replaces the `lang` option.

The command building and JSON parsing live in `require('editable-telescope.ast_grep')`
(`build`, `with_pattern`, `parse`, `entry_maker`, `resolve_lang`) for use in
your own pickers.

## Presets

`<C-b>` opens a small dropdown listing presets for the current picker. Choosing
one reopens the picker with it applied, keeping the prompt and root; `Default`
removes it and cancelling (`<Esc>`, `<C-c>`, `q`) returns to the picker
unchanged. The active preset is marked `●` and shown in the title as `{name}`.
A preset replaces the edited flags, so `<C-a>` afterwards edits the preset's flags.

The key is `<C-b>` as in *bookmarks*: presets are saved searches you jump
to. Neither Telescope nor Neovim's insert mode uses `CTRL-B`, so it overrides
nothing in the prompt.

### Built-in presets

Built-in presets are organised in groups, which `default_presets` enables or
disables per picker. Typing a group name in the window also filters by it.

| Picker       | Group        | Presets                                                                 |
| ------------ | ------------ | ----------------------------------------------------------------------- |
| `find_files` | `scope`      | all files (hidden and ignored), hidden files, ignored files             |
| `live_grep`  | `modes`      | literal, whole word, case sensitive, multiline                          |
| `live_grep`  | `scope`      | all files, same extension as the current file, exclude tests            |
| `live_grep`  | `types`      | Lua, C/C++, Python, Rust, JS/TS, Go, Java, shell, build, config, docs  |
| `ast_grep`   | `general`    | text in comments, TODO comments, text in strings, function definitions, type definitions, function calls, imports, loops, error handling |
| `ast_grep`   | `match`      | relaxed, structure only, exact (`--strictness`), all languages, all files, exclude tests |
| `ast_grep`   | `lua`        | require, setup calls, keymaps, autocommands, user commands, `vim.cmd`, notifications, scheduled callbacks, pcall, pairs/ipairs loops, methods, module tables, `vim.loop`, anonymous functions |
| `ast_grep`   | `python`     | import, from import, print, `== None`, `!= None`, isinstance, self attributes, list comprehensions, lambdas, open, raise, assert, eval/exec, subprocess, decorators, with blocks, bare except |
| `ast_grep`   | `rust`       | unwrap, expect, `?`, panics, debug output, unsafe, clone, trait impls, all impls, match, `Box::new`, Rc/Arc, `.await`, casts, derives, closures |
| `ast_grep`   | `c`          | includes, macros, allocations, unsafe string functions, printf family, NULL checks, goto, sizeof, switch, static functions, casts (C and C++ buffers) |
| `ast_grep`   | `cpp`        | new, delete, smart pointers, `std::move`, C++ casts, lambdas, range for, auto declarations, `using namespace`, templates, `std::cout`, classes |
| `ast_grep`   | `go`         | error checks, error assignments, goroutines, defer, panic, fmt output, make, channel sends/receives, select, type assertions, context roots, closures |
| `ast_grep`   | `javascript` | console, await, import from, require, exports, arrow functions, promise then, fetch, JSON, timers, event listeners, loose equality, React hooks, template literals, debugger (JS and TS buffers) |
| `ast_grep`   | `typescript` | `as any`, any annotations, non-null assertions, ts-ignore, interfaces, type aliases, enums, satisfies, decorators |
| `ast_grep`   | `java`       | System.out, printStackTrace, new, throw, catch blocks, equals, annotations, Optional, streams, lambdas, synchronized |
| `ast_grep`   | `bash`       | eval, rm, sudo, downloads, source, echo/printf, command substitution, tests, pipelines, heredocs, exports, assignments |

How the ast-grep presets work:

- `general` searches use the buffer's language. The prompt is a regex matched
  against the comment, string, import, loop or try-block text, or against the
  name for definitions and calls. An empty prompt lists every match, for example
  every comment in the project. They support Lua, Python, Rust, C, C++, Go, JS,
  TS/TSX, Java and Bash (`require('editable-telescope.ast_grep').languages`;
  imports, loops and error handling only where the language has them).
- Language presets put a pattern (or a regex, for the ones built on rules) in
  the prompt, ready to edit. Only the groups for the buffer's filetype are
  listed, or all enabled groups in a buffer without one; they search in the
  buffer's language, or the group's language when there is no filetype.
- `tests/fixtures/ast_grep` holds a sample file per language, and the tests
  check that every built-in preset finds something in it.

### Configuration

```lua
editable = {
  default_presets = {
    -- Only these ast-grep groups: general searches, match modes, Lua and C/C++.
    ast_grep = { 'general', 'match', 'lua', 'c', 'cpp' },
    -- Or drop some: ast_grep = { java = false, bash = false },
    live_grep = { types = false },
    find_files = true, -- all groups (the default); false for none
  },
  -- default_presets = false turns off every built-in preset.
  presets = {
    live_grep = {
      { name = 'Verilog', cmd_args = { '--glob', '*.{v,sv,svh}' } },
      { name = 'TODOs', prompt = 'TODO|FIXME', cmd_args = '--glob !vendor/**' },
      { name = 'Literal', disabled = true }, -- hide a built-in preset
    },
    ast_grep = {
      {
        name = 'Lua: Telescope extensions',
        ft = 'lua',
        prompt = "require('telescope').load_extension($NAME)",
        opts = { lang = 'lua' },
      },
      {
        name = 'Lua: callbacks',
        desc = 'functions passed as arguments',
        ft = 'lua',
        opts = {
          lang = 'lua',
          rule = function() return { kind = 'function_definition', inside = { kind = 'arguments' } } end,
        },
      },
    },
  },
  -- Options for the preset window; theme is 'dropdown' (default), 'ivy', 'cursor' or false.
  presets_picker = { theme = 'dropdown', winblend = 10 },
}
```

Group settings apply to built-in presets only; your own presets are always
listed (subject to `ft` and `disabled`).
`require('editable-telescope.presets').language_groups()` returns the ast-grep
language group names.

Preset fields:

| Field      | Meaning                                                                        |
| ---------- | ------------------------------------------------------------------------------ |
| `name`     | Shown in the window and title; a preset with a built-in name replaces it.      |
| `desc`     | Optional description.                                                          |
| `ft`       | Filetype or list; list the preset only in buffers of those filetypes.          |
| `cmd_args` | Flags as a list, a string (parsed like `<C-a>` input) or `function(ctx)` (`ctx.bufnr`, `ctx.filetype`, `ctx.filename`). |
| `opts`     | Picker options, e.g. `hidden`, `no_ignore`, `lang`, `globs`, `rule`.           |
| `prompt`   | Replaces the prompt.                                                           |
| `cwd`      | Search root.                                                                   |
| `group`    | Optional label; typing it in the window filters by it.                         |
| `disabled` | Hide the preset.                                                               |

A single call can add presets too: `ast_grep({ presets = { ... } })`.

`ast_grep` also accepts `rule = function(prompt, lang)` directly. It returns an
[ast-grep rule](https://ast-grep.github.io/reference/rule.html) as a Lua table
(or nil when the language is not supported) and switches the picker to
`ast-grep scan --inline-rules`. The language is `lang` or a `-l` in the edited
flags. The rules behind the general presets are
`require('editable-telescope.ast_grep').rules` (`comments`, `strings`,
`functions`, `types`, `calls`, `imports`, `loops`, `errors`), and
`rules.kind('kind', ...)` matches given node kinds, filtered by the prompt.
`lang = true` with `fallback_lang = 'lua'` uses the buffer's language, or Lua
in a buffer without a filetype.

## Shared picker API

Other extensions can call `telescope.extensions.editable.editable_picker(opts)`.
Supply `picker_opts`, `prompt_title(state)`, and `open(state, picker_opts)` to
create a picker. Optional `initial_state` supplies `cwd` and `cmd_args`;
`mappings` overrides `change_root`, `edit_args` and `presets` for this picker only
(`edit_grep_args` is still accepted as an alias). `presets` (a list, or
`function(ctx)` returning one) enables the preset window; a preset's `opts` are
merged into `picker_opts` before `open` is called, and `state.preset` holds its
name. After a preset is applied `state.cmd_args_text` is nil, so
`format_cmd_args` should fall back to `args`.
The wrapper preserves the prompt when editing settings and invokes `open` again.
Pass the supplied `picker_opts.attach_mappings` through to the picker so the
editing controls remain installed.

To enable argument editing, supply `parse_cmd_args(text)`, optionally returning
`nil, error` to reject input. The state retains the last accepted `cmd_args`,
the entered `cmd_args_text`, and `cmd_args_error` (cleared after valid input).
Consumers decide how to display errors. `format_cmd_args(args, state)` can use
the raw text as the next input default; without it, arguments are space-joined
as before. `cmd_args_prompt` customizes the input label.

`require('editable-telescope.args').split(text, true)` opts into strict parsing,
returning `nil, error` for unfinished quotes or escapes. Without the second
argument, parsing retains its permissive behavior. `args.format(tokens)` quotes
tokens for a lossless round trip through `split`; neither function runs a shell.
`args.normalize_root(path)` returns an absolute directory path without a trailing
slash (expanding `~`), or `nil, error` when it is not a directory. `args.build(opts,
edited, base)` appends `--hidden`/`--no-ignore`, `additional_args` and the edited
arguments to `opts.vimgrep_arguments` or `base`.

## Tests

`make test` runs the headless tests with Telescope and Plenary from lazy.nvim's
plugin directory, or from `DEPS_DIR` (`make deps test DEPS_DIR=.deps` clones
them, as CI does). The `ast_grep` picker tests run only when `ast-grep` is on
`PATH` (`npm install -g @ast-grep/cli`); the parsing tests always run.
