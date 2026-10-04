# G7 Runde 2 – Ruckler und Ton (Performance-/Audio-Agent)

Benutzerkritik (Browser-Testversion): „Der Ton passt noch nicht ganz, der laggt, wenn man die Karte aufmacht, und so auch ab und zu.“ – Zusatz: „Der Wind, wenn man draußen steht, hört sich auch komisch an – check einfach mal alle Sounds und die Lautstärke.“

## Ursachen

1. **Karte:** Jedes Öffnen (auch das zweite, dritte …) und jeder Blattwechsel zeichnete das ganze Blatt in `_draw` neu – Tausende Tintenlinien, Baumtupfer, ein Waldraster mit Abstandsprüfungen gegen alle Wege (`_free_for_wood`), Beschriftungen. Godot ruft `_draw` beim Sichtbarwerden erneut auf. Beim ersten Öffnen kam die Papiertextur dazu (420 × 300 Pixel, zwei Rauschfunktionen pro Pixel in GDScript). Während die Karte offen war, rasterte die GPU in jedem Frame die vielen geglätteten Linien neu.
2. **Ton im Browser:** Der ScriptProcessor-Treiber mischt im `onaudioprocess` **auf dem Hauptthread**, mit 2048 Frames Puffer (≈ 46 ms bei 44,1 kHz). Jeder Frame, der länger als ≈ 46 ms braucht (Karte, Raumwechsel, Shader beim ersten Anblick), lässt den Puffer leerlaufen → Aussetzer/Knacksen. Dazu dekodierte jede Stimme Vorbis auf dem Hauptthread; Emitter-Schleifen (Bach, Esse) liefen auch weit außer Hörweite weiter.
3. **Wind:** Böen als regelmäßige Sinus-Hüllkurve (≈ alle 5 s, 24-s-Schleife hörbar), ein zusätzliches resonantes „Pfeif“-Band 0,8–2 kHz und Laub-Körner bis 8 kHz im selben Takt → „pumpendes Zischen“ (Spektrogramm `spectro_wind_*_before.png`: senkrechte Streifen bis 8 kHz).
4. **Pegel:** Die Dateien waren auf Spitzenpegel normiert, die Lautstärken von Hand gesetzt – im Spiel streuten Klänge derselben Art um bis zu 20 dB (UI −35 … −58 LUFS, Spots −29 … −54), 13 Dateien mit DC-Versatz, 8 mit Knackser an Anfang/Ende, 19 grell (2–5 kHz).

## Maßnahmen

| Bereich | Maßnahme | Dateien |
|---|---|---|
| Karte | Statisches Blatt je Region **einmal** in eine `SubViewport`-Textur gebacken (`UPDATE_ONCE`, in der gezeigten Auflösung → gleich scharf), neu nur, wenn `static_key()` sich ändert; Leute/Aufträge/Hut als leichte eigene Ebene darüber. | `src/ui/map/map_canvas.gd` |
| Karte | Vorbacken beim `world_ready` und bei Regions-/Raumwechsel (Momente mit Blende) – das erste [M] malt nichts Großes. | `src/ui/ui_root.gd` (`prepare_map`), `src/ui/panels/map_panel.gd` (`prepare`) |
| Karte | Papier als Asset `assets/ui/map/map_paper_e3d4b0_9e8054.png` (Werkzeug `tools/map/bake_map_paper.gd`, identisch zur Laufzeit-Berechnung, die nur noch als Rückfall bleibt). | `src/ui/map/map_paint.gd`, `map_legend.gd` |
| Ton Web | `audio/driver/output_latency.web=150` → ScriptProcessor-Puffer **8192 Frames ≈ 186 ms** (gemessen im Browser: vorher 2048). Ein Frame-Ruckler bis ≈ 180 ms bleibt unhörbar. Preis: Klänge ≈ 0,15 s später. | `project.godot` |
| Ton | Einzelklänge (141 Dateien) als WAV → Godot-Import **QOA** (kein Vorbis-Dekodieren je Stimme); Schleifen/Musik bleiben Vorbis. Alle Streams sind Abhängigkeiten der Cue-Bibliotheken (beim Start geladen, kein `load()` beim Abspielen – Test). | `tools/audio/build_audio.py`, `data/audio/cues_*.tres` |
| Ton | Emitter-Schleifen nur innerhalb ihrer Reichweite + 4 m, sonst gestoppt. | `src/systems/audio/audio_world.gd` |
| Ton | Pausemenü/Panels: alle Player laufen unter der Baum-Pause weiter (geprüft, Test). Überblendung der Beds/Musik ohne neue Player (war schon so). | – |
| Wind | Neu: 48-s-Schleife, unregelmäßige Böenkurve (viele Komponenten mit 1/f-Abfall, weiche Sättigung, nie unter 45 %), drei Bänder ohne Resonanz, heller Anteil folgt der Böe leicht verzögert, Laub nur in den Böen (1,2–5 kHz); Windböen-Spot ohne Rauschkörner; 2–3 dB leiser; Vögel 1,6 × seltener, Grillen weniger/leiser. Dorf und Wald-Rand ebenso. | `tools/audio/ambience.py`, `data/audio/ambience/*.tres` |
| Pegel | Ziel-Lautheiten je Kategorie, `volume_db` aus der gemessenen Lautheit (BS.1770), `target_lufs` je Cue; DC-Hochpass, 5/10 ms Blenden, 2–5-kHz-Absenkung bei grellen Klängen, Varianten auf ±1,5 dB angeglichen; Schritte 6 statt 4 Varianten, Tonhöhe ±9–10 %, Pegel ±2,5 dB. | `tools/audio/build_audio.py`, `loudness.py`, `analyze_audio.py` |

## Messung – Frame-Zeiten (vorher → nachher)

Sonde `src/debug/perf_probe.gd` (gleicher Ablauf auf allen Plattformen: neues Spiel → Karte 3 × öffnen/schließen → Blattwechsel → Friedhof ablaufen → Tageszeit 19:00 / 21:30 / 09:00 → Hütte → Gruft → Dorf → Dorf ablaufen → Gaststube → zurück → Karte). Je Szenario die **größte Frame-Zeit** in ms, bei Desktop headless in Klammern die **Zahl der Frames > 50 ms**.

- **Desktop headless** (`--headless`, nur CPU – GDScript, Szenenaufbau; der Normalframe ist ≈ 7 ms): die Spalte zeigt, was der Code kostet.
- **Desktop lavapipe** (Forward+, Software-Vulkan, 1280 × 720) und **Web** (Chromium + SwiftShader, Compatibility, 1280 × 720, ohne Threads): im Container rendert die CPU – jeder Frame dauert hier 0,7–2,5 s, auf dem PC des Benutzers ≈ 16 ms. Aussagekräftig ist nur der **Zuschlag** gegenüber dem Normalframe (`idle`).

| Szenario | Desktop headless: max ms (>50 ms) vorher → nachher | Desktop lavapipe: max ms vorher → nachher | Web (Chromium/SwiftShader): max ms vorher → nachher |
|---|---|---|---|
| new_game | 2265 (1) → 2155 (1) | 6801 → 5735 | 5838 → 7621 |
| idle_graveyard | 9 (0) → 9 (0) | 1338 → 1169 | 2212 → 2381 |
| map_open_1 | 182 (1) → 9 (0) | 2706 → 1221 | 4799 → 2579 |
| map_close_1 | 8 (0) → 8 (0) | 871 → 852 | 2570 → 2215 |
| map_open_2 | 68 (1) → 8 (0) | 2779 → 958 | 3280 → 2121 |
| map_close_2 | 21 (0) → 8 (0) | 1004 → 964 | 3137 → 2303 |
| map_open_3 | 70 (1) → 9 (0) | 2311 → 918 | 3367 → 2254 |
| map_close_3 | 8 (0) → 9 (0) | 953 → 934 | 3150 → 2252 |
| map_tab | 104 (3) → 10 (0) | 3238 → 964 | 4647 → 2147 |
| walk_graveyard | 11 (0) → 11 (0) | 892 → 944 | 2406 → 2133 |
| time_dusk | 28 (0) → 25 (0) | 899 → 1105 | 2276 → 2310 |
| time_night | 12 (0) → 9 (0) | 887 → 1159 | 2154 → 3067 |
| time_day | 33 (0) → 34 (0) | 849 → 1210 | 2095 → 2895 |
| room_hut | 11 (0) → 10 (0) | 772 → 1063 | 2226 → 2862 |
| room_crypt | 23 (0) → 25 (0) | 893 → 3494 | 3150 → 4476 |
| region_village | 16 (0) → 23 (0) | 796 → 1037 | 2289 → 2181 |
| walk_village | 12 (0) → 13 (0) | 696 → 733 | 1542 → 1482 |
| room_inn | 60 (1) → 61 (1) | 384 → 367 | 1598 → 1431 |
| region_back | 50 (0) → 54 (1) | 898 → 994 | 2565 → 1889 |
| map_open_village_after | 83 (1) → 98 (1) | 2294 → 869 | 3790 → 1863 |

**Lesart:** Karte öffnen kostete auf Desktop 68–182 ms reine CPU-Zeit (jedes Mal, nicht nur beim ersten Mal), der Blattwechsel 104 ms – nachher 8–10 ms, also ein normaler Frame. Mit Renderer kostete jedes Öffnen 1,4–2,6 s über dem Normalframe (lavapipe) bzw. 1,1–2,6 s (Browser) – nachher kein Zuschlag mehr (2,1–2,6 s im Browser = Normalframe dieses Containers). Der einmalige Back-Aufwand fällt nun beim Laden bzw. beim Raumwechsel an (Gruft 3,5 s in lavapipe: dort wurde nach „buildings open / build crypt“ neu gebacken – im Spiel hinter der Tür-Blende).

**Web-Ton:** Im Container blockiert der Software-Renderer den Hauptthread pro Frame ≈ 2 s (Long-Task-Messung), dort setzt der Ton zwangsläufig aus – vorher wie nachher. Gemessen wurde darum, was der Browser bekommt: ScriptProcessor-Puffer **2048 → 8192 Frames (46 → 186 ms)**, Mischzeit je Frame unverändert (≈ 0,15 µs pro Ausgabe-Frame; 0,3 ms je 2048er-, 1,0–2,6 ms je 8192er-Rückruf). Auf dem PC des Benutzers sind die Frames ≈ 16 ms; Ruckler bis ≈ 180 ms (Karte vorher, Raumwechsel ≈ 60 ms Desktop-CPU ≈ 150 ms im Browser) unterbrechen den Ton nicht mehr.

### Weitere Spitzen (nicht behoben, begrenzt)

| Spitze | Desktop-CPU | Ursache | Stand |
|---|---|---|---|
| Neues Spiel / Laden | ≈ 2,2 s | Weltaufbau | einmalig hinter dem Ladebild, unverändert |
| Gaststube betreten | ≈ 60 ms | Raum aktivieren | im Browser ≈ 150 ms < 186 ms Puffer, hinter der Tür-Blende |
| Zurück zum Friedhof | ≈ 54 ms | Regionswechsel + Karte vorbacken (nur bei Änderung) | hinter der Reise-Blende |
| Erster Anblick eines Materials (Browser) | – | WebGL kompiliert Shader beim ersten Zeichnen | nicht messbar im Container (Software-GL); eine Vorkompilierung aller Materialien beim Laden wäre der nächste Schritt, wenn der Benutzer weiter Ruckler beim ersten Betreten eines Raums hört |

## Messung – Lautheit und Klangqualität (vorher → nachher)

`python tools/audio/analyze_audio.py` (alle Dateien, Werte im Spiel = Datei + `volume_db`, vor den Reglern). Einzelwerte je Datei: `audio_list.md`, Abschnitt „Analyse Runde 2“.

| Kategorie | Ziel (LUFS) | vorher Median (Spanne) | nachher Median (Spanne) |
|---|---|---|---|
| Atmosphäre (Beds) | -35 | -36.3 (-41 … -32) | -35.0 (-36 … -35) |
| Welt-Schleifen (Bach, Esse) | -30 | -34.2 (-42 … -27) | -30.0 (-30 … -30) |
| Spots (Vögel, Eule …) | -39 | -40.2 (-54 … -29) | -39.0 (-40 … -37) |
| Musik | -28 | -27.5 (-29 … -26) | -28.0 (-28 … -28) |
| Geräusche (SFX) | -27 | -30.6 (-44 … -21) | -27.0 (-33 … -24) |
| Schritte | -42 | -41.1 (-45 … -34) | -42.3 (-45 … -40) |
| UI | -38 | -39.1 (-58 … -35) | -38.0 (-48 … -38) |

| Befund (ohne Pegel) | vorher | nachher |
|---|---|---|
| dc | 13 | 0 |
| edge-click | 8 | 0 |
| harsh | 19 | 0 |
| Dateien | 154 | 162 |
| Dateien mit Befund (inkl. Pegel ±3 dB) | 112 | 0 |

Ziele (LUFS im Spiel): Atmosphäre −35 (Friedhof/Wald draußen −36, vorher −32/−33), Welt-Schleifen −30, Spots −39, Musik −28 (mit Musikregler 0,55 ≈ −33), Geräusche −27, Schritte −42 (Gras −43), UI −38 (Klick −40, Hover −48), Glocke −24. Die Werte liegen bewusst unter den Beispielwerten des Auftrags (−30/−24/−20/−26): sie halten die bisherige Gesamtlautstärke (die Spielregler bleiben, wo sie sind) und stellen die gewünschte Rangfolge her – Geräusche vorn, Musik ≈ 6 dB und Atmosphäre ≈ 8–9 dB dahinter, Schritte (≈ 15 dB unter den Geräuschen, jetzt 6 Varianten mit ±10 % Tonhöhe und ±2,5 dB) und UI leise. Die Streuung innerhalb einer Kategorie sinkt von bis zu 25 dB auf ≤ 5 dB.

Hörprobe **`audio_preview_v2.ogg`** (129 s): gleiche Abfolge wie `audio_preview.ogg`, danach 20 s nur Friedhof-Wind draußen am Tag und 20 s in der Nacht. Spektrogramme: `spectro_wind_day_before.png` / `_after.png`, `spectro_wind_night_before.png` / `_after.png`.

## Tests

- `tests/unit/test_map.gd`: Blatt wird einmal gebacken, Wiederöffnen backt/malt nichts, eine Änderung (Lindenacker freigegeben) backt genau einmal neu; `prepare_map()` backt vor dem ersten Öffnen; Papier kommt aus dem Asset und gleicht der Berechnung.
- `tests/unit/test_audio_quality.gd` (neu): alle Dateien mit Godots eigener Wiedergabe dekodiert – kein Clipping, Einzelklänge beginnen/enden still, Schleifen ohne Sprung am Nahtpunkt, jeder Cue in ±4,5 dB um `target_lufs` (K-gewichtet), Einzelklänge WAV/QOA und Schleifen Vorbis, Schritte variieren, Web-Puffer ≥ 100 ms, Laufzeit-Module ohne `load()`, alle Player laufen unter der Pause weiter, Emitter außer Reichweite gestoppt.
- `tests/unit/test_audio.gd`: Dateiendung je Art angepasst.

## Grenzen

- Im Container rendert die CPU; absolute Browser-Zeiten sind 100 × langsamer als auf einem PC. Die Verbesserung ist relativ belegt (Karte: Zuschlag weg; Puffer: × 4). Ob der Ton auf dem PC des Benutzers jetzt durchgehend sauber ist, muss er hören.
- 186 ms Puffer heißt ≈ 0,15 s spätere Klänge (Schritte, Klicks). Wirkt es träge, ist 100 ms (4096 Frames, ≈ 93 ms) der Kompromiss.
- Shader-Kompilierung beim ersten Anblick eines Materials im Browser ist nicht behandelt (siehe oben).
- WAV-Quellen vergrößern das Repo (17,7 MiB Klangquellen statt 6,1 MiB); das Web-Paket wächst um 2,2 MB (QOA + doppelt lange Wind-Schleifen).
