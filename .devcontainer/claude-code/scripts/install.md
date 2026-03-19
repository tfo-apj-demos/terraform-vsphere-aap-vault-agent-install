# Install

### 01 — Copy the script

```bash
cp claude-statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

### 02 — Add to `~/.claude/settings.json`

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 0
  }
}
```

### 03 — Choose a theme

```bash
# In your shell profile (.bashrc, .zshrc, etc.)
export CLAUDE_SL_THEME=tokyo       # default — neon indigo + violet
export CLAUDE_SL_THEME=instrument  # tonal dark base
export CLAUDE_SL_THEME=ember       # warm charcoal + copper
export CLAUDE_SL_THEME=frost       # arctic navy + icy blue
export CLAUDE_SL_THEME=mono        # grayscale, context only color
```

### 04 — Restart Claude Code

Requires a powerline-patched font.

**deps:** `jq` · `git` · `bc`
