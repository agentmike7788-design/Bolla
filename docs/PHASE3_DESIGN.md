# Phase 3 – Friedhof vollständig ausbauen – Vertrag v1

Status: **v1 – verbindlich für die Umsetzung nach Benutzerfreigabe** · Verantwortlich: Agent 01 (Lead), Agent 02 (Game Design), Agent 08 (Godot Core)
Baut auf `docs/VERTICAL_SLICE_DESIGN.md` (Vertrag v2, Phase 2 – freigegeben) auf. Alles, was dieses Dokument nicht ändert, gilt dort unverändert weiter.
Gameplay-Werte sind **Vorschläge**; der Benutzer prüft sie beim Gate G3. ART STYLE LOCK „Gemaltes Diorama" ist aktiv – Phase 3 ändert den Stil nicht, nur Inhalt, Licht-Stimmung der tiefen Nacht und Geister (alles innerhalb des Stils).

**Benutzerentscheidungen (verbindlich, 27.09.2026)**
- Inhalt: (1) Friedhof erweitern (Gestrüpp/Steine räumen, Zaun reparieren → neue Grabfelder), (2) Deko & Sauberkeit (Bänke, Blumen, Laternen, Wege; Unkraut und Laub wachsen nach), (3) Ruf & Einkommen (Qualität → Ruf → Bezahlung/Lieferungen, sichtbare Stufen), (4) Geister der Bestatteten (nachts, reagieren auf ihr Grab).
- Ton: **Ausgewogen** – tagsüber gemütlich, nachts deutlich unheimlicher (mehr Nebel, kaltes Licht, Geister) über Licht, Nebel und Shader.
- Größe: **etwa doppelt** – 12 statt 6 Grabstellen in 3 Abschnitten (1 bestehend + 2 neu, nacheinander freigelegt).

**Regeln für alle Agents** (wie Phase 2)
- Klassen, Signaturen, Dateipfade, Signale und Datenformate hier sind **fest**. Änderungen nur über den Lead.
- Der Lead legt in **Welle 0** alle Datenklassen (✦) vollständig und alle Logikklassen als **Stubs mit exakten Signaturen** an; Besitzer füllen die Körper, benennen nichts um.
- Nach jedem neuen Worktree und nach jedem Merge: `godot --headless --path . --import`.
- Jede Datei hat genau einen Besitzer (§3.2). Fremde Dateien nicht ändern – Bedarf an den Lead melden.
- Alle neuen Assets tragen `ph_` und kommen in die Placeholder-Liste (`docs/QUALITY_GATE_STATUS.md`).
- Keine Mechaniken, Namen oder Texte anderer Spiele übernehmen. Eigene Identität dieser Phase: **„Der Hügel erinnert sich"** – was man pflegt, erzählt; was man vernachlässigt, flüstert nachts.

---

## 1. Spielablauf & Progression

### 1.1 Erweiterter Kern-Loop
```
Leiche → untersuchen → bestatten → Grabzeichen → Qualität + Bezahlung (inkl. Ruf-Bonus)
  → Holz/Stein/Münzen → Gestrüpp roden, Steine räumen, Zaun flicken → neuer Abschnitt, neue Grabstellen
  → Zier bauen (Werkbank) & aufstellen (Baumodus) → Zier-Punkte
  → Unkraut/Laub wachsen nach → pflegen (sonst Abzug)
  → Friedhofsqualität → Ruf (täglich) → Bezahlung, Pflegegeld, Lieferhäufigkeit
  → Nacht: Geister zeigen, wie es ihrem Grab geht → Hinweise (was fehlt) → Grab aufwerten / pflegen / schmücken
```

### 1.2 Abschnitte (Übersicht; Werte §2.1)
| # | id | Name | Grabstellen | Freilegen | Voraussetzung |
|---|---|---|---|---|---|
| I | `yard` | **Alter Hof** | `plot_01…06` (bestehend) | offen ab Start | – |
| II | `east` | **Ostwiese** | `plot_07…09` | 4× Brombeergestrüpp, 3× Feldsteinhaufen, 3× Zaunlücke | keine (ab Tag 1 möglich) |
| III | `north` | **Birkenhang** | `plot_10…12` | 1× Dornenhecke (Zugang), 3× Gestrüpp, 2× Feldsteinhaufen, 2× Baumstumpf, 3× Zaunlücke | Ostwiese frei **und** Friedhofsqualität ≥ „Würdevoll" (50) |

Ein Abschnitt wird **automatisch freigegeben**, sobald alle seine Hindernisse geräumt und alle Zaunlücken repariert sind: Pflöcke der neuen Grabstellen erscheinen, Benachrichtigung („Die Ostwiese ist freigelegt – 3 neue Grabstellen."), Belohnung: Ruf +4.

### 1.3 Tagesbogen (Richtwert für ein neues Spiel, 1 Leiche/Tag bis „Geschätzt")
| Tag | Geschehen | Zielzeile (Beispiele) |
|---|---|---|
| 1 | Slice-Tutorial unverändert. Im Alten Hof sind 6 Pflegestellen leicht verunkrautet (Stufe 1–2). Erstes Grab. Ab 21:30 erscheint der erste Geist. | „Etwas regt sich zwischen den Gräbern …" (21:00, einmalig) |
| 2 | Osric erzählt von der Ostwiese („Die Gemeinde hätte nichts dagegen …"), verkauft **Eisenbeschläge** und **Blumensamen**. Rezept Rechen. Erstes Jäten. | „Unkraut jäten (2 Stellen)" |
| 3–4 | Erste Zier (Beet, Holzbank). Durchgang zur Ostwiese roden. Ruf steigt auf „Geachtet". | „Ostwiese freilegen: 3/10" |
| 5–6 | Alter Hof voll (6 Gräber). Ostwiese fertig → `plot_07…09`. | „Neue Grabstellen auf der Ostwiese" |
| 7–8 | Qualität ≥ 50 → Birkenhang bearbeitbar. Ruf „Geschätzt" → **zwei Leichen pro Morgen** (zweite Bahre). | „Birkenhang: erst die Dornenhecke" |
| 9–11 | Birkenhang frei, letzte Gräber, Grabzeichen aufwerten, Nachtbesuche bei unruhigen Geistern. | „Friedhof: Ehrwürdig ab 100" |
| ~11–12 | Alle 12 Grabstellen vollendet → **Phasenziel** | – |

**Phasenende:** Sind alle 12 (nicht alten) Grabstellen `MARKED` und kein Abschnitt gesperrt: Flag `cemetery_complete`, Signal `cemetery_completed`, Abschluss-Panel (Variante „Der Friedhof ist vollendet": Tage, Bestattungen, Qualität + Stufe, Zier, Pflege, Ruf + Stufe, zufriedene Geister). Das Spiel läuft danach frei weiter (Pflege, Zier, Geister); Lieferungen enden still, weil kein Grab mehr frei ist (bestehende Regel §2.5 b). **Gate-Ziel:** Stufe „Ehrwürdig" (≥ 100) erreichbar, „Würdevoll" auch bei nachlässiger Pflege.

### 1.4 Nacht (Ton „Ausgewogen")
- 21:00–22:30 Nacht wie bisher (freigegebenes Preset `night`), ab 22:30 **tiefe Nacht** (`deep_night`, §2.8): dichterer Bodennebel, kühleres Umgebungslicht, Geisterlicht färbt den Volumennebel. Ab 03:00 zurück zu `night`, 05:30 Dämmerung.
- Geister erscheinen 21:30, verblassen bis 04:30. Kein Kampf, keine Gefahr, kein Zeitdruck. Schlafen bleibt ab 18:00 möglich (Aufwachen 06:00) – Wachbleiben kostet nichts.

---

## 2. Spielwerte (Vorschläge, alle in `data/`)

### 2.1 Freilegen (`data/sections/<id>.tres` – `SectionData`, `data/clearables/<kind>.tres` – `ClearableData`)
| kind | Name / Verb | Minuten | Kosten | Ertrag |
|---|---|---|---|---|
| `bramble` | Brombeergestrüpp / „roden" | 30 | – | 1 wood |
| `rubble` | Feldsteinhaufen / „räumen" | 40 | – | 2 stone |
| `stump` | Baumstumpf / „ausgraben" | 60 | – | 2 wood |
| `hedge` | Dornenhecke / „durchschneiden" | 60 | – | 2 wood |
| `fence_gap` | Zaunlücke / „reparieren" | 30 | 2 wood, 1 iron_fittings | – |

| Abschnitt | Arbeit gesamt | Kosten gesamt | Ertrag gesamt | `decor_cap` |
|---|---|---|---|---|
| `yard` | – | – | – | 12 |
| `east` | 330 Min (≈ 5,5 h) | 6 wood, 3 iron_fittings (9 Münzen) | 4 wood, 6 stone | 9 |
| `north` | 440 Min (≈ 7,3 h) | 6 wood, 3 iron_fittings | 9 wood, 4 stone | 9 |

Regeln: Räumen braucht freie Hände, ist eine TimedAction (abbrechbar, verbrauchte Minuten bleiben verbraucht). Passt der Ertrag nicht ins Inventar → gesperrt („Kein Platz im Inventar"). Hindernisse eines Abschnitts mit unerfüllter Voraussetzung zeigen den Grund gedimmt („Erst die Ostwiese freilegen" / „Erst Friedhof „Würdevoll" (50)"). Zaunlücken zeigen fehlende Teile („Fehlt: 1 Eisenbeschlag").
*Begründung:* Die Ostwiese passt in die Lücke, in der der Alte Hof voll wird (Tag 5–6); die Kosten (9 Münzen Eisen) sind nach 3–4 Bestattungen bezahlbar. Der Birkenhang ist absichtlich an Qualität gebunden – Zier und Pflege lohnen sich dadurch, bevor der Platz ausgeht.

### 2.2 Neue Items & Rezepte
| id | Name | Kategorie | Stapel | Herkunft |
|---|---|---|---|---|
| `iron_fittings` | Eisenbeschlag | RESOURCE | 20 | Osric, 3 Münzen |
| `seeds` | Blumensamen | RESOURCE | 20 | Osric, 1 Münze |
| `rake` | Rechen | TOOL (neu) | 1 | Werkbank |
| `decor_bench_wood` | Holzbank | DECOR (neu) | 5 | Werkbank |
| `decor_bench_stone` | Steinbank | DECOR | 5 | Werkbank |
| `decor_flowerbed` | Blumenbeet | DECOR | 5 | Werkbank |
| `decor_grave_vase` | Grabvase | DECOR | 10 | Werkbank |
| `decor_lantern` | Grablaterne | DECOR | 6 | Werkbank |
| `decor_path_gravel` | Kiesplatte | DECOR | 40 | Werkbank |

`ItemData.Category` wird um `DECOR` (3) und `TOOL` (4) **am Ende** erweitert (bestehende Zahlenwerte bleiben). HUD-Ressourcenleiste zeigt weiterhin nur RESOURCE/CRAFTED (> 0); DECOR erscheint in der Bauleiste, TOOL im Inventar.

| Rezept (Station `workbench`) | Zutaten | Ergebnis | Minuten | `category` |
|---|---|---|---|---|
| `rake` | 3 wood | 1 rake | 20 | `tool` |
| `decor_bench_wood` | 4 wood | 1 | 40 | `decor` |
| `decor_bench_stone` | 6 stone | 1 | 60 | `decor` |
| `decor_flowerbed` | 1 wood, 2 seeds | 1 | 20 | `decor` |
| `decor_grave_vase` | 1 stone, 1 seeds | 1 | 15 | `decor` |
| `decor_lantern` | 2 wood, 1 iron_fittings | 1 | 30 | `decor` |
| `decor_path_gravel` | 2 stone | 4 | 20 | `decor` |
Bestehende Rezepte bekommen `category = &"grave"`. `RecipeData` erhält `@export var category: StringName = &"grave"`.

### 2.3 Zier (`data/decor/<item_id>.tres` – `DecorData`, `data/config/decor_config.tres` – `DecorConfig`)
| Deko | Footprint (Zellen à 0,5 m) | Zier | zählt max. | aufstellbar max. | Kollision | Besonderes |
|---|---|---|---|---|---|---|
| Holzbank | 3 × 1 | 3 | 4 | – | ja | – |
| Steinbank | 3 × 1 | 5 | 3 | – | ja | – |
| Blumenbeet | 2 × 2 | 2 | 8 | – | ja (flach) | unterdrückt Unkraut in seinen Zellen; Geister-Bonus (≤ 1,8 m) |
| Grabvase | 1 × 1 | 1 | 12 | – | nein | darf in den Grabring; Geister-Bonus (≤ 1,8 m) |
| Grablaterne | 1 × 1 | 3 | 6 | **6** | ja (dünn) | warmes Licht nachts (ohne Schatten); darf in den Grabring; Geister-Bonus (≤ 3,0 m) |
| Kiesplatte | 1 × 1 | 1 je 4 Platten | 24 Platten | – | nein, begehbar | darf auf Wege; unterdrückt Unkraut |

- **Zier-Wert** = Σ über Abschnitte `min(decor_cap, Σ Beiträge im Abschnitt)`; Beitrag je Deko-Art = `floor(min(Anzahl, counted_max) × zier / zier_divisor)` (Kies: `zier 1, divisor 4`). Maximum 12 + 9 + 9 = **30**. *Begründung:* Abschnitts-Obergrenzen belohnen Verteilen statt Stapeln; 30 ≈ 3 gute Gräber – spürbar, aber Gräber bleiben der Kern.
- `DecorConfig`: `cell_size 0.5`, `max_placed 80` (alle Deko inkl. Kies), `place_minutes 5`, `remove_minutes 5`, `cursor_distance 1.2`, `grid_overlay_radius 3.0`.
- **Abbauen** gibt das Stück vollständig zurück (1 Item, kein Verlust). Voll → abgelehnt („Kein Platz im Inventar").

### 2.4 Pflege (`data/config/cleanliness_config.tres` – `CleanlinessConfig`)
- **Pflegestellen:** 22 Flächenstellen aus dem Layout (`yard` 12 – davon 4 Laub unter der Eiche –, `east` 5, `north` 5 – davon 2 Laub unter Birken) + je eine **Grabstelle** pro Grabplatz (`dirt_<plot_id>`, Unkraut auf dem Hügel) = **34**.
- **Stufen** 0 sauber · 1 „sprießt" · 2 „verunkrautet" / „Laub liegt" · 3 „verwildert". Stufe = `min(3, floor(progress))`.
- **Wachstum** pro Spieltag: Unkraut `0.30`, Laub `0.40`, je Stelle ± 25 % (fester Faktor aus `hash(spot_id)`), berechnet **aus der Differenz der Spielminuten** (wie Verfall; nie Ticks zählen), angewendet bei `hour_changed` und `time_skipped`.
- Wächst nur, wenn: Abschnitt freigegeben · nicht von Kies/Beet überdeckt · Grabstellen nur bei `FILLED`/`MARKED`.
- **Start (neues Spiel):** Flächenstellen im Alten Hof mit `start_progress` aus dem Layout (6 Stellen 1,2–2,4, Rest 0); neue Abschnitte starten bei Freigabe mit 0. **Migrierte Phase-2-Stände:** alle Stellen 0 („frisch gepflegt" – kein plötzlicher Stufenverlust beim Laden).
- **Pflegen** (freie Hände, TimedAction, Stufe ≥ 1 → Fortschritt 0): Unkraut jäten 15 Min (Stufe 3: 25 Min) per Hand; Laub harken 10 Min, **braucht `rake`** (Prompt ohne Rechen: „Rechen nötig – Werkbank").
- **Abzug** je Stelle: Stufe 0/1/2/3 → 0/0/1/2 (`penalty_by_level`). *Begründung:* Stufe 1 ist nur sichtbar, nicht strafend → kein Mikromanagement; nach ~6–7 Tagen ohne Pflege kostet eine Stelle 1, nach ~10 Tagen 2. Aufwand im Mittel ≈ 60–85 Spielminuten/Tag bei vollem Friedhof, weniger mit Kieswegen.
- Geister-Einfluss der Grabstelle: Stufe 0/1/2/3 → +1/0/−2/−4 (`grave_mood_by_level`).

### 2.5 Friedhofsqualität & Stufen (`EconomyConfig`, `CemeteryScore`)
**Friedhofsqualität = max(0, Gräber + Zier − Pflegeabzug)**
- Gräber = Σ Qualität der `MARKED`-Gräber (alte Gräber 0, unverändert). Maximum 120, realistisch 95–105.
- Zier 0…30 (§2.3), Pflegeabzug 0…68 (typisch 0–6 bei Pflege, 15+ bei Vernachlässigung).

| Stufe | id | ab | Hinweis |
|---|---|---|---|
| Verwahrlost | `neglected` | 0 | – |
| Ordentlich | `orderly` | 15 | unverändert |
| Gepflegt | `tended` | 32 | unverändert |
| Würdevoll | `dignified` | 50 | unverändert – Voraussetzung Birkenhang |
| **Ehrwürdig** | `venerable` | **100** | neu – Phasenziel |
`EconomyConfig.rating_thresholds = [15, 32, 50, 100]`; `CemeteryRating.TIERS` erhält `VENERABLE` **am Ende**, `LABELS["venerable"] = "Ehrwürdig"`.
*Begründung:* 15/32/50 bleiben, damit Phase-2-Spielstände ihre Stufe behalten und die freigegebene Slice-Balance gilt. 100 verlangt ≥ 10 gute Gräber **plus** Zier **und** Pflege (6 Gräber allein ergeben nur ~51) – eine neue Stufe statt verschobener Schwellen.
**Grabzeichen aufwerten (neu):** an einem `MARKED`-Grab mit Holzkreuz und einem Grabstein im Inventar: „[E] Grabstein statt Kreuz setzen (10 Min)" → Qualität neu berechnet (+2), Kreuz verfällt, **keine zweite Bezahlung**, Ruf +1. Der wichtigste Weg, unruhige Geister zu beruhigen.

### 2.6 Ruf (`data/config/reputation_config.tres` – `ReputationConfig`)
Eigener Wert **0…100** in `GameState.stats.reputation` (Dialog-Bedingungen `stat_gte/stat_lt` bleiben nutzbar). Neues Spiel: **25**.
| Stufe | id | ab | Bezahlung je Bestattung | Pflegegeld/Tag | Lieferungen |
|---|---|---|---|---|---|
| Verrufen | `disreputable` | 0 | −2 | 0 | nur an ungeraden Tagen, 1 |
| Unauffällig | `unremarkable` | 15 | ±0 | 1 | 1/Tag |
| Geachtet | `respected` | 35 | +1 | 2 | 1/Tag |
| Geschätzt | `esteemed` | 55 | +2 | 3 | **2/Tag** |
| Gerühmt | `renowned` | 80 | +3 | 4 | 2/Tag |

- **Täglicher Drift** (bei `day_started`, genau einmal je Tag, Merker-Flag `rep_last_day`): `ziel = clamp(20 + round(0.6 × Friedhofsqualität), 0, 100)`; `Ruf += clamp(round((ziel − Ruf) × 0.34), −6, +6)`. Der Ruf folgt also der Qualität **mit Verzögerung** (2–4 Tage).
- **Ereignisse** (vom auslösenden System direkt über `Reputation.change`, nicht über Signal-Listener): Grab vollendet mit Qualität ≥ 8: +2 · ≤ 3: −3 · Wertsachen genommen: −8 (`EconomyConfig.valuables_reputation`, bisher −1) · verpasste Lieferung (Bahren belegt): −4 · Grabzeichen aufgewertet: +1 · Abschnitt freigelegt: +4.
- **Pflegegeld** wird bei `day_started` nach dem Drift in das Spielerinventar gezahlt (`payment_received(n, "Pflegegeld der Gemeinde")`) und in der Tageszusammenfassung gezeigt.
- **Bezahlung** = `base_payment(Todesursache)` + `floor(Qualität × 0,5)` + Ruf-Bonus, nie < 0.
*Nachrechnung Ruf (Richtwert):* T1 26 · T2 29 · T3 33 · T4 38 (Geachtet) · T5 44 · T6 50 · T7 56 (Geschätzt → ab T8 zwei Leichen) · T10 ≈ 68 · Ende ≈ 75–82.
*Nachrechnung Münzen (12 Bestattungen):* Einnahmen ≈ 12 × 9 + Pflegegeld ≈ 25 + Geistergaben ≤ 24 ≈ 150; Ausgaben Leichentücher 12 × 6 = 72, Freilegen 18, Zier nach Wahl 20–40 → Münzen sind endlich gebunden (mildert GP-03), ohne Zwang.

### 2.7 Lieferungen (Änderung zu Phase-2 §2.5)
- Anzahl je Tag = `ReputationRules.deliveries_on(day, tier)`; jede Leiche braucht eine **freie Bahre** (`dropoff`, neu `dropoff_2`) **und** `freie Grabstellen > nicht bestattete Leichen`. Die zweite Leiche hat `spawn_index_of_day = 1` (Seed-Formel unverändert), gleiche Ankunftszeit 07:40.
- Fehlt nur eine Bahre: Versäumnis (einmal je Tag: `missed_deliveries += Anzahl`, Ruf −4, Flag `delivery_skipped`). Fehlt Platz (b): still, wie bisher. Verrufen an geraden Tagen: still, Osric-Dialog erklärt es.
- **`slice_complete` beendet keine Lieferungen mehr** (CorpseManager, Npc, ObjectiveResolver prüfen es nicht mehr). Gesperrte Grabstellen (`LOCKED`) zählen nie als frei.
- Osrics Karren zeigt die erste Leiche des Tages (zweite: Polishing, nicht Pflicht).

### 2.8 Geister (`data/config/ghost_config.tres` – `GhostConfig`, `data/ghosts/ghost_lines.tres` – `GhostLines`)
- **Wer:** je `MARKED`-Grab ein Geist, sobald die Nacht **nach** der Vollendung beginnt (`completed_day < heute` oder vollendet vor 21:00 desselben Tages). Migrierte Gräber (`completed_day = 0`) sofort.
- **Wann:** sichtbar 21:30–04:30 (`appear_minute 1290`, `vanish_minute 270`), Ein-/Ausblenden über 30 Spielminuten. In der Hütte unsichtbar (Logik läuft weiter).
- **Wie viele:** höchstens **6 gleichzeitig** (`max_active`): die dem Spieler nächsten berechtigten, neu gewählt jede Sekunde mit 2 m Hysterese. Pool von 6 Knoten, kein Erzeugen/Freigeben pro Wechsel.
- **Stimmung** (neu berechnet bei `grave_state_changed`, `grave_quality_changed`, `dirt_changed`, Deko-Änderung):
  `wert = Grabqualität + Pflegestelle (+1/0/−2/−4) + Zierbonus (Beet/Vase ≤ 1,8 m: +1 je, Laterne ≤ 3,0 m: +1; zusammen max. +2)`
  `≥ 9` **zufrieden** (`content`) · `5…8` **gleichmütig** (`calm`) · `≤ 4` **unruhig** (`restless`).
  Beispiel: Tuch + Grabstein + untersucht + frisch = 9, gepflegt +1 → zufrieden; nur Holzkreuz 7 + 1 = 8 → gleichmütig, mit Vase 9 → zufrieden; Wertsachen genommen 5, verwildert −4 → unruhig.
- **Verhalten:** schweben 0,3–0,6 m über dem Hügel (Auf-Ab 0,08 m / 3 s); zufrieden: ruhig am Kopfende, hält das Seelenlicht hoch; gleichmütig: treibt langsam (0,4 m/s) im Radius 2 m; unruhig: umkreist das Grab (0,8 m/s), flackert (Alpha 0,4–0,8). Innerhalb 3,5 m wenden sie sich dem Spieler zu. Keine Kollision, kein Kampf, kein Folgen über den Radius hinaus.
- **Sprechen:** Interactable (Priorität 15), „[E] Zuhören – *Name* wirkt zufrieden/gleichmütig/unruhig". Sofort (keine TimedAction, Zeit läuft), Sprechblase 4 s über dem Geist, ≤ 90 Zeichen. Innerhalb 60 Spielminuten wiederholt derselbe Geist dieselbe Zeile. Auswahl deterministisch aus `hash(grave_id) + Tag`.
  - unruhig/gleichmütig: **Hinweis auf den größten Mangel** (Priorität): `weeds` (Grabstelle ≥ 2) → `valuables` (genommen) → `cold` (kein Tuch) → `cross` (nur Holzkreuz, aufwertbar) → `waited` (verwesend bestattet) → `bare` (kein Zierbonus). Ton: trocken-melancholisch, eigene Texte (P4), je Grund 3 Zeilen.
  - zufrieden: Dank-Zeilen (8) und Merkmals-Zeilen (`letter`, `tattoo`, `strange_wound` – kleine Andeutungen auf Phase 4, je 2).
- **Gabe (klein):** Beim **ersten** Zuhören eines **zufriedenen** Geistes, einmal je Grab: „Der Geist deutet ins Moos – zwei Münzen." → +2 Münzen (`gift_coins 2`). Maximal 24 Münzen im ganzen Spiel. Sonst nichts – Geister sind Rückmeldung, kein Farmziel.
- **Tiefe Nacht:** Preset `data/atmosphere/deep_night.tres` (Mond 0,45, Umgebung kühler Richtung `#1F2A3A`, Nebel 0,018, Volumennebel 0,04, Albedo blasses Blaugrün); Stützstellen der Welt: `blend_presets = [deep_night, deep_night, night, dawn, day, day, dusk, night, deep_night]` @ `blend_minutes = [0, 180, 270, 330, 480, 1020, 1140, 1260, 1350]`. Die freigegebenen Presets `night/dawn/day/dusk` bleiben unverändert. Geisterlichter: `#6FE3D2`, Energie 0,5, Reichweite 2,5 m, **ohne Schatten**, `light_volumetric_fog_energy 1.0` (Schimmer im Nebel).

---

## 3. Architektur

### 3.1 Neue Systemknoten (unter `WorldRoot/Systems`, alle vom Welt-Builder angelegt)
| Knoten | Klasse | Gruppen | save_id / save_order |
|---|---|---|---|
| `Expansion` | `ExpansionManager` | `expansion`, `saveable` | `expansion` / **5** |
| `CorpseManager` | (bestehend) | | `corpse_manager` / 0 |
| `Graveyard` | (bestehend, erweitert) | | `graveyard` / 10 |
| `Cleanliness` | `CleanlinessManager` | `cleanliness`, `saveable` | `cleanliness` / **12** |
| `Decorations` | `DecorationManager` | `decorations`, `saveable` | `decorations` / **15** |
| `BuildMode` | `BuildMode` | `build_mode` | – (nicht gespeichert; Laden/Szenenwechsel beendet ihn) |
| `GrassClearMask` | `GrassClearMask` | – | – (abgeleitet) |
| `CemeteryScore` | `CemeteryScore` | `cemetery_score` | – (abgeleitet) |
| `Reputation` | `Reputation` | `reputation` | – (Wert in `GameState`) |
| `Ghosts` | `GhostManager` | `ghosts`, `saveable` | `ghosts` / **30** |
Keine neuen Autoloads.

### 3.2 Module & Besitz (Phase 3)
| Modul | Besitzt (Pfade) |
|---|---|
| **Lead** (W0 + laufend) | `project.godot` (Input, Shader-Globals), `src/core/*` (EventBus, Database), alle **Datenklassen ✦** (unten), alle **Stubs** (nur bis zur Übergabe), `tests/run_tests.gd`, `tests/framework/*`, `tests/fixtures/*` (inkl. `saves_v1/*`, Config-Fixtures), `docs/*`, `CLAUDE.md` |
| **P1 Ausbau & Gräber** (W1) | `src/systems/expansion/expansion_manager.gd`, `src/entities/clearable/*`, `src/systems/graveyard/{graveyard,grave_record,grave_quality}.gd`, `src/entities/grave/*`, `src/systems/corpse/{corpse_manager,corpse_delivery_rules,corpse_save_codec}.gd`, `src/entities/npc/npc.gd`, `src/entities/dropoff/*`, `data/sections/*`, `data/clearables/*`, `tests/unit/test_expansion.gd`, `test_graveyard.gd`, `test_grave_quality.gd`, `test_corpse_manager.gd`, `test_entities.gd` |
| **P2 Zier & Bauen** (W1) | `src/systems/decoration/{decoration_manager,decor_placement,build_grid,build_mode,build_cursor,grass_clear_mask}.gd`, `src/entities/decor/*`, `src/entities/player/player.gd` (nur Baumodus-Haken §3.4), `data/decor/*`, `data/config/decor_config.tres`, `data/items/decor_*.tres`, `data/recipes/decor_*.tres`, `tests/unit/test_build_grid.gd`, `test_decoration.gd`, `test_build_mode.gd` |
| **P3 Pflege, Qualität, Ruf** (W1) | `src/systems/cleanliness/{cleanliness_manager,dirt_growth}.gd`, `src/entities/dirt_spot/*`, `src/systems/graveyard/{cemetery_score,cemetery_rating}.gd`, `src/systems/reputation/{reputation,reputation_rules}.gd`, `src/systems/game_state/game_state.gd`, `data/config/{cleanliness_config,reputation_config,economy_config}.tres`, `data/items/rake.tres`, `data/recipes/rake.tres`, `tests/unit/test_cleanliness.gd`, `test_cemetery_score.gd`, `test_cemetery_rating.gd`, `test_reputation.gd`, `test_game_state.gd` |
| **P4 Geister & Nacht** (W1) | `src/systems/ghosts/{ghost_manager,ghost_mood}.gd`, `src/entities/ghost/*`, `assets/shaders/{ghost.gdshader,grass.gdshader}`, `assets/materials/mat_ghost.tres`, `data/config/ghost_config.tres`, `data/ghosts/*`, `data/atmosphere/deep_night.tres`, `tests/unit/test_ghosts.gd`, `test_atmosphere.gd` |
| **P5 Assets** (W1) | `tools/blender/{asset_props_phase3,asset_env_phase3,asset_ghost}.py`, `tools/blender/asset_items.py`, `tools/blender/build_all.py`, `assets/models/{decor,props,environment,items}/**` (nur neue Phase-3-Dateien), `assets/models/characters/ph_chr_ghost.glb`, `art_source/blender/**` (Phase 3), `tests/unit/test_assets_phase3.gd`, `docs/reviews/phase3_assets/*` |
| **P6 Speichern & Dialog** (W1) | `src/systems/save/{save_migration,save_file_io,save_manager}.gd`, `src/systems/dialogue/dialogue_conditions.gd`, `data/dialogue/carter.tres`, `data/items/{seeds,iron_fittings}.tres`, `tests/unit/test_save.gd`, `test_save_migration.gd`, `test_dialogue.gd`, `tests/integration/test_phase2_save_upgrade.gd` |
| **W-Welt** (W2) | `data/world/graveyard_layout.json`, `src/world/graveyard/*` (Builder, neue Helfer `graveyard_build_phase3.gd`, `world_root.gd`, `graveyard_shots_phase3.gd`), `src/entities/notice_board/*`, `tools/blender/asset_ground_graveyard.py`, `src/world/camera/camera_rig.gd` (nur falls nötig), `tests/integration/{test_graveyard_world,test_phase3_loop}.gd`, `docs/reviews/phase3_round1/*` |
| **W-UI** (W2) | `src/ui/**`, `assets/ui/**`, `src/debug/*` (außer `asset_preview.gd`, `screenshot_capture.gd`), `tests/unit/{test_ui,test_objective,test_ui_phase3}.gd`, `tests/integration/test_ui_flow.gd` |
| **Eingefroren** | `src/world/art_prototype/*`, `src/entities/player/player_proto.*`, `data/art_prototype/*`, freigegebene Presets `data/atmosphere/{day,night,dawn,dusk}.tres`, `src/world/hut_interior/*` (keine Änderung geplant) |

✦ **Datenklassen (W0, Lead, nur Felder + kleine reine Helfer):** `SectionData`, `ClearableData`, `DecorData`, `DecorConfig`, `BuildMask`, `CleanlinessConfig`, `ReputationConfig`, `GhostConfig`, `GhostLines`; Erweiterungen `ItemData.Category`, `RecipeData.category`, `EconomyConfig` (Schwellen-Default `[15, 32, 50, 100]`, `valuables_reputation` −8; `reputation_thresholds` bleibt deklariert, wird nicht mehr gelesen).
Bei nur fünf Agents übernimmt P3 zusätzlich P6.

### 3.2.1 Klassen → Dateien
| Klasse | Datei | Art |
|---|---|---|
| `SectionData`, `ClearableData` | `src/systems/expansion/{section_data,clearable_data}.gd` | ✦ |
| `ExpansionManager` | `src/systems/expansion/expansion_manager.gd` | Stub (P1) |
| `ClearableObstacle` | `src/entities/clearable/clearable.gd` + `.tscn` | Stub (P1) |
| `DecorData`, `DecorConfig`, `BuildMask` | `src/systems/decoration/{decor_data,decor_config,build_mask}.gd` | ✦ |
| `DecorPlacement`, `BuildGrid`, `DecorationManager`, `BuildMode`, `BuildCursor`, `GrassClearMask` | `src/systems/decoration/*.gd` | Stub (P2) |
| `PlacedDecor` | `src/entities/decor/placed_decor.gd` + `.tscn` | Stub (P2) |
| `CleanlinessConfig` | `src/systems/cleanliness/cleanliness_config.gd` | ✦ |
| `DirtGrowth`, `CleanlinessManager` | `src/systems/cleanliness/*.gd` | Stub (P3) |
| `DirtSpot` | `src/entities/dirt_spot/dirt_spot.gd` + `.tscn` | Stub (P3) |
| `CemeteryScore` | `src/systems/graveyard/cemetery_score.gd` | Stub (P3) |
| `ReputationConfig` | `src/systems/reputation/reputation_config.gd` | ✦ |
| `ReputationRules`, `Reputation` | `src/systems/reputation/*.gd` | Stub (P3) |
| `GhostConfig`, `GhostLines` | `src/systems/ghosts/{ghost_config,ghost_lines}.gd` | ✦ |
| `GhostMood`, `GhostManager` | `src/systems/ghosts/*.gd` | Stub (P4) |
| `Ghost` | `src/entities/ghost/ghost.gd` + `.tscn` | Stub (P4) |
| `SaveMigration` | `src/systems/save/save_migration.gd` | Stub (P6) |
| `NoticeBoard` | `src/entities/notice_board/notice_board.gd` + `.tscn` | W-Welt |

### 3.3 EventBus – neue Signale (Ergänzung `src/core/event_bus.gd`)
```gdscript
# Friedhof-Ausbau (ExpansionManager)
signal obstacle_cleared(obstacle_id: String, section_id: StringName)
signal section_progress_changed(section_id: StringName, done: int, total: int)
signal section_unlocked(section_id: StringName)                  # nach Graveyard.unlock_section
# Gräber (Graveyard)
signal grave_quality_changed(grave_id: String, quality: int)     # Grabzeichen aufgewertet
signal cemetery_completed                                        # Phasenziel (§1.3)
# Zier & Bauen (DecorationManager, BuildMode)
signal decor_changed(uid: String, decor_id: StringName, placed: bool)   # aufgestellt (true) / abgebaut
signal build_mode_changed(active: bool)
# Pflege (CleanlinessManager)
signal dirt_changed(spot_id: String, level: int)                 # nur bei Stufenwechsel
signal cleanliness_changed(penalty: int, dirty_spots: int)       # dirty = Stufe ≥ 2; gebündelt (höchstens 1× je Aktion/Zeitsprung)
# Ruf (Reputation)
signal reputation_changed(value: int, tier: StringName, delta: int, reason: String)
# Geister (GhostManager)
signal ghost_spoke(grave_id: String, mood: StringName, text: String)
signal ghost_night_changed(active: bool)                         # 21:30 an / 04:30 aus
```
- `cemetery_quality_changed(total, rating)` wird ab Phase 3 **nur noch von `CemeteryScore`** gesendet (synchron nach jeder Änderung von Gräbern, Zier oder Pflege, nur wenn sich `total` oder `rating` ändert – nach `world_ready`/Laden genau einmal). `Graveyard` sendet es nicht mehr.
- `slice_completed` bleibt deklariert, wird nicht mehr gesendet.
- Regel wie Phase 2: Listener ändern keinen Spielzustand. Ruf-Ereignisse ruft das auslösende System direkt auf (`Reputation.change`). Zeitgetriebene Systeme (Drift, Wachstum, Geister) reagieren wie Verfall/Lieferung auf Zeit-Signale.

### 3.4 Logik-Klassen (Signaturen = Vertrag)

**Ausbau (P1)**
```gdscript
class_name SectionData extends Resource            # ✦ data/sections/<id>.tres
@export var id: StringName; @export var display_name: String; @export var order: int   # yard 1, east 2, north 3 (= Bau-Masken-Index)
@export var starts_unlocked: bool = false
@export var requires_section: StringName = &""; @export var requires_rating: StringName = &""
@export var decor_cap: int = 9
@export_multiline var unlock_text: String
class_name ClearableData extends Resource          # ✦ data/clearables/<kind>.tres
@export var id: StringName; @export var display_name: String; @export var verb: String   # "roden"
@export var minutes: int = 30; @export var animation: StringName = &"dig"
@export var cost: Dictionary[StringName, int] = {}; @export var yield_items: Dictionary[StringName, int] = {}
@export var model: PackedScene; @export var repaired_model: PackedScene    # nur fence_gap (repariert = ph_prop_fence_iron)

class_name ExpansionManager extends Node           # Systems/Expansion; sammelt in _ready alle Knoten der Gruppe &"clearable"
func sections() -> Array[SectionData]              # nach order
func is_unlocked(section_id: StringName) -> bool
func unlocked_indices() -> PackedInt32Array        # SectionData.order der offenen Abschnitte (für BuildGrid)
func block_reason(section_id: StringName) -> String   # "" = bearbeitbar; sonst Anzeigetext (Voraussetzung)
func is_cleared(obstacle_id: String) -> bool
func obstacle_ids(section_id: StringName) -> PackedStringArray
func progress(section_id: StringName) -> Vector2i  # (erledigt, gesamt)
func missing_cost(obstacle_id: String, inv: Inventory) -> Dictionary   # {id: Menge}
func can_clear(obstacle_id: String, inv: Inventory) -> bool          # Voraussetzung, Kosten, Ertrag passt
func clear(obstacle_id: String, inv: Inventory) -> bool   # atomar: Kosten ab, Ertrag rein, obstacle_cleared, section_progress_changed; letzter → unlock
func unlock(section_id: StringName) -> bool        # graveyard.unlock_section, Ruf +4, section_unlocked, Benachrichtigung (auch Debug)
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void; func post_load() -> void   # post_load: offene Abschnitte ohne freie Plots → reparieren (Warnung)
class_name ClearableObstacle extends Node3D        # Gruppe &"clearable"; Interactable Priorität 8
@export var obstacle_id: String; @export var section_id: StringName; @export var kind: StringName
@export var footprint: Rect2 = Rect2(-1, -1, 2, 2) # lokal XZ: Bau-Sperre + Gras-Maske solange vorhanden
func world_rect() -> Rect2
func apply_cleared(cleared: bool) -> void          # Modell/Kollision; fence_gap zeigt dann repaired_model
# can_interact/get_interaction_prompt/interact: "[E] Brombeeren roden (30 Min) → +1 Holz"; Zustand nur aus ExpansionManager (nicht gespeichert)
```

**Gräber (P1) – Änderungen**
```gdscript
enum State { EMPTY, DUG, FILLED, MARKED, OLD, LOCKED }   # LOCKED neu, am Ende (Speicherwerte bleiben)
# GraveRecord: + var completed_day: int = 0   (gesetzt in place_marker = TimeManager.day; to_dict/from_dict)
# GravePlot: + @export var section_id: StringName = &"yard"; LOCKED = keine Visuals, keine Kollision, kein Prompt
# Graveyard._collect_plots: Plot eines Abschnitts mit starts_unlocked == false → LOCKED; load_state überschreibt mit gespeicherten Records
func unlock_section(section_id: StringName) -> int         # LOCKED → EMPTY für dessen Plots; grave_state_changed je Plot; Anzahl
func plots_in_section(section_id: StringName) -> PackedStringArray
func upgrade_options(grave_id: String, inv: Inventory) -> Array[StringName]   # Grabzeichen mit höherer marker_quality im Inventar
func upgrade_marker(grave_id: String, marker_id: StringName, inv: Inventory) -> int   # MARKED → MARKED; Qualitätsdifferenz, 0 = abgelehnt; grave_quality_changed, Ruf +1
func total_quality() -> int                                # UNVERÄNDERT: Summe der Gräber (nicht Friedhofsqualität!)
# place_marker: Bezahlung über GraveQuality.payment_parts (+ Ruf-Bonus), Reputation.change(+2/−3), completed_day; KEIN cemetery_quality_changed mehr
# _check_slice_complete → _check_cemetery_complete: alle nicht-OLD Gräber MARKED und kein LOCKED → Flag cemetery_complete, cemetery_completed,
#   ui_panel_requested(&"slice_summary", {…Phase-2-Felder…, variant: &"cemetery", decor, dirt, reputation_tier, content_ghosts})
class_name GraveQuality  # + static func payment_parts(corpse: CorpseRecord, quality: int, tables: CorpseTables, config: EconomyConfig, rep_tier: StringName, rep: ReputationConfig) -> Dictionary   # {base, quality, reputation, total}
# CorpseManager: Lieferung je Tag bis ReputationRules.deliveries_on(day, tier) Leichen; freie Bahre je Leiche (alle Knoten der Gruppe &"dropoff");
#   + func deliveries_of(day: int) -> Array[CorpseRecord]; try_daily_delivery(day) bleibt (erste Leiche des Tages)
#   Speichern: "last_delivery_ids": Array[String] (liest v1-Feld "last_delivery_id" als Fallback). slice_complete wird ignoriert.
# CorpseDeliveryRules: + static func free_dropoffs(dropoffs: Array[Node]) -> Array[Node]; report_skip(day, reason, count := 1)
```

**Zier & Bauen (P2)**
```gdscript
class_name DecorData extends Resource              # ✦ data/decor/<item_id>.tres
@export var id: StringName                         # = Item-id (decor_bench_wood …)
@export var display_name: String; @export var model: PackedScene
@export var footprint: Vector2i = Vector2i.ONE     # Zellen bei Drehung 0 (X × Z)
@export var zier: int = 1; @export var zier_divisor: int = 1; @export var counted_max: int = 0; @export var place_max: int = 0   # 0 = unbegrenzt
@export var walkable: bool = false; @export var allow_route: bool = false; @export var allow_grave_ring: bool = false
@export var suppresses_dirt: bool = false; @export var ghost_bonus_radius: float = 0.0
@export var collider_size: Vector3 = Vector3.ZERO  # 0 = keine Kollision
class_name DecorConfig extends Resource            # ✦ Felder §2.3
class_name BuildMask extends Resource              # ✦ vom Welt-Builder gebacken: src/world/graveyard/build_mask.res
const BLOCKED := 0; const SECTION_MASK := 0x0F; const GRAVE_RING := 0x10; const ROUTE := 0x20
@export var origin: Vector2; @export var cell: float = 0.5; @export var size: Vector2i; @export var cells: PackedByteArray
func world_to_cell(p: Vector2) -> Vector2i; func cell_to_world(c: Vector2i) -> Vector2   # Zellmitte
func flags_at(c: Vector2i) -> int                  # außerhalb = BLOCKED
func section_at(c: Vector2i) -> int                # flags & SECTION_MASK (0 = nicht bebaubar)

class_name DecorPlacement extends RefCounted
var uid: String; var decor_id: StringName; var cell: Vector2i; var rot: int   # rot 0..3 (× 90°)
func to_dict() -> Dictionary; static func from_dict(d: Dictionary) -> DecorPlacement
class_name BuildGrid extends RefCounted            # reine Logik, ohne Szenenbaum testbar
func _init(mask: BuildMask) -> void
static func footprint_cells(cell: Vector2i, size: Vector2i, rot: int) -> Array[Vector2i]   # rot 1/3 tauscht X/Z; Anker = Zelle unten links
func check(decor: DecorData, cell: Vector2i, rot: int, occupied: Dictionary, blockers: Array[Rect2], unlocked: PackedInt32Array) -> StringName
# Gründe (in dieser Prüfreihenfolge): &"ok", &"blocked", &"locked_section", &"obstacle", &"route", &"grave_ring", &"occupied"
#   occupied: {Vector2i: uid}; walkable-Deko (Kies) und nicht-begehbare Deko schließen sich gegenseitig aus; alle Zellen im selben Abschnitt
class_name DecorationManager extends Node          # Systems/Decorations
@export var mask: BuildMask; @export var container_path: NodePath   # Decor/Placed
func placements() -> Array[DecorPlacement]
func can_place(decor_id: StringName, cell: Vector2i, rot: int, inv: Inventory = null, player: Player = null) -> StringName
#   zusätzlich zu BuildGrid: &"no_item", &"limit" (place_max / max_placed), &"player" (Kapsel im Footprint), &"corpse" (Leiche am Boden)
func place(decor_id: StringName, cell: Vector2i, rot: int, inv: Inventory) -> String    # uid oder ""; entnimmt 1 Item; decor_changed
func remove(uid: String, inv: Inventory) -> bool   # gibt 1 Item zurück; voll → false
func placement_at(cell: Vector2i) -> DecorPlacement
func decor_score() -> int                          # §2.3
func score_by_section() -> Dictionary              # {order: {raw: int, capped: int, cap: int}}
func suppresses_dirt_at(p: Vector2) -> bool
func ghost_bonus_at(p: Vector2) -> int             # 0..2 (§2.8)
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void   # load erzeugt die Knoten neu (Welt-_ready erzeugt keine)
class_name PlacedDecor extends Node3D              # Modell, optional StaticBody3D (Layer 1), Licht an Marker light_* (Gruppe warm_lights, shadow=false)
var uid: String; var decor_id: StringName
class_name BuildMode extends Node                  # Systems/BuildMode
var active: bool; var selected: StringName; var rotation_step: int
func enter() -> bool                               # nur draußen, Hände frei, nicht beschäftigt, kein Modal; build_mode_changed(true)
func exit() -> void; func toggle() -> void
func available() -> Array[StringName]              # DECOR-Items im Inventar (Reihenfolge = Bauleiste)
func select(decor_id: StringName) -> void; func rotate() -> void
func cursor_cell() -> Vector2i                     # Zelle bei Spielerposition + Blickrichtung × cursor_distance
func cursor_reason() -> StringName                 # can_place am Cursor
func focused_placement() -> DecorPlacement         # Deko unter dem Cursor (Abbauen)
func confirm_place() -> bool; func confirm_remove() -> bool   # TimedAction 5 Min, nicht abbrechbar durch Drehen
class_name BuildCursor extends Node3D              # Vorschau (Modell mit Vorschau-Material) + Raster-Overlay (1 Draw Call)
class_name GrassClearMask extends Node             # schreibt Shader-Globals grass_clear_mask / grass_clear_rect (§3.6)
func repaint() -> void                             # bei decor_changed, obstacle_cleared, section_unlocked, world_ready
# Player (Haken, P2): func set_build_mode(active: bool) -> void  – unterdrückt Interaktions-Fokus und [E]/[Q] des Spielers; Bewegung bleibt
```

**Pflege, Qualität, Ruf (P3)**
```gdscript
class_name CleanlinessConfig extends Resource      # ✦ §2.4
@export var growth_per_day: Dictionary[StringName, float] = {&"weeds": 0.30, &"leaves": 0.40}
@export var growth_jitter: float = 0.25; @export var max_level: int = 3
@export var penalty_by_level: PackedInt32Array = [0, 0, 1, 2]; @export var grave_mood_by_level: PackedInt32Array = [1, 0, -2, -4]
@export var weed_minutes: PackedInt32Array = [0, 15, 15, 25]; @export var rake_minutes: int = 10; @export var rake_item: StringName = &"rake"
class_name DirtGrowth extends RefCounted
static func rate(spot_id: String, kind: StringName, cfg: CleanlinessConfig) -> float    # Tagesrate inkl. Hash-Faktor
static func grow(progress: float, rate_per_day: float, minutes: int, cfg: CleanlinessConfig) -> float   # geklemmt auf max_level + 0.999
static func level(progress: float, cfg: CleanlinessConfig) -> int
class_name DirtSpot extends Node3D                 # Gruppe &"dirt_spot"; Interactable Priorität 6
@export var spot_id: String; @export var section_id: StringName; @export var kind: StringName; @export var grave_id: String = ""; @export var start_progress: float = 0.0
func show_level(level: int) -> void                # Modelle ph_env_weeds_1..3 / ph_env_leaves_1..3, Stufe 0 = nichts
class_name CleanlinessManager extends Node         # Systems/Cleanliness
func spot_ids() -> PackedStringArray
func level(spot_id: String) -> int; func progress(spot_id: String) -> float; func is_growing(spot_id: String) -> bool
func tend_minutes(spot_id: String, inv: Inventory) -> int   # 0 = nicht möglich (Stufe 0 / Rechen fehlt)
func tend(spot_id: String, inv: Inventory) -> bool          # Fortschritt 0; dirt_changed, cleanliness_changed
func penalty() -> int; func dirty_count(min_level: int = 2) -> int
func update_to(now_total: int) -> void              # Wachstum seit last_total (hour_changed / time_skipped)
func apply_start_state() -> void                    # nur bei new_game_started: start_progress aus dem Layout
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void   # {} → alles 0, last_total = jetzt
class_name CemeteryRating                          # + const VENERABLE := &"venerable"; TIERS = [NEGLECTED, ORDERLY, TENDED, DIGNIFIED, VENERABLE]
class_name CemeteryScore extends Node              # Systems/CemeteryScore, Gruppe &"cemetery_score"
static func compute(graves: int, decor: int, dirt_penalty: int) -> int   # maxi(0, graves + decor − dirt_penalty)
func total() -> int; func rating() -> StringName
func breakdown() -> Dictionary                     # {graves, decor, dirt (≥ 0, wird abgezogen), total, rating, next_rating (&"" an der Spitze), next_at}
func refresh() -> void                             # neu berechnen; cemetery_quality_changed nur bei Änderung (force nach world_ready/Laden)
class_name ReputationConfig extends Resource       # ✦ §2.6
@export var start_value: int = 25; @export var min_value: int = 0; @export var max_value: int = 100
@export var tier_thresholds: PackedInt32Array = [15, 35, 55, 80]
@export var target_base: int = 20; @export var target_per_quality: float = 0.6; @export var drift_factor: float = 0.34; @export var drift_max: int = 6
@export var pay_bonus: PackedInt32Array = [-2, 0, 1, 2, 3]; @export var stipend: PackedInt32Array = [0, 1, 2, 3, 4]
@export var deliveries_per_day: PackedInt32Array = [1, 1, 1, 2, 2]; @export var delivery_every_other_day: PackedInt32Array = [1, 0, 0, 0, 0]
@export var event_points: Dictionary[StringName, int] = {&"grave_good": 2, &"grave_poor": -3, &"missed_delivery": -4, &"marker_upgrade": 1, &"section_unlocked": 4}
@export var grave_good_min: int = 8; @export var grave_poor_max: int = 3
class_name ReputationRules extends RefCounted
const TIERS: Array[StringName] = [&"disreputable", &"unremarkable", &"respected", &"esteemed", &"renowned"]
const LABELS := {"disreputable": "Verrufen", "unremarkable": "Unauffällig", "respected": "Geachtet", "esteemed": "Geschätzt", "renowned": "Gerühmt"}
static func tier(value: int, cfg: ReputationConfig) -> StringName; static func tier_index(t: StringName) -> int; static func label(t: StringName) -> String
static func target(cemetery_total: int, cfg: ReputationConfig) -> int
static func drift(value: int, target: int, cfg: ReputationConfig) -> int
static func pay_bonus(t: StringName, cfg: ReputationConfig) -> int; static func stipend(t: StringName, cfg: ReputationConfig) -> int
static func deliveries_on(day: int, t: StringName, cfg: ReputationConfig) -> int   # 0 an geraden Tagen bei Verrufen
static func migrate_v1(old: int) -> int            # clampi(40 + old × 9, 0, 100): 0→40, −1→31, −2→22, −3→13
class_name Reputation extends Node                 # Systems/Reputation, Gruppe &"reputation"
func value() -> int; func tier() -> StringName
func change(delta: int, reason: String) -> void   # klemmt, GameState.stats.reputation, reputation_changed
func event(kind: StringName, reason: String) -> void   # event_points[kind]
func apply_daily(day: int) -> Dictionary           # idempotent (Flag rep_last_day): {drift, stipend}; bei day_started
func forecast() -> int                             # Drift, der beim nächsten Tageswechsel käme (HUD-Pfeil)
func last_daily() -> Dictionary                    # für die Tageszusammenfassung
# new_game_started → GameState.stats.reputation = start_value
# GameState.reputation_label() → ReputationRules.label(ReputationRules.tier(…)); DEFAULT_STATS unverändert (reset = 0)
```

**Geister (P4)**
```gdscript
class_name GhostConfig extends Resource            # ✦ §2.8
@export var appear_minute: int = 1290; @export var vanish_minute: int = 270; @export var fade_minutes: int = 30
@export var max_active: int = 6; @export var reselect_hysteresis: float = 2.0; @export var reselect_seconds: float = 1.0
@export var mood_thresholds: PackedInt32Array = [5, 9]   # < 5 restless, < 9 calm, sonst content
@export var decor_bonus_max: int = 2; @export var listen_radius: float = 2.2; @export var face_radius: float = 3.5
@export var wander_radius: float = 2.0; @export var speeds: Dictionary[StringName, float] = {&"content": 0.0, &"calm": 0.4, &"restless": 0.8}
@export var repeat_minutes: int = 60; @export var bubble_seconds: float = 4.0; @export var gift_coins: int = 2
class_name GhostLines extends Resource             # ✦ data/ghosts/ghost_lines.tres
@export var content: PackedStringArray; @export var calm: PackedStringArray
@export var by_reason: Dictionary[StringName, PackedStringArray]   # weeds, valuables, cold, cross, waited, bare
@export var by_trait: Dictionary[StringName, PackedStringArray]    # letter, tattoo, strange_wound
@export var gift: String = "Der Geist deutet ins Moos – zwei Münzen."
class_name GhostMood extends RefCounted
static func score(quality: int, dirt_level: int, decor_bonus: int, clean: CleanlinessConfig, cfg: GhostConfig) -> int
static func mood(score: int, cfg: GhostConfig) -> StringName          # &"restless", &"calm", &"content"
static func main_reason(grave: GraveRecord, corpse: CorpseRecord, dirt_level: int, decor_bonus: int, economy: EconomyConfig) -> StringName   # §2.8, &"" = kein Mangel
static func pick_line(lines: GhostLines, mood: StringName, reason: StringName, traits: Array[StringName], seed: int) -> String
class_name GhostManager extends Node               # Systems/Ghosts
@export var ghost_scene: PackedScene; @export var container_path: NodePath   # Decor/Ghosts
func is_ghost_time(minute_of_day: int) -> bool
func fade_at(minute_f: float) -> float             # 0..1
func eligible_graves() -> PackedStringArray
func mood_of(grave_id: String) -> StringName
func active_ghosts() -> Array[Ghost]
func listen(grave_id: String, player: Player) -> String   # Text; Gabe einmalig; ghost_spoke; Flag ghosts_seen
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void   # {gifts: {grave_id: day}, heard: {grave_id: day}}
class_name Ghost extends Node3D                    # Modell ph_chr_ghost + mat_ghost, OmniLight „Seelenlicht", Interactable (Priorität 15), Label3D-Sprechblase
var grave_id: String; var mood: StringName
func bind(grave_id: String, anchor: Transform3D, display_name: String) -> void
func set_mood(m: StringName) -> void; func set_fade(alpha: float) -> void; func say(text: String, seconds: float) -> void
```

**Speichern (P6)**
```gdscript
class_name SaveMigration extends RefCounted
const CURRENT := 2
static func migrate(state: Dictionary, from_version: int) -> Dictionary   # Kette 1→2 (§5.2); unbekannt/neuer → {} (= beschädigt)
static func migrate_1_to_2(state: Dictionary, meta: Dictionary) -> Dictionary
# SaveFileIO.FORMAT_VERSION = 2; read_doc akzeptiert 1…2, wandelt nach decode_state über SaveMigration; > 2 → ERR_FILE_UNRECOGNIZED („Spielstand aus einer neueren Version.")
```

### 3.5 Database (Lead)
Neue Ordner → Schlüssel: `data/sections` (`id`), `data/clearables` (`id`), `data/decor` (`id`), `data/ghosts` (Dateiname). Neue Funktionen: `section(id)`, `sections()` (nach `order`), `clearable(id)`, `decor(id)`, `decors()`, `has_decor(id)`, `ghost_lines()`. Rückgaben untypisiert wie bisher.

### 3.6 Eingaben & Shader-Globals (Lead, `project.godot`)
| Aktion | Taste | Wirkung |
|---|---|---|
| `build_mode` | B | Baumodus an/aus |
| `build_rotate` | R | Vorschau drehen (90°) |
| `build_remove` | X | Deko unter dem Cursor abbauen |
| `hotbar_1…8` | 1–8 | Deko in der Bauleiste wählen (Dialog nutzt weiter `dialogue_choice_1..4` – nie gleichzeitig aktiv) |
| `cemetery_overview` | U | Friedhofsübersicht (Panel) |
Im Baumodus: [E] = aufstellen, Esc = Baumodus verlassen (vor dem Pause-Menü).
Shader-Globals: `grass_clear_mask` (`sampler2D`, Standard 1×1 schwarz `assets/shaders/grass_clear_default.png`), `grass_clear_rect` (`vec4` Ursprung.xz, Größe.xz; Standard `(0,0,0,0)` = aus → Art-Prototyp unverändert). Texel 0,25 m über die Bau-Maske; 1 = Gras ausblenden (Hindernis steht / Deko steht). `grass.gdshader` skaliert Büschel mit Maskenwert 1 auf 0 (weicher Rand 1 Texel).

---

## 4. Welt (W-Welt)

### 4.1 Maße – Entscheidung: **Boden wird erweitert**
Die Ostwiese braucht ~10 m östlich des Zauns, der Birkenhang ~8 m nördlich; die Kamera sieht bei 45° Neigung ~11–12 m über den Fokus hinaus. Im 48 × 56 m-Boden wären Ränder sichtbar. Darum:
- `ground.size` **[56.0, 64.0]**, `ground.center` **[4.0, 2.5]** → x −24…32, z −29,5…34,5. Süd- und Westkante bleiben exakt wie bisher (Kutschweg, Waldrand unverändert). `ph_env_ground_graveyard` wird neu gebaut (Radspuren/Weg wie bisher).
- Friedhof gesamt: x −11,5…21,5, z −20…9,6 (≈ 33 × 30 m, vorher 23 × 22 m).
| Abschnitt | Rechteck (x, z) | Grabstellen (pos, rot_y 0) | Zaun |
|---|---|---|---|
| `yard` | −11,5…11,5 · −12,0…9,6 | bestehend | Ostzaun x = 11,5 erhält bei z −1,0…−3,4 einen **Durchgang** (2 Pfosten), zu Beginn vom Gestrüpp `obs_e_01` versperrt |
| `east` | 11,5…21,5 · −12,0…9,6 | `plot_07` (13,8, −7,0) · `plot_08` (16,2, −7,0) · `plot_09` (18,6, −7,0) | Süd [[11,5, 9,6], [21,5, 9,6]] intakt · Ost x = 21,5 mit Lücken `obs_e_gap_1` (21,5, −4,0), `obs_e_gap_2` (21,5, 4,0) · Nord z = −12 mit `obs_e_gap_3` (17,0, −12,0) |
| `north` | −2,0…11,5 · −20,0…−12,0 | `plot_10` (2,6, −16,2) · `plot_11` (5,0, −16,2) · `plot_12` (7,4, −16,2) | Nord z = −20 mit Lücken (1,0 / 8,0), West x = −2 mit Lücke (−2,0, −16,0), Ost x = 11,5 intakt; Zugang von Süden: **Dornenhecke** `obs_n_hedge` (4,5, −12,4), 4 m breit, zwischen alten Zaunstücken z = −12 (x −2…2,5 und 6,5…11,5) |
- Hindernis-Ids: `obs_e_01…07` (Gestrüpp/Steine, genaue Lage W-Welt, dürfen über späteren Grabstellen liegen), `obs_e_gap_1…3`, `obs_n_hedge`, `obs_n_01…07`, `obs_n_gap_1…3`.
- Zweite Bahre `dropoff_2` bei (6,9, 8,3), rot_y 0. Friedhofstafel `notice_board` bei (−1,4, 8,8) (Label3D mit der Stufe).
- Hintergrundbäume in den neuen Abschnitten werden versetzt: (11,5, −11) → (23,5, −13,5) · (13,5, 3,5) → (24,5, 2,0) · (17,5, −5,5) → (25,5, −6,0) · (3,0, −18) → (3,5, −23,5) · (12,5, −18,5) → (14,5, −16,0). Neu: 6 Birken (`ph_env_birch`), 2 innerhalb des Birkenhangs, 4 dahinter.
- `walkable_bounds`: min [−11,2, −20,3], max [21,2, 25,2] + **neu** `extra_walls` (gleiche Höhe/Dicke): [[−11,2, −12,5], [−2,0, −12,5]] (hinter der Hütte) und [[11,2, 9,9], [11,2, 25,2]] (Wald östlich des Kutschwegs bleibt gesperrt).
- `camera_bounds`: min [−7,0, −16,0], max [17,0, 23,0] (Zoom unverändert 12–24).

### 4.2 Layout-Schema-Erweiterungen (`data/world/graveyard_layout.json`)
`sections: [{id, rect: [x0, z0, x1, z1]}]` · `plots[].section` · `clearables: [{id, kind, section, pos, rot_y, footprint: [x, z, w, d]}]` · `dirt_spots: [{id, pos, section, kind, start}]` (Grabstellen erzeugt der Builder selbst: `dirt_<plot_id>` am Hügel) · `fence.ruins: [{pos, rot_y, obstacle}]` · `fence.passages` · `build: {cell: 0.5, route_width: 1.5, grave_ring: 0.5, station_margin: 0.6}` · `birches` · `extra_walls` · `atmosphere` (Stützstellen §2.8).
Neue Szenenknoten: `Entities/<obs_…>` (ClearableObstacle), `Entities/<dirt_…>` (DirtSpot), `Entities/dropoff_2`, `Entities/notice_board`, `Decor/Placed` (Container DecorationManager), `Decor/Ghosts` (Container GhostManager), `Systems/*` (§3.1).

### 4.3 Bau-Maske (gebacken, `src/world/graveyard/build_mask.res`)
Raster 0,5 m über x −11,5…21,5, z −20…9,6 (66 × 60 Zellen). Pro Zelle: Abschnitts-Index (1/2/3) oder 0 = **gesperrt** für: Grabplatz-Footprints (`GravePlot.footprint`, alte Gräber), Gebäude + 0,6 m, Stationen (+ `station_margin`), Bäume, Zaun, feste Kollisionen, Bahren, Wegweiser. `GRAVE_RING` = 0,5 m-Ring um Grabplätze. `ROUTE` = Erdweg (Breite 1,5 m), Kutscher-Route, Zugang 1,0 m vor jeder Station, Streifen vor dem Grab-Fußende, Durchgänge. Hindernisse sind **nicht** gebacken (Laufzeit-Sperre über `ClearableObstacle.world_rect()`, solange nicht geräumt). Gras wird auch unter Hindernissen gebacken und über `grass_clear_mask` ausgeblendet → nach dem Roden erscheint Gras (sichtbarer Erfolg).

---

## 5. Speichern & Migration (P6)

### 5.1 Format v2 (Ergänzungen)
```
format_version: 2
data.autoloads.GameState.stats.reputation      0…100 (neu skaliert)
data.autoloads.GameState.flags                 + rep_last_day:int, p3_intro, ghosts_seen, vs_finished, cemetery_complete
data.nodes.expansion      {"cleared": ["obs_e_01", …], "unlocked": [&"east"]}
data.nodes.graveyard      graves[] + "completed_day": int; state 5 = LOCKED
data.nodes.corpse_manager + "last_delivery_ids": ["c_0007", …]
data.nodes.cleanliness    {"last_total": int, "spots": {"dirt_y01": 1.35, …}}
data.nodes.decorations    {"next_uid": int, "placements": [{"uid": "d_12", "decor_id": &"decor_bench_wood", "cell": Vector2i(40, 22), "rot": 1}]}
data.nodes.ghosts         {"gifts": {"plot_02": 3}, "heard": {"plot_02": 5}}
```
Baumodus, Geister-Knoten, Cursor und abgeleitete Werte (Friedhofsqualität, Stimmungen) werden **nicht** gespeichert. Laden beendet den Baumodus. `can_save()` unverändert (Baumodus ist kein Modal; F5 im Baumodus erlaubt).

### 5.2 Migration v1 → v2 (Phase-2-Spielstände müssen laden)
`SaveMigration.migrate_1_to_2` wird in `SaveFileIO.read_doc` nach `decode_state` angewendet; danach normaler Ladeweg. Der nächste Speichervorgang schreibt v2.
1. `stats.reputation = ReputationRules.migrate_v1(alt)` (0 → 40 „Geachtet", −3 → 13 „Verrufen" – Stufenbedeutung bleibt).
2. Flag `slice_complete` → gelöscht, `vs_finished = true` (Osrics Knoten `slice_done` prüft künftig `flag:vs_finished`; Lieferungen laufen wieder, sobald Grabstellen frei sind).
3. `rep_last_day = meta.day` (kein doppelter Drift am Ladetag).
4. `nodes.expansion/cleanliness/decorations/ghosts` = `{}` einfügen → Standardzustand ohne Warnung (Pflege: alles 0, Uhr ab jetzt).
5. `graves[].completed_day = 0` für MARKED; fehlende Plots `plot_07…12` bleiben absent → `Graveyard.load_state` legt sie als `LOCKED` an.
6. `corpse_manager.last_delivery_ids = [last_delivery_id]` wenn nicht leer.
7. `Player`, `TimeManager`, Ressourcen, Truhe, Hütte: unverändert.
**Fixtures (W0, Lead, vor jeder Code-Änderung mit Build 481cb25 erzeugt):** `tests/fixtures/saves_v1/slot_day3.json` (mitten im Spiel, Leiche auf dem Tisch, offenes Grab), `slot_day7_complete.json` (`slice_complete`, 6 Gräber, Ruf −2), `slot_interior.json` (Spieler in der Hütte, Truhe gefüllt).

---

## 6. Debug-Konsole (W-UI) – neue Befehle
`unlock <east|north>` · `clear <obstacle_id|east|north>` (räumt ohne Kosten) · `dirt <0-3>` (alle Stellen) · `dirt grow <tage>` · `rep <0-100>` · `ghosts on|off` (Geisterzeit erzwingen/normal) · `ghost mood` (Liste Grab → Wert/Stimmung/Grund) · `decor clear` · `build free on|off` (keine Items nötig) · `tp <east|north>` · `quality` zeigt zusätzlich Zier/Pflege/Ruf.

## 7. UI (W-UI)
- **Bauleiste** (nur im Baumodus, unten mittig, ersetzt Interaktionshinweis): bis 8 Felder (Icon, Anzahl, „Zier +3"), gewähltes Feld mit Bernstein-Rahmen; darüber Statuszeile mit Grund bei ungültigem Cursor („Weg freihalten", „Zu nah am Grab", „Erst roden", „Höchstens 6 Grablaternen", „Du stehst im Weg", „Dieser Teil ist noch nicht freigelegt"), darunter Tastenhilfe „[1–8] wählen · [R] drehen · [E] aufstellen (5 Min) · [X] abbauen · [B] fertig". Abschnitts-Zier „Ostwiese: Zier 6/9".
- **Vorschau** (P2): Modell mit Vorschau-Material – gültig warm (Bernstein-Saum, 60 % Deckkraft), ungültig getrocknetes Rot `#8C2F2B` (sparsam), Raster-Linien im Radius 3 m.
- **HUD**: Qualitätsblock „Friedhofsqualität 57 · Würdevoll" + „Ehrwürdig ab 100" (bestehend) + **neue Ruf-Zeile** „Ruf: Geachtet" mit schmalem Balken 0–100 (Stufenstriche) und Pfeil ▲/▼/– (`forecast()`). Stufenwechsel → Benachrichtigung („Der Friedhof gilt jetzt als „Würdevoll"." / „In Hollerbrück bist du jetzt geschätzt.").
- **Tooltips** (Maus über HUD-Blöcken, Theme-Tooltip im Pergament-Look): Qualität „Gräber 48 · Zier +12 · Pflege −3"; Ruf „Bezahlung +1 je Bestattung · 1 Lieferung am Tag · Pflegegeld 2 · morgen +3"; Werkbank-Rezepte „Zier +3 – zählt je Abschnitt bis zur Obergrenze"; Bauleiste je Deko (Zier, Besonderheit).
- **Friedhofsübersicht** `&"cemetery_overview"` (U, auch Knopf im Grabregister): Abschnitte mit Fortschritt/Voraussetzung, Aufschlüsselung Qualität, Ruf mit allen Auswirkungen, Pflegestellen (Anzahl je Stufe), Geister (nur gehörte: zufrieden/gleichmütig/unruhig). Kontext `{score: Dictionary, sections: Array[Dictionary], reputation: Dictionary, dirt: Dictionary, ghosts: Dictionary}`.
- **Werkbank**: Rezepte gruppiert „Grab" / „Zier" / „Werkzeug" (`RecipeData.category`).
- **Belohnungskarte**: zusätzliche Zeilen „Ruf Geachtet: +1 Münze" und „Ruf +2".
- **Tageszusammenfassung**: + Pflegegeld, Ruf-Änderung (mit Stufe), verwilderte Stellen, freigelegte Abschnitte.
- **Grabregister**: Spalte „Stimmung" (nur nach Zuhören), aufgewertete Grabzeichen.
- **Zielzeile** (`ObjectiveResolver`, neue Prioritäten nach der Leichen-/Grab-Kette): Abschnitt freilegen (wenn ≤ 1 freie Grabstelle) → Pflegestellen Stufe ≥ 2 („Unkraut jäten (3 Stellen)") → Rechen fehlt bei Laub → erste Geisternacht (21:00, einmalig) → „Ehrwürdig ab 100".
- **Sprechblase**: Label3D des Geistes (P4); `ghost_spoke` zusätzlich als leise Benachrichtigung (Kind `&"info"`).

## 8. Assets (P5, Stil gesperrt, alle `ph_`, `lib_painted.py`)
| Asset | Zweck | Dreiecke | Marker / Hinweise |
|---|---|---|---|
| `ph_deco_bench_wood`, `ph_deco_bench_stone` | Bänke (1,4 × 0,45 m) | ≤ 1 200 | Pivot Mitte unten |
| `ph_deco_flowerbed` | Beet mit Holzeinfassung, gemalte Wildblumen (Bernstein/Blassviolett/Weiß – kein kaltes Sättigungsblau) | ≤ 1 500 | 1 × 1 m |
| `ph_deco_grave_vase` | Steinvase mit Blumen | ≤ 500 | – |
| `ph_deco_lantern_small` | Grablaterne am Pfahl (0,9 m) | ≤ 600 | `light_lantern` |
| `ph_deco_path_gravel`, `_02` | Kiesplatte 0,5 × 0,5 m, 2 Varianten | ≤ 150 | bündig (≤ 2 cm hoch) |
| `ph_prop_fence_iron_broken` | eingeknickter, lückenhafter Zaun mit liegenden Stäben | ≤ 1 200 | gleiches Maß wie `ph_prop_fence_iron` |
| `ph_prop_fence_passage` | offener Durchgang (2 Pfosten, Bogen) | ≤ 800 | – |
| `ph_env_bramble` | Brombeergestrüpp ~2 × 2 × 1,2 m | ≤ 2 500 | Laub-Shader (Wind) |
| `ph_prop_rubble_large` | Feldsteinhaufen ~1,5 m | ≤ 1 200 | – |
| `ph_env_stump` | Baumstumpf mit Wurzeln | ≤ 1 200 | – |
| `ph_env_hedge_thorn` | Dornenhecke 4 × 1 × 1,6 m | ≤ 3 000 | Laub-Shader |
| `ph_env_weeds_1…3` | Unkraut-Stufen (Sprossen → Büschel → Disteln/Löwenzahn wild) | ≤ 300 / 500 / 800 | Stufe 3 deutlich lesbar |
| `ph_env_leaves_1…3` | Laubstreu in 3 Mengen (Ocker/Braun, flach) | ≤ 200 / 350 / 500 | – |
| `ph_env_birch` | schlanke Birke (Identität Birkenhang) | ≤ 5 000 | Laub-Shader |
| `ph_chr_ghost` | schwebende Gestalt im Totenhemd mit Kapuze, ausfransender Saum, hält ein kleines **Seelenlicht** in den Händen; ohne Rig (Bewegung per Code/Shader) | ≤ 3 000 | `light_soul`, Pivot am Saum-Mittelpunkt |
| `ph_prop_notice_board` | Friedhofstafel am Tor | ≤ 800 | `label_board` |
| `ph_item_rake`, `ph_item_seeds`, `ph_item_iron_fittings` | Item-Modelle (Icons) | ≤ 800 | – |
| `ph_env_ground_graveyard` (neu gebaut, W-Welt) | Boden 56 × 64 m | – | – |
Shader (P4): `assets/shaders/ghost.gdshader` – `blend_mix`, `cull_disabled`, keine Schatten, Grundton blasses Graugrün `#B7C2B0` → Rand `#6FE3D2` (Fresnel), Pinselrauschen aus `painted_common.gdshaderinc`, Saum-Ausblendung nach Höhe, Saumwelle (`TIME`), Uniforms `fade`, `unrest` (Flackern, kältere Entsättigung, stärkere Welle). Vorschau-Material für den Baumodus (P2) teilt denselben Aufbau ohne Fresnel.
Deko-Icons rendert `icon_renderer.gd` (W-UI) aus den Modellen.

## 9. Performance-Budget (Phase 3, Messung wie Phase 2 mit `graveyard_shots_phase3.gd`)
| Größe | Budget | Begründung |
|---|---|---|
| FPS | 60 @ 1080p Mittelklasse-GPU | unverändert |
| Draw Calls | < 1 000 (erwartet ≤ 450 nachts voll geschmückt) | Deko ≤ 80, Hindernisse ≤ 20, Pflegestellen ≤ 34, Geister ≤ 6 |
| Kamera-Dreiecke inkl. Gras | < 500 k | Grasfläche +33 % (≈ 240 Chunks); außerhalb des Zauns `outer_density` 0,35; `visibility_range` 50 |
| Schattenwerfende Lichter | 1 Directional + ≤ 4 Omni (weiter 2) | Grablaternen und Geister **nie** mit Schatten |
| Omni-Lichter gesamt sichtbar | ≤ 24 | ≈ 8 bestehend + 6 Grablaternen + 6 Geister |
| Geister | ≤ 12 berechtigt, ≤ 6 sichtbar | transparente Überzeichnung begrenzen |
| Aufgestellte Deko | ≤ 80 (`max_placed`) | – |
| Skripte CPU/Frame (headless) | < 1,5 ms | Wachstum nur bei `hour_changed`/Zeitsprung; Geister-Auswahl 1×/s |
| Spielstand | < 200 kB, Laden < 1 s | – |
Das Raster-Overlay ist 1 Draw Call (ImmediateMesh). Die Gras-Maske (132 × 120 Texel, R8) wird nur bei Änderungen neu hochgeladen.

## 10. Tests
Regeln wie Phase 2 §9 (Framework, Fixtures statt fremder Moduldaten, Fehler-Logger, Watchdog). **Alle 735 bestehenden Tests bleiben grün** (Anpassungen nur durch den jeweiligen Besitzer, z. B. `cemetery_quality_changed` kommt jetzt von `CemeteryScore`).

**Unit**
| Datei | Besitzer | Prüft |
|---|---|---|
| `test_expansion.gd` | P1 | Kosten/Ertrag atomar, Voraussetzungen (Ostwiese frei, Birkenhang: Ostwiese + ≥ 50), Grund-Texte, Freigabe nach letztem Hindernis → Plots EMPTY + Signale + Ruf +4, Save/Load, `post_load`-Reparatur |
| `test_graveyard.gd` (+) | P1 | LOCKED zählt nicht frei, `unlock_section`, `upgrade_marker` (+2, keine Zahlung, Ruf +1), `completed_day`, `cemetery_complete`, kein `slice_complete` mehr |
| `test_corpse_manager.gd` (+) | P1 | 2 Lieferungen bei „Geschätzt", jede nur mit freier Bahre, Verrufen an geraden Tagen keine, Versäumnis-Zählung, v1-Feld `last_delivery_id` |
| `test_build_grid.gd` | P2 | Footprint-Drehung, Masken-Flags, jede Ablehnung in Prüfreihenfolge, Kies vs. Bank auf derselben Zelle |
| `test_decoration.gd` / `test_build_mode.gd` | P2 | Aufstellen/Abbauen mit Rückgabe, Limits, Abschnitts-Obergrenzen, Kies `floor(n/4)`, Unkraut-Unterdrückung, Geister-Bonus, Save/Load erzeugt Knoten neu; Baumodus: Betreten/Verlassen-Bedingungen, Cursorzelle, Spieler-Haken unterdrückt [E] |
| `test_cleanliness.gd` | P3 | Wachstum aus Minuten (3 × 1 Tag == 1 × 3 Tage), gesperrte Abschnitte/Grabzustände wachsen nicht, Pflegen + Rechen-Pflicht, Abzug, Startzustand vs. `{}`-Zustand, Save/Load |
| `test_cemetery_score.gd` / `test_cemetery_rating.gd` (+) | P3 | Formel, Klemmen ≥ 0, fünf Stufen, Signal nur bei Änderung, genau eins nach Laden |
| `test_reputation.gd` / `test_game_state.gd` (+) | P3 | Stufen, Ziel, Drift ±6, idempotent je Tag (kein Doppel-Drift nach Laden), Ereignisse, Bezahl-Bonus, Pflegegeld, `migrate_v1`-Tabelle, Label |
| `test_ghosts.gd` / `test_atmosphere.gd` (+) | P4 | Berechtigung, Zeitfenster + Blende, max. 6 nächste mit Hysterese, Stimmung/Grund-Tabelle, deterministische Zeile, Wiederholung in 60 Min, Gabe genau einmal, Save/Load; `deep_night` + Stützstellen, freigegebene Presets unverändert |
| `test_save_migration.gd` / `test_save.gd` (+) / `test_dialogue.gd` (+) | P6 | alle drei v1-Fixtures laden **ohne Fehler/Warnungen**, Ruf-Abbildung, Flags, LOCKED-Plots, Leerzustände; v2-Roundtrip identisch; Version 3 → abgelehnt; `get_slot_info` für v1; Osric: Phase-3-Einführung, Shop Eisen/Samen, Ruf-Reaktionen |
| `test_assets_phase3.gd` | P5 | alle Modelle vorhanden, Dreiecksbudgets §8, Marker (`light_lantern`, `light_soul`, `label_board`), geteilte Materialien |
| `test_ui_phase3.gd` | W-UI | Bauleiste + Grund-Texte, Ruf-Zeile + Pfeil, Tooltips, Übersichts-Panel, Tageszusammenfassung, Zielzeilen-Prioritäten, Debug-Befehle |

**Integration**
- `test_phase3_loop.gd` (W-Welt): Neues Spiel → `instant_actions` → 6 Gräber per Helfer vollenden → Ostwiese komplett räumen/reparieren → Plots 07–09 EMPTY, nächste Lieferung → Bestattung auf `plot_07` → Rechen + Bank + Beet bauen → Baumodus aufstellen → Qualität = Gräber + Zier − Pflege (exakt aus den Systemen) → 7 Tage vorspulen → Abzug steigt → pflegen → 21:30 → Geister berechtigt/aktiv mit erwarteter Stimmung → Zuhören → Gabe → **Roundtrip** `collect_state()` gleich nach `save_game`/`load_game` an 4 Momenten (während Räumung, im Baumodus, nachts mit Geistern, nach Phasenende).
- `test_phase2_save_upgrade.gd` (P6): `slot_day7_complete.json` laden → Lieferungen ruhen (kein Platz) → Ostwiese per Debug freigeben → Lieferung am nächsten Morgen → Osric spielt `p3_intro`.
- `test_graveyard_world.gd` (+, W-Welt): 12 Plots mit Abschnitten, alle Hindernisse/Pflegestellen/Systemknoten vorhanden, keine Überlappung Hindernis ↔ Station/Weg, Bau-Maske passt zum Layout, Durchgänge begehbar, Grenzen/`extra_walls`, Kamera-Grenzen.
- Playthrough-Bot (W3, QA): 7 Strategien × 14 Tage (u. a. „pflegt nie", „baut keine Zier", „nimmt alle Wertsachen", „schläft immer um 18:00") → alle erreichen `cemetery_complete` oder begründet nicht (Verrufen: langsamer), keine Softlocks, Stufe je Strategie protokolliert.
- Art-Prototyp-Regression: `test_art_prototype.gd` unverändert grün (Gras-Maske standardmäßig aus).

## 11. Screenshot-Liste Gate G3 (`graveyard_shots_phase3.gd -- --out=/abs/dir`, 1280×720 → `docs/reviews/phase3_round1/`)
| # | Motiv |
|---|---|
| p3_01 | Übersicht Tag, Start: Ostwiese und Birkenhang überwuchert, Zaunruinen, Durchgang zugewachsen |
| p3_02 | Ostwiese halb geräumt (Gras erscheint, Erdflecken), Spieler rodet |
| p3_03 | Ostwiese freigelegt: reparierter Zaun, 3 neue Grabstellen |
| p3_04 | Birkenhang freigelegt, Birken, Hecke weg |
| p3_05 | Baumodus gültig: Vorschau Bank + Raster |
| p3_06 | Baumodus ungültig: Vorschau rot + Grund in der Statuszeile |
| p3_07 | Geschmückter Friedhof am Tag (Bänke, Beete, Laternen, Kieswege) – Stufe „Ehrwürdig" |
| p3_08 | Vernachlässigt: Unkraut Stufe 1–3 + Laub (gleicher Ausschnitt wie p3_07) |
| p3_09 | Nacht 21:45: warme Grablaternen + kalte Geister, mehr Nebel |
| p3_10 | Tiefe Nacht 00:30: dieselbe Ansicht (Vergleich zu p3_09) |
| p3_11 | Geister nah: zufrieden vs. unruhig nebeneinander |
| p3_12 | Geist spricht (Sprechblase mit Hinweis) |
| p3_13 | HUD mit Ruf-Zeile + Qualitäts-Tooltip |
| p3_14 | Friedhofsübersicht (U) |
| p3_15 | Werkbank mit Zier- und Werkzeug-Rezepten |
| p3_16 | Belohnungskarte mit Ruf-Zeile + Tageszusammenfassung mit Pflegegeld |
| p3_17 | Morgens: zwei Leichen auf zwei Bahren, Osric |
| p3_18 | Friedhofstafel am Tor + Abschluss-Panel „Der Friedhof ist vollendet" |
Plus Asset-Tafeln `docs/reviews/phase3_assets/` (`asset_preview.gd --filter=…`) und Performance-Tabelle je Motiv.

## 12. Wellenplan
| Welle | Agents (parallel) | Inhalt | Ende |
|---|---|---|---|
| **W0** | Lead | Datenklassen ✦, Stubs, EventBus-Signale, Database-Ordner, Input-Map, Shader-Globals + Default-Textur, Config-Fixtures, **v1-Spielstand-Fixtures mit Build 481cb25**, leere Asset-Platzhalter-Pfade | Import + 735 Tests grün → Commit |
| **W1** | P1, P2, P3, P4, P5, P6 (oder P3+P6 zusammen = 5) | Systeme mit Unit-Tests gegen Fixtures (keine Welt nötig: Test-Welten aus `tests/fixtures/`), Assets + Asset-Tests, Migration | je Modul: Tests grün → Merge durch Lead, danach `--import` |
| **W2** | W-Welt, W-UI (2 parallel) | Layout, Boden, Builder, Bau-Maske, Szene neu bauen, Integrationstests; UI, Debug, Icons, Zielzeile | Integration + Roundtrips grün, Screenshots erstellt |
| **W3** | QA (19), Art (04), Lead | Playthrough-Bot, Save-Fuzzer (inkl. v1-Stände), Performance, Stil-/Lesbarkeitsprüfung Nacht, Befunde beheben (Besitzer), Gate-Protokoll in `QUALITY_GATE_STATUS.md` | **STOPP – Benutzerprüfung G3** |
Abhängigkeiten: W1-Agents nutzen nur Stubs/Datenklassen anderer Module; P2 und P4 lesen `CleanlinessManager`/`DecorationManager` nur über die Gruppen-API. P5 liefert zuerst `ph_chr_ghost`, `ph_env_weeds_*`, `ph_deco_*` (Blocker für W2-Screenshots).

## 13. Nicht in Phase 3
Jahreszeiten und Wetter (Laub fällt ganzjährig unter Bäumen) · Gräber wiederverwenden, exhumieren, Grabstellen verlegen · freies Platzieren ohne Raster, Mausplatzierung, Kamera drehen · Gebäude bauen (Phase 6) · Gras mähen/nachwachsen außer über die Maske · Geister-Quests, Geister-Dialogbäume, Geister als Gegner oder Helfer, Nekromantie (Phasen 13–15) · neue NPCs, Dorf, Kirche · Zaun-/Tor-Upgrades, verschließbares Tor · Kräuter- oder Blumenanbau als Wirtschaftssystem · zweites Karren-Modell / zwei Leichen auf dem Karren (Polishing) · Musik und Sound (Agent 17 inaktiv) · Controller, Lokalisierung · Änderungen an den freigegebenen Presets `day/night/dawn/dusk` und am Hütten-Innenraum.

## 14. Offene Fragen an den Benutzer (max. 4)
1. **Geistergabe:** Einmalig 2 Münzen je zufriedenem Geist – passt das, oder sollen Geister **nur** Hinweise geben (keine Belohnung)?
2. **Zwei Leichen pro Morgen ab Ruf „Geschätzt"** (zweite Bahre am Tor) – gewünscht, oder bei einer Leiche pro Tag bleiben (Phase 3 dauert dann ~14 statt ~11 Spieltage)?
3. **Bauen per Tastatur:** Die Vorschau steht auf der Rasterzelle vor der Figur (wie [E]-Interaktion). Reicht das, oder soll die Maus die Zelle wählen können?
4. **Namen:** neue Friedhofsstufe „Ehrwürdig" (ab 100) und Ruf-Stufen „Verrufen · Unauffällig · Geachtet · Geschätzt · Gerühmt"; neues Spiel startet „Unauffällig" (bisher „Geachtet", Phase-2-Stände behalten „Geachtet"). Einverstanden?
