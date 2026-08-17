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

While a picker is open in insert mode:

- `<C-s>` changes the search root.
- `<C-a>` edits `rg` arguments in `live_grep`.

Both pickers accept Telescope picker options:

```lua
require('telescope').extensions.editable.find_files({
  hidden = true,
  no_ignore = true,
})
```
