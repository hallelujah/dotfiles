# thoughtbot dotfiles

![prompt](http://images.thoughtbot.com/thoughtbot-dotfiles-prompt.png)

<!-- mtoc-start -->

* [Requirements](#requirements)
* [Install](#install)
* [Update](#update)
* [Make your own customizations](#make-your-own-customizations)
* [zsh Configurations](#zsh-configurations)
* [zsh History Configurations](#zsh-history-configurations)
* [nvim Configurations](#nvim-configurations)
* [What's in it?](#whats-in-it)
* [Thanks](#thanks)
* [License](#license)
* [About thoughtbot](#about-thoughtbot)

<!-- mtoc-end -->

## Requirements

Set zsh as your login shell:

    chsh -s $(which zsh)

## Install

Clone onto your machine:

    git clone git@github.com:hallelujah/dotfiles.git ~/dotfiles

(Or, [fork and keep your fork
updated](http://robots.thoughtbot.com/keeping-a-github-fork-updated)).

Install [rcm](https://github.com/thoughtbot/rcm):

    brew install rcm

Install the dotfiles:

    env RCRC=$HOME/dotfiles/rcrc rcup

After the initial installation, you can run `rcup` without the one-time variable
`RCRC` being set (`rcup` will symlink the repo's `rcrc` to `~/.rcrc` for future
runs of `rcup`). [See
example](https://github.com/thoughtbot/dotfiles/blob/master/rcrc).

This command will create symlinks for config files in your home directory.
Setting the `RCRC` environment variable tells `rcup` to use standard
configuration options:

- Exclude the `README.md` and `LICENSE` files, which are part of
  the `dotfiles` repository but do not need to be symlinked in.
- Give precedence to personal overrides which by default are placed in
  `~/dotfiles-local`
- Please configure the `rcrc` file if you'd like to make personal
  overrides in a different directory

## Update

From time to time you should pull down any updates to these dotfiles, and run

    rcup

to link any new files and install new nvim plugins. **Note** You _must_ run
`rcup` after pulling to ensure that all files in plugins are properly installed,
but you can safely run `rcup` multiple times so update early and update often!

## Make your own customizations

Create a directory for your personal customizations:

    mkdir ~/dotfiles-local

Put your customizations in `~/dotfiles-local` appended with `.local`:

- `~/dotfiles-local/aliases.local`
- `~/dotfiles-local/git_template.local/*`
- `~/dotfiles-local/gitconfig.local`
- `~/dotfiles-local/psqlrc.local` (we supply a blank `.psqlrc.local` to prevent `psql` from
  throwing an error, but you should overwrite the file with your own copy)
- `~/dotfiles-local/tmux.conf.local`
- `~/dotfiles-local/init.local.lua` (Lua)
- `~/dotfiles-local/**/*.local.lua` (any directory)
- `~/dotfiles-local/zshrc.local`
- `~/dotfiles-local/zsh/configs/*`

For example, your `~/dotfiles-local/aliases.local` might look like this:

    # Productivity
    alias todo='$EDITOR ~/.todo'

Your `~/dotfiles-local/gitconfig.local` might look like this:

    [alias]
      l = log --pretty=colored
    [pretty]
      colored = format:%Cred%h%Creset %s %Cgreen(%cr) %C(bold blue)%an%Creset
    [user]
      name = Dan Croak
      email = dan@thoughtbot.com

Your `~/dotfiles-local/init.local.lua` might look like this:

    -- Color scheme
    vim.cmd.colorscheme("github")
    vim.api.nvim_set_hl(0, "NonText", { bg = "#060606" })
    vim.api.nvim_set_hl(0, "Folded", { bg = "#0A0A0A", fg = "#9090D0" })

If you don't wish to install a plugin from the default set of nvim plugins, you can disable it in your `~/dotfiles-local/lua/plugins/`.

    -- Example to disable a plugin
    return {
      { "plugin-name", enabled = false },
    }

To extend your `git` hooks, create executable scripts in
`~/dotfiles-local/git_template.local/hooks/*` files.

Your `~/dotfiles-local/zshrc.local` might look like this:

    # load pyenv if available
    if which pyenv &>/dev/null ; then
      eval "$(pyenv init -)"
    fi

Your `~/dotfiles-local/lua/plugins/local.lua` might look like this:

    return {
      { "Lokaltog/vim-powerline" },
      { "stephenmckinney/vim-solarized-powerline" },
    }

**Tip:** You can add any file `*.local.lua` to any directory in `~/dotfiles-local/config/nvim/` and it will be recognized as a Lua file. If you add it to `after/ftplugin/`, it will be automatically loaded for that filetype.

## zsh Configurations

Additional zsh configuration can go under the `~/dotfiles-local/zsh/configs` directory. This
has two special subdirectories: `pre` for files that must be loaded first, and
`post` for files that must be loaded last.

For example, `~/dotfiles-local/zsh/configs/pre/virtualenv` makes use of various shell
features which may be affected by your settings, so load it first:

    # Load the virtualenv wrapper
    . /usr/local/bin/virtualenvwrapper.sh

Setting a key binding can happen in `~/dotfiles-local/zsh/configs/keys`:

    # Grep anywhere with ^G
    bindkey -s '^G' ' | grep '

Some changes, like `chpwd`, must happen in `~/dotfiles-local/zsh/configs/post/chpwd`:

    # Show the entries in a directory whenever you cd in
    function chpwd {
      ls
    }

This directory is handy for combining dotfiles from multiple teams; one team
can add the `virtualenv` file, another `keys`, and a third `chpwd`.

The `~/dotfiles-local/zshrc.local` is loaded after `~/dotfiles-local/zsh/configs`.

## zsh History Configurations

The zsh history is configured with several useful options:

- `hist_ignore_all_dups`: Removes duplicate commands from history

- `hist_ignore_space`: Commands starting with a space are not saved to history
  (useful for sensitive commands)

- `inc_append_history`: Adds commands to history as they're executed, not just
  when the shell exits

- `share_history`: Shares history across multiple zsh sessions in real-time

History size is set to 8,192 entries providing ample command history.

## nvim Configurations

Similarly to the zsh configuration directory as described above, nvim
automatically loads all files in the `~/dotfiles-local/config/nvim/after/plugin` directory. This does not
have the same `pre` or `post` subdirectory support that our `zshrc` has.

This is an example `~/dotfiles-local/config/nvim/after/ftplugin/c.local.lua`. It is loaded every time a C file is opened:

    -- Indent C programs according to BSD style(9)
    vim.opt_local.cinoptions = ":0,t0,+4,(4"
    vim.opt_local.shiftwidth = 0
    vim.opt_local.tabstop = 8
    vim.opt_local.expandtab = false

## What's in it?

[nvim](https://neovim.io/) configuration (now using [LazyVim](https://www.lazyvim.org)):

- [fzf-lua](https://github.com/ibhagwan/fzf-lua) for fuzzy file/buffer/tag finding.
- [Rails.vim](https://github.com/tpope/vim-rails) for enhanced navigation of
  Rails file structure via `gf` and `:A` (alternate), `:Rextract` partials,
  `:Rinvert` migrations, etc.
- Run many kinds of tests [from nvim](https://github.com/janko-m/vim-test)
- Set `<leader>` to a single space.
- Switch between the last two files with space-space.
- Syntax highlighting for Markdown, HTML, JavaScript, Ruby, Go, Elixir, more.
- Use [ripgrep](https://github.com/BurntSushi/ripgrep) instead of Grep when
  available.
- Map `<leader>ct` to re-index ctags.
- Use [vim-mkdir](https://github.com/pbrisbin/vim-mkdir) for automatically
  creating non-existing directories before writing the buffer.
- Use [lazy.nvim](https://github.com/folke/lazy.nvim) to manage plugins.

[tmux](http://robots.thoughtbot.com/a-tmux-crash-course)
configuration:

- Improve color resolution.
- Remove administrative debris (session name, hostname, time) in status bar.
- Set prefix to `Ctrl+s`
- Soften status bar color from harsh green to light gray.

[git](http://git-scm.com/) configuration:

- Adds a `co-upstream-pr $PR_NUMBER $LOCAL_BRANCH_NAME` subcommand to checkout remote upstream branch into a local branch.
- Adds a `create-branch` alias to create feature branches.
- Adds a `delete-branch` alias to delete feature branches.
- Adds a `merge-branch` alias to merge feature branches into master.
- Adds an `up` alias to fetch and rebase `origin/master` into the feature
  branch. Use `git up -i` for interactive rebases.
- Adds `post-{checkout,commit,merge}` hooks to re-index your ctags.
- Adds `pre-commit` and `prepare-commit-msg` stubs that delegate to your local
  config.
- Adds `trust-bin` alias to append a project's `bin/` directory to `$PATH`.

[Ruby](https://www.ruby-lang.org/en/) configuration:

- Add trusted binstubs to the `PATH`.

[Rails](https://rubyonrails.org)

- Adds [railsrc][] with the following options to integrate with [Suspenders][].

```
--database=postgresql
--skip-test
-m=https://raw.githubusercontent.com/thoughtbot/suspenders/main/lib/install/web.rb
```

If you want to skip this file altogether, run `rails new my_app --no_rc`.

[railsrc]: https://github.com/rails/rails/blob/7f7f9df8641e35a076fe26bd097f6a1b22cb4e2d/railties/lib/rails/generators/rails/app/USAGE#L5C1-L7
[Suspenders]: https://github.com/thoughtbot/suspenders

Shell aliases and scripts:

- `...` for quicker navigation to the parent's parent directory.
- `b` for `bundle`.
- `g` with no arguments is `git status` and with arguments acts like `git`.
- `migrate` for `bin/rails db:migrate db:rollback && bin/rails db:migrate db:test:prepare`.
- `mcd` to make a directory and change into it.
- `replace foo bar **/*.rb` to find and replace within a given list of files.
- `tat` to attach to tmux session named the same as the current directory.
- `v` for `$VISUAL`.

## Thanks

Thank you, [contributors](https://github.com/thoughtbot/dotfiles/contributors)!
Also, thank you to Corey Haines, Gary Bernhardt, and others for sharing your
dotfiles and other shell scripts from which we derived inspiration for items
in this project.

## License

dotfiles is copyright © 2009 thoughtbot. It is free software, and may be
redistributed under the terms specified in the [`LICENSE`] file.

[`LICENSE`]: /LICENSE

<!-- START /templates/footer.md -->

## About thoughtbot

![thoughtbot](https://thoughtbot.com/thoughtbot-logo-for-readmes.svg)

This repo is maintained and funded by thoughtbot, inc.
The names and logos for thoughtbot are trademarks of thoughtbot, inc.

We love open source software!
See [our other projects][community].
We are [available for hire][hire].

[community]: https://thoughtbot.com/community?utm_source=github
[hire]: https://thoughtbot.com/hire-us?utm_source=github

<!-- END /templates/footer.md -->
