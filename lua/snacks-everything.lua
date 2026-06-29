local M = {}

-- Default configuration
local defaults = {
  backend = "auto",   -- "auto" picks the first installed tool; or "everything" / "plocate"
  case_sensitive = false,
  whole_word = false,
  match_path = false, -- false = filename only, true = full path
  regex = true,
  max_results = 100,
  backends = {
    everything = {
      cmd = "es",    -- path to es.exe (if not already in PATH)
      sort = false,  -- sort results alphabetically
      offset = 0,    -- skip the first N results
    },
    plocate = {
      cmd = "plocate",
      database = nil, -- path to a custom database (-d); nil uses the system default
    },
  },
}

M.config = vim.deepcopy(defaults)

-- Build the CLI arguments for es.exe (Everything, Windows)
local function everything_args(opts, query_parts)
  local b = opts.backends.everything
  local args = {}
  if opts.case_sensitive then table.insert(args, "-case") end
  if opts.whole_word    then table.insert(args, "-whole-word") end
  if opts.match_path    then table.insert(args, "-match-path") end
  if b.sort             then table.insert(args, "-s") end
  -- In Lua, 0 is truthy (only nil and false are falsy), so check > 0 explicitly
  if b.offset and b.offset > 0 then
    table.insert(args, "-offset")
    table.insert(args, tostring(b.offset))
  end
  if opts.max_results then
    table.insert(args, "-max-results")
    table.insert(args, tostring(opts.max_results))
  end
  -- -regex must come after all other flags
  if opts.regex then table.insert(args, "-regex") end
  vim.list_extend(args, query_parts)
  return args
end

-- Build the CLI arguments for plocate (Linux)
local function plocate_args(opts, query_parts)
  local b = opts.backends.plocate
  local args = {}
  -- plocate is case-sensitive by default; add -i to make it insensitive
  if not opts.case_sensitive then table.insert(args, "-i") end
  if opts.whole_word then table.insert(args, "-w") end
  -- plocate ORs multiple terms by default; -A makes all of them required
  if #query_parts > 1 then table.insert(args, "-A") end
  if opts.max_results then
    table.insert(args, "-l")
    table.insert(args, tostring(opts.max_results))
  end
  if b.database then
    table.insert(args, "-d")
    table.insert(args, b.database)
  end
  -- plocate searches the full path by default; -b restricts to filename only
  if not opts.match_path then table.insert(args, "-b") end
  if opts.regex then table.insert(args, "--regex") end
  vim.list_extend(args, query_parts)
  return args
end

-- Split a search string into parts, keeping quoted phrases together.
-- Example: 'my "lua plugin" config' -> { "my", "lua plugin", "config" }
local function split_search(search)
  local parts = {}
  local remaining = search
  for quoted in search:gmatch('"[^"]*"') do
    table.insert(parts, quoted:sub(2, -2)) -- strip the surrounding quotes
    remaining = remaining:gsub('"[^"]*"', "", 1)
  end
  for word in remaining:gmatch("%S+") do
    table.insert(parts, word)
  end
  return parts
end

-- Return the name of the backend to use, or nil if none is available.
local function resolve_backend(opts)
  if opts.backend ~= "auto" then
    return opts.backend
  end
  for _, name in ipairs({ "everything", "plocate" }) do
    if vim.fn.executable(opts.backends[name].cmd) == 1 then
      return name
    end
  end
  return nil
end

-- The finder function Snacks calls to populate the picker.
-- Runs the search command and feeds back one result per output line.
function M.source(opts, ctx)
  local search = opts.search or ""
  if search == "" then
    return function() end -- nothing to show yet
  end

  -- Merge defaults in case this is called without going through M.pick()
  if not opts.backends then
    opts = vim.tbl_deep_extend("force", M.config, opts)
  end

  local backend_name = resolve_backend(opts)
  if not backend_name then
    vim.notify("snacks-everything: no backend found (tried: everything, plocate)", vim.log.levels.WARN)
    return function() end
  end

  local query_parts = split_search(search)
  local cmd = opts.backends[backend_name].cmd
  local args
  if backend_name == "everything" then
    args = everything_args(opts, query_parts)
  else
    args = plocate_args(opts, query_parts)
  end

  return require("snacks.picker.source.proc").proc(ctx:opts({
    cmd = cmd,
    args = args,
    transform = function(item)
      local path = vim.trim(item.text)
      if path == "" then return false end -- skip blank lines in output
      item.file = path
      item.text = path
    end,
  }), ctx)
end

-- Call this from your Neovim config to set options and register the picker.
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})

  local ok, snacks_picker = pcall(require, "snacks.picker")
  if not ok then return end

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

-- Open the file search picker. Pass opts to override config for this call only.
function M.pick(opts)
  local cfg = vim.tbl_deep_extend("force", M.config, opts or {})

  local name = resolve_backend(cfg)
  local titles = { everything = "Everything", plocate = "plocate" }
  local title = titles[name] or "File Search"

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
