# Agentenorganisation

20 feste Rollen – **keine** parallel laufenden Prozesse. Der Lead (01) aktiviert pro Aufgabe nur die minimal nötigen Rollen.
Echte Sub-Agents (separate KI-Instanzen) werden nur bei großen, unabhängigen Teilaufgaben gestartet – einfache Aufgaben mit schnelleren Modellen.

| # | Rolle | Kernbereich |
|---|---|---|
| 01 | Lead / Project Director | Architektur, Prioritäten, Quality Gates, Kommunikation |
| 02 | Game Design | Gameplay, Progression, Balancing |
| 03 | World Design | Regionen, Karten, POIs |
| 04 | Art Director | Stil, Palette, Licht, Konsistenz |
| 05 | Blender / 3D Art | Umgebung, Props, Gebäude |
| 06 | Character Art | Spieler, NPCs, Monster |
| 07 | Animation | Alle Animationen |
| 08 | Godot Core | Architektur, Autoloads, Infrastruktur |
| 09 | Player Systems | Bewegung, Interaktion, Inventar |
| 10 | Graveyard System | Gräber, Bestattung, Qualität |
| 11 | Corpse System | Leichen, Zustände, Untersuchung |
| 12 | NPC / AI | Routinen, Beziehungen, Gegner-KI |
| 13 | Quest / Story | Quests, Dialoge, Story |
| 14 | Crafting / Economy | Rezepte, Handel, Preise |
| 15 | Combat / Dungeon | Kampf, Gegner, Bosse |
| 16 | Underground / Resurrection | Krypten, Nekromantie |
| 17 | Audio / Atmosphere | Sound, Musik (nur eigene/lizenzierte) |
| 18 | UI / UX | HUD, Menüs, Spielerführung |
| 19 | QA / Testing | Tests, Regression, Performance – darf Gates auf FAILED setzen |
| 20 | Build / Integration | Git, Builds, Stabilität |

## Aktivierungsplan

| Phase | Aktiv | Grund |
|---|---|---|
| 0 Setup | 01, 08, 19, 20 | Struktur, Architektur, Tests, Git |
| 1 Art Direction | 01, 04, 05, 06, 08, 19 | Stil-Prototyp |
| 2 Vertical Slice | 01, 08, 09, 10, 11, 19, 20 dauerhaft; 03, 04, 05, 07, 12, 13, 14, 18 je Meilenstein | siehe ROADMAP.md |
| Später | 15, 16, 17 erst ab ihren Phasen (Audio evtl. früher für Atmosphäre – nur nach Rückfrage) | |
