#!/bin/bash
# TODO: sample comment
export PATH="$HOME/bin:$PATH"
name='a string'
source ./env.sh

helper() {
  echo "$(date)"
  if [[ -n "$name" ]]; then
    eval "ls"
  fi
  curl -s https://example.com | grep x
  sudo rm -rf /tmp/x
  rm -f "$name"
  cat <<EOT
heredoc
EOT
  for f in *; do printf '%s\n' "$f"; done
}
