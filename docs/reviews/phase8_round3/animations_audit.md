# G8 Runde 3 – Animations-Audit (Nachbesserung „annimationen fehlen“ / „die leichen preperation annimation fehlen auch“)

Befund: Alle Aktionen am Leichentisch liefen mit `const ANIM := &"interact"` – einer 0,8-s-Greifbewegung, die sich wiederholt. Dasselbe galt für viele andere zeitgesteuerte Aktionen (`Player.start_timed_action`). Geprüft wurden alle Aufrufer von `start_timed_action` in `src/` (Stand e23b6ae), die Daten mit `animation =` in `data/` und die Tagespläne aller NPCs gegen die Clips ihrer Modelle (Skript im Scratch-Ordner: jeder `ScheduleEntry.animation` gegen den `AnimationPlayer` des Modells).

Neue Verdrahtung: `ToolAnimConfig.clip_for(<Schlüssel>, Rückfall)` mit den Schlüsseln in `data/config/tool_anim_config.tres` (`action_clips`); die Tisch-Aktionen über `MorgueTable._start_work` mit dem Schlüssel `morgue_<aktion>`. Nichts ist mehr hart im Code; ein fehlender Schlüssel fällt auf den bisherigen Clip zurück.

## 1. Leichentisch (Gruft-Tisch, alter Tisch vor der Hütte)

Der Totengräber tritt zu Beginn jeder Tisch-Aktion in 0,3 s an seinen Arbeitsplatz (`MorgueTable.work_stand`, Werte `table_stand_*`): an die Längsseite, die von der Kamera abgewandt ist (er arbeitet zum Betrachter hin), 0,76 m von der Mittellinie (Kapsel frei vom Tisch-Collider, die Figur lehnt sich 5,5 cm hinein); Kopfarbeiten (Kämmen, Zopf, Zähne) am Kopfende auf der Tischachse. Kleine Werkzeuge kommen aus der Werkzeugtasche an der rechten Hüfte (`hand_draw`, sichtbar ab 36 %) und gehen zurück (`hand_stow` / `hand_stow_walk`) – dieselbe Mechanik wie Axt, Hammer, Säge (ToolAnimConfig `held_tools`, `draw_clips`, `draw_show_at` …); die Werkzeuge sind eigene `ph_tool_*.glb` am neuen Marker `tool_hand` des `tool`-Knochens (`tool_scenes`), weil der Körper mit 11 946 Dreiecken am 12 000er-Budget steht.

| Aktion (Panel) | Schlüssel | bisher | neu | Werkzeug | Arbeitsgeräusch |
|---|---|---|---|---|---|
| Untersuchen (Phase-2-Panel) | `morgue_examine` | interact | `table_examine` (über die Leiche gebeugt, linke Hand liegt auf, rechte tastet sich entlang, der Kopf folgt) | – | `cloth` (Stichwort „untersuch“, Takt) |
| Gründlich untersuchen | `morgue_exam_all` | interact | `table_examine` | – | `cloth` |
| Hände & Arme ansehen | `morgue_exam_hands` | interact | `table_examine` | – | `cloth` |
| Wunden & Haut prüfen | `morgue_exam_wounds` | interact | `table_examine` | – | `cloth` |
| Kleidung durchsehen | `morgue_exam_clothing` | interact | `table_search` (beide Hände wenden Säume, im Wechsel) | – | `cloth` |
| Taschen & Säume durchsuchen | `morgue_exam_pockets` | interact | `table_search` | – | `cloth` |
| Waschen | `morgue_wash` | interact | `table_wash` (nasses Tuch in langem Strich am Körper entlang, linke Hand stützt) | `ph_tool_washcloth` | `wash` im Strich (`bite_at` 0,2; Clip 1,4 s = Takt des Cues) |
| Leichentuch anlegen | `morgue_dress_shroud` | interact | `table_shroud` (Leinen zwischen beiden Fäusten: anheben, über den Körper werfen, ablegen, glattstreichen) | `ph_tool_linen` (zweihändig, linke Faust gleitet an der Kante) | `cloth` |
| Totenhemd anziehen | `morgue_dress_gown` | interact | `table_shroud` | `ph_tool_linen` | `cloth` |
| Aufbahren (Kamm, `lay_out_tool`) | `morgue_lay_out` | interact | `table_comb` (am Kopfende: Kamm von der Stirn über den Scheitel, linke Hand an der Schläfe) | `ph_tool_comb` | `cloth` im Strich |
| Mit Wacholder räuchern | `morgue_balm` | interact | `table_smoke` (glimmendes Bündel in ruhigem Bogen über den Körper, Kopf gesenkt) | `ph_tool_juniper` | `smoke_hiss` (Takt) |
| Zopf abschneiden (Verwerten) | `morgue_harvest_hair` | interact | `table_snip` (am Kopfende: linke Hand hebt den Zopf, die Schere schließt) | `ph_tool_shears` | `snip` im Schnitt (0,9 s) |
| Zähne nehmen (Verwerten) | `morgue_harvest_teeth` | interact | `table_pull` (am Kopfende, Zange ansetzen, drehen, ziehen; das Gesicht abgewandt – „du siehst dabei nicht hin“) | `ph_tool_pliers` | `anatomy_tool` beim Zug |
| Organentnahme (Herz, Lunge, Augen, Hand …, Phase 7) | `morgue_organ` | interact | `table_cut` (Skalpell, langsamer präziser Strich, linke Hand flach daneben, Kopf zur Seite gewandt; der Körper bleibt unter dem Tuch, Schleier wie bisher – kein Gore) | `ph_tool_scalpel` | `anatomy_tool` (prozedural) beim Ansetzen; Clip 1,5 s |
| Leiche ablegen / aufnehmen, Wertsachen entscheiden | – | sofort, keine Aktion | unverändert | – | – |

Die Zerlege-Geräusche bleiben die vorhandenen prozeduralen Cues (`anatomy_tool`, `snip`, `wash`, Stichwörter in `data/audio/audio_events.tres`); bei Werkzeug-Clips mit `bite_at` erklingen sie jetzt im Takt der Bewegung statt per Zeitgeber.

## 2. Andere Spieler-Aktionen

| Ort / Aktion | Datei | bisher | neu | Begründung |
|---|---|---|---|---|
| Grab: Blumen pflanzen | grave_plot.gd `grave_flowers` | interact (Schlüssel fehlte in den Daten) | `kneel_place` (vorhanden) | kniet am Hügel und setzt ein |
| Grab: Wachskranz | `grave_wreath` (neu, Rückfall `grave_flowers`) | interact | `kneel_place` | dito |
| Grab: Kerze | `grave_candle` | interact (Schlüssel fehlte) | `kneel_place` | dito |
| Grab: Gießen | `grave_water` | water | water (unverändert) | passt |
| Grab: Grabgitter setzen / abnehmen | `grave_mortsafe` (neu, Rückfall `grave_marker`) | hammer | hammer | passt (Gitter festschlagen) |
| Grab: Zeile / Namen nachmeißeln | `grave_line` (neu) | hammer | `chisel` (vorhanden) | Meißeln statt Hämmern; Geräusch war schon `chisel` |
| Grab: wieder schließen | – | dig | dig (unverändert) | passt |
| Unkraut jäten (Pflegestelle) | dirt_spot.gd `dirt_weeds` | interact | `weed_pull` (neu, 1,5 s: hinknien, zweimal ausreißen, aufstehen) | |
| Laub harken (Pflegestelle) | `dirt_leaves` | interact | `rake` (neu) mit `ph_tool_rake` (`rake_take`/`rake_put`, erscheint sofort wie die Gießkanne) | `rake_leaves` im Zug |
| Regentonne: Gießkanne füllen | rain_barrel.gd `barrel_fill` | interact (Schlüssel fehlte) | `fill_can` (neu; Kanne an `can_grip` getaucht, `can_clips`) | |
| Kapelle: Aussegnung / Andacht | chapel_altar.gd `chapel_service` / `chapel_devotion` | interact | `pray` (neu: Hände gefaltet, Kopf gesenkt) | |
| Schreibtisch: Namen abschreiben | desk.gd `desk_copy` | interact | `write` (neu) | Geräusch `quill` |
| Kirche: Im Archiv helfen | archive_cabinet.gd `archive_help` | interact | `bench_work` (neu) | Akten sortieren |
| Gruft: Gebeine beisetzen (Beinhaus) | ossuary_shelf.gd `ossuary_reinter` | interact | `place_low` (neu: tiefe Verbeugung, beide Hände setzen ab) | |
| Präparierpult: Einlegen / Schaupräparat / Arznei | pult_panel.gd `pult_seal` / `pult_display` / `pult_medicine` | interact | `bench_work` | Feinarbeit mit beiden Händen |
| Präparierpult: Knochenpräparat | `pult_bone` | interact | `table_wash` (Tuch, Schrubben) | Geräusch bleibt `scrub` (Stichwort) im Takt |
| Präparierpult: Begutachten | `pult_inspect` | interact | `table_examine` | |
| Holz/Steine sammeln (Haufen) | resource_node.gd `resource_gather` | interact | `place_low` | bückt sich und hebt auf |
| Bau-Modus: aufstellen / entfernen | build_mode.gd `decor_place` / `decor_remove` | interact | `place_low` | |
| Schuppen: Zutaten holen | shed_supply.gd `shed_fetch` | interact | `place_low` | Kisten |
| Quast: Gutachten / Vorlesung | anatomist_panel.gd `anatomist_expertise`, lecture_panel.gd `lecture_hold` | interact (wiederholtes Greifen, 30–60 Min) | `idle` | der Totengräber wartet, Quast arbeitet bzw. spricht |
| Flachs raufen, Kräuter schneiden | data/gather/flax_bed, herb_patch | interact | `weed_pull` (Daten) | kniend |
| Beeren pflücken (Holunder) | data/gather/elder_bush | interact | interact (unverändert) | Greifen in Hüfthöhe passt |
| Pforten aufschließen (Kirch-, Ost-, Rostiges Pförtchen) | data/clearables/gate_* | interact | interact (unverändert) | zum Schloss greifen passt |
| Werkbank: Auftrag beginnen / Ergebnis holen | workbench.gd | interact | interact (unverändert) | kurzes Hinlangen; Herstellen selbst = Stations-Clip (saw / hammer / chisel) |
| Grabstein setzen, Grabzeichen, Bauen, Inschrift, Gruben, Roden, Bruch | grave_plot / build_site / building_site / stone_design / clearables / gather | dig, hammer, chisel, chop, pick, saw | unverändert | hatten schon eigene Clips (G7 Runde 2) |
| Im Schatten warten | watch_spot.gd | idle | idle | passt |
| Truhe, Ofen, Bett, Regale, Grabregister, Aushänge, Trinkgeldstein (Münzen nehmen), Katafalk / Gruft-Nische (ablegen) | chest / stove / bed / desk / notice / grave tip / catafalque / crypt_niche | keine zeitgesteuerte Aktion (öffnet Panel oder wirkt sofort) | – | keine Lücke |

## 3. NPCs

| Figur / Tätigkeit | bisher | Stand | Anmerkung |
|---|---|---|---|
| Jakob (Lehrling): rechen, gießen, jäten, Kerze, fegen, Tafel, essen, Laterne | eigene Clips `rake`, `water`, `weed`, `candle`, `sweep`, `read_board`, `sit_eat`, `lantern_walk` | keine Lücke | Prüfskript: jeder Plan-Eintrag hat seinen Clip |
| Besucher an Gräbern (Kehr, Ott, Brandt, Sieber) | `lay_flowers`, `kneel_in/kneel/kneel_out`, `mourn_stand`, `idle_low` | keine Lücke | |
| Bewohner, Phase-8-Leben (Krankenbesuch, Trauer, Kathreintanz, Lichtgang) | `mourn_stand`, `kneel`, `knock`, `dance`, `clap`, `lantern_*`, `work` | keine Lücke | |
| Pfarrer Lenz „shop“ in der Kirche (16–18 Uhr am Altar), Wundarzt Quast „shop“ am Pult, Wirt „shop“ am Schanktisch, Bürgermeister | `idle` (stehen) | **offen** | kein passender Clip an diesen Modellen (`mourn_stand` am Altar wäre möglich, kollidiert aber mit der Archiv-Hilfe „neben ihm“); neue Bewohner-Clips verlangen einen Neu-Export mit den Körper-/Clip-Hash-Tests – als eigener Auftrag empfohlen |
| Osric „smoke“ (Pfeifenpause) | `talk` | offen | spricht/gestikuliert statt zu rauchen; eigener Clip + Pfeife wäre nötig |

## 4. Prüfungen

- Tests: `tests/unit/test_assets_table_work.gd` (Clip-Existenz, jede Tisch-Aktion mit eigenem Clip statt `interact`, Werkzeuge wie Gürtelwerkzeuge verdrahtet, Marker `tool_hand`, Werkzeug-Budgets, Hände am Körper, Werkzeug in der rechten Faust, Leinen zwischen beiden Fäusten, Schaufel bleibt bei Handarbeit auf dem Rücken), `tests/integration/test_table_work.gd` (echte Gruft: jede Tisch-Aktion spielt ihren Clip, Schritt an den Arbeitsplatz, Blick zum Tisch, Werkzeug aus der Tasche und zurück, abgewandte Seite zur Kamera); `test_assets_characters.gd` um die 22 Clips erweitert (Längen, Einmal-Clips); Körper-Mesh-Hash und alle alten Clips unverändert (`test_assets_phase8`), Glb-Export bytegleich bei Wiederholung.
- Bilder (echter Renderer, 1280 × 720, xvfb + lavapipe): je Aktion ein Kontaktbogen `tisch_<aktion>.jpg` / `arbeit_<aktion>.jpg` – oben Nahkamera, unten die Raumkamera des Spiels 1 : 1 um ihn; Spalten: Schritt bzw. Werkzeug aus der Tasche, fünf Momente des Clips, Werkzeug zurück. Forward+ ohne Zusatz, Browser-Renderer (`gl_compatibility`/`opengl3`) mit `_web`. Skript: `tools/godot_run.sh --resolution 1280x720 -s res://src/world/graveyard/graveyard_shots.gd -- --out=/abs/dir --table [--shots=waschen,organ] [--suffix=_web]`.
