# THE LAST GRAVEKEEPER – Arbeitsregeln (Kurzfassung)

Godot 4.7.2 · GDScript (statisch typisiert) · Forward+ · Blender → .glb. Sprache mit dem Benutzer: Deutsch.

## Master-Regel
BAUE → TESTE → ZEIGE → **WARTE AUF FREIGABE**. Keine neue Phase ohne ausdrückliche Benutzerfreigabe.
Kritik des Benutzers = Gate FAILED → ändern, testen, erneut zeigen, warten.

## Single Source of Truth (`docs/`)
GAME_DESIGN_DOCUMENT · ART_DIRECTION · TECHNICAL_ARCHITECTURE · ASSET_GUIDELINES · WORLD_DESIGN · QUALITY_GATE_STATUS · ROADMAP · AGENTS.
Widerspruch → stoppen, Benutzer fragen. Aktuellen Stand immer zuerst in `docs/QUALITY_GATE_STATUS.md` prüfen.

## Regeln
- Nur minimal nötige Agent-Rollen aktivieren (docs/AGENTS.md); keine vollständige Projektanalyse bei kleinen Änderungen.
- Keine geschützten Inhalte anderer Spiele kopieren.
- Spielwerte in `data/` (Resources), nicht im Code. Scripts klein & modular. Kommunikation über `EventBus`.
- Placeholder mit Präfix `ph_`, in Placeholder-Liste eintragen.
- ART STYLE LOCK beachten (Status in QUALITY_GATE_STATUS.md).
- Nach jedem stabilen Meilenstein: Tests grün → Commit.

## Tests
```
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd
```
In der Cloud ist Godot nicht vorinstalliert: Linux-Build von github.com/godotengine/godot/releases (4.7.2-stable) in den Scratch-Ordner laden. Blender headless: `pip install bpy==5.0.1` (Python 3.11) in ein venv.
