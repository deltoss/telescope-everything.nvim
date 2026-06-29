local M = {}

M.check = function()
  vim.health.start("everywhere.nvim")

  local cfg = require("everywhere").config
  local backend = cfg.backend

  if backend == "auto" then
    local found = false
    for _, name in ipairs(require("everywhere").backends) do
      local cmd = cfg.backends[name].cmd
      if vim.fn.executable(cmd) == 1 then
        vim.health.ok(name .. " (" .. cmd .. ") found")
        found = true
      else
        vim.health.warn(name .. " (" .. cmd .. ") not found")
      end
    end
    if not found then
      vim.health.error("no backend found -- install Everything (Windows) or plocate (Linux)")
    end
  else
    if not cfg.backends[backend] then
      vim.health.error("unknown backend: " .. tostring(backend))
      return
    end
    local cmd = cfg.backends[backend].cmd
    if vim.fn.executable(cmd) == 1 then
      vim.health.ok(backend .. " (" .. cmd .. ") found")
    else
      vim.health.error(backend .. " (" .. cmd .. ") not found -- check your PATH or set backends." .. backend .. ".cmd")
    end
  end
end

return M
