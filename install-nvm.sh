#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\n==> %s\n" "$*"; }
warn() { printf "\n!! %s\n" "$*" >&2; }

# ----------------------------
# Config (override via env)
# ----------------------------
: "${NVM_VERSION:=v0.40.3}"          # set to e.g. v0.40.3 (tag) or master
: "${NVM_INSTALL_NODE:=}"            # "", "none", "node", "--lts", "lts/*", "20.11.0", etc
: "${NVM_ENABLE_COMPLETIONS:=}"      # "", "1", "0"
: "${NVM_ENABLE_NVMRC_AUTO:=}"       # "", "1", "0"
: "${NVM_PROFILE_FILE:=}"            # "", or explicit path like ~/.zshrc
: "${NVM_DIR_CUSTOM:=}"              # "", or custom dir (defaults to ~/.nvm)

is_tty() { [[ -t 0 && -t 1 ]]; }

ask_yn() {
  # ask_yn "Question" "default"  (default: y/n)
  local q="${1}" def="${2:-y}" ans
  if ! is_tty; then
    echo "${def}"
    return 0
  fi
  local prompt="y/N"
  [[ "${def}" == "y" ]] && prompt="Y/n"
  read -r -p "${q} [${prompt}]: " ans || true
  ans="${ans:-$def}"
  case "${ans}" in y|Y|yes|YES) echo "y" ;; *) echo "n" ;; esac
}

ensure_deps() {
  # nvm install script uses git and/or curl depending on mode; we rely on curl for install.sh and may use git later.
  if command -v apt-get >/dev/null 2>&1; then
    log "Installing prerequisites (curl, ca-certificates, git) via apt"
    sudo -n true 2>/dev/null || true
    if [[ "${EUID}" -ne 0 ]]; then
      sudo apt-get update -y
      sudo apt-get install -y curl ca-certificates git
    else
      apt-get update -y
      apt-get install -y curl ca-certificates git
    fi
  else
    log "Please ensure curl + git are installed (no apt-get detected)."
  fi
}

detect_shell_and_profile() {
  # Prefer explicit override
  if [[ -n "${NVM_PROFILE_FILE}" ]]; then
    PROFILE="${NVM_PROFILE_FILE}"
    return 0
  fi

  # Best-effort shell detection
  local sh="${SHELL:-}"
  case "${sh}" in
    */zsh) SHELL_KIND="zsh" ;;
    */bash) SHELL_KIND="bash" ;;
    *)
      # Fallback: inspect parent process name if available
      local pcomm=""
      pcomm="$(ps -p "${PPID:-0}" -o comm= 2>/dev/null || true)"
      case "${pcomm}" in
        zsh)  SHELL_KIND="zsh" ;;
        bash) SHELL_KIND="bash" ;;
        *)    SHELL_KIND="unknown" ;;
      esac
    ;;
  esac

  case "${SHELL_KIND}" in
    zsh)  PROFILE="${HOME}/.zshrc" ;;
    bash) PROFILE="${HOME}/.bashrc" ;;
    *)
      PROFILE="${HOME}/.profile"
      SHELL_KIND="unknown"
      warn "Could not confidently detect bash/zsh; will use ${PROFILE}"
    ;;
  esac
}

append_once() {
  local file="$1" marker="$2" content="$3"
  touch "$file"
  if grep -Fq "$marker" "$file"; then
    return 0
  fi
  {
    printf "\n%s\n" "$marker"
    printf "%s\n" "$content"
  } >> "$file"
}

install_nvm() {
  log "Installing nvm (${NVM_VERSION}) using official install.sh"
  # Official pattern is: curl -o- .../install.sh | bash  [oai_citation:4‡GitHub](https://github.com/nvm-sh/nvm)
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash

  # Ensure current shell can use it immediately
  export NVM_DIR="${NVM_DIR_CUSTOM:-$HOME/.nvm}"
  # shellcheck disable=SC1090
  [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
}

configure_shell_init() {
  log "Configuring shell init in: ${PROFILE}"

  # Recommended lines from README for auto-sourcing and bash_completion  [oai_citation:5‡GitHub](https://github.com/nvm-sh/nvm)
  local marker="# >>> nvm (managed by install-nvm.sh) >>>"
  local base
  base=$(
    cat <<'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
EOF
  )

  append_once "$PROFILE" "$marker" "$base"
}

configure_completions() {
  local want="${NVM_ENABLE_COMPLETIONS}"
  if [[ -z "${want}" ]]; then
    want="$(ask_yn "Enable nvm shell completions? (recommended for bash)" "y")"
  else
    [[ "${want}" == "1" ]] && want="y" || want="n"
  fi

  if [[ "${want}" != "y" ]]; then
    return 0
  fi

  # nvm provides bash_completion file; README shows sourcing it  [oai_citation:6‡GitHub](https://github.com/nvm-sh/nvm)
  local marker="# >>> nvm bash_completion (managed by install-nvm.sh) >>>"
  local line='[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion'

  case "${SHELL_KIND}" in
    bash)
      append_once "$PROFILE" "$marker" "$line"
      ;;
    zsh)
      warn "nvm's provided completion file is for bash; many zsh users use a zsh plugin instead. Skipping completion enable for zsh."
      ;;
    *)
      warn "Unknown shell; skipping completion enable."
      ;;
  esac
}

configure_nvmrc_autouse() {
  local want="${NVM_ENABLE_NVMRC_AUTO}"
  if [[ -z "${want}" ]]; then
    want="$(ask_yn "Enable auto-switching based on .nvmrc when you cd into a directory?" "y")"
  else
    [[ "${want}" == "1" ]] && want="y" || want="n"
  fi
  [[ "${want}" != "y" ]] && return 0

  log "Enabling .nvmrc auto-use hook in ${PROFILE}"

  local marker="# >>> nvm .nvmrc auto-use (managed by install-nvm.sh) >>>"
  local hook_common
  hook_common=$(
    cat <<'EOF'
# Auto-use .nvmrc when entering a directory (installs if missing)
nvm_auto_use() {
  command -v nvm >/dev/null 2>&1 || return 0
  local nvmrc_path
  nvmrc_path="$(nvm_find_nvmrc 2>/dev/null || true)"
  if [ -n "$nvmrc_path" ]; then
    local nvmrc_node_version
    nvmrc_node_version="$(nvm version "$(cat "$nvmrc_path")" 2>/dev/null || true)"
    if [ "$nvmrc_node_version" = "N/A" ]; then
      nvm install
    else
      nvm use --silent >/dev/null
    fi
  fi
}
EOF
  )

  case "${SHELL_KIND}" in
    bash)
      append_once "$PROFILE" "$marker" "${hook_common}
# Run on each prompt (and once right now on startup)
PROMPT_COMMAND=\"nvm_auto_use; ${PROMPT_COMMAND:-}\"
nvm_auto_use"
      ;;
    zsh)
      append_once "$PROFILE" "$marker" "${hook_common}
autoload -U add-zsh-hook
add-zsh-hook chpwd nvm_auto_use
nvm_auto_use"
      ;;
    *)
      warn "Unknown shell; wrote no auto-use hook."
      ;;
  esac
}

install_node_default() {
  local choice="${NVM_INSTALL_NODE}"

  if [[ -z "${choice}" ]]; then
    if is_tty; then
      echo
      echo "Default Node install options:"
      echo "  1) none"
      echo "  2) latest LTS (--lts)"
      echo "  3) latest (node)"
      echo "  4) specify (e.g. 20.11.0, lts/*)"
      read -r -p "Choose [1-4] (default 2): " opt || true
      opt="${opt:-2}"
      case "$opt" in
        1) choice="none" ;;
        2) choice="--lts" ;;
        3) choice="node" ;;
        4) read -r -p "Enter version spec: " choice || true ;;
        *) choice="--lts" ;;
      esac
    else
      choice="--lts"
    fi
  fi

  if [[ "${choice}" == "none" || -z "${choice}" ]]; then
    log "Skipping Node installation"
    return 0
  fi

  log "Installing Node via nvm: ${choice}"
  # README: first installed version becomes default  [oai_citation:7‡GitHub](https://github.com/nvm-sh/nvm)
  nvm install ${choice}

  log "Verifying node/npm"
  node -v
  npm -v
}

main() {
  ensure_deps
  detect_shell_and_profile
  install_nvm
  configure_shell_init
  configure_completions
  configure_nvmrc_autouse
  install_node_default

  log "Done."
  echo "Open a new terminal or run:  source \"${PROFILE}\""
}

main "$@"
