# telescope-everything.nvim

Fast file search in Neovim powered by a pre-indexed database.
Supports [Everything](https://www.voidtools.com/) (Windows) and
[plocate](https://plocate.sesse.net/) (Linux) via
[Snacks picker](https://github.com/folke/snacks.nvim),
with a legacy [Telescope](https://github.com/nvim-telescope/telescope.nvim)
backend kept for backwards compatibility.

## Requirement

One of:

- **Windows** — install [Everything](https://www.voidtools.com/) and add
  [es.exe](https://www.voidtools.com/support/everything/command_line_interface/)
  to `PATH` (or set `backends.everything.cmd`).
- **Linux** — install `plocate` via your package manager
  (`sudo apt install plocate` / `sudo pacman -S plocate` / …).
  Run `sudo updatedb` (or `sudo plocate --updatedb`) to build the initial index.

---

## Snacks picker (recommended)

### Installation

```lua
-- lazy.nvim
{
  "deltoss/telescope-everything.nvim",
  dependencies = { "folke/snacks.nvim" },
}
```

### Setup

```lua
require("snacks-everything").setup({
  -- "auto" tries each backend in order (everything → plocate)
  backend = "auto", -- "auto" | "everything" | "plocate"

  -- Shared flags (translated for each backend automatically)
  case_sensitive = false,
  whole_word    = false,
  match_path    = false, -- false = basename only, true = full path
  regex         = true,
  max_results   = 100,

  -- Backend-specific options
  backends = {
    everything = {
      cmd    = "es",  -- path to es.exe if not in PATH
      sort   = false, -- sort results alphabetically
      offset = 0,     -- skip the first N results
    },
    plocate = {
      cmd      = "plocate",       -- path to plocate if not in PATH
      database = nil,             -- custom database path (-d); nil = system default
    },
  },
})
```

`setup()` also registers `Snacks.picker.everything` as a named source so you
can call it alongside built-in Snacks pickers.

### Usage

```lua
-- Direct call (works without calling setup first)
require("snacks-everything").pick()

-- Via the registered Snacks source (requires setup to have been called)
Snacks.picker.everything()

-- Keymap
vim.keymap.set("n", "<leader>se", require("snacks-everything").pick, { desc = "File search" })
```

### Per-call overrides

Any config key can be overridden at call time:

```lua
-- Force plocate, ignore case, search full paths
require("snacks-everything").pick({
  backend        = "plocate",
  case_sensitive = true,
  match_path     = true,
})
```

---

## Telescope (legacy)

### Installation

```lua
-- lazy.nvim
{
  "deltoss/telescope-everything.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
}
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
      es_path       = "es",
      case_sensitive = false,
      whole_word    = false,
      match_path    = false,
      sort          = false,
      regex         = true,
      offset        = 0,
      max_results   = 100,
    },
  },
})
```

---

## Config reference (Snacks backend)

### Shared options

| Option | Default | Description |
|---|---|---|
| `backend` | `"auto"` | Which backend to use. `"auto"` picks the first available. |
| `case_sensitive` | `false` | Case-sensitive matching |
| `whole_word` | `false` | Whole-word matching |
| `match_path` | `false` | `false` = match filename/basename only; `true` = match full path |
| `regex` | `true` | Treat the query as a regular expression |
| `max_results` | `100` | Maximum number of results returned |

### `backends.everything`

| Option | Default | Description |
|---|---|---|
| `cmd` | `"es"` | Path to `es.exe`; only needed if not in `PATH` |
| `sort` | `false` | Sort results alphabetically |
| `offset` | `0` | Skip the first N results |

### `backends.plocate`

| Option | Default | Description |
|---|---|---|
| `cmd` | `"plocate"` | Path to `plocate`; only needed if not in `PATH` |
| `database` | `nil` | Custom database path (`-d`). `nil` uses the system default. |

### Multi-term queries

Both backends treat space-separated terms as **AND** (all must match):

- Everything does this natively.
- plocate is given the `-A` flag automatically when more than one term is present.

Quoted phrases are kept together:

```
"my project" .lua   →  finds paths matching both "my project" AND ".lua"
```
