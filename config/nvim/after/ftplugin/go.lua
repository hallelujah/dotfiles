vim.g.go_fmt_command = "goimports"
vim.opt_local.listchars = { tab = "  ", trail = "·", nbsp = "·" }
vim.opt_local.expandtab = false
vim.cmd.compiler("go")
