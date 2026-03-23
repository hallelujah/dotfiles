local tty_path

if [ -z "${GPG_TTY-}" ]; then
  if tty_path=$(tty 2>/dev/null); then
    export GPG_TTY="$tty_path"
  fi
fi
