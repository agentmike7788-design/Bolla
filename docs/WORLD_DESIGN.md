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

## Phase-6-Welt – Gruft, Kapelle, Lagerschuppen (W-Welt, Vertrag `docs/PHASE6_DESIGN.md` §4)

Quelle: `data/world/graveyard_layout.json` (Blöcke `buildings` {sites, site_rects, crypt_route, soul_lantern}, `building_doors`, `interiors`, Abschnitt `churchyard`, Hindernis `obs_c_gate`, `old_graves[].pit_variant`), Raum-Layouts `data/world/interiors/{crypt,chapel,shed}_layout.json`. Builder-Teil `graveyard_build_phase6.gd` (Systemknoten Buildings 32 · Ossuary 36 · Chapel 37, Bauplätze `Entities/site_*` mit Footprint-Kollision und `Exterior` = `building_exterior.gd`, Türen `Entities/door_*` am Marker `door_outside`, Innenräume `Interiors/CryptInterior|ChapelInterior|ShedInterior`, Rückbau des alten Tischs), generischer Raum-Builder `src/world/interiors/interior_build.gd` (+ `interior_builder.gd -- --room=<id>`), Kapellen-Ritenlichter `chapel_rite_lights.gd`. Aufnahmen: `graveyard_shots_phase6.gd`.

```
 z −30 ┌──────────── Kirchhof churchyard (x −2…11,5, keine Gräber, keine Zier) ────────────┐
       │  Kulisse K7 (z −31…−36) · K2 (0,2|−32)      KAPELLE (4,5|−25,5)  Footprint 5,2 × 7  │
 z −22 │  Birke (−1,4|−22,2)   Tür (4,5|−21,3) ░ Vorplatz ░  Totenleuchter (6,6|−21,4) · Birke K3 (9,6|−23,4)
 z −20 ═══════ Nordzaun Birkenhang ═══[KIRCHPFORTE x 3,7…5,3]════════════════════════════
 z −12 ═ Holunderwinkel ═[Pförtchen]═╗    … Birkenhang …   ═══ Zaun Alter Hof ═[Durchgang]═
       SCHUPPEN (−12,9|−9,0)  │ Gang x −11,2…−8,6   HÜTTE (fest)
       Tasche x −14,6…−11,2 · z −7,2…−5,4 (Tür −12,8|−6,85)   Tisch (−1,6|−5,4) → Trittstelle ab Gruft 1
       … Alter Hof … Eiche (−7,6|3,2) · old_08 (−5,2|5,6)
 z  5,6 GRUFT (−9,0|6,9) Footprint x −10,4…−7,6 · z 5,6…8,2, Tür (−9,0|8,55), Zugang bis z 9,2
 z  9,6 ═══ Südzaun ═══ … Tor · Bahre (4,4|8,3)
```

**Bauplätze und Stufen.** `BuildingSite` zeigt das Modell der Stufe (0 = `model_site`, sonst `levels[n].model` aus `data/buildings/*.tres`), sichtbar ab `buildings_open`; eine Footprint-Box kollidiert (Gruft 2,4 m, Kapelle 6,0 m, Schuppen 3,0 m hoch). `building_exterior.gd` hängt an die Marker der jeweils gezeigten Stufe warme Lichter ohne Schatten: Gruft-Laterne (St. 3), zwei Kapellenfenster (nur während `ChapelAltar.rite_active` und ab St. 3 nachts), Totenleuchter (St. 3, nachts); die Glocke (Kindmesh `bell`, ab St. 2) schwingt 6 s bei Beginn und Ende eines Ritus (GDScript, kein Shader-TIME). Die Türen sitzen an den Positionen der `door_outside`-Marker (Gruft (−9,0 | 8,55), Kapelle (4,5 | −21,3), Schuppen (−12,8 | −6,85)).

**Rückbau vor der Hütte (§4.4).** `Entities/morgue_table` hat `retire_at_level 1`; Waschschüssel (`Decor/Phase4Props/WashBasin`), Räucherschale (`Entities/morgue_table/SmokeBowl`) und die Kollisionskörper `Colliders/morgue_table`, `Colliders/WashBasin` tragen `follows_table = "morgue_table"`. Ab Gruft 1 bleibt die Trittstelle (Bau-Maske und Gras dort unverändert).

**Innenräume (§4.7/§4.8).** Gruft (60 | 0 | −200): Gewölbe 8 × 6 m, Treppe nach Süden (Schacht, 8 Motes), Gruft-Tisch in der Mitte (`MorgueTable` room crypt, requires_level 1) mit Räucherschale und Waschbecken (`follows_table`), Hängelaterne darüber (einziges Schattenlicht), Kühlnischen **niche_1/2 an der Nordwand beiderseits des Beinhauses** (Stufe 1, von der Raumkamera frontal lesbar), niche_3/4 an West-/Ostwand mitte (St. 2), niche_5/6 vorne (St. 3), vermauerte Nischen als Ziegelfront bis zur Stufe davor; Beinhaus-Nische im Norden mit Regal (6 Kistenplätze, Namenstafel ab St. 3), vermauerte Tür schräg in der Nordost-Ecke der Nische, damit die Raumkamera sie sieht (St. 2 / Gitter St. 3), Gebeinregal (St. 2), Kerzennischen über niche_1/2. Kapelle (120 | 0 | −200): Katafalk längs vor dem Chor, Altar mit Kerzen (Rolle `rite`), rohe Bänke nur St. 1, vier Kirchenbänke ab St. 2 mit den Trauergästen (MournerSet, 2 auf St. 2, 4 auf St. 3), Glockenseil (St. 2), Kerzenständer = Ewiges Licht und Chorfenster mit Lichtfleck (St. 3), eine Innenraum-Sonne mit Schatten. Schuppen (180 | 0 | −200): Regal mit Lagerbuch = `ShedStore` an der Nordwand, Holzlege (St. 1), Steinkiste (St. 2), zweites Regal (St. 3), Laterne an der Tür. Jeder Raum hat `Sun`, `Spawn`, `camera_rig_path` / `outdoor_sun_path`, `hide_when_inactive`; Möbel der Stufen tragen `min_level`/`max_level` (Kollision mit).

**Versetzte bzw. geänderte Elemente (vollständig; Layout-Diff-Test gegen `tests/fixtures/phase6/layout_p5.json`):**
| # | Element | vorher | nachher | Grund |
|---|---|---|---|---|
| G1 | Pflegestelle `dirt_y01` | (−9,8 \| 7,8) | (−6,6 \| 8,6) | §4.1 |
| G4 | Waldbaum `forest.trees[0]` | (−8,2 \| 14,2) | **(−15,8 \| 14,6)** | Sichtprüfung Gruft (weiter als die 2 m aus §4.1; W1-Notiz 1) |
| – | Kulissenbaum `background_trees[3]` | (−13,0 \| 9,0) | **(−16,5 \| 9,5)** | Sichtprüfung Gruft |
| – | Waldbaum `forest.trees[1]` | (−12,8 \| 18,0) | **(−16,2 \| 20,6)** | Sichtprüfung Gruft |
| – | Erle `gather_alder_2` (Schlag) | (−10,4 \| 15,6) | **(−10,4 \| 16,6)** | Sichtprüfung Gruft bei Zoom 12 (Tür und Kopf); weiter südlich verdeckt der Waldbaum (−9,4 \| 22,4) Stumpf und Schösslinge (QA5-06) |
| G5 | Pflegestelle `dirt_y11` | (−8,8 \| 4,9) | **(−8,8 \| 4,1)** | Kopf des Spielers dort lag in der Box des Gruft-Portals (Prüfung §4.5 Punkt 4) |
| K1 | Zaun Birkenhang-Nord | [[2,0, −20], [7,0, −20]] | [[2,0, −20], [3,7, −20]] + Kirchpforte + [[5,3, −20], [7,0, −20]] | §4.2 |
| K2 | Hintergrundbaum | (3,5 \| −23,5) | (0,2 \| −32,0) | §4.2 |
| K3 | Birke | (6,6 \| −22,0) | (9,6 \| −23,4) | §4.2 |
| K4–K6 | Laufgrenze min, Kameragrenze min.z, Boden | – | min (−14,8 \| −30,3), camera min (−11,5 \| −24), Boden 64 × 80, Mitte (8 \| −5,5) | §4.2/§4.3 |
| K7 | Kulisse hinter der Kapelle | – | (−3,6 \| −33,6), (4,2 \| −35,6), (9,6 \| −31,6), (13,4 \| −34,2) | §4.2 |
| S1 | Hintergrundbaum | (−12,5 \| −9,5) | **(−16,8 \| −13,4)** (1 m weiter als §4.3: sonst verdeckt die Krone den Schuppen-First) | §4.3 |
| S2 | Westgrenze | Wand x −11,2 | ohne Rechteck-Westwand (`west_wall false`); `extra_walls` auf der alten Linie nördlich/südlich der Tasche, die Tasche **x −14,6…−11,2** (0,2 m schmaler als §4.3, damit Ilses Weg ≥ 0,4 m außerhalb bleibt) · z −7,2…−5,4 und ihr Nordrand unter dem Schuppen | §4.3 |
| S4 | Hintergrundbaum `background_trees[5]` | (−17,0 \| −1,5) | (−18,6 \| −0,4) | Sichtprüfung Schuppen (bedingt) |
Nicht bewegt: Hütte, Tisch (nur zur Laufzeit verborgen), Werkbank, Stationen, Pförtchen, Ostpforte, Eiche, alle Grabstellen, Altgräber (nur `pit_variant` neu), alle übrigen Pflegestellen (außer G1, G5), Laternenpfähle, Schwarzes Brett, Ilses Wegpunkte, Bauplätze an den Vertragspositionen (kein Versatz nötig).

**Sichtprüfung §4.5 (Test `test_graveyard_world.gd`, AABB-Strahlen, Stufen 0–3, Zoom 12/22/24):** Tür und Kopf überall frei. Freie Gebäudepunkte von 4: Gruft 3 (der First liegt in der AABB der Eichenkrone dahinter), Kapelle 4, Schuppen 4 (Stufe 0: 3). Im Bild bei Zoom 22 (Modellecken-Stichprobe der Mesh-Vertices): Gruft 100 %, Kapelle 82–100 %, Schuppen 100 %; Bildanteil Gruft 4,6–7,4 %, Kapelle 24–31 %, Schuppen 5–12 %. Übersicht (Mesh-Strahlen): Gruft von der Bahre und `tp_workyard` 5/5, Kapelle von `tp_north` 5/5, Schuppen von `tp_workyard` 5/5. Keine neue Verdeckung an Hüttentür, Stationen, Bahre, Grab- und Pflegestellen, Altgräbern, Ilses Platz.
**Routen (Flood-Fill 1,5 m):** Hüttentür ↔ Bahre, Gruft-Zugang (die letzten ≈ 2 m zwischen Gruftfront und Südzaun sind 1,4 m breit – der Zugangsstreifen, mit der Spielerkapsel frei), Kirchpforte, Kapellentür, jedes Altgrab, Schuppentür, Pförtchen, Tor, Ostpforte, Stationszugänge; Gang an `old_08` vorbei ≥ 1,9 m. **Boden/Gras:** Boden flach unter den drei Footprints (+ 0,35 m), Trittspuren vor den Türen; Gras fehlt unter Footprints und Vorplätzen (1 m), Kirchhof × 0,6. Bau-Maske: Gruft-Rechtecke gesperrt, Weg Bahre → Gruft ROUTE, Kirchpforte ROUTE.

## G8 Runde 2 – Gruft-Eingang neu (Benutzerkritik am Gruft-Eingang, Gate G8)

Kritik: zu klein / wirkt wie eine Kiste · Treppe kaum zu sehen · steht direkt am Zaun · passt nicht zum Friedhof (hellgraues Mauerwerk, grüner Hügel) · „der Eingang soll zum Weg zeigen". Umsetzung (ersetzt die Gruft-Zeilen der Phase-6-Skizze oben):

```
 z  3,2       Eiche (−7,6|3,2) bleibt stehen – die Gruft liegt unter dem Rand ihrer Krone
 z  5,6 GRUFT-PORTAL (−9,5|5,6), rot_y 56° → blickt nach Südosten, Treppe 1,6 m breit · 1,3 m tief nach vorn
        Tür am Treppenfuß (−9,46|5,63) · Treppenkopf/Zugang (−6,89|7,36) · old_08 (−5,2|5,6) ≥ 0,65 m frei
 z  7,4 ░ gepflasterter Vorplatz ░ → Plattenweg (crypt_route) südlich an old_08 vorbei, nördlich der Tafel → Hauptweg am Tor
 z  9,6 ═══ Südzaun ═══ (Treppenkopf-Pfeiler ≥ 1,3 m davor) … Tor · Bahre (4,4|8,3)
```

- **Portal** (`ph_bld_crypt_l1…l3`, `tools/blender/asset_buildings_phase6.py`): versenktes Gruftportal 3 m breit, Giebel 3,0 m (Kreuz bis 3,6 m), Pilaster mit Basis und Kapitell, Gebälk mit Fries, Dreiecksgiebel; der Treppenschacht davor (Footprint lokal x −1,5…1,5 · z −0,85…2,75) mit sechs Stufen bis zum Absatz vor der Tür, hintere (+X) Stützmauer mit Brüstung, vordere (Kameraseite) niedrige Wange mit Eisengeländer, zwei Pfeiler mit Laternen am Treppenkopf (Marker `light_lantern_1/_2`, jede Stufe, ohne Schatten, Flackern). Dunkles, grünstichiges Mauerwerk mit Moos auf allen Simsen, Wasserläufen unter den Gesimsen, Flechten, Efeu an der Kameraseite; kein Grashügel mehr. Stufe 1 alt und verfallen (abgebrochenes Giebelkreuz, Riss, Bruchstück im Gras, viel Efeu), Stufe 2 ausgebessert (Kreuz, Kugeln, Kranz im Giebelfeld, Handlauf, Ranken am Geländer, weniger Efeu), Stufe 3 Namenstafel im Fries (Inschrift), Gittertor am Treppenfuß, Gitter-Laterne über der Tür.
- **Lage**: Südwestecke Alter Hof wie bisher, aber gedreht und frei gestellt – Abstand Treppenkopf ↔ Südzaun ≥ 1,3 m, Portalrücken ↔ Westzaun ≥ 0,6 m, kein Baum und kein Grab verschoben; nur die Laubstellen `dirt_y11` (−8,5|3,0) und `dirt_y12` (−6,6|3,7) rückten neben das Portal bzw. unter die Eiche.
- **Vorplatz und Weg**: `buildings.paving` (Welt-Polygon `forecourt`, Breite 1,15 m entlang `crypt_route` ab x −0,1) – alte, eingesunkene Steinplatten `ph_env_crypt_paving` (aus `asset_ground_graveyard.py`, Weltkoordinaten, ohne Kollision), darunter dunkle, moosige Erde, kein Gras; nie näher als 0,2 m an einem Altgrab.
- **Boden und Kollision**: Grube der Treppe im Boden (`stair.rect`, Tiefe 1,3 m + 0,3 m unter den Stufen), Rampe auf den Stufenkanten, Absatz `foot` vor der Tür, Wangen als Kollision (vorne bis 1,0 m – Geländer), der Bauplatz steht auf der Bodenhöhe hinter dem Portal (`site_xform`).
- **Alte Spielstände**: Gruft-Position steht nicht im Stand. Wer beim Laden im Mauerwerk oder unter dem Boden steht (alte Treppe), landet am Treppenkopf (`BuildingSite.free_area`, Gravekeeper und liegende Leichen); Zier im neuen Bauplatz-Rechteck räumt `Buildings` einmal (Flag `crypt_site_moved_g8`).
