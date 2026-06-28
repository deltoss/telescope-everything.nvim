local M = {}

---@class snacks_everything.Config
local defaults = {
  es_path = "es",
  case_sensitive = false,
  whole_word = false,
  match_path = false,
  sort = false,
  regex = true,
  offset = 0,
  max_results = 100,
}

M.config = vim.deepcopy(defaults)

---@param opts? snacks_everything.Config
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})

  -- Register as a named Snacks source so users can call Snacks.picker.everything()
  local ok, snacks_picker = pcall(require, "snacks.picker")
  if ok then
    snacks_picker.sources = snacks_picker.sources or {}
    snacks_picker.sources.everything = {
      title = "Everything",
      live = true,
      supports_live = true,
      need_search = true,
      finder = M.source,
      format = "file",
      preview = "file",
      -- Propagate the merged config as source defaults
      es_path = M.config.es_path,
      case_sensitive = M.config.case_sensitive,
      whole_word = M.config.whole_word,
      match_path = M.config.match_path,
      sort = M.config.sort,
      regex = M.config.regex,
      offset = M.config.offset,
      max_results = M.config.max_results,
    }
  end
end

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

local function build_es_args(opts, query_parts)
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
  if opts.sort then
    args[#args + 1] = "-s"
  end
  -- Avoid passing -offset 0 (default) unnecessarily; 0 is truthy in Lua
  if opts.offset and opts.offset > 0 then
    args[#args + 1] = "-offset"
    args[#args + 1] = tostring(opts.offset)
  end
  if opts.max_results then
    args[#args + 1] = "-max-results"
    args[#args + 1] = tostring(opts.max_results)
  end
  -- -regex must be the last flag, before query terms
  if opts.regex then
    args[#args + 1] = "-regex"
  end
  vim.list_extend(args, query_parts)
  return args
end

---@param opts snacks.picker.Config
---@param ctx snacks.picker.ctx
function M.source(opts, ctx)
  local search = opts.search or ""
  if search == "" then
    return function(_cb) end
  end
  local query_parts = split_search(search)
  local es_args = build_es_args(opts, query_parts)
  return require("snacks.picker.source.proc").proc(ctx:opts({
    cmd = opts.es_path,
    args = es_args,
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

---@param opts? snacks_everything.Config|snacks.picker.Config
function M.pick(opts)
  opts = vim.tbl_deep_extend("force", M.config, opts or {})
  Snacks.picker.pick({
    title = "Everything",
    live = true,
    supports_live = true,
    need_search = true,
    finder = M.source,
    format = "file",
    preview = "file",
    es_path = opts.es_path,
    case_sensitive = opts.case_sensitive,
    whole_word = opts.whole_word,
    match_path = opts.match_path,
    sort = opts.sort,
    regex = opts.regex,
    offset = opts.offset,
    max_results = opts.max_results,
  })
end

return M
