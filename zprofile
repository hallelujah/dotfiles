if [ -d "/opt/homebrew" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
elif [ -d "~/.linuxbrew" ]; then
  eval "$(~/.linuxbrew/bin/brew shellenv zsh)"
elif [ -d "/home/linuxbrew" ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
fi

# Enable systemd linger so --user services (e.g. mcp-hub) start at boot without
# an active login session. Idempotent; safe to run on every new distro setup.
# On NixOS use users.users.<name>.linger = true; instead.
if command -v loginctl &>/dev/null && [ "$(loginctl show-user "$USER" --property=Linger --value 2>/dev/null)" != "yes" ]; then
  loginctl enable-linger "$USER"
fi
