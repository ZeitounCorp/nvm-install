# nvm-install

Opinionated, automation-friendly **nvm installer** with optional Node install, shell detection, completions, and `.nvmrc` auto-switching.

Designed for people who bootstrap a lot of servers or developer machines and want a **single `curl | bash` command** that “just works”.

---

## Features

- ✅ Installs **nvm** using the **official upstream install script**
- ✅ Detects your shell (`bash`, `zsh`, fallback to `.profile`)
- ✅ Safely edits the correct shell config file
- ✅ Optional:
  - nvm shell auto-loading
  - bash completions
  - `.nvmrc` auto-use on `cd`
  - Install a default Node.js version on first run
- ✅ Works **interactively** *and* **non-interactively**
- ✅ Idempotent (won’t duplicate config lines)

---

## Quick Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/ZeitounCorp/nvm-install/main/install-nvm.sh | bash
```

You will be prompted for:
- enabling shell completions
- installing a default Node.js version
- enabling `.nvmrc` auto-switching

---

## Non-Interactive / Automation Usage

Perfect for cloud-init, Ansible, or server bootstrap scripts.

```bash
curl -fsSL https://raw.githubusercontent.com/ZeitounCorp/nvm-install/main/install-nvm.sh | \
  env \
    NVM_INSTALL_NODE="--lts" \
    NVM_ENABLE_COMPLETIONS=1 \
    NVM_ENABLE_NVMRC_AUTO=1 \
  bash
```

---

## Environment Variables

All options can be controlled via environment variables.

| Variable | Description | Default |
|--------|-------------|---------|
| `NVM_VERSION` | nvm git tag or branch to install | `v0.40.3` |
| `NVM_INSTALL_NODE` | Node version to install (`--lts`, `node`, `20.11.0`, `none`) | interactive prompt / `--lts` |
| `NVM_ENABLE_COMPLETIONS` | Enable bash completions (`1` or `0`) | prompt |
| `NVM_ENABLE_NVMRC_AUTO` | Enable `.nvmrc` auto-switching (`1` or `0`) | prompt |
| `NVM_PROFILE_FILE` | Explicit shell config file path | auto-detected |
| `NVM_DIR_CUSTOM` | Custom nvm install directory | `~/.nvm` |

---

## Node.js Installation Options

When enabled, the script can install a default Node version.

Valid values for `NVM_INSTALL_NODE`:

| Value | Meaning |
|-----|--------|
| `--lts` | Latest LTS (recommended) |
| `lts/*` | Latest LTS alias |
| `node` | Latest current Node |
| `20.11.0` | Specific version |
| `none` | Skip Node install |

> ℹ️ The **first installed version becomes the default**, per nvm behavior.

---

## Shell Detection & Config Files

The script automatically detects your shell and edits the correct file:

| Shell | File |
|-----|------|
| `bash` | `~/.bashrc` |
| `zsh` | `~/.zshrc` |
| unknown | `~/.profile` |

You can override this with:

```bash
NVM_PROFILE_FILE=~/.customrc
```

---

## `.nvmrc` Auto-Switching

When enabled:
- `cd` into a directory with `.nvmrc`
- Automatically installs the version if missing
- Automatically switches Node version silently

This works for both **bash** and **zsh**.

---

## Bash Completions

- Enabled only for **bash**
- Uses nvm’s official `bash_completion` file
- Zsh users are encouraged to use a plugin manager instead

---

## After Installation

Restart your terminal or run:

```bash
source ~/.bashrc
# or
source ~/.zshrc
```

Verify:

```bash
nvm --version
node -v
npm -v
```

---

## Security Notes

- This script uses the **official nvm install.sh**
- For production use:
  - pin `NVM_VERSION` to a tag
  - avoid `master`
  - vendor the script if needed

---

## License

MIT

---

## Maintainer

**ZeitounCorp**  
https://github.com/ZeitounCorp
