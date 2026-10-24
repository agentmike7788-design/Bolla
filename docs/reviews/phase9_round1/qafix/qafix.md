# Phase 9 – W3 QA-Fix (Befunde aus `docs/reviews/phase9_wip/qa_g9.md`)

Branch `vs/p9-qafix` (von `claude/last-gravekeeper-dev-aos21h` 86b5a2d). Lead-Vollmacht für alle Besitzer. Nicht geändert: Münzwerte, Kapitelzeitpunkt, HillBot-Werte (Benutzerentscheidung 18.10.2026: angenommen, siehe unten). Vertrag nachgetragen: `docs/PHASE9_DESIGN.md` Abschnitt „W3 QA-Fix“ und „G9 – Benutzerentscheidungen“ 3/4.

Bilder: echter Renderer, Forward+ (Vulkan lavapipe) und `_web` (Compatibility, OpenGL 3), 1280 × 720 (Merkbuch auch 1920 × 1080). `…_vorher` = Stand 86b5a2d, `…_nachher` = dieser Zweig.

## Neu: die kurze Auswahl `&"action_choice"`

`src/ui/panels/action_choice_panel.gd` (`ActionChoicePanel`): Kontext `{title, question?, options [{id, label, reason?}], target, method = request_action, player}`. Knöpfe in der gegebenen Reihenfolge, der erste freie hat den Fokus (die Hauptaktion des Ortes, Enter genügt), gedimmte Wahl nennt ihren Grund, „Abbrechen“. Die Wahl schließt das Panel und ruft `target.request_action(id)`; der Ort startet seine eigene TimedAction. Keine Zahlen. Der Phase9Bot beantwortet die Auswahl wie der Knopf (`_on_choice_panel` → `request_action`, wie `request_marker` bei der Grabzeichen-Wahl).

## Hoch

| ID | Befund | Behoben | Nachweis |
|---|---|---|---|
| QA9-01 | Esse: [E] verbrannte den ersten Brief | `ForgeLetter` hat keinen eigenen Prompt/Interactable mehr – [E] bleibt die Esse (Werkbank-Panel). Dort steht „Brief verbrennen …“ (nur mit einem Brief, der an der Esse brennen darf) → Auswahl je Brief („Verbrennen: <Aufschrift> (2 Min)“), es brennt nur der gewählte. Gemeinsame Regel `LetterBurning` (Ofen + Esse). | `test_letters_flow::test_forge_stays_the_forge_and_burns_only_the_chosen_letter`, `test_action_choice_panel::test_crafting_panel_letter_button_at_the_forge`, `test_graveyard_world` (ForgeLetter ohne Interactable) |
| QA9-02 | Leiche + ihr Brief im Beutel: [E] = „Brief mit ins Grab legen“ | Prompt „[E] Bestatten (n Min) …“ → Auswahl „Bestatten“ (Fokus) oder „Den Brief mit ins Grab legen und bestatten“ (eine Bestattung, + 2 Min; Brief `bury` mit `burying`). „Bestatten“ lässt den Brief im Beutel. Der Truhen-Umweg im Bot ist entfallen. | `test_letters_flow::test_lay_the_letter_into_the_open_grave_of_its_sender`, `::test_bury_without_the_letter_keeps_it` |

## Mittel

| ID | Befund | Behoben | Nachweis |
|---|---|---|---|
| QA9-03 | Ofen verbrannte den ersten Brief, „Wärmen“ unerreichbar | Ohne Brief wie bisher „[E] Am Ofen wärmen“. Mit Brief „[E] Am Ofen: wärmen oder einen Brief verbrennen“ → „Am Ofen wärmen“ zuerst, dann je Brief eine Zeile; nur der gewählte brennt. | `test_letters_flow::test_stove_burns_only_the_chosen_letter_and_still_warms`, `test_phase9_loop` |
| QA9-04 | Pflege verdeckte „Brief am Grab vorlesen“ / die Kerze | Steht eine Phase-9-Arbeit (Datum, Vorlesen, Aufs-Grab-Legen, Erde) neben einer anderen Aktion, zeigt das Grab „[E] Am Grab: Datum vergleichen, Grabblumen setzen, …“ und [E] öffnet die Auswahl mit **allen** möglichen Aktionen (Münzen / Schließen, dann Phase 9, dann die Pflege in `care_order`). Ohne Phase-9-Arbeit bleibt das Grab beim einen Tastendruck (Phase 3–8 und HillBot bitgleich). | `test_letters_flow::test_grave_choice_reaches_the_letter_and_the_care`, `test_p9_fixes_grave::test_compare_the_date_before_the_flowers`, Bilder `qa9_04_*` |
| QA9-F2 | Nicht-bool in `hill_requests.parts.<id>[n]` → Script-Fehler, halb geladen | `flags[i] is bool and bool(flags[i])` beim Laden und in `parts_done`. Fuzzer: Ausnahme entfernt (die Pfade werden mitgefuzzt) + gezielter Fall 14 (int, String, null, float). | `test_save_fuzzer` (109 geladen, 21 abgewiesen, keine Ausnahme mehr) |
| QA9-T1 | trader9 ohne Kapitel | **Inhaltsfehler** in `data/dialogue/carter.tres`: Der hartherzige Totengräber (Anatom, Pietät −45 …) bekommt Osrics kühles Menü `menu_cold` – dort fehlten alle Phase-8/9-Zeilen (Post für Gesas Botengang und Briefe in die Stadt, die große Bitte, die Liste, die Wundarzt-Kiste). Jetzt hat `menu_cold` dieselben Zeilen wie `menu`; das Gespräch nach „Bahre war belegt“ führt wie vorher über `remark_rep` … zum Menü. | `test_p9_qafix::test_qa9_t1_osrics_cold_menu_keeps_the_phase8_9_lines`, Playthrough trader9 (siehe Suite) |
| A9-1 | Veit und Brenneisen ineinander | `stranger_gate` 0,8 m vom Zaun weg: (0,1 \| 11,3) → (0,1 \| 12,1); `graveyard.tscn` neu gebaut. Brenneisen steht jetzt vor Veits ausgestreckten Beinen, nicht darin. | `test_graveyard_world::test_phase9_gate_places_and_prompts` (≥ 1 m von Veits Füßen), Bilder `a9_1_*` |
| A9-2 | Krug: Brenneisen überlappt eine Figur | Er sitzt auf dem Sitzmarker `seat_2` der Nordbank (`v_in_inn_stranger`, `sit_inn`), unverändert. Die zweite Figur war Lenz (abends 18:10–20:00) bzw. morgens Osric auf `v_in_inn_corner` – 0,25 m hinter seinem Platz. `v_in_inn_corner` steht jetzt am Westende des Ecktischs (2,1 \| 1,3, Blick nach Osten, 1,1 m von ihm); `inn_interior.tscn` neu gebaut. | `test_interiors::test_phase9_inn_stranger_table_and_cellar` (≥ 0,9 m zu Ecke, Tisch, Schank), Bilder `a9_2_*` |

## Klein

| ID | Befund | Behoben | Nachweis |
|---|---|---|---|
| QA9-05 | Osrics Zeile „für die große Bitte“ nie sichtbar | `HillRequests.small_ready_for` / `large_ready_for`; Bedingung `hill_ready` zählt nur kleine Bitten, die große Zeile braucht nur `large_ready:carter`. Übergabe weiter über `turn_in`. HillBot prüft beide Bedingungen (gleiches Verhalten). | `test_hill_requests::test_large_craft_at_the_workbench_and_osric_takes_it` (die große Zeile sichtbar, die kleine nicht) |
| QA9-08 | Botenbrief nach versäumtem Auftrag noch aufgebbar | `Letters.errand_late` (Auftrag `failed`): `post_block_reason`, die Brief-Karte und `ask_postage` sperren mit „Dafür ist es zu spät. Der Auftrag ist verstrichen – der Brief käme nicht mehr rechtzeitig an.“ Der Brief bleibt lesbar im Beutel. | `test_letters_flow::test_errand_letter_after_the_missed_order_stays` |
| QA9-F1 | D3 bei `sieber_gone` (kaputter Stand) bleibt | `WhoKnows.post_load`: Der D3-Record gewinnt (die Leiche liegt in der Welt), `sieber_gone` wird mit Warnung gelöscht. Fuzzer prüft es jetzt scharf. | `test_save_fuzzer` (`_check_phase9`) |
| QA9-09 | `phase8_bot._copy_extract` mit `_craft5(&"workbench")` | Beide Stellen (Auszug, Zeile nachmeißeln) machen die Tinte an der Hügel-Werkbank (`_craft`, wie Phase9Bot), vorher zurück auf den Hügel. | `test_p9_qafix::test_qa9_09_phase8_bot_has_no_station_workbench_call` |
| A9-5 | Johanns Gesicht fleckig | `tools/blender/asset_mourners.py` (lib_faces unverändert): Stoppeln heller und ohne Sprenkel (die Vertex-Farben des Kopfes sind dafür zu grob), weniger auf der Oberlippe (`stubble` mit Parametern, Standardwerte = bisher, der Nachtwächter bleibt gleich); `age` 0,75 → 0,55 (weniger hohle Wangen); Hut schmaler und weniger hängend (Krempe 0,085 → 0,07, slouch 0,05 → 0,02) – sein Schatten lag über dem Gesicht. Nur `ph_chr_mourner_m_b.glb` neu (deterministisch). | Bilder `a9_5_gesichter_*` (zweite Kachel) |
| A9-6 | Schild „Große Bitte“ schwebt über dem Zettel | Zweizeilig, kleiner (22 statt 30), auf dem Bogen zwischen Nadel und Falz. | `test_p9_qafix::test_a9_6_large_sheet_word_on_the_sheet`, Bilder `a9_6_*` |
| A9-7 | Merkbuch: rechts ≈ 110 px leer | Die beiden Seiten teilen sich die ganze Buchbreite (`SIZE_EXPAND_FILL`, mindestens `page_width`). | `test_ui_phase9::test_qafix_a9_7_pages_fill_the_book_with_eleven_tabs` (1280 × 720 und 1920 × 1080), Bilder `a9_7_*` |
| A9-8 | Compatibility: Leiche auf der Bahre schwarz | Nachgestellt (`--rendering-method gl_compatibility --rendering-driver opengl3`, v7-Stand, Lieferung Tag 63, Tag 65): schwarz ist das Verwesungs-Overlay. Sonde: ein `blend_mul`-Pass mit `ALBEDO = 1` ist im Compatibility-Renderer schwarz, sobald die Umgebung ihren Post-Process-Weg nimmt (Glow / Adjustments der Friedhofs-Umgebung); ohne Glow/Adjustments richtig. Behoben in `assets/shaders/decay_overlay.gdshader`: im Compatibility-Zweig ein beleuchteter `blend_mix`-Pass mit dem gemalten `light()` – Fleckfarbe über dem Körper, Anteil als Alpha (Basis × (1 − m) + Fleck × m, wie die Multiplikation). Forward+ unverändert. | `test_p9_qafix::test_a9_8_…`, `test_decay_visual`, Bilder `a9_8_*` (Forward+ unverändert, `_web` vorher schwarz / nachher grau-grün) |

## Benutzerentscheidungen 18.10.2026

- **QA9-07 umgesetzt:** Die Frist der Hauptkette (Licht + 17 → „still“, Johanns Licht und Tod) läuft erst nach Lorenz' Kladde. Der Lichttag wird beim Lesen festgelegt: Lesetag − 12 (`LightRules.reading_light_day`, nie vor `p9_open_day`). Begründung: So liegt das Licht immer in der Vergangenheit, die sechs Daten der Liste (fünf Tote, ein offener Eintrag) bleiben untereinander stimmig, und die Frist lässt nach dem Lesen dieselben fünf Tage wie bisher. Wer am Eröffnungstag liest, hat exakt den alten Ablauf. Vor dem Lesen gibt es keinen Lichttag, keine Frist, keinen Nachtweg `np_sieber`. Tests: `test_who_knows::test_qa9_07_*`, `test_who_knows_endings`, Playthrough lazy9 (Kette wartet bei H1, kein „still“, kein Tod).
  - Offen: Ein Spielstand, der *vor* diesem Zweig nach `p9_open` gespeichert wurde, hat `q_light_day` schon ab dem Eröffnungsmorgen; er behält seine alte Frist (keine Migration – ein gültiger neuer Stand hat den Lichttag nie ohne Kladde).
- **Angenommen:** Münzen +55 … +64 (Band ≥ +40, ≤ +70 geprüft), Kapitel bei etwa B7 (kindly9 B7–B11), HillBot Pflicht 1887 min (Wächter 1900). Kommentar „Benutzerentscheidung 18.10.2026“ in den Tests.

## Fixture

`docs/reviews/phase9_wip/slot_p9_mid_h4.json` → `tests/fixtures/saves_v8/slot_p9_mid_h4.json`; `test_phase9_qa` lädt jetzt diese Fixture (Stand erhalten, Speichern → Laden gleich, `QuestLog.entries` ≤ 4 ms).

## Bilder (dieser Ordner)

- `qa9_04_grab_prompt_{vorher,nachher}[_web]`, `qa9_04_grab_auswahl_nachher[_web]` – Marthe Quendels Grab mit Setzlingen, Kranz, Strohblumen: vorher verdeckte die Pflege das Datum, nachher nennt der Prompt die Auswahl und [E] öffnet sie.
- `a9_1_tor_veit_brenneisen_*`, `a9_1_tor_spiel_*` · `a9_2_krug_ecktisch_*` · `a9_5_gesichter_*` · `a9_6_torafel_bogen_*` · `a9_7_merkbuch_{1280,1920}_*` · `a9_8_leiche_bahre_*`.
