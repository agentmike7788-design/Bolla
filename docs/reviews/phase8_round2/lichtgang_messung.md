# G8 Runde 2 – Lichtgang: Laternen und Browser-Helligkeit (Messung)

Benutzerkritik: „Die Laternen beim Lichtgang sind nur Leuchtpunkte." · „Im Browser wirkt der Lichtgang heller."

## Messverfahren

- Werkzeug `tools/qa/qa_light_match.gd` (erbt die Phase-8-Motive aus `graveyard_shots_phase8.gd`): misst im laufenden Renderer das gespeicherte Bild – **mittlere Bildhelligkeit** (Rec.-709-Luma über die sRGB-Pixel, jedes 2. Pixel), **Laternenflecken** (Mittel der Luma in einer Scheibe von 0,9 m um den Bodenpunkt unter jeder Laterne im Bild) und das hellste Glas-Pixel; `--variants=` probiert Werte in einem Weltladen durch (nur im Speicher).
- Forward+: `tools/godot_run.sh --resolution 1280x720 -s res://tools/qa/qa_light_match.gd -- --out=… --shots=p8_21,p8_22,g8_laterne,perf_p8_03`
- Browser: dasselbe mit `--rendering-method gl_compatibility --rendering-driver opengl3 … --suffix=_web`
- Dorf nachts (`village_shots.gd` p7_05, perf_p7_02) und Gruft (`graveyard_shots.gd --gruft2 --shots=abend,nacht`): mittlere Luma derselben Formel über die gespeicherten Bilder.
- Kein Headless-Test möglich (der Headless-Lauf rendert nicht); die Datenseite ist durch Tests abgesichert (`test_atmosphere`, `test_carried_lanterns`).

## Ursache „im Browser heller"

1. **Kein Volumennebel im Compatibility-Renderer.** Forward+ legt in Dämmerung/Nacht Volumennebel (Dichte 0,014 / 0,025 / 0,04) über die Szene – bei 18–31 m Kameraabstand nimmt er rund die Hälfte des Lichts weg und mischt kühles Streulicht hinein. Der Browser kennt nur den Tiefennebel → dieselben Presets wirken dort ~50 % heller (Lichtgang +50/+56 %, Dorf nachts +68 %, Gruft-Abend +43 %). Belegt durch die Nahaufnahme: bei 4 m Abstand sind beide Renderer gleich hell, bei 31 m nicht.
2. Kein SSAO (Kontaktschatten fehlen) – kleiner Anteil.
3. Additive Leuchtflächen: der Browser addiert den Wert unkodiert ins sRGB-Bild – ein Bodenfleck wird dort kleiner und schwächer (Sonde `tools/qa/qa_spot_probe.gd`).
4. Je Mesh höchstens 8 Lichter (Compatibility): der große Boden bekommt nicht alle Kerzen-/Laternenlichter – warme Bodenpfützen fehlen dort teilweise.

## Maßnahmen (nur Browser, Forward+ unverändert)

- `data/atmosphere/compat_overrides.tres` (`CompatOverrides`): im Compatibility-Renderer arbeitet `AtmosphereController` auf Kopien der freigegebenen Presets (Dateien bytegleich, ART STYLE LOCK) mit zusätzlichem Tiefennebel als Ersatz des Volumennebels: Dämmerung +0,012 (Farbe 0,12/0,14/0,20), Nacht +0,026 (0,08/0,10/0,16), tiefe Nacht +0,034 (0,07/0,09/0,13). Tag/Morgen unverändert.
- `lantern_spot.gdshader` / `lantern_glass.gdshader`: Zweig `#if CURRENT_RENDERER == RENDERER_COMPATIBILITY` kodiert die Stärke (nicht den Farbton) vor dem Addieren.
- `carried_lanterns.tres`: `spot_radius_compat` 1,9 m, `spot_under_light_compat` 0,75 (der Fleck ersetzt im Browser das Pool-Licht am Boden).

## Ergebnis (Browser gegen Forward+, mittlere Luma)

| Motiv | vorher Forward+ | vorher Browser | Abw. vorher | nachher Forward+ | nachher Browser | Abw. nachher |
|---|---|---|---|---|---|---|
| p8_21 Lichtgang-Zug 18:12 | 0,182 | 0,274 | +50 % | 0,201 | 0,215 | **+7 %** |
| p8_22 Lichtgang-Übersicht 17:55 (Zoom 31) | 0,196 | 0,307 | +56 % | 0,199 | 0,186 | **−6 %** |
| perf_p8_03 Lichtgang Spiel-Zoom 22 | – | – | – | 0,212 | 0,208 | **−2 %** |
| g8_laterne_nah (4 m) | – | – | – | 0,228 | 0,247 | **+8 %** |
| p7_05 Dorf nachts | 0,150 | 0,252 | +68 % | 0,150 | 0,150 | **±0 %** |
| perf_p7_02 Dorf nachts | 0,150 | 0,265 | +77 % | 0,150 | 0,149 | **−1 %** |
| Gruft-Abend (Laternen) | 0,245 | 0,349 | +43 % | 0,245 | 0,263 | **+7 %** |
| Gruft nachts | 0,179 | 0,277 | +55 % | 0,179 | 0,191 | **+6 %** |

Laternenflecken (Scheibe 0,9 m): p8_21 0,214 / 0,232 (**+8 %**); p8_22 0,188 / 0,157 (−17 %); perf_p8_03 0,174 / 0,136 (−22 %). In den Übersichten fehlen dem Browser die warmen Bodenpfützen der Kerzen und Pool-Lichter am Kirchhof (Grenze 8 Lichter je Mesh am großen Boden) – offener Punkt, s. unten. „Vorher" in der Tabelle: Stand vor dieser Runde (Lichtgang ohne Laternenlicht; die Übersichten damals ohne brennende Kerzen im Motiv).

## Laternen

- Modell `lantern_hand` (`asset_props_phase8.py`, alle Laternenträger über `lantern_child`, Jakob am `tool`): Eisenrahmen mit vier Eckstäben, Glas (`mat_lantern_glass`, additiv durchscheinend), Pyramidendach mit Kamin, Bügel, Kerzenstumpf mit Flamme (`mat_emissive_warm`) – **146 Dreiecke** (vorher 156). Körper-Hashes und alte Clips unverändert (`test_assets_phase8`), neuer Clip `lantern_idle` bei allen Laternenträgern.
- Zug: hinauf und hinab `lantern_walk`, an Grab und Kirchhof `lantern_idle` (Fest-Daten) – vorher trug der Zug im Spiel gar keine Laterne (nur in den Bildern).
- `CarriedLanterns`: 4 Pool-Lichter ohne Schatten für die nächsten Laternen (Kerzen-Pool gibt ebenso viele ab, ≥ 2 bleiben), Fake-Fleck für alle übrigen, Flackern im Gleichtakt, Pendeln im Gehen. 16 Laternen: 0,22 ms je Bild (Messtest, unter Last).

## Leistung (Lichtgang, Spiel-Zoom 22, `perf_p8_03`)

| | vorher (G8 R1) | nachher Forward+ | nachher Browser |
|---|---|---|---|
| Dreiecke (inkl. Gras) | 444 k | 444–463 k | 444–463 k |
| Draw Calls | 319 | 350–364 | 678–700 |
| Lichter im Bild / mit Schatten | 13 / 2 (Kerzen im Motiv aus) | 19 (13 feste + 2 Kerzen + 4 Laternen) / 2 | 19 / 2 |

Budget §9: < 500 k Dreiecke ✓, ≤ 750 Draw Calls ✓ (auch Browser), sichtbar ≤ 25 / Schatten ≤ 4 ✓. Im Spiel brannten am Lichtgang vorher 6 Kerzenlichter, jetzt 2 Kerzen- + 4 Laternenlichter – keine zusätzlichen Lichter. Die Übersicht p8_22 (Zoom 31, über dem Spielmaximum) bleibt bei 611 k Dreiecken (P8-2, unverändert).

## Offen

- **Browser-Bodenpfützen in der Übersicht:** Der Boden ist ein Mesh; der Compatibility-Renderer nimmt je Mesh höchstens 8 Lichter. Abhilfe wäre ein gekachelter Boden oder ein höheres Limit (`rendering/limits/opengl/max_lights_per_object`) – beides größere Eingriffe, nicht gemacht (Vertrag §9: „≤ 8 Lichter je Mesh").
- Im Browser bleiben die Mondschatten härter und das Gras etwas gelber (kein Volumennebel/SSAO); die Helligkeit stimmt.
