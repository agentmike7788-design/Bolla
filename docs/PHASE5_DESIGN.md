# Phase 5 – Crafting und Ressourcen – Vertrag v1

Status: **v1.1 – Entwurf zur Benutzerfreigabe (Vertragsfragen §14 beantwortet), danach verbindlich für die Umsetzung** · Verantwortlich: Agent 01 (Lead), Agent 02 (Game Design), Agent 14 (Crafting/Economy), Agent 08 (Godot Core), Agent 10 (Graveyard System)
Baut auf `docs/PHASE4_DESIGN.md` (Vertrag v1, freigegeben 28.09.2026), `docs/PHASE3_DESIGN.md` und `docs/VERTICAL_SLICE_DESIGN.md` auf. Was dieses Dokument nicht ändert, gilt dort unverändert weiter. Referenz-Build: **69f8d49** (Gate G4 freigegeben).
Gameplay-Werte sind **Vorschläge**; der Benutzer prüft sie beim Gate G5. ART STYLE LOCK „Gemaltes Diorama" ist aktiv: Phase 5 ändert den Stil nicht. Der Maler-Shader (`painted.gdshader`, `painted_common.gdshaderinc`, `painted_foliage.gdshader`) bleibt unverändert. Die freigegebenen Abschnitte I–IV (Alter Hof, Ostwiese, Birkenhang, Holunderwinkel) bleiben unverändert. Ausnahmen (Benutzerentscheidung §14.2): der **Werkhof an der Hütte** mit genau einer versetzten Requisite und neu gesperrten Zier-Zellen (§4.1) sowie die **Ostpforte** im Ostzaun der Ostwiese (§4.2).

**Benutzerentscheidungen (verbindlich, 28.09.2026)**
- Inhalt, alle vier Teile:
  1. **Neue Stationen:** neben der Werkbank eine Steinmetzbank (Grabsteine mit Inschrift), ein Webstuhl (Leinen, Totenhemden) und eine kleine Esse (Beschläge, Werkzeug). Der Spieler baut sie selbst, mit Material und Münzen.
  2. **Ressourcen sammeln:** neue Rohstoffe (Lehm, Eisenerz, Flachs, Holunder, Kräuter); Bäume fällen, kleiner Steinbruch, Flachsfeld am Rand; nachwachsende Sammelstellen. Der Boden darf an den Rändern wachsen, die freigegebenen Abschnitte bleiben unverändert.
  3. **Werkzeug-Stufen:** bessere Schaufel, Axt und Spitzhacke. Schneller arbeiten und neue Aufgaben (Findlinge nur mit Spitzhacke).
  4. **Grabstein-Gestaltung:** Form, Inschrift und Zierde an der Steinmetzbank wählen. Bessere Steine → mehr Grabqualität, zufriedenere Geister. Inschriften als Vorlagen mit automatisch eingesetztem Namen und Daten, kein Freitext. Kompatibel mit dem Grabzeichen-Tausch (Kreuz → Stein).
- **Münzüberschuss (G4-Befund B1) wird mit Phase 5 gelöst.** Ein würdevoller Spieler gibt bis zum Phasenende den größten Teil aus, ohne sich arm zu fühlen (Rechnung §2.8).
- **Pietät-Fix aus Phase 4 (G4-Befund B2):** Eine verwertete Leiche bekommt keinen „Voll hergerichtet"-Bonus (+3 Pietät) mehr. Die Grabqualität zählt weiter (§2.9).
- **Crafting-Tiefe: mittel.** Wenige klare Ketten, 13 neue Rezepte plus 3 Steinformen. Keine Qualitätsstufen bei Items, nur bei der Grabstein-Gestaltung.
- **Antworten auf die Vertragsfragen (28.09.2026, §14):** keine neuen Grabstellen in Phase 5 · Stationen **neben der Hütte** (Werkhof), Am Bruch bleibt Rohstoffgebiet · Jahreszahl **1834** · Osric führt den Bruch in einem Satz als Lorenz' alten Werkplatz ein, ohne neuen Hinweis.

**Regeln für alle Agents** (wie Phase 3/4)
- Klassen, Signaturen, Dateipfade, Signale und Datenformate hier sind **fest**. Änderungen nur über den Lead.
- Der Lead legt in **Welle 0** alle Datenklassen (✦) vollständig und alle Logikklassen als **Stubs mit exakten Signaturen** an. Die Besitzer füllen die Körper und benennen nichts um.
- Nach jedem neuen Worktree und nach jedem Merge: `godot --headless --path . --import`.
- Jede Datei hat genau einen Besitzer (§3.2). Fremde Dateien nicht ändern; Bedarf an den Lead melden.
- Alle neuen Assets tragen `ph_` und kommen in die Placeholder-Liste (`docs/QUALITY_GATE_STATUS.md`).
- Keine Mechaniken, Namen oder Texte anderer Spiele übernehmen. Ausdrücklich **nicht**: Technologie-Bäume mit Forschungspunkten, Item-Qualitätssterne, „Grabschmuck"-Wertungen mit Stufen-Symbolen, Handwerks-Warteschlangen mit Sofort-Kauf, Energie-/Ausdauerleisten.
- Eigene Identität dieser Phase: **„Was bleibt"**. Der Totengräber lernt Dinge zu machen, die länger halten als er: Werkzeug, Tuch, Stein. Die Toten bekommen ihre Namen zurück, in Stein gehauen. Ein Stein gibt nicht zurück, was man ihnen genommen hat. Er kann aber erinnern.
- Sprache: alle Spieltexte eigenständig auf Deutsch, trocken-melancholisch, handwerklich genau. Kein Spott über die Toten.

---

## 1. Spielablauf & Progression

### 1.1 Erweiterter Kern-Loop
```
Freischaltung (Friedhof vollendet) → Osric erzählt vom Bruch → Steinbruchbrief kaufen (Münzen)
  → AM BRUCH: Ostpforte aufschließen · Lehm stechen · Flachs raufen · Kräuter · (Findlinge brechen → Steinbruch)
  → IM SCHLAG: Erlen fällen (Axt) · am Holunder Beeren pflücken
  → WERKHOF AN DER HÜTTE: Steinmetzbank · Webstuhl · Esse auf ihren Bauplätzen bauen (Material + Münzen)
  → ESSE: Meiler (Holzkohle, läuft allein) → Eisen schmelzen → Beschläge → Werkzeug Stufe 1/2
  → WEBSTUHL: Flachs → Garn → Leinen / Totenhemd
  → STEINMETZBANK: Grab wählen → Form × Inschrift × Zierde → Stein hauen → am Grab setzen
  → Grabqualität ↑ · Geister ruhiger · Friedhofsqualität ↑ · Münzen fließen in Werkzeug, Stationen, Gold
```
Werkzeuge liegen **passiv** am Werkzeuggürtel: Die beste Stufe gilt automatisch, es gibt kein Ausrüsten (§2.3).

### 1.2 Freischaltung
- **Neues Spiel:** Phase 5 öffnet sich mit dem Phase-3-Ziel `cemetery_complete` (bisher ≈ Tag 12–13). Am ersten Morgen danach (erste Minute ≥ 06:00, idempotent) setzt `Workshop.apply_morning` das Flag `workshop_open`. Ab dann hat Osric den Knoten `p5_intro`. So fallen die Phase-4-Tage 13–19 (Holunderwinkel, S3–S5) mit den ersten Phase-5-Tagen zusammen: Der Webstuhl liefert Leinen für die letzten Totenhemden, die Steinmetzbank die ersten gestalteten Steine für neue Gräber.
- **Migrierte Stände (v3):** Ist `cemetery_complete` gesetzt, setzt `Workshop.post_load` `workshop_open` sofort (auch nach 06:00). Ein Phase-4-Endstand (alle 18 Gräber belegt, Lieferungen ruhen) beginnt damit direkt den Phase-5-Bogen (§1.4).
- Vor `workshop_open` sind alle Phase-5-Sammelstellen, Bauplätze und Händlerwaren unsichtbar bzw. ohne Prompt. Die Erlen im Schlag stehen als Kulisse.

### 1.3 Zeitkosten (Spielminuten; TimedAction wie bisher)
| Handlung | Min (Stufe 0 / 1 / 2) | Braucht | Abbrechbar |
|---|---|---|---|
| Station bauen (Bauplatz) | 90 / 90 / 120 (Steinmetzbank / Webstuhl / Esse) | Material + Münzen (§2.1) | nein |
| Grab ausheben | 60 / 50 / 35 | Schaufel | ja (wie bisher) |
| Bestatten | 30 / 25 / 20 | Schaufel | ja |
| Erle fällen | – / 50 / 35 | Axt ≥ 1 | ja |
| Findling brechen | – / 50 / 35 | Spitzhacke ≥ 1 | ja |
| Bruchstein schlagen | – / 25 / 20 | Spitzhacke ≥ 1 | ja |
| Erz abbauen | – / 30 / 25 | Spitzhacke ≥ 1 | ja |
| Werkstein brechen | – / – / 25 | Spitzhacke 2 | ja |
| Lehm stechen | 30 / 25 / 20 | Schaufel | ja |
| Flachs raufen · Beeren pflücken · Kräuter schneiden | 20 · 10 · 10 | – | ja |
| Hindernisse Phase 3/4 (Brombeere, Hecke, Dickicht → Axt; Stumpf, Grube → Schaufel; Feldsteinhaufen → Spitzhacke) | Basis × Faktor (§2.3) | wie bisher, Werkzeug nur schneller | ja |
| Handwerk an einer Station | laut Rezept (§2.4) | Zutaten | nein |
| Meiler aufschichten (dann 480 Min allein) · Holzkohle holen | 10 · 5 | 4 Holz | nein |
| Stein hauen (Steinmetzbank) | Form + Inschrift + Vergolden + Zierde (§2.5) | Material | nein |
| Gestalteten Stein setzen (am Grab) | 20 | fertiger Stein für dieses Grab | ja |

Rundung: `minuten = max(5, round(basis × faktor / 5) × 5)`, Faktoren §2.3.
*Begründung:* Phase 5 braucht keine neue Zeitquelle. Ein voller Friedhof kostet ≈ 60–85 Min Pflege am Tag. Der Rest eines Tages (≈ 12 h) reicht für einen Bau oder eine Handwerkskette **oder** einen großen Stein, aber nicht für alles zugleich. Diese Wahl ist gewollt.

### 1.4 Tagesbogen
**A) Referenz: Phase-4-Endstand (würdevoll, Tag 20, 121 Münzen, 18 Gräber, keine Lieferungen mehr).** Der Bogen dauert **8–10 Tage**. Richtwert Mensch; der Bot `reverent5` spielt ihn nach (§10).
| Tag (Bogen) | Geschehen | Münzen (Richtwert, §2.8) | Zielzeile (Beispiel) |
|---|---|---|---|
| 20 (B1) | Osric `p5_intro`: Lorenz' alter Werkplatz am Bruch. **Steinbruchbrief** (20). Ostpforte aufschließen. Lehm, Flachs. **Steinmetzbank** bauen (15). | 121 → 86 | „Sprich mit Osric über den Bruch" → „Bauplatz: Steinmetzbank" |
| 21 (B2) | Osric: 4 Eisenbeschläge (12), **Alte Spitzhacke** (14). **Webstuhl** (10). Erste Stele mit Inschrift für ein Grab mit schlichtem Stein. | 90 → 54 | „Ein Stein liegt bereit – setz ihn bei Marthe Quendel" |
| 22 (B3) | **Esse** (25), 2 Beschläge für die Axt (6). Meiler angesteckt. | 58 → 27 | „Meiler brennt – Holzkohle morgen früh" |
| 23 (B4) | Findlinge brechen → **Steinbruch** frei. Erz, Bruchstein. Holzfälleraxt. Erste Erlen. | 31 | „Steinbruch: Erz und Bruchstein" |
| 24 (B5) | Eisen schmelzen, Beschläge, Eisenschaufel. **Stahlstab** (6) → **Meisterhacke**. | 35 → 29 | „Werkzeug: Schaufel 1 · Axt 1 · Spitzhacke 2" |
| 25 (B6) | Werkstein. Rundbogenstein für ein zweites Grab. Nachts bei Ilse **Blattgold** (6). | 33 → 27 | – |
| 26 (B7) | **Meisterstein** (Werkstein, Klammern, Inschrift, vergoldet, Zierde) für eine Geschichts-Tote → gesetzt → **Kapitel „Namen in Stein"**. | 31 | „Setz den Meisterstein" |
| 27–29 (B8–B10) | Freies Spiel: weitere Gräber neu setzen, Meisterschaufel/-axt (12), Blattgold (12). | 35 → 19 | „Gräber ohne Namen: 11" |

**B) Neues Spiel:** `cemetery_complete` ≈ Tag 12–13 → B1–B3 laufen parallel zu den Phase-4-Tagen 13–19 (die täglichen Leichen verbrauchen 2–3 h). Richtwert Kapitelende „Namen in Stein" ≈ Tag 24–28, nach „Sechs Gruben" (≈ Tag 19). Beide Kapitel sind unabhängig voneinander; keins sperrt das andere.

### 1.5 Phasenziel – Kapitel „Namen in Stein" (`names_in_stone`)
Erfüllt, sobald **alle** gelten (geprüft von `Workshop.check_goal` bei `station_built`, `tool_tier_changed`, `grave_stone_set`):
1. Steinmetzbank, Webstuhl und Esse gebaut.
2. Werkzeug: Schaufel ≥ 1, Axt ≥ 1, **Spitzhacke 2** (ohne sie gibt es keinen Werkstein).
3. Mindestens **ein Meisterstein** (`stone_master`) mit Inschrift gesetzt.

Dann: Flag `names_in_stone_complete`, `chapter_completed(&"names_in_stone")`, Abschluss-Panel Variante `names_in_stone` (Tage seit `workshop_open`, gebaute Stationen, Werkzeugstufen, gesetzte Steine davon Meistersteine, Gräber mit Namen n/18, in Phase 5 ausgegebene Münzen nach Zweck, Geister zufrieden vorher → jetzt). Schlusszeile: „Die Namen stehen jetzt da, wo der Regen sie nicht wegwäscht." Danach läuft das Spiel frei weiter. **Gate-Ziel:** Alle Bot-Strategien erreichen das Kapitel; der verwertende Weg ist nicht gesperrt (Steine kann jeder hauen).

---

## 2. Spielwerte (Vorschläge, alle in `data/`)

### 2.1 Stationen (`data/stations/<id>.tres` – `StationData`, `data/config/workshop_config.tres` – `WorkshopConfig`)
**Bauweise – Entscheidung: feste Bauplätze statt freier Platzierung, als Werkhof um die Hütte (Benutzerentscheidung §14.2).** Um die Hütte liegen drei abgesteckte Bauplätze. Der Spieler baut dort per Bauplatz-Panel. *Begründung feste Plätze:* Freie Platzierung bräuchte Wege- und Kollisionsregeln zur Laufzeit und Bildschirmfotos ohne feste Lage. *Begründung Werkhof:* Hütte, Truhe, Bett, Werkbank und Leichentisch bleiben das Zentrum. Handwerk passiert dort, wo der Tag beginnt und endet. Rohstoffe holt man als Gang: zum Bruch ≈ 28 m (≈ 9 s bei 3,2 m/s), zum Schlag ≈ 22 m. Wege: Hüttentür ↔ Webstuhl ≈ 4 m, ↔ Steinmetzbank ≈ 7 m, ↔ Esse ≈ 9 m (westlich um die Hütte). Lage, versetzte Elemente und Routen: §4.1.

| Station | `id` | Bauplatz (x | z, rot_y) | Footprint (x × z) | Zugang (1,0 m) | Kosten | Min | Panel | Besonderes |
|---|---|---|---|---|---|---|---|---|---|
| Werkbank | `workbench` | bestehend (−2,5 | −8,4) | – | bestehend | – (vorhanden) | – | `crafting` | + 2 Rezepte (§2.4) |
| Steinmetzbank | `mason` | `site_mason` (−0,5 | −10,6), 0° | 2,6 × 1,6 m | Süd | 6 stone, 3 wood, **15 Münzen** (Meißelsatz aus Hollerbrück) | 90 | `stone_design` | Ablage für **3 fertige Steine** (Marker `stone_slot_1…3`, Ostende) |
| Webstuhl | `loom` | `site_loom` (−8,6 | −1,3), 0° | 2,2 × 1,8 m | Süd | 8 wood, 2 iron_fittings, **10 Münzen** (Webkamm und Schäfte) | 90 | `crafting` | unter einem kleinen Pultdach |
| Esse | `forge` | `site_forge` (−7,3 | −11,1), 0° | 2,6 × 2,0 m (+ Meiler Ø 1,4 m bei (−4,6 | −11,4)) | West (Gang zum Pförtchen) | 10 stone, 6 clay, 2 iron_fittings, **25 Münzen** (Amboss und Blasebalg) | 120 | `crafting` | **Meiler** als einziger Hintergrund-Auftrag; Glut-Licht |

- Bauplatz-Prompt: „[E] Bauplatz: Steinmetzbank" → Panel mit Kosten (vorhanden/fehlt), Dauer, Vorschaubild, Knopf „Bauen (90 Min)". Fehlt etwas → Knopf gedimmt mit „Es fehlt: 2 Stein, 5 Münzen". Bau = TimedAction (nicht abbrechbar). Verbraucht wird **erst am Ende**, atomar (Items + Münzen). Danach ersetzt die Station das Bauplatz-Modell.
- Stationen lassen sich nicht abreißen oder versetzen.
- Die Münzen stehen für Teile aus Hollerbrück, die Osric schon mitgebracht hat. Es gibt keine Warte- oder Liefertage.
- **Meiler (Esse):** Rezept `charcoal` mit `background = true`: 10 Min aufschichten (4 wood), danach 480 Spielminuten allein (Rauchfaden am Meiler), dann „[E] Holzkohle holen (3)". Höchstens **ein** Hintergrund-Auftrag je Station. Webstuhl und Steinmetzbank arbeiten nur, solange der Spieler dort steht. *Begründung:* Ein einziges „läuft allein" gibt dem Abend einen Plan (Meiler anstecken, morgen schmieden), ohne eine zweite Warteschlangen-Logik.
- `WorkshopConfig`: `unlock_flag &"cemetery_complete"`, `open_flag &"workshop_open"`, `license_flag &"bruch_license"`, `intro_minute 360`, `goal_stations [mason, loom, forge]`, `goal_tiers {shovel: 1, axe: 1, pickaxe: 2}`, `goal_master_stones 1`, `chapter_id &"names_in_stone"`, `ready_slots 3` (Steinablage).

### 2.2 Rohstoffe & Sammelstellen (`data/gather/<kind>.tres` – `GatherNodeData`)
**Regeln**
- Eine Sammelstelle hat **Ladungen** (`charges_max`). Eine Aktion kostet eine Ladung und gibt `yield_amount` (+ Bonus bei Werkzeugstufe 2).
- **Nachwachsen:** Beim `day_started` wird eine Stelle mit `charges < charges_max` voll, wenn `tag − last_taken_day ≥ regrow_days`. Tägliche Stellen haben `regrow_days 1`. Berechnet aus der Tageszahl, nie aus Ticks, idempotent (`last_refresh_day`).
- Leer → Prompt „Abgeerntet – in 2 Tagen wieder" (Rest aus `regrow_days`). Werkzeug fehlt → „Holzfälleraxt nötig – Esse" (gedimmt). Abschnitt gesperrt → „Findlinge versperren den Weg." Kein Platz → „Kein Platz im Inventar".
- Sichtbare Stufen (Modelltausch): `full` · `empty` (· `regrowing` nur bei Erlen: Stumpf 0–1 Tage, Schössling 2–4 Tage, Baum ab Tag 5).

| Stelle (Anzahl) | `kind` | Item | Ertrag | Ladungen | Nachwachsen | Werkzeug (min.) | Basis-Min | Bonus Stufe 2 | Ort |
|---|---|---|---|---|---|---|---|---|---|
| Schlag-Erle (5) | `alder` | `wood` | 4 | 1 | 5 Tage | Axt ≥ 1 | 60 | +1 | Schlag am Kutschweg |
| Flachsbeet (3) | `flax_bed` | `flax` | 3 | 1 | 3 Tage | – | 20 | – | Am Bruch |
| Lehmkuhle (1) | `clay_pit` | `clay` | 2 | 3 | täglich | Schaufel ≥ 0 | 30 | +1 | Am Bruch |
| Bruchsteinwand (1) | `rubble_face` | `stone` | 2 | 4 | täglich | Spitzhacke ≥ 1 | 30 | +1 | Steinbruch |
| Erzader (1) | `ore_vein` | `iron_ore` | 1 | 3 | täglich | Spitzhacke ≥ 1 | 40 | – | Steinbruch |
| Werksteinbank (2) | `workstone_ledge` | `workstone` | 1 | 2 | täglich | Spitzhacke 2 | 45 | – | Steinbruch |
| Holunder (3, bestehend) | `elder_bush` | `elderberries` | 2 | 1 | 2 Tage | – | 10 | – | Holunderwinkel |
| Kräuterrain (4) | `herb_patch` | `herbs` | 1 | 2 | 2 Tage | – | 10 | – | 2 Am Bruch, 2 im Schlag |
| **Findling** (3, Hindernis) | `boulder` (`ClearableData`) | `stone` | 3 | einmalig | – | Spitzhacke ≥ 1 | 60 | – | Zugang Steinbruch |

**Tagesmengen bei voller Nutzung** (Stufe 1): Holz 6 (Haufen) + 4 (Erlen) = 10 · Stein 4 (Haufen) + 8 (Bruchstein) = 12 · Lehm 6 · Erz 3 · Werkstein 4 (Stufe 2) · Flachs ≈ 3 · Beeren ≈ 3 · Kräuter ≈ 4. Der bestehende Holz- und Steinhaufen (`ResourceNode`, 6/4 je Tag) bleibt unverändert.
*Begründung:* Erz ist der Engpass (3/Tag → 1,5 Barren). Das Werkzeug-Upgrade zieht sich damit über 2–3 Tage und kann nicht an einem Nachmittag passieren. Werkstein erst mit der Meisterhacke macht den Meisterstein zum Endpunkt der Werkzeugkette. Die Erlen wachsen als Stockausschlag nach (Niederwald: Man fällt den Stamm, der Stock treibt neu aus). 5 Tage sind für ein Diorama schnell, aber lesbar.

**Rohstoffe & Zwischenprodukte** – `ItemData.Category` erhält **`MATERIAL` (6) am Ende** (Werkstoff: nur im Inventar, nicht in der HUD-Ressourcenleiste, sonst liefe sie über).
| id | Name | Kategorie | Stapel | Herkunft |
|---|---|---|---|---|
| `flax` | Flachs | MATERIAL | 30 | Flachsbeet |
| `yarn` | Leinengarn | MATERIAL | 30 | Webstuhl |
| `clay` | Lehm | MATERIAL | 30 | Lehmkuhle |
| `iron_ore` | Eisenerz | MATERIAL | 20 | Erzader |
| `iron_bar` | Eisenbarren | MATERIAL | 20 | Esse |
| `charcoal` | Holzkohle | MATERIAL | 30 | Meiler |
| `workstone` | Werkstein | MATERIAL | 10 | Werksteinbank |
| `elderberries` | Holunderbeeren | MATERIAL | 20 | Holunder |
| `herbs` | Kräuter (Rainfarn & Beifuß) | MATERIAL | 20 | Kräuterrain |
| `ink` | Holundertinte | MATERIAL | 10 | Werkbank |
| `herb_bundle` | Räucherkräuter | MATERIAL | 10 | Werkbank |
| `gold_leaf` | Blattgold | MATERIAL | 10 | Ilse, 6 Münzen |
| `steel_rod` | Stahlstab | MATERIAL | 5 | Osric, 6 Münzen |
Bestehend und weiter genutzt: `wood`, `stone`, `linen`, `iron_fittings` (Osric 3 Münzen **oder** Esse), `burial_gown`.

### 2.3 Werkzeuge (`data/config/tool_config.tres` – `ToolConfig`, `data/config/action_config.tres` – `ActionConfig`)
**Halten – Entscheidung: Werkzeuggürtel, passiv.** Items der Kategorie `TOOL` belegen im **Spieler**-Inventar keinen Slot mehr, sondern hängen am Gürtel (wie Münzen außerhalb der Slots, höchstens 1 je id). Das gilt für alle Werkzeuge, auch Rechen, Wurzelbürste, Kamm, Schere und Zange. Es gibt kein Ausrüsten: Je Werkzeugart zählt die **höchste** Stufe am Gürtel. Die Truhe bleibt ein normales Slot-Inventar. *Begründung:* Mit 5 Pflege-/Verwertungswerkzeugen und 3 neuen Werkzeugarten wären sonst 8 von 16 Slots dauerhaft belegt, während 13 neue Werkstoffe hinzukommen. Das Spieler-Inventar wächst zusätzlich von **16 auf 20 Slots** (`PlayerConfig.inventory_slots`).

| Art | Stufe 0 (immer da) | Stufe 1 | Stufe 2 | Neue Aufgaben |
|---|---|---|---|---|
| Schaufel `shovel` | Alte Schaufel | **Eisenschaufel** `shovel_iron` (Esse) | **Meisterschaufel** `shovel_master` | keine – nur schneller (Graben, Bestatten, Lehm, Stumpf, Grube); Stufe 2: Lehm +1 |
| Axt `axe` | Altes Beil | **Holzfälleraxt** `axe_iron` (Esse) | **Meisteraxt** `axe_master` | Stufe 1: **Erlen fällen**; Stufe 2: +1 Holz je Erle |
| Spitzhacke `pickaxe` | – (keine) | **Alte Spitzhacke** `pickaxe_iron` (Osric, 14 Münzen) | **Meisterhacke** `pickaxe_master` (Esse) | Stufe 1: **Findlinge, Erz, Bruchstein**; Stufe 2: **Werkstein**, Bruchstein +1 |

- `ItemData` erhält `tool_kind: StringName` und `tool_tier: int` (✦). Stufe-0-Werkzeuge sind **keine** Items (sie waren nie im Inventar).
- **Faktoren** `ActionConfig.tool_tier_factors = [1.0, 0.8, 0.6]`; `ActionConfig.action_tools = {dig: shovel, bury: shovel}`; `ActionConfig.tool_minutes(base, tier)` rundet wie §1.3. Hindernisse: `ClearableData.tool_kind`/`min_tier` (bramble/hedge/elder_thicket → axe 0; stump/sunken_pit → shovel 0; rubble → pickaxe 0; **boulder → pickaxe 1**; fence_gap/gate_small → keins). Sammelstellen: `GatherNodeData.tool_kind/min_tier`.
- **Aufwerten** = Rezept an der Esse, das das niedrigere Werkzeug als Zutat **verbraucht** (am Gürtel bleibt je Art ein Werkzeug). Nach dem Handwerk: `tool_tier_changed(kind, tier)` und die Notiz „Graben dauert jetzt 35 statt 50 Minuten."

| Aktion | Stufe 0 | Stufe 1 | Stufe 2 |
|---|---|---|---|
| Grab ausheben (60) | 60 | 50 | 35 |
| Bestatten (30) | 30 | 25 | 20 |
| Erle fällen (60) | – | 50 | 35 |
| Findling / Stumpf / Hecke (60) | – / 60 / 60 | 50 | 35 |
| Feldsteinhaufen (40) | 40 | 30 | 25 |
| Erz (40) · Werkstein (45) · Bruchstein (30) · Lehm (30) | – · – · – · 30 | 30 · – · 25 · 25 | 25 · 25 · 20 · 20 |
*Begründung:* 0,8/0,6 spart am Tag mit einem Grab 25 Min und an einem Arbeitstag am Bruch 1–1,5 h. Das ist spürbar, macht Zeit aber nicht wertlos. Stärkere Faktoren (0,5) würden die Tagesplanung aus Phase 3/4 aushebeln. Die neuen Aufgaben tragen den Rest.

### 2.4 Rezepte (`data/recipes/<id>.tres`) – 13 neue
`RecipeData` erhält `background: bool = false` (✦). Neue `category`-Werte: `material`, `tool` (bestehend), `grave` (bestehend).
| Station | `id` | Name | Zutaten | Ergebnis | Min | `category` |
|---|---|---|---|---|---|---|
| forge | `charcoal` | Meiler anstecken | 4 wood | 3 charcoal | 10 + **480 allein** | material |
| forge | `iron_bar` | Eisen schmelzen | 2 iron_ore, 1 charcoal | 1 iron_bar | 45 | material |
| forge | `iron_fittings_forge` | Beschläge schmieden | 1 iron_bar | 2 iron_fittings | 30 | material |
| forge | `shovel_iron` | Eisenschaufel | 2 iron_fittings, 1 wood | 1 shovel_iron | 30 | tool |
| forge | `axe_iron` | Holzfälleraxt | 2 iron_fittings, 1 wood | 1 axe_iron | 30 | tool |
| forge | `shovel_master` | Meisterschaufel | 1 shovel_iron, 2 iron_bar, 1 charcoal, 1 steel_rod | 1 shovel_master | 60 | tool |
| forge | `axe_master` | Meisteraxt | 1 axe_iron, 2 iron_bar, 1 charcoal, 1 steel_rod | 1 axe_master | 60 | tool |
| forge | `pickaxe_master` | Meisterhacke | 1 pickaxe_iron, 2 iron_bar, 1 charcoal, 1 steel_rod | 1 pickaxe_master | 60 | tool |
| loom | `yarn` | Garn spinnen | 2 flax | 1 yarn | 20 | material |
| loom | `linen_woven` | Leinen weben | 3 yarn | 2 linen | 40 | material |
| loom | `burial_gown_loom` | Totenhemd weben | 1 linen, 2 yarn | 1 burial_gown | 30 | grave |
| workbench | `ink` | Holundertinte ansetzen | 2 elderberries, 1 herbs | 2 ink | 15 | material |
| workbench | `herb_bundle` | Räucherkräuter binden | 3 herbs | 1 herb_bundle | 10 | material |
Dazu an der Steinmetzbank die **3 Steinformen** (§2.5, keine `RecipeData`).

**Ketten**
- Flachs → Garn → Leinen → Totenhemd: 3 Flachs je Leinen. Ein gewebtes Totenhemd kostet 1 Leinen + 2 Garn = **7 Flachs** statt 3 gekaufter Leinen (9 Flachs-Äquivalente oder 6–9 Münzen). Das Werkbank-Totenhemd (3 linen) bleibt unverändert.
- Erz + Holzkohle → Eisenbarren → Beschläge / Werkzeug Stufe 2. Ein Barren = 2 Beschläge = 6 Münzen bei Osric.
- Holunder + Kräuter → Tinte → Inschrift. Kräuter → Räucherkräuter (§2.6).
- Stein / Lehm / Werkstein + Beschläge → Grabstein (§2.5). Lehm → Esse (Bau) und Mörtel der großen Steine.
*Begründung:* Jede Kette endet an einem Grab (Totenhemd, Stein, Räuchern) oder an einem Werkzeug. Es gibt keine Zwischenprodukte ohne Zweck und keine Verkaufsschleife.

### 2.5 Grabstein-Gestaltung (`data/stone/{shapes,inscriptions,ornaments}/*.tres`, `data/config/stone_config.tres` – `StoneConfig`)
**Entscheidung: je Grab, gewählt an der Steinmetzbank.** Man wählt an der Bank ein **bestimmtes Grab** (Liste: `FILLED` oder `MARKED`, mit Leiche). Die Inschrift füllt Name und Daten dieses Toten sofort ein, und die Vorschau zeigt den echten Text. Der fertige Stein ist **kein Inventar-Item**. Er steht an der Bank (Ablage 3 Plätze, sichtbar) und wird am Grab mit „[E] Gestalteten Stein setzen (20 Min)" gesetzt. *Begründung:* Das Inventar kennt keine Item-Einzelstücke mit Daten. Ein fertiger Stein je Grab braucht weder Metadaten noch einen Zuordnungsschritt am Grab, und der Name steht fest, sobald der Stein gehauen ist. Der Spieler wählt, was er wählen soll (Form, Spruch, Zierde), und die Welt füllt ein, was feststeht (Name, Daten).

**Formen** (`StoneShapeData`, `marker_id` = id; `EconomyConfig.marker_quality` wird ergänzt)
| Form | `id` | Punkte | Zutaten | Min | Modell |
|---|---|---|---|---|---|
| Schlichte Stele | `stone_stele` | 3 | 4 stone | 50 | `ph_prop_gravestone_stele` |
| Rundbogenstein | `stone_arch` | 4 | 5 stone, 1 clay | 70 | `ph_prop_gravestone_arch` |
| **Meisterstein** (breit, Sockel, Giebel, Eisenklammern) | `stone_master` | 5 | 3 workstone, 2 stone, 2 iron_fittings, 1 clay | 150 | `ph_prop_gravestone_master` |
Bestehend bleiben `wooden_cross` 1 und `gravestone_simple` 3 (Werkbank, Inventar-Item, Grabzeichen-Tausch wie bisher).

**Aufschläge** (für alle Formen)
| Teil | Punkte | Kosten | Min | Regel |
|---|---|---|---|---|
| Inschrift (Vorlage) | +1 | 1 ink | +20 | Name + Daten + Spruch; ohne Inschrift bleibt der Stein namenlos |
| Passende Inschrift | +1 | – | – | Vorlage passt zum Toten (Ursache, Alter oder Geschichte; UI zeigt „passt zu Marthe Quendel") |
| Vergoldet | +1 | 1 gold_leaf | +10 | nur mit Inschrift |
| Zierde (1 aus 4) | +1 | – | +25 | Relief an der Stirnseite |
**Höchstwerte:** Stele 7 · Rundbogen 8 · Meisterstein **9** (bisher bester Stein 3). **`EconomyConfig.quality_max` 13 → 19** (2+1+3+1+9+1+1+1). Gräber vor Phase 5 behalten ihre gespeicherte Qualität, bis sie einen neuen Stein bekommen.
Beispiel Meisterstein komplett: 150 + 20 + 10 + 25 = **205 Min**, 3 Werkstein, 2 Stein, 2 Beschläge, 1 Lehm, 1 Tinte, 1 Blattgold.

**Inschrift-Vorlagen** (`InscriptionData`, eigene Texte; `{name}`, `{born}`, `{died}`, `{age}`)
| `id` | Titel | Zeilen | passt zu |
|---|---|---|---|
| `i_rest` | Hier ruht | „Hier ruht" · „{name}" · „{born} – {died}" | – (immer möglich, nie „passend") |
| `i_long_road` | Ein langer Weg | „{name}" · „{born} – {died}" · „Ein langer Weg, gut gegangen." | Alter ≥ 60 |
| `i_too_soon` | Zu früh | „{name}" · „{born} – {died}" · „Zu früh. Viel zu früh." | Alter ≤ 35 |
| `i_water` | Was das Wasser nahm | „{name}" · „{died}" · „Das Wasser nahm dich. Die Erde hält dich." | `drowned_millpond`, `moor_cold` |
| `i_fever` | Die Hitze ist vorbei | „{name}" · „{born} – {died}" · „Die Hitze ist vorbei. Schlaf kühl." | `fever`, `poisoned` |
| `i_road` | Mitten im Weg | „{name}" · „{born} – {died}" · „Mitten im Weg. Nun angekommen." | `coach_accident`, `fall_hayloft` |
| `i_garden` | Was du gesät hast | „{name}" · „{born} – {died}" · „Was du gesät hast, blüht noch." | Geschichte `s1_quendel` |
- **Daten:** `{died}` = Tag der Ankunft (Spieltag aus `CorpseRecord.arrival_total_minutes` mit der Umrechnung des TimeManagers; ohne Wert: `buried_day`) als Kalenderdatum: Spieltag 1 = **3. Gilbhart 1834** (alte deutsche Monatsnamen: Hartung, Hornung, Lenzing, Ostermond, Wonnemond, Brachet, Heuet, Ernting, Scheiding, Gilbhart, Nebelung, Julmond; echte Monatslängen). `{born}` = „* " + (Todesjahr − Alter), also nur das Jahr. Beispiel: „† 8. Nebelung 1834", „* 1771". Jahr und Startdatum stehen in `StoneConfig.calendar` (Benutzerentscheidung §14.3).
- Der Text wird beim Hauen **festgeschrieben** (`StoneDesign.text`). `{name}` ist der Registername ohne den Zusatz „ (?)" – S5 heißt vor der Erkenntnis im Stein also „Lorenz Aschau". Wird S5 danach in „Kaspar Dorn" umbenannt, behält ein schon gehauener Stein den alten Namen. Ein neuer Stein ist möglich (gleiche Regeln). Der Geist S5 hat dafür eine Zeile (§2.5 Geister).
- Namen länger als 22 Zeichen werden in zwei Zeilen umbrochen; höchstens 4 Zeilen je Stein.

**Zierden** (`OrnamentData`, Relief-Modelle am Marker `ornament`)
| `id` | Name | Bedeutung (Tooltip) |
|---|---|---|
| `orn_ivy` | Efeuranke | „Was grün bleibt, wenn alles welkt." |
| `orn_poppy` | Mohnkapsel | „Für einen langen, ruhigen Schlaf." |
| `orn_elder` | Holunderdolde | „Hollerbrücks Blüte. Sie hält fern, was nicht herein soll." |
| `orn_torch` | Gesenkte Fackel | „Ein Licht, das ausgegangen ist." |
Alle +1, 25 Min, ohne Material. Die Wahl ist Ausdruck, keine Optimierung.

**Setzen & Kompatibilität**
- `Stonemasonry.order_block_reason`: Das Grab muss `FILLED` oder `MARKED` sein, und der neue Stein muss mehr Grabzeichen-Punkte bringen als das aktuelle Zeichen (Kreuz 1, Grabstein 3, gestalteter Stein = seine Summe). Sonst steht es gedimmt in der Liste: „Der jetzige Stein ist schon besser." Für ein Grab liegt höchstens ein fertiger Stein bereit. Bei voller Ablage: „Die Ablage ist voll – setz erst einen Stein."
- **FILLED → MARKED:** wie `place_marker`, mit Bezahlung (`base + floor(Q × 0,5) + Ruf-Bonus`; ein Meisterstein-Grab zahlt bis zu 3 Münzen mehr), Ruf „Grab gut/schlecht", Geister wie bisher.
- **MARKED → MARKED (neu setzen):** wie `upgrade_marker`: neue Qualität und Aufschlüsselung, **keine** zweite Bezahlung, Ruf `marker_upgrade +1`; ein Meisterstein zusätzlich Ruf `master_stone +3` („Ein Meisterstein auf dem Friedhof. Das spricht sich herum.", einmal je Grab). Der alte Stein ist weg (wie beim Kreuz → Stein).
- Ist ein fertiger Stein nicht mehr besser (in der Zwischenzeit anderer Stein gesetzt), zeigt die Bank ihn als „passt nicht mehr" mit „Verwerfen" (Material verloren, nie automatisch).
- Der Grabzeichen-Tausch aus Phase 3 (`upgrade_options` über Inventar-Items) bleibt unverändert. Gestaltete Steine sind keine Items und tauchen dort nie auf.

**Grabqualität – Aufschlüsselung** (`GraveQuality.breakdown(…, design)`): statt der Zeile „Grabstein +3" z. B. „Meisterstein +5", „Inschrift +1", „Passende Inschrift +1", „Vergoldet +1", „Zierde: Holunderdolde +1".

**Geister** (`GhostMood`, `GhostLines`)
- Der Stimmungswert enthält die Grabqualität (unverändert). Ein gestalteter Stein hebt ihn um bis zu **+6** gegenüber dem schlichten Grabstein.
- Neuer Grund **`nameless`** (Stein ohne Inschrift), Priorität nach `cross`: `robbed` → `weeds` → `valuables` → `cold` → `unkempt` → `cross` → **`nameless`** → `waited` → `bare`. Zeilen (P4): „Ein Stein, aber kein Name. Wer soll mich finden?" · „Die Leute gehen vorbei und raten, wer hier liegt." · „Schreib mich auf, Totengräber. Nur den Namen."
- Neuer Pool **`by_design`** (einmal je Grab in der ersten Nacht nach dem Setzen, zufrieden/gleichmütig): „Da steht mein Name. Ich hatte ihn fast vergessen." · „So schön hat mich keiner gekannt." · „Gold? Für mich? Na, na." (vergoldet) · „Ein Stein wie für einen Ratsherrn. Die im Dorf werden reden." (Meisterstein) · S5 mit „Lorenz Aschau" im Stein: „Da steht Lorenz' Name. Er würde lachen."
- **Wirkung in Zahlen:** Mixed-Grab (Zopf genommen, Tuch, schlichter Stein): 8 + 1 − 5 = 4 **unruhig** → mit Meisterstein komplett 10 **zufrieden**. Holzkreuz-Grab aus Phase 3 (Q 8): 9 gleichmütig → Rundbogen + Inschrift (+4): 13 zufrieden. Voll beraubt (Haar + Zähne): −4 → +6 = 2, **bleibt unruhig**. Ein Stein gibt nicht zurück, was genommen wurde. Das ist gewollt und steht in keiner Anzeige.

### 2.6 Handel (Osric `data/dialogue/carter.tres`, Ilse `data/config/trader_config.tres`)
| Ware | Wo | Preis | Grenze | Zweck |
|---|---|---|---|---|
| **Steinbruchbrief** der Gemeinde | Osric (`p5_intro`, danach im Menü) | **20** | einmal (Flag `bruch_license`) | öffnet Ostpforte, Lehmkuhle, Flachs, Steinbruch |
| **Alte Spitzhacke** | Osric | **14** | einmal (Flag `bought_pickaxe`) | Spitzhacke Stufe 1 |
| **Stahlstab** | Osric | **6** | – | Stufe-2-Werkzeuge |
| Eisenbeschlag | Osric (bestehend) | 3 | – | Stationen, Werkzeug Stufe 1, Meisterstein |
| **Blattgold** | Ilse (Laden) | **6** | 2 je Nacht | Vergolden |
| Leinen / Wacholder | Osric 3/2 · Ilse 2/1 (bestehend) | – | – | unverändert |
- Osric `p5_intro` (einmal ab `workshop_open`, Leittext, P6 darf glätten): „Drüben am Bruch, hinter der Ostwiese, war Lorenz' alter Werkplatz. Da hat er seine Steine selbst gebrochen. Die Gemeinde verkauft dir den Brief dafür, zwanzig Münzen, die Lehmkuhle ist dabei." (Benutzerentscheidung §14.4: nur dieser eine Bezug, kein Hinweis im Merkbuch.) · Spitzhacke: „Eine alte Spitzhacke vom Wegebau. Vierzehn Münzen. Die Spitze ist stumpf, aber ehrlich." · Stahlstab: „Guter Stahl aus der Stadt. Sechs Münzen. Frag nicht, was der Schmied in Hollerbrück dafür nimmt."
- Ilse beim Blattgold (einmal): „Aus dem Nachlass eines Vergolders. Er hätte gewollt, dass es glänzt."
- **Räucherkräuter** (`herb_bundle`): gelten beim Räuchern wie `juniper` (`PrepConfig.balm_items = [juniper, herb_bundle]`, gleiche Wirkung). Selbst gebundene Kräuter ersetzen gekauften Wacholder. Das ist nur bei künftigen Leichen von Nutzen.
- **Kein Verkauf** von Phase-5-Waren (Steine, Leinen, Eisen). Das Dorf als Abnehmer kommt in Phase 7/10.

### 2.7 Ruf, Statistiken
- `ReputationConfig.event_points` + `master_stone 3`.
- `GameState.DEFAULT_STATS` + `crafted` (Handwerk abgeschlossen), `stones_set` (gestaltete Steine gesetzt), `coins_spent` (alle über `coins_spent` gemeldeten Ausgaben), `trees_felled`.
- Friedhofsstufen (15/32/50/100 + Ehrwürdig-Bedingung) bleiben unverändert. Gestaltete Steine heben die Friedhofsqualität um bis zu +6 je Grab (18 Gräber: bis +108). Die Stufe ändert sich dadurch nicht mehr, wohl aber Geister, Belohnungskarte und Register.

### 2.8 Münzrechnung (würdevoller Spieler, Ziel „größter Teil des Überschusses ausgegeben, nie arm")
**Ausgangslage (G4, `qa_playthrough.md` §3):** Bot `reverent` hat an Tag 19 125, an Tag 20 121 und an Tag 24 129 Münzen. Nach dem 18. Grab kommen keine Lieferungen mehr; Einnahmen sind nur noch das Pflegegeld „Gerühmt" = **4/Tag** (Geistergaben sind schon ausgezahlt).

**Pflichtausgaben für das Phasenziel**
| Posten | Münzen |
|---|---|
| Steinbruchbrief | 20 |
| Steinmetzbank (15) + Webstuhl (10) + Esse (25) | 50 |
| 4 Eisenbeschläge für Webstuhl und Esse (Osric, vor der eigenen Esse) | 12 |
| Alte Spitzhacke | 14 |
| 2 Eisenbeschläge für die Holzfälleraxt (vor dem ersten eigenen Barren) | 6 |
| Stahlstab für die Meisterhacke | 6 |
| **Summe Pflicht** | **108** |
**Freiwillig (so spielt der Bot `reverent5`):** Stahlstäbe für Meisterschaufel und -axt 12 · Blattgold für 3 Steine 18 → **30**.

**Verlauf (Bogen A, §1.4)**
| | B1 | B2 | B3 | B4 | B5 | B6 | B7 | B8 | B9 | B10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Morgens (+4 ab B2) | 121 | 90 | 58 | 31 | 35 | 33 | 31 | 35 | 27 | 19 |
| Ausgaben | 35 | 36 | 31 | 0 | 6 | 6 | 0 | 12 | 12 | 0 |
| Abends | 86 | 54 | 27 | 31 | 29 | 27 | 31 | 23 | 15 | 19 |
- Verfügbar: 121 + 9 × 4 = **157**. Ausgegeben: **138 (88 %)**. Ende: **≈ 19**, nie unter 15.
- Vom Überschuss (121) fließen 108 (89 %) in Pflichtposten. Der Rest ist Wahl: Wer lieber Polster behält, lässt die Meisterschaufel/-axt und das Gold weg und endet bei ≈ 50.
- *Warum nicht arm:* Jeder Pflichtkauf ist ein bleibender Gewinn (Station, Werkzeug, Zugang), kein Verbrauch. Das Pflegegeld läuft weiter, und alle Phase-4-Käufe (Leinen 2–3, Wacholder 1–2) bleiben jederzeit bezahlbar. Blattgold ist ein ruhiger Dauerabfluss: 18 Gräber × 6 = 108 Münzen für den, der sie alle vergolden will.

**Andere Wege (Erwartung für W3)**
| Weg | Start | Einnahmen/Tag | Ausgaben Phase 5 | Ende (≈ 10 Tage) | Bemerkung |
|---|---|---|---|---|---|
| verwertend (`harvester5`, Tag 25) | 179 | 0–1 (Ruf „Verrufen/Unauffällig") | 108 Pflicht, Gold nach Laune | ≈ 70–80 | reich, aber die Geister bleiben unruhig (§2.5) |
| neues Spiel (`crafter`) | ≈ 55–67 bei `cemetery_complete` | 11/Grab + 3–4 bis Tag 19 | 108–140 | ≈ 20–70 an Tag 30 | Webstuhl spart ≈ 20–30 Münzen Leinen bei den letzten 6 Leichen |
*Begründung Preise:* Die Pflichtsumme (108) liegt knapp unter dem Überschuss eines würdevollen Spielers an Tag 20 (121). Der teuerste Einzelposten (Esse 25) ist nach B2 noch bezahlbar. Kein Posten verlangt Sparen über mehrere Tage, außer man kauft alles am ersten Tag.

### 2.9 Übertrag aus Phase 4: Pietät-Fix (G4-Befund B2)
- `CorpseCare._after_prep`: Das Ereignis `full_prep` (+3 Pietät) kommt nur, wenn `record.harvested.is_empty()`. Gesteuert über **`PietyConfig.full_prep_requires_unharvested = true`** (✦). `stats.prepared` zählt weiter jede voll hergerichtete Leiche (das Merkbuch bleibt ehrlich). Grabqualität und Aufschlüsselung („Gewaschen", „Totenhemd", „Aufgebahrt") bleiben unverändert.
- Reihenfolge ist kein Schlupfloch: Verwerten geht nur vor dem Einkleiden, und „voll hergerichtet" braucht das Einkleiden. Zum Zeitpunkt der Prüfung steht also fest, ob verwertet wurde.
- Nicht rückwirkend: Die Pietät gespeicherter Stände bleibt.
- **Bot (W3):** Die Strategie `mixed` richtet an Verwerter-Tagen jetzt **ebenfalls voll her** (neue Flagge `prep_on_harvest`, genau das B2-Muster). Erwartung weiter „Sachlich" oder „Abgebrüht". Nachrechnung: gemessen 37 mit dem alten Bonus, ≈ 9 Verwerter-Leichen × −3 → ≈ 10 → „Sachlich". Zusätzlich geprüft: `stats.prepared` enthält die Verwerter-Leichen, und kein `piety_changed` mit Grund „Voll hergerichtet" gehört zu einer verwerteten Leiche.

---

## 3. Architektur

### 3.1 Neue Systemknoten (unter `WorldRoot/Systems`, vom Welt-Builder angelegt)
| Knoten | Klasse | Gruppen | save_id / save_order |
|---|---|---|---|
| `Workshop` | `Workshop` | `workshop`, `saveable` | `workshop` / **30** |
| `Gathering` | `GatherManager` | `gathering`, `saveable` | `gathering` / **25** |
| `Stonemasonry` | `Stonemasonry` | `stonemasonry`, `saveable` | `stonemasonry` / **35** |
Entitäten (Werkhof §4.1): `Entities/site_mason|site_loom|site_forge` (`BuildSite`), `Entities/station_mason|station_loom|station_forge` (bestehendes `Workbench` mit `station` + `requires_built`), `Entities/gather_*` (`GatherNode`, **nicht** einzeln saveable – Zustand im `GatherManager`), `Entities/obs_b_gate`, `obs_q_boulder_1…3` (`ClearableObstacle`). Keine neuen Autoloads. `Graveyard` (10) speichert `design` im GraveRecord.

### 3.2 Module & Besitz (Phase 5)
| Modul | Besitzt (Pfade) |
|---|---|
| **Lead** (W0 + laufend) | `project.godot`, `src/core/*` (EventBus, Database), alle **Datenklassen ✦**, alle **Stubs** (bis zur Übergabe), `tests/run_tests.gd`, `tests/framework/*`, `tests/fixtures/*` (inkl. **`saves_v3/*`**, `phase5/*`), `tests/integration/test_saves_v3_load.gd`, `tests/unit/test_phase5_scaffold.gd`, `docs/*`, `CLAUDE.md` |
| **P1 Werkstatt & Stationen** | `src/systems/workshop/{workshop,workshop_rules}.gd`, `src/systems/decoration/decoration_manager.gd` (nur `evict_rects`, §5.2), `src/entities/build_site/*`, `src/entities/workbench/*` (Station-Erweiterung: `requires_built`, Panel aus `StationData`, Hintergrund-Auftrag), `data/stations/*`, `data/config/workshop_config.tres`, `data/recipes/{charcoal,iron_bar,iron_fittings_forge,yarn,linen_woven,burial_gown_loom,ink,herb_bundle}.tres`, `src/systems/crafting/*` (nur Werkzeug-Ausgabe/-Eingabe + `tool_tier_changed`), `tests/unit/{test_workshop,test_crafting}.gd` |
| **P2 Rohstoffe, Sammeln & Hindernisse** | `src/systems/gathering/{gather_manager,gather_rules}.gd`, `src/entities/gather_node/*`, `data/gather/*`, `src/systems/expansion/expansion_manager.gd` (Arbeitsabschnitte: keine Plots, kein Ruf), `src/entities/clearable/clearable.gd` (Werkzeug-Sperre, Minuten), `data/sections/{bruch,quarry}.tres`, `data/clearables/*` (Werkzeugfelder + neu `boulder`, `gate_east`), `data/items/{flax,yarn,clay,iron_ore,iron_bar,charcoal,workstone,elderberries,herbs,ink,herb_bundle,gold_leaf,steel_rod}.tres`, `tests/unit/{test_gathering,test_expansion}.gd` |
| **P3 Werkzeuge & Inventar** | `src/systems/inventory/inventory.gd` (Werkzeuggürtel), `src/systems/tools/tool_rules.gd`, `src/entities/player/{player,player_action_runner}.gd` (nur `tool_tier`), `src/entities/grave/grave_plot.gd` (nur Minuten über Werkzeug), `src/entities/resource_node/resource_node.gd` (unverändert außer Minutenquelle), `data/config/{action_config,tool_config,player_config}.tres`, `data/items/{shovel_iron,shovel_master,axe_iron,axe_master,pickaxe_iron,pickaxe_master}.tres`, `data/recipes/{shovel_iron,axe_iron,shovel_master,axe_master,pickaxe_master}.tres`, `tests/unit/{test_inventory,test_tools,test_player}.gd` |
| **P4 Grabstein-Gestaltung, Qualität & Geister** | `src/systems/stone/{stone_design,stone_design_rules,stone_calendar,stonemasonry}.gd`, `data/stone/**`, `data/config/stone_config.tres`, `src/systems/graveyard/{graveyard,grave_record,grave_quality}.gd`, `data/config/economy_config.tres`, `src/entities/grave/grave_plot_visuals.gd` + Stein-Setzen in `grave_plot.gd` (**Absprache mit P3:** P3 ändert nur die Minuten-Zeilen, P4 den Rest), `src/systems/ghosts/{ghost_mood,ghost_manager}.gd`, `data/ghosts/ghost_lines.tres`, `data/config/{ghost_config,reputation_config}.tres`, `tests/unit/{test_stone_design,test_stonemasonry,test_grave_quality,test_graveyard,test_ghosts}.gd` |
| **P5 Assets** | `tools/blender/{asset_stations_phase5,asset_env_phase5,asset_stones_phase5}.py` (neu), `tools/blender/asset_items.py`, `tools/blender/build_all.py`, `assets/models/**` (nur neue Phase-5-Dateien), `art_source/blender/**` (Phase 5), `tests/unit/test_assets_phase5.gd`, `docs/reviews/phase5_assets/*` |
| **P6 Handel, Dialog, Speichern & Übertrag** | `src/systems/save/{save_migration,save_file_io,save_manager}.gd`, `data/dialogue/{carter,trader}.tres`, `src/systems/dialogue/dialogue_actions.gd` (nur `coins_spent` bei `take_item:coin`), `src/systems/utilization/night_trade.gd` (Blattgold, `coins_spent`), `data/config/{trader_config,piety_config,prep_config}.tres`, `src/systems/corpse/{corpse_care,corpse_prep}.gd` (**Pietät-Fix**, `balm_items`), `src/systems/game_state/game_state.gd` (Stats), `tests/unit/{test_save,test_save_migration,test_dialogue,test_night_trade,test_corpse_prep,test_piety,test_game_state}.gd`, `tests/integration/test_phase4_save_upgrade.gd` (neu) |
| **W-Welt** (W2) | `data/world/graveyard_layout.json` (inkl. **Werkhof und versetzter Holzhaufen**, §4.1), `src/world/graveyard/*` (Builder, neu `graveyard_build_phase5.gd`, `graveyard_shots_phase5.gd`, Bau-Maske und Gras neu gebacken), `src/world/camera/camera_rig.gd` (nur Grenzen), `tools/blender/asset_ground_graveyard.py` (Bodenerweiterung Ost), `tests/integration/{test_graveyard_world,test_phase5_loop}.gd`, `docs/reviews/phase5_round1/*` |
| **W-UI** (W2) | `src/ui/**` (neu `panels/{build_site_panel,stone_design_panel,stone_preview}.gd`, `phase5_texts.gd`), `assets/ui/**`, `tools/ui/*`, `src/debug/*` (neu `debug_commands_phase5.gd`; außer `asset_preview.gd`, `screenshot_capture.gd`), `tests/unit/{test_ui,test_objective,test_ui_phase5}.gd`, `tests/integration/test_ui_flow.gd` |
| **W3 QA** | `tests/integration/{phase3_bot,phase4_bot,phase5_bot,test_phase3_playthrough,test_phase4_playthrough,test_phase5_playthrough,test_phase5_qa,test_save_fuzzer}.gd`, `docs/reviews/phase5_wip/*` |
| **Eingefroren** | `src/world/art_prototype/*`, `src/entities/player/player_proto.*`, `data/art_prototype/*`, **Maler-Shader** (`painted.gdshader`, `painted_common.gdshaderinc`, `painted_foliage.gdshader`), `data/atmosphere/*`, `src/world/hut_interior/*`, Abschnitte I–IV im Layout (Plots, Zaun außer der Ostpforte, Hindernisse, Pflegestellen, alle Requisiten außer `res_wood`), **Hütte, Leichentisch, Werkbank, Pförtchen** |

✦ **Datenklassen (W0, Lead):** `StationData`, `WorkshopConfig`, `GatherNodeData`, `ToolConfig`, `StoneShapeData`, `InscriptionData`, `OrnamentData`, `StoneConfig`, `StoneDesign` (Wertobjekt). Erweiterungen: `ItemData` (+ `Category.MATERIAL`, `tool_kind`, `tool_tier`), `RecipeData.background`, `ClearableData` (+ `tool_kind`, `min_tier`), `SectionData.is_burial`, `ActionConfig` (+ `tool_tier_factors`, `action_tools`, `tool_minutes`), `PlayerConfig.inventory_slots`-Default 20, `EconomyConfig` (+ Formen in `marker_quality`, `quality_max 19`), `GhostLines` (+ `nameless`, `by_design`), `ReputationConfig.event_points` (+ `master_stone`), `PietyConfig.full_prep_requires_unharvested`, `PrepConfig.balm_items`, `TraderConfig.shop`-Default (+ `gold_leaf`).
Bei nur fünf Agents übernimmt P1 zusätzlich P6.

### 3.2.1 Klassen → Dateien
| Klasse | Datei | Art |
|---|---|---|
| `StationData`, `WorkshopConfig` | `src/systems/workshop/{station_data,workshop_config}.gd` | ✦ |
| `WorkshopRules`, `Workshop` | `src/systems/workshop/{workshop_rules,workshop}.gd` | Stub (P1) |
| `BuildSite` | `src/entities/build_site/build_site.gd` (+ `.tscn`) | Stub (P1) |
| `GatherNodeData` | `src/systems/gathering/gather_node_data.gd` | ✦ |
| `GatherRules`, `GatherManager` | `src/systems/gathering/{gather_rules,gather_manager}.gd` | Stub (P2) |
| `GatherNode` | `src/entities/gather_node/gather_node.gd` (+ `.tscn`) | Stub (P2) |
| `ToolConfig` | `src/systems/tools/tool_config.gd` | ✦ |
| `ToolRules` | `src/systems/tools/tool_rules.gd` | Stub (P3) |
| `StoneShapeData`, `InscriptionData`, `OrnamentData`, `StoneConfig`, `StoneDesign` | `src/systems/stone/{stone_shape_data,inscription_data,ornament_data,stone_config,stone_design}.gd` | ✦ |
| `StoneDesignRules`, `StoneCalendar`, `Stonemasonry` | `src/systems/stone/{stone_design_rules,stone_calendar,stonemasonry}.gd` | Stub (P4) |
| `BuildSitePanel`, `StoneDesignPanel`, `StonePreview` | `src/ui/panels/{build_site_panel,stone_design_panel,stone_preview}.gd` | W-UI |

### 3.3 EventBus – neue Signale (Ergänzung `src/core/event_bus.gd`)
```gdscript
# Werkstatt (Workshop)
signal station_built(station_id: StringName)
signal workshop_job_changed(station_id: StringName, recipe_id: StringName, state: StringName)   # &"started", &"ready", &"collected"
# Sammeln (GatherManager)
signal resource_gathered(node_id: String, item_id: StringName, amount: int)
signal gather_node_changed(node_id: String, charges: int, stage: StringName)                    # &"full", &"partial", &"empty", &"regrowing"
# Werkzeug (Workbench nach einem Werkzeug-Rezept, Player beim Laden nicht)
signal tool_tier_changed(kind: StringName, tier: int)
# Steine (Stonemasonry / Graveyard)
signal stone_order_changed(order_id: String, grave_id: String, state: StringName)             # &"ready", &"set", &"discarded"
signal grave_stone_set(grave_id: String, shape_id: StringName, quality: int)
# Münzen (jede Ausgabe über ein System: Bau, Osric, Ilse)
signal coins_spent(amount: int, reason: StringName)                                             # &"license", &"build", &"osric", &"ilse"
```
Regel wie Phase 3/4: **Listener ändern keinen Spielzustand.** Wer ändert, ruft direkt auf: `BuildSite` → `Workshop.build`; `GravePlot` → `Stonemasonry.set_stone` → `Graveyard.set_designed_stone`; `Workshop.check_goal` wird von `Workshop.build`, `Workbench._finish_craft` (Werkzeug) und `Graveyard.set_designed_stone` direkt gerufen. `coins_spent` erhöht `stats.coins_spent` im Sender (nicht im Listener).

### 3.4 Logik-Klassen (Signaturen = Vertrag)

**Werkstatt & Stationen (P1)**
```gdscript
class_name StationData extends Resource            # ✦ data/stations/<id>.tres
@export var id: StringName; @export var display_name: String; @export var site_id: String
@export var build_inputs: Dictionary[StringName, int] = {}; @export var build_coins: int = 0; @export var build_minutes: int = 90
@export var panel: StringName = &"crafting"        # &"crafting" | &"stone_design"
@export var prompt_use: String = ""                # „[E] Steinmetzbank benutzen"
@export_multiline var build_text: String           # Bauplatz-Beschreibung
@export var coin_part_label: String = ""           # „Meißelsatz aus Hollerbrück"
@export var prebuilt: bool = false                 # workbench: true
class_name WorkshopConfig extends Resource          # ✦ §2.1
@export var unlock_flag: StringName = &"cemetery_complete"; @export var open_flag: StringName = &"workshop_open"
@export var license_flag: StringName = &"bruch_license"; @export var intro_minute: int = 360
@export var goal_stations: Array[StringName] = [&"mason", &"loom", &"forge"]
@export var goal_tiers: Dictionary[StringName, int] = {&"shovel": 1, &"axe": 1, &"pickaxe": 2}
@export var goal_master_stones: int = 1; @export var chapter_id: StringName = &"names_in_stone"
@export var goal_flag: StringName = &"names_in_stone_complete"; @export var ready_slots: int = 3
class_name WorkshopRules extends RefCounted
static func build_block_reason(station: StationData, inv: Inventory, built: bool, open: bool) -> String   # "" | „Schon gebaut." | „Es fehlt: …"
static func missing(station: StationData, inv: Inventory) -> Dictionary                                  # {item_or_coin: fehlend}
static func goal_progress(built: Array[StringName], tiers: Dictionary, master_stones: int, cfg: WorkshopConfig) -> Dictionary   # {done: int, total: int, missing: PackedStringArray}
class_name Workshop extends Node                    # Systems/Workshop
func is_open() -> bool; func is_built(station_id: StringName) -> bool; func built() -> Array[StringName]
func build(station_id: StringName, inv: Inventory) -> bool   # atomar Items + Münzen; station_built, coins_spent(&"build"); check_goal
func start_job(station_id: StringName, recipe: RecipeData, inv: Inventory) -> bool   # nur background-Rezepte; Zutaten sofort; Ende = jetzt + craft_minutes
func job_of(station_id: StringName) -> Dictionary     # {} | {recipe, end_total, ready: bool}
func collect(station_id: StringName, inv: Inventory) -> int   # Ertrag ins Inventar (voll → 0, Auftrag bleibt)
func goal_progress() -> Dictionary; func check_goal() -> void # Kapitel §1.5 einmalig
func apply_morning(day: int) -> void                  # idempotent: workshop_open ab unlock_flag
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void; func post_load() -> void   # post_load: workshop_open sofort, wenn unlock_flag; Zier im Werkhof räumen (§5.2)
@export var workyard_rects: Array[Rect2] = []   # vom Builder aus layout.workyard.blocked_rects (Footprint + Rand + Zugang)
# DecorationManager (P1, nur Ergänzung): func evict_rects(rects: Array[Rect2]) -> Dictionary   # {decor_id: Anzahl} abgebaut, decor_changed je Stück
class_name BuildSite extends Node3D                  # Entities/site_<id> (Werkhof); sichtbar ab workshop_open ∧ nicht gebaut
@export var station_id: StringName
func request_build() -> void                          # Panel: TimedAction build_minutes (nicht abbrechbar) → Workshop.build
# Workbench (P1-Erweiterung): @export var requires_built: bool = false  # unsichtbar + ohne Kollision bis Workshop.is_built(station)
#   interact → Panel aus StationData.panel (Standard &"crafting"); request_craft: background-Rezept → Workshop.start_job;
#   läuft ein Auftrag und ist fertig → Prompt „[E] Holzkohle holen (3)" → Workshop.collect
#   _finish_craft: Ausgabe mit ItemData.tool_kind → tool_tier_changed + Workshop.check_goal
```

**Rohstoffe & Sammeln (P2)**
```gdscript
class_name GatherNodeData extends Resource          # ✦ data/gather/<kind>.tres (§2.2)
@export var id: StringName; @export var display_name: String; @export var verb: String   # „Erle fällen"
@export var item_id: StringName; @export var yield_amount: int = 1; @export var charges_max: int = 1
@export var regrow_days: int = 1; @export var minutes: int = 10
@export var tool_kind: StringName = &""; @export var min_tier: int = 0; @export var tier2_bonus: int = 0
@export var animation: StringName = &"interact"; @export var requires_flag: StringName = &"workshop_open"
@export var model_full: PackedScene; @export var model_empty: PackedScene; @export var model_regrow: PackedScene
@export var regrow_stage_days: PackedInt32Array = []  # alder: [2, 5] → Stumpf <2, Schössling <5
class_name GatherRules extends RefCounted
static func refreshed(state: Dictionary, day: int, data: GatherNodeData) -> Dictionary   # {charges, last_taken_day, last_refresh_day}
static func stage(state: Dictionary, day: int, data: GatherNodeData) -> StringName
static func days_left(state: Dictionary, day: int, data: GatherNodeData) -> int
static func block_reason(state: Dictionary, data: GatherNodeData, inv: Inventory, tier: int, section_open: bool, flag_ok: bool) -> String
static func yield_for(data: GatherNodeData, tier: int) -> int
class_name GatherManager extends Node               # Systems/Gathering
func register(node_id: String, data: GatherNodeData) -> void
func state_of(node_id: String) -> Dictionary; func charges(node_id: String) -> int; func stage(node_id: String) -> StringName
func gather(node_id: String, inv: Inventory, tier: int) -> int   # nach der TimedAction; 0 = abgelehnt; resource_gathered, gather_node_changed; alder → stats.trees_felled
func refresh(day: int) -> void                        # day_started + post_load
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void; func post_load() -> void
class_name GatherNode extends Node3D                 # Entities/gather_<id>; Interactable; Modell nach stage
@export var node_id: String; @export var kind: StringName; @export var section_id: StringName = &""
# Holunder: GatherNode als Kind der bestehenden Holunderstrauch-Instanz, ohne eigenes Modell (Strauch unverändert)
# ClearableData ✦ + tool_kind, min_tier; ClearableObstacle: block_reason über ToolRules, Minuten über ActionConfig.tool_minutes
# SectionData ✦ + @export var is_burial: bool = true   # bruch/quarry: false → keine Plots, kein Ruf section_unlocked, nicht in Friedhofsübersicht/Ehrwürdig
```

**Werkzeuge & Inventar (P3)**
```gdscript
class_name ToolConfig extends Resource              # ✦ data/config/tool_config.tres
@export var kinds: Array[StringName] = [&"shovel", &"axe", &"pickaxe"]
@export var labels: Dictionary[StringName, String] = {&"shovel": "Schaufel", &"axe": "Axt", &"pickaxe": "Spitzhacke"}
@export var base_names: Dictionary[StringName, String] = {&"shovel": "Alte Schaufel", &"axe": "Altes Beil", &"pickaxe": ""}
@export var source_hint: Dictionary[StringName, String] = {&"shovel": "Esse", &"axe": "Esse", &"pickaxe": "Osric"}
# ActionConfig ✦ + @export var tool_tier_factors: PackedFloat32Array = [1.0, 0.8, 0.6]
#                 + @export var action_tools: Dictionary[StringName, StringName] = {&"dig": &"shovel", &"bury": &"shovel"}
#                 + @export var tool_minute_step: int = 5
#                 + func tool_minutes(base: int, tier: int) -> int     # max(step, round(base × f / step) × step)
class_name ToolRules extends RefCounted
static func tier(inv: Inventory, kind: StringName) -> int              # höchste ItemData.tool_tier am Gürtel, sonst 0
static func block_reason(inv: Inventory, kind: StringName, min_tier: int, cfg: ToolConfig) -> String   # „Holzfälleraxt nötig – Esse" · „Meisterhacke nötig"
static func tool_name(kind: StringName, tier: int, cfg: ToolConfig) -> String
# Inventory: @export var tool_belt: bool = false (Spieler true)
#   func tools() -> Dictionary[StringName, int]; TOOL-Items gehen an den Gürtel (max_stack je id, Rest zurück);
#   count/has/remove_item/can_add beziehen den Gürtel ein; get_slots unverändert ohne Gürtel; save_state + "tools"; load_state
#   legt TOOL-Items aus alten Slots an den Gürtel (tolerant); changed einmal je Aufruf wie bisher
# Player: func tool_tier(kind: StringName) -> int
# GravePlot / ClearableObstacle / GatherNode: Minuten = actions.tool_minutes(base, player.tool_tier(kind))
```

**Grabstein-Gestaltung (P4)**
```gdscript
class_name StoneShapeData extends Resource          # ✦ data/stone/shapes/<id>.tres
@export var id: StringName; @export var display_name: String; @export var order: int
@export var inputs: Dictionary[StringName, int] = {}; @export var minutes: int = 50
@export var model: PackedScene; @export var max_lines: int = 4
@export var label_width: float = 0.5                  # Meter; Label3D-Breite am Marker inscription
class_name InscriptionData extends Resource         # ✦ data/stone/inscriptions/<id>.tres
@export var id: StringName; @export var order: int; @export var title: String
@export var lines: PackedStringArray = []            # Platzhalter {name} {born} {died} {age}
@export var fits_causes: Array[StringName] = []; @export var fits_min_age: int = -1; @export var fits_max_age: int = -1
@export var fits_story: Array[StringName] = []
class_name OrnamentData extends Resource            # ✦ data/stone/ornaments/<id>.tres
@export var id: StringName; @export var order: int; @export var display_name: String; @export var tooltip: String
@export var points: int = 1; @export var minutes: int = 25; @export var model: PackedScene
class_name StoneConfig extends Resource             # ✦ data/config/stone_config.tres
@export var inscription_points: int = 1; @export var fitting_points: int = 1; @export var gilded_points: int = 1
@export var ink_item: StringName = &"ink"; @export var ink_amount: int = 1; @export var inscription_minutes: int = 20
@export var gold_item: StringName = &"gold_leaf"; @export var gilding_minutes: int = 10
@export var set_minutes: int = 20
@export var calendar: Dictionary = {"start_year": 1834, "start_month": 10, "start_day": 3,
		"month_names": ["Hartung", "Hornung", "Lenzing", "Ostermond", "Wonnemond", "Brachet", "Heuet", "Ernting", "Scheiding", "Gilbhart", "Nebelung", "Julmond"],
		"month_days": [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]}
@export var ink_color: Color = Color("2A1F18"); @export var gold_color: Color = Color("C9A24A")
class_name StoneDesign extends RefCounted            # ✦ Wertobjekt
var shape: StringName; var inscription: StringName = &""; var ornament: StringName = &""; var gilded: bool = false
var text: PackedStringArray = []                     # beim Hauen festgeschrieben
func to_dict() -> Dictionary; static func from_dict(d: Dictionary) -> StoneDesign; func is_empty() -> bool
class_name StoneCalendar extends RefCounted
static func date_text(day: int, cfg: StoneConfig) -> String         # „8. Nebelung 1834"
static func year_of(day: int, cfg: StoneConfig) -> int
class_name StoneDesignRules extends RefCounted
static func fits(ins: InscriptionData, corpse: CorpseRecord) -> bool
static func render_text(ins: InscriptionData, corpse: CorpseRecord, cfg: StoneConfig) -> PackedStringArray
static func marker_points(design: StoneDesign, corpse: CorpseRecord, economy: EconomyConfig, cfg: StoneConfig) -> int
static func breakdown_lines(design: StoneDesign, corpse: CorpseRecord, economy: EconomyConfig, cfg: StoneConfig) -> Array[Dictionary]
static func inputs(design: StoneDesign, cfg: StoneConfig) -> Dictionary; static func minutes(design: StoneDesign, cfg: StoneConfig) -> int
static func current_marker_points(grave: GraveRecord, corpse: CorpseRecord, economy: EconomyConfig, cfg: StoneConfig) -> int
class_name Stonemasonry extends Node                # Systems/Stonemasonry
func eligible_graves() -> Array[Dictionary]          # {grave_id, name, section, marker, quality, ready: bool}
func preview(grave_id: String, design: StoneDesign) -> Dictionary   # {quality_before, quality_after, lines, text, fits, minutes, inputs, missing, block_reason}
func order_block_reason(grave_id: String, design: StoneDesign, inv: Inventory) -> String
func carve(grave_id: String, design: StoneDesign, inv: Inventory) -> String   # nach der TimedAction; entnimmt atomar; order_id | "" ; stone_order_changed(&"ready"); stats.crafted
func ready_stones() -> Array[Dictionary]; func ready_for(grave_id: String) -> Dictionary
func discard(order_id: String) -> bool
func set_stone(grave_id: String, inv: Inventory) -> int   # von GravePlot nach 20 Min → Graveyard.set_designed_stone; Qualitätsdifferenz
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
# GraveRecord + var design: Dictionary = {}  (StoneDesign.to_dict; in to_dict/from_dict, tolerant)
# Graveyard + func set_designed_stone(grave_id: String, design: StoneDesign, inv: Inventory) -> int
#   FILLED → wie place_marker (Bezahlung) · MARKED → wie upgrade_marker (ohne Bezahlung, marker_upgrade, stone_master → master_stone)
#   grave_stone_set, grave_quality_changed/grave_completed wie bisher; stats.stones_set; Workshop.check_goal
# GraveQuality.breakdown(corpse, marker_id, config, design: Dictionary = {}) / compute(…, design = {})
# GravePlot: MARKED/FILLED + Stonemasonry.ready_for(grave_id) → Prompt „[E] Gestalteten Stein setzen (20 Min)" (Vorrang vor Inventar-Zeichen)
# GravePlotVisuals: Marker-Modell der Form; Zierde-Modell am Marker `ornament`; Label3D am Marker `inscription` (§8)
# GhostMood.main_reason: + &"nameless" nach &"cross"; GhostLines + nameless, by_design (Schlüssel: &"default", &"gilded", &"master", &"s5_lorenz")
```

**Handel, Speichern & Übertrag (P6)**
```gdscript
# PietyConfig ✦ + @export var full_prep_requires_unharvested: bool = true
# CorpseCare._after_prep: full_prep nur bei harvested.is_empty() (wenn Flag), stats.prepared immer
# PrepConfig ✦ + @export var balm_items: Array[StringName] = [&"juniper", &"herb_bundle"]  (balm_item bleibt = erstes Element, Kompatibilität)
# CorpsePrep.block_reason(&"balm"): irgendein balm_item vorhanden; CorpseCare.apply_balm verbraucht das erste vorhandene in Listenreihenfolge
# NightTrade.buy: + coins_spent(price, &"ilse"); TraderConfig.shop + gold_leaf {price 6, per_night 2}
# DialogueActions take_item:coin:<n> → + coins_spent(n, &"osric") (Sprecher aus context; Ilse &"ilse")
class_name SaveMigration  # CURRENT := 4; Kette 1→2→3→4; + static func migrate_3_to_4(state: Dictionary, meta: Dictionary) -> Dictionary
# SaveFileIO.FORMAT_VERSION = 4; read_doc akzeptiert 1…4
# GameState.DEFAULT_STATS + &"crafted", &"stones_set", &"coins_spent", &"trees_felled"
```

### 3.5 Database (Lead)
Neue Ordner → Schlüssel: `data/stations` (`id`), `data/gather` (`id`), `data/stone/shapes`, `data/stone/inscriptions`, `data/stone/ornaments` (`id`, sortiert nach `order`, dann id). Funktionen: `station(id)`, `stations()`, `gather_kind(id)`, `gather_kinds()`, `stone_shape(id)`, `stone_shapes()`, `inscription(id)`, `inscriptions()`, `ornament(id)`, `ornaments()`. Configs `workshop_config`, `tool_config`, `stone_config` über `config()`. Leere/fehlende Ordner = leere Listen.

### 3.6 Eingaben
Keine neuen Tasten. Panels über [E] an Stationen/Bauplätzen, Esc schließt. Im Stein-Panel: Mausklick; `[`/`]` blättern die Grabliste (bestehende Aktionen `journal_page_prev/next`).

---

## 4. Welt (W-Welt)

### 4.1 Werkhof an der Hütte (Benutzerentscheidung §14.2)
**Fest bleiben:** Hütte (−5,6 | −7,2; Ecken NW −8,66|−8,36 · NO −3,81|−9,94 · SO −2,54|−6,04 · SW −7,39|−4,46), Leichentisch (−1,6 | −5,4), Werkbank (−2,5 | −8,4), Pförtchen zum Holunderwinkel (−10,0 | −12,5), Waschschüssel, Kiste, Schaufel-Requisite, Steinhaufen `res_stone`, Ilses Zugangsstreifen, alle Pflegestellen, Spielerstart.
```
 z −12,5 ══Zaun Holunderwinkel══[Pförtchen x −10,6…−9,4]════════════╗ z −12 ═Zaun═[Durchgang Birkenhang x 2,5…6,5]═
         │ Gang   │ ESSE (−7,3|−11,1)    Meiler (−4,6|−11,4)         ║  STEINMETZBANK (−0,5|−10,6)  ┆ Route   │ plot_01
         │ x −11,2│ Zugang West                                      ║  Zugang Süd                  ┆ x 0,8…2,4│ (3,6|−8,2)
         │ …−8,6  │           ┌───────── HÜTTE ─────────┐            ║  Werkbank (−2,5|−8,4)        ┆
         │ Stein- │           │  (Dach, fest)           │            ║  HOLZHAUFEN neu (0,0|−7,8)   ┆
         │ haufen │  Kiste    └──── Tür (−5,67|−4,5) ───┘  Tisch (−1,6|−5,4) · Schüssel
  Ilse ▌ │ Route z −3,86…−2,2 (1,66 m) zwischen Hütten-SW-Ecke und Webstuhl ──→ Tür
         │ WEBSTUHL (−8,6|−1,3), Zugang Süd            Pfad → Tor
         │ dirt_y07 (−9,6|−2,6) bleibt · Eiche (−7,6|3,2) bleibt
```
**Plätze** (Maße §2.1): Die Steinmetzbank steht nordöstlich neben der Werkbank, östlich der Hütte, und ist von der Kamera aus frei sichtbar. Die Esse steht nördlich der Hütte am Holunderwinkel-Zaun (0,1 m vor der Zaunkante, 0,27 m vor dem Hüttenrand). Ihr Zugang liegt im bestehenden Gang zum Pförtchen: Der Spieler steht an der Esse **westlich** der Hütte und bleibt sichtbar. Kamin, Rauch und Glut ragen über das Dach. Der Meiler steht hinter der Hütte; sichtbar ist nur sein Rauch, die Interaktion („Holzkohle holen") läuft an der Esse. Der Webstuhl steht südwestlich vor der Hütte, links der Tür, mit Blick zur Kamera.

**Versetzte bzw. geänderte Elemente (vollständig – alles andere im Alten Hof bleibt bitgleich):**
| # | Element (Layout-id) | vorher | nachher | Δ | Grund |
|---|---|---|---|---|---|
| V1 | Holzhaufen `res_wood` (Entity `resource_node`, `ph_prop_wood_pile`, rot 100° bleibt) | (−1,2 | −9,4) | **(0,0 | −7,8)** | 2,0 m | Er lag im Zugang (Süd) der Steinmetzbank. Neu: 0,4 m östlich des Werkbank-Zugangs, 1,7 m Abstand zum Grabring von `plot_01`, 1,9 m nördlich des Leichentischs |
| V2 | Zier-Zellen der Bau-Maske unter den 3 Footprints + `station_margin 0,6` + Zugang 1,0 m + Meiler (`workyard.blocked_rects`) | Abschnitt `yard` (Zier erlaubt) | gesperrt (Stationen) bzw. ROUTE (Zugänge) | – | Stationen brauchen feste Fläche. Dort schon platzierte Zier wird beim Laden geräumt (§5.2) |
| V3 | Gras unter Footprints und Zugängen | gebacken | entfernt (`keep_out_station`), `grass.scn` neu gebacken | – | wie bei allen Stationen |
| – | Pflegestellen | – | **keine versetzt** (`dirt_y07` bleibt 0,4 m hinter dem Webstuhl in der Route, `dirt_y08` bleibt in der Route östlich der Steinmetzbank) | – | Pflegestellen dürfen auf Routen liegen (Phase 3) |
W-Welt darf die drei Bauplätze um höchstens ±0,3 m schieben, wenn die Routen-Prüfung das verlangt, und meldet es. Weitere Versetzungen braucht es nicht, sonst fragt W-Welt beim Lead nach.

**Routen (Bau-Maske ROUTE, Breite ≥ 1,5 m, von W-Welt per Flood-Fill geprüft):**
- Hüttentür → Pförtchen: zwischen Hütten-SW-Ecke (Rand 0,6 m) und Webstuhl-Rückseite z −3,86…−2,2 (1,66 m), dann der Gang x −11,2…−8,6 nach Norden (am Steinhaufen so schmal wie in Phase 4, unverändert); vor dem Pförtchen bleiben 1,2 m frei, die Esse beginnt bei x −8,6. Alternativ westlich um den Webstuhl über Ilses Streifen: x −11,2…−9,7 (1,5 m).
- Hüttentür → Birkenhang-Durchgang (Hecke x 2,5…6,5, z −12): östlich der Steinmetzbank x 0,8…2,38 (Grabring `plot_01`) = 1,58 m.
- Hüttentür → Tor / Ostwiese / Ostpforte: unverändert (Erdweg, Leichentisch, Gräber).
- Der Streifen hinter der Hütte (zwischen Esse, Meiler und Steinmetzbank) ist **keine** Route. Hütte und Zaun lassen dort ≤ 2,6 m, und das Dach verdeckt ihn. Von der Esse zur Steinmetzbank geht man südlich um die Hütte (≈ 18 m, ≈ 6 s).

**Licht & Rauch (Budget §9):** Esse-Glut: 1 OmniLight `#E07A3A`, Energie 0,5, Reichweite 3,5 m, **ohne Schatten**, leichtes Flackern, nur wenn gebaut, Gruppe `warm_lights`. Sie zählt nicht zu den ≤ 4 Schattenlichtern; die Hüttenlaterne (Südseite, mit Schatten) bleibt unverändert. Die Glut reicht nicht in den Holunderwinkel (Abstand zu `h_04` ≈ 3,8 m) und leuchtet nicht in den Innenraum (Innenraum ist eine eigene Szene fern der Außenwelt). Rauch: Esse-Kamin 3 + Meiler 3 Partikel (`CPUParticles3D`, Wacholderrauch-Textur warmgrau getönt, `visibility_range_end 40 m`), zusammen mit den Verfallseffekten ≤ 60.

**Vorher/Nachher (G5):** W-Welt rendert den Alten Hof aus derselben Kamera: vorher mit Build `69f8d49` (eigener Worktree, nur lesen), nachher mit leeren Bauplätzen und nachher mit gebautem Werkhof → `p5_00a/b/c` (§11).

### 4.2 Am Bruch (Rohstoffgebiet östlich der Ostwiese)
```
            z −12 ┌──────── Bruchkante (Felswand ph_env_quarry_face, 9 m) ────────┐
                  │  Erzader        Werkstein 1        Werkstein 2   Bruchstein   │  Steinbruch `quarry`
                  │  (24,6|−9,6)    (26,8|−9,4)        (29,2|−9,6)   (30,4|−8,0)   │
            z −6,5│   Findling 1 ·· Findling 2 ·· Findling 3  (24,2 / 26,8 / 29,4) │  ← gesperrt bis gebrochen
                  │ (leere, eingewachsene Steinplatte 24,0|−2,8 – Kulisse)          │
 Ostwiese  x 21,5 ▌ Ostpforte (21,5|0,0)                                           │  Arbeitsbereich `bruch`
  (Zaun bleibt)   │                       Flachsbeete (26,4 / 28,2 / 30,0 | 1,8)   │
                  │ Kräuter (23,0|8,2)     Lehmkuhle (28,6|6,6)    Kräuter (30,6|8,4)│
            z 9,6 └────────────── Hecke / Bruchkante Süd ──────────────────────────┘
                  x 21,5                                                       x 31,5
```
- Abschnitt **`bruch`** (Rechteck x 21,5…31,5, z −6,5…9,6; `is_burial false`, `counts_for_cemetery false`, `decor_cap 0`, `requires_flag bruch_license`, Text „Die Pforte ist zu. Osric weiß, wer den Schlüssel hat."): Hindernis `obs_b_gate` (Kind `gate_east`, „Ostpforte / aufschließen", 10 Min, Modell `ph_prop_gate_small`/`_open` auf 1,6 m Breite skaliert).
- Abschnitt **`quarry`** (x 21,5…31,5, z −12…−6,5; `requires_section bruch`, sonst wie `bruch`): Hindernisse `obs_q_boulder_1…3` (Kind `boulder`, „Findling / brechen", 60 Min Basis, Spitzhacke ≥ 1, Ertrag 3 stone). Die Sammelstellen im Steinbruch sind bis zur Freigabe **logisch** gesperrt (Prompt „Findlinge versperren den Weg."). Die Findlinge liegen sichtbar davor; eine lückenlose Kollisionssperre ist nicht nötig.
- **Ostpforte:** Das Zaunstück [[21,5, 3,0], [21,5, −3,0]] der Ostwiese wird zu [[21,5, 3,0], [21,5, 0,8]] + Pforte (1,6 m) + [[21,5, −0,8], [21,5, −3,0]]. Das ist der einzige Eingriff an der Ostwiese. Die Pflegestelle `dirt_e02` (20,0 | −1,2) bleibt; der Zugang vor der Pforte (1,0 m) wird ROUTE in der Bau-Maske.
- Rand: Nord- und Ostkante als Felsabbruch (`ph_env_quarry_face`, `ph_env_quarry_edge`), Südkante als Hecke (`ph_env_hedge_thorn`, bestehendes Asset). Unsichtbare Wand x 31,2.
- Bestehende Hintergrundbäume im Bereich werden versetzt: (24,5 | 2,0) → (34,5 | 3,0) · (25,5 | −6,0) → (35,0 | −7,0); (23,5 | −13,5) bleibt (hinter der Felswand).
- **Keine Stationen am Bruch.** Er ist reines Rohstoffgebiet (Steinbruch, Findlinge, Erz, Werkstein, Bruchstein, Lehmkuhle, Flachs, Kräuter). Osric nennt ihn Lorenz' alten Werkplatz (§2.6); im Gelände erinnert daran nur eine eingewachsene, leere Steinplatte bei (24,0 | −2,8) ohne Funktion (Requisite `ph_prop_build_site` ohne Pflöcke).
- Teleport `tp_bruch` (25,5 | 0,0), `tp_quarry` (27,0 | −8,0).

### 4.3 Schlag am Kutschweg
- 5 Schlag-Erlen `gather_alder_1…5` zwischen den bestehenden Waldbäumen westlich des Kutschwegs (innerhalb der begehbaren Fläche): (−6,2 | 16,4), (−10,4 | 15,8), (−7,6 | 20,4), (−10,6 | 21,2), (−5,4 | 24,2). Die bestehenden Bäume und Büsche bleiben (W-Welt darf die Erlen um ±0,6 m schieben und meldet es).
- Kräuter `gather_herbs_3/4` am Wegrain (−2,8 | 18,0), (−2,6 | 23,6).
- Teleport `tp_schlag` (−6,0 | 19,0).

### 4.4 Holunder
Die drei Holundersträucher (`elder_bushes`) bekommen je ein Interactable (`GatherNode` ohne Modell, Kind `elder_bush`). Das Modell bleibt unverändert. Ist ein Strauch von innen nicht erreichbar (der Strauch über dem Pförtchen steht außen), entfällt dort die Sammelstelle; W-Welt meldet die Zahl.

### 4.5 Boden, Grenzen, Schema
- `ground.size` **[64,0, 64,0]**, `ground.center` **[8,0, 2,5]** → x −24…40. Süd-, West- und Nordkante unverändert; `ph_env_ground_graveyard` wird neu exportiert (Glättung unter den Werkhof-Bauplätzen und den Beeten, Steinboden-Tönung im Steinbruch nur über Vertex-Farbe im bestehenden Material).
- `walkable_bounds.max` [21,2, 25,2] → **[31,2, 25,2]**. Neue `extra_walls`: Ostwiesen-Ostzaun bleibt Kollision (Zaun), dazu [[21,5, 9,6], [31,2, 9,6]] (Hecke Süd) und die Felskanten.
- `camera_bounds.max` [17,0, 23,0] → **[27,0, 23,0]**.
- Gras: Im `bruch` Dichte × 0,5 (`grass.bruch_density_scale`), im `quarry` keins (Steinboden), `keep_out` um Beete und Lehmkuhle; im Werkhof um die Stationen (V3).
- Die Bau-Maske (Zier) bleibt auf x −11,5…21,5 und wird mit den Werkhof-Sperren (V2) neu gebacken. Der Bruch liegt außerhalb, also keine Zier dort (gewollt).
- **Layout-Schema:** `sections[]` + `bruch`, `quarry` · `clearables[]` + `obs_b_gate`, `obs_q_boulder_1…3` · `workyard {build_sites[] {id, station, pos, rot_y, footprint, access}, meiler {pos, radius}, blocked_rects[]}` · `stations[]` (Entities `type: workbench`, params `station`, `requires_built: true`) · `gather_nodes[] {id, kind, pos, rot_y, section?}` · `elder_bushes[].gather` · `quarry_edges[]` · `entities[res_wood].pos` (V1) · `waypoints` + `tp_bruch`, `tp_quarry`, `tp_schlag`, `tp_workyard` (−4,4 | −3,6) · `fence.segments` (Ostpforte) · `lights` + `ph_bld_forge/light_ember`. Neue Systemknoten §3.1 legt `graveyard_build_phase5.gd` an.

---

## 5. Speichern & Migration (P6)

### 5.1 Format v4 (Ergänzungen)
```
format_version: 4
data.autoloads.GameState.stats   + crafted, stones_set, coins_spent, trees_felled
data.autoloads.GameState.flags   + workshop_open, bruch_license, bought_pickaxe, p5_intro, names_in_stone_complete, remark_gold
data.nodes.player (Inventory)    + "tools": {"rake": 1, "shears": 1, "pickaxe_iron": 1, …}   (Gürtel; Slots ohne TOOL-Items)
data.nodes.graveyard.graves[]    + design: {} | {"shape": "stone_master", "inscription": "i_garden", "ornament": "orn_elder", "gilded": true, "text": ["Marthe Quendel", "* 1771 – † 8. Nebelung 1834", "Was du gesät hast, blüht noch."]}
data.nodes.workshop              {"built": ["mason", "loom"], "jobs": {"forge": {"recipe": "charcoal", "end_total": 38400}}, "goal_done": false, "evict_pending": {}}
data.nodes.gathering             {"gather_alder_1": {"charges": 0, "last_taken_day": 23, "last_refresh_day": 24}, …}
data.nodes.stonemasonry          {"next_id": 4, "ready": [{"id": "stone_0003", "grave_id": "h_01", "design": {…}}], "heard_design": ["plot_04"]}
data.nodes.expansion             + Abschnitte bruch, quarry (fehlen → LOCKED)
```
Nicht gespeichert: Werkzeugstufen (aus dem Gürtel abgeleitet), Kapitel-Fortschritt (abgeleitet), Vorschau, Modellstufen der Sammelstellen (aus dem Zustand).

### 5.2 Migration v3 → v4 (Phase-4-Spielstände müssen laden)
`SaveMigration.migrate_3_to_4` läuft in `read_doc` nach `decode_state` (Kette 1→2→3→4), rein, auf einer tiefen Kopie.
1. **Spieler-Inventar:** alle Slot-Einträge mit einem Item der Kategorie `TOOL` → `tools` (Menge 1 je id); die Slots werden leer, andere Slots behalten ihren Index. Truhe unverändert (kein Gürtel). Unbekannte ids bleiben, wo sie sind (Inventory warnt wie bisher). Die Slot-Zahl wächst beim Laden auf 20 (neue Slots leer).
2. **Gräber:** `design = {}`; `marker_id`, `quality`, `breakdown` unverändert.
3. `nodes.workshop = {}`, `nodes.gathering = {}`, `nodes.stonemasonry = {}` → nichts gebaut, alle Sammelstellen voll beim nächsten `refresh` (post_load), keine fertigen Steine.
4. `nodes.expansion`: `bruch`/`quarry` fehlen → LOCKED (ExpansionManager tolerant).
5. **Zier im Werkhof** (zur Laufzeit, nicht in der reinen Migration): `Workshop.post_load` ruft einmalig `DecorationManager.evict_rects(workyard_rects)`. Zier-Stücke, deren Zellen ein Werkhof-Rechteck schneiden, werden abgebaut. Die Items gehen in die Truhe `hut_chest`, ein Überlauf ins Spieler-Inventar. Was auch dort nicht passt, bleibt als offene Rückgabe im Zustand von `Workshop` und wird ausgegeben, sobald Platz ist. Einmalige Notiz: „Deine Zier stand auf dem neuen Werkhof. Sie liegt jetzt in der Truhe.“ Flag `workyard_cleared`. Nichts geht verloren.
6. Stats `crafted`, `stones_set`, `coins_spent`, `trees_felled` = 0. Flags: keine. `workshop_open` setzt `Workshop.post_load` zur Laufzeit, wenn `cemetery_complete` gilt.
7. Pietät, Gräber, Leichen, Merkbuch, Ilse: unverändert (der Pietät-Fix wirkt nur künftig). Der Holzhaufen (V1) speichert keine Position (nur `remaining`) und steht nach dem Laden am neuen Platz.

**Fixtures (W0, Lead, vor jeder Code-Änderung mit Build `69f8d49` erzeugt, über `Phase4Bot` + echte Systeme):** `tests/fixtures/saves_v3/`
- `slot_p4_day7_table.json`: `mixed`, Tag 7, 10:00, Leiche auf dem Tisch mit 2 von 4 Schritten, laufendes Räucherfenster, Zopf genommen; Wurzelbürste, Kamm, Rechen, Schere, Zange **in Slots** (Gürtel-Migration).
- `slot_p4_day13_complete.json`: `reverent`, Tag 13, 09:00, `cemetery_complete` frisch gesetzt, Holunderwinkel offen, Lieferungen laufen (Phase-5-Freischaltung mitten in Phase 4).
- `slot_p4_day20_reverent.json`: `reverent`, Tag 20, 07:00, Kapitel `six_pits`, 18 Gräber, **121 Münzen**, Ruf 100 (Start `reverent5`/`toolsmith`).
- `slot_p4_day20_mixed.json`: `mixed` (alte Strategie), Tag 20, 07:00, Kapitel erreicht, beraubte Gräber mit unruhigen Geistern (Start `mender`).
- `slot_p4_day25_harvester.json`: `harvester`, Tag 25, 07:00, Kapitel erreicht, ≈ 179 Münzen (Start `harvester5`).
- `slot_p4_interior_chest_tools.json`: Tag 9, 20:00, Spieler in der Hütte, Rechen und Kamm **in der Truhe**, Zange im Inventar; dazu **Zier im späteren Werkhof** (Holzbank vor der Hütte bei (−8,6 | −1,3), Grabvase bei (−0,5 | −10,6)) für die Räum-Regel.
Dazu `make_v3_saves.gd` + `_driver.gd` (historisches Werkzeug, wie Phase 4). Lade-Wächter: `tests/integration/test_saves_v3_load.gd` (Lead). v2- und v1-Fixtures laden weiterhin (Kette bis 4).

---

## 6. Debug-Konsole (W-UI) – neue Befehle
`workshop open` · `license` · `build <mason|loom|forge|all>` · `tool <shovel|axe|pickaxe> <0-2>` · `gather refill` · `gather empty <node_id|all>` · `regrow <tage>` (Nachwachsen simulieren, gleiche Regel wie `day_started`) · `job done` (Meiler fertig) · `stone <grave_id> <shape> [inscription|-] [ornament|-] [gold]` (sofort gesetzt, gleiche Regeln außer Material/Zeit) · `stones showcase` (Screenshot p5_14: je Form und Zierde ein Stein) · `calendar <tag>` (zeigt das Inschrift-Datum) · `coins <n>` (bestehend) · `tp <bruch|quarry|schlag>` · `goal` (Kapitel-Fortschritt).

## 7. UI (W-UI)
- **Werkstatt-Panel (verallgemeinert, bestehendes `crafting`):** Titel aus `StationData.display_name` („Esse", „Webstuhl", „Werkbank"). Gruppen nach `category` (Werkstoffe · Werkzeug · Grab · Zier). Werkzeug-Rezepte zeigen „ersetzt: Eisenschaufel" und die Wirkung „Graben 50 → 35 Min". Der Meiler zeigt „läuft allein · 8 Std." bzw. den Auftrag „fertig um 06:10" / „fertig – holen". Eine Station, ein Panel. Station-Reiter gibt es nicht, weil man immer an genau einer Station steht.
- **Bauplatz-Panel** `&"build_site"` (Kontext `{station, site, inventory}`): Bild der Station (Icon-Renderer), Beschreibung, Kostenliste mit vorhanden/fehlt (Münzen als eigene Zeile „Meißelsatz aus Hollerbrück · 15 Münzen"), Dauer, „Bauen".
- **Stein-Panel** `&"stone_design"` (Kontext `{inventory, player, bench}`), Pergament wie das Merkbuch, drei Spalten:
  - *links* **Gräber:** Liste (Name, Abschnitt, jetziges Zeichen, Qualität), Filter „ohne Namen zuerst". Gedimmt mit Grund, wenn kein besserer Stein möglich ist.
  - *Mitte* **Gestaltung:** *Form* (3 Karten mit Punkten, Material, Minuten) · *Inschrift* (7 Zeilen mit dem echten Text des gewählten Toten, Abzeichen „passt" + Grund, Schalter „vergoldet" mit Blattgold-Anzahl) · *Zierde* („ohne" + 4 Karten mit Tooltip).
  - *rechts* **Vorschau** (`StonePreview`: eigene `SubViewport` + `World3D`, das echte Formmodell mit Zierde und Label3D, feste warme Seitenlicht-Stimmung, neu gerendert nur bei Änderung), darunter „Grab 13 → 19", Aufschlüsselungs-Zeilen, Material vorhanden/fehlt, Minuten, Knopf „Stein hauen (205 Min)". Kopfzeile: „Ablage: 2/3 fertig".
  - Unten „Fertige Steine": Name, Form, „bereit" / „passt nicht mehr – Verwerfen" (zweistufig wie Verwerten).
- **Inventar:** 20 Slots (5 × 4). Neue Leiste **Werkzeuggürtel** über den Slots: Schaufel/Axt/Spitzhacke mit Stufen-Namen (Stufe 0 als „Alte Schaufel", blass), daneben Rechen, Bürste, Kamm, Schere, Zange. Tooltip mit Wirkung.
- **HUD:** unverändert (MATERIAL erscheint nicht in der Ressourcenleiste). Kleine Kapitelanzeige im Friedhofs-Tooltip: „Werkhof 2/3 · Werkzeug 2/3 · Meisterstein 0/1".
- **Grab-Prompt:** „Grab von Marthe Quendel – Qualität 18/19"; im Grabregister eine Spalte „Inschrift" (erste Zeile + Spruch); Totenzettel im Merkbuch zeigt den Steintext; Seite *Ich* + „Steine gesetzt: 6".
- **Belohnungskarte / Neu-gesetzt-Karte:** Aufschlüsselung mit den Stein-Zeilen, „Grabqualität +6".
- **Tageszusammenfassung:** + „Ausgaben" (nach Zweck aus `coins_spent`), „Gesammelt" (Summen je Item), „Gebaut".
- **Zielzeile** (`ObjectiveResolver`, nach Leichen-Kette und Phase-4-Zielen): „Sprich mit Osric über den Bruch" (open ∧ ohne Brief) · „Ostpforte aufschließen" · „Bauplatz: <Station> bauen" (nächste bezahlbare zuerst) · „Findlinge brechen – Spitzhacke nötig" · „Holzkohle ist fertig" · „Ein Stein liegt bereit – setz ihn bei <Name>" · „Setz den Meisterstein" · danach „Gräber ohne Namen: n".
- **Abschluss-Panel** Variante `&"names_in_stone"` (§1.5).

## 8. Assets (P5, Stil gesperrt, alle `ph_`, `lib_painted.py` / geteilte Materialien)
| Asset | Zweck | Dreiecke | Hinweise |
|---|---|---|---|
| `ph_bld_mason_bench` | Steinmetzbank: schwerer Holzbock, Steinblock, Klüpfel, Meißel, Ablagegestell | ≤ 3 500 | Marker `stone_slot_1…3` (fertige Steine lehnen dort), `use` |
| `ph_bld_loom` | kleiner Trittwebstuhl unter Pultdach, halb gewebtes Tuch | ≤ 4 000 | Leinen ungebleicht warm, Holz dunkel |
| `ph_bld_forge` | gemauerte Esse mit Kamin, Amboss auf Stumpf, Löschtrog, Blasebalg | ≤ 4 500 | Marker `light_ember`, `smoke`; Glut `#E07A3A` nur als Vertex-Farbe + Licht |
| `ph_prop_charcoal_kiln` / `_kiln_burning` | Meiler kalt / rauchend (Rauch = bestehende Wacholder-Rauchtextur, anders getönt) | ≤ 900 | Marker `smoke` |
| `ph_prop_build_site` | Pflöcke, Schnur, Tafel, eingewachsene Steinplatte | ≤ 600 | skaliert auf den Footprint (nur X/Z) |
| `ph_env_alder_coppice`, `_alder_stump`, `_alder_sapling` | Schlag-Erle: Baum / Stock / Stockausschlag | ≤ 4 500 / 400 / 900 | Laub-Shader; Stock mit frischer, heller Schnittfläche |
| `ph_env_flax_bed`, `_flax_bed_empty` | Flachsbeet reif (gelbbraun, Samenkapseln) / gerauft (Erde, kleine Triebe) | ≤ 1 500 / 400 | **kein** kaltes Blau (Blüte ist vorbei) |
| `ph_env_clay_pit` | Lehmkuhle mit Wasserlache, Spaten-Stichkanten | ≤ 1 200 | Lache matt, kein Spiegel |
| `ph_env_quarry_face`, `_quarry_edge` | Felswand 9 m / Kantenstück | ≤ 6 000 / 1 500 | Stein `#8A8F94`-Familie, gemalte Schichtung |
| `ph_env_ore_vein`, `_ore_vein_empty` | Erzader: rostbraune Adern / abgebaut | ≤ 700 | Rostbraun im Erdton-Bereich |
| `ph_env_workstone_ledge`, `_ledge_empty` | Werksteinbank mit Keillöchern / leer | ≤ 900 | – |
| `ph_env_rubble_face` | Bruchsteinwand mit Haufen | ≤ 900 | – |
| `ph_env_boulder`, `_boulder_broken` | Findling ~2 × 1,6 m (moosig) / Trümmer | ≤ 1 200 / 600 | Footprint 2 × 2 |
| `ph_env_herb_patch`, `_herb_patch_cut` | Rainfarn (gelbe Knöpfe) + Beifuß / geschnitten | ≤ 800 / 300 | Laub-Shader |
| `ph_prop_gravestone_stele`, `_arch`, `_master` | Steinformen | ≤ 600 / 800 / 1 600 | Marker `inscription` (Mitte der Schriftfläche, lokal +Z-Normale), `ornament`; Meisterstein mit Sockel, Giebel, 2 sichtbaren Eisenklammern |
| `ph_prop_orn_ivy`, `_orn_poppy`, `_orn_elder`, `_orn_torch` | Relief-Zierden (flach, 0,02 m) | ≤ 400 | gleiches Steinmaterial, nur Form |
| `ph_item_shovel_iron`, `_shovel_master`, `_axe_iron`, `_axe_master`, `_pickaxe_iron`, `_pickaxe_master` | Werkzeug-Icons | ≤ 800 | Meister-Stufe: gebläute Klinge, Messingring am Stiel (warm) |
| `ph_item_flax`, `_yarn`, `_clay`, `_iron_ore`, `_iron_bar`, `_charcoal`, `_workstone`, `_elderberries`, `_herbs`, `_ink`, `_herb_bundle`, `_gold_leaf`, `_steel_rod` | Item-Icons | ≤ 800 | Holunderbeeren tintenviolett (wie Phase 4) |
- **Inschrift:** `Label3D` am Marker `inscription` (Präzedenz: Wegweiser „Hollerbrück"): `shaded = true` (nimmt Licht wie Stein), `double_sided = false`, `alpha_cut = ALPHA_CUT_DISCARD`, `modulate` = `StoneConfig.ink_color` bzw. `gold_color`, `outline_size 0`, `surface_offset 0,012`, `autowrap` auf `label_width`, `visibility_range_end 40 m`. Schrift: die Platzhalter-Schrift (offener Punkt „Schriftwahl"). Kein Decal: Decals ignorieren das Pinselrauschen des Maler-Shaders und kosten pro Pixel. Ein schattiertes Label3D wirkt wie eingelegte Farbe und ist bereits erprobt.
- **Zierde:** eigenes Relief-Mesh am Marker `ornament` mit dem geteilten Steinmaterial. Kein Textur-Aufkleber.
- Fertige Steine an der Bank: dieselben Modelle mit Zierde und Label am Marker `stone_slot_n`, gleiche Regeln.

## 9. Performance-Budget (Phase 5, Messung mit `graveyard_shots_phase5.gd`)
| Größe | Budget | Begründung |
|---|---|---|
| FPS | 60 @ 1080p Mittelklasse-GPU | unverändert |
| Draw Calls | < 1 000 (erwartet ≤ 560) | Bruch ≈ +45 (Felswand, 12 Stellen, Findlinge), Werkhof ≈ +15 (3 Stationen, Meiler, Bauplätze), Schlag ≈ +20, Inschriften ≤ 18 Label3D, Zierden ≤ 18 |
| Kamera-Dreiecke inkl. Gras (Spiel-Zoom) | < 500 k | Bruch ≈ +45 k (halbe Grasdichte, Steinbruch ohne Gras), Schlag ≈ +25 k |
| Lichter | ≤ 4 Omni mit Schatten (unverändert), ≤ 25 sichtbar | + Esse-Glut am Werkhof (ohne Schatten, 3,5 m). Messung `perf_p5_02`: Werkhof nachts mit Hüttenlaterne, Grablaternen und Esse; Zahl der Schattenlichter wie in Phase 4 |
| Partikel | ≤ 60 (unverändert) | Meiler-Rauch 3, Esse-Rauch 3 (`visibility_range_end 40 m`); der Werkhof liegt neben dem Leichentisch, also gemeinsam mit ≤ 3 Leichen-Effekten gemessen |
| Skripte CPU/Frame (headless) | Phase-5-Anteil ≤ +0,2 ms gegenüber dem Phase-4-Build auf derselben Inszenierung | Sammelstellen ohne `_process` (nur `day_started` / Interaktion), Label3D statisch, Vorschau-Viewport nur bei offenem Panel (`UPDATE_ONCE` bei Änderung). Absolutes Ziel 1,5 ms nur auf dem Benutzer-PC messbar (G4-Befund) |
| Spielstand | < 300 kB, Laden < 1 s | + Sammelstellen ≈ 2 kB, + ≈ 0,4 kB je gestaltetem Grab |
| Stein-Panel öffnen | < 150 ms bei 18 Gräbern | Vorschau lazy |

## 10. Tests
Regeln wie Phase 3/4 (Fixtures statt fremder Moduldaten, Fehler-Logger, Watchdog). **Alle 1 473 bestehenden Tests bleiben grün**; Anpassungen nur durch den Besitzer (z. B. `quality_max 19`, Slots 20, Werkzeuge am Gürtel, „/13"-Texte).

**Unit**
| Datei | Besitzer | Prüft |
|---|---|---|
| `test_workshop.gd` | P1 | Werkhof-Räumung (`evict_rects`: Zier im Rechteck → Truhe, Überlauf → Inventar, Rest offen bis Platz ist, einmalig, kein Verlust), Bau atomar (Items + Münzen; fehlt eins → nichts verbraucht), Sperrgründe, `station_built`/`coins_spent`, Station erst nach Bau sichtbar/benutzbar, Meiler (Start, Ende aus Minuten, laden mitten im Brand, einsammeln bei vollem Inventar), Freischaltung `workshop_open` (Morgen/Laden, idempotent), Kapitel genau einmal, Save/Load |
| `test_crafting.gd` (+) | P1 | Werkzeug als Ein- und Ausgabe (Gürtel), `tool_tier_changed`, neue Rezepte laden, Zählung Rezepte je Station |
| `test_gathering.gd` | P2 | Ladungen, Ertrag, Bonus Stufe 2, Nachwachsen je `regrow_days` (Tagessprung, Mehrtagessprung, laden), Erlen-Stufen (Stumpf/Schössling/Baum), Werkzeug-/Abschnitts-/Flag-Sperren, voll → abgelehnt, Holunder ohne Modellwechsel, Save/Load |
| `test_expansion.gd` (+) | P2 | Arbeitsabschnitte ohne Plots und ohne Ruf, `requires_flag bruch_license`, `requires_section`, Findling nur mit Spitzhacke, Minuten nach Stufe |
| `test_inventory.gd` (+) / `test_tools.gd` / `test_player.gd` (+) | P3 | Gürtel: TOOL außerhalb der Slots, `count/has/remove` inkl. Gürtel, Truhe ohne Gürtel, 20 Slots, Laden alter Slots → Gürtel; `tool_minutes` Tabelle §2.3 exakt; `ToolRules.tier/block_reason`; Graben/Bestatten mit Stufen |
| `test_stone_design.gd` | P4 | `render_text` aller 7 Vorlagen (Kalender: Tag 1 = 3. Gilbhart 1834, Monats-/Jahreswechsel, `* Jahr`), Umbruch > 22 Zeichen, `fits` je Ursache/Alter/Geschichte, Punkte/Minuten/Material, Maximum 9 |
| `test_stonemasonry.gd` | P4 | wählbare Gräber, „schon besser"-Sperre, Ablage 3, ein Stein je Grab, Hauen atomar, Setzen FILLED (Bezahlung) vs. MARKED (keine), Meisterstein-Ruf einmal, Verwerfen, „passt nicht mehr", festgeschriebener Text nach Umbenennung S5, Save/Load |
| `test_grave_quality.gd` (+) / `test_graveyard.gd` (+) | P4 | Stein-Zeilen, `quality_max 19`, alte Gräber unverändert, `upgrade_options` bietet nie gestaltete Formen, `grave_stone_set` |
| `test_ghosts.gd` (+) | P4 | Grund `nameless` in Priorität, `by_design` einmal je Grab, S5-Zeile, Zahlenbeispiele §2.5 (4 → 10, 2 bleibt unruhig) |
| `test_corpse_prep.gd` (+) / `test_piety.gd` (+) | P6 | **Pietät-Fix:** Haar genommen → waschen, Totenhemd, aufbahren → **kein** `full_prep`, `stats.prepared` +1, Qualitätszeilen unverändert; unverwertet weiter +3; Flag aus → altes Verhalten; `herb_bundle` räuchert wie Wacholder |
| `test_save_migration.gd` (+) / `test_save.gd` (+) / `test_dialogue.gd` (+) / `test_night_trade.gd` (+) | P6 | **6 v3-, 4 v2-, 3 v1-Fixtures laden ohne Fehler/Warnungen**; Gürtel-Migration (Slots → Gürtel, Truhe bleibt); `design {}`; neue Knoten leer; v4-Roundtrip identisch; Version 5 → abgelehnt; Osric `p5_intro`, Brief/Spitzhacke einmalig, Stahlstab, `coins_spent`; Ilse Blattgold (Preis, 2/Nacht) |
| `test_assets_phase5.gd` | P5 | Modelle vorhanden, Budgets §8, Marker (`stone_slot_*`, `inscription`, `ornament`, `light_ember`, `smoke`), geteilte Materialien, Icons |
| `test_ui_phase5.gd` | W-UI | Werkstatt-Panel (Titel, Gruppen, Werkzeug-Wirkung, Meiler-Status), Bauplatz-Panel (fehlt/vorhanden), Stein-Panel (Grabliste + Gründe, Text mit Namen, „passt", Vergolden nur mit Inschrift, Vorschau-Zahlen = `Stonemasonry.preview`), Gürtel-Leiste, Zielzeilen, Tageszusammenfassung „Ausgaben", Debug-Befehle |

**Integration**
- `test_phase5_loop.gd` (W-Welt): v3-Fixture `slot_p4_day20_reverent` laden → `workshop_open` → Osric: Brief → Ostpforte → Lehm, Flachs → Steinmetzbank bauen → Stele mit Inschrift für ein Grab hauen und setzen (Qualität steigt, keine Bezahlung) → Spitzhacke kaufen → Webstuhl, Esse am Werkhof (Wege Hütte ↔ Bruch mit echter Bewegung, nicht per Teleport) → Meiler über Nacht → Findlinge → Erz → Barren → Beschläge → Holzfälleraxt → Erle fällen (Stumpf, nach 5 Tagen Baum) → Stahlstab → Meisterhacke → Werkstein → Meisterstein vergoldet mit Zierde → Kapitel. **Roundtrip** `collect_state()` identisch nach `save_game`/`load_game` an 4 Momenten: Meiler brennt, zwei fertige Steine in der Ablage, Erle im Schössling-Stadium, nach dem Kapitel.
- `test_phase4_save_upgrade.gd` (P6): `slot_p4_day13_complete` laden → Lieferungen laufen weiter → `workshop_open` am Morgen → Webstuhl-Totenhemd für die nächste Leiche → gestalteter Stein direkt auf ein `FILLED`-Grab (mit Bezahlung).
- `test_graveyard_world.gd` (+): **Werkhof:** Bauplätze + Stationen deckungsgleich an den Positionen §2.1; `res_wood` bei (0,0 | −7,8); **Layout-Diff** gegen `tests/fixtures/phase5/layout_p4.json` (Kopie aus `69f8d49`, W0): in den Abschnitten I–IV ändern sich nur `res_wood` und die Ostpforten-Zaunstücke, dazu kommen die neuen Einträge; Hütte, Tisch, Werkbank, Pförtchen und Pflegestellen sind identisch. Routen-Flood-Fill (Kapselbreite 1,5 m): Hüttentür ↔ Pförtchen, ↔ Birkenhang-Durchgang, ↔ Tor, ↔ Ostpforte, ↔ jeder Stationszugang. Sichtprüfung: Ein Strahl von der Standard-Kamera (22 m) zum Kopf (1,7 m) des Spielers an jedem Stationszugang trifft die Hütte nicht. Esse-Licht ohne Schatten. **Am Bruch:** Abschnitte `bruch`/`quarry`, Ostpforte (nach Öffnen begehbar), 12 Sammelstellen Am Bruch + 7 im Schlag + Holunder, Kamera-/Laufgrenzen, Boden 64 × 64, Esse-Licht ohne Schatten.
- **Playthrough-Bot (W3):** `phase5_bot.gd` erweitert `Phase4Bot` um Freischaltung, Käufe bei Osric/Ilse (echter `DialogueRunner` für `p5_intro`), Bauen, Sammeln mit Werkzeugstufen, Meiler, Stationshandwerk, Steinwahl (bestes passendes Design, das Material erlaubt) und Setzen. **Münzbuch je Strategie:** Start, Einnahmen (Bezahlung, Pflegegeld, Gaben, Ilse-Verkäufe), Ausgaben nach `coins_spent.reason` (license, build, osric, ilse), Ende, niedrigster Morgenstand.
  | Strategie | Start | Tage | Verhalten | Erwartung |
  |---|---|---|---|---|
  | `reverent5` | v3 `day20_reverent` | 10 | Bogen A §1.4, Gold für 3 Steine | Kapitel ≤ Tag 28; Phase-5-Ausgaben ≥ 100; Ende 10–45; Morgenstand nie < 10; ≥ 6 Gräber neu gesetzt |
  | `toolsmith` | v3 `day20_reverent` | 10 | erst alle Werkzeuge auf Stufe 2, dann Steine | alle Stufe 2 bis Tag 25; gemessene Minuten je Aktion = Tabelle §2.3 (Uhr-Differenz); Kapitel ≤ Tag 29; Münzen ≥ 0 |
  | `mender` | v3 `day20_mixed` | 10 | Meistersteine zuerst für beraubte Gräber | zufriedene Geister +≥ 3; kein voll beraubter Geist wird zufrieden |
  | `harvester5` | v3 `day25_harvester` | 10 | Pflicht, kein Gold | Kapitel erreicht; Ende ≥ 60 (Befund dokumentieren, kein Fehler); voll beraubte Geister bleiben unruhig |
  | `crafter` | neues Spiel | 30 | reverent + Phase 5 ab `workshop_open` | `six_pits` ≤ Tag 22 (unverändert); `names_in_stone` ≤ Tag 30; Phase-5-Ausgaben ≥ 100; Ende 15–80; ≥ 4 Totenhemden vom Webstuhl |
  | `save_load5` | wie `reverent5` | 10 | lädt jeden Morgen | bitgleich zu `reverent5` |
  - **Phase-4-Bot:** `mixed` mit `prep_on_harvest` (§2.9), Erwartung „Sachlich"/„Abgebrüht" + Zusatzprüfungen. Übrige Phase-4-Erwartungen unverändert (die Strategien nutzen Phase 5 nicht). Qualitätsgrenze im Bot-Test 0…270 → 0…380 (18 × 19 + 36). Phase-3-Bot unverändert grün.
- Save-Fuzzer (W3): + v4-Stand mitten in Phase 5 (Meiler brennt, Ablage 2/3, Erlen gemischt, Gürtel voll) mit gezielten Mutationen der Phase-5-Teile (`workshop`, `gathering`, `stonemasonry`, `design`, `tools`) + alle v3/v2/v1-Fixtures. Gleiche zwei erlaubte Ausgänge.
- Art-Prototyp-Regression: `test_art_prototype.gd` unverändert grün.

## 11. Screenshot-Liste Gate G5 (`graveyard_shots_phase5.gd -- --out=/abs/dir` + `ui_screenshots.gd --phase5`, 1280×720 → `docs/reviews/phase5_round1/`)
| # | Motiv |
|---|---|
| p5_00a | **Alter Hof vorher** (Build `69f8d49`, Kamera auf die Hütte, Tag) |
| p5_00b | **Alter Hof nachher, Bauplätze leer** (gleiche Kamera): Holzhaufen versetzt, drei Bauplätze mit Pflöcken |
| p5_00c | **Alter Hof nachher, Werkhof gebaut** (gleiche Kamera): Webstuhl vor der Hütte, Steinmetzbank mit 2 fertigen Steinen, Esse-Kamin mit Rauch über dem Dach |
| p5_01 | Übersicht Tag: Friedhof mit Werkhof + Am Bruch, Ostpforte offen |
| p5_02 | Am Bruch nah: Lehmkuhle, Flachsbeete reif, Findlinge vor dem Steinbruch |
| p5_03 | Werkhof am Abend: Spieler an der Esse (westlich der Hütte, sichtbar), Glut, Meiler raucht hinter dem Dach |
| p5_04 | Werkhof nachts: Esse-Glut neben der Hüttenlaterne, Geister im Holunderwinkel dahinter |
| p5_05 | Steinbruch vorher (Findlinge) / nachher (Erzader, Werksteinbank) |
| p5_06 | Schlag: Erlen in drei Stufen nebeneinander (Baum, Stock, Stockausschlag) |
| p5_07 | Flachsbeet reif vs. gerauft; Kräuterrain |
| p5_08 | Spieler fällt eine Erle / bricht einen Findling (Aktionsbalken) |
| p5_09 | Bauplatz-Panel (etwas fehlt) |
| p5_10 | Werkstatt-Panel Esse (Werkzeug-Wirkung, Meiler „fertig um …") |
| p5_11 | Werkstatt-Panel Webstuhl |
| p5_12 | Stein-Panel: Grab gewählt, Inschrift „passt", vergoldet, Zierde Holunderdolde, Vorschau, „Grab 13 → 19" |
| p5_13 | Inventar mit Werkzeuggürtel (Stufen) und 20 Slots |
| p5_14 | Steinreihe (Debug `stones showcase`): 3 Formen, 4 Zierden, schwarz vs. gold, Tag |
| p5_15 | Meisterstein am Grab nah (Zoom 12 m): Inschrift lesbar, Klammern, Zierde |
| p5_16 | derselbe Stein nachts im Laternenlicht (Gold nicht leuchtend, nur warm) |
| p5_17 | Holunderwinkel mit gestalteten Steinen, Nacht, Geister zufrieden |
| p5_18 | Geist mit `by_design`-Sprechblase „Da steht mein Name …" |
| p5_19 | Osric `p5_intro` + Brief-Kauf |
| p5_20 | Ilse: Blattgold im Laden |
| p5_21 | Grabregister mit Inschrift-Spalte / Totenzettel mit Steintext |
| p5_22 | Tageszusammenfassung mit „Ausgaben" |
| p5_23 | Abschluss-Panel „Namen in Stein" |
Dazu Asset-Tafeln `docs/reviews/phase5_assets/` und eine Performance-Tabelle je Motiv (`perf_p5_01…04`: Bruch Tag Zoom max, Werkhof nachts mit Esse + 3 verwesenden Leichen am Tisch, Friedhof mit 18 Inschriften, Werkhof Tag Zoom max).

## 12. Wellenplan
| Welle | Agents (parallel) | Inhalt | Ende |
|---|---|---|---|
| **W0** | Lead | **Zuerst v3-Fixtures mit Build `69f8d49`** (6 Stände §5.2, eigener Commit vor jedem Gerüst) und `tests/fixtures/phase5/layout_p4.json` (Layout-Kopie für den Diff-Test). Dann: Datenklassen ✦ (inkl. Erweiterungen), Stubs mit exakten Signaturen, 8 EventBus-Signale, Database-Ordner, `Category.MATERIAL`, `SaveMigration.CURRENT = 4` mit `migrate_3_to_4` als Identität (fail-safe), Config-Fixtures `tests/fixtures/phase5/` (+ `Phase5Fixtures`, u. a. `grave_with(corpse, marker, design)`, `inv_with_tools(tiers)`), `test_phase5_scaffold.gd`, `test_saves_v3_load.gd` | Import + alle Tests grün → Commit |
| **W1** | P1, P2, P3, P4, P5, P6 (bei 5 Agents: P1 + P6) | Systeme mit Unit-Tests gegen Fixtures (ohne Welt): Werkstatt/Bau/Meiler (P1) · Sammelstellen, Arbeitsabschnitte, Hindernis-Werkzeug (P2) · Gürtel, Werkzeugstufen, Minuten (P3) · Stein-Gestaltung, Kalender, Qualität, Setzen, Geister (P4) · Assets + Asset-Tests (P5) · Migration v4, Osric/Ilse, `coins_spent`, **Pietät-Fix** (P6) | je Modul: Tests grün → Merge durch Lead, danach `--import` |
| **W2** | W-Welt, W-UI (2 parallel) | **Werkhof an der Hütte** (Bauplätze/Stationen, Holzhaufen V1, Bau-Maske V2, Gras V3, Routen- und Sicht-Prüfung, Vorher/Nachher p5_00a–c), Bodenerweiterung Ost, Am Bruch (Rohstoffe), Schlag, Holunder-Sammelstellen, Ostpforte, Esse-Licht, Builder `graveyard_build_phase5.gd`, `test_phase5_loop`; Werkstatt-/Bauplatz-/Stein-Panel mit Vorschau, Gürtel-Leiste, HUD-Tooltip, Zielzeilen, Tageszusammenfassung, Debug, Icons | Integration + Roundtrips grün, Screenshots erstellt |
| **W3** | QA (19), Art (04), Lead | `phase5_bot.gd` (6 Strategien inkl. **crafter**, **toolsmith**, Münzbuch), `phase4_bot` `mixed` + `prep_on_harvest`, Save-Fuzzer v4, Performance, Stil-/Ton-Prüfung (Inschriften, Gold, Glut, Erlen-Stufen), Befunde beheben (Besitzer), Gate-Protokoll in `QUALITY_GATE_STATUS.md` | **STOPP – Benutzerprüfung G5** |
Abhängigkeiten:
- W1-Agents nutzen nur Stubs und Datenklassen anderer Module.
- P3 liefert den Gürtel zuerst (Tag 1 der Welle): P1 (Werkzeug-Rezepte), P2 (Sperren) und P4 hängen an `ToolRules.tier`. Bis dahin liefert der Stub `ToolRules.tier` 0 und `Inventory` das alte Verhalten.
- `grave_plot.gd`: P3 ändert nur die zwei Minuten-Zeilen (`dig`, `bury`), P4 ergänzt Stein-Prompt und -Aktion. Merge-Reihenfolge P3 → P4.
- P1 liefert `Workshop.workyard_rects` + `DecorationManager.evict_rects` vor W2 (W-Welt füllt die Rechtecke aus dem Layout).
- P5 liefert zuerst die Steinformen + Zierden (Vorschau im Stein-Panel), `ph_bld_*` (Esse-Kamin mindestens 0,5 m über der Hütten-Traufe, damit er über dem Dach sichtbar ist) und `ph_env_quarry_face` (Blocker für W2-Screenshots). Bis dahin: graue Platzhalter-Quader aus dem Builder (nur Tests, nie in Screenshots).
- Texte: P6 besitzt `carter.tres`/`trader.tres`, P4 `data/stone/**` und `ghost_lines.tres`, P1 `data/stations/*`, P2 `data/gather/*` und neue Item-Texte. Die Leittexte stehen in §2. Wer sie ändert, meldet es dem Lead.

## 13. Nicht in Phase 5
- Freie Platzierung oder Abriss von Stationen, weitere Gebäude, Werkstatt-Innenräume (Gebäude: Phase 6)
- Neue Grabstellen oder neue Lieferungen nach vollem Friedhof (Benutzerentscheidung §14.1: später), Exhumieren, Umbetten
- Verkauf von Handwerkswaren, Aufträge des Dorfes, Preisdynamik, weitere Händler (Dorf/Wirtschaft: Phase 7/10)
- Freitext-Inschriften, Schriftwahl, Übersetzungen der Inschriften
- Item-Qualitätsstufen, Werkzeug-Verschleiß oder Reparatur, Werkzeug sichtbar in der Hand der Figur (Modell bleibt, Stufe nur im Gürtel)
- Mehr als ein Hintergrund-Auftrag je Station, Handwerk in Abwesenheit außer dem Meiler, Warteschlangen
- Tiere, Landwirtschaft über das Flachsbeet hinaus, Aussaat/Samen für Flachs, Jahreszeiten, Wetter
- Neue Erzählfäden oder Erkenntnisse (der Bezug zu Lorenz' Werkplatz ist nur ein Osric-Satz, Benutzerentscheidung §14.4)
- Krypten unter dem Birkenhang (Phase 12), Kräfte (Phase 13+), Kampf
- Musik, Sound (Agent 17 inaktiv), Controller, Lokalisierung
- Änderungen am Maler-Shader, an den Atmosphären-Presets, am Hütten-Innenraum und an den Abschnitten I–IV (außer Werkhof V1–V3 und Ostpforte); Hütte, Leichentisch, Werkbank und Pförtchen werden nicht bewegt

## 14. Benutzerentscheidungen (28.09.2026, bindend)
1. **Keine neuen Grabstellen in Phase 5**; sie kommen später. Der Phase-5-Bogen auf einem Phase-4-Endstand lebt vom Neu-Setzen der 18 Steine. Die Münzrechnung §2.8 gilt unverändert.
2. **Stationen neben der Hütte.** Steinmetzbank, Webstuhl und Esse bilden einen Werkhof um die Hütte (§2.1, §4.1). Freigegebene Elemente im Alten Hof dürfen versetzt werden, aber nur das Nötigste: Holzhaufen (V1), gesperrte Zier-Zellen (V2), Gras (V3). Hütte, Leichentisch, Werkbank und Pförtchen bleiben stehen. „Am Bruch" bleibt Rohstoffgebiet (Steinbruch, Findlinge, Erz, Stein, Lehmkuhle, Flachs, Kräuter). Die Esse hält die Licht- und Partikelbudgets ein (§4.1, §9).
3. **Jahreszahl 1834** auf den Inschriften (Spieltag 1 = 3. Gilbhart 1834, alte Monatsnamen).
4. **Lorenz' Werkplatz: ja.** Osric führt den Bruch in einem Satz als Lorenz' alten Werkplatz ein, ohne neuen Hinweis und ohne Erkenntnis (§2.6).

## W0-Notizen (Lead, Welle 0 – verbindlich für W1)
1. **v3-Fixtures** `tests/fixtures/saves_v3/*.json` wurden **vor** jeder Code-Änderung mit Stand 30343c5 erzeugt (Code identisch zu 69f8d49, nur Doku neu) – über `Phase4Bot` + echte Systeme (`make_v3_saves.gd` + `_driver.gd`, historisches Werkzeug; `-- --out=/abs/dir [--only=day7,day13,day20r,day20m,day25,interior]`; auf einem Phase-5-Stand schriebe es v4). Eigener Commit 243fd53 vor dem Gerüst, zusammen mit `tests/fixtures/phase5/layout_p4.json` (= `data/world/graveyard_layout.json` von 69f8d49, bytegleich). Gemessene Stände:
   - *day7_table* (`mixed`, Tag 7 = Verwerter-Tag, 10:00): Tagesleiche auf dem Tisch, **„2 von 4 Schritten" = Untersuchungsschritte** `clothing` + `hands` (§5.2 sagt nicht, welche Schritte), Zopf genommen, Wacholder-Fenster läuft; Wurzelbürste, Kamm, Rechen, Schere, Zange in Slots. Ruf 51, Pietät 10, 11 Münzen.
   - *day13_complete* (`reverent`, 09:00): `cemetery_complete`, Holunderwinkel offen, 12 Gräber `MARKED`, `six_pits` noch offen, Ruf 98, 55 Münzen.
   - *day20_reverent* (07:00): `six_pits`, 18 Gräber, Ruf 100, **125 Münzen** (§1.4/§2.8 rechnen mit 121 – der QA-Wert „Tag 20" war der Abendstand; die Abweichung +4 ist das Pflegegeld des Morgens, die Münzrechnung bleibt gültig).
   - *day20_mixed* (07:00): `six_pits`, 18 Gräber, Ruf 99, Pietät 10, 123 Münzen, **3** beraubte Gräber mit unruhigem Geist.
   - *day25_harvester* (07:00): `six_pits`, 18 Gräber, Ruf 16, Pietät −100, **178 Münzen** (≈ 179).
   - *interior_chest_tools* (`reverent`, Tag 9, 20:00): Spieler in der Hütte, Rechen + Kamm in der Truhe, Zange (und Schere, Bürste) im Inventar; Holzbank 0,35 m neben (−8,6 | −1,3) (Webstuhl-Platz) und Grabvase 1,76 m neben (−0,5 | −10,6) (nächste gültige Zelle, innerhalb Footprint + Rand 0,6 + Zugang des Steinmetzbank-Platzes) – beide gebaut über `BuildMode` wie ein Spieler.
2. **Speicherformat v4 schon in W0:** `SaveMigration.CURRENT = 4` (`SaveFileIO`/`SaveManager.FORMAT_VERSION` folgen), Kette 1→2→3→4. `migrate_3_to_4(state, meta)` ist **Identität auf einer tiefen Kopie** (`## STUB (P6)`; fail-safe, alle `from_dict`/`load_state` tolerieren fehlende Schlüssel). **P6** implementiert §5.2 1–7. `SaveMigration.V4_EMPTY_NODES = ["workshop", "gathering", "stonemasonry"]` ist vorbereitet, wird in W0 aber **nicht** eingefügt (sonst „saved state for unknown save_id … ignored", solange W-Welt die Knoten nicht anlegt – wie Phase 4). Lead-Anpassungen an fremden Tests (nur Versionsnummer / Enum-Größe, mechanisch): `test_save_migration.gd` (`test_current_version_is_three` = 4, `test_version_four_is_rejected` = `CURRENT + 1`, Roundtrip = `FORMAT_VERSION`), `test_saves_v2_load.gd`, `test_phase3_save_upgrade.gd`, `test_save_fuzzer.gd` (Neuspeichern = `FORMAT_VERSION`), `test_phase3_scaffold.gd`, `test_phase4_scaffold.gd` (Enum 7 Werte, v4). Lade-Wächter `tests/integration/test_saves_v3_load.gd`: 6 v3-Fixtures laden **ohne jede Warnung**, Zustand erhalten, Neuspeichern v4, Roundtrip identisch. Die Prüfungen zählen Werkzeuge über `count` (bleiben nach Gürtel-Migration gültig). v2/v1-Fixtures laden weiter (Kette bis 4).
3. **Datenklassen ✦ vollständig** (§3.2.1): `StationData`, `WorkshopConfig`, `GatherNodeData`, `ToolConfig`, `StoneShapeData`, `InscriptionData`, `OrnamentData`, `StoneConfig`, **`StoneDesign` fertig** (`to_dict` = Format §5.1 mit Strings, leeres Design → `{}`; `from_dict` tolerant; `is_empty` = keine Form). `ActionConfig.tool_minutes` ist **fertig** (Datenklassen-Helfer, §2.3-Tabelle im Scaffold-Test geprüft; Stufen außerhalb der Tabelle werden geklemmt, nie unter einem Schritt).
4. **Erweiterungen bestehender Datenklassen (Klassen-Defaults = Vertrag):** `ItemData.Category.MATERIAL = 6` (angehängt) + `tool_kind`/`tool_tier`, `RecipeData.background`, `ClearableData.tool_kind/min_tier`, `SectionData.is_burial = true`, `ActionConfig` (+ `tool_tier_factors`, `action_tools`, `tool_minute_step`), `PlayerConfig.inventory_slots = 20`, `GhostLines.by_design` (neu; **`nameless` ist ein Schlüssel in `by_reason`**, kein eigenes Feld), `ReputationConfig.event_points` + `master_stone 3`, `PietyConfig.full_prep_requires_unharvested = true`, `PrepConfig.balm_items = [juniper, herb_bundle]`, `TraderConfig.shop` + `gold_leaf {6, 2}`. **Abweichung (wie Phase 4):** `EconomyConfig` bleibt in W0 bei **`quality_max 13`** und `marker_quality` **ohne** die Formen (Default und `.tres`): 19 bzw. die Formen brechen die „/13"-Texte in `test_entities.gd` und `test_grave_quality.gd::test_clamp_to_max`/`test_real_economy_config_matches_defaults`/`test_phase4_lines_in_order` sowie über `GhostMood` (Grund `cross` hängt an den Zeichen-Punkten) drei Fälle in `test_ghosts.gd`. **P4** stellt Default **und** `economy_config.tres` gemeinsam um (Formen + 19) und passt diese Tests an (Lead-genehmigt); die Phase-5-Werte stehen schon in `tests/fixtures/phase5/economy_config_fixture.tres`. **Die `.tres` der Besitzer sind unverändert** (setzen die alten Werte ausdrücklich): `player_config.tres` 16 Slots (→ P3), `economy_config.tres` (→ P4), `reputation_config.tres` (→ P4), `trader_config.tres` (→ P6). `prep_config.tres`/`piety_config.tres` setzen die neuen Felder nicht → die Defaults gelten schon, werden aber erst von P6 gelesen. Ebenfalls **nicht** in W0: `GameState.DEFAULT_STATS` (+ crafted, stones_set, coins_spent, trees_felled → P6, sonst ändern sich alle Stand-Vergleiche).
5. **Neue Config-Dateien** mit Vertragswerten: `data/config/{workshop_config (→ P1), tool_config (→ P3), stone_config (→ P4)}.tres`. Identische Kopien in `tests/fixtures/phase5/*_fixture.tres` (Scaffold-Test: data == Fixture == Klassen-Default bis zur Übergabe; danach dürfen die Daten abweichen, die Fixture bleibt – Besitzer tragen Abweichungen dort ein).
6. **Nicht** in W0 angelegt (Besitzer, W1): `data/stations/*` (P1), `data/gather/*`, `data/sections/{bruch,quarry}.tres`, `data/clearables/{boulder,gate_east}.tres`, Werkzeugfelder in den bestehenden `data/clearables/*` (P2), `data/items/*` (13 Werkstoffe → P2, 6 Werkzeuge → P3), `data/recipes/*` (P1/P3 laut §3.2), `data/stone/**`, `ghost_lines.tres`-Erweiterung (P4). Die Fixtures unten sind vollständige Vorlagen mit den Leittexten aus §2 (kopieren erlaubt). Neue Abschnitte in `data/sections` ändern `Database.sections().size()` – P2 passt `test_phase3_scaffold.gd::test_sections_in_data_and_fixtures` dann an (Lead-genehmigt); `test_phase5_scaffold.gd::test_extended_data_classes` erwartet für **alle** echten Abschnitte `is_burial` – P2 schränkt die Prüfung auf I–IV ein (Lead-genehmigt).
7. **Stubs** (Körper leer/trivial, `## STUB (P<n>)`, Signaturen exakt §3.4; Test `test_phase5_scaffold.gd` mit Liste `IMPLEMENTED`, die Besitzer füllen):
   - **P1:** `WorkshopRules` (+ `TEXT_BUILT`, `TEXT_MISSING`, `COIN`), `Workshop` (Gruppen `workshop`, `saveable`; `save_id "workshop"`, `save_order 30`; `@export workyard_rects`; `var config`), `BuildSite` (+ minimales `build_site.tscn` nur mit `Interactable`; `PANEL &"build_site"`). An bestehenden Klassen: `Workbench.requires_built` (Export ohne Wirkung), `DecorationManager.evict_rects` (liefert `{}`).
   - **P2:** `GatherRules` (+ `STAGE_*`), `GatherManager` (Gruppen `gathering`, `saveable`; `"gathering"`, 25), `GatherNode` (+ `gather_node.tscn` nur mit `Interactable`).
   - **P3:** `ToolRules` (`tier` = 0 bis zum Gürtel, §12). An bestehenden Klassen: `Inventory.tool_belt` (Export ohne Wirkung), `Inventory.tools()` (liefert `{}`), `Player.tool_tier(kind)` (= `ToolRules.tier(inventory, kind)`).
   - **P4:** `StoneDesignRules`, `StoneCalendar`, `Stonemasonry` (Gruppen `stonemasonry`, `saveable`; `"stonemasonry"`, 35). An bestehenden Klassen: `GraveRecord.design` (Feld, **noch nicht** in `to_dict`/`from_dict` – P4), `Graveyard.set_designed_stone` (liefert 0), `GraveQuality.breakdown/compute(…, _design: Dictionary = {})` (Parameter noch ungelesen; P4 benennt ihn in `design` um). `GhostMood` ändert P4 selbst (fertige Klasse).
   - **P5:** keine Stubs. **P6:** `SaveMigration.migrate_3_to_4` (Identität).
   - W-UI/W-Welt: Panels und Builder nicht als Stub (W2).
8. **EventBus:** die 8 Signale aus §3.3 (`station_built`, `workshop_job_changed`, `resource_gathered`, `gather_node_changed`, `tool_tier_changed`, `stone_order_changed`, `grave_stone_set`, `coins_spent`). **Eingaben:** keine neuen (§3.6); das Stein-Panel blättert mit den Phase-4-Aktionen `journal_page_prev/next`.
9. **Database** (§3.5): `station/stations` (`data/stations`, nach id), `gather_kind/gather_kinds` (`data/gather`, nach id), `stone_shape/stone_shapes`, `inscription/inscriptions`, `ornament/ornaments` (`data/stone/{shapes,inscriptions,ornaments}`, nach `order`, bei Gleichstand nach id); leere/fehlende Ordner = leere Listen. Configs über `config(&"workshop_config" | &"tool_config" | &"stone_config")`.
10. **Fixtures für W1:** `tests/fixtures/phase5/` – `{workshop,tool,stone}_config_fixture.tres` (= W0-Daten), Phase-5-Werte bestehender Configs: `action_config_fixture` (Faktoren, `action_tools`, Schritt 5), `player_config_fixture` (20 Slots), `economy_config_fixture` (Phase-4-Fixture + Formen, **`quality_max 19`**, Maximum im Test nachgerechnet), `reputation_config_fixture` (+ `master_stone`), `piety_config_fixture`, `prep_config_fixture`, `trader_config_fixture` (+ Blattgold); `ghost_lines_fixture.tres` (Phase-4-Platzhalter + `by_reason.nameless` und `by_design` mit den Leittexten §2.5); `stations/` (workbench prebuilt, mason, loom, forge; `build_text` sind W0-Entwürfe – P1 formuliert), `gather/` (8 Arten §2.2), `clearables/{boulder,gate_east}`, `sections/{bruch,quarry}`, `recipes/` (13, `charcoal` mit `background`), `stone/{shapes (3), inscriptions (7), ornaments (4)}`; `tests/fixtures/items/` + 13 MATERIAL-Items und 6 Stufen-Werkzeuge. Zugriff: `Phase5Fixtures` (`tests/fixtures/phase5/phase5_fixtures.gd`), u. a. `design(shape, ins, orn, gilded, text)`, `corpse(age, cause, story_id)`, **`grave_with(corpse, marker, design)`** (FILLED ohne Zeichen, sonst MARKED; Qualität mit der Phase-5-Economy-Fixture, Stein-Zeilen kommen mit P4), **`inv_with_tools(tiers, items)`** (unbegrenztes Test-Inventar mit Gürtel `tools()` = `{item_id: 1}`, `count/has/remove_item` sehen den Gürtel; nötig, weil `data/items` bis P3 keine Werkzeuge kennt), `install_save_v3`, `save_v3_path`, `layout_p4()`.
11. **Lücken, pragmatisch entschieden:**
    - `SectionData.order` für `bruch`/`quarry` steht nicht im Vertrag: Fixture **5 / 6** (nach `elder` 4; beide liegen außerhalb der Bau-Maske, der Index wird dort nicht gelesen).
    - `quarry`: „`requires_section bruch`, sonst wie `bruch`" – die Fixture setzt nur `requires_section` (der Brief ist über `bruch` schon Voraussetzung), `requires_flag_text` = „Findlinge versperren den Weg.".
    - Animationen: Der Spieler hat keine eigene Fäll-Animation – `alder`, `clay_pit`, Steinbruch-Stellen, `boulder`, `gate_east` nutzen `&"dig"` (wie alle Hindernisse), Flachs/Beeren/Kräuter `&"interact"`.
    - `StoneShapeData.label_width` 0,5 / 0,55 / 0,7 m und `max_lines 4` sind W0-Schätzwerte (P4/P5 passen an die Modelle an).
    - Werkzeug-Items haben `max_stack 1`; Rechen, Bürste, Kamm, Schere, Zange behalten `tool_kind &""` (keine Stufen).
12. **Testzahl:** vor W0 1 473, nach W0 **1 506** (+ `test_phase5_scaffold.gd` 25, `test_saves_v3_load.gd` 8).
