#!/bin/bash

set -e

GIZMO_HOME="$HOME/.gizmo"
GIZMO_BIN="$GIZMO_HOME/bin"
GIZMO_SRC="$GIZMO_HOME/src"

# download or update gizmo
if [[ ! -e "$HOME/.gizmo" ]]; then
  mkdir -p "$HOME/.gizmo/bin"
  git clone https://github.com/brian-dlee/gizmo "$HOME/.gizmo/src"
else
  cd "$HOME/.gizmo/src"
  git pull
fi

# regenerate the shell entrypoint
cat >"$HOME/.gizmo/init.sh" <<"EOF"
export GIZMO_HOME="$HOME/.gizmo"
export GIZMO_BIN="$GIZMO_HOME/bin"
export GIZMO_SRC="$GIZMO_HOME/src"
export PATH="$HOME/.gizmo/bin:$PATH"
EOF

# install scripts
cp -f "$GIZMO_SRC/install.sh" "$GIZMO_BIN/gizmo-update"
cp -f "$GIZMO_SRC/docker/build/ecr.sh" "$GIZMO_BIN/gizmo-ecr"

# make all scripts executable
find "$GIZMO_BIN" -exec chmod +x {} \;

# check the shell integration
case $(basename "$SHELL") in
zsh)
  if ! grep ".gizmo/init.sh" "$HOME/.zshrc" >/dev/null; then
    echo 'Add "source $HOME/.gizmo/init.sh" to your .zshrc file to complete installation.' >&2
  fi
  ;;
bash)
  if ! grep ".gizmo/init.sh" "$HOME/.bashrc" >/dev/null; then
    echo 'Add "source $HOME/.gizmo/init.sh" to your .bashrc file to complete installation.' >&2
  fi
  ;;
*)
  echo 'Add "source $HOME/.gizmo/init.sh" to your shell configuration file to complete installation.' >&2
  ;;
esac
