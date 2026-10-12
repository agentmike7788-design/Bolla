# G8 Runde 4 – Leichentisch und Osrics Lieferung

Benutzerentscheidung: „1 ja kannst du 8 sec machen bei 2. ja soll etwas länger dauern und das auswahl bild muss weg der verdekt den leichentisch".

Alle Bilder stammen aus dem echten Spiel in 1280 × 720: neues Spiel, Tag 1, echte Systeme. Bilder ohne Endung sind mit Forward+ aufgenommen, Bilder mit `_web` im Compatibility-Renderer (`--rendering-method gl_compatibility --rendering-driver opengl3`, so sieht es im Browser aus).
Erzeugt mit `tools/godot_run.sh --resolution 1280x720 -s res://src/world/graveyard/graveyard_shots.gd -- --out=<dir> --round4=ui|work|delivery [--tag=vorher|nachher] [--suffix=_web]` (Modul `graveyard_shots_round4.gd`). Die Kontaktbögen setzt `python tools/contact_sheet.py <frames.json> <out.jpg>` aus den Einzelbildern zusammen.

## 1. Das verdeckende „Auswahlbild" am Leichentisch

**Befund:** Gemeint war das Panel des Leichentisches (`corpse_exam`, `src/ui/panels/corpse_exam_panel.gd`). Es lag zweispaltig und etwa 1250 px breit (von 1920) in der Bildmitte, mit Abdunklung über der ganzen Welt. Der Spieler öffnet es mit E am Tisch, und dort startet er auch alle Arbeiten (Untersuchen, Herrichten, Verwerten, Präparate). Während einer Arbeit blieb es offen und zeigte nur einen Fortschrittsbalken. Tisch und Totengräber waren dabei vollständig verdeckt, man sah von den neuen Arbeits-Clips nichts (`tisch_ui_vorher.jpg`, `tisch_ui_vorher_auswahl.jpg`).

**Fix (beides):**
- **Während der Arbeit ausgeblendet:** Sobald eine Arbeit aus dem Panel startet, verschwindet das Panel samt Abdunklung (`UIPanel.hide_while_working`). Die Arbeit zeigt dann der normale HUD-Balken unten in der Mitte („Hände & Arme ansehen …"). Das Panel bleibt dabei modal, es ist also keine andere Interaktion möglich. Nach der Arbeit kommt es zurück, und der Tastaturfokus liegt auf dem ersten freien Knopf. Esc schließt es auch während der Arbeit.
- **Sonst seitlich:** Das Panel ist rechts angedockt, einspaltig und etwa 650 px breit (34 %). Die Reihenfolge ist Todesursache, Zustand, Reiter mit Arbeitsschritten, dann der Befund. Ist der Inhalt höher als der Bildschirm, rollt er. Die Welt wird nicht abgedunkelt, Tisch und Figur bleiben in der Raumkamera frei (`tisch_ui_nachher_auswahl.jpg`). Das betrifft nur `corpse_exam`. Alle anderen Panels bleiben in der Mitte und abgedunkelt.
- Maus und Tastatur funktionieren unverändert. Das prüft `test_ui.gd::test_corpse_exam_docked_and_hidden_while_working`: Enter auf dem fokussierten Knopf, Mausklick auf „Aufnehmen", Fokus nach der Arbeit, Schließen während der Arbeit.

| Bild | Inhalt |
|---|---|
| `tisch_ui_vorher_auswahl(_web).jpg` | vorher: Panel offen, verdeckt Tisch und Figur |
| `tisch_ui_vorher(_web).jpg` | vorher: während „Hände & Arme ansehen" – Panel mit Balken über dem Tisch |
| `tisch_ui_nachher_auswahl(_web).jpg` | nachher: Panel rechts, Tisch und Totengräber frei |
| `tisch_ui_nachher(_web).jpg` | nachher: während der Arbeit nur der HUD-Balken, der Totengräber untersucht sichtbar |
| `tisch_ui_ablauf_vorher(_web).jpg` | Kontaktbogen vorher: das Panel bleibt die ganze Arbeit über (1,5 s) über dem Tisch |
| `tisch_ui_ablauf(_web).jpg` | Kontaktbogen Auswahl → Klick → Arbeit (+0,0 … +2,6 s) → fertig, Panel wieder da (+3,5 s) |

**Andere Arbeits-Panels** (nur geprüft, nicht geändert):
- Präparierpult (`pult`, 1500 px) und Werkbank (`crafting`, 900 px) liegen ebenfalls mittig und abgedunkelt. Während ihrer Arbeiten bleiben sie offen mit eigenem Balken. Da die Raumkamera dem Totengräber folgt und er dann in der Bildmitte steht, verdecken sie ihn.
- Die Abhilfe wäre dieselbe Zeile `hide_while_working = true` im jeweiligen Panel, optional auch `dock_right`. Das habe ich nicht geändert, es bleibt Benutzerentscheidung.

## 2. Tisch-Arbeiten dauern länger

- **Vorher:** Alle Tisch-Aktionen liefen real `clamp(Minuten × 0,05, 1,5, 4,0)` s, also meist 1,5 s. Nach dem Herausholen des Werkzeugs (0,33 s) blieb kaum ein Zyklus des Arbeits-Clips übrig.
- **Neu:** Nur die Tisch-Aktionen (`MorgueTable._start_work`) laufen mindestens `table_real_seconds_min` = 3,0 s. Außerdem laufen sie mindestens so lange, dass nach dem Ziehen des Werkzeugs `table_work_cycles` = 2 volle Zyklen des Clips zu sehen sind (`ToolAnimConfig.table_seconds`, Werte in `data/config/tool_anim_config.tres`).
- Die Spielminuten bleiben unverändert. Alle anderen Aktionen behalten 1,5 s (`ActionConfig.real_seconds_min`).

| Clip | Aktionen | Länge | vorher | neu |
|---|---|---|---|---|
| `table_examine` | Untersuchen, Hände, Wunden, gründlich | 1,6 s | 1,5 s | 3,2 s |
| `table_search` | Kleidung, Taschen | 1,2 s | 1,5 s | 3,0 s (2,5 Zyklen) |
| `table_wash` | Waschen (+ Tuch) | 1,4 s | 1,5 s | 3,13 s |
| `table_cut` | Organentnahme (+ Skalpell) | 1,5 s | 1,5–4,0 s | ≥ 3,33 s |
| `table_comb` | Aufbahren (+ Kamm) | 1,2 s | 1,5 s | 3,0 s |
| `table_smoke` | Räuchern (+ Wacholder) | 1,6 s | 1,5 s | 3,53 s |
| `table_shroud` | Leichentuch, Totenhemd (+ Leinen) | 1,8 s | 1,5 s | 3,93 s |
| `table_snip` | Zopf (+ Schere) | 0,9 s | 1,5 s | 3,0 s (3 Zyklen) |
| `table_pull` | Zähne (+ Zange) | 1,5 s | 1,5 s | 3,33 s |

Lange Aktionen (z. B. „Gründlich untersuchen" 45 Min = 2,25 s nach der alten Formel, Organe bis 4 s) werden nie kürzer als vorher. Kontaktbogen `arbeit_ablauf(_web).jpg`:
- Waschen (15 Spielminuten) im 0,4-s-Takt, oben die Nahkamera, unten die Raumkamera.
- Ablauf: Tuch aus der Tasche (0,0 s), dann zwei volle Striche `table_wash` (0,4–2,8 s), Tuch zurück (3,2 s), Ruhe (3,6 s).

## 3. Osrics Abladen: 8 s statt 4 s

- **Zeitskala:** 0,5 s real je Spielminute (`time_config.tres`). Deshalb gilt `unload_minutes` 8 → **16** (`cart_delivery_config.tres`), also 8 s real.
- **Fahrplan:** Die Lieferung bleibt **07:40** (`delivery_minute`, HUD „gegen 07:40"). Damit verschieben sich Aufbruch und Ankunft (`carter_schedule.tres`):
  - Aufbruch **06:44** statt 06:52, bei gleichem Schiebetempo (40 Min)
  - an der Bahre **07:24** statt 07:32
- **Danach unverändert:** Torglocke (~07:44), 07:46 an den Griffen, Dialog bis 10:00, Abfahrt 10:00, Abend.
- **Bewegung lesbar statt gestreckt:** Ein bloßes Strecken der alten Anteile hätte `load_lift` auf 1,76 × und `load_lower` auf 2 × seiner Länge gedehnt, das wirkt wie Zeitlupe. Neue Anteile:

| Teil | Anteil | real | Bewegung |
|---|---|---|---|
| hinübertreten | 22 % | 1,76 s | 1,92 m mit ≈ 1,1 m/s (Clip `walk` läuft passend zur Bodengeschwindigkeit) |
| heben `load_lift` | 15 % | 1,2 s | 1,2 × Cliplänge (1,0 s) |
| tragen `carry_walk` | 26 % | 2,08 s | 1,78 m mit ≈ 0,86 m/s – schwere, kurze Schritte |
| ablegen `load_lower` | 18 % | 1,44 s | 1,2 × Cliplänge (1,2 s) |
| kurz an der Bahre stehen `idle` (neu) | 19 % | 1,52 s | die Leiche liegt schon, er steht und sieht sie an, dann geht er um 07:40 zur Glocke |

Bildreihe `osric_abladen(_web).jpg` im 0,75-s-Takt von −1,5 s bis +11,25 s: Ankunft, hinübertreten, heben, tragen, ablegen, stehen, 07:40 zur Glocke, läuten, 07:46 an den Griffen.

**Code:**
- `CartUnload` hat eine fünfte Phase (`ANIM_IDLE`, `rest_share`, `rest_idle_span`).
- `Npc._play_unload` ist unverändert, es spielt den `idle`-Clip über `anim_t`. **Keine Änderung an `npc.gd`.**

## Tests

- **`test_cart_delivery.gd`:** 16 Min ≈ 8 s, fünf Anteile, Clips 0,9–1,3 × ihrer Länge, Gehtempo 0,8–1,5 m/s, Tragen 0,6–1,2 m/s, Ruhephase an der Bahre. Bei zwei Leichen liegen am Ende beide auf ihren Bahren.
- **`test_cart_delivery_live.gd`:** Reihenfolge mit `idle`.
- **`test_schedule.gd`, `test_schedule_resolver.gd`, `test_phase7_scaffold.gd` (Fixture `tests/fixtures/phase7/schedules/carter_schedule.tres` mitgezogen), `test_graveyard_world.gd`:** 06:44 / 07:24.
- **Volle Suite:** 2965/2965 grün.
- **`test_table_duration.gd` (neu):** Datenwerte, `table_seconds` mit Ersatz-Rig und mit den echten Clips (2–3,5 Zyklen, ≤ 5 s).
- **`test_table_work.gd::test_table_work_lasts_a_few_cycles`:** in der echten Gruft ≥ 1,9 Zyklen gesehen, Spielminuten unverändert, andere Aktion 1,5 s.
- **`test_ui.gd`:** Andocken, Ausblenden während der Arbeit, Tastatur und Maus. Die Abdunkelungs-Prüfung gilt jetzt für alle Panels außer dem angedockten.

## Offen

- Mehrere Leichen auf einem Karren teilen sich die 16 Minuten weiter. Bei zwei Leichen laufen Heben und Ablegen dann etwa 0,6 × ihrer Länge. Das kommt nur mit geänderten Daten vor.
- Präparierpult und Werkbank verdecken die Figur weiterhin, siehe §1. Ob sie den gleichen Fix bekommen, entscheidet der Benutzer.
- Vertrag `docs/VERTICAL_SLICE_DESIGN.md` „(G8 Runde 4 angepasst)": Fahrplan 06:44 / 07:24, Tisch-Echtzeit, Panel-Verhalten. Die Benutzerbestätigung steht noch aus.
