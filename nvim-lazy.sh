#!/bin/bash
#
# Installs Neovim + LazyVim with our team's configuration.
#
# Everything lands under $HOME, so no part of this needs root except the apt
# packages in step 1. Re-running is safe: each step detects what is already
# there, and an existing ~/.config/nvim is moved aside rather than overwritten.
#
# Unlike the other scripts here this uses `set -e`. A half-installed editor is
# harder to diagnose than a failed install, so it stops at the first error.

set -euo pipefail

NVIM_VERSION="v0.12.5"
FD_VERSION="v10.5.0"
NERD_FONTS_VERSION="v3.5.1"
NERD_FONT="JetBrainsMono"

BIN_DIR="$HOME/.local/bin"
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
NVIM_CONFIG="$HOME/.config/nvim"
# Sibling of ~/.local/share/nvim, which is plugin data and gets moved aside on
# reinstall. Keeping the program out of it means a reinstall never deletes it.
NVIM_PREFIX="$HOME/.local/share/nvim-$NVIM_VERSION"
WORK_DIR="$(mktemp -d)"

trap 'rm -rf "$WORK_DIR"' EXIT

step() { printf "\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n" "$1"; }
info() { printf "    %s\n" "$1"; }
warn() { printf "\033[1;33m    warning: %s\033[0m\n" "$1"; }

case "$(uname -m)" in
  x86_64)  NVIM_ARCH="linux-x86_64" ; FD_ARCH="x86_64-unknown-linux-musl" ;;
  aarch64) NVIM_ARCH="linux-arm64"  ; FD_ARCH="aarch64-unknown-linux-gnu" ;;
  *) echo "Unsupported architecture: $(uname -m). Expected x86_64 or aarch64." >&2 ; exit 1 ;;
esac

# ---------------------------------------------------------------------------
step "1/8  System packages"

if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update
  # ripgrep backs the grep pickers, fontconfig registers the Nerd Font, and
  # build-essential is what nvim-treesitter needs to compile its parsers.
  sudo apt-get install -y \
    git curl unzip tar build-essential fontconfig ripgrep xclip
else
  warn "apt-get not found. Install these yourself: git curl unzip tar a C compiler fontconfig ripgrep xclip"
fi

# ---------------------------------------------------------------------------
step "2/8  Neovim $NVIM_VERSION"

mkdir -p "$BIN_DIR"
if [ -x "$BIN_DIR/nvim" ] && "$BIN_DIR/nvim" --version 2>/dev/null | head -1 | grep -q "${NVIM_VERSION#v}"; then
  info "already installed"
else
  curl -fsSL -o "$WORK_DIR/nvim.tar.gz" \
    "https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/nvim-$NVIM_ARCH.tar.gz"
  tar xzf "$WORK_DIR/nvim.tar.gz" -C "$WORK_DIR"
  # Keep the whole prefix, not just bin/nvim. Neovim finds its runtime files
  # relative to the binary, so a lone binary starts without syntax files or
  # commands and every plugin call fails. The upstream AppImage solves this by
  # bundling the runtime, but it needs FUSE, which Ubuntu no longer installs by
  # default; the symlink here resolves to the real path and needs nothing.
  rm -rf "$NVIM_PREFIX"
  mkdir -p "$(dirname "$NVIM_PREFIX")"
  mv "$WORK_DIR/nvim-$NVIM_ARCH" "$NVIM_PREFIX"
  ln -sfn "$NVIM_PREFIX/bin/nvim" "$BIN_DIR/nvim"
  info "installed $("$BIN_DIR/nvim" --version | head -1)"
fi

# ---------------------------------------------------------------------------
step "3/8  fd $FD_VERSION"

# The snacks explorer hardcodes `fd` for its search and passes `--type d` to
# list directories, which ripgrep cannot do. Without fd, pressing `/` in the
# file tree fails with "No supported finder found".
if [ -x "$BIN_DIR/fd" ]; then
  info "already installed"
else
  curl -fsSL -o "$WORK_DIR/fd.tar.gz" \
    "https://github.com/sharkdp/fd/releases/download/$FD_VERSION/fd-$FD_VERSION-$FD_ARCH.tar.gz"
  tar xzf "$WORK_DIR/fd.tar.gz" -C "$WORK_DIR"
  install -m 0755 "$WORK_DIR/fd-$FD_VERSION-$FD_ARCH/fd" "$BIN_DIR/fd"
  info "installed fd $("$BIN_DIR/fd" --version | cut -d' ' -f2)"
fi

# ---------------------------------------------------------------------------
step "4/8  $NERD_FONT Nerd Font"

# Every file-type icon in the tree and statusline lives in a Nerd Font private
# use area. Without one the whole UI renders as tofu boxes.
# Checked on disk rather than through fc-list: a stale or unbuilt fontconfig
# cache would report the font missing and re-download 128MB every run.
if [ -f "$FONT_DIR/JetBrainsMonoNerdFontMono-Regular.ttf" ]; then
  info "already installed"
else
  curl -fsSL -o "$WORK_DIR/font.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/$NERD_FONTS_VERSION/$NERD_FONT.zip"
  mkdir -p "$FONT_DIR"
  # The Mono faces are single-width, which is what keeps tree indentation and
  # statusline separators aligned in a terminal.
  unzip -o -j "$WORK_DIR/font.zip" \
    "JetBrainsMonoNerdFontMono-Regular.ttf" \
    "JetBrainsMonoNerdFontMono-Bold.ttf" \
    "JetBrainsMonoNerdFontMono-Italic.ttf" \
    "JetBrainsMonoNerdFontMono-BoldItalic.ttf" \
    -d "$FONT_DIR" >/dev/null
  fc-cache -f "$HOME/.local/share/fonts" >/dev/null
  info "installed $(find "$FONT_DIR" -name '*.ttf' | wc -l) faces"
fi

# ---------------------------------------------------------------------------
step "5/8  LazyVim starter"

if [ -d "$NVIM_CONFIG" ]; then
  BACKUP="$NVIM_CONFIG.bak.$(date +%Y%m%d%H%M%S)"
  mv "$NVIM_CONFIG" "$BACKUP"
  info "existing config moved to $BACKUP"
  # Plugin and state directories belong to the old config; leaving them behind
  # makes lazy.nvim try to reconcile two different plugin sets.
  for dir in "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
    [ -d "$dir" ] && mv "$dir" "$dir.bak.$(date +%Y%m%d%H%M%S)"
  done
fi

git clone --depth 1 https://github.com/LazyVim/starter "$NVIM_CONFIG"
rm -rf "$NVIM_CONFIG/.git"
info "cloned"

# ---------------------------------------------------------------------------
step "6/8  Our configuration"

mkdir -p "$NVIM_CONFIG/lua/config" "$NVIM_CONFIG/lua/plugins"

cat > "$NVIM_CONFIG/lua/config/options.lua" <<'LUA'
-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Absolute line numbers. LazyVim turns on relativenumber by default, which
-- renumbers every line as a distance from the cursor instead of its real
-- position in the file.
vim.opt.relativenumber = false
LUA

cat > "$NVIM_CONFIG/lua/plugins/explorer.lua" <<'LUA'
-- LazyVim's explorer is the snacks picker, not neo-tree. `<leader>e` maps to
-- "Explorer Snacks (root dir)", so neo-tree options never reach the tree on
-- screen. The explorer source inherits `hidden`/`ignored` from the files
-- picker, and both default to false.

-- Typing in the picker input re-runs `fd` and rebuilds the tree from the
-- matches, which expands directories that were never opened. These actions
-- search the in-memory item list instead and only move the cursor, so the tree
-- stays exactly as it was. Native `/` cannot do this: the list buffer is
-- virtualized and holds only the on-screen window (21 lines for 51 items), so
-- vim's search would silently skip everything scrolled out of view.
local last_pattern = nil

-- Matches the basename, which is the text the tree actually displays, and
-- follows vim's smartcase: an uppercase character makes the search sensitive.
local function matches(item, pattern)
  local name = vim.fn.fnamemodify(item.file or "", ":t")
  if pattern:lower() == pattern then
    return name:lower():find(pattern, 1, true) ~= nil
  end
  return name:find(pattern, 1, true) ~= nil
end

-- Walks the whole list from the cursor, wrapping once, and returns the index
-- of the next match in `step` direction.
local function find_match(picker, pattern, step)
  local total = picker.list:count()
  if total == 0 then
    return nil
  end
  local from = picker.list.cursor or 1
  for offset = 1, total do
    local index = ((from - 1 + step * offset) % total) + 1
    local item = picker.list:get(index)
    if item and matches(item, pattern) then
      return index
    end
  end
  return nil
end

local function jump(picker, pattern, step)
  if not pattern or pattern == "" then
    return
  end
  last_pattern = pattern
  local index = find_match(picker, pattern, step)
  if index then
    picker.list:move(index, true)
  else
    Snacks.notify.warn("No tree entry matching " .. vim.inspect(pattern))
  end
end

return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          explorer = {
            hidden = true,
            ignored = true,
            actions = {
              tree_search = function(picker)
                jump(picker, vim.fn.input("/"), 1)
              end,
              tree_search_next = function(picker)
                jump(picker, last_pattern, 1)
              end,
              tree_search_prev = function(picker)
                jump(picker, last_pattern, -1)
              end,
            },
            win = {
              list = {
                keys = {
                  -- `/` defaults to "toggle_focus", which jumps to the input
                  -- box and starts filtering. `i` still goes there when a real
                  -- filter is what you want.
                  ["/"] = "tree_search",
                  ["n"] = "tree_search_next",
                  ["N"] = "tree_search_prev",
                },
              },
            },
          },
        },
      },
    },
  },
}
LUA

# The extras LazyVim loads on startup. lang.go is deliberately absent: it pulls
# gopls, gofumpt and goimports through mason, all of which need a Go toolchain
# and fail loudly on every launch without one.
cat > "$NVIM_CONFIG/lazyvim.json" <<'JSON'
{
  "extras": [
    "lazyvim.plugins.extras.coding.luasnip",
    "lazyvim.plugins.extras.coding.mini-comment",
    "lazyvim.plugins.extras.coding.mini-snippets",
    "lazyvim.plugins.extras.editor.fzf",
    "lazyvim.plugins.extras.editor.telescope",
    "lazyvim.plugins.extras.lang.ansible",
    "lazyvim.plugins.extras.lang.docker",
    "lazyvim.plugins.extras.lang.git",
    "lazyvim.plugins.extras.lang.java",
    "lazyvim.plugins.extras.lang.json",
    "lazyvim.plugins.extras.lang.kotlin",
    "lazyvim.plugins.extras.lang.markdown",
    "lazyvim.plugins.extras.lang.python",
    "lazyvim.plugins.extras.lang.ruby",
    "lazyvim.plugins.extras.lang.rust",
    "lazyvim.plugins.extras.lang.sql",
    "lazyvim.plugins.extras.lang.tailwind",
    "lazyvim.plugins.extras.lang.typescript",
    "lazyvim.plugins.extras.lang.vue",
    "lazyvim.plugins.extras.lang.yaml"
  ],
  "install_version": 8,
  "news": {
    "NEWS.md": "11866"
  },
  "version": 8
}
JSON

info "options.lua, plugins/explorer.lua, lazyvim.json"

# ---------------------------------------------------------------------------
step "7/8  Terminal font"

# The font has to be selected by the terminal emulator; Neovim only draws with
# whatever glyphs the terminal hands it.
TERMINATOR_CONFIG="$HOME/.config/terminator/config"
if ! command -v terminator >/dev/null 2>&1; then
  info "terminator not installed - set your terminal's font to 'JetBrainsMono Nerd Font Mono' manually"
elif grep -q "JetBrainsMono Nerd Font" "$TERMINATOR_CONFIG" 2>/dev/null; then
  info "terminator already configured"
else
  mkdir -p "$(dirname "$TERMINATOR_CONFIG")"
  if [ -f "$TERMINATOR_CONFIG" ]; then
    cp "$TERMINATOR_CONFIG" "$TERMINATOR_CONFIG.bak.$(date +%Y%m%d%H%M%S)"
    # Insert into the default profile only. The [layouts] section has a block
    # with the same [[default]] heading, and a font key there does nothing.
    awk '
      /^\[profiles\]/ { in_profiles = 1 }
      /^\[[^[]/ && !/^\[profiles\]/ { in_profiles = 0 }
      { print }
      in_profiles && /^  \[\[default\]\]$/ {
        print "    use_system_font = False"
        print "    font = JetBrainsMono Nerd Font Mono 11"
      }
    ' "$TERMINATOR_CONFIG.bak."* > "$TERMINATOR_CONFIG"
  else
    cat > "$TERMINATOR_CONFIG" <<'CFG'
[global_config]
[keybindings]
[profiles]
  [[default]]
    use_system_font = False
    font = JetBrainsMono Nerd Font Mono 11
[layouts]
[plugins]
CFG
  fi
  info "terminator profile set - restart terminator fully for it to apply"
fi

# ---------------------------------------------------------------------------
step "8/8  Install plugins"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    if ! grep -qs 'HOME/.local/bin' "$HOME/.bashrc"; then
      printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
      info "added ~/.local/bin to PATH in ~/.bashrc"
    fi
    export PATH="$BIN_DIR:$PATH"
    ;;
esac

info "this clones every plugin and may take a few minutes"
SYNC_LOG="$WORK_DIR/lazy-sync.log"
if "$BIN_DIR/nvim" --headless "+Lazy! sync" +qa >"$SYNC_LOG" 2>&1; then
  info "$(find "$HOME/.local/share/nvim/lazy" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l) plugins installed"
else
  warn "plugin sync failed. Last lines:"
  tail -10 "$SYNC_LOG" | sed 's/^/    /'
  warn "Open nvim and run :Lazy sync to retry."
fi

# ---------------------------------------------------------------------------
printf "\n\033[1;32mDone.\033[0m\n\n"
echo "  Restart your terminal, then run: nvim"
echo
echo "  Language servers install themselves through mason the first time you"
echo "  open a matching file. Run :checkhealth if something looks off."
echo

if command -v rbenv >/dev/null 2>&1 && [ "$(rbenv global 2>/dev/null)" = "system" ]; then
  warn "rbenv global is 'system'. mason spawns gem from its own directory, so"
  warn "rubocop and ruby-lsp will fail to install unless a real version is set:"
  warn "  rbenv global \$(rbenv versions --bare | tail -1) && rbenv rehash"
fi
