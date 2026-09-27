# Asset Guidelines

Status: **VERBINDLICH – ART STYLE LOCK ACTIVE (27.09.2026)**
Alle neuen Assets nutzen `tools/blender/lib_painted.py` (Vertex-Paint-Stil, Palette aus ART_DIRECTION.md §3) und die geteilten Materialien.
Verantwortlich: Agent 04 (Art Director), Agent 05 (Blender), Agent 20 (Integration)

## Pipeline

`art_source/blender/<kategorie>/<name>.blend` → Export glTF 2.0 (.glb) → `assets/models/<kategorie>/<name>.glb` → Godot-Import → Testszene → Integration.
Skriptbasierte Assets: Generator-Script in `tools/blender/` (reproduzierbar, versionierbar).

## Maßstab & Orientierung

| Regel | Wert |
|---|---|
| Einheit | 1 Blender-Unit = 1 m = 1 Godot-Unit |
| Spielerhöhe | ca. 1,7 m (stilisierte Proportionen, siehe Art Direction) |
| Grabplatz (Raster) | 1 × 2 m |
| Vorne | Modell blickt in Blender nach **−Y** → wird in Godot zu **+Z** (`Vector3.MODEL_FRONT`) |
| Up-Achse | Z in Blender, Y in Godot (glTF-Exporter konvertiert) |
| Transform | Vor Export: Apply Scale & Rotation (Scale = 1) |

## Pivot

- Props, Gebäude, Grabsteine, Bäume: **Mitte unten** (Bodenkontakt bei Z = 0).
- Charaktere: zwischen den Füßen am Boden.
- Türen/Tore: an der Scharnierachse.

## Geometrie & Detailgrad (Richtwerte)

| Typ | Dreiecke |
|---|---|
| Kleines Prop / Grabstein | 200 – 1 500 |
| Baum | 2 000 – 6 000 |
| Kleines Gebäude | 3 000 – 10 000 |
| Charakter | 3 000 – 12 000 (freigegebener Totengräber: 3 030 – Ausnahme dokumentiert) |

## Materialien & Texturen

- Wenige geteilte Materialien; bevorzugt **Palette-/Atlas-Texturen** statt vieler Einzeltexturen.
- Texturgröße: Props 512², Gebäude/Charaktere 1024², Ausnahme nur nach Freigabe.
- Formate: PNG in Quelle; Godot komprimiert (VRAM-Compression).
- PBR (Albedo/Roughness/Normal) – Stilisierungsgrad gemäß Art Direction.

## Animation

- Skelett: ein gemeinsames humanoides Rig für Spieler & menschliche NPCs.
- Namensschema Aktionen: `idle`, `walk`, `run`, `interact`, `dig`, `carry_idle`, `carry_walk` …
- 30 FPS in Blender, Root-Motion aus (Bewegung durch Code).

## Dateinamen

`snake_case`, englisch, Kategorie-Präfix:
`prop_gravestone_cross_01`, `bld_morgue_small`, `veg_tree_oak_dead_01`, `chr_gravekeeper`, `tex_ground_grass_albedo`.

## Placeholder

- Placeholder-Assets tragen Präfix **`ph_`** und stehen in der Placeholder-Liste in `QUALITY_GATE_STATUS.md`.
- Ein `ph_`-Asset darf nie ohne ausdrückliche Benutzerfreigabe final werden.

## Lizenz

Nur selbst erstellte oder nachweislich passend lizenzierte Assets (CC0 o. ä., mit Quelle in `assets/LICENSES.md`). Keine Inhalte aus anderen Spielen.
