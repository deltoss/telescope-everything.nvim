# telescope-everything.nvim

Search files with [es.exe](https://www.voidtools.com/support/everything/command_line_interface/)
(Everything Command Line Interface) for Windows users. Supports both
[Snacks picker](https://github.com/folke/snacks.nvim) and
[Telescope](https://github.com/nvim-telescope/telescope.nvim).

## Requirement

Install [Everything](https://www.voidtools.com/), and put
[Everything Command Line Interface](https://www.voidtools.com/support/everything/command_line_interface/)
in PATH (or set `es_path` to the full path of `es.exe`).

---

## Snacks picker (recommended)

### Installation

[lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "deltoss/telescope-everything.nvim",
  dependencies = { "folke/snacks.nvim" },
}
```

### Setup

```lua
require("snacks-everything").setup({
  -- optional — shown with defaults
  es_path = "es",
  case_sensitive = false,
  whole_word = false,
  match_path = false,
  sort = false,
  regex = true,
  offset = 0,
  max_results = 100,
})
```

`setup()` also registers `Snacks.picker.everything` as a named source so you
can call it alongside the built-in Snacks pickers.

### Usage

```lua
-- Direct call (works without setup)
require("snacks-everything").pick()

-- Via the registered Snacks source (requires setup to have been called)
Snacks.picker.everything()

-- Keymap example
vim.keymap.set("n", "<leader>se", require("snacks-everything").pick, { desc = "Everything search" })
```

### Per-call overrides

Any config key can be overridden at call time:

```lua
require("snacks-everything").pick({ regex = false, max_results = 500 })
```

---

## Telescope (legacy)

### Installation

[lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "deltoss/telescope-everything.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
}
```

[vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'deltoss/telescope-everything.nvim'
```

### Setup

```lua
require("telescope").load_extension("everything")
```

### Usage

```vim
:Telescope everything
```

### Config

```lua
require("telescope").setup({
  extensions = {
    everything = {
      es_path = "es",
      case_sensitive = false,
      whole_word = false,
      match_path = false,
      sort = false,
      regex = true,
      offset = 0,
      max_results = 100,
    },
  },
})
```

---

## Config reference

| Option | Default | Description |
|---|---|---|
| `es_path` | `"es"` | Path to `es.exe`; only needed if not in `PATH` |
| `case_sensitive` | `false` | Case-sensitive matching |
| `whole_word` | `false` | Whole-word matching |
| `match_path` | `false` | Match against the full path, not just the filename |
| `sort` | `false` | Sort results alphabetically |
| `regex` | `true` | Treat the query as a regex |
| `offset` | `0` | Skip the first N results |
| `max_results` | `100` | Maximum number of results returned |

See the [Everything CLI docs](https://www.voidtools.com/support/everything/command_line_interface/)
for more detail on each flag.
