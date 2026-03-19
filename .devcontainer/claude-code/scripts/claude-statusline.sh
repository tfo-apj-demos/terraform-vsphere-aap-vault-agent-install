#!/usr/bin/env bash
# ┌─────────────────────────────────────────────────────────────────────┐
# │  CLAUDE CODE STATUSLINE                                             │
# │  Powerline statusline with themes and worktree awareness           │
# │                                                                     │
# │  Requires: bash, jq, git, bc, powerline-patched font              │
# │                                                                     │
# │  Settings (~/.claude/settings.json):                                │
# │    {                                                                │
# │      "statusLine": {                                                │
# │        "type": "command",                                           │
# │        "command": "~/.claude/statusline.sh",                        │
# │        "padding": 0                                                 │
# │      }                                                              │
# │    }                                                                │
# │                                                                     │
# │  Env:                                                               │
# │    CLAUDE_SL_THEME=instrument  Theme (see below)                    │
# │    CLAUDE_SL_LINES=2           1=single-line  2=with context bar    │
# │    CLAUDE_SL_MINIMAL=1         Strip to essentials                  │
# │                                                                     │
# │  Themes:                                                            │
# │    tokyo       Deep indigo, neon violet + cyan accents (default)   │
# │    instrument  Dark tonal base, context as vivid signal            │
# │    ember       Warm charcoal, copper + amber tones                 │
# │    frost       Arctic navy, icy whites + sharp blues               │
# │    mono        Pure grayscale — context is the only color          │
# └─────────────────────────────────────────────────────────────────────┘

set -euo pipefail

input=$(cat)

# ── Config ────────────────────────────────────────────────────────────
THEME="${CLAUDE_SL_THEME:-tokyo}"
MULTILINE="${CLAUDE_SL_LINES:-2}"
MINIMAL="${CLAUDE_SL_MINIMAL:-0}"
CTX_WARN=50
CTX_CRIT=70
BAR_WIDTH=32

# ── Glyphs ────────────────────────────────────────────────────────────
SEP=""
BLOCK_FULL="█" BLOCK_7="▉" BLOCK_6="▊" BLOCK_5="▋"
BLOCK_4="▌" BLOCK_3="▍" BLOCK_2="▎" BLOCK_1="▏"
BAR_EMPTY_CH="░"

RST='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Helper: rgb to ANSI escape
bg() { printf '\033[48;2;%s;%s;%sm' "$1" "$2" "$3"; }
fg() { printf '\033[38;2;%s;%s;%sm' "$1" "$2" "$3"; }

# ══════════════════════════════════════════════════════════════════════
# ── THEMES                                                           ──
# ══════════════════════════════════════════════════════════════════════
#
#   Each theme sets bg/fg/arrow for every segment. Themes only
#   touch color — layout, data, and logic are shared.
#
#   To create a custom theme: copy any theme_* function, rename it,
#   and adjust the RGB values. Add your theme name to the case block.

theme_instrument() {
  # Dark tonal base with visible character.
  # Context is the vivid signal; cost gets warm gold.
  dir_bg=$(bg 24 28 42);     dir_fg=$(fg 165 178 210);   dir_arrow=$(fg 24 28 42)
  git_bg=$(bg 30 27 46);     git_fg=$(fg 175 165 210);   git_arrow=$(fg 30 27 46)
  wt_fg=$(fg 65 215 250)
  mdl_bg=$(bg 22 34 40);     mdl_fg=$(fg 140 200 200);   mdl_arrow=$(fg 22 34 40)
  cost_bg=$(bg 34 30 20);    cost_fg=$(fg 235 200 105);   cost_arrow=$(fg 34 30 20)
  lines_bg=$(bg 24 32 28);   lines_fg=$(fg 140 195 150); lines_arrow=$(fg 24 32 28)
  dur_bg=$(bg 26 28 38);     dur_fg=$(fg 140 150 185);   dur_arrow=$(fg 26 28 38)

  ctx_g_bg=$(bg 10 50 34);   ctx_g_fg=$(fg 45 250 150);  ctx_g_arrow=$(fg 10 50 34)
  ctx_g_bar=$(fg 40 245 145); ctx_g_pct=$(fg 40 245 145)
  ctx_y_bg=$(bg 56 44 8);    ctx_y_fg=$(fg 255 215 45);  ctx_y_arrow=$(fg 56 44 8)
  ctx_y_bar=$(fg 250 210 40); ctx_y_pct=$(fg 250 210 40)
  ctx_r_bg=$(bg 62 14 14);   ctx_r_fg=$(fg 255 80 65);   ctx_r_arrow=$(fg 62 14 14)
  ctx_r_bar=$(fg 250 75 60);  ctx_r_pct=$(fg 250 75 60)

  bar_label=$(fg 55 60 80);   bar_empty=$(fg 28 30 40)
}

theme_tokyo() {
  # Deep indigo base. Neon violet for git, electric cyan for model,
  # hot magenta-pink for context signal at critical. Inspired by
  # Tokyo city lights on wet pavement.
  dir_bg=$(bg 22 22 42);     dir_fg=$(fg 150 155 200);   dir_arrow=$(fg 22 22 42)
  git_bg=$(bg 32 22 52);     git_fg=$(fg 190 160 240);   git_arrow=$(fg 32 22 52)
  wt_fg=$(fg 80 220 255)
  mdl_bg=$(bg 18 30 48);     mdl_fg=$(fg 100 195 240);   mdl_arrow=$(fg 18 30 48)
  cost_bg=$(bg 36 28 22);    cost_fg=$(fg 240 195 110);   cost_arrow=$(fg 36 28 22)
  lines_bg=$(bg 22 32 30);   lines_fg=$(fg 130 210 170); lines_arrow=$(fg 22 32 30)
  dur_bg=$(bg 24 24 38);     dur_fg=$(fg 130 135 175);   dur_arrow=$(fg 24 24 38)

  ctx_g_bg=$(bg 12 44 40);   ctx_g_fg=$(fg 55 240 180);  ctx_g_arrow=$(fg 12 44 40)
  ctx_g_bar=$(fg 50 235 175); ctx_g_pct=$(fg 50 235 175)
  ctx_y_bg=$(bg 50 40 12);   ctx_y_fg=$(fg 255 220 60);  ctx_y_arrow=$(fg 50 40 12)
  ctx_y_bar=$(fg 250 215 55); ctx_y_pct=$(fg 250 215 55)
  ctx_r_bg=$(bg 55 12 32);   ctx_r_fg=$(fg 255 70 120);  ctx_r_arrow=$(fg 55 12 32)
  ctx_r_bar=$(fg 250 65 115); ctx_r_pct=$(fg 250 65 115)

  bar_label=$(fg 48 48 72);   bar_empty=$(fg 26 26 38)
}

theme_ember() {
  # Warm charcoal base. Copper and amber foregrounds. The whole
  # strip feels like forged metal. Context burns from warm green
  # through gold to deep red — like a temperature gauge.
  dir_bg=$(bg 32 26 22);     dir_fg=$(fg 195 170 145);   dir_arrow=$(fg 32 26 22)
  git_bg=$(bg 36 28 24);     git_fg=$(fg 210 175 140);   git_arrow=$(fg 36 28 24)
  wt_fg=$(fg 100 210 230)
  mdl_bg=$(bg 30 28 22);     mdl_fg=$(fg 200 180 140);   mdl_arrow=$(fg 30 28 22)
  cost_bg=$(bg 40 30 16);    cost_fg=$(fg 245 200 90);    cost_arrow=$(fg 40 30 16)
  lines_bg=$(bg 28 30 22);   lines_fg=$(fg 170 195 130); lines_arrow=$(fg 28 30 22)
  dur_bg=$(bg 30 28 26);     dur_fg=$(fg 170 158 145);   dur_arrow=$(fg 30 28 26)

  ctx_g_bg=$(bg 18 44 24);   ctx_g_fg=$(fg 80 235 110);  ctx_g_arrow=$(fg 18 44 24)
  ctx_g_bar=$(fg 75 230 105); ctx_g_pct=$(fg 75 230 105)
  ctx_y_bg=$(bg 60 42 8);    ctx_y_fg=$(fg 255 200 40);  ctx_y_arrow=$(fg 60 42 8)
  ctx_y_bar=$(fg 250 195 35); ctx_y_pct=$(fg 250 195 35)
  ctx_r_bg=$(bg 60 16 10);   ctx_r_fg=$(fg 250 85 50);   ctx_r_arrow=$(fg 60 16 10)
  ctx_r_bar=$(fg 245 80 45);  ctx_r_pct=$(fg 245 80 45)

  bar_label=$(fg 60 52 42);   bar_empty=$(fg 32 28 24)
}

theme_frost() {
  # Arctic navy base. Icy white and sharp blue foregrounds. Clean
  # and clinical — like a cockpit at altitude. Context signals
  # are pure and saturated against the cold backdrop.
  dir_bg=$(bg 16 22 36);     dir_fg=$(fg 175 195 225);   dir_arrow=$(fg 16 22 36)
  git_bg=$(bg 18 24 40);     git_fg=$(fg 160 185 230);   git_arrow=$(fg 18 24 40)
  wt_fg=$(fg 80 225 255)
  mdl_bg=$(bg 14 26 38);     mdl_fg=$(fg 140 200 235);   mdl_arrow=$(fg 14 26 38)
  cost_bg=$(bg 28 28 22);    cost_fg=$(fg 225 205 130);   cost_arrow=$(fg 28 28 22)
  lines_bg=$(bg 16 28 28);   lines_fg=$(fg 140 210 195); lines_arrow=$(fg 16 28 28)
  dur_bg=$(bg 18 22 34);     dur_fg=$(fg 150 165 200);   dur_arrow=$(fg 18 22 34)

  ctx_g_bg=$(bg 8 46 36);    ctx_g_fg=$(fg 40 255 170);  ctx_g_arrow=$(fg 8 46 36)
  ctx_g_bar=$(fg 35 250 165); ctx_g_pct=$(fg 35 250 165)
  ctx_y_bg=$(bg 52 42 6);    ctx_y_fg=$(fg 255 225 50);  ctx_y_arrow=$(fg 52 42 6)
  ctx_y_bar=$(fg 250 220 45); ctx_y_pct=$(fg 250 220 45)
  ctx_r_bg=$(bg 58 12 12);   ctx_r_fg=$(fg 255 75 60);   ctx_r_arrow=$(fg 58 12 12)
  ctx_r_bar=$(fg 250 70 55);  ctx_r_pct=$(fg 250 70 55)

  bar_label=$(fg 40 50 70);   bar_empty=$(fg 20 24 34)
}

theme_mono() {
  # Pure grayscale for all base segments. Context is the ONLY
  # color — when it appears, it's startling. Maximum signal-to-
  # noise ratio. For the minimalist who wants just the facts.
  dir_bg=$(bg 26 26 28);     dir_fg=$(fg 170 170 175);   dir_arrow=$(fg 26 26 28)
  git_bg=$(bg 30 30 32);     git_fg=$(fg 165 165 170);   git_arrow=$(fg 30 30 32)
  wt_fg=$(fg 80 200 240)
  mdl_bg=$(bg 24 24 26);     mdl_fg=$(fg 155 155 162);   mdl_arrow=$(fg 24 24 26)
  cost_bg=$(bg 32 30 28);    cost_fg=$(fg 210 195 155);   cost_arrow=$(fg 32 30 28)
  lines_bg=$(bg 28 28 28);   lines_fg=$(fg 160 165 158); lines_arrow=$(fg 28 28 28)
  dur_bg=$(bg 24 24 26);     dur_fg=$(fg 130 130 138);   dur_arrow=$(fg 24 24 26)

  ctx_g_bg=$(bg 10 48 32);   ctx_g_fg=$(fg 50 245 145);  ctx_g_arrow=$(fg 10 48 32)
  ctx_g_bar=$(fg 45 240 140); ctx_g_pct=$(fg 45 240 140)
  ctx_y_bg=$(bg 54 42 8);    ctx_y_fg=$(fg 255 212 42);  ctx_y_arrow=$(fg 54 42 8)
  ctx_y_bar=$(fg 250 208 38); ctx_y_pct=$(fg 250 208 38)
  ctx_r_bg=$(bg 60 12 12);   ctx_r_fg=$(fg 255 72 58);   ctx_r_arrow=$(fg 60 12 12)
  ctx_r_bar=$(fg 250 68 54);  ctx_r_pct=$(fg 250 68 54)

  bar_label=$(fg 50 50 55);   bar_empty=$(fg 26 26 28)
}

# ── Load theme ────────────────────────────────────────────────────────
case "$THEME" in
  instrument) theme_instrument ;;
  tokyo)      theme_tokyo ;;
  ember)      theme_ember ;;
  frost)      theme_frost ;;
  mono)       theme_mono ;;
  *)          theme_tokyo ;;
esac

# ══════════════════════════════════════════════════════════════════════
# ── EXTRACT DATA                                                     ──
# ══════════════════════════════════════════════════════════════════════

MODEL=$(echo "$input" | jq -r '.model.display_name // "--"')
MODEL_ID=$(echo "$input" | jq -r '.model.id // ""')
CWD=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
PROJECT_DIR=$(echo "$input" | jq -r '.workspace.project_dir // ""')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
LINES_ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

CTX_PCT=$(echo "$input" | jq -r '
  if .context_window.used_percentage then .context_window.used_percentage
  elif .used_percentage then .used_percentage
  else 0 end | round
')

CTX_USED=$(echo "$input" | jq -r '
  if .context_window.used then .context_window.used
  elif .used_tokens then .used_tokens
  else 0 end
')

CTX_TOTAL=$(echo "$input" | jq -r '
  if .context_window.total then .context_window.total
  elif .total_tokens then .total_tokens
  elif .context_window.max then .context_window.max
  else 0 end
')

# Format tokens: 1500 → "1.5k", 200000 → "200k"
fmt_tokens() {
  local n=$1
  if [ "$n" -ge 1000000 ] 2>/dev/null; then
    printf '%.1fM' "$(echo "scale=1; $n / 1000000" | bc 2>/dev/null)"
  elif [ "$n" -ge 1000 ] 2>/dev/null; then
    local k=$(( n / 1000 ))
    local r=$(( (n % 1000) / 100 ))
    if [ "$r" -gt 0 ]; then printf '%s.%sk' "$k" "$r"
    else printf '%sk' "$k"; fi
  elif [ "$n" -gt 0 ] 2>/dev/null; then
    printf '%s' "$n"
  else
    printf ''
  fi
}

CTX_USED_FMT=$(fmt_tokens "$CTX_USED")
CTX_TOTAL_FMT=$(fmt_tokens "$CTX_TOTAL")

# Build context display: "58% 45k/200k" or just "58%" if no token data
if [ -n "$CTX_USED_FMT" ] && [ -n "$CTX_TOTAL_FMT" ]; then
  CTX_TOKENS="${CTX_USED_FMT}/${CTX_TOTAL_FMT}"
else
  CTX_TOKENS=""
fi

# ── Derived ───────────────────────────────────────────────────────────

if [ -n "$PROJECT_DIR" ] && [ -n "$CWD" ] && [ "$CWD" != "$PROJECT_DIR" ]; then
  DISPLAY_DIR="${CWD#"$PROJECT_DIR"/}"
else
  DISPLAY_DIR="${CWD##*/}"
fi
[ "${#DISPLAY_DIR}" -gt 32 ] && DISPLAY_DIR="…${DISPLAY_DIR: -31}"

if [ "$DURATION_MS" -gt 0 ] 2>/dev/null; then
  TS=$((DURATION_MS / 1000))
  DH=$((TS / 3600)); DM=$(( (TS % 3600) / 60 )); DS=$((TS % 60))
  if [ "$DH" -gt 0 ]; then DURATION="${DH}h${DM}m"
  elif [ "$DM" -gt 0 ]; then DURATION="${DM}m${DS}s"
  else DURATION="${DS}s"; fi
else
  DURATION="0s"
fi

if [ "$(echo "$COST > 0" | bc 2>/dev/null || echo 0)" = "1" ]; then
  COST_FMT=$(printf '$%.2f' "$COST")
else
  COST_FMT='$0.00'
fi

BURN_FMT=""
if [ "$DURATION_MS" -gt 120000 ] 2>/dev/null; then
  HOURS=$(echo "scale=4; $DURATION_MS / 3600000" | bc 2>/dev/null || echo "0")
  if [ "$(echo "$HOURS > 0" | bc 2>/dev/null || echo 0)" = "1" ]; then
    BURN=$(echo "scale=2; $COST / $HOURS" | bc 2>/dev/null || echo "0")
    BURN_FMT=$(printf '$%s/h' "$BURN")
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# ── GIT                                                              ──
# ══════════════════════════════════════════════════════════════════════

GIT_BRANCH="" GIT_STAGED=0 GIT_UNSTAGED=0 GIT_UNTRACKED=0
GIT_AHEAD=0 GIT_BEHIND=0 GIT_WORKTREE="" IS_WORKTREE=false HAS_GIT=false

if git rev-parse --git-dir > /dev/null 2>&1; then
  HAS_GIT=true
  GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")

  GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
  GIT_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
  GIT_COMMON=$(git rev-parse --git-common-dir 2>/dev/null || echo "")
  if [ -n "$GIT_COMMON" ] && [ "$GIT_DIR" != "$GIT_COMMON" ]; then
    IS_WORKTREE=true
    GIT_WORKTREE="${GIT_TOPLEVEL##*/}"
  fi

  [ "${#GIT_BRANCH}" -gt 18 ] && GIT_BRANCH="${GIT_BRANCH:0:17}…"

  GIT_STAGED=$(git --no-optional-locks diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
  GIT_UNSTAGED=$(git --no-optional-locks diff --numstat 2>/dev/null | wc -l | tr -d ' ')
  GIT_UNTRACKED=$(git --no-optional-locks ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

  UPSTREAM=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo "")
  if [ -n "$UPSTREAM" ]; then
    GIT_AHEAD=$(git rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
    GIT_BEHIND=$(git rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo 0)
  fi
fi

GIT_CONTENT=""
if [ "$HAS_GIT" = true ]; then
  GIT_CONTENT="$GIT_BRANCH"

  if [ "$IS_WORKTREE" = true ] && [ -n "$GIT_WORKTREE" ]; then
    GIT_CONTENT="${GIT_CONTENT}${RST}${git_bg} ${wt_fg}⊕${GIT_WORKTREE}${RST}${git_bg}${git_fg}"
  fi

  D=""
  [ "$GIT_STAGED" -gt 0 ]    && D="${D}+${GIT_STAGED} "
  [ "$GIT_UNSTAGED" -gt 0 ]  && D="${D}~${GIT_UNSTAGED} "
  [ "$GIT_UNTRACKED" -gt 0 ] && D="${D}?${GIT_UNTRACKED} "
  [ "$GIT_AHEAD" -gt 0 ]     && D="${D}↑${GIT_AHEAD} "
  [ "$GIT_BEHIND" -gt 0 ]    && D="${D}↓${GIT_BEHIND} "
  D="${D% }"

  [ -n "$D" ] && GIT_CONTENT="${GIT_CONTENT} ${DIM}${D}${RST}${git_bg}${git_fg}"
fi

# ── Context state ─────────────────────────────────────────────────────

if [ "$CTX_PCT" -gt "$CTX_CRIT" ]; then
  c_bg="$ctx_r_bg" c_fg="$ctx_r_fg" c_arrow="$ctx_r_arrow"
  c_bar="$ctx_r_bar" c_pct="$ctx_r_pct"
elif [ "$CTX_PCT" -gt "$CTX_WARN" ]; then
  c_bg="$ctx_y_bg" c_fg="$ctx_y_fg" c_arrow="$ctx_y_arrow"
  c_bar="$ctx_y_bar" c_pct="$ctx_y_pct"
else
  c_bg="$ctx_g_bg" c_fg="$ctx_g_fg" c_arrow="$ctx_g_arrow"
  c_bar="$ctx_g_bar" c_pct="$ctx_g_pct"
fi

# ══════════════════════════════════════════════════════════════════════
# ── CONTEXT BAR                                                      ──
# ══════════════════════════════════════════════════════════════════════

build_bar() {
  local pct=$1 w=$BAR_WIDTH
  local total_steps=$(( w * 8 ))
  local filled_steps=$(( (pct * total_steps) / 100 ))
  [ "$filled_steps" -gt "$total_steps" ] && filled_steps=$total_steps
  [ "$filled_steps" -lt 0 ] && filled_steps=0

  local full_blocks=$(( filled_steps / 8 ))
  local remainder=$(( filled_steps % 8 ))
  local empty_blocks=$(( w - full_blocks - (remainder > 0 ? 1 : 0) ))

  local bar=""

  if [ "$full_blocks" -gt 0 ]; then
    bar="${c_bar}"
    for ((i=0; i<full_blocks; i++)); do bar="${bar}${BLOCK_FULL}"; done
  fi

  if [ "$remainder" -gt 0 ]; then
    bar="${bar}${c_bar}"
    case "$remainder" in
      7) bar="${bar}${BLOCK_7}" ;; 6) bar="${bar}${BLOCK_6}" ;;
      5) bar="${bar}${BLOCK_5}" ;; 4) bar="${bar}${BLOCK_4}" ;;
      3) bar="${bar}${BLOCK_3}" ;; 2) bar="${bar}${BLOCK_2}" ;;
      1) bar="${bar}${BLOCK_1}" ;;
    esac
  fi

  if [ "$empty_blocks" -gt 0 ]; then
    bar="${bar}${bar_empty}"
    for ((i=0; i<empty_blocks; i++)); do bar="${bar}${BAR_EMPTY_CH}"; done
  fi

  local tokens="$2"
  local tokens_suffix=""
  [ -n "$tokens" ] && tokens_suffix=" ${bar_label}${tokens}"

  printf '%b %b%b %b%b' "${bar_label}ctx${RST}" "$bar" "${RST}" "${c_pct}${BOLD}${pct}%${RST}" "${tokens_suffix}${RST}"
}
}

# ══════════════════════════════════════════════════════════════════════
# ── ASSEMBLE                                                         ──
# ══════════════════════════════════════════════════════════════════════

OUT=""
PREV_ARROW=""
FIRST=true

seg() {
  local text="$1" bg="$2" fg="$3" arrow="$4"
  if [ "$FIRST" = true ]; then
    OUT="${OUT}${bg}${fg} ${text} "
    FIRST=false
  else
    OUT="${OUT}${bg}${PREV_ARROW}${SEP}${fg} ${text} "
  fi
  PREV_ARROW="$arrow"
}

seg "${DISPLAY_DIR}" "$dir_bg" "$dir_fg" "$dir_arrow"

if [ "$HAS_GIT" = true ]; then
  seg "${GIT_CONTENT}" "$git_bg" "$git_fg" "$git_arrow"
fi

seg "${MODEL}" "$mdl_bg" "$mdl_fg" "$mdl_arrow"

# 4. Context — shown on bar in multiline mode, inline in single-line mode
if [ "$MULTILINE" != "2" ]; then
  CTX_DISPLAY="${CTX_PCT}%"
  if [ -n "$CTX_TOKENS" ]; then
    CTX_DISPLAY="${CTX_PCT}% ${DIM}${CTX_TOKENS}${RST}${c_bg}${BOLD}${c_fg}"
  fi
  seg "${CTX_DISPLAY}" "$c_bg" "${BOLD}${c_fg}" "$c_arrow"
fi

COST_TEXT="${COST_FMT}"
[ -n "$BURN_FMT" ] && COST_TEXT="${COST_TEXT} ${DIM}${BURN_FMT}${RST}${cost_bg}${cost_fg}"
seg "${COST_TEXT}" "$cost_bg" "$cost_fg" "$cost_arrow"

if [ "$MINIMAL" != "1" ] && { [ "$LINES_ADDED" -gt 0 ] || [ "$LINES_REMOVED" -gt 0 ]; }; then
  seg "+${LINES_ADDED} −${LINES_REMOVED}" "$lines_bg" "$lines_fg" "$lines_arrow"
fi

if [ "$MINIMAL" != "1" ]; then
  seg "${DURATION}" "$dur_bg" "$dur_fg" "$dur_arrow"
fi

OUT="${OUT}${RST}${PREV_ARROW}${SEP}${RST}"

if [ "$MULTILINE" = "2" ]; then
  LINE2=$(build_bar "$CTX_PCT" "$CTX_TOKENS")
  printf '%b\n%b' "$OUT" "$LINE2"
else
  printf '%b' "$OUT"
fi
