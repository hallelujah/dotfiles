# ensure dotfiles bin directory is loaded first
PATH="$HOME/.local/bin:$HOME/.bin:/usr/local/sbin:$PATH"

# mkdir .git/safe in the root of repositories you trust
PATH=".git/safe/../../bin:$PATH"

export -U PATH

# Activate Mise for system that has it (MacOS, Fedora)
if command -v mise >/dev/null; then
  eval "$(mise activate zsh)"
fi

arch="$(uname -m)"
if [ "$arch" = "arm64" ]; then
  HOMEBREW_PREFIX="/opt/homebrew"
else
  HOMEBREW_PREFIX="/usr/local"
fi

# Activate Homebrew for system that has it (MacOS)
if [ -f "$HOMEBREW_PREFIX/bin/brew" ]; then
  eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"
fi
