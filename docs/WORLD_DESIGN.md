# World Design Document

Status: **ENTWURF**
Verantwortlich: Agent 03 (World Design)

## Prinzip

Mittelgroß, dicht, interessant. Gebiete werden **erst gebaut, wenn die vorherigen Systeme stabil sind.**

## Gebiete (Reihenfolge der Erschließung)

| Gebiet | Funktion | Phase |
|---|---|---|
| 🪦 Friedhof | Hub, Kern-Loop | 1–3 |
| 🏘 Dorf | Händler, Quests, Leichenquelle | 7 |
| 🌲 Wald | Holz, Kräuter, Geheimnisse | 11 |
| ⛏️ Mine / Steinbruch | Stein für Grabsteine | 11 |
| 🏚 Sumpf | Seltene Ressourcen, Gefahr | 11 |
| ⛪️ Kirche | Segen, Story | 7 / 11 |
| 💀 Krypten | Unter dem Friedhof | 12 |
| 🕯 Untergrund | Nekromantie, Auferstehung | 13 |
| ⚔️ Dungeons | Kampf | 16 |
| 🌑 Endgame | später | – |

## Vertical-Slice-Welt

- **Friedhof** (ca. 40 × 40 m): Eingangstor, 10–15 Grabplätze, Totengräberhütte/Leichenhalle, Werkbank, Baum, Weg.
- **Angrenzender Bereich:** Waldrand oder Feldweg Richtung Dorf (Ankunftsort der Leichen, NPC-Weg).
- Grab-Raster 1 × 2 m, Wege ≥ 1,5 m breit (Navigation, Lesbarkeit).

## Phase-3-Welt – Friedhof vollständig (W-Welt, Vertrag `docs/PHASE3_DESIGN.md` §4)

Quelle der Wahrheit: `data/world/graveyard_layout.json` (Builder `src/world/graveyard/graveyard_builder.gd` + `graveyard_build_phase3.gd`). Koordinaten Godot: x = Osten, z = Süden (zur Kamera).

```
            z −20 ┌───────── Birkenhang (north) ─────────┐ Zaun z −20, Lücken x 1 / 8, West x −2 Lücke z −16
                  │  Birke   plot_10 plot_11 plot_12  Birke│
   (Hütte) z −12 ─┴──Zaun──[Dornenhecke x 2,5…6,5]──Zaun──┼──────── Ostwiese (east) ────────┐ Zaun z −12, Lücke x 17
                  │                                        │ plot_07  plot_08  plot_09       │
                  │          Alter Hof (yard)            Durchgang x 11,5 / z −1…−3,4        │ Zaun x 21,5, Lücken z ±4
                  │  plot_01–03 · alte Gräber · plot_04–06 │ (anfangs Brombeere obs_e_01)    │
            z 9,6 └──────────── Tor · Friedhofstafel ──────┴─────────────────────────────────┘
                 x −11,5                                  x 11,5                           x 21,5
```

| Abschnitt | Rechteck (x, z) | Grabstellen | Hindernisse (Start) | Pflegestellen |
|---|---|---|---|---|
| Alter Hof `yard` | −11,5…11,5 · −12…9,6 | `plot_01…06` | – | 12 (4 Laub unter der Eiche), davon 6 zu Beginn Stufe 1–2 |
| Ostwiese `east` | 11,5…21,5 · −12…9,6 | `plot_07…09` (z −7) | 4 Brombeeren, 3 Feldsteinhaufen, 3 Zaunlücken | 5 |
| Birkenhang `north` | −2…11,5 · −20…−12 | `plot_10…12` (z −16,2) | Dornenhecke (Zugang), 3 Brombeeren, 2 Steinhaufen, 2 Baumstümpfe, 3 Zaunlücken | 5 (2 Laub unter Birken) |

- Boden 56 × 64 m (x −24…32, z −29,5…34,5), Süd-/Westkante und Kutschweg unverändert; begehbar x −11,2…21,2, z −20,3…25,2 plus zwei unsichtbare Zusatzwände (hinter der Hütte z −12,5; Wald östlich des Kutschwegs x 11,2). Kamera-Fokus x −7…17, z −16…23.
- Gesperrte Abschnitte tragen **Verwilderung** (`Decor/Overgrowth/<Abschnitt>`: hohe Disteln, Laub, niedrige Büsche) als reine Kulisse; sie verschwindet mit der Freigabe. Unter Hindernissen ist Gras gebacken und über die Gras-Maske ausgeblendet – nach dem Roden erscheint es.
- Jede Grabstelle hat eine Pflegestelle `dirt_<plot_id>` auf dem Hügel (Interactable-Priorität 11 > Grab-Info 10).
- Friedhofstafel `notice_board` innen am Tor (−1,5, 8,7): Friedhofsstufe + Ruf-Stufe.
- 6 Birken (2 im Birkenhang, 4 dahinter); fünf Hintergrundbäume aus den neuen Abschnitten versetzt.
- Bau-Maske `src/world/graveyard/build_mask.res` (66 × 60 Zellen à 0,5 m) wird beim Welt-Bau gebacken.
- Debug-Teleportziele: Wegpunkte `tp_east` (15,6, −1,0) und `tp_north` (4,5, −14,0).
