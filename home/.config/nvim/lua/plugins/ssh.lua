return {
  {
    "chipsenkbeil/distant.nvim",
    branch = "v0.3",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    },
    cmd = {
      "Distant",
      "DistantInstall",
      "DistantLaunch",
      "DistantOpen",
      "DistantUpload",
      "DistantShell",
    },
    config = function()
      require("distant"):setup({})
      vim.keymap.set("n", "<leader>fS", "<cmd>DistantShell<cr>", { desc = "Start remote SSH shell" })
      vim.keymap.set("n", "<leader>fo", "<cmd>DistantOpen<cr>", { desc = "Open remote file" })
      vim.keymap.set("n", "<leader>rs", "<cmd>DistantShell<cr>", { desc = "Start remote SSH shell" })
      vim.keymap.set("n", "<leader>ro", "<cmd>DistantOpen<cr>", { desc = "Open remote file" })
    end,
    keys = {
      {
        "<leader>fS",
        "<cmd>DistantShell<cr>",
        desc = "Start remote SSH shell",
      },
      {
        "<leader>fo",
        "<cmd>DistantOpen<cr>",
        desc = "Open remote file",
      },
      {
        "<leader>rs",
        "<cmd>DistantShell<cr>",
        desc = "Start remote SSH shell",
      },
      {
        "<leader>ro",
        "<cmd>DistantOpen<cr>",
        desc = "Open remote file",
      },
    },
  },
}
