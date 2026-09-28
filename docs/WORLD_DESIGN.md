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

## Phase-4-Welt – Holunderwinkel & Nachthändlerin (W-Welt, Vertrag `docs/PHASE4_DESIGN.md` §4)

Quelle: `data/world/graveyard_layout.json`, Builder-Teile `graveyard_build_phase4.gd` (Systemknoten, Holundersträucher, Requisiten, Tür-Zettel) + die Phase-2/3-Helfer (Plots, Hindernisse, Zaun, Pflegestellen). Die freigegebenen Abschnitte I–III sind unverändert.

```
            z −20 ┌──Zaun──[Lücke x −7]──Zaun──┬── Birkenhang ──
                  │ Dickicht  h_01  h_02  h_03 │
     Holunder ─── │          (z −18,35)        │ (bestehender Westzaun des Birkenhangs, x −2)
                  │ Gang x −11,5…−9,6          │
                  │ Dickicht  h_04  h_05  h_06 │
            z −12,5 └[Pförtchen x −10]──Zaun───┘  ← Holunder über dem Pförtchen
                  x −11,5   (Hütte südlich davon)  x −2
  Westmauer x −11,5, z −5…−1: außen Ilses Platz trader_spot (−12,1 | −2,6), Mauerstein (−12,0 | −2,9)
  Weg: trader_far (−22 | −14, Waldrand) → trader_mid (−16 | −6) → trader_spot (außerhalb der begehbaren Fläche)
```

| Abschnitt | Rechteck (x, z) | Grabstellen | Hindernisse (Start) | Pflegestellen |
|---|---|---|---|---|
| Holunderwinkel `elder` (Index 4, Flag `has_elder_key`) | −11,5…−2,0 · −20…−12,5 | `h_01…03` (z −18,35), `h_04…06` (z −14,85), x −9,0 / −6,5 / −4,0 | Pförtchen `obs_h_gate`, 2 Holunderdickichte, 6 eingesunkene Gruben (je über der Grabstelle), Zaunlücke `obs_h_gap_1` – 300 Min | 3 (2 Laub unter den Holundern) + 6 Gräber |

- **Abweichung Grabstellen (±0,4 m erlaubt, §4.1):** x um +0,4 m nach Osten (Westgang 1,5 m für Pförtchen und Dickicht), Reihe 1 um −0,35 m, Reihe 2 um −0,25 m nach Norden: Reihenabstand 3,5 m, damit der Fußstreifen der Nordreihe frei bleibt und die Südreihe Abstand zum Zaun hat.
- Zaun: Das unsichtbare `extra_walls`-Segment hinter der Hütte ist durch den sichtbaren Eisenzaun z −12,5 mit Pförtchen (x −10, 1,2 m) ersetzt, dazu West- (x −11,5) und Nordzaun (z −20) des Winkels. Das Pförtchen blockiert zu, offen (Modell `ph_prop_gate_small_open`) ist es ein Weg (Bau-Maske ROUTE).
- **Westmauer:** Ein neues Zaunstück x −11,5, z −5…−1 schließt die Lücke südlich der alten Westseite; Ilse steht außen, der Spieler spricht innen bei x ≈ −10,9 über den Zaun (Interactable-Reichweite reicht). Der Streifen innen (x −11,5…−10,3, z −3,8…−1,4) ist ROUTE.
- **Ilses Laterne (Entscheidung):** Das Modell trägt die Laterne tief in der linken Hand. Statt einer zweiten Laterne auf dem Stein steht der Mauerstein `ph_prop_wall_ledge` genau unter ihrer Hand (Blick nach Osten, `face_player_range 0`: sie dreht sich nicht zum Spieler), sodass die Laterne auf dem Stein aufsitzt. Ein Licht, keine Zusatzlogik; beim Gehen trägt sie sie mit.
- Requisiten: Waschschüssel (−2,88 | −4,98) 1,2 m neben dem Tisch (mit Kollision), Räucherschale auf der Tischplatte genau am Ursprung des Wacholderrauchs der Leiche (tischlokal 0,55 | −0,38), Mauerstein an Ilses Platz.
- Tür-Zettel `Decor/DoorNote` (`ph_door_note`) am Türblatt der Hütte: sichtbar ab `trader_known` bis zum ersten Treffen mit Ilse.
- Zwei Bäume aus dem Winkel versetzt (Eiche −6,5 | −17,5 → −7,6 | −23,4; Birke −4,8 | −17,6 → −4,9 | −22,9), drei Holundersträucher `ph_env_elder_bush`. Kamera-Grenze min → (−10, −17,5); `walkable_bounds` unverändert. Teleport `tp_elder` (−10,75 | −15,9).
- Boden neu exportiert (nur die neuen Grabstellen werden geglättet; Größe und Kanten unverändert).
