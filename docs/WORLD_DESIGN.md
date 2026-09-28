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

## Phase-5-Welt – Werkhof, Am Bruch, Schlag (W-Welt, Vertrag `docs/PHASE5_DESIGN.md` §4)

Quelle: `data/world/graveyard_layout.json` (Blöcke `workyard`, `stations`, `gather_nodes`, `quarry_edges`, Abschnitte `bruch`/`quarry`, Hindernisse `obs_b_gate`, `obs_q_boulder_1…3`), Builder-Teil `graveyard_build_phase5.gd` (Systemknoten Gathering 25 · Workshop 30 · Stonemasonry 35, Bauplätze, Stationen, Meiler, Steinablage, Sammelstellen, Felskante), Laufzeit-Präsentation `kiln_visual.gd` (Meiler kalt/brennend) und `stone_rack.gd` (fertige Steine an `stone_slot_1…3`). Aufnahmen: `graveyard_shots_phase5.gd`.

```
 z −12 ══Holunderwinkel-Zaun══[Pförtchen]════╗══Birkenhang-Zaun══[Hecke x 2,5…6,5]══
        │ Gang x −11,2…−8,6   Meiler (−4,6|−11,4) ║ ESSE (−2,2|−10,9) STEINMETZBANK (0,32|−10,55, 90°)
        │ Steinhaufen          ┌─── HÜTTE ───┐     Zugang Süd (−1,55|−9,4)  Zugang Ost (1,6|−10,55)
        │ Kiste (−8,4|−5,75)   │  (fest)      │ Werkbank   Holzhaufen (0,3|−8,4)       plot_01 …
 Ilse ▌ │ WEBSTUHL (−8,75|−3,9, 270°) └Tür┘ Tisch
        │ Zugang West (−10,2|−3,9) über Ilses Streifen          Pfad → Tor
```

**Werkhof – Stationen neben der Hütte, alle drei von der Spielkamera sichtbar.** Die Lage aus §2.1/§4.1 wurde geändert (Benutzer-Hinweis nach P5): Die Esse hinter der Hütte war von der Kamera (45°, 22 m) fast ganz vom Dach verdeckt, der Webstuhl vor der Hütte lag unter der Eichenkrone. Gesucht wurde per Strahlprüfung (Kamera → Modellpunkte, Verdecker Hütte + Kronen) über alle freien Plätze am Hof:

| Station | vorher (§2.1) | nachher | Zugang | sichtbare Modellpunkte (Kamera am Zugang / vor der Tür; §2.1-Lage zum Vergleich) |
|---|---|---|---|---|
| Esse | (−7,3 \| −11,1), hinter der Hütte | **(−2,2 \| −10,9), 0°** – nordöstlich neben der Werkbank am Birkenhang-Zaun | Süd (−1,55 \| −9,4) | 91 % / 59 % (obere Hälfte 99 %; Westende hinter der Traufe, Glut und Kamin frei) – vorher 70 % / 32 % |
| Steinmetzbank | (−0,5 \| −10,6), 0° | **(0,32 \| −10,55), 90°** – östlich neben der Esse, Ablage zur Kamera | Ost (1,6 \| −10,55) | 98 % / 88 % |
| Webstuhl | (−8,6 \| −1,3), unter der Krone | **(−8,75 \| −3,9), 270°** – an der Südwestecke der Hütte, Pultdach zur Kamera | West (−10,2 \| −3,9) über Ilses Streifen | 78 % / 79 % (obere Hälfte 100 %) – vorher 1 % / 8 % |
| Meiler | (−4,6 \| −11,4) | unverändert (hinter der Hütte, nur Rauch sichtbar) | an der Esse | – |

**Versetzte bzw. geänderte freigegebene Elemente (vollständig; Layout-Diff-Test gegen `tests/fixtures/phase5/layout_p4.json`):**
- V1 Holzhaufen `res_wood`: (−1,2 | −9,4) → **(0,3 | −8,4)** (§4.1 nannte (0,0 | −7,8); dort ließ er zum Leichentisch keinen 1,5-m-Gang).
- Kiste `ph_prop_crate`: (−8,2 | −4,9) → **(−8,4 | −5,75)** (Platz für den Webstuhl an der Hütten-Südwestecke).
- V2/V3: Bau-Maske gesperrt unter Footprint + 0,6 m, Zugang 1,0 m ROUTE, Meiler gesperrt; Gras dort entfernt; Boden unter den Bauplätzen geglättet (an bestehende Zonen angeglichen, Werkbank/Tisch bitgleich).
- Ostpforte: Ostwiesen-Zaunstück [[21,5, 3], [21,5, −3]] → [[21,5, 3], [21,5, 0,8]] + Pforte + [[21,5, −0,8], [21,5, −3]].
- Zwei Hintergrundbäume aus Am Bruch: (24,5 | 2,0) → (34,5 | 3,0), (25,5 | −6,0) → (35,0 | −7,0).
- Nicht bewegt: Hütte, Leichentisch, Werkbank, Pförtchen, Steinhaufen, Waschschüssel, Schaufel, alle Pflegestellen, Grabstellen, Spielerstart.

**Routen (Flood-Fill mit 1,5-m-Zylinder, alle Stationen gebaut):** Hüttentür ↔ Pförtchen (westlich um den Webstuhl über Ilses Streifen, dann der Gang; die Engstelle am Steinhaufen bleibt wie in Phase 4), ↔ Birkenhang-Durchgang (östlich der Steinmetzbank), ↔ Tor, ↔ Ostpforte, ↔ jeder Stationszugang. Esse-Glut: 1 Omni `#E07A3A`, 0,5, 3,5 m, ohne Schatten, Kind der Station (nur gebaut sichtbar). Rauch: Kamin 3 + Meiler 3 Partikel (`ph_vfx_smoke_wisp`, warmgrau, 40 m).

**Am Bruch (§4.2)** – x 21,5…31,5: Abschnitt `bruch` (z −6,5…9,6, Flag `bruch_license`, Ostpforte 1,6 m = `ph_prop_gate_small` × 1,345 in X), `quarry` (z −12…−6,5, nach `bruch`, 3 Findlinge `ph_env_boulder` → `_broken` bei z −6,6). Sammelstellen: Erzader, 2 Werksteinbänke, Bruchsteinwand im Steinbruch; 3 Flachsbeete, Lehmkuhle, 2 Kräuterraine Am Bruch. Rand: Felswand `ph_env_quarry_face` (26,2 | −12,9), Kantenstücke an Nord- und Ostkante, 3 Dornhecken im Süden; unsichtbare Wände z 9,6 und z −11,4, Ostgrenze x 31,2. Eingewachsene Steinplatte (24,0 | −2,8) ohne Funktion. Teleports `tp_bruch` (25,5 | 0), `tp_quarry` (27,0 | −8,3).
**Schlag (§4.3):** 5 Erlen an den Vertragspositionen (nicht verschoben), Kräuter (−2,8 | 18,0), (−2,6 | 23,6); `tp_schlag` (−5,2 | 19,4) statt (−6,0 | 19,0) (dort stand ein Busch). **Holunder (§4.4):** alle 3 Sträucher tragen eine Sammelstelle (Kind des Strauchs, nach innen versetzt), alle 3 vom Spieler erreichbar.
**Boden, Grenzen:** Boden 64 × 64 m (Mitte (8 | 2,5), x −24…40), Steinboden-Tönung im Steinbruch, Gras Am Bruch halbe Dichte, im Steinbruch keins; `walkable_bounds.max` x 31,2, `camera_bounds.max` x 27. Die Bau-Maske bleibt x −11,5…21,5.
