# G8 Runde 6 – Bitten vom Hügel

Benutzerkritik (Gate G8): „wen man eine leiche begraben hat dann hat man bis am nächsten morgen nichts mehr zu tun das ist ein wenig langweilig da fehlt kontent“.

Benutzerentscheidung (12.10.2026): **nur Paket A „Bitten vom Hügel“**. Nicht gebaut: Grabpflege-Waren ab Tag 1 bei Osric, „Warten bis …“, mehr Leichen, Angeln vorziehen. Vertrag: `docs/PHASE8_DESIGN.md`, Abschnitt „G8 Runde 6 – Bitten vom Hügel“ (mit dem Vermerk: Gemeinde-Bitten mit Frist und Abklingzeit, keine Sofortbelohnungs-Tagesquests).

## Was gebaut ist

- **Torafel wird interaktiv.** Die Tafel `NoticeBoard` am Friedhofstor (−1,5 | 8,7) bekommt ein `Interactable` (Priorität 5 wie die Stationen). Ab Tag 2 steht dort „[E] Bitten am Tor lesen“. Kein neues Modell, kein Eingriff ins Layout. Für jede offene Bitte hängt unten an der Tafel ein Zettel „Bitte“ mit rotem Stift (`ph_notice_slip`, `ph_notice_pin`: Code-Meshes mit `mat_painted`, wie `ph_door_note`). Die Bewertung und der Ruf auf der Tafel bleiben.
- **Panel `hill_requests`** (`HillRequestsPanel`): rechts angedockt unter der HUD-Leiste wie die Panels der Runden 4/5, ohne Abdunklung. Eine Karte je Bitte:
  - Titel, Geber, Text
  - Frist („Frist: 2 Tage“ / „noch 1 Tag“ / „heute der letzte Tag“), wie lange eine offene Bitte noch hängt
  - Lohn, bei Abgaben der Ort („Abgabe bei Osric am Karren …“)
  - „Annehmen“ (gedimmt mit Grund, z. B. „2 Bitten laufen schon.“)
  - Maus und Tastatur: ↑/↓ bzw. Tab, Enter, Esc. Nach dem Annehmen springt der Fokus zur nächsten Karte.
- **HUD-Ziel:** „Bitte: Unkraut am Tor (noch 2 Tage)“ bzw. „Bitte: Drei Scheite für Osric – bei Osric abgeben“.
  - Vor dem Dorf steht es gleich nach der Leichenarbeit, danach hinter den Zeilen der Phasen 7/8.
  - Hängt eine Bitte und darf man noch eine annehmen, steht tagsüber im Leerlauf (und statt der bloßen Notiz „Eine Grube wartet noch“) „Eine Bitte am Tor wartet“ / „Zwei Bitten am Tor warten“. Pflege, Abschnitte und Werkhof-Zeilen bleiben davor.
- **Leerlauftext korrigiert:** „Feierabend – Ausruhen am Bett in der Hütte“ und „Feierabend – Schlafen am Bett in der Hütte“ (vorher „… an der Hüttentür“).
- **Merkbuch:** neuer Reiter „Bitten“, sobald die erste Bitte hing. Links die angenommenen Bitten und was am Tor hängt, rechts erledigt/versäumt mit Tag.
- **Osric:** im Menü von `carter.tres` (auch im kalten Menü) „[Bitte] Das hier ist für die Leute unten.“ (`hill_ready:carter` → `hill_turn_in:carter`). Er lädt es auf: „Für unten? Ich sag ihnen, es kommt vom Hügel. Dann wissen sie schon, von wem.“
- **HUD-Notizen:**
  - um 07:44 „Osric hat eine Bitte ans Tor geheftet.“ / „… zwei Bitten …“
  - beim Annehmen „Angenommen: …“
  - bei Erfüllung die Dankesnotiz des Gebers und „Bitte erfüllt: <Titel> – 2 Münzen · Ruf +1“
  - beim Verfall „Zu spät: …“

## Regeln (alle Werte in `data/config/hill_requests_config.tres`)

| Wert | vor `village_open` | ab `village_open` |
|---|---|---|
| Plätze am Tor | 2 | 1 |
| gleichzeitig angenommen | 2 | 1 |
| freier Platz wird neu belegt | am nächsten Morgen | am dritten Morgen |

- **Beginn:** ab Tag 2, Osric heftet um 07:44 an (nach Lieferung und Torglocke).
- **Ablauf:**
  - Eine offene Bitte hängt 2 Tage und wird dann folgenlos abgenommen.
  - Eine angenommene hat 1–3 Tage Frist. Die Prüfung läuft um 06:00 wie bei den Aufträgen: angenommen an Tag D mit 2 Tagen → fällig am Morgen von D + 2.
  - Verfall kostet **−1 Ruf**, keine Münzen.
- **Lohn:** Ruf +1 und 1–3 Münzen (im Schnitt 1,8; Abgaben, die Holz oder Stein kosten, zahlen 2–3, was man ohnehin am Toten oder am Grab tut 1–2), bei 3 der 18 Bitten ein kleines Ding (1 Leinen, 1 Honigkuchen, 1 Samen). Keine Beziehungspunkte, die Phase-7-Stufen bleiben unberührt.
- **Wiederholung:**
  - Abklingzeit je Bitte 6–8 Tage ab ihrem Ende.
  - Nie zwei Bitten desselben Gebers zugleich am Tor.
  - Die Auswahl ist deterministisch (`hash([Tag, Platz, id])`, keine globale Zufallszahl), sodass die Bots bitgleich laufen.
- **Zählung:** Bitten sind keine Aufträge. `Orders` kennt sie nicht, sie zählen weder für „6 Aufträge von 4 Gebern“ noch für `stats.orders_done` oder die Grenzen 4 / 2 (Test `test_requests_never_count_for_the_village_chapter`).
- **Speichern:** kein neues Format, v7 bleibt.
  - Neuer Knoten `Systems/HillRequests` (`save_id hill_requests`, 80).
  - Fehlt sein Eintrag (alle Stände vor dieser Runde), lädt er still seinen Grundzustand (`save_optional`, `SaveStateCollector.apply_nodes`).
  - Ein v6-Stand (Tag 53, Dorf offen) bekommt am nächsten Morgen eine Bitte.

## Pool (18 Bitten, `data/hill_requests/*.tres`, `OrderData` mit `category = hill`)

Alle Bitten sind mit den Mitteln von Tag 2–13 lösbar: Holz, Stein, Werkbank, Grab, Gruft-Tisch, Roden, Unkraut und Laub, Geister. Dorfläden und Werkhof-Teile braucht keine.

| id | Auftraggeber | Bitte – Aufgabe | Frist | Lohn | Abklingzeit |
|---|---|---|---|---|---|
| `hr_osric_wood` | Osric Faulhaber | Drei Scheite für Osric – 3 Holz bei Osric abgeben | 2 Tage | 2 Münzen · Ruf +1 | 6 Tage |
| `hr_esch_stone` | Ulrich Esch | Zwei Steine für die Esse – 2 Steine bei Osric abgeben | 2 Tage | 2 Münzen · Ruf +1 | 6 Tage |
| `hr_sieber_cross` | Johann Sieber (Trauernder) | Ein Kreuz für den Hohlweg – 1 Holzkreuz (Werkbank) bei Osric abgeben | 3 Tage | 3 Münzen · Ruf +1 | 8 Tage |
| `hr_quast_exam` | Severin Quast | Ein Befund für den Wundarzt – einen Toten gründlich untersuchen (alle 4 Schritte); Name und Todesursache stehen in der Dankesnotiz | 2 Tage | 1 Münze · Ruf +1 | 6 Tage |
| `hr_liesel_wash` | Liesel Dorn | Gewaschen und gekleidet – einen Toten gewaschen und im Leichentuch/Totenhemd bestatten | 2 Tage | 1 Münze · Ruf +1 · 1× Leinen | 6 Tage |
| `hr_lenz_stone` | Pfarrer Ambrosius Lenz | Ein Stein, der bleibt – einem Bestatteten einen Grabstein setzen (kein Holzkreuz) | 3 Tage | 2 Münzen · Ruf +1 | 7 Tage |
| `hr_kehr_gate` | Martha Kehr (Trauernde) | Unkraut am Tor – die beiden Unkrautstellen am Tor jäten | 2 Tage | 2 Münzen · Ruf +1 | 6 Tage |
| `hr_brandt_grave` | Hinrich Brandt (Trauernder) | Das Grab von ‹Name› – ein belegtes, verschmutztes Grab säubern (beim Aushängen gewählt) | 2 Tage | 1 Münze · Ruf +1 | 6 Tage |
| `hr_rosine_leaves` | Rosine Wackernagel | Laub unter der Eiche – vier Laubstellen rechen (nur mit Rechen) | 2 Tage | 1 Münze · Ruf +1 · 1× Honigkuchen | 6 Tage |
| `hr_ott_ghost` | Gesa Ott (Trauernde) | Was die Toten sagen – nachts einem Geist zuhören; seine Worte stehen in der Notiz | 2 Tage | 1 Münze · Ruf +1 | 7 Tage |
| `hr_fenner_clear` | Gottlieb Fenner | Platz für die Nächsten – ein Hindernis auf Ostwiese, Birkenhang oder im Holunderwinkel roden | 3 Tage | 2 Münzen · Ruf +1 | 6 Tage |
| `hr_esch_vase` | Ulrich Esch | Eine Vase für die Gräber – eine Grabvase aufstellen (ab Tag 3) | 3 Tage | 2 Münzen · Ruf +1 | 8 Tage |
| `hr_mangold_bench` | Theres Mangold | Eine Bank zum Ausruhen – eine Holz- oder Steinbank aufstellen (ab Tag 3) | 3 Tage | 2 Münzen · Ruf +1 · 1× Samen | 8 Tage |
| `hr_lenz_ghost` | Pfarrer Ambrosius Lenz | Ein Wort für die Unruhigen – nachts einem Geist zuhören | 2 Tage | 1 Münze · Ruf +1 | 8 Tage |
| `hr_rosine_wood` | Rosine Wackernagel | Holz für den Holderkrug – 4 Holz bei Osric abgeben | 2 Tage | 3 Münzen · Ruf +1 | 6 Tage |
| `hr_fenner_stone` | Gottlieb Fenner | Steine für den Grenzweg – 4 Steine bei Osric abgeben | 3 Tage | 3 Münzen · Ruf +1 | 7 Tage |
| `hr_liesel_paths` | Liesel Dorn | Freie Wege zwischen den Gräbern – zwei Unkrautstellen am Mittelweg jäten | 2 Tage | 1 Münze · Ruf +1 | 6 Tage |
| `hr_osric_laidout` | Osric Faulhaber | Ordentlich aufgebahrt – einen Toten gewaschen, gekleidet und aufgebahrt bestatten | 2 Tage | 2 Münzen · Ruf +1 | 7 Tage |

Geber: alle sieben Dorfbewohner (Rosine, Esch, Theres, Lenz, Fenner, Quast, Liesel), Osric und vier Trauernde (Martha Kehr, Hinrich Brandt, Gesa Ott, Johann Sieber). Die Texte sind eigene, warm und leicht melancholisch, z. B. Liesel: „Jetzt geht man wieder gerade. Das ist gut. Trauer geht krumm genug.“

**Erfüllung** über vorhandene EventBus-Signale bzw. Systeme:

| Art | Erfüllt durch |
|---|---|
| `deliver` | Osrics Dialog |
| `tend` | `dirt_changed`: alle Stellen sauber, mindestens eine nach der Annahme gepflegt |
| `exam` | `exam_step_done`: ein Toter vollständig untersucht |
| `prep` | `corpse_buried` mit gewaschen/gekleidet/aufgebahrt |
| `marker` | `grave_completed` mit dem verlangten Zeichen |
| `ghost` | `ghost_spoke` |
| `clear` | `obstacle_cleared` im Abschnitt |
| `decor` | `decor_changed` (gesetzt) |

Angebotsbedingungen, damit nichts Unlösbares aushängt:

- Pflege nur bei schmutzigen Stellen, Laub nur mit Rechen im Besitz.
- Roden nur bei einem bearbeitbaren Abschnitt mit Hindernis.
- Leichen-Bitten nur bei einer freien Grabstelle.
- Geist nur bei einem Grab mit Zeichen.

## Bot-Messung (Tag 1–14, vorher/nachher)

Gemessen mit `tests/integration/test_hill_requests_bot.gd` (`HillBot`, abgeleitet von `Phase4Bot`): echte Welt, neues Spiel, Tag 1–14, `Player.instant_actions`. Die Bot-Arbeit kostet die echten Spielminuten der Handlungen, dazu 3 Minuten je Gang. „Arbeit bis“ ist die Uhrzeit nach der letzten Tagesarbeit, also vor Osrics Abendabgabe, den Geistern und dem Bett. „Leerlauf“ zählt die Minuten bis 18:00, ab dann steht im HUD „Feierabend – Schlafen …“. 1 Spielminute = 0,5 s.

**Spieler „Pflicht“** (die Kritik des Benutzers): Leichen, Gräber und das Roden, das das HUD verlangt, wenn kein Platz mehr frei ist. Kein Pflegen, keine Zier, keine Geister, kein Nachthandel.

| Tag | vorher: Arbeit bis | vorher: Leerlauf | nachher: Arbeit bis | nachher: Leerlauf | Bitten erledigt (Σ) | Münzen aus Bitten (Σ) |
|---|---|---|---|---|---|---|
| 2 | 13:01 | 299 min | 13:04 | 296 min | 1 | 2 |
| 3 | 13:01 | 299 min | 13:37 | 263 min | 2 | 4 |
| 4 | 13:01 | 299 min | 12:31 | 329 min | 4 | 6 |
| 5 | 12:28 | 332 min | 15:25 | 155 min | 4 | 6 |
| 6 | 13:06 | 294 min | 21:19 | 0 min | 6 | 11 |
| 7 | 19:48 | 0 min | 14:36 | 204 min | 7 | 13 |
| 8 | 13:01 | 299 min | 13:04 | 296 min | 9 | 16 |
| 9 | 17:58 | 2 min | 19:10 | 0 min | 11 | 21 |
| 10 | 12:28 | 332 min | 13:21 | 279 min | 13 | 25 |
| 11 | 12:28 | 332 min | 12:31 | 329 min | 13 | 25 |
| 12 | 12:28 | 332 min | 12:28 | 332 min | 15 | 29 |
| **Σ Tag 2–12** | | **2820 min** | | **2483 min (−337, −12 %)** | 15 | 29 |
| Tag 14 | Münzen 51, Ruf 72 | | Münzen 105, Ruf 91 | | 18 erledigt, 0 versäumt | 32 |

**Spieler „Andächtig“** (`Phase4Bot` reverent: zusätzlich Pflege, Zier, Gräber aufwerten, Geister, Ilse): Leerlauf Tag 2–12 **1569 → 1581 min**, also unverändert. Erledigt sind 7 Bitten, 3 verfallen. Aus den Bitten kommen 11 Münzen und Ruf +6. Tag 14: Münzen 80 → 91, Ruf 100 → 99.

**Was das heißt:**

- **Pflicht-Spieler:**
  - Die Bitten bringen im Schnitt ≈ 40 Spielminuten Arbeit je Tag (512 min in 13 Tagen). Das sind ≈ 20 s Echtzeit beim Bot. Ein echter Spieler braucht für die Gänge zur Tafel, zu den Stellen und abends zu Osric deutlich mehr.
  - Wichtiger ist die Wirkung auf den Ablauf: Er rodet früher, stellt Vase und Bank auf und pflegt Stellen. Dadurch arbeitet er an den Tagen 5, 6 und 9 bis in den Abend, weil Plätze früher frei werden und Arbeit nachrückt.
  - Der Leerlauf sinkt um 12 %, an Tagen mit offener Pflichtarbeit bleibt er. Gegen Mittag bleibt an vielen Tagen weiter Zeit übrig. Die Bitten füllen einen Teil davon, nicht den ganzen Nachmittag. Das ist gewollt klein („kleine Bitten“, Paket A).
- **Andächtiger Spieler:** Er tut ohnehin fast alles, was die Bitten verlangen. Für ihn sind sie vor allem Anerkennung (Lohn, Dankesnotiz) und ein Ziel für den Tag.
- **Münzen:**
  - In der ersten Messung (2–4 Münzen, Ruf +1…+2) brachte der Pflicht-Spieler 43 Münzen und Ruf +26 aus den Bitten. Danach wurde der Lohn auf **1–3 Münzen (Schnitt 1,8) und Ruf +1** gesenkt.
  - Jetzt sind es 32 Münzen in 13 Tagen (≈ 2,5 je Tag) und Ruf +18.
  - Tag 14 hat er 105 statt 51 Münzen. Der Rest über die 32 hinaus kommt aus höherem Ruf (Lohnzuschlag) und besserer Friedhofsqualität, also aus den bestehenden Systemen, die die Bitten anstoßen.
  - Damit liegt er etwa beim andächtigen Spieler (80–91).
- **Bot-Ziele der bisherigen Tests:**
  - Kein bestehender Bot (Phase 3–8) nimmt Bitten an, die Auswahl braucht keine Zufallszahl. Deshalb laufen alle alten Bot-Tests bitgleich. Die Münzziele (≈ 11 je Grab, Münzen nie negativ, Phase-7/8-Bilanz 48/60 → Bogen) kippen nicht.
  - Nach `village_open` hängt höchstens eine Bitte mit drei Tagen Neubelegung. Das sind ≈ 1 Bitte je 4–5 Tage ≈ 0,4 Münzen je Tag, gegenüber Trinkgeld und Aufträgen der Phasen 7/8 vernachlässigbar.

## Bilder (echter Renderer, 1280 × 720; ohne Endung Forward+, `_web` = Compatibility/OpenGL wie im Browser)

Aufnahme: `GODOT=… tools/godot_run.sh --resolution 1280x720 -s res://src/world/graveyard/graveyard_shots.gd -- --out=<dir> --round6 [--suffix=_web]` (Modul `graveyard_shots_round6.gd`).

- Neues Spiel, Uhr still auf Tag 2, 10:10.
- Die Leiche von Tag 1 wird über die Graveyard-API bestattet, damit das HUD keinen Leichenschritt zeigt.
- Zwei Bitten werden angeheftet: „Unkraut am Tor“ und „Drei Scheite für Osric“.
- Danach laufen die echten Systeme und die echte UI.

| Bild | Inhalt |
|---|---|
| `tafel.jpg` / `tafel_web.jpg` | Die Tafel am Tor mit zwei Zetteln „Bitte“ und dem Hinweis „[E] Bitten am Tor lesen“. Nahaufnahme, Kamera 6 m statt der kleinsten Spiel-Zoomstufe 10 m |
| `panel.jpg` / `panel_web.jpg` | das angedockte Panel mit den offenen Bitten, Fokus auf „Annehmen“ |
| `annahme.jpg` / `annahme_web.jpg` | nach „Annehmen“: HUD-Ziel „Bitte: Unkraut am Tor (noch 2 Tage)“, Notiz „Angenommen: Unkraut am Tor“ |
| `merkbuch.jpg` / `merkbuch_web.jpg` | der Merkbuch-Reiter „Bitten“ |
| `erfuellt.jpg` / `erfuellt_web.jpg` | Unkraut am Tor gejätet: Dankesnotiz von Martha Kehr und „Bitte erfüllt: Unkraut am Tor – 2 Münzen · Ruf +1“, Münzen 11 → 13 |

## Tests

- `tests/unit/test_hill_rules.gd`: Config, Plätze/Grenzen vor und nach dem Dorf, Angebotsbedingungen je Art, deterministische Auswahl, Frist, Erfüllungsprüfungen, Lohnwörter. Für den Pool: Größe, Arten, Geber, kleine Werte, Lösbarkeit mit den frühen Mitteln, Texte.
- `tests/integration/test_hill_requests.gd` (echte Welt):
  - Tag 1 leer, Tag 2 um 07:44 zwei Bitten
  - Tafel und Panel: angedockt, Tastatur (Enter, Fokus weiter), Maus, Esc; HUD-Ziel, Merkbuch-Reiter
  - zwei gleichzeitig vor dem Dorf, eine danach, Neubelegung am dritten Morgen
  - Verfall −1 Ruf, Abklingzeit, Abnahme ohne Folgen
  - jede Art erfüllt: Abgabe über Osrics Dialog, Pflegestellen und Grab, Untersuchung, gewaschen/gekleidet, Grabstein statt Kreuz, Geist, Roden, Zier
  - Kapitelzählung unberührt
  - Speichern → Laden; v6-Stand ohne Warnung, danach eine Bitte
- `tests/unit/test_objective.gd`: HUD-Zeilen der Bitten und die korrigierten Leerlauftexte.
- `tests/integration/test_save_fuzzer.gd`:
  - `hill_requests` in den Pfadmutationen des echten Phase-8-Stands
  - neu `test_fuzz_v7_hill_requests` mit sieben gezielten Fällen: fehlender Knoten, falsche Typen, unbekannte ids, alles angenommen, Unsinn-Tage, kaputtes Protokoll, unbekanntes Zielgrab
  - Konsistenzprüfung: höchstens 2 am Tor, höchstens 2 angenommen, nur bekannte Bitten, keine Bitte ist ein Auftrag
- `tests/integration/test_hill_requests_bot.gd` + `hill_bot.gd`: die Bot-Messung oben.
- Angepasst:
  - `test_phase3_scaffold.gd`: die Tafel hat jetzt ein `Interactable`
  - `test_ui.gd`: Panel in DOCKED_PANELS und in den Kontexten
  - `test_dialogue.gd`: Grammatik `hill_ready`, `hill_turn_in`
  - `test_graveyard_world.gd`: Systemknoten `HillRequests`, Ladereihenfolge + `hill_requests`
  - `test_objective.gd`, `test_ui_phase3.gd`: Leerlauftext

## Offen

- Die Bitten nach `village_open` laufen mit denselben 18 Texten (ohne eigene Dorf-Bitten). Die Daten erlauben `conditions.phase = "village"` für spätere Bitten.
- Die Zettel sind Code-Meshes (Platzhalter `ph_notice_slip`/`ph_notice_pin`), kein eigenes Blender-Modell.
- Die Nahaufnahme der Tafel ist näher als die kleinste Spiel-Zoomstufe (10 m). Im Spiel sind die Zettel kleiner zu sehen, wie in `annahme.jpg`.
