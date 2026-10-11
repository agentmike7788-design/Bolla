# G8 Runde 3 – Lieferung mit dem Holzkarren

Benutzerkritik: „ich dachte die neuen leichen werden mit dem holz wagen hergebracht".

Die Bilder kommen aus dem echten Spiel (neues Spiel, Tag 1, die Uhr läuft Minute für Minute über `TimeManager.advance(1)`, also mit jedem `time_tick` wie beim Spielen), 1280×720. Ohne Endung: Forward+; `_web`: Compatibility-Renderer (`--rendering-method gl_compatibility --rendering-driver opengl3`, so sieht es im Browser aus). Die `_web`-Reihe beginnt mit dem Debug-Befehl `time 07:25`.
Erzeugt mit `tools/godot_run.sh --resolution 1280x720 -s res://src/world/graveyard/graveyard_shots.gd -- --out=<dir> --delivery [--skip] [--suffix=_web] [--before-set] [--from=HHMM]`.

## Vorher (`*_before*.jpg`)

- Der Karren kommt mit der Leiche sichtbar über den Kutschweg (`0728`, `0735`, `0739`). Bei Spielbeginn ist die Bahre leer. Forward+ und Browser zeigen dasselbe.
- **Fehler:** Um **07:40** sprang die Leiche ohne jede Bewegung vom Karren auf die Bahre (`0739` → `0740`). Osric stand währenddessen an den Griffen, 2,6 m von der Bahre entfernt. Wer den Augenblick verpasst hat (im Dorf, in der Gruft, beim Schlafen, nach einem Zeitsprung oder einfach woanders hingeschaut), fand nur eine Leiche auf der Bahre vor, und neben dem Tor stand ein leerer Karren.
- Weitere Fehler im Code gefunden:
  - Eine Story-Leiche lag in einem falschen, zufälligen Look auf dem Karren, weil die Ladung immer aus Seed-Index 0 gewürfelt wurde. Auf der Bahre lag dann eine andere Gestalt.
  - An Tagen, an denen eine Zufallsleiche wegen der Reserve für Story-Leichen still ausfällt, verschwand die Leiche auf dem Karren um 07:40 spurlos.
  - Nach einem Debug-Spawn am selben Tag stimmte der Look nicht mehr.
- **`time 07:25` (Browser-Hänger):** Der Sprung kostet 4–7 ms. Es gibt keine Schleife über jede Minute, denn `advance()` meldet nur die Stundengrenzen, und an `time_skipped` hängen nur fünf Abfragen ohne Schleife. Gemessen im Compatibility-Renderer mit Software-GL: vor dem Sprung 4,3 s pro Frame am Tor, danach 3,4 s pro Frame. Der Sprung macht das Spiel also nicht langsamer. Den Hänger im Browser verursacht das teure Bild am Tor in swiftshader, nicht die Zeit.

## Nachher (`*_after*.jpg`)

| Bild | Uhr | Was passiert |
|---|---|---|
| `0630` | 06:30 | Spielbeginn: die Bahre ist leer, Osric ist noch nicht da |
| `0705`, `0720`, `0728` | 06:52–07:32 | er schiebt den Holzkarren mit der Leiche über den Kutschweg ans Tor (gleiches Schiebetempo, Aufbruch 8 Min früher) |
| `0732`, `0733` | 07:32 | er hält an, die Bahre ist noch leer, und er tritt neben den Karren auf die Seite zur Bahre |
| `0734_2`, `0735_2` | 07:34–07:35 | `load_lift`: er beugt sich über den Karren, fasst zu und hebt die Leiche in die Arme |
| `0736_3`, `0737_2` | 07:36–07:37 | `carry_walk`: er trägt sie zur Bahre hinüber |
| `0738_4`, `0739_4` | 07:38–07:39 | `load_lower`: er beugt sich über die Bahre und legt sie ab |
| `0740` | 07:40 | erst jetzt liegt die Leiche auf der Bahre und gilt als geliefert (gleiche Stelle, gleicher Look, Ankunft = 07:40), der Karren ist leer |
| `0741_5` | 07:41 | er geht zurück zu den Griffen, ohne Dialog-Prompt |
| `0750` | 07:50 | er steht wieder am Karren, Dialog wie bisher bis 10:00 |

- **Ladung:** Was auf dem Karren liegt, ist der Plan der echten Lieferung (`CorpseManager.cart_load` / `_plan_delivery`). Die Lieferung nutzt dieselbe Regel, deshalb stimmen Seed, Name, Story-Leiche und Look überein.
  - Bahre belegt: die Leiche bleibt auf dem Karren und fährt wieder mit, wie bisher.
  - Friedhof endgültig voll, Reserve für Story-Leichen oder kein Liefertag: der Karren ist schon auf dem Weg leer.
  - Mehrere Leichen (nur mit geänderten Daten möglich): sie liegen nebeneinander auf dem Karren und werden nacheinander auf je eine Bahre gelegt.
- **Zeitsprung, Dorf, Laden:** Alles folgt aus der Uhr. Ein Sprung über 07:40 endet mit der Leiche auf der Bahre und leerem Karren, ein Sprung mitten in das Abladen zeigt ihn beim Abladen. Ist der Totengräber im Dorf, wird trotzdem um 07:40 geliefert. Ein Spielstand, der beim Abladen gespeichert wurde, zeigt nach dem Laden dieselbe Haltung. Es gibt kein neues Spielstand-Feld (Format v7), und die v6-Stände funktionieren weiter.
- **Werte:** in `data/config/cart_delivery_config.tres`: 8 Min Abladen (4 s), Anteile Schritt / Heben / Tragen / Ablegen, 3 Min Rückweg, Abstände, Tragehöhe, Kopf zu den Griffen.
- **Modell:** Der Karren ist bereits ein hölzerner zweirädriger Handkarren (Bodenbretter, Bordwände, Speichenräder mit Eisenreif, Griffe) und bleibt unverändert. Osric hat drei neue Clips (`carry_walk`, `load_lift`, `load_lower`). Sein Körper und die alten Clips sind hash-gleich.
- **Offen:** Die Uhrzeiten im Vertrag habe ich angepasst: Aufbruch 06:52 statt 07:00, Ankunft an der Bahre 07:32 statt 07:40. Die Lieferminute 07:40 und der HUD-Text „gegen 07:40" sind unverändert. Diese Anpassung muss der Benutzer noch bestätigen.

## Prüfung im echten Spiel (nach dem Browser-Test)

Benutzer nach dem Test der Browser-Fassung: „also im spiel sah es gerade nicht so aus wie auf den bilder bitte mal prüfen" und „er kam ohne karren und hat die leiche abgelegt".

**Geprüft wurde der echte Ablauf**, nicht das Shot-Skript: Titel → „Neues Spiel" über den SaveManager, dann die Debug-Konsole wie beim Benutzer (öffnen, `tp gate`, `time 07:15` bzw. `07:25`, `07:35`, `07:38`, `07:45`, schließen). Danach läuft die Uhr frei über `TimeManager._process`, ohne `advance(1)`-Schleife und ohne gesetzten Akkumulator. Außerdem: ohne `time` von 06:30 bis 07:45, ein Spielstand der Version vor dem Umbau (v7, 07:20 und 07:36) und der Spieler auf Osrics Weg bzw. vor der Bahre.

Geprüft in drei Umgebungen:
- Projekt headless mit 60 / 4 Bildern pro Sekunde
- Forward+
- **das exportierte Web-pck aus der Browser-Testversion**, geladen mit `--main-pack` im Compatibility-Renderer. So läuft der Browser, nur ohne Chromium.

**Ursache, nur im Export:** Godot 4.7.2 wandelt beim Export Text-Ressourcen in Binärdateien um (`editor/export/convert_text_resources_to_binary`, Standard an). Dabei verlieren alle `Packed*Array`-Werte ihren Inhalt, sie sind danach leer oder stehen auf dem Standardwert. Der Regressionstest fand 353 betroffene Werte.
- In Osrics Zeitplan sind alle Wegpunkte (`path`) leer. Er und sein Karren bleiben deshalb den ganzen Morgen außerhalb des Bildes am Kutschweg-Ende (`road_end`, 15,8 | 32,6) stehen.
- Die Abladehaltung rechnet aber von der Bahre aus. So „trägt" seine Figur die Leiche in gut einer Sekunde 28 m von dort zur Bahre und legt sie ab. Der Karren bleibt dabei am `road_end`.
- Das ist genau „er kam ohne karren und hat die leiche abgelegt" (Bild `delivery_game_0738_before_web.jpg`).
- Dieselbe Ursache betrifft auch andere Werte:
  - alle anderen Wege der Figuren,
  - Namen in den Leichentabellen,
  - Plauder-Zeilen,
  - die Mischminuten der Atmosphäre (deshalb bleibt es im Browser nachts hell).
- Im Editor-Projekt, also auch bei allen bisherigen Bildern und Tests, ist alles vorhanden. Deshalb sahen die Bilder anders aus als das Spiel.

**Fix:** In `project.godot` steht jetzt `[editor] export/convert_text_resources_to_binary=false`. Ein neu exportiertes Web-pck zeigt danach denselben Ablauf wie das Projekt: Wege, Karren, Ladung, Abladen, 07:40 auf der Bahre (Bilder `delivery_game_*_web.jpg`).

**Nebenbefund `time`-Sprung:** Nach einem Zeitsprung drehte sich Osrics Wurzel noch etwa 1 s lang von der alten Richtung herum. Der Karren schwang dabei bis zu 3 m um ihn, bei `time 07:35` zum Beispiel neben den Spieler. Im ersten Bild direkt nach dem Befehl stand er sogar noch am alten Ort.
- Jetzt platziert sich jede Figur bei `time_skipped` sofort nach der Uhr (`Npc._on_time_skipped` → `refresh`).
- Sonst springt beim Befehl nichts:
  - Der Zeitplan wird nicht neu aufgesetzt.
  - Ein Sprung mitten ins Abladen zeigt ihn beim Abladen.
  - Ein Sprung über 07:40 endet mit der Leiche auf der Bahre und leerem Karren.

**Weitere Befunde:**
- **Dauer bei normal laufender Uhr** (0,5 s pro Spielminute):
  - Ankunft am Tor 20 s (06:52–07:32).
  - Abladen 8 Spielminuten = **4 s**: zum Karren treten 0,8 s, heben 0,9 s, tragen 1,1 s (2,6 m, also flott), ablegen 1,2 s.
  - Rückweg 1,5 s.
  - Bei 60 Bildern pro Sekunde sind das 240 Bilder. Bei 4 Bildern pro Sekunde sind es nur 16 Bilder, die Reihenfolge und das Ende auf der Bahre bleiben aber gleich.
  - Sichtbar ist das Abladen, aber kurz. Ob es länger dauern soll, ist ein Datenwert (`unload_minutes`) und muss der Benutzer entscheiden.
- **Spieler im Weg:** Nichts blockiert die Lieferung. Osric und der Karren folgen der Uhr und laufen durch den Spieler hindurch, der Spieler wird nicht geschoben. Steht der Spieler vor der Bahre, überlagert sich Osrics Figur beim Ablegen mit ihm.
- **Alter Spielstand** (v7 vor dem Umbau, 07:20 / 07:36): Er lädt ohne Fehler. Osric zeigt die Haltung der Uhr, um 07:40 wird geliefert.
- **Nichts Web-Spezifisches** unterdrückt das Abladen:
  - kein LOD und kein Culling: Osric ist am Tor Stufe 0, nicht gecullt,
  - die Clips `carry_walk`, `load_lift` und `load_lower` sind im exportierten pck vorhanden und laufen,
  - kein `has_feature("web")` im NPC-Code,
  - die Logik hängt nicht von der Bildrate ab.

**Tests:**
- `tests/integration/test_cart_delivery_live.gd`: neues Spiel, Debug-Konsole, laufende Uhr, Prüfung in jedem Bild. Abgedeckt sind `time 07:15`, Start 06:30, `time 07:35` und `time 07:45`.
- `tests/integration/test_export_packed_arrays.gd`: Prüft die Einstellung und Osrics Wegpunkte. Außerdem exportiert er das Web-Preset in ein temporäres pck und vergleicht in einem zweiten Godot-Prozess alle `Packed*Array`-Werte der Ressourcen und Szenen unter `data/` und `src/` mit den Quellen. Mit eingeschalteter Umwandlung schlägt er fehl, bei 353 Werten.

### Bilder aus dem echten Spiel (`delivery_game_*`)

Neues Spiel, `tp gate`, `time 07:15`, Konsole zu. Danach läuft die Uhr frei mit festen 30 Bildern pro Sekunde (`--fixed-fps 30`, damit die Software-Grafik so viel Spielzeit pro Bild zeigt wie ein 30-fps-Rechner). Die Kamera ist die normale Spielkamera auf dem Totengräber, 1280×720, der Dateiname ist die Uhrzeit.
- Ohne Endung: Forward+, Projekt.
- `_web`: Compatibility-Renderer mit dem neu exportierten Web-pck (Stand `2f2b160` + Export-Einstellung).
- `_before_web`: das pck der Browser-Testversion, die der Benutzer gespielt hat.

| Bild | Uhr | Was passiert |
|---|---|---|
| `0717`, `0721` | 07:17–07:21 | Osric schiebt den Karren mit der Leiche den Kutschweg herauf |
| `0728`, `0730` | 07:28–07:30 | durchs Tor, Karren voran |
| `0732` | 07:32 | hält an der Bahre, die Bahre ist leer |
| `0734`, `0735` | 07:34–07:35 | hebt die Leiche vom Karren |
| `0736` | 07:36 | trägt sie hinüber |
| `0737`, `0739` | 07:37–07:39 | legt sie auf die Bahre |
| `0740` | 07:40 | sie liegt auf der Bahre, der Karren ist leer |
| `0741_6` | 07:41 | geht um das Bahrenende zur Torglocke |
| `0743_5` | 07:43 | greift zur Glocke (`ring_bell`) |
| `0744` | 07:44 | läutet, HUD „Am Tor läutet es – Osric hat eine neue Leiche gebracht." |
| `0746_4` | 07:46 | wieder an den Griffen, Dialog bis 10:00 |
| `0736/0738/0740_before_web` | 07:36–07:40 | Browser-Testversion vor dem Fix: kein Osric am Tor, dann trägt er die Leiche ohne Karren heran und ist um 07:40 schon wieder auf dem Rückweg zum `road_end` |

- Die Bilder `0741_6` bis `0746_4` stammen aus einem eigenen Lauf mit dem fertigen Stand (Glocke, Export-pck neu gebaut). Er beginnt mit `time 07:39` und läuft mit 15 Bildern pro Sekunde.
- Alle Bilder davor zeigen Ankunft und Abladen. Diese Teile hat der Glocken-Commit nicht verändert.

## Torglocke nach der Lieferung (Benutzerwunsch)

Benutzer: „und er soll an der glock klingeln das ich höre wen eine neue leiche da ist".

**Ablauf:** Um 07:40 liegt die Leiche auf der Bahre.
- Danach geht Osric um das Ende der Bahre herum zur Glocke am östlichen Torpfosten (`GateBell`, 3 Spielminuten).
- Er stellt sich darunter, sieht hoch und zieht zweimal kurz daran. Dafür hat er einen neuen Clip `ring_bell` (1 s). Körper und alte Clips sind hash-gleich.
- Beim ersten Zug (07:43,8) schwingt die Glocke, und der Ton `gate_bell` erklingt mit +8 dB über dem Besucher-Läuten. Er kommt vom Tor und ist auf dem ganzen Friedhof zu hören.
- Danach geht er in 1 Minute zu den Griffen zurück, also bis 07:46. Dialog und Leinen gibt es wie bisher bis 10:00, um 10:00 fährt er mit dem leeren Karren ab. Der übrige Zeitplan ist unverändert.
- **Im Haus, in der Gruft oder im Dorf** ist die Glocke nicht zu hören. Dort kommt nur der HUD-Hinweis „Am Tor läutet es – Osric hat eine neue Leiche gebracht." Draußen kommt der Hinweis zusätzlich zum Ton.
- **Zeitsprung oder Schlafen über die Lieferung:** Es läutet nicht. Danach kommt nur „Osric hat am Tor eine neue Leiche gebracht."
- **Laden:** Ein Spielstand meldet nichts nach, wie bei den Besuchern. Läuft die Uhr nach dem Laden über den Moment des Läutens, läutet er wie beim Zuschauen.
- **Werte** in `data/config/cart_delivery_config.tres`: `ring_bell`, `bell_walk_minutes`, `bell_ring_minutes`, `bell_ring_at`, `bell_stand_distance`, `bell_corner_offset`, `bell_volume_db`, `bell_note`, `skipped_note`. `return_minutes` gilt jetzt für den Weg von der Glocke zu den Griffen und ist 1.
- **Geprüft im exportierten Web-pck:** Läuten um 07:43,8, hörbar. Abfahrt um 10:00 mit dem Karren, um 10:40 weg. Abends 18:00–18:30 Anmarsch ohne Karren, Pfeife bis 21:00, um 21:30 weg.
- **Tests:**
  - `tests/unit/test_gate_bell_delivery.gd`: Werte, Weg um die Bahre ohne sie zu schneiden, Läuten am Platz unter der Glocke, Rückweg, „gehört" draußen und nur der Hinweis drinnen bzw. im Dorf.
  - `test_cart_delivery_live.gd`: Läuten einmal und zur richtigen Zeit bei laufender Uhr; kein Läuten bei Zeitsprung, dann nur der Hinweis; im Raum nur der Hinweis; kein Läuten nach dem Laden.
- **Offen:** Die Glocke ist von oben klein, ihr Schwingen sieht man kaum. Sichtbar sind Osrics Griff nach oben und der Hinweis.
