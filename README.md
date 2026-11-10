# editable-telescope.nvim

A small [Telescope](https://github.com/nvim-telescope/telescope.nvim) extension
whose file and grep pickers let you change the search root without losing the
current prompt. The grep picker also lets you edit `rg` arguments while it is
open.

## Requirements

- Neovim
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [ripgrep](https://github.com/BurntSushi/ripgrep) for `live_grep`

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
            edit_grep_args = '<C-a>',
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
```

Or call the exported pickers from Lua:

```lua
require('telescope').extensions.editable.find_files()
require('telescope').extensions.editable.live_grep()
```

While a picker is open in insert or normal mode:

- `<C-s>` changes the search root.
- `<C-a>` edits `rg` arguments in `live_grep`.

The keys can be changed under `extensions.editable.mappings` in Telescope's
setup, as shown in the installation example.

Set `extensions.editable.remember_query = true` to restore the last query for
`find_files` and `live_grep` separately, including after selection or cancellation.
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

## Shared picker API

Other extensions can call `telescope.extensions.editable.editable_picker(opts)`.
Supply `picker_opts`, `prompt_title(state)`, and `open(state, picker_opts)` to
create a picker. Optional `initial_state` supplies `cwd` and `cmd_args`;
`mappings` overrides `change_root` and `edit_grep_args` for this picker only.
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
