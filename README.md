# The Last Gravekeeper

2.5D Fantasy Graveyard Management / Adventure / RPG – Godot 4.7 + Blender.

**Status:** Phase 2 (Vertical Slice) – fertig, wartet auf Freigabe. Siehe [`docs/QUALITY_GATE_STATUS.md`](docs/QUALITY_GATE_STATUS.md).

## Starten
1. Godot **4.7.2** installieren (godotengine.org).
2. Im Projektmanager „Importieren" → `project.godot` in diesem Ordner wählen.
3. **F5** startet das Spiel → Titelbildschirm → **Neues Spiel** (oder **Fortsetzen**).

## Steuerung (Vertical Slice)
| Taste | Aktion |
|---|---|
| **WASD** / Pfeile | Laufen |
| **E** | Interagieren (aufheben, ablegen, untersuchen, graben, bestatten, reden …) |
| **Q** | Getragene Leiche ablegen |
| **I** | Inventar |
| **1–4** | Dialog-Antwort wählen |
| **Esc** | Panel schließen / Pause-Menü (Speichern, Laden) |
| **F5 / F9** | Schnellspeichern / Schnellladen |
| **Mausrad** | Zoom |
| **F1** | Debug-Konsole (nur Debug-Builds; `help` listet alle Befehle) |

## Dokumente
Alle verbindlichen Dokumente liegen in [`docs/`](docs/) – der Vertrag für Phase 2 ist [`docs/VERTICAL_SLICE_DESIGN.md`](docs/VERTICAL_SLICE_DESIGN.md). Arbeitsregeln für KI-Sessions: [`CLAUDE.md`](CLAUDE.md).
Stil-Referenz (Art Style Lock): `src/world/art_prototype/art_prototype.tscn` (direkt öffnen und mit F6 starten).
