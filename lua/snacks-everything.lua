local M = {}

-- ─── config ────────────────────────────────────────────────────────────────

---@class snacks_everything.Config
local defaults = {
  -- "auto" tries each backend in order until one is executable
  backend = "auto", -- "auto" | "everything" | "plocate"

  -- Shared flags (translated per-backend)
  case_sensitive = false,
  whole_word = false,
  -- false = match filename/basename only; true = match full path
  match_path = false,
  regex = true,
  max_results = 100,

  -- Per-backend options
  backends = {
    everything = {
      cmd = "es",
      sort = false, -- sort results alphabetically
      offset = 0,   -- skip first N results
    },
    plocate = {
      cmd = "plocate",
      database = nil, -- custom database path (-d); nil = system default
    },
  },
}

M.config = vim.deepcopy(defaults)

-- ─── backend definitions ───────────────────────────────────────────────────

local BACKENDS_ORDER = { "everything", "plocate" }

local backends = {}

backends.everything = {
  available = function(opts)
    return vim.fn.executable(opts.backends.everything.cmd) == 1
  end,

  cmd = function(opts)
    return opts.backends.everything.cmd
  end,

  ---@param opts snacks_everything.Config
  ---@param query_parts string[]
  build_args = function(opts, query_parts)
    local b = opts.backends.everything
    local args = {}
    if opts.case_sensitive then
      args[#args + 1] = "-case"
    end
    if opts.whole_word then
      args[#args + 1] = "-whole-word"
    end
    if opts.match_path then
      args[#args + 1] = "-match-path"
    end
    if b.sort then
      args[#args + 1] = "-s"
    end
    -- 0 is truthy in Lua, so guard explicitly to avoid -offset 0 at default
    if b.offset and b.offset > 0 then
      args[#args + 1] = "-offset"
      args[#args + 1] = tostring(b.offset)
    end
    if opts.max_results then
      args[#args + 1] = "-max-results"
      args[#args + 1] = tostring(opts.max_results)
    end
    -- -regex must come after all other flags
    if opts.regex then
      args[#args + 1] = "-regex"
    end
    vim.list_extend(args, query_parts)
    return args
  end,
}

backends.plocate = {
  available = function(opts)
    return vim.fn.executable(opts.backends.plocate.cmd) == 1
  end,

  cmd = function(opts)
    return opts.backends.plocate.cmd
  end,

  ---@param opts snacks_everything.Config
  ---@param query_parts string[]
  build_args = function(opts, query_parts)
    local b = opts.backends.plocate
    local args = {}
    -- plocate is case-sensitive by default; add -i for case-insensitive
    if not opts.case_sensitive then
      args[#args + 1] = "-i"
    end
    if opts.whole_word then
      args[#args + 1] = "-w"
    end
    -- plocate ANDs multiple patterns only with -A; mirrors Everything behaviour
    if #query_parts > 1 then
      args[#args + 1] = "-A"
    end
    if opts.max_results then
      args[#args + 1] = "-l"
      args[#args + 1] = tostring(opts.max_results)
    end
    if b.database then
      args[#args + 1] = "-d"
      args[#args + 1] = b.database
    end
    -- plocate matches full path by default; -b restricts to basename
    if not opts.match_path then
      args[#args + 1] = "-b"
    end
    -- --regex = ERE; omit for plain substring/glob matching
    if opts.regex then
      args[#args + 1] = "--regex"
    end
    vim.list_extend(args, query_parts)
    return args
  end,
}

-- ─── helpers ───────────────────────────────────────────────────────────────

local function split_search(search)
  local args = {}
  local remaining = search
  for quoted in search:gmatch('"[^"]*"') do
    table.insert(args, quoted:sub(2, -2))
    remaining = remaining:gsub('"[^"]*"', "", 1)
  end
  for word in remaining:gmatch("%S+") do
    table.insert(args, word)
  end
  return args
end

local function resolve_backend(opts)
  local name = opts.backend or "auto"
  if name ~= "auto" then
    return backends[name], name
  end
  for _, n in ipairs(BACKENDS_ORDER) do
    if backends[n].available(opts) then
      return backends[n], n
    end
  end
  return nil, nil
end

-- ─── picker source ─────────────────────────────────────────────────────────

---@param opts snacks.picker.Config
---@param ctx snacks.picker.ctx
function M.source(opts, ctx)
  local search = opts.search or ""
  if search == "" then
    return function(_cb) end
  end

  -- Ensure opts.backends is populated (needed when called via registered source)
  if not opts.backends then
    opts = vim.tbl_deep_extend("force", M.config, opts)
  end

  local backend, name = resolve_backend(opts)
  if not backend then
    vim.notify(
      "snacks-everything: no supported backend found (tried: " .. table.concat(BACKENDS_ORDER, ", ") .. ")",
      vim.log.levels.WARN
    )
    return function(_cb) end
  end

  local query_parts = split_search(search)
  return require("snacks.picker.source.proc").proc(ctx:opts({
    cmd = backend.cmd(opts),
    args = backend.build_args(opts, query_parts),
    transform = function(item)
      local path = vim.trim(item.text)
      if path == "" then
        return false
      end
      item.file = path
      item.text = path
    end,
  }), ctx)
end

-- ─── public API ────────────────────────────────────────────────────────────

---@param opts? snacks_everything.Config
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})

  local ok, snacks_picker = pcall(require, "snacks.picker")
  if not ok then
    return
  end

  snacks_picker.sources = snacks_picker.sources or {}
  snacks_picker.sources.everything = vim.tbl_extend("force", {
    title = "File Search",
    live = true,
    supports_live = true,
    need_search = true,
    finder = M.source,
    format = "file",
    preview = "file",
  }, M.config)
end

---@param opts? snacks_everything.Config|snacks.picker.Config
function M.pick(opts)
  local cfg = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Resolve backend early so we can show an accurate title
  local _, name = resolve_backend(cfg)
  local title_map = { everything = "Everything", plocate = "plocate" }
  local title = title_map[name] or "File Search"

  Snacks.picker.pick(vim.tbl_extend("force", cfg, {
    title = title,
    live = true,
    supports_live = true,
    need_search = true,
    finder = M.source,
    format = "file",
    preview = "file",
  }))
end

return M
