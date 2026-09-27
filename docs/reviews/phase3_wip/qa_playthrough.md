# Phase 3 – QA-Playthrough (W3)

Bot: `tests/integration/phase3_bot.gd` · Tests: `tests/integration/test_phase3_playthrough.gd` (in der Suite, ≈ 7 s für alle Strategien).
Der Bot spielt die **echte Graveyard-Welt**: Er ruft `interact()` / `request_*()` der Entities auf (Holz/Stein sammeln, Bahre → Tisch → untersuchen → Wertsachen → Leichentuch → ausheben → bestatten → Grabzeichen, Hindernisse, Pflegestellen, Grabzeichen aufwerten, Werkbank). Zier stellt er **über den Baumodus mit dem Mauszeiger** auf (Kamera-Strahl auf die Zelle, Linksklick). Geistern hört er über den `Ghost`-Knoten zu. Geschlafen wird im Bett der Hütte. Es gilt `instant_actions`, und jeder Weg kostet pauschal 3 Spielminuten. Käufe bei Osric bilden die Dialog-Aktionen nach (Leinen und Eisen 3 Münzen, Samen 1 Münze). Der Bot spielt 14 Tage, ist also fast ein **perfekter Spieler**.

Geprüft je Strategie:
- keine Engine-Fehler und **keine Warnungen** (eigener Logger)
- Qualität 0…150, Ruf 0…100
- Ruf-Drift genau einmal je Tag (`rep_last_day` = heute, kein Doppel-Drift)
- keine Bot-Probleme (kein freies Grab, kein Grabzeichen, Baumodus abgelehnt, kein Geist …)

## Strategien

| Strategie | Verhalten |
|---|---|
| diligent | pflegt, untersucht, Leichentuch, Grabstein, räumt beide Abschnitte, Zier (Vase je Grab, 2 Laternen und 1 Bank je Abschnitt), hört Geistern zu, wertet Grabzeichen auf |
| neglectful | wie diligent, pflegt aber **nie** (Gate-Ziel „Würdevoll auch bei nachlässiger Pflege“) |
| sloppy | pflegt nie, **nimmt alle Wertsachen**, keine Zier, hört nicht zu |
| hoarder | räumt alles und pflegt, aber **keine Zier** |
| save_load | wie diligent, lädt **jeden Morgen den Autosave** (Schlaf → Slot 0 → laden) |
| early_sleeper | wie diligent, schläft aber um 18:00 und hört nicht zu |

## Ergebnis (14 Tage)

| Strategie | 12 Gräber | Ostwiese / Birkenhang | Qualität max (Tag 14) | „Würdevoll“ ab | „Ehrwürdig“ ab | Ruf Tag 7 / 14 | Münzen Ende | Einnahmen / Ausgaben / Geistergaben |
|---|---|---|---|---|---|---|---|---|
| diligent | Tag 12 | T4 / T6 | 144 (144) | T5 | T9 | 61 / 97 Gerühmt | 58 | 172 / 119 / 24 |
| save_load | Tag 12 | T4 / T6 | 144 (144) | T5 | T9 | 61 / 97 | 58 | **identisch zu diligent** |
| early_sleeper | Tag 12 | T6 / T7 | 144 (144) | T5 | T9 | 61 / 97 | 32 | 146 / 119 / 0 |
| hoarder | Tag 12 | T5 / T7 | 114 (114) | T6 | T11 | 57 / 85 | 52 | 140 / 93 / 0 |
| neglectful | Tag 12 | T5 / T6 | 105 (92) | T6 | T12 (T12–13) | 55 / 79 | 48 | 162 / 119 / 24 |
| sloppy | – (9) | T3 / – | 40 (24) | nie | nie | 27 / 36 | 50 | 76 / 66 / 0 |

### diligent (Tag für Tag)
| Tag | Gräber | Q Gräber | Zier | Pflege | Qualität | Stufe | Ruf | Ruf-Stufe | Münzen | Ost | Nord |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 9 | 0 | −0 | 9 | Verwahrlost | 26 | Unauffällig | 12 | – | – |
| 2 | 2 | 19 | 5 | −0 | 24 | Ordentlich | 31 | Unauffällig | 7 | – | – |
| 3 | 3 | 28 | 5 | −0 | 33 | Gepflegt | 35 | Geachtet | 12 | – | – |
| 4 | 4 | 38 | 5 | −0 | 43 | Gepflegt | 43 | Geachtet | 10 | ✓ | – |
| 5 | 5 | 48 | 5 | −0 | 53 | Würdevoll | 47 | Geachtet | 11 | ✓ | – |
| 6 | 6 | 57 | 8 | −0 | 65 | Würdevoll | 55 | Geschätzt | 13 | ✓ | ✓ |
| 7 | 7 | 67 | 17 | −0 | 84 | Würdevoll | 61 | Geschätzt | 16 | ✓ | ✓ |
| 8 | 8 | 76 | 20 | −0 | 96 | Würdevoll | 68 | Geschätzt | 21 | ✓ | ✓ |
| 9 | 9 | 86 | 20 | −0 | 106 | Ehrwürdig | 75 | Geschätzt | 30 | ✓ | ✓ |
| 10 | 10 | 96 | 26 | −0 | 122 | Ehrwürdig | 82 | Gerühmt | 38 | ✓ | ✓ |
| 11 | 11 | 105 | 29 | −0 | 134 | Ehrwürdig | 89 | Gerühmt | 45 | ✓ | ✓ |
| 12 | 12 | 114 | 29 | −0 | 143 | Ehrwürdig | 94 | Gerühmt | 56 | ✓ | ✓ |
| 13 | 12 | 114 | 30 | −0 | 144 | Ehrwürdig | 96 | Gerühmt | 56 | ✓ | ✓ |
| 14 | 12 | 114 | 30 | −0 | 144 | Ehrwürdig | 97 | Gerühmt | 58 | ✓ | ✓ |

### neglectful (pflegt nie)
| Tag | Gräber | Q Gräber | Zier | Pflege | Qualität | Stufe | Ruf | Ruf-Stufe | Münzen | Ost | Nord |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 9 | 0 | −3 | 6 | Verwahrlost | 26 | Unauffällig | 12 | – | – |
| 3 | 3 | 28 | 5 | −8 | 25 | Ordentlich | 33 | Unauffällig | 11 | – | – |
| 5 | 5 | 48 | 8 | −13 | 43 | Gepflegt | 45 | Geachtet | 12 | ✓ | – |
| 6 | 6 | 57 | 8 | −15 | 50 | Würdevoll | 51 | Geachtet | 10 | ✓ | ✓ |
| 8 | 8 | 76 | 20 | −23 | 73 | Würdevoll | 59 | Geschätzt | 17 | ✓ | ✓ |
| 10 | 10 | 96 | 26 | −25 | 97 | Würdevoll | 70 | Geschätzt | 33 | ✓ | ✓ |
| 12 | 12 | 114 | 29 | −38 | 105 | Ehrwürdig | 79 | Geschätzt | 47 | ✓ | ✓ |
| 13 | 12 | 114 | 30 | −44 | 100 | Ehrwürdig | 80 | Gerühmt | 47 | ✓ | ✓ |
| 14 | 12 | 114 | 30 | −52 | 92 | Würdevoll | 79 | Geschätzt | 48 | ✓ | ✓ |

### sloppy (pflegt nie, nimmt Wertsachen, keine Zier)
| Tag | Gräber | Q Gräber | Zier | Pflege | Qualität | Stufe | Ruf | Ruf-Stufe | Münzen | Ost | Nord |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 9 | 0 | −3 | 6 | Verwahrlost | 26 | Unauffällig | 10 | – | – |
| 3 | 3 | 23 | 0 | −8 | 15 | Ordentlich | 28 | Unauffällig | 7 | ✓ | – |
| 5 | 5 | 37 | 0 | −13 | 24 | Ordentlich | 22 | Unauffällig | 17 | ✓ | – |
| 7 | 7 | 53 | 0 | −18 | 35 | Gepflegt | 27 | Unauffällig | 29 | ✓ | – |
| 9 | 9 | 69 | 0 | −29 | 40 | Gepflegt | 32 | Unauffällig | 40 | ✓ | – |
| 11 | 9 | 69 | 0 | −33 | 36 | Gepflegt | 38 | Geachtet | 44 | ✓ | – |
| 14 | 9 | 69 | 0 | −45 | 24 | Ordentlich | 36 | Geachtet | 50 | ✓ | – |

## Abgleich mit dem Vertrag (§1.3, §2.5, §2.6)

- **Phasenziel ≈ Tag 14:** Der perfekte Bot erreicht es an **Tag 12**. Das Tempo bestimmt allein „1 Leiche pro Tag“ (§14.2). Ein menschlicher Spieler mit echten Wegen, abgebrochenen Aktionen und verpassten Morgen landet realistisch bei 13–15. ✓
- **„Ehrwürdig“ erreichbar:** ✓ ab Tag 9 (diligent). **„Würdevoll“ bei nachlässiger Pflege:** ✓ (neglectful ab Tag 6, und er hält es bis Tag 14).
- **Ruf-Kurve:** Vertrag T4 38 · T7 56 · T10 ≈ 68 · Ende 75–82. Der Bot liegt bei T4 43 · T7 61 · T10 82 · Ende 97, also etwa 5 Punkte früh bis T7. Danach ist er deutlich höher, weil seine Friedhofsqualität 144 statt der erwarteten ≈ 125 ist: Er ist fehlerlos, jedes Grab hat 9–10 Punkte, Gräber gesamt 114 statt „realistisch 95–105“. Das Ziel ist auf 100 geklemmt, der Ruf nähert sich also 100.
- **Münzen:** Einnahmen 172 statt ≈ 150 (Bestattungen ≈ 11,5 je Grab mit Ruf-Bonus, Pflegegeld, 24 Geistergaben). Ausgaben 119 statt 110–130. Am Tag 14 bleiben **58 Münzen** übrig. Das liegt im Rahmen des Vertrags, aber am oberen Rand.
- **Freilegen:** Ostwiese an Tag 4–5 (Vertrag 5–6), Birkenhang an Tag 6–7 (Vertrag 9–13). Früher als geplant, weil Qualität 50 schon an Tag 5 erreicht ist. Unschädlich: Der Platz wird erst ab Grab 10 gebraucht.
- **Verpasste Lieferungen:** 0 in allen Strategien (der Bot räumt die Bahre jeden Morgen).
- **Speichern/Laden jeden Tag:** Die Zahlen sind **bitgleich** zu diligent. Es gibt keinen Doppel-Drift, kein doppeltes Pflegegeld und keine doppelten Gaben.

## Balancing – keine Datenänderung (Empfehlung für G3)

Nichts weicht „klar“ vom Vertrag ab, deshalb sind die Werte **unverändert**. Die Spielwerte prüft laut Vertrag der Benutzer beim Gate G3. Zwei Beobachtungen für die Freigabe:

1. **„Ehrwürdig“ ohne Zier oder ohne Pflege.** §2.5 sagt: „100 verlangt ≥ 10 gute Gräber **plus** Zier **und** Pflege“. Der perfekte Spieler schafft es aber auch ohne eines davon:
   - hoarder ohne Zier: 114
   - neglectful ohne Pflege: 105 an Tag 12, danach sinkt der Wert (92 an Tag 14), der Spieler kann ihn also nicht halten

   Das gilt nur bei Gräbern mit 9,5 Punkten im Schnitt. Soll 100 wirklich beides verlangen, gibt es zwei Stellschrauben:
   - Schwelle `rating_thresholds[3]` auf 110 setzen
   - `penalty_by_level` auf [0, 0, 1, 3] setzen
2. **Münzüberschuss.** Nach der Vollendung fließen täglich 4 Pflegegeld, und es gibt nichts mehr zu kaufen. Das hängt mit GP-03 zusammen: Ab Phase 4 sollte es eine Münzsenke geben.

## Befunde aus dem Review (Stand vs/p3-qa)

Jeder Befund hat zuerst einen fehlschlagenden Test bekommen und wurde dann behoben. Die Tests stehen in `tests/integration/test_phase3_qa.gd` (QA-01 … QA-06, QA-11) und `tests/integration/test_save_fuzzer.gd` (QA-07 … QA-10).

| # | Schwere | Befund | Behoben | Test |
|---|---|---|---|---|
| QA-01 | mittel | Tageszusammenfassung (Bett) und Grabregister (Pult) zeigten die Qualität **nur der Gräber** statt der Friedhofsqualität (Zier, Pflege fehlten) | ja: `CemeteryScore` | `test_bed_day_summary_reports_cemetery_quality`, `test_desk_register_reports_cemetery_quality` |
| QA-02 | klein | Grabregister ohne Spalte „Stimmung“ (§7) | ja: Spalte, nur nach dem Zuhören | `test_register_mood_after_listening` |
| QA-03 | klein | Debug `tp east/north` landete auf der gesperrten Grabstelle bzw. im Gestrüpp | ja: Wegpunkte `tp_east` / `tp_north` | `test_debug_tp_uses_section_waypoints` |
| QA-04 | klein | Ein Grab, das nach 21:00 vollendet wurde: Nach Speichern + Laden erschien sein Geist **noch in derselben Nacht** (`_late` wurde nicht gespeichert) | ja: `late` wird gespeichert, solange es gilt (Format abwärtskompatibel) | `test_late_grave_ghost_survives_load` |
| QA-05 | mittel (Softlock) | Abschnitt mit allen Hindernissen geräumt, aber gesperrt (inkonsistenter oder älterer Stand), ließ sich **nie** freilegen | ja: `post_load` legt ihn frei (mit Warnung) | `test_all_cleared_section_unlocks_on_load` |
| QA-06 | mittel | Zier auf Unkraut: Kies/Beet „unterdrückten“ nur das Wachstum. Das Unkraut stand sichtbar im Kies und kostete weiter Abzug. Bänke und Laternen ließen sich mitten auf Pflegestellen stellen (Unkraut wächst durch die Bank) | ja: abgedeckte Stellen zählen und zeigen Stufe 0 (Fortschritt bleibt). Deko mit Kollision → Grund „Hier wächst Unkraut – nur Kies oder Beet“ | `test_gravel_over_weeds_covers_them`, `test_bench_refused_on_weeds` |
| QA-07 | mittel | Beschädigter Spielstand: `JSON.to_native` erzeugte Engine-Fehler (Rohzahlen, fremde Typen, kaputte Container). Das Laden schlug zwar fehl, aber nicht sauber | ja: `SaveFileIO.is_native_json` prüft vor dem Dekodieren → „Spielstand ist beschädigt.“ | Fuzzer |
| QA-08 | klein | Ein Stand ohne Zustand eines Rohstoffhaufens blieb für den Tag leer, beim nächsten Laden war er voll (Laden ≠ Laden) | ja: `ResourceNode.post_load` | Fuzzer (Stabilität) |
| QA-09 | klein | Ruf außerhalb 0…100 aus einem beschädigten Stand wurde übernommen | ja: `Reputation.value()` klemmt, `game_loaded` repariert | Fuzzer |
| QA-10 | klein | Skriptfehler bei beschädigten Werten: `TimeManager.load_state` (`int()` auf Nicht-Zahl), `%`-Formatierung mit Array-Schlüsseln (SaveStateCollector, GameState), Überlauf in `DecorationManager._uid_num` | ja | Fuzzer |
| QA-11 | mittel (Lesbarkeit) | Unkraut/Laub aus der Spielkamera kaum sichtbar | ja: Assets + Gras-Maske (siehe unten) | `test_weedy_spot_clears_the_grass_under_it`, `qa_weeds_before_after.jpg` |

Außerdem geprüft, ohne Befund:
- v1-Migration (3 Fixtures und gefuzzte Varianten)
- Ruf-Drift genau einmal je Tag, auch mit Laden jeden Tag
- Pflegegeld und Geistergaben nicht duplizierbar; Gabe genau einmal je Grab, auch nach Laden
- 1 Lieferung je Tag; „Verrufen“ nur an ungeraden Tagen; Versäumnis nur bei belegter Bahre, einmal je Tag
- Zeitsprünge über 21:30, 04:30 und Mitternacht; Wachstum aus Minuten
- LOCKED-Plots: nie frei, kein Prompt
- Baumodus: Wege und Stationszugänge sind ROUTE; Kutscher-Route frei; Zaunlücken haben schon vor der Reparatur Kollision, der Spieler kann also nicht im Zaun eingeschlossen werden; Deko ist mit Baumodus bis 8 m immer wieder abbaubar
- Kein Rückgabe-Kreislauf: Abbauen gibt nur 1 Stück zurück, es gibt keinen Verkauf
- 14 Tage × 6 Strategien ohne eine Warnung

## Save-Fuzzer (`test_save_fuzzer.gd`)

Gefuzzt werden ein echter v2-Stand eines Phase-3-Spiels (Zier, geräumte Hindernisse, Geister gehört, 2 Bot-Tage) und die drei v1-Fixtures. Je Stand:
- 16 abgeschnittene Dateien
- 70 Mutationen auf JSON-Ebene (auch innerhalb der `from_native`-Hülle)
- 90 Mutationen auf Zustandsebene (Werte ersetzen oder löschen, neu kodiert)
- Version und Meta separat

Erlaubt sind nur zwei Ausgänge:
1. Laden schlägt fehl mit „Spielstand ist beschädigt.“ oder „… neueren Version.“, und `collect_state()` ist **unverändert** (nichts halb angewendet, `is_loading` wieder falsch).
2. Laden gelingt, Ruf liegt in 0…100, Qualität ≥ 0, und Speichern → Laden ergibt denselben Zustand.

Es gibt keine Engine-Fehler. Ein zusätzlicher Lauf mit Seed 777 (300/600 Mutationen, ≈ 3500 Ladevorgänge) fand QA-09 und QA-10. Beide sind behoben.

## Unkraut/Laub-Lesbarkeit (`qa_weeds_before_after.jpg`)

Ansicht aus der Spielkamera (Abstand 18, 12:00, Ostwiese). Stil bleibt gesperrt: gleiche Materialien, gemalte Vertex-Farben.

- **Stufe 1:** helle, gelbgrüne Sprossen-Rosetten und wenig Erde
- **Stufe 2:** 1,1× so groß, dunkle Rosetten, Strohähren auf blanker Erde
- **Stufe 3:** 1,15× so groß, Rost-Ampfer auf zertretener Erde
- **Laub:** größere Blätter, Ocker/Rost, Haufen ab Stufe 2, Moder-Fleck bei Stufe 3
- **Vertauschte Windung:** Die flachen Rosetten (vorher `mat_grass`, beidseitig) sind jetzt `mat_painted`, die Windung zeigt nach oben.
- **Gras-Maske:** Unter einer Pflegestelle ab Stufe 1 blendet `GrassClearMask` das Gras aus (0,45 / 0,7 / 1,0 m). Die flachen Teile lagen vorher unter den Grasbüscheln. Nach dem Pflegen wächst das Gras wieder.

Dreiecke: 254 / 339 / 799 (Budget 300 / 500 / 800) und 160 / 336 / 454 (200 / 350 / 500).

## Screenshot-Satz Gate G3 (`docs/reviews/phase3_round1/`, 1280×720, echte Phase-3-Welt)

Weltaufnahmen stammen aus `graveyard_shots_phase3.gd --jpg` (neu: `world_11`/`world_12`). UI-Aufnahmen stammen aus `ui_screenshots.gd --phase3`; der Regisseur läuft jetzt auf der **echten** Welt, alles wird über die System-APIs aufgebaut.

| Datei | Motiv (§11) |
|---|---|
| p3_01_overview_day | Übersicht Tag, Start (Ostwiese / Birkenhang überwuchert) |
| p3_02_east_uncleared / p3_03_east_cleared | Ostwiese vorher / freigelegt |
| p3_04_birkenhang | Birkenhang freigelegt |
| p3_05_build_valid / p3_06_build_invalid | Baumodus mit Mauszeiger: gültig / „Zu nah am Grab“ |
| p3_07_decorated_day / p3_08_neglected_day | geschmückt / vernachlässigt (gleicher Ausschnitt) |
| p3_09_night_ghosts / p3_10_deep_night_ghosts | 22:15 / 00:30 |
| p3_11_ghosts_moods_close | zufrieden (Seelenlicht hoch) · gleichmütig · unruhig nebeneinander |
| p3_12_ghost_speaks | Sprechblase mit Hinweis („Mir ist kalt …“) |
| p3_13a / p3_13b | HUD mit Ruf-Zeile + Qualitäts- / Ruf-Tooltip |
| p3_14_cemetery_overview | Friedhofsübersicht (U) |
| p3_15_workbench | Werkbank, Gruppen Grab / Zier / Werkzeug |
| p3_16a_reward_card / p3_16b_day_summary | Belohnungskarte mit Ruf-Zeilen / Tageszusammenfassung (Hütte) |
| p3_17_osric_phase3_intro | Osric, Phase-3-Einführung |
| p3_18a_notice_board / p3_18b_cemetery_complete | Friedhofstafel / „Der Friedhof ist vollendet“ |
| p3_19_overview_end | Übersicht Phasenende |

`render_stats.txt` enthält Dreiecke, Draw Calls und Lichter je Motiv:
- Beim Spielzoom (Abstand ≤ 24) höchstens 453 k Kamera-Dreiecke inklusive Gras (Budget 500 k).
- Die Übersichten mit Abstand 30–40 liegen außerhalb des Spielzooms und erreichen bis zu 566 k.
- Draw Calls höchstens 346 (Budget 1 000).
