# Phase 6 – Gebäude – Vertrag v1

Status: **v1 – Entwurf zur Benutzerfreigabe (Vertragsfragen §14 offen), danach verbindlich für die Umsetzung** · Verantwortlich: Agent 01 (Lead), Agent 02 (Game Design), Agent 03 (World Design), Agent 05 (Blender/Gebäude), Agent 08 (Godot Core), Agent 10 (Graveyard System), Agent 11 (Corpse System)
Baut auf `docs/PHASE5_DESIGN.md` (Vertrag v1.1, freigegeben 28.09.2026), `docs/PHASE4_DESIGN.md`, `docs/PHASE3_DESIGN.md` und `docs/VERTICAL_SLICE_DESIGN.md` (§11 Hütte & Innenraum) auf. Was dieses Dokument nicht ändert, gilt dort unverändert weiter. Referenz-Build: **c5bd76d** (Gate G5 freigegeben).
Gameplay-Werte sind **Vorschläge**; der Benutzer prüft sie beim Gate G6. ART STYLE LOCK „Gemaltes Diorama" ist aktiv: Phase 6 ändert den Stil nicht. Der Maler-Shader (`painted.gdshader`, `painted_common.gdshaderinc`, `painted_foliage.gdshader`) bleibt unverändert, ebenso die Atmosphären-Presets der Außenwelt. Die freigegebenen Abschnitte I–IV (Alter Hof, Ostwiese, Birkenhang, Holunderwinkel) und der Werkhof aus Phase 5 bleiben bitgleich, **außer** den in §4.1–§4.3 vollständig aufgezählten Eingriffen (Gruft-Bauplatz in der Südwestecke des Alten Hofs, Kirchpforte im Nordzaun des Birkenhangs, Schuppen-Tasche westlich der Hütte) und dem Rückbau des Leichentischs vor der Hütte, sobald die Gruft steht (§4.4).

> **Änderung (geändert 04.10.2026, Benutzerwunsch: Gruft von Beginn an):** „Die Treppe in meinem Friedhof soll immer da sein – da muss ich ja die Leichen runterbringen und bearbeiten." Die Gruft steht ab Spielbeginn auf **Stufe 1** (`BuildingData.start_level = 1`, kostenlos, ohne Bauaktion): Treppe, Portal und Tür unter der Eiche sind von Tag 1 sichtbar und begehbar, die Grasdecke über dem Schacht fehlt, der **Gruft-Tisch** ist der einzige aktive Tisch. Der Tisch vor der Hütte ist im Spiel nie aktiv (er bleibt nur als stiller Knoten im Layout für Welten ohne Buildings-System). Alle Phase-2–5-Handgriffe finden von Anfang an unten am Gruft-Tisch statt. Ausbau auf Stufe 2 und 3 wie bisher ab `buildings_open`; das Kapitelziel `goal_levels crypt: 2` bleibt. Alte Stände (v1–v6, Gruft 0) werden in `Buildings.post_load` repariert (Gruft → 1, Leiche vom alten Tisch → Gruft-Tisch mit Notiz; kein Versionssprung). Die betroffenen Stellen unten sind markiert.

**Benutzerentscheidungen (verbindlich, 28.09.2026)**
- **Gebäude:** alle vier genannten Aufgaben:
  1. **Leichenhalle:** kühler Raum für mehrere Leichen, bremst den Verfall; Untersuchen und Herrichten finden dort statt.
  2. **Kapelle:** kleine Friedhofskapelle. Trauerfeiern bringen mehr Ruf und Bezahlung und beruhigen Geister. Ein Pfarrer kommt erst in Phase 8.
  3. **Lagerschuppen:** großes Lager für Holz, Stein und Werkstoffe, als Erweiterung der Truhe.
  4. **Beinhaus / Gruft:** alte Gebeine umbetten; ein erster Blick in die Unterwelt als Vorbereitung auf die Krypten in Phase 12.
- **Wunsch des Benutzers, wörtlich:** „und am besten noch eine gruft da wo man die leichen bearbeitet nicht so wie jetzt das der tisch da vor dem haus steht". Die Leichenarbeit zieht deshalb vom offenen Tisch vor der Hütte **in ein Gebäude unter der Erde**. Vorschlag dieses Vertrags (§2.2, Bestätigung §14.1): Leichenhalle und Gruft werden **ein** Gebäude, **„Die Gruft"**. Es hat drei Teile: einen Arbeitsraum mit Leichentisch, **Kühlnischen** (die Aufgabe der Leichenhalle) und eine **Beinhaus-Nische** (Umbettung, Blick in die Tiefe). Damit bleibt es bei **drei Gebäuden**: Gruft, Kapelle und Lagerschuppen.
- **Bauweise:** feste Bauplätze mit Ausbaustufen 1 → 2 → 3 (wie der Werkhof), jede Stufe kostet Material und Münzen.
- **Innenräume:** Jedes Gebäude ist begehbar und hat eine eigene, eingerichtete Innenraum-Szene nach dem erprobten Hüttenmuster: eigene Szene fern der Welt, Überblendung am Portal, Kameraprofil und Innenlicht nach Tag und Nacht. Die Gruft liegt unter der Erde (Treppe hinab, Kerzen- und Laternenlicht, kalte Luft, keine Fenster). Die Kapelle hat Fenster, Bänke, Altar und Kerzen. Der Lagerschuppen ist ein schlichter Holzschuppen mit Regalen.
- **Umfang: mittel.** Etwa 8–10 Spieltage auf dem Phase-5-Endstand. Kapitelziel (§1.5): alle drei Gebäude mindestens auf Stufe 2, die erste Aussegnung gehalten und die ersten Gebeine beigesetzt.
- **Lage:** Die Bauplätze legt dieser Vertrag fest. Versetzungen bleiben minimal und stehen vollständig in einer Liste (§4). Alle Wege bleiben frei. Jedes Gebäude muss aus der Spielkamera **klar sichtbar** sein; das prüft ein Kamerastrahl-Test (§4.5, Lehre aus Phase 5).
- **Münzsenke:** Die Gebäude verbrauchen einen spürbaren Teil der Münzen. Rechnung in §2.8.

**Regeln für alle Agents** (wie Phase 3–5)
- Klassen, Signaturen, Dateipfade, Signale und Datenformate hier sind **fest**. Änderungen nur über den Lead.
- Der Lead legt in **Welle 0** alle Datenklassen (✦) vollständig und alle Logikklassen als **Stubs mit exakten Signaturen** an. Die Besitzer füllen die Körper und benennen nichts um.
- Nach jedem neuen Worktree und nach jedem Merge: `godot --headless --path . --import`.
- Jede Datei hat genau einen Besitzer (§3.2). Fremde Dateien nicht ändern; Bedarf an den Lead melden.
- Alle neuen Assets tragen `ph_` und kommen in die Placeholder-Liste (`docs/QUALITY_GATE_STATUS.md`).
- Keine Mechaniken, Namen oder Texte anderer Spiele übernehmen. Ausdrücklich **nicht**: Gebäude-Sternwertungen, Bauwarteschlangen mit Sofortkauf, Arbeiterzuweisung, tägliche Unterhaltskosten für Gebäude, Predigt- oder Messe-Minispiele, Knochen oder Schädel als Handelsware, bemalte Schädel, Reliquien, Ablass.
- Eigene Identität dieser Phase: **„Wo die Toten warten"**. Bisher lagen die Toten auf einem Brett vor der Hütte, im Regen und unter Fliegen. Jetzt bekommen sie einen Ort zum Warten: eine kühle Nische unter der Eiche, einen Katafalk vor dem Altar und für die ganz Alten einen trockenen Platz im Beinhaus. Wer wartet, muss nicht vergessen werden.
- Sprache: alle Spieltexte eigenständig auf Deutsch, trocken-melancholisch, in der Gruft leise unheimlich. Kein Spott über die Toten, keine Frömmelei.

---

## 1. Spielablauf & Progression

### 1.1 Erweiterter Kern-Loop
```
Freischaltung (Kapitel „Namen in Stein") → Osric: Gemeinderat, Gruft, Kapelle, Beinhaus
  → GRUFT unter der Eiche ausbauen (Stufe 2) – Stufe 1 steht ab Spielbeginn (geändert 04.10.2026, Benutzerwunsch: Gruft von Beginn an)
  → BEINHAUS: Gebeinkiste zimmern → altes Grab heben → Gebeine beisetzen → die Stelle ist wieder frei
  → Osric bringt wieder Leichen (eine je freie Stelle, wie bisher)
  → Bahre → GRUFT: Tisch (untersuchen, herrichten) · Kühlnische (warten lassen, Verfall gebremst)
  → optional KAPELLE: Leichenzug hinauf → Katafalk → Aussegnung (Kerze, Gebühr, Ruf, Trauergäste)
  → Grab (die gehobene Altstelle) → bestatten → Stein → Qualität (+ „Ausgesegnet") + Bezahlung
  → nachts: Geister (neuer Pool „ausgesegnet") · ab Kapelle 1: Andacht für ein Grab (Stimmung ↑)
  → LAGERSCHUPPEN: Werkstoffe lagern · ab Stufe 2 an jeder Station „Fehlendes aus dem Schuppen holen"
```
Alle Phase-4-Handgriffe (Schritte, Funde, Herrichten, Verwertung, Räuchern) bleiben **unverändert**. Sie finden nur an einem anderen Tisch statt (§2.2).

### 1.2 Freischaltung
- **Neues Spiel:** Phase 6 öffnet sich mit dem Phase-5-Kapitel `names_in_stone_complete` (gemessen am Tag 20–29, G5). Am ersten Morgen danach (erste Minute ≥ 06:00, idempotent) setzt `Buildings.apply_morning` das Flag `buildings_open`. Ab dann hat Osric den Knoten `p6_intro`, und die drei Bauplätze sowie die Kirchpforte erscheinen.
- **Migrierte Stände (v4):** Ist `names_in_stone_complete` gesetzt, setzt `Buildings.post_load` `buildings_open` sofort (auch nach 06:00). Bei einem v5-Stand gilt wie beim Werkhof die Morgenregel (Speichern → Laden bitgleich).
- Vor `buildings_open` sind Bauplätze, Kirchpforte (geschlossenes Tor im Zaun), Altgrab-Prompts, die Altarkerze bei Osric und das Gebeinkisten-Rezept unsichtbar bzw. ohne Prompt. ~~Der Leichentisch vor der Hütte arbeitet unverändert weiter, bis die Gruft Stufe 1 hat (§2.2).~~ (geändert 04.10.2026, Benutzerwunsch: Gruft von Beginn an): Die Gruft (Stufe 1) mit Gruft-Tisch, 2 Kühlnischen und Beinhaus-Nische steht ab Tag 1; vor `buildings_open` fehlt nur der Ausbau-Prompt am Portal.
- Osric `p6_intro` (Leittext, P6 darf glätten): „Der Gemeinderat hat getagt, Totengräber. Der Friedhof ist voll, und die Leute wollen ihre Toten nicht mehr auf dem Brett vor deiner Hütte liegen sehen, wie Fisch auf dem Markt. Unter der alten Eiche liegt die Gruft der Gemeinde, seit Jahren zugeschüttet. Meine Leute haben den Hals freigelegt. Oben am Kamm steht die Kapelle, ohne Dach. Und wenn du die ganz Alten ins Beinhaus bringst, wird unten im Hof Platz. Vier Münzen zahlt die Gemeinde für jede Umbettung."

### 1.3 Zeitkosten (Spielminuten; TimedAction wie bisher)
| Handlung | Min | Braucht | Abbrechbar |
|---|---|---|---|
| Gebäude-Stufe bauen (Bauplatz) | Gruft 180 / 210 / 240 · Kapelle 240 / 210 / 240 · Schuppen 120 / 120 / 150 | Material + Münzen (§2.1) | nein |
| Gebeinkiste zimmern (Werkbank) | 15 | 3 wood | nein |
| Altes Grab heben | 60 / 50 / 35 (Schaufel-Stufe 0/1/2, §2.3 Phase 5) | 1 `bone_box`, freier Beinhaus-Platz | ja |
| Gebeine beisetzen (Beinhaus-Nische) | 20 | 1 `bone_box_full` | nein |
| Leiche in Kühlnische legen / herausnehmen · auf den Katafalk legen | 0 (wie Ablegen) | Leiche tragen / Hände frei | – |
| Aussegnung (Altar) | 45 | Leiche auf dem Katafalk, 1 `altar_candle`, Beginn 08:00–17:00 | nein |
| Andacht (Altar) | 30 | 1 `altar_candle`, ein Grab mit Geist | nein |
| Fehlendes aus dem Schuppen holen (an einer Station) | 10 (Schuppen 2) / 0 (Schuppen 3) | Schuppen ≥ 2 | nein |
| Überschuss einlagern (an einer Station) | 0 | Schuppen 3 | – |
| Gang durch ein Portal | 0 (Überblendung 0,5 s wie die Hütte) | – | – |
| Untersuchen, Herrichten, Verwerten, Räuchern | unverändert (Phase 4 §1.2) | – | unverändert |

*Begründung:* Phase 6 bringt keine neue Zeitquelle. Ein Tag mit einer Leiche kostet gründlich und voll hergerichtet ≈ 85 Min Tisch, 35 Min Graben, 20 Min Bestatten und 70–90 Min für einen gestalteten Stein. Mit Aussegnung kommen 45 Min Ritus und ≈ 70 Spielminuten Leichenzug dazu (§4.2: der einzige lange Tragweg, ≈ 45 m hinauf und ≈ 25 m zum Grab). Ein Bau von 3–4 h passt daneben. Eine Aussegnung **und** ein großer Bau **und** ein Meisterstein am selben Tag passen nicht. Diese Wahl ist gewollt. Der Leichenzug ist Teil des Ritus und keine Strafe: Wer keine Zeit hat, bestattet ohne Aussegnung.

### 1.4 Tagesbogen
**A) Referenz: Phase-5-Endstand (würdevoll, v4-Fixture `slot_p5_day30_reverent`, Tag 30, ≈ 31 Münzen am Morgen, 18 Gräber, keine Lieferungen).** Der Bogen dauert **10 Tage**, das Kapitel fällt an B6. Richtwert Mensch; der Bot `reverent6` spielt ihn nach (§10).
| Tag (Bogen) | Geschehen | Münzen früh → abends (§2.8) | Zielzeile (Beispiel) |
|---|---|---|---|
| 30 (B1) | Osric `p6_intro`. ~~**Gruft 1** (20)~~ (steht schon, (geändert 04.10.2026, Benutzerwunsch: Gruft von Beginn an)). 3 Gebeinkisten zimmern. `old_04`, `old_06`, `old_07` heben und beisetzen (+12). Der Tisch vor der Hütte ist fort. | 31 → 23 | „Sprich mit Osric" → „Bauplatz: Gruft" → „Altes Grab heben: Barbe Lindt" |
| 31 (B2) | Die erste Leiche seit Tagen. Bahre → Gruft → Tisch. **Kapelle 1** (25), 1 Altarkerze (2). **Erste Aussegnung** (+3), Leichenzug, Grab `old_04`, Stele mit Inschrift (+14). | 27 → 17 | „Bring die Leiche in die Gruft" → „Die Kapelle steht – leg die Tote auf den Katafalk" |
| 32 (B3) | Leiche 2 mit Aussegnung (+17). **Schuppen 1** (10). | 21 → 26 | – |
| 33 (B4) | Leiche 3 mit Aussegnung (+17). **Gruft 2** (30): 4 Kühlnischen, Beinhaus 5 Plätze, vermauerter Gang entdeckt (Hinweis). `old_02`, `old_05` heben (+8). | 30 → 23 | „Hinter dem Beinhaus zieht es kalt" |
| 34 (B5) | Leiche 4 mit Aussegnung (+17), erste Geistergabe (+2). **Schuppen 2** (15). | 27 → 29 | „Werkhof: Schuppen angeschlossen" |
| 35 (B6) | Leiche 5 mit Aussegnung (+19). **Kapelle 2** (30), Glocke und Trauergäste → **Kapitel „Unter Dach und Erde"**. | 33 → 20 | „Kapelle 2 · Gruft 2 · Schuppen 2" |
| 36 (B7) | Keine freie Stelle mehr → keine Lieferung. Zwei **Andachten** für gleichmütige Geister (4). Werkstein brechen. | 24 → 22 | „Eine Andacht für Agnes Hollweg?" |
| 37–39 (B8–B10) | Freies Spiel: Vorrat für Stufe 3, gestaltete Steine für die neuen Gräber. B10: **Gruft 3** (35), `old_03` heben und beisetzen (+4). Gitter im Gang, Blick in die Tiefe. | 26 → 5 | „Gruft 3: Das Gitter im Gang" |

**B) Neues Spiel:** `names_in_stone` fällt je nach Spielweise an Tag 20–29, der Bogen läuft danach wie A (die Endstände aus Phase 5 sind vergleichbar: 18 Gräber, keine Lieferungen, 27–53 Münzen). Richtwert Kapitelende „Unter Dach und Erde" ≈ Tag 27–36. Die Kapitel sind voneinander unabhängig: Phase 6 sperrt nichts aus Phase 4/5.

### 1.5 Phasenziel – Kapitel „Unter Dach und Erde" (`roof_and_earth`)
Erfüllt, sobald **alle** gelten (geprüft von `Buildings.check_goal` bei `building_upgraded`, `bones_reinterred` und `grave_completed`):
1. Gruft, Kapelle und Lagerschuppen stehen mindestens auf **Stufe 2**.
2. Mindestens **eine Aussegnung** ist gehalten, und die ausgesegnete Leiche liegt **bestattet und mit Zeichen** im Grab (`service_held ∧ MARKED`).
3. Mindestens **eine Gebeinkiste** ist im Beinhaus beigesetzt.

Dann: Flag `roof_and_earth_complete`, `chapter_completed(&"roof_and_earth")`, Abschluss-Panel Variante `roof_and_earth`. Es zeigt: Tage seit `buildings_open`, Stufen der drei Gebäude, Aussegnungen (davon mit Trauergästen), Andachten, Umbettungen n/6 mit Namen, Leichen, die in einer Kühlnische gewartet haben, in Phase 6 ausgegebene Münzen nach Zweck und zufriedene Geister vorher → jetzt. Schlusszeile: „Die Toten warten jetzt nicht mehr im Regen." Danach läuft das Spiel frei weiter. **Gate-Ziel:** Alle Bot-Strategien erreichen das Kapitel. Der verwertende Weg ist nicht gesperrt, Aussegnung und Umbettung stehen jedem offen.

---

## 2. Spielwerte (Vorschläge, alle in `data/`)

### 2.1 Gebäude & Stufen (`data/buildings/<id>.tres` – `BuildingData` mit `BuildingLevelData`, `data/config/buildings_config.tres` – `BuildingsConfig`)
**Bauweise – Entscheidung: feste Bauplätze, drei Stufen, nie abreißen.** Jedes Gebäude hat einen festen Bauplatz (Stufe 0: „Bauplatz" mit Vorgeschichte, §4). „[E] Gruft: Stufe 1 bauen" öffnet das Gebäude-Panel mit allen drei Stufen (erreichte hell, die nächste mit Kosten, spätere gedimmt). Der Bau ist eine TimedAction, nicht abbrechbar. Verbraucht wird **erst am Ende**, atomar (Items + Münzen). Danach tauscht der Bauplatz das Außenmodell der neuen Stufe ein. Das Portal öffnet ab Stufe 1. Eine Stufe baut nur auf der vorigen auf, Stufen überspringen geht nicht, ein Rückbau ist nicht möglich. Die Münzen stehen für Teile aus Hollerbrück, die Osric bringt; es gibt keine Warte- oder Liefertage (wie Phase 5).
*Begründung Stufen statt Einzelbau:* Die Stufen verteilen Kosten und Wirkung über den Bogen. Jede Stufe fügt sichtbar etwas hinzu (neues Außenmodell, neue Einrichtung innen) und schaltet eine Mechanik frei. Kein Gebäude ist mit dem ersten Bau „fertig".

| Gebäude | St. | Titel | Material | Münzen (wofür) | Min | Neu auf dieser Stufe |
|---|---|---|---|---|---|---|
| **Gruft** `crypt` | 1 | Gruft geöffnet | ~~12 stone, 6 wood, 4 clay, 2 iron_fittings~~ – (ab Spielbeginn (geändert 04.10.2026, Benutzerwunsch: Gruft von Beginn an)) | ~~20~~ **0** | ~~180~~ – | Portal und Treppe, Gewölbe, **Gruft-Tisch** (ersetzt den Tisch vor der Hütte, §2.2), Waschbecken und Räucherschale, **2 Kühlnischen** (× 0,5), Raumkühle × 0,8, **Beinhaus-Nische mit 3 Plätzen**, Hängelaterne |
| | 2 | Kühlgewölbe | 4 workstone, 8 stone, 4 clay, 1 iron_bar | ~~30~~ **35** (Schieferplatten, Kalk und Mörtel – Ausgleich für die entfallene Stufe 1, (geändert 04.10.2026, Benutzerwunsch: Gruft von Beginn an)) | 210 | **4 Kühlnischen** (alle × 0,4), Raumkühle × 0,7, **Beinhaus 5 Plätze**, Gebeinregal; hinter dem Beinhaus kommt ein **vermauerter Gang** zum Vorschein (Hinweis „Der kalte Zug", §2.3) |
| | 3 | Tiefe Gruft | 6 workstone, 6 stone, 2 iron_bar | **35** (Eisengitter und Namenstafel) | 240 | **6 Kühlnischen** (alle × 0,3), Raumkühle × 0,6, **Beinhaus 6 Plätze**, Namenstafel, **Gitter im Gang** (Blick in die Tiefe, kaltes Licht, §2.3), Laterne am Portal |
| **Kapelle** `chapel` | 1 | Kapelle unter Dach | 10 wood, 8 stone, 2 clay, 2 linen, 2 iron_fittings | **25** (Dachschiefer) | 240 | Dach, Altar mit Altartuch, **Katafalk**, 2 rohe Bänke, Altarkerzen; **Aussegnung** (Gebühr 3, Ruf +1), **Andacht** (+1) |
| | 2 | Glocke und Gestühl | 8 wood, 3 workstone, 2 iron_bar | **30** (Totenglocke aus der Stadt) | 210 | Dachreiter mit **Glocke** (schwingt bei der Aussegnung; kein Ton, Agent 17 inaktiv), 4 Kirchenbänke, **2 Trauergäste**, Gebühr 5, Ruf +2, Andacht +2 |
| | 3 | Licht im Chor | 4 workstone, 2 gold_leaf, 3 linen, 2 iron_fittings | **40** (bleigefasstes Chorfenster) | 240 | farbiges Chorfenster, **Totenleuchter** vor der Tür (nachts, ohne Schatten), Ewiges Licht, **4 Trauergäste**, Gebühr 7, Ruf +3, Andacht +3 |
| **Lagerschuppen** `shed` | 1 | Schuppen | 12 wood, 4 stone, 2 iron_fittings | **10** (Nägel und Schindeln) | 120 | **Lager 24 Plätze** (Regale innen), Holzlege außen |
| | 2 | Werkhof-Anschluss | 10 wood, 2 iron_fittings | **15** (Achse für den Handkarren) | 120 | **32 Plätze**, an allen Stationen, Bauplätzen und am Stein-Panel: „Fehlendes aus dem Schuppen holen" (10 Min), Handkarren am Schuppen |
| | 3 | Regale und Legen | 8 wood, 6 stone, 1 iron_bar | **20** (Eisenhaken und Regalwinkel) | 150 | **40 Plätze**, **doppelte Stapel** für Rohstoffe und Werkstoffe (`RESOURCE`, `MATERIAL`), Holen 0 Min, „Überschuss einlagern" an den Stationen |

**Summen** ((geändert 04.10.2026, Benutzerwunsch: Gruft von Beginn an): ohne Gruft 1, Gruft 2 = 35 → **115** Pflicht / **210** alle Stufen; Material −12 stone, −6 wood, −4 clay, −2 iron_fittings)**:** Stufe 1+2 aller Gebäude = **130 Münzen** (Pflicht für das Kapitel) · alle Stufen = **225 Münzen**. Material Stufe 1+2: 46 wood, 32 stone, 10 clay, 7 workstone, 3 iron_bar, 8 iron_fittings, 2 linen. Das entspricht bei vollen Tagesmengen aus Phase 5 (§2.2 dort: Holz 10, Stein 12, Erz 3) etwa 5 Sammeltagen, die sich über den Bogen verteilen.
*Begründung Werte:* Die Gruft ist zuerst nötig (sie gibt Stellen frei, §2.3) und deshalb auf Stufe 1 am billigsten unter den großen Bauten. Die Kapelle kostet am meisten, weil Glocke und Fenster Stadtware sind. Der Schuppen ist Holzbau und billig, seine Stufe 2 lohnt sich aber erst mit vielen Stationen. Eisen bleibt knapp (3 Barren + 8 Beschläge ≈ 14 Erz ≈ 5 Tage Erzader, vieles liegt nach Phase 5 schon im Lager).

- `BuildingsConfig`: `unlock_flag &"names_in_stone_complete"`, `open_flag &"buildings_open"`, `intro_minute 360`, `goal_levels {crypt: 2, chapel: 2, shed: 2}`, `goal_services 1`, `goal_reinterred 1`, `chapter_id &"roof_and_earth"`, `goal_flag &"roof_and_earth_complete"`, `cleared_flag &"building_sites_cleared"`.
- Gebäude-Panel-Prompt ((geändert 04.10.2026, Benutzerwunsch: Gruft von Beginn an): die Gruft hat nie Stufe 0; ihr Prompt „[E] Gruft ausbauen (Stufe 2)" erscheint ab `buildings_open`): Stufe 0 „[E] Bauplatz: Gruft", danach am Außenmodell „[E] Gruft ausbauen (Stufe 2)" (seitlich am Bauplatz-Marker `build`, nicht an der Tür; die Tür ist das Portal). Voll ausgebaut: kein Ausbau-Prompt.

### 2.2 Die Gruft – Leichenhalle unter der Eiche (`data/config/crypt_config.tres` – `CryptConfig`)
**Entscheidung: ein Gebäude für Leichenhalle, Gruft und Beinhaus (Bestätigung §14.1).** *Begründung:* Kühle, Stille und Dunkelheit brauchen Leichenhalle und Beinhaus gleichermaßen. Ein Gebäude unter der Erde erfüllt den Benutzerwunsch („eine Gruft, wo man die Leichen bearbeitet") wörtlich. Zwei getrennte Gebäude würden dieselbe Einrichtung doppelt verlangen, einen vierten Bauplatz im vollen Alten Hof und einen weiteren Tragweg. Die Gruft liegt 11 m von der Bahre entfernt; der alte Tisch lag 14 m entfernt (§4.1).

**Wo die Arbeit stattfindet – der Tischwechsel**
- **(geändert 04.10.2026, Benutzerwunsch: Gruft von Beginn an):** Es gibt keinen Tischwechsel mehr im Spiel. Die Gruft hat ab Tag 1 Stufe 1, der Gruft-Tisch ist von Anfang an der eine aktive Tisch; Raumkühle × 0,8, 2 Kühlnischen × 0,5 und die Gestank-Ausnahme (`stench_exempt`) gelten ab Spielbeginn (Balance-Hinweis im P8-pre-Bericht). Die Schritte 1–4 unten laufen nur noch in Welten/Tests mit Gruft 0 (Fixture-Gebäudetabellen) und als **post_load-Reparatur** alter Stände: `Buildings.post_load` hebt Gruft 0 → 1 und ruft `CorpseManager.relocate_table_corpse` (Notiz „Die Leiche vom alten Tisch liegt jetzt unten in der Gruft.").
- ~~Bis **Gruft 1** arbeitet der Leichentisch vor der Hütte unverändert (Phase 2–5). Das frühe Spiel und alle Phase-2- bis Phase-5-Tests gelten weiter.~~
- Beim Abschluss von **Gruft 1** (`Buildings.upgrade(&"crypt")`, im selben Aufruf):
  1. Der **Gruft-Tisch** (`MorgueTable` im Gruft-Innenraum, `room &"crypt"`, `requires_level 1`) wird aktiv.
  2. Der **Tisch vor der Hütte** (`retire_at_level 1`) wird inaktiv: unsichtbar, ohne Kollision und ohne Prompt. Waschschüssel und Räucherschale verschwinden mit ihm (§4.4).
  3. Liegt dort eine Leiche, legt `CorpseManager.relocate_table_corpse` sie mit **allen** Zuständen auf den Gruft-Tisch (Schritte, Funde, Räucherfenster, Verwertung, Einkleidung bleiben erhalten). Dazu kommt die einmalige Notiz: „Die Tote vom alten Tisch liegt jetzt unten in der Gruft."
  4. Es gibt weiterhin **genau einen** aktiven Tisch. Die Regel „`LOCATION_TABLE` = der eine Tisch" aus Phase 2–5 bleibt gültig. Untersuchungs-Panel, Zielzeilen und Tests brauchen dadurch keine zweite Tischlogik.
- Die Phase-4-Handgriffe (4 Schritte, Funde, Verfall-Verlust, Herrichten, Verwertung, Räuchern) laufen am Gruft-Tisch **ohne Änderung**. Das Panel heißt „Gruft-Tisch", sonst ändert sich nichts.

**Leichenfluss**
```
Osric 07:40 → Bahre am Tor (unverändert)
  → tragen (≈ 11 m, ≈ 6 s) → „[E] Gruft betreten" (mit Leiche erlaubt) → Überblendung → Fuß der Treppe
  → Gruft-Tisch „[E] Leiche ablegen" → Untersuchen · Herrichten · Verwerten · Räuchern (Panel wie Phase 4)
  → oder Kühlnische „[E] In die Kühlnische legen" → später „[E] Leiche aus der Nische nehmen"
  → „[E] Hinaufgehen" (mit Leiche erlaubt) → zum Grab oder zur Kapelle (§2.4)
```
- Der Boden der Gruft zählt als Ablageort (`LOCATION_GROUND`, `room &"crypt"`), wie draußen über den bestehenden Boden-Test.
- Mit Leiche lässt sich nur **in Gruft und Kapelle** gehen. Hütte und Schuppen weisen ab: „Leiche draußen ablegen" (bestehender Text).
- Speichern ist in der Gruft erlaubt (wie in der Hütte), auch mit getragener Leiche (bestehende Regel `CorpseManager.post_load`).

**Kühle – Verfall gebremst.** Neu sind **Kältefenster** am `CorpseRecord`, analog zu den Räucherfenstern aus Phase 4: `cold_windows = [start, ende, faktor‰, …]` in Gesamtminuten, Ende `-1` = offen (die Leiche liegt noch da).
| Ort in der Gruft | Faktor Stufe 1 / 2 / 3 | Wirkung bei Rate 1,0 (Frisch bleibt …) |
|---|---|---|
| Kühlnische | **0,5 / 0,4 / 0,3** | … 16 / 20 / 26,7 h statt 8 h |
| Gruft-Tisch, Boden der Gruft (Raumkühle) | **0,8 / 0,7 / 0,6** | … 10 / 11,4 / 13,3 h |
| Kapelle, draußen, getragen | 1,0 | unverändert |

- **Regel:** Die wirksame Rate in jeder Minute ist `min(Räucherfaktor falls aktiv sonst 1, Kältefaktor falls aktiv sonst 1)`. Kälte und Rauch **addieren sich nicht**, es gilt der stärkere. `CorpseDecay.effective_minutes` läuft über die Grenzen beider Fensterlisten; die Formel bleibt eine reine Funktion der Minutendifferenz (keine Ticks), Raster 1e-6 wie bisher. `minutes_until` berücksichtigt beide Listen.
- `CorpseManager` öffnet ein Kältefenster, sobald eine Leiche an einem kühlen Ort abgelegt wird. Es schließt, wenn sie aufgenommen oder bestattet wird. Bei einem Stufenwechsel der Gruft (`restart_cold`) schließen alle offenen Fenster zur Abschlussminute und öffnen mit dem neuen Faktor neu.
- *Begründung Faktoren:* Eine Kühlnische auf Stufe 1 hält eine Leiche einen Tag und eine Nacht „frisch". Wer abends ankommt, untersucht am Morgen, und die feinen Spuren (Phase 4) sind noch da. Stufe 3 (× 0,3) reicht für zwei Tage. Der Faktor liegt bewusst über dem Wacholder (× 0,25): Räuchern bleibt die stärkste, aber verbrauchende Konservierung, die Gruft die ruhige, dauerhafte. Mit Kältefenstern statt eines neuen Verfallszustands bleibt die bestehende Mathematik unangetastet und prüfbar.
- **Gestank am Tor** (Phase 4 §2.5): Leichen mit `room &"crypt"` zählen nicht mit (`CryptConfig.stench_exempt = true`). *Begründung:* Die Gruft hält den Geruch, und genau das wollte der Gemeinderat.
- **Sichtbarer Verfall in der Nische** (`DecayVisualConfig`): In einer Kühlnische ruhen die Fliegen (Anzahl × 0), die Geruchsschwaden laufen mit × 0,5. Der Farbüberzug der Stufe bleibt ehrlich. Ein kalter Hauch (2 Partikel je belegter Nische, warmgrau-bläulich, die bestehende Rauchtextur) zeigt die Kühle.
- **Nischen** (`CryptNiche`, `slot_id` `niche_1…6`, `min_level` 1/1/2/2/3/3): „[E] In die Kühlnische legen" · „[E] Leiche aus der Nische nehmen" · gesperrt: „Die Nische ist noch vermauert." Die Belegung wird wie beim Tisch aus den Records abgeleitet (`location &"niche"`, `slot_id`); die Nische selbst speichert nichts.
- `CryptConfig`: `niches_by_level [0, 2, 4, 6]`, `niche_factor_by_level [1.0, 0.5, 0.4, 0.3]`, `room_factor_by_level [1.0, 0.8, 0.7, 0.6]`, `ossuary_by_level [0, 3, 5, 6]`, `stench_exempt true`, Beinhaus-Werte §2.3.

### 2.3 Das Beinhaus – alte Gebeine umbetten (`data/ossuary/old_graves/<grave_id>.tres` – `OldGraveData`, `CryptConfig`)
**Entscheidung: Die Umbettung macht verwitterte Altgräber wieder frei (Bestätigung §14.2).** Im Alten Hof liegen seit dem Art-Prototyp 8 alte Gräber (`old_01…08`, Zustand `GraveRecord.State.OLD`). Ein Beinhaus ist historisch genau dafür da: Nach der Ruhezeit hebt man die Gebeine, bringt sie trocken ins Beinhaus, und die Stelle nimmt einen neuen Toten auf. *Begründung:* Der Friedhof ist nach Phase 4 voll, seitdem kommen keine Lieferungen mehr (G5: Einnahme nur Pflegegeld 4/Tag). Ohne neue Leichen hätten Gruft-Tisch, Kühlnischen und Aussegnung nichts zu tun. Die Umbettung verbindet die drei Gebäude: Beinhaus → freie Stelle → Leiche → Gruft → Kapelle → Grab. Sie ist zugleich die Einnahmequelle, die die Bauten bezahlt (§2.8). Es braucht keine neue Liefer- oder Grabstellenlogik: Die bestehende Regel „eine Lieferung je freie Stelle" greift von selbst.

**Die Altgräber** (Leitdaten, eigene Namen; `died_year` nach `StoneConfig.calendar`, Spieljahr 1834)
| Grab | Stein / Hügel | Name | Jahre | hebbar | Zeile beim Beisetzen |
|---|---|---|---|---|---|
| `old_01` | Kreuz, frisch | Wendel Gratz | 1779–1833 | **nein** (Ruhezeit) | – |
| `old_02` | rund, grasig | Agnes Hollweg | 1741–1789 | ja | „Agnes Hollweg. Trocken jetzt, und bei den anderen." |
| `old_03` | Obelisk, grasig | Konrad Pfister, Ratsherr | 1702–1771 | ja | „Konrad Pfister, Ratsherr. Der Obelisk war größer als das, was von ihm übrig ist." |
| `old_04` | alte Platte, eingesunken | Barbe Lindt | 1730–1758 | ja | „Barbe Lindt. Achtundzwanzig Jahre. Die Platte hat sie länger gehalten als das Leben." |
| `old_05` | rund, grasig | Mattheis Korb | 1755–1797 | ja | „Mattheis Korb. Jemand hat ihm einen Knopf mitgegeben. Er bleibt bei ihm." |
| `old_06` | Kreuz, eingesunken | Hanne Sörgel | 1748–1782 | ja | „Hanne Sörgel. Das Kreuz war morsch, die Knochen nicht." |
| `old_07` | alte Platte, grasig | Elias Brand, Totengräber | 1690–1751 | ja | „Elias Brand, Totengräber zu Hollerbrück. Einer von uns. Er hat lange genug gewartet." |
| `old_08` | rund, frisch | Dorothee Mahn | 1788–1831 | **nein** (Ruhezeit) | – |
- **Ruhezeit:** hebbar nur, wenn `Spieljahr − died_year ≥ CryptConfig.min_rest_years (30)`. `old_01` und `old_08` (frische Hügel) bleiben stehen: „Die Ruhezeit ist nicht um. Hier liegt noch keiner lange genug." *Begründung:* Die zwei jungen Gräber mit Kreuz und rundem Stein bleiben als Teil der freigegebenen Komposition erhalten, und die Ruhezeit ist eine ehrliche, lesbare Grenze. **6 hebbare Stellen**, genau die Beinhaus-Plätze auf Stufe 3.
- Die Namen sind Flair. Sie erzählen keinen neuen Faden (§13). Elias Brand ist ein früherer Totengräber und bekommt nur diese eine Zeile.

**Ablauf**
1. **Gebeinkiste** zimmern: Werkbank-Rezept `bone_box` (3 wood → 1 `bone_box`, 15 Min).
2. **Altes Grab heben** am Altgrab: „[E] Altes Grab heben: Agnes Hollweg (1741–1789)". Voraussetzung: `buildings_open`, Gruft ≥ 1, ein freier Beinhaus-Platz (`gehoben + beigesetzt < ossuary_by_level[Stufe]`), 1 `bone_box`, Schaufel. Dauer 60 / 50 / 35 Min nach Schaufel-Stufe (Phase-5-Faktoren), abbrechbar ohne Verlust. Am Ende: `bone_box` → `bone_box_full`, `Graveyard.lift_old(grave_id)` setzt **OLD → EMPTY**, und das Altgrab ist ab sofort eine normale Grabstelle. Stein und Hügel verschwinden, die Stelle zeigt die leere Grabstelle. Beim Ausheben liegt der Aushub am **Fußende** (Variante `ph_prop_grave_pit_foot`), weil die Altgräber enger stehen (1,8–1,9 m) als die Phase-3-Reihen (2,4 m). Sperrtexte: „Keine Gebeinkiste – an der Werkbank zimmern." · „Das Beinhaus ist voll – erst die Gruft ausbauen." · „Die Gruft ist noch verschüttet."
3. **Gebeine beisetzen** in der Gruft an der Beinhaus-Nische: „[E] Gebeine beisetzen (20 Min)". Das nimmt 1 `bone_box_full` und die **älteste** noch nicht beigesetzte Hebung (Reihenfolge des Hebens; die Kiste trägt keine eigenen Daten, Lehre aus Phase 5 §2.5). Wirkung: **Umbettgeld 4 Münzen** (Gemeinde), Ruf `reinterred +1`, Pietät `reinterred +1`, die Zeile aus der Tabelle als Notiz. Der **alte Grabstein** dieses Grabes lehnt ab jetzt im Beinhaus an der Wand (dasselbe Modell, §4.8), ab Gruft 3 steht der Name auf der Namenstafel.
- Gehoben und noch nicht beigesetzt belegt einen Beinhaus-Platz. Die Kiste darf in Truhe oder Schuppen liegen, sie verfällt nicht. Ilse kauft sie nicht.
- Die gehobene Stelle nimmt eine neue Leiche auf wie jede andere (Graben, Bestatten, Zeichen, Qualität, Bezahlung, Geist). Eine eigene Pflegestelle bekommt sie in Phase 6 nicht (§13); für die Geisterstimmung zählt sie als sauber (Stufe 0).
- Die Friedhofsqualität sinkt durch das Heben nicht (`old_grave_quality 0`). Die Stufe „Ehrwürdig" und das Flag `cemetery_complete` bleiben unberührt.

**Der vermauerte Gang – Blick in die Tiefe (Haken Phase 12)**
- **Gruft 2:** Beim Ausbau des Beinhauses kommt hinter dem Gebeinregal eine vermauerte Tür zum Vorschein (`SealedPassage`). „[E] Die vermauerte Tür ansehen": „Hinter dem Beinhaus eine zugemauerte Tür, jünger als das Gewölbe. Durch die Fugen zieht es kalt. Der Zug kommt von Nordosten, von unter dem Hof her, Richtung Birkenhang." Das ergibt den **Hinweis** `c_crypt_draft` „Der kalte Zug" im Merkbuch. Er bildet mit nichts eine Erkenntnis und steht unter „Offen" mit der Randnotiz „Unter dem Birkenhang ist es nicht still." (Phase-4-Zitat).
- **Gruft 3:** Ein Stein der Vermauerung ist durch ein **Eisengitter** ersetzt. „[E] Durch das Gitter sehen": „Stufen, die weiter hinabführen, als die Laterne reicht. Ganz unten ein Schimmer, bläulich, der nicht flackert wie Feuer." Hinter dem Gitter liegt ein kaltes, schwaches Licht (`OmniLight3D` `#7FA0C8`, Energie 0,25, Reichweite 2,5 m, ohne Schatten, langsames Pulsieren 0,1 Hz). Es ist nur durch das Gitter zu sehen, man kommt nicht hindurch. Kein Hinweis, keine Erkenntnis. Phase 12 öffnet das Gitter.
- *Begründung:* Die Gruft liegt unter der Eiche, die Krypten aus Phase 4 §1.4 unter dem Birkenhang. Ein Gang, der von hier dorthin zieht, verbindet beide, ohne etwas vorwegzunehmen.
- `CryptConfig`: `lift_minutes 60`, `reinter_minutes 20`, `reinter_fee 4`, `box_item &"bone_box"`, `full_item &"bone_box_full"`, `min_rest_years 30`, `passage_level 2`, `grille_level 3`, `passage_clue &"c_crypt_draft"`.

### 2.4 Die Kapelle – Aussegnung und Andacht (`data/config/chapel_config.tres` – `ChapelConfig`)
**Entscheidung: Der Totengräber hält die Aussegnung selbst, als Laienritus, bis Phase 8 einen Pfarrer bringt.** *Begründung:* Der Küster oder Totengräber, der am Sarg ein Gebet spricht, ist historisch belegt und braucht kein neues NPC-System. Die Handlung ist einfach: Leiche aufbahren, Kerze anzünden, 45 Minuten Ritus. Die Wirkung ist klar und über Stufen steigerbar. In Phase 8 kann der Pfarrer dieselbe Schnittstelle (`ChapelRites.hold_service`) mit stärkerer Wirkung nutzen, der Laienritus bleibt dann als Rückfall.

**Aussegnung (Trauerfeier vor der Bestattung)**
- **Wo und wie:** Die Leiche wird in die Kapelle getragen und auf den **Katafalk** vor dem Altar gelegt (`LOCATION_CATAFALQUE`, `room &"chapel"`). Am Altar steht dann: „[E] Aussegnung halten (45 Min)". Das ist eine TimedAction, nicht abbrechbar, Animation `interact`.
- **Wann:** Beginn zwischen **08:00 und 17:00** (`service_start_min 480`, `service_start_max 1020`). Außerhalb: „Die Trauergäste kommen nur bei Tag." Nachts ist die Kapelle offen, für Andachten (siehe unten).
- **Voraussetzungen:** Leiche eingekleidet (Leichentuch oder Totenhemd: „Erst einkleiden – so legt man niemanden vor den Altar."); Frische ≥ 0,3, also nicht verwesend („Zu spät für eine offene Aussegnung."); noch nicht ausgesegnet; 1 `altar_candle` („Keine Altarkerze – Osric hat welche.").
- **Wirkung am Ende** (sofort, einmal je Leiche; Werte je Kapellen-Stufe 1 / 2 / 3):
  | | Stufe 1 | Stufe 2 | Stufe 3 |
  |---|---|---|---|
  | Gebühr der Familie (Münzen sofort, „Die Familie legt X Münzen auf den Altar.") | 3 | 5 | 7 |
  | Ruf „Aussegnung" | +1 | +2 | +3 |
  | Trauergäste (stille Figuren in den Bänken) | 0 | 2 | 4 |
  | Pietät „Aussegnung" (nur unverwertete Leichen, wie der Phase-5-Fix) | +1 | +1 | +1 |
  - `record.service_held = true`, `service_day`. Beim späteren Grabzeichen erscheint die neue Qualitätszeile **„Ausgesegnet +1"** (`EconomyConfig.quality_service 1`, **`quality_max 19 → 20`**). Sie zahlt über `floor(Q × 0,5)` bis zu 1 Münze mehr.
  - Die Glocke (ab Stufe 2) schwingt sichtbar zu Beginn und am Ende. Trauergäste erscheinen mit einer Überblendung zu Beginn und gehen am Ende. Sie haben keinen Dialog und keine Namen, sie sind „Leute aus Hollerbrück".
  - Geist: In der ersten Nacht nach dem Grabzeichen spricht er einmal aus dem neuen Pool `by_service`: „Es waren Leute da. Für mich." · „Die Glocke hab ich gehört. Oder geträumt." · „Du hast etwas gesagt, drinnen. Ich hab es nicht verstanden. Es war trotzdem gut."
- Danach trägt man die Leiche zum Grab (Leichenzug). Die Aussegnung verfällt nicht: Sie gilt auch, wenn erst am nächsten Tag bestattet wird. Eine verwertete Leiche kann ausgesegnet werden (Gebühr und Ruf wie immer, die Familie weiß nichts), bekommt aber keine Pietät. Das bleibt still, ohne Anzeige.
- *Begründung Werte:* Eine Aussegnung kostet 2 Münzen (Kerze) und ≈ 2 h (Ritus + Leichenzug). Sie bringt auf Stufe 1 netto +1 Münze, +1 Ruf, +1 Qualität und einen besseren Geist, auf Stufe 3 netto +5–6 Münzen und +3 Ruf. Das lohnt, ist aber keine Goldgrube. Die Zeit ist der eigentliche Preis.

**Andacht (für ein bestehendes Grab, beruhigt Geister)**
- Am Altar, wenn der Katafalk leer ist: „[E] Andacht halten" öffnet eine Grabliste (`&"devotion"`) mit Name, Abschnitt, Geisterstimmung und „schon gehalten". Grab wählen → 30 Min, 1 `altar_candle`. Zu jeder Tageszeit möglich, auch nachts.
- Wirkung: dauerhafter **Stimmungsbonus** für diesen Geist (`GhostMood.score` + Andacht) = `devotion_mood_by_level[Stufe]` = **+1 / +2 / +3**. Einmal je Grab und Kapellen-Stufe: Nach dem Ausbau der Kapelle darf man für ein Grab erneut halten, dann gilt der höhere Wert (kein Aufsummieren). Pietät `devotion +1` einmal je Grab. Kein Ruf, die Andacht ist privat.
- **Beraubte Seelen:** Bei `robbed_count > 0` hebt die Andacht den Wert höchstens bis **8** (`devotion_robbed_cap`, oberste Stufe von „gleichmütig"). Eine beraubte Seele wird durch Kerzen nie „zufrieden". Das setzt die Phase-5-Linie fort („Ein Stein gibt nicht zurück, was genommen wurde"), gibt dem verwertenden Weg aber eine ehrliche, bezahlte Möglichkeit, das Unruhige zu dämpfen.
- Pool `by_devotion` (erste Nacht danach): „Da war ein Licht für mich. Nur für mich." · „Ich schlafe jetzt ein bisschen tiefer." · beraubt: „Eine Kerze. Und trotzdem fehlt mir etwas."
- *Zahlen:* Voll beraubt (Haar + Zähne) mit Meisterstein: 2 **unruhig** → Andacht 3: 5 **gleichmütig**. Mixed-Grab mit Zopf und schlichtem Stein: 4 → Andacht 2: 6 gleichmütig. Gleichmütiges Holzkreuz-Grab mit 8 → Andacht 1: 9 **zufrieden**.
- `ChapelConfig`: `service_minutes 45`, `service_start_min 480`, `service_start_max 1020`, `candle_item &"altar_candle"`, `candle_amount 1`, `service_min_freshness 0.3`, `service_needs_dress true`, `service_fee_by_level [0, 3, 5, 7]`, `service_rep_by_level [0, 1, 2, 3]`, `mourners_by_level [0, 0, 2, 4]`, `devotion_minutes 30`, `devotion_mood_by_level [0, 1, 2, 3]`, `devotion_robbed_cap 8`.

### 2.5 Der Lagerschuppen (`data/config/shed_config.tres` – `ShedConfig`)
- **Lager:** Im Schuppen-Innenraum steht ein Regal mit Lagerbuch (`ShedStore`, eine Erweiterung von `Chest`, `save_id "shed_store"`). „[E] Lager öffnen" öffnet das bestehende Panel `&"chest"` mit {storage, inventory, chest}; das Verschieben bleibt `ChestTransfer`. Plätze nach Stufe: **24 / 32 / 40** (`slots_by_level`); die Hüttentruhe (16) bleibt. Ab Stufe 3 doppelte Stapelgröße für `RESOURCE` und `MATERIAL` (`stack_mult_by_level [1, 1, 1, 2]`, `stack_categories [RESOURCE, MATERIAL]`). Beim Ausbau wachsen die Plätze, es geht nie etwas verloren.
- **Werkhof-Anschluss (Stufe 2):** An jeder Station (Werkbank, Steinmetzbank, Webstuhl, Esse), jedem Bauplatz (Werkhof und Gebäude) und im Stein-Panel zeigt die Zutatenliste „im Schuppen: 6". Fehlt etwas, das der Schuppen hat, erscheint der Knopf **„Fehlendes aus dem Schuppen holen (10 Min)"**. Er verschiebt genau die fehlenden Mengen vom Schuppen ins Spieler-Inventar, und zwar **atomar**: nur wenn der Schuppen alles Fehlende hat und das Inventar Platz hat, sonst gedimmt mit Grund („Im Schuppen fehlt: 2 Werkstein" · „Kein Platz im Inventar"). Danach wird gebaut oder gehandwerkt wie gewohnt. Stufe 3: 0 Min, dazu „Überschuss einlagern" (alle `RESOURCE`/`MATERIAL` des Spielers in den Schuppen; keine Werkzeuge, keine Münzen, keine Gebeinkisten).
- *Begründung Holen statt gemeinsamer Bestand:* Ein Rezept, das still aus zwei Inventaren zieht, wäre bequemer, aber undurchsichtig. Es müsste außerdem jede Phase-5-Prüfung (`WorkshopRules`, `Stonemasonry`, `CraftingRules`) doppelt können. Das Holen ist ein sichtbarer Schritt mit klarer Zeit und nutzt die bestehenden Prüfungen unverändert.
- `ShedConfig`: `slots_by_level [0, 24, 32, 40]`, `stack_mult_by_level [1, 1, 1, 2]`, `stack_categories [0, 6]` (`RESOURCE`, `MATERIAL`), `fetch_min_level 2`, `fetch_minutes_by_level [0, 0, 10, 0]`, `store_min_level 3`, `excluded_items [bone_box_full]`.

### 2.6 Items, Rezepte, Handel
| id | Name | Kategorie | Stapel | Herkunft | Zweck |
|---|---|---|---|---|---|
| `altar_candle` | Altarkerze | MATERIAL | 10 | Osric, **2 Münzen** (ab `buildings_open`) | Aussegnung, Andacht |
| `bone_box` | Gebeinkiste | MATERIAL | 5 | Werkbank `bone_box` (3 wood, 15 Min) | Altgrab heben |
| `bone_box_full` | Gebeinkiste (belegt) | MATERIAL | 3 | Altgrab heben | Beisetzen; nicht verkäuflich, nicht einlagerbar über „Überschuss" |
- Osric (`carter.tres`, P6): Kerzen im Menü: „Altarkerzen aus der Stadt, zwei Münzen das Stück. Sie brennen so lange wie ein Gebet, wenn man nicht trödelt." `coins_spent(&"osric")` wie in Phase 5.
- Keine neue Ware bei Ilse. Kein Verkauf von Gebeinen, Kisten oder Kerzen.

### 2.7 Qualität, Ruf, Pietät, Geister, Statistik
- `EconomyConfig` + `quality_service 1`, **`quality_max 20`** (19 + „Ausgesegnet"). Alte Gräber behalten ihre gespeicherte Qualität.
- `ReputationConfig.event_points` + `reinterred 1`. Die Aussegnung nutzt `ChapelConfig.service_rep_by_level` mit dem Grund „Aussegnung".
- `PietyConfig.events` + `service 1` (nur unverwertet), `devotion 1` (einmal je Grab), `reinterred 1`.
- `GhostConfig` + `devotion_robbed_cap 8`. `GhostMood.score(…, devotion: int = 0)`. `GhostLines` + `by_service`, `by_devotion`.
- `GameState.DEFAULT_STATS` + `services_held`, `devotions_held`, `bones_lifted`, `bones_reinterred`, `niche_waits` (Leichen, die ≥ 60 Min in einer Nische lagen).
- `coins_spent`-Zwecke + `&"building"`. Kerzen laufen unter `&"osric"`.
- Die Friedhofsstufen bleiben unverändert. Ausgesegnete Gräber heben die Qualität um +1, das macht bei 6 Stellen höchstens +6.

### 2.8 Münzrechnung (würdevoller Spieler)
**Ausgangslage (G5, `qa_playthrough.md`):** `reverent5` endet mit **27** Münzen. Einnahmen sind nur noch das Pflegegeld „Gerühmt" mit **4/Tag**, denn es kommen keine Leichen mehr. Den Morgenstand der v4-Fixture misst W0 (Erwartung ≈ 31). Anders als in Phase 5 gibt es **keinen großen Überschuss mehr**. Phase 6 bezahlt sich deshalb aus den Einnahmen, die sie selbst möglich macht: Umbettgeld, Bestattungen der neuen Toten und Gebühren der Aussegnung. Die Gebäude ziehen diesen Zufluss fast vollständig wieder ab. So wird die Münzsenke spürbar, ohne dass man verarmt.

**Einnahmen im Bogen A (10 Tage)**
| Quelle | Rechnung | Münzen |
|---|---|---|
| Start (B1 früh) | W0-Messung | ≈ 31 |
| Pflegegeld | 9 × 4 (B2–B10) | 36 |
| Umbettgeld | 6 × 4 | 24 |
| Bestattungen der neuen Toten | 5 × ≈ 14 (G5: 11/Grab ohne Steingestaltung; mit Stele, Inschrift, voll hergerichtet und „Ausgesegnet" ≈ 14) | 70 |
| Aussegnungsgebühren | 5 × 3 (alle noch auf Kapellen-Stufe 1) | 15 |
| Geistergaben (neue zufriedene Geister) | ≈ 4 × 2 | 8 |
| **Verfügbar** | | **≈ 184** |

**Ausgaben**
| Posten | Münzen |
|---|---|
| Gruft 1 + 2 · Kapelle 1 + 2 · Schuppen 1 + 2 (Pflicht) | 20 + 30 + 25 + 30 + 10 + 15 = **130** ((geändert 04.10.2026, Benutzerwunsch: Gruft von Beginn an): Gruft 1 entfällt, Gruft 2 kostet 35 → **115**; Bilanz §2.8a) |
| 1 Altarkerze für die erste Aussegnung (Pflicht) | 2 |
| **Summe Pflicht** | **132 (72 %)** |
| Freiwillig (so spielt `reverent6`): 4 weitere Aussegnungen und 2 Andachten (6 Kerzen) · **Gruft 3** an B10 | 12 + 35 = 47 |
| **Summe** | **179 (97 %)** |

**Verlauf (Bogen A, §1.4)**
| | B1 | B2 | B3 | B4 | B5 | B6 | B7 | B8 | B9 | B10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Morgens (+4 ab B2) | 31 | 27 | 21 | 30 | 27 | 33 | 24 | 26 | 32 | 36 |
| Ausgaben | 20 | 27 | 12 | 32 | 17 | 32 | 4 | 0 | 0 | 35 |
| Einnahmen (ohne Pflegegeld) | 12 | 17 | 17 | 25 | 19 | 19 | 2 | 2 | 0 | 4 |
| Abends | 23 | 17 | 26 | 23 | 29 | 20 | 22 | 28 | 32 | 5 |
- Morgens nie unter **21** (B3). Ohne Gruft 3 endet der Bogen bei ≈ 38, mit Gruft 3 bei ≈ 5 (das war dann die eigene Wahl). B2 geht zwischenzeitlich auf 0: Kapelle und Kerze kosten 27, bevor Gebühr und Bestattung kommen. Wer vorsichtig ist, baut die Kapelle an B3.
- *Warum nicht arm:* Jede Ausgabe ist ein bleibender Gewinn (Stufe, Stelle, Ritus). Kerzen sind der ruhige Dauerabfluss. Phase-4-Käufe (Leinen, Wacholder) bleiben jederzeit bezahlbar.
- **Nach der sechsten Umbettung ist der Friedhof wieder voll.** Die höheren Gebühren der Kapellen-Stufen 2 und 3 (5 / 7) und die dritte bis sechste Kühlnische wirken dann erst, wenn es wieder freie Stellen gibt (§14.2).

**§2.8a Nachrechnung (geändert 04.10.2026, Benutzerwunsch: Gruft von Beginn an).** Mit Gruft 1 ab Start spart der Spieler am Bogenbeginn 20 Münzen und 12 stone, 6 wood, 4 clay, 2 iron_fittings. Gemessen mit `reverent6` (v4-Fixture, 27 Münzen, 10 Tage) ohne Ausgleich: Kapitel weiter Tag 37, 5 Aussegnungen (vorher 3), 5 Umbettungen, Ende **47** (vorher 20, Testband 0–45), morgens nie unter 19. Die Bilanz kippt damit sichtbar ins Reiche. **Ausgleich (maßvoll): Gruft 2 kostet 35 statt 30 Münzen.** Pflicht 115 statt 130; der Spieler behält gegenüber dem Vertrag 15 Münzen Vorsprung, was Befund B6-1 (knapper Start) etwas entschärft. Probe mit 40: Ende 37, aber morgens einmal nur 9 (Testband ≥ 12, B3/B4 zu knapp) – deshalb 35. Gemessen mit 35: `reverent6` Kapitel Tag 37, Ende 42, morgens ≥ 14, 5 Aussegnungen; `mortician` Tag 38 (Ende 28); `mender6` Tag 37 (Ende 55); `harvester6` Tag 41 (Ende 111); `founder` (neues Spiel) Tag 27 (Ende 43). Material der entfallenen Stufe 1 wird nicht umgelegt (Eisen bleibt der Engpass über Gruft 2/Kapelle).

**Andere Wege (Erwartung für W3)**
| Weg | Start | Einnahmen | Ausgaben Phase 6 | Ende (≈ 10 Tage) | Bemerkung |
|---|---|---|---|---|---|
| verwertend (`harvester6`, v4 Endstand ≈ 102) | ≈ 102 | Pflegegeld 0–1, Bestattungen ≈ 6 × 9 (Ruf niedrig), Umbettgeld 24, Gebühren 18, Verwertung nach Laune | Pflicht 132, alle Stufe 3 (95), 14 Andachten für beraubte Seelen (28) | ≈ 0–40 | Das beantwortet G5-Befund E5: Stufe 3 und Kerzen sind die Senke des reichen Wegs. Die beraubten Seelen werden höchstens gleichmütig |
| Ausgleich (`mender6`, v4 mender) | ≈ 41 | wie A | Kapelle zuerst, Andachten | ≈ 10–30 | zufriedene Geister + ≥ 3 |
| neues Spiel (`founder`) | 27–53 bei `names_in_stone` | wie A | wie A | ≈ 5–40 | Kapitel ≤ Tag 36 |

### 2.9 Übertrag aus Phase 5
- **G5-Befund E5 (verwertender Weg bleibt reich):** Phase 6 ändert keine Phase-5-Werte. Die Senke für den reichen Weg sind Stufe 3 und Andachten (§2.8). Eine echte Preisdynamik bleibt Phase 10.
- Der Werkhof, alle Rezepte, Werkzeuge und Steine bleiben unverändert. Der Schuppen ergänzt sie nur (§2.5).

---

## 3. Architektur

### 3.1 Neue Systemknoten (unter `WorldRoot/Systems`, vom Welt-Builder angelegt)
| Knoten | Klasse | Gruppen | save_id / save_order |
|---|---|---|---|
| `Buildings` | `Buildings` | `buildings`, `saveable` | `buildings` / **32** |
| `Ossuary` | `Ossuary` | `ossuary`, `saveable` | `ossuary` / **36** |
| `Chapel` | `ChapelRites` | `chapel_rites`, `saveable` | `chapel` / **37** |
Entitäten (§4): `Entities/site_crypt|site_chapel|site_shed` (`BuildingSite`), `Entities/door_crypt|door_chapel|door_shed` (`BuildingDoor`), `Entities/obs_c_gate` (`ClearableObstacle`, Kirchpforte). Innenräume (§4.7): `Interiors/CryptInterior|ChapelInterior|ShedInterior` (`InteriorRoom`-Szenen). Darin: `MorgueTable` (Gruft), `CryptNiche` × 6, `OssuaryShelf`, `SealedPassage`, `Catafalque`, `ChapelAltar`, `MournerSet`, `ShedStore` (saveable, `shed_store` / **61**), `RoomExit` je Raum. Die Hütte bleibt `HutInterior`. Keine neuen Autoloads. `CorpseManager` (0) speichert die neuen Record-Felder, `Graveyard` (10) den Zustand der Altgräber (bestehendes `state`).

### 3.2 Module & Besitz (Phase 6)
| Modul | Besitzt (Pfade) |
|---|---|
| **Lead** (W0 + laufend) | `project.godot`, `src/core/*` (EventBus, Database), alle **Datenklassen ✦**, alle **Stubs** (bis zur Übergabe), `tests/run_tests.gd`, `tests/framework/*`, `tests/fixtures/*` (inkl. **`saves_v4/*`**, `phase6/*`), `tests/integration/test_saves_v4_load.gd`, `tests/unit/test_phase6_scaffold.gd`, `docs/*`, `CLAUDE.md` |
| **P1 Gebäude, Bau & Schuppen** | `src/systems/buildings/{buildings,building_rules,shed_supply}.gd`, `src/entities/building_site/*`, `src/entities/shed_store/*`, `src/entities/workbench/workbench.gd` + `src/entities/build_site/build_site.gd` (nur `request_fetch`/`request_store`), `src/systems/inventory/inventory.gd` (nur `stack_multiplier`/`stack_categories`), `src/systems/decoration/decoration_manager.gd` (nur Aufruf `evict_rects` für `site_rects`, keine Änderung der Methode), `data/buildings/*`, `data/config/{buildings_config,shed_config}.tres`, `tests/unit/{test_buildings,test_shed}.gd` |
| **P2 Gruft & Leichen** | `src/systems/corpse/{corpse_manager,corpse_decay,corpse_record,corpse_save_codec}.gd` (Nischen, Räume, Kältefenster, Tischwechsel, Gestank-Ausnahme, `mark_service`), `src/entities/morgue_table/*` (`room`, `requires_level`, `retire_at_level`), `src/entities/crypt_niche/*`, `src/entities/corpse/{corpse_decay_visual,decay_visual_config}.gd`, `data/config/{crypt_config,decay_visual_config}.tres`, `tests/unit/{test_crypt,test_corpse_decay,test_corpse_manager,test_morgue_table}.gd` |
| **P3 Beinhaus & Altgräber** | `src/systems/ossuary/{ossuary,ossuary_rules}.gd`, `src/entities/ossuary_shelf/*`, `src/entities/sealed_passage/*`, `src/systems/graveyard/graveyard.gd` (`lift_old`, Laden der Altgrab-Zustände), `src/entities/grave/{grave_plot,grave_plot_visuals}.gd` (Heben-Prompt, Aushub am Fußende, OLD → EMPTY ohne Neuaufbau), `data/ossuary/**`, `data/items/{bone_box,bone_box_full}.tres`, `data/recipes/bone_box.tres`, `data/journal/clues/c_crypt_draft.tres`, `tests/unit/{test_ossuary,test_graveyard,test_grave_plot}.gd` |
| **P4 Kapelle, Qualität & Geister** | `src/systems/chapel/{chapel_rites,chapel_rules}.gd`, `src/entities/{catafalque,chapel_altar,mourner_set}/*`, `data/config/chapel_config.tres`, `data/items/altar_candle.tres`, `src/systems/graveyard/grave_quality.gd`, `data/config/{economy_config,ghost_config,reputation_config,piety_config}.tres`, `src/systems/ghosts/{ghost_mood,ghost_manager}.gd`, `data/ghosts/ghost_lines.tres`, `tests/unit/{test_chapel,test_grave_quality,test_ghosts,test_piety}.gd` |
| **P5 Assets** | `tools/blender/{asset_buildings_phase6,asset_interiors_phase6,asset_props_phase6}.py` (neu), `tools/blender/asset_items.py`, `tools/blender/build_all.py`, `assets/models/**` (nur neue Phase-6-Dateien), `art_source/blender/**` (Phase 6), `tests/unit/test_assets_phase6.gd`, `docs/reviews/phase6_assets/*` |
| **P6 Innenraum-Kern, Speichern & Dialog** | `src/world/interiors/{interior_room,room_exit}.gd` (neu), `src/entities/building_door/*`, `src/world/hut_interior/{hut_interior,hut_portal,interior_lighting,interior_config}.gd` (Verallgemeinerung §3.4, Verhalten der Hütte bitgleich), `src/entities/player/player.gd` (nur `interior_id`), `src/world/camera/camera_rig.gd` (unverändert außer Bedarf), `data/config/interiors/*` (Raum-Configs), `src/systems/save/{save_migration,save_file_io,save_manager}.gd`, `src/systems/game_state/game_state.gd` (Stats), `data/dialogue/carter.tres`, `tests/unit/{test_interior_room,test_save,test_save_migration,test_dialogue,test_game_state}.gd`, `tests/integration/{test_hut_interior,test_phase5_save_upgrade}.gd` |
| **W-Welt** (W2) | `data/world/graveyard_layout.json` (Bauplätze, Kirchpforte, Kirchhof, Schuppen-Tasche, Versetzungen §4), `data/world/interiors/{crypt,chapel,shed}_layout.json`, `src/world/interiors/{interior_build,interior_builder}.gd` + `{crypt,chapel,shed}_interior.tscn`, `src/world/graveyard/*` (neu `graveyard_build_phase6.gd`, `graveyard_shots_phase6.gd`, Bau-Maske und Gras neu gebacken), `tools/blender/asset_ground_graveyard.py` (Bodenerweiterung Nord), `tests/integration/{test_graveyard_world,test_phase6_loop,test_interiors}.gd`, `docs/reviews/phase6_round1/*` |
| **W-UI** (W2) | `src/ui/**` (neu `panels/{building_panel,chapel_panel,devotion_panel}.gd`, `phase6_texts.gd`; Holen-Knopf in `crafting`/`build_site`/`stone_design`), `assets/ui/**`, `tools/ui/*`, `src/debug/*` (neu `debug_commands_phase6.gd`; außer `asset_preview.gd`, `screenshot_capture.gd`), `tests/unit/{test_ui,test_objective,test_ui_phase6}.gd`, `tests/integration/test_ui_flow.gd` |
| **W3 QA** | `tests/integration/{phase3_bot,phase4_bot,phase5_bot,phase6_bot,test_phase3_playthrough,test_phase4_playthrough,test_phase5_playthrough,test_phase6_playthrough,test_phase6_qa,test_save_fuzzer}.gd`, `docs/reviews/phase6_wip/*` |
| **Eingefroren** | `src/world/art_prototype/*`, `src/entities/player/player_proto.*`, `data/art_prototype/*`, **Maler-Shader**, `data/atmosphere/*`, `data/world/hut_interior_layout.json` und `hut_interior.tscn` (Inhalt der Hütte), Abschnitte I–IV und Werkhof im Layout (außer §4.1–§4.4), **Hütte, Werkbank, Stationen, Pförtchen, Ostpforte** |

✦ **Datenklassen (W0, Lead):** `BuildingData`, `BuildingLevelData`, `BuildingsConfig`, `CryptConfig`, `OldGraveData`, `ChapelConfig`, `ShedConfig`. Erweiterungen: `CorpseRecord` (+ `LOCATION_NICHE`, `LOCATION_CATAFALQUE`, `room`, `slot_id`, `cold_windows`, `service_held`, `service_day`), `EconomyConfig` (+ `quality_service`, `quality_max 20`), `GhostConfig.devotion_robbed_cap`, `GhostLines` (+ `by_service`, `by_devotion`), `ReputationConfig.event_points` (+ `reinterred`), `PietyConfig.events` (+ `service`, `devotion`, `reinterred`), `DecayVisualConfig` (+ `niche_fly_scale 0`, `niche_wisp_scale 0.5`, `niche_chill_particles 2`), `InteriorConfig` (+ `fog_enabled`, `fog_color`, `fog_density`, `shaft_role_as_window`), `Inventory` (+ `stack_multiplier`, `stack_categories`; nur Felder, Wirkung P1).
Bei nur fünf Agents übernimmt P1 zusätzlich P6.

### 3.2.1 Klassen → Dateien
| Klasse | Datei | Art |
|---|---|---|
| `BuildingData`, `BuildingLevelData`, `BuildingsConfig` | `src/systems/buildings/{building_data,building_level_data,buildings_config}.gd` | ✦ |
| `BuildingRules`, `Buildings`, `ShedSupply` | `src/systems/buildings/{building_rules,buildings,shed_supply}.gd` | Stub (P1) |
| `ShedConfig` | `src/systems/buildings/shed_config.gd` | ✦ |
| `BuildingSite` | `src/entities/building_site/building_site.gd` (+ `.tscn`) | Stub (P1) |
| `ShedStore` | `src/entities/shed_store/shed_store.gd` (+ `.tscn`, `extends Chest`) | Stub (P1) |
| `CryptConfig` | `src/systems/corpse/crypt_config.gd` | ✦ |
| `CryptNiche` | `src/entities/crypt_niche/crypt_niche.gd` (+ `.tscn`) | Stub (P2) |
| `OldGraveData` | `src/systems/ossuary/old_grave_data.gd` | ✦ |
| `OssuaryRules`, `Ossuary` | `src/systems/ossuary/{ossuary_rules,ossuary}.gd` | Stub (P3) |
| `OssuaryShelf`, `SealedPassage` | `src/entities/{ossuary_shelf,sealed_passage}/*.gd` (+ `.tscn`) | Stub (P3) |
| `ChapelConfig` | `src/systems/chapel/chapel_config.gd` | ✦ |
| `ChapelRules`, `ChapelRites` | `src/systems/chapel/{chapel_rules,chapel_rites}.gd` | Stub (P4) |
| `Catafalque`, `ChapelAltar`, `MournerSet` | `src/entities/{catafalque,chapel_altar,mourner_set}/*.gd` (+ `.tscn`) | Stub (P4) |
| `InteriorRoom`, `RoomExit` | `src/world/interiors/{interior_room,room_exit}.gd` | Stub (P6) |
| `BuildingDoor` | `src/entities/building_door/building_door.gd` (+ `.tscn`) | Stub (P6) |
| `BuildingPanel`, `ChapelPanel`, `DevotionPanel` | `src/ui/panels/{building_panel,chapel_panel,devotion_panel}.gd` | W-UI |

### 3.3 EventBus – neue Signale (Ergänzung `src/core/event_bus.gd`)
```gdscript
# Gebäude (Buildings)
signal building_upgraded(building_id: StringName, level: int)
# Innenräume (Player.set_in_interior) – "" = draußen; interior_changed(inside) bleibt und kommt zuerst
signal interior_room_changed(room_id: StringName)
# Beinhaus (Ossuary)
signal bones_lifted(grave_id: String)
signal bones_reinterred(grave_id: String, count: int)
# Kapelle (ChapelRites)
signal funeral_held(corpse_id: String, chapel_level: int, fee: int)
signal devotion_held(grave_id: String, bonus: int)
# Schuppen (ShedSupply über die Entität)
signal shed_supply_moved(items: Dictionary, direction: StringName)     # &"fetch" | &"store"
```
Regel wie Phase 3–5: **Listener ändern keinen Spielzustand.** Wer ändert, ruft direkt auf: `BuildingSite` → `Buildings.upgrade` → (Gruft 1) `CorpseManager.relocate_table_corpse`, (jede Gruft-Stufe) `CorpseManager.restart_cold`, `Ossuary.on_crypt_level`, `ShedStore.apply_level`, `InteriorRoom.apply_level` (über `Buildings.apply_levels()`); `GravePlot` → `Ossuary.lift` → `Graveyard.lift_old`; `OssuaryShelf` → `Ossuary.reinter`; `ChapelAltar` → `ChapelRites.hold_service` → `CorpseManager.mark_service`; `Buildings.check_goal` wird von `Buildings.upgrade`, `Ossuary.reinter` und `Graveyard.place_marker`/`set_designed_stone` (nur wenn die Leiche `service_held` hat) direkt gerufen. `coins_spent` erhöht `stats.coins_spent` im Sender über `GameState.note_coins_spent` (QA5-01).

### 3.4 Logik-Klassen (Signaturen = Vertrag)

**Gebäude & Bau (P1)**
```gdscript
class_name BuildingLevelData extends Resource        # ✦ Teil von BuildingData.levels
@export var level: int = 1; @export var title: String = ""
@export var inputs: Dictionary[StringName, int] = {}; @export var coins: int = 0; @export var minutes: int = 180
@export var coin_part_label: String = ""             # „Kalk und Mörtel aus Hollerbrück"
@export_multiline var text: String = ""              # Panel-Beschreibung
@export var adds: PackedStringArray = []            # „2 Kühlnischen", „Beinhaus: 3 Plätze" …
@export var model: PackedScene                      # Außenmodell dieser Stufe
class_name BuildingData extends Resource             # ✦ data/buildings/<id>.tres (§2.1)
@export var id: StringName; @export var display_name: String; @export var order: int = 0
@export var site_id: String; @export var door_id: String; @export var room_id: StringName
@export var model_site: PackedScene                 # Stufe 0
@export var levels: Array[BuildingLevelData] = []
@export var allows_corpse: bool = true              # Gruft, Kapelle true; Schuppen false
@export var prompt_enter: String = ""; @export var prompt_exit: String = ""   # „[E] Gruft betreten" / „[E] Hinaufgehen"
func level_data(level: int) -> BuildingLevelData    # null außerhalb 1…max
func max_level() -> int
class_name BuildingsConfig extends Resource          # ✦ §2.1 (Werte dort)
@export var unlock_flag: StringName = &"names_in_stone_complete"; @export var open_flag: StringName = &"buildings_open"
@export var intro_minute: int = 360; @export var goal_levels: Dictionary[StringName, int] = {&"crypt": 2, &"chapel": 2, &"shed": 2}
@export var goal_services: int = 1; @export var goal_reinterred: int = 1
@export var chapter_id: StringName = &"roof_and_earth"; @export var goal_flag: StringName = &"roof_and_earth_complete"
@export var cleared_flag: StringName = &"building_sites_cleared"
class_name BuildingRules extends RefCounted
static func next_level(data: BuildingData, level: int) -> BuildingLevelData                       # null = voll ausgebaut
static func upgrade_block_reason(data: BuildingData, level: int, inv: Inventory, open: bool) -> String   # "" | „Voll ausgebaut." | „Es fehlt: …"
static func missing(level_data: BuildingLevelData, inv: Inventory) -> Dictionary                  # {item_or_coin: fehlend}
static func goal_progress(levels: Dictionary, services: int, reinterred: int, cfg: BuildingsConfig) -> Dictionary   # {done, total, missing: PackedStringArray}
class_name Buildings extends Node                     # Systems/Buildings
@export var site_rects: Array[Rect2] = []           # vom Builder (Footprint + Rand + Zugang der Gruft); Zier dort einmal räumen
func is_open() -> bool; func level(building_id: StringName) -> int; func levels() -> Dictionary[StringName, int]
func upgrade_block_reason(building_id: StringName, inv: Inventory) -> String
func upgrade(building_id: StringName, inv: Inventory) -> bool   # atomar; building_upgraded; note_coins_spent(&"building"); apply_levels; Gruft 1: relocate_table_corpse; check_goal
func apply_levels() -> void                          # Räume, Tische, Nischen, Schuppen, Kältefenster auf den Stand bringen (auch post_load)
func goal_progress() -> Dictionary; func check_goal() -> void    # §1.5 einmalig
func apply_morning(day: int) -> void                  # idempotent: buildings_open ab unlock_flag (erste Minute ≥ intro_minute)
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void; func post_load() -> void   # post_load: v4 → sofort offen; site_rects räumen (§5.2)
class_name BuildingSite extends Node3D                # Entities/site_<id>; sichtbar ab buildings_open
@export var building_id: StringName
func refresh() -> void                                # Modell der Stufe (0 = model_site), Kollision, Prompt
func request_upgrade() -> void                        # Panel &"building": TimedAction minutes (nicht abbrechbar) → Buildings.upgrade
func request_fetch() -> void                          # Schuppen ≥ 2: fehlende Baustoffe holen (ShedSupply)
class_name ShedConfig extends Resource               # ✦ §2.5
@export var slots_by_level: PackedInt32Array = [0, 24, 32, 40]; @export var stack_mult_by_level: PackedInt32Array = [1, 1, 1, 2]
@export var stack_categories: Array[int] = [0, 6]; @export var fetch_min_level: int = 2
@export var fetch_minutes_by_level: PackedInt32Array = [0, 0, 10, 0]; @export var store_min_level: int = 3
@export var excluded_items: Array[StringName] = [&"bone_box_full"]
class_name ShedSupply extends RefCounted
static func shortfall(needs: Dictionary, inv: Inventory) -> Dictionary                             # {id: fehlend} (Münzen ausgenommen)
static func available(needs: Dictionary, shed: Inventory) -> Dictionary                            # {id: im Schuppen}
static func fetch_block_reason(needs: Dictionary, player_inv: Inventory, shed: Inventory, level: int, cfg: ShedConfig) -> String
static func fetch(needs: Dictionary, player_inv: Inventory, shed: Inventory) -> Dictionary           # atomar; {id: bewegt} | {}
static func store_surplus(player_inv: Inventory, shed: Inventory, cfg: ShedConfig) -> Dictionary     # Stufe 3; {id: bewegt}
class_name ShedStore extends Chest                    # Innen Schuppen; save_id "shed_store", save_order 61; PANEL &"chest"
func apply_level(level: int) -> void                  # slot_count, stack_multiplier; nie verkleinern
func store() -> Inventory                              # = storage
# Inventory (P1): @export var stack_multiplier: int = 1; @export var stack_categories: Array[int] = []   # leer = alle
#   _stack_limit(item) × stack_multiplier, wenn item.category in stack_categories; save/load unverändert
# Workbench / BuildSite (P1): func request_fetch(needs: Dictionary) -> void; func request_store() -> void
#   Stein-Panel ruft bench.request_fetch(design_inputs); Holen = TimedAction fetch_minutes (0 → sofort), danach shed_supply_moved
```

**Gruft & Leichen (P2)**
```gdscript
class_name CryptConfig extends Resource               # ✦ data/config/crypt_config.tres (§2.2, §2.3)
@export var niches_by_level: PackedInt32Array = [0, 2, 4, 6]
@export var niche_factor_by_level: PackedFloat32Array = [1.0, 0.5, 0.4, 0.3]
@export var room_factor_by_level: PackedFloat32Array = [1.0, 0.8, 0.7, 0.6]
@export var ossuary_by_level: PackedInt32Array = [0, 3, 5, 6]
@export var stench_exempt: bool = true
@export var lift_minutes: int = 60; @export var reinter_minutes: int = 20; @export var reinter_fee: int = 4
@export var box_item: StringName = &"bone_box"; @export var full_item: StringName = &"bone_box_full"
@export var min_rest_years: int = 30; @export var passage_level: int = 2; @export var grille_level: int = 3
@export var passage_clue: StringName = &"c_crypt_draft"
@export var room_id: StringName = &"crypt"; @export var niche_wait_minutes: int = 60
# CorpseRecord ✦ + const LOCATION_NICHE := &"niche", LOCATION_CATAFALQUE := &"catafalque" (an LOCATIONS angehängt)
#   + var room: StringName = &""      # &"crypt" | &"chapel" | "" (draußen)
#   + var slot_id: String = ""        # niche_1…6 bei LOCATION_NICHE
#   + var cold_windows: PackedInt32Array = []   # [start, ende (-1 = offen), faktor‰, …]
#   + var service_held: bool = false; var service_day: int = 0
#   to_dict/from_dict tolerant (fehlend = Default)
# CorpseDecay (P2):
static func effective_minutes(record: CorpseRecord, now_total: int, balm_factor: float) -> float   # jetzt über Räucher- UND Kältefenster, Rate = min(…)
static func cold_factor_at(record: CorpseRecord, total: int) -> float                               # 1.0 ohne offenes/überdeckendes Fenster
#   freshness_at / minutes_until: gleiche Signaturen, beide Fensterlisten
# CorpseManager (P2):
#   PLACE_LOCATIONS + LOCATION_NICHE, LOCATION_CATAFALQUE
func put_down(id: String, location: StringName, xform: Transform3D, parent: Node3D = null, room: StringName = &"", slot_id: String = "") -> bool
#   schließt das offene Kältefenster, öffnet ein neues, wenn cold_factor_for(location, room) < 1
func corpse_in_slot(location: StringName, slot_id: String) -> String   # "" = frei
func cold_factor_for(location: StringName, room: StringName) -> float  # CryptConfig × Buildings.level(&"crypt"); Nische → niche_factor, Tisch/Boden in der Gruft → room_factor
func restart_cold(now_total: int) -> void                               # Stufenwechsel: offene Fenster schließen und mit neuem Faktor öffnen
func relocate_table_corpse(xform: Transform3D, parent: Node3D, room: StringName) -> String   # Gruft 1: Leiche vom alten Tisch auf den Gruft-Tisch; id | ""
func mark_service(id: String, day: int) -> void                         # von ChapelRites; corpse_updated
#   pick_up / mark_buried schließen offene Kältefenster; _deliver: „Gestank am Tor" überspringt room == crypt (stench_exempt)
#   Nische ≥ niche_wait_minutes belegt → stats.niche_waits +1 beim Herausnehmen (einmal je Leiche)
# MorgueTable (P2): @export var room: StringName = &""; @export var requires_level: int = 0; @export var retire_at_level: int = 0
#   func is_active() -> bool     # Buildings.level(&"crypt") in [requires_level, retire_at_level) (retire 0 = nie)
#   inaktiv: unsichtbar, ohne Kollision, can_interact false; Requisiten mit meta "follows_table" folgen
#   interact → put_down(…, LOCATION_TABLE, slot, room); PROMPT/Panel wie bisher; Panel-Titel „Gruft-Tisch" bei room == crypt
class_name CryptNiche extends Node3D                   # Innen Gruft
@export var slot_id: String; @export var min_level: int = 1
func is_open() -> bool                                  # Buildings.level(&"crypt") ≥ min_level
func occupant() -> String                               # aus den Records
# can_interact/get_interaction_prompt/interact: ablegen (tragend, frei, offen) · aufnehmen (Hände frei, belegt) · „Die Nische ist noch vermauert."
# DecayVisualConfig ✦ + niche_fly_scale 0.0, niche_wisp_scale 0.5, niche_chill_particles 2
# CorpseDecayVisual: liest record.location == niche → Skalen; kalter Hauch an Marker „chill" der Nische
```

**Beinhaus & Altgräber (P3)**
```gdscript
class_name OldGraveData extends Resource               # ✦ data/ossuary/old_graves/<grave_id>.tres (§2.3)
@export var grave_id: String; @export var display_name: String
@export var born_year: int; @export var died_year: int; @export var reinter_line: String = ""
@export var stone_model: PackedScene                  # derselbe alte Stein (für das Beinhaus)
class_name OssuaryRules extends RefCounted
static func liftable(data: OldGraveData, year: int, cfg: CryptConfig) -> bool
static func lift_block_reason(grave: GraveRecord, data: OldGraveData, crypt_level: int, used: int, inv: Inventory, year: int, cfg: CryptConfig, open: bool) -> String
static func capacity(crypt_level: int, cfg: CryptConfig) -> int
static func label(data: OldGraveData) -> String        # „Agnes Hollweg (1741–1789)"
class_name Ossuary extends Node                         # Systems/Ossuary
func capacity() -> int; func used() -> int               # gehoben (wartend) + beigesetzt
func lift_block_reason(grave_id: String, inv: Inventory) -> String
func lift(grave_id: String, inv: Inventory) -> bool      # nach der TimedAction: bone_box → bone_box_full, Graveyard.lift_old, bones_lifted, stats.bones_lifted
func pending() -> PackedStringArray; func reinterred() -> PackedStringArray
func reinter(inv: Inventory) -> String                   # FIFO; nimmt bone_box_full; reinter_fee (payment_received), Ruf, Pietät, Zeile; bones_reinterred; Buildings.check_goal; grave_id | ""
func on_crypt_level(level: int) -> void                  # Gang/Gitter freischalten (Zustand, keine Notiz)
func passage_state() -> StringName                       # &"hidden" | &"sealed" | &"grille"
func look_at_passage() -> void                           # Hinweis c_crypt_draft einmal (Journal.add_clue), Texte §2.3
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
# Graveyard (P3) + func lift_old(grave_id: String) -> bool  # OLD → EMPTY, grave_state_changed; nur is_old-Plots
#   load_state übernimmt für Altgräber den gespeicherten Zustand (OLD oder später), _collect_plots liefert OLD nur als Ausgangswert
# GravePlot (P3): Altgrab im Zustand OLD: Interactable aktiv ab buildings_open mit „[E] Altes Grab heben: …" (sonst wie bisher aus)
#   nach lift_old: normale Grabstelle; @export var pit_variant: StringName = &""   # &"foot" für Altgräber
# GravePlotVisuals (P3): OLD → EMPTY tauscht die Modelle ohne Neuaufbau; DUG mit pit_variant foot → ph_prop_grave_pit_foot
class_name OssuaryShelf extends Node3D                   # Innen Gruft, Beinhaus-Nische; „[E] Gebeine beisetzen (20 Min)"
func refresh() -> void                                    # Kistenreihe nach used(), alte Steine nach reinterred(), Namenstafel ab Stufe 3 (Label3D)
class_name SealedPassage extends Node3D                   # Innen Gruft, hinter dem Regal; ab passage_level sichtbar, Gitter + Licht ab grille_level
```

**Kapelle, Qualität & Geister (P4)**
```gdscript
class_name ChapelConfig extends Resource                 # ✦ data/config/chapel_config.tres (§2.4)
@export var service_minutes: int = 45; @export var service_start_min: int = 480; @export var service_start_max: int = 1020
@export var candle_item: StringName = &"altar_candle"; @export var candle_amount: int = 1
@export var service_min_freshness: float = 0.3; @export var service_needs_dress: bool = true
@export var service_fee_by_level: PackedInt32Array = [0, 3, 5, 7]; @export var service_rep_by_level: PackedInt32Array = [0, 1, 2, 3]
@export var mourners_by_level: PackedInt32Array = [0, 0, 2, 4]
@export var devotion_minutes: int = 30; @export var devotion_mood_by_level: PackedInt32Array = [0, 1, 2, 3]
@export var devotion_robbed_cap: int = 8; @export var room_id: StringName = &"chapel"
class_name ChapelRules extends RefCounted
static func service_block_reason(record: CorpseRecord, inv: Inventory, minute: int, level: int, cfg: ChapelConfig) -> String
static func devotion_block_reason(grave: GraveRecord, current: int, inv: Inventory, level: int, cfg: ChapelConfig) -> String   # „Für dieses Grab brennt schon ein Licht."
static func devotion_bonus(level_held: int, robbed: int, base_score: int, cfg: ChapelConfig) -> int   # Deckel für beraubte Seelen
class_name ChapelRites extends Node                       # Systems/Chapel
func level() -> int                                        # = Buildings.level(&"chapel")
func service_block_reason(corpse_id: String, inv: Inventory) -> String
func hold_service(corpse_id: String, inv: Inventory) -> int   # nach der TimedAction: Kerze, Gebühr (payment_received), Ruf, Pietät, mark_service, stats.services_held, funeral_held; Gebühr | -1
func devotion_block_reason(grave_id: String, inv: Inventory) -> String
func hold_devotion(grave_id: String, inv: Inventory) -> bool  # Kerze, _devotions[grave_id] = level, Pietät einmal, devotion_held, stats.devotions_held
func devotion_level(grave_id: String) -> int               # 0 = keine
func eligible_devotions() -> Array[Dictionary]             # {grave_id, name, section, mood, held_level, block_reason}
func services_buried() -> int                               # service_held ∧ MARKED (Kapitel)
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
class_name Catafalque extends Node3D                       # Innen Kapelle; LOCATION_CATAFALQUE, room chapel; „[E] Auf den Katafalk legen" / „[E] Leiche aufnehmen"
func occupant() -> String
class_name ChapelAltar extends Node3D                      # „[E] Aussegnung halten (45 Min)" (Katafalk belegt) · „[E] Andacht halten" (sonst) → Panel &"chapel" bzw. &"devotion"
func request_service() -> void; func request_devotion(grave_id: String) -> void
class_name MournerSet extends Node3D                       # bis zu 4 stille Figuren an Markern „pew_seat_1…4"; show(n) / hide() mit Überblendung 0,6 s
func show_mourners(count: int) -> void; func hide_mourners() -> void
# GraveQuality (P4): breakdown/compute + Zeile „Ausgesegnet" (quality_service) wenn corpse.service_held
# GhostMood (P4): static func score(quality, dirt_level, decor_bonus, clean, cfg, robbed := 0, devotion := 0) -> int
#   devotion = ChapelRules.devotion_bonus(…) (bereits gedeckelt); GhostManager holt ChapelRites.devotion_level
# GhostLines ✦ + by_service: Array[String], by_devotion: Dictionary {&"default": […], &"robbed": […]}
```

**Innenraum-Kern, Speichern & Dialog (P6)**
```gdscript
class_name InteriorRoom extends Node3D                     # src/world/interiors/interior_room.gd – Kern von HutInterior (§11 Vertical Slice)
const GROUP := &"interior_room"
@export var room_id: StringName = &"hut"
@export var config: InteriorConfig; @export var environment: Environment; @export var camera_attributes: CameraAttributes
@export var bounds_min: Vector2 = Vector2(-0.5, -0.3); @export var bounds_max: Vector2 = Vector2(0.5, 0.3)
@export var camera_rig_path: NodePath; @export var outdoor_sun_path: NodePath
@export var hide_when_inactive: bool = false             # neue Räume true, Hütte false (bitgleich)
@export var building_id: StringName = &""                # "" = Hütte (keine Stufen)
var active: bool = false
func spawn_transform() -> Transform3D; func camera_profile() -> CameraProfile
func apply_room(current: StringName) -> void             # EventBus.interior_room_changed: aktiv, wenn current == room_id; Sonne, Profil, Sichtbarkeit
func apply_level(level: int) -> void                     # Kinder mit meta "min_level"/"max_level" ein-/ausblenden (Kollision mit)
static func find(tree: SceneTree, room_id: StringName) -> InteriorRoom
# HutInterior extends InteriorRoom: room_id &"hut", Gruppe hut_interior bleibt, apply_view(inside) bleibt als Kompatibilität
#   (= apply_room(&"hut" if inside else &"")); Szene und Layout der Hütte unverändert
# InteriorLighting: get_parent() as InteriorRoom (statt HutInterior); Rollen unverändert (window, lantern, candle)
# InteriorConfig ✦ + @export var fog_enabled: bool = false; fog_color: Color; fog_density: float = 0.0   # Gruft: kalte Luft
# HutPortal.travel(player, destination, inside, fade_seconds, room: StringName = &"") -> bool   # room leer + inside → &"hut"
# HutPortal.arrive(player, destination, inside, room: StringName = &"")
# Player (P6): var interior_id: StringName = &""; func set_in_interior(value: bool, room: StringName = &"") -> void
#   in_interior = value; interior_id = (room if room != &"" else &"hut") if value else &""
#   emit interior_changed(value), dann interior_room_changed(interior_id); save_state + "interior_id"; load_state tolerant (fehlt + in_interior → hut)
class_name BuildingDoor extends Node3D                     # Entities/door_<id> am Marker door_outside des Außenmodells (ab Stufe 1)
@export var building_id: StringName
func is_open() -> bool; func exit_transform() -> Transform3D
# Prompt BuildingData.prompt_enter; mit Leiche nur wenn allows_corpse (sonst HutDoor.TEXT_CORPSE_OUTSIDE); Stufe 0: kein Prompt
class_name RoomExit extends Node3D                         # innen am Marker door_inside; „[E] Hinaufgehen" (Gruft) / „[E] Hinausgehen"
@export var building_id: StringName
# travel zu BuildingDoor.exit_transform(), inside false; mit Leiche erlaubt, wenn allows_corpse
class_name SaveMigration  # CURRENT := 5; Kette 1→…→5; + static func migrate_4_to_5(state: Dictionary, meta: Dictionary) -> Dictionary
# SaveFileIO.FORMAT_VERSION = 5; read_doc akzeptiert 1…5
# GameState.DEFAULT_STATS + &"services_held", &"devotions_held", &"bones_lifted", &"bones_reinterred", &"niche_waits"
```

### 3.5 Database (Lead)
Neue Ordner → Schlüssel: `data/buildings` (`id`, sortiert nach `order`), `data/ossuary/old_graves` (`grave_id`). Funktionen: `building(id)`, `buildings()`, `old_grave(grave_id)`, `old_graves()`. Configs `buildings_config`, `crypt_config`, `chapel_config`, `shed_config` über `config()`. Raum-Configs `data/config/interiors/<room_id>.tres` über `interior_config(room_id)` (fehlt → `interior_config`). Leere/fehlende Ordner = leere Listen.

### 3.6 Eingaben
Keine neuen Tasten. Panels über [E], Esc schließt. Im Andachts-Panel: Mausklick; `[`/`]` blättern (bestehende Aktionen `journal_page_prev/next`).

---

## 4. Welt & Innenräume (W-Welt)

Kamera zur Erinnerung: Neigung 45°, Gier 0° (Blick nach Norden, −Z), FOV 30°, Distanz 22 (Zoom 12–24), `look_offset` 0,8. **Was südlich eines Gebäudes steht, kann es verdecken, und das Gebäude verdeckt, was nördlich hinter ihm liegt.** Daraus folgen die drei Plätze: Die Gruft ist niedrig (höchstens 2,6 m), die Kapelle steht als einziges hohes Gebäude am Nordrand, hinter ihr liegt nur Kulisse, und der Schuppen steht westlich neben der Hütte statt dahinter.

### 4.1 Die Gruft unter der Eiche (Südwestecke Alter Hof)
```
 z 3,2   ── Alte Eiche (−7,6|3,2, freigegeben, bleibt) ──
         dirt_y11 (−8,8|4,9) · dirt_y12 (−7,2|5,3)        old_08 (−5,2|5,6, bleibt)  Kerzen (−5,6|4,6)
 z 5,6   ┌── Hügel über dem Gewölbe ──┐
         │  GRUFT  site_crypt         │  Footprint x −10,4…−7,6 · z 5,6…8,2
         │  (−9,0|6,9), rot 0°        │  Höhe: Portal ≤ 2,6 m, Hügel ≤ 1,0 m
 z 8,2   └──────[Tür]─────────────────┘  Zugang 1,0 m: x −9,5…−8,5 · z 8,2…9,2
         ░ Zugang ░   ← Weg von der Bahre entlang z 6,6…9,3 (Breite ≥ 2,0 m bis old_08)
 z 9,6   ════ Südzaun ════════════════════════════════ Tor (x −0,4…2,6) · Bahre (4,4|8,3)
```
- **Lage:** `site_crypt` (−9,0 | 6,9), `rot_y 0` (Tür nach Süden zur Kamera), Footprint lokal [−1,4, −1,3, 2,8, 2,6]. Portal mit Steingiebel und Eisentür an der Südseite, dahinter die Treppe unter einen flachen Grashügel nach Norden, Richtung Eiche. Der Bau bleibt 2,4 m vor dem Eichenstamm (Kollision r 0,6).
- **Wege:** Bahre (4,4 | 8,3) → Zugang (−9,0 | 8,7): ≈ 13 m Weg, entlang dem Südzaun zwischen `old_08` und Zaun, frei ≥ 2,0 m. Bis zum alten Tisch waren es ≈ 14 m. Gruft → Altgräber (Mitte des Alten Hofs): 7–16 m. Gruft → Hüttentür: ≈ 14 m.
- **Stufenmodelle** ((geändert 04.10.2026, Benutzerwunsch: Gruft von Beginn an): im Spiel ab Tag 1 `ph_bld_crypt_l1`, Treppe offen, Grasdecke weg; `_site` nur noch in Fixture-Welten)**:** Stufe 0 `ph_bld_crypt_site`: ein freigelegter, zugeschütteter Grufthals mit Erdhaufen, Brettern und Pflöcken (erscheint mit `buildings_open`; Osric: „meine Leute haben den Hals freigelegt"). Stufe 1 `ph_bld_crypt_l1`: gemauertes Portal, Tür, Hügel. Stufe 2 `_l2`: dazu Schieferdach auf dem Portal und Lüftungsschlitz im Hügel. Stufe 3 `_l3`: Eisengitter vor der Tür (offen), Laterne am Portal (Marker `light_lantern`, **ohne Schatten**, 2,2 m, `warm_lights`), eingemeißelter Sturz „Wir waren, was ihr seid."

**Versetzte bzw. geänderte Elemente am Gruft-Platz (vollständig):**
| # | Element | vorher | nachher | Grund |
|---|---|---|---|---|
| G1 | Pflegestelle `dirt_y01` | (−9,8 \| 7,8) | **(−6,6 \| 8,6)** | lag im Footprint; neu am Weg zwischen Gruft-Zugang und `old_08` (Pflegestellen dürfen auf Routen liegen) |
| G2 | Zier-Zellen unter Footprint + Rand 0,6 + Zugang (`buildings.site_rects`) | Abschnitt `yard` (Zier erlaubt) | gesperrt bzw. ROUTE | wie Werkhof V2; dort schon platzierte Zier wird einmal geräumt (§5.2) |
| G3 | Gras unter Footprint und Zugang | gebacken | entfernt (`keep_out_station`), `grass.scn` neu gebacken | wie bei allen Stationen |
| G4 (bedingt) | Waldbaum am Kutschweg (−8,2 \| 14,2) | – | bis 2,0 m nach Südwesten | **nur**, wenn die Sichtprüfung §4.5 an der Gruft scheitert; W-Welt meldet es |
| G5 (bedingt) | `dirt_y11`, `dirt_y12` | – | ≤ 1,0 m | nur, wenn die Sichtprüfung sie hinter dem Portal verdeckt findet |
W-Welt darf den Bauplatz um höchstens ±0,3 m schieben, wenn die Routen-Prüfung das verlangt, und meldet es. Eiche, `old_08`, Kerzen, Laternenpfahl, Schwarzes Brett und Zaun bleiben bitgleich.

### 4.2 Die Kapelle am Birkenkamm (neuer Kirchhof nördlich des Birkenhangs)
```
 z −30,0 ┌────────────────── Kirchhof `churchyard` (x −2,0…11,5) ──────────────────┐
         │    Birken/Bäume (Kulisse)                                                │
 z −29,0 │          ┌───────── KAPELLE site_chapel (4,5|−25,5) ─────────┐           │
         │          │  Chor mit Fenster (St. 3), Altar, Katafalk          │           │
         │          │  Dachreiter mit Glocke ab St. 2 (First ≤ 6,8 m,     │           │
         │          │  Kreuz ≤ 8,6 m)          Footprint 5,2 × 7,0 m      │           │
 z −22,0 │          └───────────────[Tür]────────────────────────────────┘ Totenleuchter (6,6|−21,4, St. 3)
         │ Birke (−1,4|−22,2)    ░ Vorplatz 2,0 m ░                  Birke (9,6|−23,4) ← versetzt
 z −20,0 ═══Nordzaun Birkenhang═══[KIRCHPFORTE x 3,7…5,3]═════════════════════════
         plot_10 (2,6|−16,2) · plot_11 (5,0|−16,2) · plot_12 (7,4|−16,2)   ← Weg nördlich der Reihe (≥ 1,5 m)
 z −12,0 ═══ Zaun Alter Hof ═══[Durchgang Birkenhang x 2,5…6,5]═══
```
- **Lage:** `site_chapel` (4,5 | −25,5), `rot_y 0` (Tür nach Süden), Footprint lokal [−2,6, −3,5, 5,2, 7,0] → x 1,9…7,1, z −29,0…−22,0. Zugang 1,0 m vor der Tür (x 4,0…5,0, z −22,0…−21,0), dann Vorplatz bis zur Kirchpforte. Die Kapelle steht als einziges hohes Gebäude **am Nordrand**. Südlich von ihr liegen nur Gräber, Grabsteine und der niedrige Zaun, sie ist also frei sichtbar. Sie verdeckt nichts Spielbares, nur Kulisse. Der Dachreiter wird zur Silhouette des Friedhofs.
- **Kirchpforte** `obs_c_gate` (`ClearableObstacle`, Kind `gate_church`, „Kirchpforte / aufschließen", 10 Min, `requires_flag buildings_open`, Text vorher „Die Pforte zum Kamm ist verschlossen."; Modell `ph_prop_gate_small`/`_open` auf 1,6 m skaliert, wie die Ostpforte): Das Zaunstück [[2,0, −20,0], [7,0, −20,0]] wird zu [[2,0, −20,0], [3,7, −20,0]] + Pforte + [[5,3, −20,0], [7,0, −20,0]]. Das geschlossene Tor ist ab Laden sichtbar (einzige frühe Änderung am Birkenhang).
- **Wege:** Gruft → Kapelle (Leichenzug): Gruft-Zugang → Südzaun entlang → Hofweg nach Norden → Durchgang Birkenhang (x 2,5…6,5) → westlich an `plot_10` vorbei (x −1,7…1,0) → nördlich der Grabreihe (z −18,4…−19,7, kollisionsfrei ≥ 1,5 m) → Kirchpforte → Tür: **≈ 45 m**, getragen ≈ 22 s ≈ 45 Spielminuten. Kapelle → Altgräber: ≈ 25 m. Das ist der einzige lange Tragweg der Phase und gehört bewusst zum Ritus (§1.3).
- **Neuer Abschnitt `churchyard`** (Rechteck x −2,0…11,5, z −30,0…−20,0; `is_burial false`, `counts_for_cemetery false`, `decor_cap 0`, außerhalb der Bau-Maske, `order 7`). Keine Grabstellen, keine Zier, kein Ruf für den Abschnitt.
- **Stufenmodelle:** Stufe 0 `ph_bld_chapel_ruin`: dachlose Mauern, Tür ohne Blatt, Gestrüpp (erscheint mit `buildings_open`; „Die Gemeinde hat den Kamm roden lassen."). Stufe 1 `_l1`: Schieferdach, Tür, Glasfenster (Marker `light_window_1…4`). Stufe 2 `_l2`: Dachreiter mit Glocke (Marker `bell`, schwingt über `AnimationPlayer` bei der Aussegnung). Stufe 3 `_l3`: farbiges Chorfenster (Nordseite, von der Kamera abgewandt, nachts als warmes Licht auf den Birken sichtbar) und Totenleuchter-Säule `ph_prop_soul_lantern` vor der Tür.
- **Licht außen:** Fenster nur während einer Aussegnung und ab Stufe 3 nachts warm (2 × `OmniLight3D` ohne Schatten, 3 m, `warm_lights`). Totenleuchter ab Stufe 3 nachts (1 × ohne Schatten, 2,5 m). Kein neues Schattenlicht außen.

**Versetzte bzw. geänderte Elemente am Kamm (vollständig):**
| # | Element | vorher | nachher | Grund |
|---|---|---|---|---|
| K1 | Zaunstück Birkenhang-Nord | [[2,0, −20,0], [7,0, −20,0]] | Kirchpforte (s. o.) | einziger Eingriff am Birkenhang; `obs_n_gap_1/2` bleiben |
| K2 | Hintergrundbaum (3,5 \| −23,5) | – | **(0,2 \| −32,0)** | stand im Footprint |
| K3 | Birke (6,6 \| −22,0) | – | **(9,6 \| −23,4)** | stand auf dem Vorplatz; rahmt jetzt die Ostseite |
| K4 | `walkable_bounds.min.z` −20,3 | – | **−30,3**, dazu `extra_walls` [[−2,0, −20,0], [−2,0, −30,3]] und [[11,5, −20,0], [11,5, −30,3]] | Kirchhof begehbar; Holunderwinkel-, Ostwiesen- und Bruch-Zäune schließen den Rest ab |
| K5 | `camera_bounds.min.z` −17,5 | – | **−24,0** | Kapellentür und Fassade im Bild |
| K6 | Boden | 64 × 64, Mitte (8,0 \| 2,5) | **64 × 80, Mitte (8,0 \| −5,5)** → z −45,5…34,5 | sonst würde hinter der Kapelle die Bodenkante sichtbar; `ph_env_ground_graveyard` wird neu exportiert (Glättung unter dem Footprint) |
| K7 | Kulisse hinter der Kapelle | – | + 4 Birken/Bäume bei z −31…−36 (Positionen W-Welt, keine im Footprint oder Vorplatz) | Rahmung, gegen die leere Bodenfläche |
Birke (−1,4 | −22,2), Birke (12,8 | −21,4) und Hintergrundbaum (−7,6 | −23,4) bleiben. Gras im Kirchhof: Dichte × 0,6, keep_out um Footprint und Vorplatz.

### 4.3 Der Lagerschuppen an der Westseite (neben der Hütte, am Gang zum Pförtchen)
```
 z −12,5 ═Zaun Holunderwinkel═[Pförtchen x −10,6…−9,4]══
         Hintergrundbaum (−12,5|−9,5) → versetzt (S1)
 z −10,8 ┌── SCHUPPEN site_shed (−12,9|−9,0) ──┐  │ Gang x −11,2…−8,6 (Route Hüttentür → Pförtchen, unverändert)
         │  Footprint x −14,5…−11,3 · 3,2 × 3,6 │  │ Steinhaufen res_stone (−9,35|−6,8)     HÜTTE (−5,6|−7,2)
 z −7,2  └──────────[Tür]────────────────────────┘  │
         ░ Tasche x −14,8…−11,2 · z −7,2…−5,4 ░ ──→ Gang (Durchgang ≥ 1,5 m zwischen Steinhaufen und Webstuhl-Sperre z −5,65)
 z −5,0  ══ Westmauer (x −11,5, z −5…−1) ══  Ilses Platz (−12,1|−2,6)       WEBSTUHL (−8,75|−3,9)
```
- **Lage:** `site_shed` (−12,9 | −9,0), `rot_y 0` (Tür nach Süden), Footprint lokal [−1,6, −1,8, 3,2, 3,6] → x −14,5…−11,3, z −10,8…−7,2. Ein Pultdach fällt nach Westen, die Traufe an der Tür liegt bei ≤ 3,4 m. Von der Tür sind es 4 m zum Steinhaufen, 6 m zum Webstuhl-Zugang und 10 m zur Hüttentür. Werkbank und Steinmetzbank liegen über den Hof ≈ 14–18 m entfernt; dafür ist der Werkhof-Anschluss auf Stufe 2 da (§2.5).
- **Warum hier:** Westlich der Hütte verdeckt der Schuppen nichts. Er steht neben der Hütte, nicht hinter ihr (Lehre aus Phase 5). Südlich von ihm liegen nur die niedrige Westmauer und Ilses Platz. Nördlich hinter ihm ist Kulisse, der Gang bleibt unberührt.
- **Stufenmodelle:** Stufe 0 `ph_bld_shed_site`: Pflöcke, Balkenstapel, ein alter Schwellbalken. Stufe 1 `_l1`: Bretterschuppen mit Schindeldach, Holzlege an der Südwand (Kulisse). Stufe 2 `_l2`: dazu Handkarren an der Tür. Stufe 3 `_l3`: dazu Steinlege und zweites Regalfenster.

**Versetzte bzw. geänderte Elemente am Schuppen (vollständig):**
| # | Element | vorher | nachher | Grund |
|---|---|---|---|---|
| S1 | Hintergrundbaum (−12,5 \| −9,5) | – | **(−15,8 \| −12,4)** | stand im Footprint |
| S2 | Laufgrenze West | Wand bei x −11,2 | Tasche x −14,8…−11,2, z −7,2…−5,4: `walkable_bounds.min.x` → −14,8, dazu `extra_walls` [[−11,2, −20,3], [−11,2, −10,8]], [[−14,8, −7,2], [−14,8, −5,4]], [[−14,8, −5,4], [−11,2, −5,4]], [[−11,2, −5,4], [−11,2, 25,2]] | Zugang zur Tür; Ilses Weg (trader_far → trader_mid → trader_spot) bleibt ≥ 0,4 m außerhalb |
| S3 | `camera_bounds.min.x` −10,0 | – | **−11,5** | Schuppen nicht am Bildrand |
| S4 (bedingt) | Hintergrundbaum (−17,0 \| −1,5) | – | bis (−18,6 \| −0,4) | nur, wenn die Sichtprüfung am Schuppen scheitert |
Westmauer, Mauerstein, Ilses Wegpunkte, Steinhaufen, Kiste, Webstuhl und die Gang-Route bleiben bitgleich. W-Welt darf den Bauplatz um ±0,4 m schieben, wenn Routen- oder Ilse-Prüfung es verlangen.

### 4.4 Vor der Hütte – Rückbau des Leichentischs (Vorher/Nachher)
- **(geändert 04.10.2026, Benutzerwunsch: Gruft von Beginn an):** Der Tisch vor der Hütte ist ab Spielbeginn inaktiv (unsichtbar, ohne Kollision und Prompt, Waschschüssel und Räucherschale mit ihm); die Trittstelle bleibt. Der Knoten `Entities/morgue_table` bleibt im Layout (Welten ohne Buildings-System, Debug/Screenshot-Werkzeuge).
- **Ab Gruft 1** (zur Laufzeit, das Layout bleibt): Leichentisch `morgue_table` (−1,6 | −5,4), Waschschüssel `wash_basin` (−2,88 | −4,98) und Räucherschale `smoke_bowl` (auf dem Tisch) werden unsichtbar und ohne Kollision (`MorgueTable.retire_at_level 1`, Requisiten mit `follows_table`). Die Schaufel-Requisite (−2,0 | −6,8) bleibt als Werkzeug der Hütte.
- Zurück bleibt eine **Trittstelle**: das Stück ohne Gras, das der Tisch schon bisher hatte, am Ende des Hofwegs. Das passt, denn hier wurde gearbeitet. Bau-Maske und Gras werden dafür nicht neu gebacken; die Zellen bleiben gesperrt (Zier dort erst später, §13).
- **Vorher/Nachher (G6):** Aus derselben Kamera auf die Hütte rendert W-Welt: vorher mit Build `c5bd76d` (eigener Worktree, nur lesen), nachher mit Gruft 0 (Tisch noch da, Grufthals in der Ecke sichtbar) und nachher mit Gruft 1 (Tisch fort, Trittstelle, Gruft-Portal hinten links) → `p6_00a/b/c` (§11).
- Die Option „Aufbahrungsbank statt Rückbau" steht in §14.4.

### 4.5 Sichtprüfung (Kamerastrahl-Test, Pflicht für jedes Gebäude und jede Stufe)
Test in `test_graveyard_world.gd` (W-Welt) auf der echten Welt mit allen drei Gebäuden auf Stufe 0, 1, 2 und 3 (über `Buildings.apply_levels`):
1. **Nahsicht:** Der Spieler steht am Zugang des Gebäudes. Kamera wie im Spiel (Fokus = Spieler + `look_offset`, auf `camera_bounds` geklemmt) bei Zoom 12, 22 und 24. Strahlen von der Kameraposition zu 5 Punkten: Türmitte (1,2 m), Traufe links, Traufe rechts, First (bzw. Dachreiter), Kopf des Spielers (1,7 m). Geprüft wird gegen die **AABBs aller `VisualInstance3D`** der Welt, außer Boden, Gras, Partikeln, dem Gebäude selbst und dem Spieler (Baumkronen als AABB, das ist bewusst konservativ). **Bestanden:** Tür und Kopf sind bei allen drei Zoomstufen frei, und mindestens 3 der 4 Gebäudepunkte sind frei.
2. **Im Bild:** Die AABB des Außenmodells liegt bei Zoom 22 zu ≥ 80 % im Bild (1280 × 720) und deckt ≥ 3 % der Bildfläche.
3. **Übersicht:** Von festen Standpunkten aus ist das Gebäude zu ≥ 60 % unverdeckt (Strahl je AABB-Ecke oben und Mitte): Gruft von `dropoff` und `tp_workyard`, Kapelle von `tp_north` (4,5 | −14,0), Schuppen von `tp_workyard`.
4. **Keine neue Verdeckung:** Strahlen von der Spielkamera zum Spielerkopf an allen bestehenden Zugängen (Hüttentür, alle Stationen, Bahre, jede Grabstelle, jede Pflegestelle, alle Altgräber, Ilses Platz) treffen **keines** der drei neuen Gebäude. Das gilt vor allem für die Pflegestellen hinter dem Gruft-Portal (G5) und für `plot_10…12` vor der Kapelle.
5. Scheitert eine Prüfung, verschiebt W-Welt nur die bedingten Elemente (G4, G5, S4) oder den Bauplatz im erlaubten Rahmen. Jede Abweichung steht im G6-Bericht. Die Prüfliste steht zusätzlich als Bild `p6_vis_*` im Satz (§11).

### 4.6 Boden, Grenzen, Schema
- Boden, Lauf- und Kameragrenzen: K4–K6, S2–S3. Die Bau-Maske (Zier) bleibt auf x −11,5…21,5, z −20…9,6 und wird mit den Gruft-Sperren (G2) neu gebacken. Kirchhof und Schuppen liegen außerhalb, also gibt es dort keine Zier (gewollt).
- **Layout-Schema:** `sections[]` + `churchyard` · `clearables[]` + `obs_c_gate` · `buildings {sites[] {id, building, pos, rot_y, footprint, access, door_marker}, site_rects[]}` · `building_doors[]` (Entities `type: building_door`, params `building`) · `old_graves[].pit_variant: "foot"` · `dirt_spots[dirt_y01].pos` (G1) · `background_trees` (K2, S1, K7) · `birches` (K3) · `fence.segments` (Kirchpforte) · `walkable_bounds`, `extra_walls`, `camera_bounds`, `ground` (K4–K6, S2, S3) · `waypoints` + `tp_crypt` (−9,0 | 8,9), `tp_chapel` (4,5 | −21,0), `tp_shed` (−12,9 | −6,4) · `interiors {crypt: {origin}, chapel: {origin}, shed: {origin}}` (§4.7) · `lights` + `ph_bld_crypt_l3/light_lantern`, `ph_bld_chapel_l1/light_window_*`, `ph_prop_soul_lantern/light_soul`. Neue Systemknoten (§3.1) legt `graveyard_build_phase6.gd` an.

### 4.7 Innenräume – Szenen, Ursprünge, Portale, Kamera
| Raum | Szene (W-Welt, generiert) | Layout | Ursprung (Welt) | Grundfläche | Kamera (Distanz / Zoom) | Portal außen → innen |
|---|---|---|---|---|---|---|
| Hütte (bestehend) | `src/world/hut_interior/hut_interior.tscn` | `hut_interior_layout.json` | (0, 0, −200) | 5 × 4 m | 9 / 7–11 (unverändert) | `HutDoor` (unverändert) |
| **Gruft** | `src/world/interiors/crypt_interior.tscn` | `data/world/interiors/crypt_layout.json` | **(60, 0, −200)** | 8 × 6 m Gewölbe + Treppenschacht 1,4 × 3 m (Süden) + Beinhaus-Nische 3 × 1,6 m (Norden) | 10 / 8–12 | `door_crypt` → Fuß der Treppe |
| **Kapelle** | `src/world/interiors/chapel_interior.tscn` | `…/chapel_layout.json` | **(120, 0, −200)** | Schiff 5 × 7,5 m + Chor 3 × 2 m | 11 / 9–13 | `door_chapel` → hinter der Tür |
| **Schuppen** | `src/world/interiors/shed_interior.tscn` | `…/shed_layout.json` | **(180, 0, −200)** | 3,2 × 3,6 m | 8 / 7–10 | `door_shed` → hinter der Tür |
- **Muster wie die Hütte:** eigene Szene, vom Welt-Builder fern der Außenwelt instanziert. Betreten heißt: Überblendung 0,5 s, Teleport zur Mitte, `Player.set_in_interior(true, room)`, Kameraprofil, eigene Sonne und Umgebung. Die Welt läuft weiter (Uhr, Osric, Verfall), Speichern geht auch drinnen. Die Ursprünge liegen 60 m auseinander; aus keinem Innenraum-Profil ist ein anderer Raum oder die Welt zu sehen (Frustum-Test §10).
- **Nur der aktive Raum ist sichtbar:** Die neuen Räume haben `hide_when_inactive = true` (Licht, Schatten, Draw Calls nur für einen Raum). Die Hütte bleibt wie bisher. Leichen in Gruft und Kapelle hängen am `Corpses`-Container der Welt (wie bisher), nicht am Raum. Ihre Partikel enden mit `visibility_range_end 40 m`.
- **Generischer Builder** `src/world/interiors/interior_build.gd` (aus `hut_interior_build.gd` abgeleitet, gleiches Layout-Format: `room`, `door_inside`, `spawn_inside`, `walkway`, `camera_bounds`, `sun_rotation_deg`, `items[] {asset, pos, rot_y, mount, interact, use_pos, min_level, max_level}`) + `interior_builder.gd -- --room=<id>`. `graveyard_builder.gd` baut und instanziert alle drei. `hut_interior_build.gd` bleibt für die Hütte unverändert.
- **Treppe der Gruft:** Der Raum liegt bei y 0 wie alle Innenräume. Die Treppe ist Einrichtung: ein Schacht mit 8 Stufen, der nach Süden zur Kamera hin **aufsteigt** und oben im Tageslicht endet. Der Spieler erscheint am Fuß der Treppe (`spawn_inside`), `RoomExit` liegt auf der untersten Stufe („[E] Hinaufgehen"). Es gibt keine begehbare Treppenphysik. Die Tiefe entsteht durch das Bild: Schacht, Licht von oben, Deckengewölbe.

### 4.8 Innenräume – Licht, Einrichtung, Entitäten, Stufen
Lichtsteuerung: `InteriorLighting` unverändert (Rollen `window`, `lantern`, `candle`), eigene Werte je Raum in `data/config/interiors/<id>.tres` (`InteriorConfig`). Je Raum ≤ **2 Schattenlichter**, die außen nicht mitzählen, weil immer nur ein Raum sichtbar ist.

**Gruft** (unter der Erde, kalt, ohne Fenster)
- Licht: Die Rolle `window` ist der **Lichtschacht** der Treppe: Tag fahl blaugrau `#9AA8B8` 0,7, Nacht `#2A3446` 0,05, ohne Schatten. Die **Hängelaterne** über dem Tisch (Rolle `lantern`) hat Schatten immer an (`lantern_shadow_below 1.01`), Nacht 1,2, Tag 0,9. Die **Kerzen** in zwei Wandnischen (Rolle `candle`) brennen Tag und Nacht mit 0,45. Das Umgebungslicht ist kühl: Nacht `#1C2330` 0,28, Tag `#4A5563` 0,38. Hintergrund `#050607`, keine Sonne (Energie 0), `fog_enabled` mit `#8A98A8`, Dichte 0,02 (kalte Luft, nicht volumetrisch). Staub bzw. Kältehauch: 8 Partikel im Schacht. Ab Stufe 3 kommt das Gitterlicht dazu (§2.3).
- Einrichtung (`min_level` in Klammern): Treppe `ph_int_crypt_stair` (1), Gewölbe `ph_int_crypt_room` (1; Nischen 3–6 vermauert, sichtbar als Ziegelflächen), **Gruft-Tisch** `ph_int_crypt_table` (Steinplatte auf Böcken, Marker `slot_corpse`) mit `MorgueTable` (`room crypt`, `requires_level 1`) (1), Waschbecken (bestehend `ph_prop_wash_basin`) und Räucherschale (bestehend `ph_prop_smoke_bowl`) am Tisch (1), **Kühlnischen** `ph_int_crypt_niche` (Schieferbank, Marker `slot_corpse`, `chill`) je 2 für Stufe 1/2/3, sonst `ph_int_crypt_niche_sealed`, **Beinhaus-Nische** `ph_int_ossuary_shelf` (Regal mit 6 Kistenplätzen, Marker `box_1…6`, `stone_1…6`) mit `OssuaryShelf` (1), Gebeinkisten `ph_int_bone_box` je beigesetzter Hebung, alte Steine (die bestehenden `ph_prop_gravestone_*`, an die Wand gelehnt, 0,9 ×) je beigesetzter Hebung, Gebeinregal `ph_int_bone_rack` (2), **vermauerte Tür** `ph_int_sealed_passage` mit `SealedPassage` (2) und `_grille` mit Gitterlicht (3), Namenstafel `ph_int_name_board` mit Label3D wie die Inschriften aus Phase 5 (3), Laterne `ph_int_crypt_lantern`, Kerzennischen `ph_int_candle_niche`, Eimer, Tuchstapel, Kräuterbündel (bestehend `ph_int_herbs`).

**Kapelle** (Fenster, Bänke, Altar, Kerzen)
- Licht: 4 Seitenfenster (Rolle `window`) mit den Werten der Hütte (warm bei Tag, kühles Blau bei Nacht). Altarkerzen (Rolle `candle`, Nacht 0,6, Tag 0,2) brennen **nur während Aussegnung oder Andacht** und ab Stufe 3 immer (Ewiges Licht: 1 kleines warmes Licht, `#FF9A4A`, 0,4, 1,5 m). Keine Hängelaterne. Eine weiche Innenraum-Sonne durch die Fenster, mit Schatten. Ab Stufe 3 wirft das Chorfenster einen farbigen Lichtfleck (Spot ohne Schatten, warm-rot/gold, gemalt, nicht grell).
- Einrichtung: Raum `ph_int_chapel_room` (Schiff, Chor, Fenster; Stufe 1), Altar `ph_int_altar` mit Altartuch und Kerzenleuchtern + `ChapelAltar` (1), **Katafalk** `ph_int_catafalque` (Marker `slot_corpse`) + `Catafalque` (1), rohe Bänke `ph_int_pew_rough` × 2 (1, `max_level 1`), Kirchenbänke `ph_int_pew` × 4 (2; Marker `pew_seat_1…4`), Glockenseil `ph_int_bell_rope` (2), Totenleuchter-Kerzenständer `ph_int_candelabrum` (3), farbiges Chorfenster `ph_int_stained_window` (3), Trauergäste `ph_chr_mourner_a…d` (sitzend, ohne Rig, gemalt, Hut/Kopftuch, keine Gesichter im Detail) mit `MournerSet` (2), Weihwasserbecken als Requisite, Blumen in einer Vase (bestehend `ph_deco_grave_vase`).

**Lagerschuppen** (schlichter Holzschuppen mit Regalen)
- Licht: 1 kleines Fenster (Rolle `window`, Werte der Hütte × 0,7), Laterne an der Tür (Rolle `lantern`, Schatten nachts).
- Einrichtung: Raum `ph_int_shed_room` (Bretter, Balken; 1), Regale `ph_int_shed_rack` mit Lagerbuch + `ShedStore` (1), Holzlege innen `ph_int_wood_rack` (1), Steinkiste `ph_int_stone_bin` (2), zweites Regal (3). Die Füllung der Regale ist gemalt und fest; es gibt keine Füllstands-Modelle (§13).

---

## 5. Speichern & Migration (P6)

### 5.1 Format v5 (Ergänzungen)
```
format_version: 5
data.autoloads.GameState.stats   + services_held, devotions_held, bones_lifted, bones_reinterred, niche_waits
data.autoloads.GameState.flags   + buildings_open, p6_intro, building_sites_cleared, roof_and_earth_complete, c_crypt_draft_seen
data.nodes.player                + "interior_id": "" | "hut" | "crypt" | "chapel" | "shed"
data.nodes.corpse_manager.records[] + room: "" | "crypt" | "chapel", slot_id: "niche_2", cold_windows: [38400, -1, 400], service_held: true, service_day: 32
                                      location + "niche", "catafalque"
data.nodes.graveyard.graves[]    Altgräber: state OLD (4) | EMPTY … (bestehendes Feld)
data.nodes.buildings             {"levels": {"crypt": 2, "chapel": 1, "shed": 0}, "goal_done": false, "open_day": 30, "spent": {"building": 75}, "evict_pending": {}}
data.nodes.ossuary               {"lifted": ["old_04", "old_06", "old_07"], "reinterred": ["old_04", "old_06"], "passage": "sealed"}
data.nodes.chapel                {"devotions": {"plot_04": 2}, "services": 3}
data.nodes.shed_store            {"storage": Inventory.save_state()}
```
Nicht gespeichert: Nischen-, Tisch- und Katafalk-Belegung (aus den Records), Raum-Sichtbarkeit (aus `interior_id`), Stufenmodelle (aus `levels`), Trauergäste (nur während einer TimedAction; ein Laden mitten im Ritus ist gesperrt, `can_save` false wie beim Hauen in Phase 5).

### 5.2 Migration v4 → v5 (Phase-5-Spielstände müssen laden)
`SaveMigration.migrate_4_to_5` läuft in `read_doc` nach `decode_state` (Kette 1→…→5), rein, auf einer tiefen Kopie.
1. **Spieler:** `interior_id = "hut"`, wenn `in_interior` wahr ist, sonst `""`.
2. **Leichen:** alle Records + `room ""`, `slot_id ""`, `cold_windows []`, `service_held false`, `service_day 0`. **Eine Leiche auf dem Tisch vor der Hütte bleibt dort** (`location table`, `room ""`). Nach dem Laden ist die Gruft auf Stufe 0, also bleibt der alte Tisch aktiv und die Leiche bearbeitbar wie gewohnt. Erst der Abschluss von Gruft 1 trägt sie zur Laufzeit hinunter (§2.2, mit allen Zuständen). Getragene Leichen und Leichen am Boden bleiben unverändert.
3. **Gräber:** unverändert; Altgräber bleiben `OLD`.
4. `nodes.buildings = {}`, `nodes.ossuary = {}`, `nodes.chapel = {}`, `nodes.shed_store = {}`: Stufe 0 überall, nichts gehoben, keine Andacht, leeres Lager. `SaveMigration.V5_EMPTY_NODES` fügt sie erst ein, wenn W-Welt die Knoten anlegt (wie Phase 4/5).
5. **Zier auf dem Gruft-Platz** (zur Laufzeit, nicht in der reinen Migration): `Buildings.post_load` ruft einmalig `DecorationManager.evict_rects(site_rects)`. Die Items gehen in die Truhe `hut_chest`, ein Überlauf ins Spieler-Inventar, der Rest bleibt als offene Rückgabe im Zustand von `Buildings`. Einmalige Notiz: „Deine Zier stand am alten Grufthals unter der Eiche. Sie liegt jetzt in der Truhe." Flag `building_sites_cleared`. Nichts geht verloren (gleiches Verfahren wie Phase 5 §5.2 Schritt 5).
6. Stats `services_held`, `devotions_held`, `bones_lifted`, `bones_reinterred`, `niche_waits` = 0. Flags: keine. `buildings_open` setzt `Buildings.post_load` zur Laufzeit, wenn `names_in_stone_complete` gilt.
7. Pflegestelle `dirt_y01` (G1) speichert nur ihren Grad, keine Position: Nach dem Laden steht sie am neuen Platz mit dem alten Grad.

**Fixtures (W0, Lead, vor jeder Code-Änderung mit Build `c5bd76d` erzeugt, über `Phase5Bot` + echte Systeme):** `tests/fixtures/saves_v4/`
- `slot_p5_day30_reverent.json`: `reverent5`-Endstand, Tag 30, 07:00, `names_in_stone_complete`, 18 Gräber, 8 Altgräber `OLD`, Münzen gemessen (≈ 31). Start für `reverent6`, `mortician`, `save_load6`.
- `slot_p5_day35_harvester.json`: `harvester5`-Endstand, 07:00, ≈ 102 Münzen, 14 voll beraubte Seelen. Start für `harvester6`.
- `slot_p5_day30_mender.json`: `mender`-Endstand, 07:00, beraubte Gräber mit unruhigem Geist. Start für `mender6`.
- `slot_p5_day16_table.json`: `crafter`, Tag 16, 10:00, `workshop_open`, Lieferungen laufen, **Leiche auf dem Tisch vor der Hütte** mit 2 von 4 Schritten, laufendem Räucherfenster und genommenem Zopf. Für den Migrations- und Tischwechsel-Test.
- `slot_p5_day16_carry.json`: wie oben, 08:10, Spieler **trägt** die Tagesleiche draußen.
- `slot_p5_day20_crafter.json`: `crafter`, Tag 20, 20:00, `names_in_stone` gerade erreicht (Freischaltung am nächsten Morgen, neues Spiel).
- `slot_p5_interior.json`: Tag 12, 22:00, Spieler in der Hütte (`in_interior`), Zier auf dem späteren Gruft-Platz (Holzbank bei (−9,0 | 6,9), über `BuildMode` gebaut) für die Räum-Regel.
Dazu `make_v4_saves.gd` + `_driver.gd` (historisches Werkzeug, wie Phase 5) und `tests/fixtures/phase6/layout_p5.json` (= `graveyard_layout.json` von `c5bd76d`, bytegleich). Lade-Wächter: `tests/integration/test_saves_v4_load.gd` (Lead). v3-, v2- und v1-Fixtures laden weiter (Kette bis 5).

---

## 6. Debug-Konsole (W-UI) – neue Befehle
`buildings open` · `build <crypt|chapel|shed|all> [1-3]` (sofort, gleiche Regeln außer Material/Zeit) · `lift <old_id|all>` · `reinter [all]` · `service` (Katafalk-Leiche sofort aussegnen) · `devotion <grave_id>` · `room <hut|crypt|chapel|shed|out>` (Teleport hinein/hinaus mit Profil) · `niche fill [n]` (Testleichen in die Nischen) · `cold` (Faktoren und Fenster der Leichen anzeigen) · `candles <n>` · `mourners <0-4>` (Screenshot) · `passage` (Gang/Gitter-Zustand) · `tp <crypt|chapel|shed>` · `vis` (Sichtprüfung §4.5 im laufenden Spiel, Strahlen als Linien) · `goal6`.

## 7. UI (W-UI)
- **Gebäude-Panel** `&"building"` (Kontext `{building, data, level, site, inventory, player}`): Pergament wie das Bauplatz-Panel aus Phase 5, drei Stufenkarten nebeneinander (erreicht hell mit Häkchen · nächste mit Kosten vorhanden/fehlt, Münzzeile „Kalk und Mörtel aus Hollerbrück · 20 Münzen", Dauer, „Neu:"-Liste · spätere gedimmt), Bild der Stufe (Icon-Renderer), Knopf „Stufe 2 bauen (210 Min)", ab Schuppen 2 dazu „Fehlendes aus dem Schuppen holen (10 Min)".
- **Kapellen-Panel** `&"chapel"` (Aussegnung, Kontext `{corpse_id, altar, inventory, player}`): Name, Kleidung, Frische, „Die Familie legt 5 Münzen auf den Altar", Ruf +2, Trauergäste 2, Kerze vorhanden/fehlt, Uhrzeit-Fenster, Knopf „Aussegnung halten (45 Min)"; gedimmt mit Grund.
- **Andachts-Panel** `&"devotion"`: Grabliste (Name, Abschnitt, Geisterstimmung als Wort, „Licht brennt (Stufe 2)"), Filter „unruhig zuerst", Hinweis bei beraubten Seelen („Mehr als Ruhe kann eine Kerze nicht geben."), Knopf „Andacht halten (30 Min)".
- **Untersuchungs-Panel:** Titel „Gruft-Tisch" bzw. „Tisch vor der Hütte". Neue Zeile „Kühle: × 0,7 (Gruft)" bzw. „Nische: × 0,4". Die Frische-Prognose („frisch noch ≈ 5 h") rechnet mit Kälte (über `CorpseDecay.minutes_until`).
- **Holen-Knopf** in `crafting`, `build_site`, `building` und `stone_design`: Zutatenzeilen mit „im Schuppen: n", Knopf wie oben; ab Stufe 3 zusätzlich „Überschuss einlagern".
- **Prompts:** Altgrab „[E] Altes Grab heben: Agnes Hollweg (1741–1789)" · Ruhezeit-Sperre · Beinhaus „[E] Gebeine beisetzen (20 Min) – 2 Kisten warten" · Nische, Katafalk, Portale laut §2.
- **HUD:** unverändert. Kapitelanzeige im Friedhofs-Tooltip: „Gruft 2/2 · Kapelle 1/2 · Schuppen 2/2 · Aussegnung 1/1 · Umbettung 3/1". Gräberzahl: „Gräber 21 belegt · 2 frei · 2 alt (Ruhezeit) · 4 umgebettet".
- **Grabregister** (Hütte): Spalte „Ausgesegnet" (✓); Altgräber als eigene Zeilen „Altgrab – Agnes Hollweg (1741–1789) – umgebettet am 31. Gilbhart" (Kalender aus Phase 5). **Merkbuch:** Seite *Ich* + „Ausgesegnet: 4 · Andachten: 2 · Umgebettet: 5"; Hinweis „Der kalte Zug".
- **Tageszusammenfassung:** + „Ausgesegnet", „Umgebettet", „Gebaut" (Gebäude + Stufe), Ausgaben nach Zweck mit „Gebäude".
- **Zielzeile** (`ObjectiveResolver`, nach Leichen-Kette und Phase-4/5-Zielen): „Sprich mit Osric über die Gruft" · „Bauplatz: Gruft" · „Gebeinkiste zimmern" · „Altes Grab heben: <Name>" · „Gebeine beisetzen (<n> warten)" · „Bring die Leiche in die Gruft" (statt „zum Tisch", sobald Gruft ≥ 1) · „Die Kapelle steht – leg <Name> auf den Katafalk" (nur bei eingekleideter Leiche, 08:00–17:00) · „Hinter dem Beinhaus zieht es kalt" (Gang nicht angesehen) · „Kapelle 2 · Gruft 2 · Schuppen 2" · danach „Eine Andacht für <Name>?" (unruhigster Geist ohne Licht).
- **Abschluss-Panel** Variante `&"roof_and_earth"` (§1.5).

## 8. Assets (P5, Stil gesperrt, alle `ph_`, `lib_painted.py` / geteilte Materialien)
| Asset | Zweck | Dreiecke | Hinweise |
|---|---|---|---|
| `ph_bld_crypt_site` | Gruft Stufe 0: freigelegter, zugeschütteter Grufthals, Erdhaufen, Bretter | ≤ 1 500 | Marker `build` |
| `ph_bld_crypt_l1`, `_l2`, `_l3` | Gruft-Portal mit Hügel: gemauert / + Schieferdach, Lüftung / + Gitter, Laterne, Sturzinschrift | ≤ 3 000 / 3 500 / 4 200 | Marker `door_outside`, `build`, `light_lantern` (l3); Höhe ≤ 2,6 m; Hügel mit Gras-Vertexfarbe wie der Boden |
| `ph_bld_chapel_ruin` | Kapelle Stufe 0: dachlose Mauern, Gestrüpp | ≤ 4 000 | Marker `build` |
| `ph_bld_chapel_l1`, `_l2`, `_l3` | Kapelle / + Dachreiter mit Glocke / + Chorfenster | ≤ 6 000 / 7 000 / 7 500 | Marker `door_outside`, `build`, `light_window_1…4`, `bell` (l2+, eigenes Knotenmesh für die Schwingung), `light_choir` (l3); Kalkputz warmgrau, Schiefer `#5B6168`-Familie |
| `ph_prop_soul_lantern` | Totenleuchter (Steinsäule mit Lichthaus) | ≤ 900 | Marker `light_soul` |
| `ph_bld_shed_site`, `ph_bld_shed_l1`, `_l2`, `_l3` | Schuppen: Pflöcke + Balken / Bretterschuppen mit Holzlege / + Handkarren (bestehendes `ph_prop_handcart` wiederverwenden) / + Steinlege | ≤ 800 / 3 000 / 3 400 / 3 800 | Marker `door_outside`, `build` |
| `ph_prop_grave_pit_foot` | Grube mit Aushub am Fußende (Altgräber) | ≤ 900 | gleiche Grube wie `ph_prop_grave_pit`, Haufen +Z |
| `ph_int_crypt_room`, `_crypt_stair`, `_crypt_table`, `_crypt_niche`, `_crypt_niche_sealed`, `_crypt_lantern`, `_candle_niche` | Gruft innen | ≤ 9 000 / 2 000 / 1 200 / 900 / 500 / 600 / 400 | Marker `door_inside`, `spawn_inside`, `slot_corpse`, `chill`; Tonnengewölbe, Ziegel `#8A6F5C`-Familie, Schiefer kühl |
| `ph_int_ossuary_shelf`, `_bone_box`, `_bone_rack`, `_name_board`, `_sealed_passage`, `_sealed_passage_grille` | Beinhaus | ≤ 2 500 / 400 / 1 500 / 500 / 1 200 / 1 400 | Knochen **angedeutet**: Kisten mit Deckel, im Regal geordnete Langknochen als ruhige Form, kein Schädelberg; Marker `box_1…6`, `stone_1…6`, `names`, `light_below` |
| `ph_int_chapel_room`, `_altar`, `_catafalque`, `_pew_rough`, `_pew`, `_bell_rope`, `_candelabrum`, `_stained_window` | Kapelle innen | ≤ 9 000 / 1 800 / 900 / 500 / 900 / 300 / 800 / 600 | Marker `door_inside`, `spawn_inside`, `slot_corpse`, `pew_seat_1…4`, `light_candle_*`; Chorfenster gemalt, warme Töne, keine Figuren oder Symbole anderer Werke |
| `ph_chr_mourner_a`, `_b`, `_c`, `_d` | Trauergäste, sitzend, ohne Rig | ≤ 2 500 | dunkle Kleidung, Hut / Kopftuch / Umhang, Gesichter gesenkt, Palette der Figuren |
| `ph_int_shed_room`, `_shed_rack`, `_wood_rack`, `_stone_bin` | Schuppen innen | ≤ 5 000 / 1 500 / 1 200 / 800 | Marker `door_inside`, `spawn_inside` |
| `ph_item_altar_candle`, `_bone_box`, `_bone_box_full` | Item-Icons | ≤ 800 | belegte Kiste mit Schnur und Namenszettel (ohne lesbaren Text) |
- Vorhandenes wiederverwenden: alte Grabsteine (`ph_prop_gravestone_*`), Waschschüssel, Räucherschale, Grabvase, Kräuterbündel, Handkarren, `ph_prop_gate_small`.
- **Kein Gore:** Die Gebeine sind Formen in Kisten und Regalen, gemalt wie der Rest. Es gibt keine offenen Särge und keine sichtbaren Schädel in Nahaufnahme.

## 9. Performance-Budget (Phase 6, Messung mit `graveyard_shots_phase6.gd`)
| Größe | Budget | Begründung |
|---|---|---|
| FPS | 60 @ 1080p Mittelklasse-GPU | unverändert |
| Draw Calls außen | < 1 000 (erwartet ≤ 600) | Kapelle ≈ +14, Gruft ≈ +6, Schuppen ≈ +6, Kirchhof-Kulisse ≈ +10, Kirchpforte +2 |
| Draw Calls innen | ≤ 250 je Raum | nur der aktive Raum sichtbar (`hide_when_inactive`) |
| Kamera-Dreiecke inkl. Gras (Spiel-Zoom) | < 500 k | Kirchhof ≈ +20 k (Gras × 0,6), Kapelle ≈ 7 k |
| Lichter außen | ≤ 4 Omni mit Schatten (unverändert), ≤ 25 sichtbar | neu nur ohne Schatten: Gruft-Laterne (St. 3), Kapellenfenster (2), Totenleuchter; Messung `perf_p6_02` nachts am Kamm |
| Lichter innen | ≤ 2 mit Schatten, ≤ 8 sichtbar je Raum | Gruft: Laterne + (Tag) nichts weiter; Kapelle: Sonne; Schuppen: Laterne |
| Partikel | ≤ 60 außen (unverändert); ≤ 60 im aktiven Raum | Gruft voll: 6 Nischen × (Schwaden × 0,5 + 2 Kältehauch) + Tisch-Leiche (≤ 13) + 8 Schacht ≈ 51 |
| Portal-Wechsel | Überblendung 0,5 s, Hänger ≤ 50 ms in der Mitte | Räume sind vorgeladen, nur Sichtbarkeit wechselt |
| Skripte CPU/Frame (headless) | Phase-6-Anteil ≤ +0,2 ms gegenüber c5bd76d auf derselben Inszenierung | Nischen, Katafalk, Altar ohne `_process`; Kältefenster nur bei Ablage/Stunde; `InteriorLighting` läuft nur im aktiven Raum |
| Spielstand | < 300 kB, Laden < 1 s | + ≈ 1 kB Gebäude/Beinhaus/Kapelle, + Schuppen-Inventar ≈ 2 kB |

## 10. Tests
Regeln wie Phase 3–5 (Fixtures statt fremder Moduldaten, Fehler-Logger, Watchdog). **Alle 1 748 bestehenden Tests bleiben grün**; Anpassungen nur durch den Besitzer (z. B. `quality_max 20`, „/19"-Texte, Tisch-Prompts nach Gruft 1, Laufgrenzen im Welt-Test).

**Unit**
| Datei | Besitzer | Prüft |
|---|---|---|
| `test_buildings.gd` | P1 | Stufenfolge (kein Überspringen, kein Rückbau), Bau atomar (fehlt eins → nichts verbraucht), Sperrgründe, `building_upgraded`/`coins_spent(&"building")` im Münzbuch, Freischaltung (Morgen/Laden v4/v5, idempotent), Kapitel genau einmal (alle drei Bedingungen, jede Reihenfolge), Räumen der `site_rects` (Truhe, Überlauf, offen bis Platz, einmalig), Save/Load |
| `test_shed.gd` | P1 | Plätze 24/32/40, Stapel × 2 nur für RESOURCE/MATERIAL ab Stufe 3, Ausbau verkleinert nie, Holen atomar (alles oder nichts, Platzprüfung), Minuten 10/0, Einlagern ohne Werkzeuge/Münzen/`bone_box_full`, `shed_supply_moved`, Holen an Werkbank/Bauplatz/Stein-Panel nutzt danach die unveränderten Prüfungen |
| `test_crypt.gd` / `test_corpse_decay.gd` (+) / `test_corpse_manager.gd` (+) | P2 | Kältefenster öffnen/schließen bei Ablage, Aufnahme, Bestattung und Stufenwechsel; `min(Räuchern, Kälte)` exakt (Tabelle §2.2, Überlappung, Mehrtagessprung, Laden mitten im Fenster); `minutes_until` mit beiden Listen; Nischen je Stufe offen/vermauert; eine Leiche je Nische; **Tischwechsel** bei Gruft 1 (alle Zustände erhalten, genau ein aktiver Tisch, Notiz einmal); Gestank-Ausnahme in der Gruft; `niche_waits`; Verfallsbild in der Nische (Fliegen 0) |
| `test_morgue_table.gd` (+) | P2 | `is_active` nach Stufe, der alte Tisch ohne Kollision/Prompt ab Gruft 1, Requisiten folgen, Panel-Titel |
| `test_ossuary.gd` / `test_graveyard.gd` (+) / `test_grave_plot.gd` (+) | P3 | Ruhezeit (`old_01`/`old_08` gesperrt), Kapazität 3/5/6, Heben braucht Kiste + Gruft, OLD → EMPTY (Modelle, Kollision, Prompt, Lieferregel greift), FIFO-Beisetzen, Umbettgeld/Ruf/Pietät einmal, alter Stein im Beinhaus, Gang/Gitter je Stufe, Hinweis einmal, Aushub am Fußende, Save/Load |
| `test_chapel.gd` | P4 | Aussegnung: Zeitfenster, eingekleidet, Frische, Kerze, einmal je Leiche; Gebühr/Ruf/Trauergäste je Stufe; Pietät nur unverwertet; `service_held` → Qualitätszeile beim Zeichen; Andacht: Bonus je Stufe, erneut nach Ausbau (höherer Wert, nicht summiert), Deckel 8 für beraubte Seelen, Zahlenbeispiele §2.4; `services_buried`; Save/Load |
| `test_grave_quality.gd` (+) / `test_ghosts.gd` (+) / `test_piety.gd` (+) | P4 | „Ausgesegnet +1", `quality_max 20`, alte Gräber unverändert; `score(…, devotion)`; Pools `by_service`/`by_devotion` einmal je Grab; neue Pietät-Ereignisse |
| `test_interior_room.gd` | P6 | `InteriorRoom.apply_room`: nur der passende Raum aktiv, Profil/Sonne/Außensonne, `hide_when_inactive`; `apply_level` (min/max_level inkl. Kollision); `HutInterior` bitgleich (bestehender `test_hut_interior.gd` unverändert grün); Portal mit/ohne Leiche je `allows_corpse`; `interior_id` Save/Load |
| `test_save_migration.gd` (+) / `test_save.gd` (+) / `test_dialogue.gd` (+) / `test_game_state.gd` (+) | P6 | **7 v4-, 6 v3-, 4 v2-, 3 v1-Fixtures laden ohne Fehler/Warnungen**; Tisch-Leiche bleibt am alten Tisch; `interior_id` aus `in_interior`; neue Knoten leer; v5-Roundtrip identisch; Version 6 → abgelehnt; Osric `p6_intro` einmal, Kerzen (`coins_spent`) |
| `test_assets_phase6.gd` | P5 | Modelle vorhanden, Budgets §8, Marker (`door_outside`, `door_inside`, `spawn_inside`, `slot_corpse`, `chill`, `box_*`, `stone_*`, `pew_seat_*`, `bell`, `light_*`), Höhe Gruft ≤ 2,6 m, geteilte Materialien, Icons |
| `test_ui_phase6.gd` | W-UI | Gebäude-Panel (drei Karten, fehlt/vorhanden, Holen), Kapellen- und Andachts-Panel (Gründe, Werte = `ChapelRites`), Tisch-Titel und Kühle-Zeile, Zielzeilen, Register „Ausgesegnet"/Altgräber, Tooltip, Tageszusammenfassung, Debug-Befehle |

**Integration**
- `test_phase6_loop.gd` (W-Welt): v4-Fixture `slot_p5_day30_reverent` laden → `buildings_open` → Osric `p6_intro` (echter `DialogueRunner`) → Gruft 1 bauen (der alte Tisch verschwindet) → Kiste zimmern → `old_04` heben (Grab wird EMPTY, echte Bewegung zum Beinhaus durch das Portal) → beisetzen → nächster Morgen: Lieferung → Leiche **tragend** in die Gruft → Tisch → Untersuchen/Herrichten → Nische → Kapelle 1 → Leichenzug mit echter Bewegung (Gruft → Kapelle) → Katafalk → Aussegnung (08:00–17:00) → Grab → Zeichen („Ausgesegnet") → Schuppen 1/2 → Holen an der Esse → Gruft 2 (Gang, Hinweis) → Kapelle 2 (Trauergäste) → **Kapitel**. **Roundtrip** `collect_state()` identisch nach `save_game`/`load_game` an 5 Momenten: Leiche in der Nische mit offenem Kältefenster und Räucherfenster; Spieler in der Gruft mit getragener Leiche; Leiche auf dem Katafalk; Kiste gehoben und nicht beigesetzt; nach dem Kapitel.
- `test_phase5_save_upgrade.gd` (P6): `slot_p5_day16_table` laden → Leiche am alten Tisch bearbeitbar (Schritt 3) → `build crypt 1` → Leiche auf dem Gruft-Tisch mit Schritten, Funden, Zopf-Verwertung und Räucherfenster → Rest der Untersuchung unten → Bestattung. `slot_p5_day16_carry` laden → tragend in die Gruft (Stufe 1 per Debug) → Nische.
- `test_interiors.gd` (W-Welt): alle drei Räume gebaut und instanziert an ihren Ursprüngen; Frustum-Test (aus jedem Innenraum-Profil ist weder ein anderer Raum noch die Welt im Bild); `spawn_inside`/`door_inside` begehbar; Stufen-Einrichtung (Kollision nur, wenn sichtbar); Licht-Rollen je Raum; ≤ 2 Schattenlichter.
- `test_graveyard_world.gd` (+): Bauplätze und Türen an den Positionen §4; **Layout-Diff** gegen `tests/fixtures/phase6/layout_p5.json`: in den Abschnitten I–IV und im Werkhof ändern sich nur G1, K1, K2, K3, S1 und die Grenzen (K4–K6, S2, S3), dazu kommen die neuen Einträge. Hütte, Werkbank, Stationen, Pförtchen, Altgräber und alle übrigen Pflegestellen sind identisch. **Routen-Flood-Fill** (Kapselbreite 1,5 m): Bahre ↔ Gruft-Zugang, Gruft ↔ Kapelle (über Durchgang und Kirchpforte), Kapelle ↔ jedes Altgrab, Hüttentür ↔ Schuppen, Schuppen ↔ Pförtchen, Hüttentür ↔ alle Phase-5-Ziele. **Sichtprüfung §4.5** vollständig (alle Stufen, alle Zoomstufen, Punkte 1–4). Ilses Weg ohne neue Kollision.
- **Playthrough-Bot (W3):** `phase6_bot.gd` erweitert `Phase5Bot` um Freischaltung, Gebäudebau über das echte Panel, Kisten, Heben/Beisetzen, Gruft-Tisch/Nischen, Leichenzug mit echter Bewegung, Aussegnung, Andachten, Holen aus dem Schuppen. **Münzbuch je Strategie** wie Phase 5 (+ Zweck `building`, Einnahmen Umbettgeld/Gebühr).
  | Strategie | Start | Tage | Verhalten | Erwartung |
  |---|---|---|---|---|
  | `reverent6` | v4 `day30_reverent` | 10 | Bogen A §1.4 | Kapitel ≤ Tag 36; Phase-6-Ausgaben ≥ 130; Ende 0–45; Morgenstand ab B2 nie < 15; ≥ 4 Aussegnungen; 6 umgebettet |
  | `mortician` | v4 `day30_reverent` | 10 | Gruft zuerst auf 3; jede Leiche erst in die Nische, Untersuchung am nächsten Morgen | 0 Funde durch Verfall verloren bei Liegezeit ≤ 20 h; gemessene Frische = Formel §2.2 (Uhr-Differenz); Kapitel ≤ Tag 38 |
  | `mender6` | v4 `day30_mender` | 10 | Kapelle zuerst, Andachten für die unruhigsten | zufriedene Geister + ≥ 3; keine beraubte Seele zufrieden; Kapitel erreicht |
  | `harvester6` | v4 `day35_harvester` | 10 | Pflicht, alle Stufe 3, Andachten für alle beraubten | Kapitel erreicht; Ausgaben ≥ 180; Ende ≥ 0; beraubte höchstens gleichmütig (Befund, kein Fehler) |
  | `founder` | neues Spiel | 36 | `crafter` + Phase 6 ab `buildings_open` | `six_pits` ≤ 22, `names_in_stone` ≤ 30, `roof_and_earth` ≤ 36 (unverändert für die alten Kapitel) |
  | `save_load6` | wie `reverent6` | 10 | lädt jeden Morgen und einmal in der Gruft mit Leiche in der Nische | bitgleich zu `reverent6` |
  - Phase-3/4/5-Bots unverändert grün: Phase-5-Strategien dürfen nach ihrem Kapitel `buildings_open` sehen, bauen aber nichts. Ohne Gruft 1 bleibt der alte Tisch aktiv, und Osric bietet `p6_intro` nur an (der Dialog-Bot wählt es nicht). Qualitätsgrenze im Bot-Test 0…380 → 0…400.
- Save-Fuzzer (W3): + echter v5-Stand mitten in Phase 6 (Leiche in der Nische, eine auf dem Katafalk, Kiste gehoben, Spieler in der Gruft, Schuppen halb voll) mit gezielten Mutationen der Phase-6-Teile (`buildings`, `ossuary`, `chapel`, `shed_store`, `cold_windows`, `room`, `slot_id`, `interior_id`) + alle v4/v3/v2/v1-Fixtures. Neu in der Konsistenzprüfung: höchstens eine Leiche je Nische/Tisch/Katafalk; Nische nur, wenn offen (sonst → Boden der Gruft, Warnung erlaubt); Stufen 0…3; `reinterred ⊆ lifted`; `lifted` nur hebbare Altgräber; Gruft 0 ∧ Leiche mit `room crypt` → Boden am Grufteingang. Gleiche zwei erlaubte Ausgänge.
- Art-Prototyp-Regression: `test_art_prototype.gd` unverändert grün.

## 11. Screenshot-Liste Gate G6 (`graveyard_shots_phase6.gd -- --out=/abs/dir` + `ui_screenshots.gd --phase6`, 1280×720 → `docs/reviews/phase6_round1/`)
| # | Motiv |
|---|---|
| p6_00a | **Vor der Hütte vorher** (Build `c5bd76d`, Kamera auf die Hütte, Tag): Leichentisch mit Leiche, Waschschüssel |
| p6_00b | **Vor der Hütte nachher, Gruft 0** (gleiche Kamera): Tisch noch da, freigelegter Grufthals in der Südwestecke |
| p6_00c | **Vor der Hütte nachher, Gruft 1** (gleiche Kamera): Tisch fort, Trittstelle, Gruft-Portal unter der Eiche |
| p6_01 | Übersicht Tag: Alter Hof mit Gruft, Schuppen an der Westseite, Kapelle mit Dachreiter am Kamm (Zoom 24) |
| p6_02 | Gruft außen, Stufen 0–3 nebeneinander (Debug), Spieler am Zugang |
| p6_03 | Kapelle außen, Stufen 0–3 (Ruine, Dach, Dachreiter, Chorfenster + Totenleuchter) |
| p6_04 | Schuppen außen, Stufen 0–3 |
| p6_05 | Nacht am Kamm: Kapellenfenster warm (St. 3), Totenleuchter, Geister auf dem Birkenhang davor |
| p6_06 | Gruft innen, Stufe 1: Treppe mit Tageslicht, Gruft-Tisch mit Leiche, 2 Nischen offen, 4 vermauert |
| p6_07 | Gruft innen, Stufe 3, nachts: 6 Nischen (3 belegt, kalter Hauch), Laterne, Beinhaus mit Kisten und alten Steinen |
| p6_08 | Beinhaus nah: Namenstafel, vermauerte Tür (St. 2) / Gitter mit blauem Schimmer (St. 3) |
| p6_09 | Kapelle innen, Tag: Katafalk mit eingekleideter Leiche, Altarkerzen, 2 Trauergäste (St. 2) |
| p6_10 | Kapelle innen, Aussegnung auf Stufe 3: 4 Trauergäste, farbiger Lichtfleck, Aktionsbalken |
| p6_11 | Kapelle innen, Nacht: Andacht, nur Kerzenlicht |
| p6_12 | Schuppen innen: Regale, Holzlege, Laterne |
| p6_13 | Leichenzug: Spieler trägt eine Leiche durch die Kirchpforte (Übersicht Birkenhang) |
| p6_14 | Altgrab vorher (alter Stein) / beim Heben (Aktionsbalken) / danach (leere Stelle, Aushub am Fußende) |
| p6_15 | Neues Grab auf einer Altstelle mit gestaltetem Stein, daneben `old_01` mit Kreuz (Ruhezeit) |
| p6_16 | Gebäude-Panel (Gruft, Stufe 2 fehlt etwas, Holen-Knopf) |
| p6_17 | Kapellen-Panel (Aussegnung) und Andachts-Panel (beraubte Seele mit Hinweis) |
| p6_18 | Untersuchungs-Panel am Gruft-Tisch mit Kühle-Zeile und Prognose |
| p6_19 | Werkstatt-Panel Esse mit „im Schuppen: n" und Holen-Knopf |
| p6_20 | Geist mit `by_service`-Sprechblase |
| p6_21 | Osric `p6_intro` + Kerzen im Menü |
| p6_22 | Grabregister mit „Ausgesegnet" und Altgrab-Zeilen / Merkbuch „Der kalte Zug" |
| p6_23 | Abschluss-Panel „Unter Dach und Erde" |
| p6_vis_crypt / _chapel / _shed | Sichtprüfung §4.5: Kamerabild am Zugang mit eingezeichneten Strahlen (frei grün, verdeckt rot), Zoom 12/22/24 |
Dazu Asset-Tafeln `docs/reviews/phase6_assets/` und eine Performance-Tabelle je Motiv (`perf_p6_01…05`: Übersicht Tag Zoom max, Kamm nachts mit Kapelle St. 3, Gruft innen voll belegt nachts, Kapelle innen während der Aussegnung, Alter Hof mit 3 verwesenden Leichen + Gruft-Laterne).

## 12. Wellenplan
| Welle | Agents (parallel) | Inhalt | Ende |
|---|---|---|---|
| **W0** | Lead | **Zuerst v4-Fixtures mit Build `c5bd76d`** (7 Stände §5.2, eigener Commit vor jedem Gerüst) und `tests/fixtures/phase6/layout_p5.json`. Dann: Datenklassen ✦ (inkl. Erweiterungen), Stubs mit exakten Signaturen, 7 EventBus-Signale, Database-Ordner, `SaveMigration.CURRENT = 5` mit `migrate_4_to_5` als Identität (fail-safe), Config-Fixtures `tests/fixtures/phase6/` (+ `Phase6Fixtures`, u. a. `record_in(location, room, slot)`, `crypt_at(level)`, `old_grave(id, year)`), `test_phase6_scaffold.gd`, `test_saves_v4_load.gd` | Import + alle Tests grün → Commit |
| **W1** | P1, P2, P3, P4, P5, P6 (bei 5 Agents: P1 + P6) | Systeme mit Unit-Tests gegen Fixtures (ohne Welt): Gebäude/Stufen/Kapitel/Schuppen/Holen (P1) · Kältefenster, Nischen, Tischwechsel, Gestank-Ausnahme (P2) · Beinhaus, Altgräber OLD → EMPTY, Gang (P3) · Aussegnung, Andacht, Qualität, Geister (P4) · Assets + Asset-Tests (P5) · `InteriorRoom`, Portale, `interior_id`, Migration v5, Osric (P6) | je Modul: Tests grün → Merge durch Lead, danach `--import` |
| **W2** | W-Welt, W-UI (2 parallel) | Gruft unter der Eiche (G1–G5), Kirchhof + Kirchpforte + Bodenerweiterung Nord (K1–K7), Schuppen-Tasche (S1–S4), Rückbau vor der Hütte, **drei Innenräume** (Layouts, generischer Builder, Licht), **Sichtprüfung §4.5** und Routen, Vorher/Nachher `p6_00a–c`, `test_phase6_loop`, `test_interiors`; Gebäude-/Kapellen-/Andachts-Panel, Holen-Knopf, Tisch-Titel/Kühle, Zielzeilen, Register, Tageszusammenfassung, Debug, Icons | Integration + Roundtrips grün, Screenshots erstellt |
| **W3** | QA (19), Art (04), Lead | `phase6_bot.gd` (6 Strategien inkl. **mortician**, **founder**, Münzbuch), Save-Fuzzer v5, Performance, Stil-/Ton-Prüfung (Gruft-Licht, Gebeine ohne Gore, Trauergäste, Chorfenster, Texte), Befunde beheben (Besitzer), Gate-Protokoll in `QUALITY_GATE_STATUS.md` | **STOPP – Benutzerprüfung G6** |
Abhängigkeiten:
- W1-Agents nutzen nur Stubs und Datenklassen anderer Module. Der Stub `Buildings.level` liefert 0 (alter Tisch aktiv, Nischen zu). Tests setzen Stufen über `Phase6Fixtures.crypt_at(level)`.
- **P6 liefert zuerst** (Tag 1 der Welle) `InteriorRoom` + `HutPortal.travel(…, room)` + `Player.interior_id`. P2 (Nischen), P3 (Beinhaus) und P4 (Katafalk, Altar) hängen an Räumen. Bis dahin arbeiten ihre Entitäten ohne Raum (`room &""`).
- P2 erweitert `put_down` zuerst (optionale Parameter, alte Aufrufe unverändert). P4 (`Catafalque`) und P3 hängen daran.
- `graveyard.gd`: Nur P3 ändert (`lift_old`, Laden). P4 berührt `graveyard.gd` nicht: Die Qualitätszeile kommt über `grave_quality.gd`, der Kapitelaufruf über `Buildings.check_goal` ist ein Einzeiler, den der Lead nach P3 einfügt.
- P1 liefert `Buildings.site_rects` + den Aufruf von `evict_rects` vor W2 (W-Welt füllt die Rechtecke aus dem Layout).
- P5 liefert zuerst die Außenmodelle (Höhe Gruft ≤ 2,6 m, Dachreiter-Höhe) – **Blocker für die Sichtprüfung** – und die Raum-Hüllen. Bis dahin: graue Platzhalter-Quader aus dem Builder in Modellmaß (nur Tests, nie in Screenshots).
- Texte: P6 besitzt `carter.tres`, P3 `data/ossuary/**` und den Gang-Hinweis, P4 `ghost_lines.tres` und die Kapellen-Texte, P1 `data/buildings/*`. Die Leittexte stehen in §2. Wer sie ändert, meldet es dem Lead.

## 13. Nicht in Phase 6
- Ein Pfarrer, Messen, Taufen, Hochzeiten, Glockenklang und Musik (Priester: Phase 8; Sound: Agent 17 inaktiv)
- Trauergäste mit Namen, Wegen oder Dialog; Trauerzüge als NPC-Gruppe; Angehörige am Grab (NPCs: Phase 8)
- Weitere Gebäude, freie Platzierung, Abriss, Umzug von Gebäuden; Hütte als Ausbaugebäude; Unterhaltskosten
- Neue Grabstellen außer den gehobenen Altgräbern; mehr als eine Lieferung am Tag; Exhumieren eigener Gräber; Umbetten von `old_01`/`old_08` (Ruhezeit)
- Begehbare Krypten, ein offenes Gitter, Gegner, Kräfte, Untote (Krypten: Phase 12, Auferstehung: Phase 13)
- Neue Erzählfäden oder Erkenntnisse (Altgrab-Namen sind Flair; der Gang gibt nur einen offenen Hinweis)
- Pflegestellen für wiederbelegte Altgräber; Zier auf der Trittstelle vor der Hütte, im Kirchhof und am Schuppen
- Handkarren zum Fahren, schnellerer Leichenzug; Tragen mehrerer Leichen
- Füllstands-Modelle im Schuppen, Sortieren oder Filtern im Lager-Panel, gemeinsamer Bestand ohne Holen
- Verkauf von Gebeinen, Kerzen oder Gebäudeteilen; Spenden des Dorfes; Preisdynamik (Wirtschaft: Phase 10)
- Wetter, Jahreszeiten, Frost in der Gruft
- Änderungen am Maler-Shader, an den Atmosphären-Presets der Außenwelt, am Inhalt des Hütten-Innenraums und an den Abschnitten I–IV sowie am Werkhof (außer G1–G5, K1, S2 und dem Rückbau §4.4); Hütte, Werkbank, Stationen und Pförtchen werden nicht bewegt

## 14. Benutzerentscheidungen (28.09.2026, bindend)
1. **Die Gruft = Leichenhalle + Beinhaus** – ein Gebäude unter der alten Eiche; insgesamt drei Gebäude (Gruft, Kapelle, Lagerschuppen) wie in §2.2.
2. **6 Altgräber umbetten** – die 6 verwitterten Altgräber im Alten Hof können gehoben und wieder belegt werden; `old_01` und `old_08` bleiben immer stehen (§2.3). Die schrittweise Veränderung des Alten Hofs ist freigegeben.
3. **Lage wie vorgeschlagen** – Gruft Südwestecke Alter Hof unter der Eiche, Kapelle am Kamm nördlich des Birkenhangs mit Kirchpforte, Schuppen westlich der Hütte (§4).
4. **Alter Tisch wird entfernt** – nach Gruft 1 verschwindet der Tisch vor der Hütte samt Waschschüssel und Räucherschale; es bleibt nur die Trittstelle (§4.4).

---

## W0-Notizen (Lead, Welle 0 – verbindlich für W1)
1. **v4-Fixtures** `tests/fixtures/saves_v4/*.json` wurden **vor** jeder Code-Änderung mit Stand cd1620e erzeugt (Code identisch zu c5bd76d, nur Doku neu) – über `Phase5Bot` + echte Systeme (`make_v4_saves.gd` + `_driver.gd`, historisches Werkzeug; `-- --out=/abs/dir [--only=day30r,day35h,day30m,day16t,day16c,day20c,interior]`; auf einem Phase-6-Stand schriebe es v5). Die Endstände setzen die v3-Fixtures mit denselben 10 Bot-Tagen fort wie `test_phase5_playthrough.gd`. Eigener Commit 7e99d9a vor dem Gerüst, zusammen mit `tests/fixtures/phase6/layout_p5.json` (= `data/world/graveyard_layout.json` von c5bd76d, bytegleich). Gemessene Stände:
   - *day30_reverent* (`reverent5`, 07:00): `names_in_stone_complete`, 18 Gräber `MARKED`, 8 Altgräber `OLD`, Ruf 100, Pietät 69, **27 Münzen** (§1.4/§2.8 rechnen mit ≈ 31 – die Münzrechnung des Bogens beginnt damit 4 Münzen tiefer; W3 rechnet den Verlauf mit 27 nach, der Morgen B3 liegt dann bei ≈ 17 statt 21).
   - *day35_harvester* (`harvester5`, 07:00): 18 Gräber, **102 Münzen**, Ruf 86, Pietät −90, **14** voll beraubte Seelen (Haar + Zähne), alle unruhig.
   - *day30_mender* (`mender`, 07:00): 18 Gräber, 41 Münzen, Ruf 100, Pietät 10, **8 beraubte Gräber, aber keines mehr unruhig** (7 zufrieden, 1 gleichmütig – der mender setzt die Meistersteine zuerst auf die beraubten Gräber). **Abweichung von §5.2** („beraubte Gräber mit unruhigem Geist"): W3 prüft, ob `mender6` („zufriedene Geister + ≥ 3") von hier aus erreichbar ist, sonst Erwartung anpassen (Befund, kein Fehler).
   - *day16_table* (`crafter`, Tag 16, 10:00): `workshop_open`, Lieferungen laufen, Tagesleiche auf dem Tisch vor der Hütte, **„2 von 4 Schritten" = `clothing` + `hands`** (wie Phase 5), Zopf genommen (Schere von Ilse), Wacholder-Fenster läuft. Ruf 97, 31 Münzen.
   - *day16_carry* (`crafter`, Tag 16, 08:10): Spieler trägt die Tagesleiche draußen.
   - *day20_crafter* (`crafter`): `names_in_stone` fiel tatsächlich an **Tag 20**; gespeichert vor dem Zubettgehen um **23:05** statt 20:00 (der Bot arbeitet bis 21:30 und handelt nachts mit Ilse; der Test prüft „Abend des Kapiteltags", `buildings_open` noch nicht gesetzt).
   - *interior* (`crafter`, Tag 12, 22:00): Spieler in der Hütte, Holzbank 0,29 m neben (−9,0 | 6,9), über `BuildMode` gebaut (innerhalb Footprint + Rand 0,6 + Zugang des Gruft-Platzes).
2. **Speicherformat v5 schon in W0:** `SaveMigration.CURRENT = 5` (`SaveFileIO`/`SaveManager.FORMAT_VERSION` folgen), Kette 1→…→5. `migrate_4_to_5(state, meta)` ist **Identität auf einer tiefen Kopie** (`## STUB (P6)`; fail-safe, alle `from_dict`/`load_state` tolerieren fehlende Schlüssel). **P6** implementiert §5.2 1–7. `SaveMigration.V5_EMPTY_NODES = ["buildings", "ossuary", "chapel", "shed_store"]` ist vorbereitet, wird in W0 aber **nicht** eingefügt; `SaveManager.without_absent_defaults` kennt V5 noch nicht (P6 ergänzt es wie V4, bevor die Migration die Knoten einfügt). Lead-Anpassungen an fremden Tests (nur Versionsnummer / Feldzahl, mechanisch): `test_save_migration.gd` (v5, „neuer" = `CURRENT + 1`), `test_phase4_save_upgrade.gd`, `test_save_fuzzer.gd` (Neuspeichern = `FORMAT_VERSION`), `test_corpse.gd` (35 Record-Felder), `test_phase3_scaffold.gd`, `test_phase4_scaffold.gd` (v5; `test_piety_config_values` prüft die Phase-4-Ereignisse als Teilmenge, weil der Klassen-Default jetzt `service`/`devotion`/`reinterred` hat), `test_phase5_scaffold.gd` (v5, „neuer" = `CURRENT + 1`). Lade-Wächter `tests/integration/test_saves_v4_load.gd`: 7 v4-Fixtures laden **ohne jede Warnung**, Zustand erhalten, Neuspeichern v5, Roundtrip identisch. v3/v2/v1-Fixtures laden weiter (Kette bis 5).
3. **Datenklassen ✦ vollständig** (§3.2.1): `BuildingData` (+ `level_data`, `max_level` fertig), `BuildingLevelData`, `BuildingsConfig`, `ShedConfig`, `CryptConfig`, `OldGraveData`, `ChapelConfig`.
4. **Erweiterungen bestehender Datenklassen (Klassen-Defaults = Vertrag):**
   - `CorpseRecord`: `LOCATION_NICHE`, `LOCATION_CATAFALQUE` an `LOCATIONS` **angehängt**; `room`, `slot_id`, `cold_windows`, `service_held`, `service_day` **schon in `to_dict`/`from_dict`** (fehlend = Default; `cold_windows` als Tripel `[start, ende (-1 = offen), faktor‰]`, ungültige Tripel – Ende ≤ Start außer −1, Faktor außerhalb 1…1000 – werden verworfen). Gespeicherte Records tragen die fünf Schlüssel also schon ab W0. `CorpseManager.PLACE_LOCATIONS` ist **unverändert** (P2 hängt Nische/Katafalk an).
   - `EconomyConfig.quality_service = 1`. **Abweichung (wie Phase 4/5):** `quality_max` bleibt in W0 bei **19** (Default und `.tres`), sonst brechen die „/19"-Texte und Maximum-Tests. **P4** stellt Default **und** `economy_config.tres` auf 20 um und passt die Tests an (Lead-genehmigt); `tests/fixtures/phase6/economy_config_fixture.tres` hat schon 20.
   - `GhostConfig.devotion_robbed_cap = 8`; `GhostLines.by_service` ist **`PackedStringArray`** (statt `Array[String]` in §3.4 – wie alle anderen Zeilenlisten der Klasse), `by_devotion: Dictionary[StringName, PackedStringArray]` (`&"default"`, `&"robbed"`).
   - `ReputationConfig.event_points` + `reinterred 1`, `PietyConfig.events` + `service 1`, `devotion 1`, `reinterred 1` (nur Klassen-Defaults; die `.tres` setzen die Listen ausdrücklich und bleiben bis P4 unverändert).
   - `DecayVisualConfig` + `niche_fly_scale 0`, `niche_wisp_scale 0.5`, `niche_chill_particles 2`; `InteriorConfig` + `fog_enabled false`, `fog_color #8A98A8`, `fog_density 0`, `shaft_role_as_window false` (§3.2 nennt das Feld ohne Typ: `bool`, die Rolle `window` ist in der Gruft der Treppenschacht). Die `.tres` der Hütte ist unverändert.
   - `Inventory.stack_multiplier = 1`, `stack_categories: Array[int] = []` – nur Felder, keine Wirkung (P1).
   - **Nicht** in W0: `GameState.DEFAULT_STATS` (+ 5 Stats → P6, sonst ändern sich alle Stand-Vergleiche; wie Phase 5).
5. **Neue Config-Dateien** mit Vertragswerten: `data/config/{buildings_config (→ P1), shed_config (→ P1), crypt_config (→ P2), chapel_config (→ P4)}.tres`. Identische Kopien in `tests/fixtures/phase6/*_fixture.tres` (Scaffold-Test: data == Fixture == Klassen-Default bis zur Übergabe; danach dürfen die Daten abweichen, die Fixture bleibt).
6. **Nicht** in W0 angelegt (Besitzer, W1): `data/buildings/*` (P1), `data/ossuary/old_graves/*`, `data/items/{bone_box,bone_box_full}.tres`, `data/recipes/bone_box.tres`, `data/journal/clues/c_crypt_draft.tres` (P3), `data/items/altar_candle.tres`, `ghost_lines.tres`-Erweiterung (P4), `data/config/interiors/*`, `carter.tres` (P6). Die Fixtures sind vollständige Vorlagen mit den Leittexten aus §2 (kopieren erlaubt). Neue Items in `data/items` ändern ggf. Item-Zählungen in fremden Tests – der Besitzer passt sie an (Lead-genehmigt).
7. **Stubs** (Körper leer/trivial, `## STUB (P<n>)`, Signaturen exakt §3.4; Test `test_phase6_scaffold.gd` mit Liste `IMPLEMENTED`, die Besitzer füllen):
   - **P1:** `BuildingRules` (+ `TEXT_MAXED`, `TEXT_MISSING`, `COIN`), `Buildings` (Gruppen `buildings`, `saveable`; `"buildings"`, 32; `@export site_rects`; `var config`), `ShedSupply` (+ `DIRECTION_FETCH/STORE`), `BuildingSite` (+ `building_site.tscn` mit `Interactable`; `PANEL &"building"`), `ShedStore` (`extends Chest`, `_init` setzt `"shed_store"`/61; `shed_store.tscn` mit `Interactable` + `Storage`; `store()` = `storage` fertig). An bestehenden Klassen: `Workbench.request_fetch(needs)`/`request_store()`, `BuildSite.request_fetch(needs)`/`request_store()` (leer). **`Buildings.level()` antwortet schon aus `load_state({"levels": {…}})`** (Format §5.1), damit W1-Tests Stufen setzen können (`Phase6Fixtures.crypt_at/buildings_at`); P1 behält dieses Ladeformat.
   - **P2:** `CryptNiche` (+ `.tscn`). An bestehenden Klassen: `CorpseDecay.cold_factor_at` (liefert 1.0), `CorpseManager.put_down(…, _room := &"", _slot_id := "")` (Parameter noch ungelesen – P2 benennt sie in `room`/`slot_id` um), `corpse_in_slot` (""), `cold_factor_for` (1.0), `restart_cold`, `relocate_table_corpse` (""), `mark_service`; `MorgueTable.room/requires_level/retire_at_level` (Exports ohne Wirkung) + `is_active()` (**liefert true** – der alte Tisch bleibt aktiv).
   - **P3:** `OssuaryRules` (+ Sperrtexte §2.3), `Ossuary` (Gruppen `ossuary`, `saveable`; `"ossuary"`, 36; `PASSAGE_*`), `OssuaryShelf`, `SealedPassage` (+ `.tscn`). An bestehenden Klassen: `Graveyard.lift_old` (false), `GravePlot.pit_variant` (Export ohne Wirkung).
   - **P4:** `ChapelRules` (+ Sperrtexte §2.4), `ChapelRites` (Gruppen `chapel_rites`, `saveable`; `"chapel"`, 37), `Catafalque`, `ChapelAltar` (+ `.tscn` mit `Interactable`), `MournerSet` (+ `.tscn` ohne `Interactable`). An bestehenden Klassen: `GhostMood.score(…, robbed := 0, _devotion := 0)` (ungelesen; P4 benennt um). `GraveQuality` ändert P4 selbst.
   - **P6:** `InteriorRoom` (Gruppe `interior_room` in `_init`, `find()` fertig), `RoomExit`, `BuildingDoor` (+ `.tscn`), `SaveMigration.migrate_4_to_5` (Identität). An bestehenden Klassen: **`Player.interior_id` + `set_in_interior(value, room := &"")` setzen `interior_id` schon nach der Formel §3.4** (`hut`, wenn `room` leer), senden aber noch kein `interior_room_changed` und speichern es nicht; `HutPortal.travel(…, room := &"")`/`arrive(…, room := &"")` reichen `room` durch. `HutInterior` erbt noch **nicht** von `InteriorRoom` (P6, §3.4).
   - P5: keine Stubs. W-UI/W-Welt: Panels und Builder nicht als Stub (W2).
8. **EventBus:** die 7 Signale aus §3.3. **Eingaben:** keine neuen (§3.6). **Angehängte „Enums":** nur `CorpseRecord.LOCATIONS` (+ `niche`, `catafalque`); `GraveRecord.State`, `ItemData.Category` unverändert.
9. **Database** (§3.5): `building/buildings` (`data/buildings`, nach `order`, bei Gleichstand nach id), `old_grave/old_graves` (`data/ossuary/old_graves`, Schlüssel `grave_id`, nach `grave_id`), `interior_config(room_id)` (`data/config/interiors/<room_id>.tres`, fehlt → `interior_config`; `config()` liest den Unterordner nicht). Leere/fehlende Ordner = leere Listen. Configs über `config(&"buildings_config" | &"crypt_config" | &"chapel_config" | &"shed_config")`.
10. **Fixtures für W1:** `tests/fixtures/phase6/` – `{buildings,crypt,chapel,shed}_config_fixture.tres` (= W0-Daten), Phase-6-Werte bestehender Configs: `economy_config_fixture` (Phase-5-Fixture + `quality_service 1`, **`quality_max 20`**), `reputation_config_fixture` (+ `reinterred`), `piety_config_fixture` (+ `service`, `devotion`, `reinterred`), `ghost_config_fixture` (+ `devotion_robbed_cap 8`), `decay_visual_config_fixture` (+ Nischen-Skalen); `ghost_lines_fixture.tres` (Phase-5-Fixture + `by_service`, `by_devotion` mit den Leittexten §2.4); `buildings/{crypt,chapel,shed}.tres` (3 Stufen §2.1: Material, Münzen, Minuten, Münz-Zweck; **Titel, `text` und `adds` sind W0-Entwürfe** – P1 formuliert); `old_graves/old_01…08.tres` (Namen, Jahre, Zeilen §2.3, `stone_model` = das bestehende `ph_prop_gravestone_<stone>` aus dem Layout); `recipes/bone_box.tres`, `clues/c_crypt_draft.tres`; `interiors/{crypt,chapel,shed}.tres` (`InteriorConfig` nach §4.7/§4.8); `tests/fixtures/items/` + `altar_candle`, `bone_box`, `bone_box_full` (MATERIAL, Stapel 10/5/3). Zugriff: `Phase6Fixtures` (`tests/fixtures/phase6/phase6_fixtures.gd`), u. a. `crypt_at(level, tree)` / `buildings_at(levels, tree)` (Buildings-Knoten über `load_state`, unter `tree.root` in Gruppe `buildings`; Aufrufer gibt frei), `record_in(location, room, slot, cold_windows)`, `service_corpse(freshness, dress)` (eingekleidet auf dem Katafalk), `serviced_grave(day, marker)`, `old_grave(id, died_year)` (Ruhezeit-Tests), `old_grave_record(id)` (OLD), `room_config(room)`, `ROOMS` (Ursprünge, Maße, Kamera §4.7), `NICHES` (`niche_1…6` → `min_level`), `YEAR 1834`, `LIFTABLE_IDS`, `inv_with(items, tiers)`, `install_save_v4`, `save_v4_path`, `layout_p5()`.
11. **Lücken, pragmatisch entschieden:**
    - `OldGraveData.display_name` trägt den Titel mit („Konrad Pfister, Ratsherr", „Elias Brand, Totengräber"); `OssuaryRules.label` ergibt damit „Konrad Pfister, Ratsherr (1702–1771)". `reinter_line` ist "" für `old_01`/`old_08`.
    - Spieljahr: `StoneConfig.calendar.start_year` 1834; nach Tag ≈ 90 beginnt 1835 – `old_08` (1831) bleibt trotzdem gesperrt.
    - `c_crypt_draft`: `kind &"place"`, `order 20`; die Randnotiz „Unter dem Birkenhang ist es nicht still." hat in `ClueData` kein Feld – P3 entscheidet (z. B. zweite Textzeile), meldet es dem Lead.
    - Anzeigenamen/Prompts: „Gruft" / „Kapelle" / „Lagerschuppen"; „[E] Gruft betreten" / „[E] Hinaufgehen", „[E] Kapelle betreten" / „[E] Hinausgehen", „[E] Schuppen betreten" / „[E] Hinausgehen" (Schuppen `allows_corpse false`).
    - Raum-Configs: Kapelle ohne Hängelaterne (`lantern_*_energy 0`), Schuppen-Fenster = Hütte × 0,7 (Energie), Gruft ohne Sonne (Energie 0), `stove_*` in allen neuen Räumen 0. Die Hütte bleibt `data/config/interior_config.tres`.
    - `ChapelRules.devotion_bonus`: Rückgabe ist der bereits gedeckelte Bonus (`base_score + bonus ≤ devotion_robbed_cap` bei `robbed > 0`, nie negativ).
    - Item-Beschreibungen der drei neuen Items sind W0-Entwürfe (P3/P4 formulieren).
12. **Testzahl:** vor W0 1 748, nach W0 **1 782** (+ `test_phase6_scaffold.gd` 25, `test_saves_v4_load.gd` 9).
