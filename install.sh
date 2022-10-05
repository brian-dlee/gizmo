#!/bin/bash

set -e

if [[ ! -e "$HOME/.gizmo" ]]; then
  mkdir -p "$HOME/.gizmo/bin"
  git clone https://github.com/brian-dlee/gizmo "$HOME/.gizmo/src"
else
  cd "$HOME/.gizmo/src"
  git pull
fi

cat >"$HOME/.gizmo/exports.sh" <<EOF
export GIZMO_HOME="$HOME/.gizmo"
export GIZMO_BIN="$GIZMO_HOME/bin"
export GIZMO_SRC="$GIZMO_SRC/bin"
export PATH="$HOME/.gizmo/bin:$PATH"
EOF

chmod +x "$GIZMO_SRC/docker/build/ecr.sh"
ln -s "$GIZMO_SRC/docker/build/ecr.sh" "$GIZMO_BIN/gizmo-ecr"