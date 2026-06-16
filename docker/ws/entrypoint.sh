#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.ssh" "$HOME/.config" "$HOME/.cache" "$HOME/.bun/install/cache" /alp
chmod 700 "$HOME/.ssh" 2>/dev/null || true

DOTFILES_DIR="/alp/dotfiles"

link_dotfile() {
  local source_path="$1"
  local target_path="$2"

  if [ ! -e "$source_path" ]; then
    return
  fi

  if [ -e "$target_path" ] && [ ! -L "$target_path" ]; then
    return
  fi

  ln -sfn "$source_path" "$target_path"
}

if [ -d "$DOTFILES_DIR" ]; then
  link_dotfile "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
  link_dotfile "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"
  link_dotfile "$DOTFILES_DIR/.config/tmux" "$HOME/.config/tmux"
  link_dotfile "$DOTFILES_DIR/.config/lazygit" "$HOME/.config/lazygit"
fi

render_deepcode_settings() {
  if [ ! -f "$DOTFILES_DIR/.env" ]; then
    return
  fi

  set -a
  # shellcheck disable=SC1091
  . "$DOTFILES_DIR/.env"
  set +a

  mkdir -p "$HOME/.deepcode"
  jq -n \
    --arg model "${DEEPCODE_MODEL:-deepseek-v4-pro}" \
    --arg base_url "${DEEPCODE_BASE_URL:-https://api.deepseek.com}" \
    --arg api_key "${DEEPCODE_API_KEY:-}" \
    --argjson thinking_enabled "${DEEPCODE_THINKING_ENABLED:-true}" \
    --arg reasoning_effort "${DEEPCODE_REASONING_EFFORT:-max}" \
    '{
      env: {
        MODEL: $model,
        BASE_URL: $base_url,
        API_KEY: $api_key
      },
      thinkingEnabled: $thinking_enabled,
      reasoningEffort: $reasoning_effort
    }' > "$HOME/.deepcode/settings.json"
  chmod 600 "$HOME/.deepcode/settings.json"
}

render_deepcode_settings

if [ ! -f "$HOME/.ssh/known_hosts" ]; then
  ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
fi

if [ ! -f "$HOME/.gitconfig" ]; then
  cat > "$HOME/.gitconfig" <<'EOF'
[init]
	defaultBranch = main
[pull]
	rebase = false
[core]
	editor = nvim
EOF
fi

exec "$@"
