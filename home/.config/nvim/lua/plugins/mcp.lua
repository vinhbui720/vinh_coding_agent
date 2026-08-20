return {
  {
    "linw1995/nvim-mcp",
    build = "cargo install --path .",
    init = function()
      require("jcode_ai").setup()
    end,
    opts = function()
      return {
        custom_tools = require("jcode_ai").mcp_tools(),
      }
    end,
  },
}
