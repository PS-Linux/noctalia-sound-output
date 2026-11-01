#!/usr/bin/env bash
# Installs the sound-output bar button for Noctalia.
# Safe to run again: it updates files in place and skips steps already done.
#
#   ./install.sh    install, and put the button where the "volume" widget is
#                   (or before "bluetooth", else at the end of the bar)

set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
BIN_DIR="$HOME/.local/bin"
PLUGIN_ROOT="$HOME/.local/share/noctalia-local-plugins"
PLUGIN_ID="ps/sound-output"
SOURCE_NAME="local"
WIDGET_NAME="sound-output"

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

say "Checking requirements"
for cmd in pactl jq noctalia python3; do
    command -v "$cmd" >/dev/null || die "'$cmd' is not installed"
done
pgrep -x noctalia >/dev/null || die "Noctalia isn't running; start it and run this again"
pactl info >/dev/null 2>&1 || die "can't reach the sound server (is pipewire-pulse running?)"

say "Installing script to $BIN_DIR/sound-output"
install -Dm755 "$HERE/bin/sound-output" "$BIN_DIR/sound-output"

say "Installing Noctalia plugin to $PLUGIN_ROOT/sound-output"
mkdir -p "$PLUGIN_ROOT/sound-output"
cp "$HERE"/noctalia-plugin/sound-output/* "$PLUGIN_ROOT/sound-output/"

# Capture first: `cmd | grep -q` under pipefail fails when grep exits early.
SOURCES=$(noctalia msg plugins source list 2>/dev/null || true)
PLUGINS=$(noctalia msg plugins list 2>/dev/null || true)

if grep -qF "$PLUGIN_ROOT" <<<"$SOURCES"; then
    say "Plugin source already registered"
else
    say "Registering plugin source '$SOURCE_NAME'"
    noctalia msg plugins source add "$SOURCE_NAME" path "$PLUGIN_ROOT" >/dev/null
    sleep 1
fi

if grep -qE "^$PLUGIN_ID .* enabled" <<<"$PLUGINS"; then
    # Already on: toggle it so Noctalia picks up updated files.
    say "Reloading plugin"
    noctalia msg plugins disable "$PLUGIN_ID" >/dev/null
    sleep 0.5
fi
say "Enabling plugin $PLUGIN_ID"
noctalia msg plugins enable "$PLUGIN_ID" >/dev/null
sleep 1

say "Adding the button to the bar"
noctalia msg config-set "widget.$WIDGET_NAME.type" "\"$PLUGIN_ID:button\"" >/dev/null

# Work out the new widget list for the first enabled bar: swap the built-in
# "volume" widget for the button, keeping everything else as is. Read the
# "full" export: the plain one leaves out sections still at their built-in
# defaults, and writing one of those would replace it.
read -r BAR_PATH NEW_LIST < <(noctalia config export full | python3 -c '
import sys, tomllib, json
cfg = tomllib.loads(sys.stdin.read())
widget = sys.argv[1]
bars = cfg.get("bar", {})
order = bars.get("order") or [k for k, v in bars.items() if isinstance(v, dict)]
names = [n for n in order if isinstance(bars.get(n), dict) and bars[n].get("enabled", True)]
if not names:
    sys.exit("no enabled bar in the Noctalia config")
name = names[0]
bar = bars[name]
sections = ("end", "center", "start")
section = next((k for k in sections if widget in bar.get(k, [])), None) or \
          next((k for k in sections if "volume" in bar.get(k, [])), None) or \
          next((k for k in sections if bar.get(k)), "end")
items = list(bar.get(section, []))
if widget not in items:
    if "volume" in items:
        items[items.index("volume")] = widget
    elif "bluetooth" in items:
        items.insert(items.index("bluetooth") + 1, widget)
    else:
        items.append(widget)
print(f"bar.{name}.{section}", json.dumps(items))
' "$WIDGET_NAME")
noctalia msg config-set "$BAR_PATH" "$NEW_LIST" >/dev/null

say "Done. Hover the volume icon in the bar to pick the sound output."
