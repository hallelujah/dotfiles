-- Exclude Javascript files in :Rtags via rails.vim due to warnings when parsing
vim.g.Tlist_Ctags_Cmd = "ctags --exclude='*.js'"

-- Index ctags from any project, including those outside Rails
function _G.ReindexCtags()
  local ctags_hook_file = "$(git rev-parse --show-toplevel)/.git/hooks/ctags"
  local ctags_hook_path = vim.fn.system("echo " .. ctags_hook_file):gsub("\n+$", "")

  if vim.fn.filereadable(vim.fn.expand(ctags_hook_path)) == 1 then
    vim.fn.system(ctags_hook_file)
  else
    vim.fn.system("ctags -R .")
  end
end

-- to stop this mapping from being added, put this in $MYVIMRC:
--   let g:thoughtbot_ctags_mappings_enabled = 0
vim.g.thoughtbot_ctags_mappings_enabled = vim.g.thoughtbot_ctags_mappings_enabled or 1

if vim.g.thoughtbot_ctags_mappings_enabled ~= 0 then
  vim.keymap.set("n", "<Leader>ct", ReindexCtags, { noremap = true })
end
