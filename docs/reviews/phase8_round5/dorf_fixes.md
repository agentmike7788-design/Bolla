# G8 Runde 5 – Dorfbewohner: die bekannten Probleme aus Runde 4

Benutzerauftrag: „bitte die bekannten probleme mal fixen" – die drei offenen Befunde aus `docs/reviews/phase8_round4/dorf_arbeit.md` §5 (Fenner am Amtstisch, Jakobs Besen im Krug, Lenz mit dem Rücken zur Kamera).

## 1. Bürgermeister Fenner am Amtstisch (`desk_files`)

**Vorher:** Er stand 0,67 m hinter der Tischmitte, die Akten und das Siegel lagen auf der Kameraseite des Tisches; die Linke blätterte nur an der vorderen Kante (0,30 m vor ihm, die Kante liegt bei 0,31 m), der Stempel (5 cm) war aus der Spielkamera kaum zu sehen. Weiter beugen ging nicht: die Rechte hielt den Amtsstab lotrecht, er wäre in den Tisch gekippt.

**Jetzt:**
- **Der Stab lehnt am Tisch**, solange er arbeitet: Der Stab ist nicht mehr Teil des Körper-Meshes, sondern das Kindmesh `prop_staff` an `arm_r` (gleiche Geometrie, gleiche Bemalung, gleiches Figurenlicht) mit `hide_with: desk_files`; dazu `prop_staff_rest` am `root` (`show_with: desk_files`), an das rechte Tischende gelehnt (Zwinge auf dem Boden neben dem Tisch, Schaft über der Tischkante). Tritt der Totengräber heran, hat er ihn wieder in der Hand (Pause = `idle`); am Aushangbrett (`proclaim`) bleibt er in der Hand.
- **Beide Hände arbeiten über dem Tisch** (0,45–0,58 m vor ihm, Tischkante 0,24 m): die Linke blättert im Aktenstapel, die Rechte drückt den Stempel aufs Stempelkissen, hebt ihn hoch (1,18 m) und stempelt das Blatt; der Rumpf beugt sich 20–24° vor, die Hüfte geht etwas zurück (der Rock bleibt frei vom Tisch). Die Posen sind auf die Lage der Requisiten gerechnet (`asset_villager_work.py`, `MY_*`).
- **Stempel größer:** 11 × 8 cm Messingblock mit roter Stempelfläche, dunkler Holzknauf (44 Dreiecke).
- **Requisiten auf dem Tisch** (`ph_int_office_desk` neu exportiert, auf Fenners Seite): Aktenstapel in brauner Mappe mit rotem Aktenband, Stempelkissen (Blechkasten, rotes Kissen), die losen Blätter vor ihm, eines schon gestempelt.
- Stehplatz `v_in_office_desk` 7 cm näher (z −2,12 → −2,05, 0,6 m hinter der Tischmitte; Layout + Szene).
- Budget: 8994 Dreiecke (≤ 9000): Körper 8590 + Stab 148 + angelehnter Stab 34 (gröber) + Stempel 44 + Aushang 32 + Laterne 146.

## 2. Jakob fegt abends im Krug (`sweep`)

**Vorher:** `v_in_inn_jakob` (−2,2 | 1,08) liegt direkt hinter dem Tisch am Westfenster (von der Kamera aus davor); um −120° gedreht sah man den Besen nur am Stiel.

**Jetzt:** eigener Fegeplatz **`v_in_inn_sweep`** (−2,4 | −0,35, Blick 80° in die Stube) auf dem freien Boden vor dem Schanktisch zwischen Treppe und Mitteltisch. Der Besenkopf fegt vor ihm über die Dielen, nichts steht zwischen ihm und der Kamera. Der Ort steht in den Daten (`NpcWorkConfig.runtime_spots`: `apprentice_inn` → `v_in_inn_sweep`), `Apprentice.village_schedule` läuft abends dorthin (Weg `v_road_in → v_bridge → v_inn_door → v_in_inn_sweep`), der Daten-Fallback-Zeitplan (`apprentice_schedule.tres`, 17:00) ebenfalls; Frühstück, freier Tag, Kathreintanz und Lichtgang bleiben an `v_in_inn_jakob`. Die Sonderrichtung −120° in `work_facing` ist entfallen.

**Kollision und Wege** (`test_interiors.test_g8r5_work_places_seen_from_the_game_camera`, echte Welt, Physik): Strahl vom Besenkopf und von seinen Füßen zur Spielkamera frei; die Kapsel des Totengräbers passt auf den Fegeplatz, an ihm vorbei (−1,6 | −0,35, 0,9 m Durchgang zum Mitteltisch), vor Rosine am Schanktisch (−2,0 | −1,25) und hinter ihm zur Treppe (−2,4 | 0,45). Der Kathrein-Tanzboden (x −1,15…1,85) wird nicht berührt.

## 3. Pfarrer Lenz am Altar (`pray_altar`)

**Vorher:** vor der Chorstufe (0 | −2,3) zum Altar gewandt – aus der Spielkamera nur der Rücken.

**Jetzt: hinter dem Altar mit Blick ins Kirchenschiff, wie bei der Messe.**
- Kirchen-Szene geprüft: hinter dem Altar waren nur 5 cm bis zur Nordwand (die Altarstufe reichte bis an die Wand). Der Altar rückt 0,45 m vor (z −3,85 → −3,4, Stufe endet 15 cm vor der Chorkante), Lenz steht auf dem Chor dahinter (0 | −4,18, Blick 0° = zur Kamera; Mitte 0,32 m vor der Nordwand, 0,3 m hinter der Altarplatte).
- **Bodenhöhe:** Raum-Wegpunkte können jetzt eine vierte Zahl tragen, die Bodenhöhe (`[x, z, Blick°, Höhe]`, `interior_build.gd`); Lenz steht auf dem 0,18 m hohen Chor statt darin zu versinken.
- **Altar der Dorfkirche = eigenes Modell `ph_int_altar_church`** (gleiche Funktion, `facing_nave=True`): das Altarkreuz steht an der Vorderkante zum Volk – hinten stehend lag es aus der Spielkamera genau vor seinem Gesicht –, das Buch liegt auf seiner Seite, zu ihm geöffnet. Die Kapelle behält `ph_int_altar` bytegleich.
- **Gebetsgeste weiter und höher** (`PR_ORANS`): die Hände gehen weit auseinander hoch über die Schultern (1,64 m, 0,8 m Spanne), ein V, das sich von vorn liest; die Verneigung geht über den Altar.
- Er bleibt ansprechbar: von der Chorkante (Spieler ≥ 1,75 m entfernt) erreicht ihn die Interaktion; kommt der Totengräber näher als 2,8 m, unterbricht er und schaut ihn an. Der Sonderwinkel 180° in `work_facing` ist entfallen.

## 4. Bilder (echte Spielkamera, 1280 × 720, xvfb + lavapipe)

Vorher-Stand = Commit 3a75fb3 (Kopie), nachher = dieser Stand, gleiches Skript `village_shots_work.gd`, gleicher Spielstand (`slot_p7_day53_neighbor`, Tag 54), je Forward+ und Browser-Look (`--rendering-method gl_compatibility --rendering-driver opengl3`, `_web`). Obere Reihe Nahkamera von der Kameraseite, untere Reihe die Spielkamera 1 : 1; sechs Momente des Clips, letzte Spalte: der Totengräber tritt heran.

| Figur | vorher | nachher |
|---|---|---|
| Fenner, Amtstisch 09:00 | `dorf_buergermeister_vorher(_web).jpg` | `dorf_buergermeister_nachher(_web).jpg` |
| Jakob, Krug 17:30 | `dorf_jakob_vorher(_web).jpg` | `dorf_jakob_nachher(_web).jpg` |
| Lenz, Altar 16:30 | `dorf_pfarrer_vorher(_web).jpg` | `dorf_pfarrer_nachher(_web).jpg` |

## 5. Assets und Hashes

- Neu exportiert: `ph_chr_v_mayor` (Körper ohne Stab → Hash in `test_assets_phase8.REEXPORT` bewusst nachgezogen, alte Clips idle/talk/walk hash-gleich; `desk_files` neu, `proclaim` mit etwas lebhafterer Linken, Kindmeshes `prop_staff`, `prop_staff_rest`, neuer `prop_stamp` an `arm_r`), `ph_chr_v_priest` (nur `pray_altar` geändert, Körper hash-gleich), `ph_int_office_desk` (Requisiten), neu `ph_int_altar_church`. Unverändert: `ph_int_altar` (bytegleich), alle anderen Figuren.
- Glb-Export deterministisch (Fenner zweimal gebaut, md5 gleich).

## 6. Tests

- `tests/unit/test_npc_work.gd`: Stempel an `arm_r` in der Faust; Fenners Hände immer ≥ 0,40 m vor ihm (über dem Tisch), der Stempel kommt herunter (0,84–0,90 m) und hoch (> 1,12 m); `test_fenner_leans_his_staff_against_the_desk` (Kindmeshes, Knochen, Extras, Lage am Tischende); `test_church_altar_faces_the_nave` (Kreuz vorn im Kirchenaltar, hinten in der Kapelle; Wegpunkt mit Chorhöhe); Lenz’ Arme > 1,55 m und weit gespreizt; `runtime_spots`/`spot_for`; Jakobs 17-Uhr-Eintrag am Fegeplatz; keine Sonderrichtung mehr für Altar und Jakob.
- `tests/integration/test_npc_work.gd`: Lenz arbeitet mit 0° (zur Kamera), Jakob am Fegeplatz mit Besen (Arbeit, Pause, Gespräch, weiter); `test_fenner_takes_up_his_staff_for_the_gravekeeper`.
- `tests/integration/test_interiors.gd`: `test_g8r5_work_places_seen_from_the_game_camera` (s. o.).
- `tests/unit/test_assets_phase6.gd`: `ph_int_altar_church` in Maßen, Markern, Kerzenflammen.

## 7. Offen

- Die Porträt-Icons (`src/ui/tools/icon_renderer.gd`, nicht neu gerendert) blenden Kindmeshes aus – würde Fenners Porträt neu erzeugt, fehlte der Knauf des Stabs am unteren Bildrand.
- Der angelehnte Stab und die Tischrequisiten sind auf Fenners Stehplatz 0,6 m hinter der Tischmitte gerechnet (Test prüft das); wird der Tisch verschoben, muss der Platz mitwandern.
- `tools/dialogue/build_phase8_schedules.py` kennt die Arbeits-Clips aus Runde 4 noch nicht (die `.tres` wurden in Runde 4 von Hand gepflegt); Runde 5 hat nur Jakobs 17-Uhr-Eintrag in der `.tres` umgestellt.
