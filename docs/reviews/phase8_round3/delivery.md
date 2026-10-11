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
