#!/usr/bin/env bash
# Run Godot with a real (software Vulkan) renderer in a virtual display.
# Needed for the scene builder (MultiMesh data) and for screenshots.
#   GODOT=/path/to/godot tools/godot_run.sh [godot args...]
set -euo pipefail
GODOT="${GODOT:-godot}"
export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/lvp_icd.json}"
cd "$(dirname "$0")/.."
exec xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --audio-driver Dummy --path . "$@"
