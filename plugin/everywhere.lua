vim.api.nvim_create_user_command("Everywhere", function()
  require("everywhere").pick()
end, { desc = "Open the everywhere.nvim file search picker" })
