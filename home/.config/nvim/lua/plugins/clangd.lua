return {
  -- Official LazyVim Extras
  { import = "lazyvim.plugins.extras.lang.clangd" },
  { import = "lazyvim.plugins.extras.lang.cmake" },
  { import = "lazyvim.plugins.extras.lang.json" },

  -- Optimized clangd configuration for large/huge C++ codebases
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        clangd = {
          cmd = {
            "clangd",
            "--background-index",             -- Index in background without freezing UI
            "--background-index-priority=low", -- Keep editor responsive even during heavy indexing
            "--header-insertion=iwyu",         -- Include-what-you-use (auto add headers)
            "--completion-style=detailed",    -- Detailed signatures (classes, return types, pointers)
            "--function-arg-placeholders",     -- Snippet placeholders for parameters
            "--fallback-style=llvm",
            "--limit-results=100",             -- Prevent RAM bloat on huge queries
            "-j=4",                            -- Worker threads
          },
        },
      },
    },
  },
}
