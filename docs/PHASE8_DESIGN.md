# Phase 8 – NPCs – Vertrag v1

Status: **v1 – Entwurf zur Benutzerfreigabe (Vertragsfragen §14 offen), danach verbindlich für die Umsetzung** · Verantwortlich: Agent 01 (Lead), Agent 02 (Game Design), Agent 03 (World Design), Agent 06 (Character Art), Agent 07 (Animation), Agent 08 (Godot Core), Agent 10 (Graveyard System), Agent 12 (NPC/AI), Agent 13 (Quest/Story), Agent 17 (Audio), Agent 18 (UI/UX)
Baut auf `docs/PHASE7_DESIGN.md` (Vertrag v1, freigegeben 04.10.2026 nach Runde 2), `docs/PHASE6_DESIGN.md`, `docs/PHASE5_DESIGN.md`, `docs/PHASE4_DESIGN.md`, `docs/PHASE3_DESIGN.md` und `docs/VERTICAL_SLICE_DESIGN.md` auf. Was dieses Dokument nicht ändert, gilt dort unverändert weiter. Referenz-Build: **9353b74** (Gate G7 freigegeben, 2 472 Tests) **plus der parallel umgesetzte Gruft-Umbau** (Gruft Stufe 1 mit Treppe und Gruft-Tisch ab Spielbeginn, kein Tisch vor der Hütte; Leichenarbeit immer in der Gruft). Der Lead trägt den Hash des Stands mit Gruft-Umbau in die W0-Notizen ein; alle v6-Fixtures entstehen auf diesem Stand (§5.2).
Gameplay-Werte sind **Vorschläge**; der Benutzer prüft sie beim Gate G8. ART STYLE LOCK „Gemaltes Diorama" ist aktiv: Phase 8 ändert den Stil nicht. Maler-Shader (`painted.gdshader`, `painted_common.gdshaderinc`, `painted_foliage.gdshader`), Atmosphären-Presets, Flackerlicht (`flicker_light.gd`) und der gemeinsame Gesichtsaufbau (`tools/blender/lib_faces.py`) bleiben unverändert und werden für alle neuen Figuren **wiederverwendet**. Friedhof, Dorf, alle Gebäude und Innenräume bleiben bitgleich, **außer** den in §4.7 vollständig aufgezählten Eingriffen (dritte Reihe im Lindenacker, Besucherplätze an den Gräbern, Lehrlingsecke an der Hütte, Pfarrarchiv in der Kirche, Krankenlicht-Fenster, Stände von Bettler und Händlerin, Kathrein-Schmuck in der Gaststube).

**Benutzerentscheidungen (verbindlich, 04.10.2026)**
- **Inhalt, alle vier Teile:**
  1. **Lebendigere Dorfbewohner:** reden miteinander, haben Launen und kleine eigene Geschichten, kommen auf den Friedhof (Grabbesuche, Blumen) und reagieren auf das, was der Spieler tut.
  2. **Trauernde & Besucher:** Angehörige besuchen die Gräber ihrer Toten, haben Wünsche (Grabpflege, Inschrift, Blumen) und geben Trinkgeld oder Ruf.
  3. **Neue Figuren:** Vorschlag dieses Vertrags (§2.6): **Veit Ammer** (Bettler, Zeuge der Nacht), **Hanne Vogelsang** (Wanderhändlerin) und **Lambert Grell** (nächtlicher Grabräuber); der Pilger bleibt draußen (§13).
  4. **Beziehungen vertiefen:** mehrstufige Freundschafts-Geschichten je Bewohner, Gefallen und Gegengefallen, Dorffeste.
- **Umfang: mittel** (etwa wie Phase 6, **10 Spieltage** auf dem Phase-7-Endstand) trotz vier Schwerpunkten. Jeder Teil ist schlank und priorisiert (A = Pflicht fürs Gate, B = wenn W1 im Plan, C = gestrichen → §13). Liste §12.4.
- **Helfer: ja, ein Lehrling.** Ein menschlicher Helfer mit einfachen Aufgaben (Harken, Jäten, Gießen, Kerzen), den man anlernt. Er ist **kein** Vorgriff auf Phase 14 („Untote Arbeiter"); die Grenze steht in §2.5.7.
- **Gruft ab Spielbeginn** (parallel umgesetzt, nicht Teil dieses Vertrags): Phase 8 setzt sie voraus. Der Lehrling betritt die Gruft nie; Liesels Gefallen „Totenwäsche" (§2.4) findet am Gruft-Tisch statt.

**Lehren aus G7 (verbindlich für alle Pakete)**
- **Sichtbare, würdige Abläufe.** Keine Abblende und kein Teleport als Ersatz für eine Handlung. Besucher kommen den Kutschweg herauf, gehen durch das Tor, knien am Grab, legen Blumen ab und gehen wieder. Der Lehrling geht von Stelle zu Stelle und harkt mit dem Rechen in der Hand. Der Grabräuber gräbt sichtbar. Erlaubt bleiben nur die Übergänge, die G7 freigegeben hat: Portale (Wegstein, Haustüren, Treppe) als Überblendung und das Warten (TimedAction) vor einem Ereignis.
- **Werkzeug in der Hand:** Rechen, Gießkanne, Kerze, Spaten und Laterne sitzen am Knochen `tool` (bzw. an `arm_l`) und sind während der Handlung sichtbar (Muster `ToolProps`, G7 Runde 2).
- **Licht:** Räume hell (G7-Werte), Grabkerzen und Lichtgang warm, aber billig (§9). **Ton zu allem** (§8.3). **Schöne Gesichter** über `lib_faces.py`. **Karte** zeigt die neuen Leute und Orte (§7.8). **Browser-Testversion:** Compatibility-Renderer, Audio auf dem Hauptthread – keine neuen Dauerströme außer Musik, Einzelklänge als WAV/QOA, Leistungsbudget §9.

**Regeln für alle Agents** (wie Phase 3–7)
- Klassen, Signaturen, Dateipfade, Signale und Datenformate hier sind **fest**. Änderungen nur über den Lead.
- Der Lead legt in **Welle 0** alle Datenklassen (✦) vollständig und alle Logikklassen als **Stubs mit exakten Signaturen** an. Die Besitzer füllen die Körper und benennen nichts um.
- Nach jedem neuen Worktree und nach jedem Merge: `godot --headless --path . --import`.
- Jede Datei hat genau einen Besitzer (§3.2). Fremde Dateien nicht ändern; Bedarf an den Lead melden.
- Alle neuen Assets tragen `ph_` und kommen in die Placeholder-Liste (`docs/QUALITY_GATE_STATUS.md`).
- Keine Mechaniken, Namen oder Texte anderer Spiele übernehmen. Ausdrücklich **nicht**: Freundschafts-Herzchen oder Herzstufen, Geschenk-Kalender und Geburtstage, Romanzen, Werben, Hochzeiten, Kinder bekommen; Tagesquests mit Sofortbelohnung; Helfer mit Fähigkeitsbäumen, Sternen, Erfahrungsbalken in Prozent oder Zuweisungsrastern; Tanz-, Rhythmus- oder Sammel-Minispiele auf Festen; Schleich-Sichtkegel, Verstecken in Büschen, Kampf; Grabräuber als Gegner mit Lebenspunkten; Bettler, die Aufträge gegen Gold verteilen; Händler mit wechselndem Glücksangebot zum Neuladen.
- **Eigene Identität dieser Phase: „Wer heraufkommt".** In Phase 7 ging der Totengräber drei Meilen hinunter zu den Lebenden. Jetzt kommen die Lebenden herauf: eine Witwe mit Heidekraut, ein Junge mit einem Rechen, der zu groß für ihn ist, ein Bettler, der nachts nicht schläft, eine Händlerin mit einer Kiepe voller Grabkerzen und einer, der mit einer Schaufel kommt, die nicht ihm gehört. Der Friedhof ist nicht mehr nur ein Ort, an dem die Toten liegen, sondern einer, an den man geht.
- Sprache: alle Spieltexte eigenständig auf Deutsch, trocken-melancholisch und würdig. Trauer wird gezeigt, nicht ausgesprochen: kein Schluchzen, keine Schauerprosa, keine Frömmelei, kein Spott über Tote oder Trauernde. Der Bettler spricht nüchtern, die Händlerin schnell, der Grabräuber leise und verlegen, der Lehrling wie ein Vierzehnjähriger, der sich Mühe gibt.

---

## 1. Spielablauf & Progression

### 1.1 Erweiterter Kern-Loop
```
Freischaltung (Kapitel „Ein Name im Dorf") → Osric p8_intro: „Die Wirtin will was von dir. Es geht um den Jungen."
  → DORF: Rosine (Geschichte 1) → LEHRLING Jakob · Fenner: dritte Reihe im Lindenacker · Kathreintanz (25. Nebelung)
  → FRIEDHOF bei Tag:
       └ BESUCHER kommen den Kutschweg herauf → Tor → Grab: Blumen ablegen · knien / mit dem Hut in der Hand stehen · gehen
            └ das Grab wird angesehen (gepflegt? Stein? aufgewühlt?) → Ruf ± · ANGEHÖRIGE sprechen → WUNSCH (pflegen, Blumen,
              Kerze, Zeile im Stein, Vase) → beim nächsten Besuch erfüllt? → TRINKGELD (unter dem Stein) · Ruf +1
       └ GRABPFLEGE neu: Grabblumen setzen und gießen (Regenfass) · Grabkerzen · Grabgitter gegen den Nachtgräber
       └ LEHRLING: Arbeitsliste an der Kreidetafel (bis 3 Zeilen) → Jakob harkt, jätet, gießt, zündet Kerzen an
            └ ANLERNEN: einmal vormachen → „Angelernt" · Übung → „Geübt" · Fehler, Lohn 3/Tag, Loben / Tadeln
  → DORF lebt: BEGEGNUNGEN (zwei reden miteinander, Sprechblasen) · LAUNEN (heiter, bedrückt, gereizt) · REAKTIONEN auf dein Tun
       └ FREUNDSCHAFT: drei Schritte je Bewohner (Vertraut → Befreundet) → GEFALLEN (einmal je 5 Tage) → GEGENGEFALLEN
       └ VEIT am Kirchtor / am Friedhofstor (Almosen) · HANNE alle 6 Tage mit der Kiepe (Anger, dann Friedhofstor)
  → NACHT: Krankenlicht im Fenster → Pfarrer (Versehgang), Wundarzt (Krankenbesuch), Seelfrau (Totenwache) gehen hin → BEOBACHTEN
       └ GRABRÄUBER Lambert Grell an frischen Gräbern → verscheuchen · stellen (Schultheiß / laufen lassen) · Grab aufgewühlt
  → LICHTGANG (29. Nebelung, Vorabend des Advents): das Dorf trägt Lichter zu seinen Toten herauf
  → GEHEIMNIS: „Der unterstrichene Name" (Veit · Beobachtungen · D2 Gerhard Ott · Lorenz' zweite Kladde im Pfarrarchiv)
```
Alle Handgriffe aus Phase 2–7 bleiben **unverändert**. Wer sich um keinen Besucher kümmert und keinen Lehrling nimmt, spielt weiter wie bisher; er verliert nur Trinkgeld und ein wenig Ruf an verwahrlosten Gräbern (§2.2.4).

### 1.2 Freischaltung
- **Neues Spiel und laufende Stände:** Phase 8 öffnet sich mit dem Phase-7-Kapitel `name_in_village_complete`. Am ersten Morgen danach (erste Minute ≥ 06:00, idempotent) setzt `NpcLife.apply_morning` das Flag `p8_open` und speichert den Tag in `p8_open_day`. Ab dann hat Osric den Knoten `p8_intro`, Rosine den ersten Geschichtsschritt, Fenner die dritte Reihe (§2.8), und die Besucher planen ihre Gänge (§2.2).
- **Migrierte Stände (v6):** Ist `name_in_village_complete` gesetzt, setzt `NpcLife.post_load` `p8_open` sofort (auch nach 06:00). Bei einem v7-Stand gilt die Morgenregel (Speichern → Laden bitgleich, wie Phase 6/7).
- **Vor `p8_open`:** keine Besucher, kein Lehrling, keine Wünsche, keine neuen Figuren, keine Launen-Wirkung, kein Grabräuber. **Einzige Ausnahme:** die **Begegnungen** (§2.1.2) laufen schon ab `village_open`. Sie sind reine Darstellung (Sprechblasen ohne Spielzustand) und ändern die Phase-7-Bots nicht.
- Osric `p8_intro` (Leittext, P6 darf glätten): „Unten reden sie über dich, Totengräber. Diesmal nicht über die Toten. Die Wirtin will was von dir, es geht um ihren Jungen. Und Fenner hat noch ein Stück Lindenacker übrig, sagt er, falls du wieder Platz brauchst. Ich brauch keinen. Ich fahr nur." Danach als Menüpunkt „Wer kommt eigentlich zu den Gräbern hinauf?" (wechselnd: Besucher, Veit, Hanne).

### 1.3 Zeitkosten (Spielminuten; TimedAction wie bisher, 0,5 s Echtzeit je Spielminute auf der Uhr)
| Handlung | Min | Braucht | Abbrechbar |
|---|---|---|---|
| Mit einem Besucher reden, Wunsch annehmen, Trinkgeld nehmen | 0 (Dialog modal) | Besucher wartet am Grab bzw. Münzen liegen auf dem Stein | – |
| Grabblumen setzen | 15 | 1 `flower_seedlings`, Grab `FILLED`/`MARKED`, keine Blumen darauf | ja |
| Blumen gießen (je Grab) | 5 | `watering_can` mit Füllung (6 Füllungen) | ja |
| Gießkanne füllen (Regenfass an der Hütte) | 2 | `watering_can` | – |
| Grabkerze aufstellen und anzünden | 3 | 1 `grave_candle`; brennt bis 07:00 | – |
| Grabgitter aufsetzen / abnehmen | 20 / 10 | 1 `mortsafe`; frühestens nach 10 Tagen abnehmbar | ja |
| Aufgewühltes Grab wieder schließen | 30 | Schaufel (Werkzeug-Faktor Phase 5) | ja |
| Zeile nachmeißeln (Inschrift-Wunsch) | 30 | 1 `ink`, gestalteter Stein mit < 4 Zeilen | ja |
| Jakob etwas vormachen („Schau zu") | Dauer der vorgemachten Handlung | Jakob auf dem Friedhof, ≤ 30 m, Aufgabe noch „Ungelernt" | wie die Handlung |
| Arbeitsliste schreiben (Kreidetafel) | 0 (Panel) | Jakob eingestellt | – |
| Almosen an Veit | 0 | 1 Münze, einmal je Tag | – |
| Zuhören (Person mit Laune „bedrückt") | 10 | einmal je Tag und Person | nein |
| Tanzen (Kathreintanz) | 15 | Partner ≥ „Bekannt", 19:00–23:00 in der Gaststube, höchstens 2 Partner | nein |
| Im Schatten warten (Krankenlicht, Dorf nachts) | bis 10 Min vor dem nächsten Nachtbesuch, höchstens 120 | Beobachtungsplatz `watch_<haus>`, Nacht mit Krankenlicht | ja |
| Einen Nachtbesuch beobachten | in Echtzeit (≈ 30–40 Spielminuten, nichts wird übersprungen) | ≤ 12 m von der Haustür, wenn die Person wieder herauskommt | – |
| Im Pfarrarchiv helfen (Lenz Schritt 2) | 60 | Lenz in der Kirche (16:00–18:00) | nein |
| Grabräuber stellen | 0 (Dialog) | zweite Begegnung (§2.6.3) | – |
| Lichtgang: Kerze auf ein Grab ohne Angehörige | 3 je Grab | 1 `grave_candle` (Lenz schickt 12) | – |
| Gefallen erbitten | 0 | Schritt 3 der Geschichte erledigt, Abklingzeit 5 Tage | – |
| Untersuchen, Herrichten, Bestatten, Präparate, Bauen, Reisen | unverändert (Phase 4–7) | – | unverändert |

*Begründung:* Alles Neue ist kurz (2–30 Min). Phase 8 nimmt dem Spieler keine großen Zeitblöcke weg, sondern füllt den Tag mit kleinen, sichtbaren Gängen. Der Lehrling gibt dafür Zeit zurück (≈ 2–3 Stunden Pflege am Tag, §2.5.6).

### 1.4 Tagesbogen
**A) Referenz: Phase-7-Endstand (würdevoll, v6-Fixture `slot_p7_day53_neighbor`, Tag 53 = 24. Nebelung 1834, ≈ 60 Münzen am Morgen, Lindenacker voll, alle acht Bewohner „Vertraut").** Der Bogen dauert **10 Tage**, das Kapitel fällt an **B9**. Richtwert Mensch; der Bot `kindly8` spielt ihn nach (§10).

| Tag (Bogen) | Geschehen | Münzen früh → abends (§2.10) | Zielzeile (Beispiel) |
|---|---|---|---|
| 53 (B1) | Osric `p8_intro`. Dorf: **Rosine Schritt 1 „Der Junge"** → Jakob ist ab morgen Lehrling; Rechen und Gießkanne bei Esch (7). Fenner gibt die **dritte Reihe** (`l_09…l_12`, ein Stumpf, eine Brombeere). Rosine lädt zum Kathreintanz. Erster **Besuch**: Martha Kehr an `l_02` (Wunsch: Blumen). | 60 → 53 | „Sprich mit Osric" → „Rosine will dich sprechen" → „Kreidetafel: Arbeitsliste für Jakob" |
| 54 (B2) | **Jakobs erster Tag:** vormachen „Laub harken" → Angelernt. Reihe 3 roden. Abends **Kathreintanz** im Holderkrug: Runde (5), Tanz mit Theres und Rosine. | 57 → 52 | „Zeig Jakob, wie man harkt" → „Kathreintanz im Holderkrug (ab 19:00)" |
| 55 (B3) | Lieferung 1 (Reihe 3). Esch besucht `old_01` → **Esch Schritt 1**; Theres an `old_08` → **Theres Schritt 1** (Christrosen). Jakob: vormachen „Jäten". **Hanne** am Friedhofstor (15:40): Grabblumen, Grabkerzen. Gerücht vom Nachtgräber (Begegnung Rosine–Osric). | 56 → 61 | „Hanne Vogelsang ist am Tor (bis 16:20)" |
| 56 (B4) | **Krankenlicht bei den Otts.** Veit (drittes Almosen) → Hinweis *Drei gehen nachts*. Nachts: Quast besucht Gerhard Ott → **beobachtet**. Lenz Schritt 1. | 65 → 63 | „Merkbuch: Wer geht nachts zu den Kranken?" |
| 57 (B5) | Lieferung 2. Grabgitter von Esch (12) auf das frische Grab. Nachts 21:00: **Lenz' Versehgang** → beobachtet. In der Nacht auf B6, **01:40, der Nachtgräber** an Lieferung 1 → verscheucht (die Leiche bleibt, das Grab ist angegraben). | 67 → 60 | „Ein Grabgitter für das frische Grab?" |
| 58 (B6) | 02:10 stirbt Gerhard Ott, **02:40 kommt Liesel** (beobachtet, wer wach ist). Jakob hat frei. **Lichtgang** 16:30–19:00: das Dorf kommt mit Lichtern herauf, Lenz spricht am Kirchhof, Glocke; du setzt Lenz' 12 Kerzen auf die Gräber ohne Angehörige. | 64 → 66 | „Heute Abend ist Lichtgang" → „Kein Grab ohne Licht: 31/34" |
| 59 (B7) | **D2 Gerhard Ott** (gezeichnet, drei Spuren). Aussegnung, Reihe 3. **Lenz Schritt 2: Pfarrarchiv** → Lorenz' zweite Kladde. Rosine Schritt 2 (Namenstafel für Konrad Wackernagel). | 70 → 78 | „Im Pfarrarchiv helfen (16:00–18:00)" |
| 60 (B8) | Krankenlicht bei den Kehrs (der kleine Paul). Jakob „Geübt" im Harken. Theres besucht `old_08`. Wünsche erfüllt: 4. | 82 → 79 | „Merkbuch: Hinweise passen zusammen" |
| 61 (B9) | Lieferung 4. Der Nachtgräber kommt wieder → **gestellt** (Schultheiß oder laufen lassen). Erkenntnis **„Der unterstrichene Name"**, fünfter Wunsch, sechster Geschichtsschritt → **Kapitel „Wer heraufkommt"**. | 83 → 86 | „Wer heraufkommt: 4/4" |
| 62 (B10) | Freies Spiel. Paul Kehr ist wieder gesund (Quast). Gefallen und Gegengefallen. | 90 → 88 | „Gefallen: Esch schmiedet dir etwas" |

**B) Neues Spiel:** `name_in_village` fällt je nach Spielweise an Tag 41–55 (G7). Der Bogen läuft danach wie A, nur die Feste liegen an anderer Stelle (Kalender §2.7): Bei frühem Kapitel liegt Kathrein (Tag 54) und Lichtgang (Tag 58) mitten im Bogen, bei spätem Kapitel (Öffnung ab Tag 55) fällt Kathrein aus, und der Lichtgang rückt nach der Verschiebungsregel (§2.7.2) auf `p8_open_day + 3`. Richtwert Kapitelende „Wer heraufkommt" ≈ Tag 50–65. Die Kapitel sind voneinander unabhängig: Phase 8 sperrt nichts aus Phase 4–7.

### 1.5 Phasenziel – Kapitel „Wer heraufkommt" (`who_comes_up`)
Erfüllt, sobald **alle** gelten (geprüft von `NpcLife.check_goal` bei `apprentice_level_changed`, `wish_changed`, `friend_step_completed` und `insight_unlocked`):
1. **Jakob ist eingestellt** und in mindestens **2 Aufgaben „Angelernt"** oder besser (§2.5).
2. Mindestens **5 Wünsche** von Besuchern erfüllt, von mindestens **3 verschiedenen** Angehörigen (Haushalte und Bewohner zählen je einzeln, §2.2).
3. Mindestens **6 Freundschafts-Schritte** erledigt, davon **eine Geschichte vollständig** (alle drei Schritte, §2.4).
4. Die Erkenntnis **„Der unterstrichene Name"** (`i_underlined`) ist verknüpft (§1.6).

Dann: Flag `who_comes_up_complete`, `chapter_completed(&"who_comes_up")`, Abschluss-Panel Variante `who_comes_up`. Es zeigt: Tage seit `p8_open`, Besuche (nach Angehörigen), Wünsche erfüllt / verfehlt, Trinkgeld gesamt, Jakobs Stufen je Aufgabe und seine erledigten Stellen, Fehler, Lohn gezahlt, Freundschafts-Schritte je Bewohner (drei Punkte), Gefallen genutzt / erwidert, Feste besucht, Lichter am Lichtgang („Kein Grab ohne Licht" ja/nein), Begegnungen mit dem Nachtgräber und sein Verbleib, beobachtete Nachtwege, Erkenntnisse der Phase. Schlusszeile nach Pietät-Stufe (5 Varianten, P6), Standard: „Früher kam nur Osric den Hügel herauf. Jetzt muss man am Tor manchmal warten, bis einer vorbei ist." Danach läuft das Spiel frei weiter. **Gate-Ziel:** Alle Bot-Strategien außer `lazy8` (absichtlich ohne Lehrling und ohne Wünsche, §10) erreichen das Kapitel, auch der verwertende Weg (Lenz und Liesel höchstens „Bekannt") und ein Spieler ohne Grabgitter; **kein Fest ist Pflicht** (Kalender, §2.7), kein Präparat wird verlangt oder verboten, kein Grabräuber muss gestellt werden.

### 1.6 Das Geheimnis – Phase-8-Ausschnitt „Der unterstrichene Name"
**Leitplanke (Autorenwissen, Phase 18 entscheidet endgültig):** Phase 7 hat drei Menschen mit Zugang zu den Sterbenden benannt: Pfarrer Lenz (Versehgang), Wundarzt Quast (Krankenbesuch), Seelfrau Liesel Dorn (Totenwache). Lorenz hatte einen von ihnen unterstrichen (Ilse, Phase 7). Phase 8 zeigt, **wen Lorenz verdächtigte**, nicht, ob er recht hatte. Wer zeichnet, bleibt offen (Phase 13–18). **Welcher Name unterstrichen ist, entscheidet der Benutzer (§14.1).** Die Texte unten sind für den Vorschlag geschrieben; die anderen beiden Varianten liegen als Daten bereit (P6 schreibt alle drei, `StoryConfig.underlined` wählt).

**Der Brauch: das Krankenlicht.** In Hollerbrück stellt man ein Licht ins Fenster, wenn einer im Haus krank liegt: dann wissen die, die kommen sollen, Bescheid. Es gibt in Phase 8 genau **zwei Krankenlicht-Folgen** (`data/night/paths/*.tres` – `NightPathData`, deterministisch ab `p8_open_day`):
| Folge | Haus | Kranker | Nächte (ab `p8_open_day` + n) | Wer kommt (Zeit) | Ausgang |
|---|---|---|---|---|---|
| `np_ott` | `house_ott` | Gerhard Ott, 74, Altbauer | +3 · +4 · Nacht auf +5 | +3: **Quast** 22:30–23:10 · +4: **Lenz** 21:00–21:40 (Versehgang) · Nacht auf +5: Gerhard Ott stirbt 02:10, **Liesel** 02:40–05:30 (Totenwache) | **D2** (§2.9), Lieferung an +6 |
| `np_kehr` | `house_kehr` | Paul Kehr, 7 (Fieber) | +7 · +8 | +7: **Quast** 22:30–23:10 · +8: **Lenz** 21:00–21:30 (Krankensegen) · Liesel kommt **nicht** | Paul wird gesund (+9) |

**Was der Spieler herausfinden kann:**
1. *Drei gehen nachts* (`c_n_veit`, Veit Ammer nach dem **dritten Almosen** an verschiedenen Tagen **oder** einmal „Zuhören" bei Laune bedrückt + zwei Almosen): „Nachts gehen drei durchs Dorf. Der Pfarrer mit der Laterne, der Doktor mit dem Koffer, die Dorn mit dem Tuch. Wohin, sieht man am Fenster: wo das Krankenlicht brennt. Lorenz hat mich das auch gefragt. Ich hab's ihm gesagt. Danach hat er mir nie wieder was gegeben, nur noch genickt." Ab diesem Hinweis zeigt die Karte Krankenlichter (§7.8).
2. *Der Krankenbesuch* (`c_n_quast_visit`, beobachtet): „Quast bleibt vierzig Minuten. Er lässt ein Fläschchen da und schreibt beim Hinausgehen nichts auf. Er schreibt sonst alles auf."
3. *Der Versehgang* (`c_n_lenz_visit`, beobachtet): „Lenz bleibt eine halbe Stunde. Beim Hinausgehen bleibt er unter der Laterne stehen und schreibt etwas in sein Brevier."
4. *Die Totenwache* (`c_n_liesel_watch`, beobachtet, nur `np_ott`): „Liesel kommt eine halbe Stunde nach dem Tod. Niemand hat nach ihr geschickt. Das Krankenlicht brennt noch."
5. *Drei Spuren* (`c_n_ott_three`, Funde an D2, §2.9): Quasts Fläschchen in der Tasche, ein Wachstropfen von Lenz' Kerze am Kragen, ein frisch gewaschenes Hemd unter dem Kittel.
6. *Lorenz' zweite Kladde* (`c_n_kladde`, Pfarrarchiv: Lenz Schritt 2 **oder** Fenner Schritt 2 mit dem Gemeindeschlüssel, §2.4): „Zwischen den Kirchenrechnungen von 1831 steckt ein schmales Heft in Lorenz' Hand. Auf der letzten beschriebenen Seite stehen drei Namen: A. Lenz · S. Quast · L. Dorn. Einer ist zweimal unterstrichen. Darunter: ‚Wer kommt, bevor man ruft?'"

**Erkenntnis (Pflicht fürs Kapitel):** `i_underlined` „Der unterstrichene Name" (Frage: „Wen hat Lorenz verdächtigt?") = **alle** von `c_n_veit`, `c_n_kladde` **und zwei beliebige** von `c_n_quast_visit`, `c_n_lenz_visit`, `c_n_liesel_watch`, `c_n_ott_three` (✦ `InsightData.any_clues` + `any_count`, §3.4). Text (Vorschlag §14.1, Variante `washer`): „Lorenz hat die Seelfrau unterstrichen. Sie kommt, bevor man nach ihr schickt, und sie hat ihm jedes Zeichen gemeldet, das sie fand. Vielleicht wollte er sie in der Nähe haben, weil er ihr nicht traute. Vielleicht wollte er sie schützen. Auf der Seite steht nicht, welches von beiden." Flag `insight_underlined`. Belohnung wie Phase 4/7: Text, Flag, Zeile im Abschluss-Panel, keine Münzen.
- *Begründung zwei aus vier:* Wer eine Nacht verschläft oder D2 nicht untersucht, findet die Erkenntnis trotzdem; wer alles sieht, bekommt mehr Text, aber keinen Vorteil. Die zwei Folgen liefern zusammen fünf Gelegenheiten (Quast 2×, Lenz 2×, Liesel 1×), dazu die Funde an D2.
- **Liesel weiß nichts davon.** Ihre Geschichte (§2.4) bleibt warm; mit der Erkenntnis bekommt ihr dritter Schritt eine zusätzliche, stille Zeile, die nichts verrät.

**Nächster Erzählschritt (Phase 9, benannt): „Wer weiß, wann?"** Die Kladde endet mit einer Liste von Daten. Phase 9 (Quests) macht daraus eine Kette: Zu jedem Datum gehört ein Toter auf dem Hügel, und zu jedem Toten ein Fenster mit einem Licht, das jemand gesehen hat.

---
## 2. Spielwerte (Vorschläge, alle in `data/`)

### 2.1 Das Dorf lebt (`data/config/npc_life_config.tres` – `NpcLifeConfig`, `data/npc_life/chatter/<id>.tres` – `ChatterData`)
**Entscheidung: drei kleine Bausteine auf dem bestehenden `Npc`-, Gerede- und Dialog-System, keine neue KI.** Tagesabläufe bleiben deterministisch aus der Uhr (Phase 2/7). Neu sind Launen (eine Zahl am Morgen), Begegnungen (Sprechblasen, wenn zwei am selben Ort sind) und Reaktionen (Gerede-Zeilen auf Ereignisse). *Begründung:* Ein Dorf wirkt lebendig, wenn man sieht, dass die Leute einander kennen und dass sie sich an gestern erinnern. Eine Wegfindungs- oder Bedürfnis-KI würde das CPU-Budget im Browser sprengen (§9) und die Tagesabläufe, nach denen sich der Spieler richtet, unberechenbar machen.

#### 2.1.1 Launen
- Jeder Dorfbewohner hat **eine Laune je Tag**: `cheerful` „heiter", `plain` „wie immer", `low` „bedrückt", `cross` „gereizt". `MoodRules.roll(npc_id, day)` würfelt um 06:00 deterministisch aus Tag und `npc_id` (Gewichte `mood_weights` {plain 70, cheerful 15, low 10, cross 5}). Danach gelten **Vorrangregeln** (erste passende gewinnt, `NpcLifeConfig.mood_rules`):
  | Vorrang | Auslöser | Laune | Wer |
  |---|---|---|---|
  | 1 | Festtag (§2.7) | heiter | alle |
  | 2 | Trauerflor an einem Haus aus dem eigenen Kreis (✦ `VillagerData.circle`) heute oder gestern | bedrückt | der Kreis (z. B. Liesel: beide Katen) |
  | 3 | gestern ein Geschichtsschritt dieser Person erledigt | heiter | die Person |
  | 4 | gestern schlechtes Gerede über den Totengräber (`lecture_rumor`, Präparat eines Dorftoten verkauft, aufgewühltes Grab) | gereizt | Pfarrer, Liesel (Präparate), Fenner (Grab) |
  | 5 | Krankenlicht im Dorf (§1.6) | bedrückt | Quast, Lenz, Liesel (sie wissen es) |
- **Wirkung** (nur ab `p8_open`; vorher nur der Begrüßungstext): Begrüßung aus ✦ `VillagerData.mood_lines[mood]` (2 je Laune); Gespräch des Tages **heiter +2** statt +1, **gereizt 0**; „gereizt" bietet heute keinen neuen Auftrag und keinen Geschichtsschritt an („Heute nicht, Totengräber. Morgen."), Läden und Abgaben gehen normal; **„bedrückt"** öffnet die Dialogzeile **„[Zuhören]"** (10 Min, +3, einmal je Tag und Person). Bedrückte Figuren stehen mit gesenktem Kopf (`idle_low`, §8.2).
- Die Laune steht im Merkbuch („Hollerbrück": „heute bedrückt") und im Karten-Tooltip, nie als Zahl. Nicht gespeichert (aus Tag und gespeicherten Ereignissen abgeleitet, §5.1).
- *Begründung:* Eine Laune je Tag gibt jedem Gang ins Dorf ein kleines Gesicht, ohne den Spieler zu bestrafen: „gereizt" verschiebt nur, „bedrückt" ist eine Gelegenheit.

#### 2.1.2 Begegnungen (Sprechblasen zwischen zwei Leuten)
- Eine Begegnung (`ChatterData`) gehört zu zwei Personen, einem Ort (Wegpunkt) und einem Zeitfenster, das ihre bestehenden Zeitpläne schon überlappen lassen. Sind beide da und ist der Totengräber in derselben Region **≤ 10 m** nah (und in keinem Dialog), wechseln sie 2–4 Zeilen als Sprechblasen (3,5 s je Zeile, die Sprechenden drehen sich zueinander, `talk`). Höchstens **eine Begegnung zugleich** je Region, jede höchstens **einmal am Tag**; Bedingungen in der Dialog-Syntax (`rel_tier`, `flag`, `rep_tier`, `mood` …).
- **16 Begegnungen** (P6 schreibt sie, je 2–4 Zeilen; Leitzeilen):
  | id | wer | wo · wann | Leitzeilen |
  |---|---|---|---|
  | `ch_well_spin` | Theres · Liesel | Brunnen 16:00–16:30 | T: „Du spinnst zu dünn, Dorn. Das reißt." – L: „Für die Toten reicht's. Die ziehen nicht dran." |
  | `ch_linden_bench` | Esch · Fenner | Linde 17:34–18:00 | F: „Der Brunnen hält, Esch." – E: „Der hält länger als wir." |
  | `ch_inn_council` | Lenz · Fenner | Gaststube 18:10–20:00 | F: „Wieder drei im Sterbebuch diesen Monat, Hochwürden." – L: „Ich zähle nicht, Fenner. Ich schreibe." |
  | `ch_inn_carter` | Rosine · Osric | Gaststube 14:05–17:30 | R: „Faulhaber, du riechst nach Hügel." – O: „Der Hügel riecht nach mir. Das ist was anderes." |
  | `ch_bridge_water` | Quast · Veit | Holderbrücke 18:06–19:30 | V: „Sie schauen jeden Abend ins Wasser, Doktor." – Q: „Und Sie jeden Abend mir zu." |
  | `ch_church_alms` | Lenz · Veit | Kirchtür 08:00–11:30 | L: „Hast du gegessen, Veit?" – V: „Gestern, Hochwürden. Ich spar mir den Rest." |
  | `ch_rumor_robber` | Rosine · Osric | Gaststube, ab `p8_open_day` + 2 | O: „Drüben bei Ellbach haben sie wieder eins offen gefunden." – R: „Bei uns nicht. Bei uns liegt einer auf dem Hügel, der nicht schläft." (setzt `robber_known`, §2.6.3) |
  | `ch_inn_jakob` | Rosine · Jakob | Gaststube 17:00–21:00 | R: „Hast du dir die Hände gewaschen?" – J: „Zweimal. Die Erde geht nicht ab." |
  | `ch_gate_jakob` | Jakob · Osric | Friedhofstor 07:55–08:20 | J: „Was bringst du heute, Herr Faulhaber?" – O: „Heute nichts, Junge. Freu dich nicht zu früh." |
  | `ch_grave_kehr` | Martha Kehr · Jakob | an ihrem Grab, wenn Jakob in der Nähe arbeitet | J: „Ich mach nur das Laub weg, Frau Kehr." – M: „Mach nur. Er hat Laub nie leiden können." |
  | `ch_market_rival` | Hanne · Theres | Anger, Hanne-Tag 10:00–14:00 | T: „Bei mir kostet der Zwirn einen." – H: „Bei Ihnen kostet er auch einen, wenn er reißt." |
  | `ch_gate_peddler` | Hanne · Veit | Friedhofstor, Hanne-Tag 15:40–16:20 | H: „Immer noch hier, Veit?" – V: „Wo soll ich hin? Die Toten geben nichts, aber sie nehmen auch nichts." |
  | `ch_smith_mayor` | Esch · Fenner | Amboss 12:20–13:00 | F: „Ein Gitter für jedes frische Grab, Esch? Was kostet das die Gemeinde?" – E: „Weniger als ein offenes." (nur `robber_known`) |
  | `ch_surgery_priest` | Quast · Lenz | Kirchplatz 11:30–11:40 | L: „Bei den Otts brennt Licht." – Q: „Ich weiß. Ich war schon da." (nur bei Krankenlicht) |
  | `ch_lights_prepare` | Lenz · Liesel | Kirchtür, Tag vor dem Lichtgang | Li: „Wie viele Kerzen dieses Jahr?" – L: „Eine mehr als letztes. Wie jedes Jahr." |
  | `ch_after_lights` | Theres · Rosine | Brunnen, Tag nach dem Lichtgang | T: „Oben brannte jedes Grab. Hat er alle selbst angezündet?" – R: „Er und mein Junge." (nur `lights_all`) |
- Begegnungen sind **reine Darstellung** außer `ch_rumor_robber` (setzt ein Flag, keinen Spielwert). Sie laufen ab `village_open` (§1.2); Begegnungen mit Phase-8-Figuren (Jakob, Veit, Hanne, Angehörige) erscheinen natürlich erst ab `p8_open`.

#### 2.1.3 Reaktionen auf das Tun des Spielers
- Das Phase-7-Gerede (Sprechblase einmal je Tag und Person bei 4 m) bekommt einen neuen obersten Vorrang: **Ereignis** (`NpcLifeConfig.reactions`, höchstens 2 Tage alt) → Beziehung „Befreundet" → Pietät → Ruf (die Phase-7-Reihenfolge bleibt darunter).
  | Ereignis | Wer reagiert | Beispielzeile (P2 schreibt 1–2 je Person und Ereignis) |
  |---|---|---|
  | `apprentice_hired` | alle | Esch: „Der Wackernagel-Junge harkt jetzt bei dir? Gib ihm einen Stiel, der zu ihm passt." |
  | `jakob_scolded` | Rosine | „Er sagt, du warst streng. Gut. Ich bin's nicht genug." |
  | `wish_done` (Haushalt) | alle, die den Haushalt im Kreis haben | Theres: „Die Kehr sagt, das Grab sieht aus wie ein Garten. Sie hat geweint. Das ist gut." |
  | `grave_disturbed` | alle | Fenner: „Ein offenes Grab auf dem Hügel. Das kommt ins Protokoll, Totengräber. Nicht gegen dich." |
  | `robber_reported` / `robber_let_go` | alle / Liesel, Veit | Rosine: „Den Grell haben sie in die Stadt gebracht. Der hat bei mir noch zwei Bier offen." · Liesel: „Du hast ihn laufen lassen. Das hätte Lorenz auch getan." |
  | `lights_all` | alle | Lenz: „Kein Grab ohne Licht. Das hatten wir noch nie." |
  | `kathrein_danced` | Tanzpartner, Rosine | Theres: „Du trittst wie einer, der Erde gewohnt ist." |
  | `noise_at_grave` | Haushalt, Lenz | Lenz: „Man sagt, du hast gehackt, während der Brandt gebetet hat. Hack ein andermal." |
- Reaktionen ändern keinen Spielwert; die Folgen tragen die auslösenden Systeme (§2.2.4).

#### 2.1.4 Bewohner auf dem Friedhof
Die Dorfbewohner, die einen Toten auf dem Hügel haben, kommen selbst herauf. Sie gehen den Kutschweg (Region-Übergang wie bei Osric: im Dorf gehen sie über die Holderbrücke hinaus, auf dem Friedhof erscheinen sie 30 Min später am Wegende `road_end`) und folgen dem Besuchsablauf §2.2.3.
| Person | Grab | Abstand | Zeit am Grab (Besuchstag) | Im Dorf an diesem Tag |
|---|---|---|---|---|
| Ulrich Esch | `old_01` Wendel Gratz (sein Lehrmeister) | alle 6 Tage | 13:40–14:30 | Schmiede 13:00–15:00 zu („Bin oben beim Meister.") |
| Theres Mangold | `old_08` Dorothee Mahn (ihre Mutter) | alle 5 Tage | 14:40–15:10 | Laden 14:05–16:00 zu |
| Liesel Dorn | D1 Wiebke Hagedorn, Gräber mit `kin_house` der beiden Katen, S5 „Kaspar Dorn" (erst ab `insight_not_lorenz`) | alle 4 Tage | 09:40–10:40 (statt der Totenwache) | – |
| Lenz, Fenner, Rosine | – | nur am Lichtgang (§2.7) und in Geschichtsschritten (§2.4) | – | – |
| Quast | – | **nie** („Ich sehe die Toten lieber vorher, Totengräber.") – auch am Lichtgang bleibt er an der Brücke | – | – |
- **Erster Besuch** an `p8_open_day` + 2 (Esch, Theres) bzw. + 1 (Liesel), danach im Abstand der Tabelle; fällt ein Besuchstag auf den Lichtgang, rückt er einen Tag weiter.
- Technisch hat jede dieser Personen einen zweiten `Npc` in der Friedhofs-Region (`npc_<id>_g`, wie `npc_priest` seit Phase 7), dessen Einträge über `today_flag` (`visit_<npc>_day`, vom Besuchsplan gesetzt, bzw. `fest_<id>_day`) nur am Besuchstag gelten; die Dorf-Einträge desselben Tags werden über dieselben Flags verborgen (gleicher `start_minute`, gültiger `today_flag` gewinnt, Phase 7 §3.4).

### 2.2 Besucher & Trauernde (`data/config/visitor_config.tres` – `VisitorConfig`, `data/visitors/kin/<id>.tres` – `KinData`, `data/visitors/wishes/<id>.tres` – `WishData`)
**Eigene Identität: der Besuch wird gesehen, nicht gemeldet.** Es gibt keine Liste „Besucher heute: 3". Man sieht eine Frau mit einem Korb am Tor, man sieht, wo sie kniet, und man sieht hinterher, ob zwei Münzen auf dem Stein liegen.

#### 2.2.1 Die Angehörigen
| kin_id | Name | Haus (`mourning_houses`) | Figur (§8.1) | Stimme | bringt |
|---|---|---|---|---|---|
| `kin_kehr` | **Martha Kehr**, 41, Witwe eines Tagelöhners, Mutter von Paul | `house_kehr` | `ph_chr_mourner_w_a`: dunkles Wolltuch, Schürze, Korb mit Heidekraut | knapp, höflich, praktisch; dankt mit Arbeit, nicht mit Worten | Heidekraut |
| `kin_brandt` | **Hinrich Brandt**, 34, Fuhrknecht | `house_brandt` | `ph_chr_mourner_m_a`: Kittel, Halstuch, den Hut in der Hand | stockend, bedankt sich zu oft | Tannengrün |
| `kin_ott` | **Gesa Ott**, 26, Bauerntochter | `house_ott` | `ph_chr_mourner_w_b`: helles Kopftuch, schwarzer Rock, Umschlagtuch | jung, direkt, fragt viel | Strohblumen |
| `kin_sieber` | **Johann Sieber**, 71, Altknecht | `house_sieber` | `ph_chr_mourner_m_b`: Stock, langer Mantel, Schlapphut | redet mit dem Grab, nicht mit dir | nichts außer seinem Stock |
| (Bewohnerin) | Liesel Dorn | `cottage_dorn`, `cottage_hagedorn` | `ph_chr_v_washer` | §2.1.4 | einen Wollfaden um einen Zweig |
| (Bewohner) | Esch, Theres | – (feste Gräber) | `ph_chr_v_smith`, `_grocer` | §2.1.4 | Esch nichts, Theres einen Topf Christrosen |
- **Zuordnung:** ✦ `CorpseRecord.kin_house` = `Village.mourning_house(Ankunftstag)` (seit Phase 7 deterministisch aus Tag und Seed, der Trauerflor). Gesetzt bei der Lieferung ab `village_open`; für ältere Lindenacker-Tote berechnet die Migration ihn nach (§5.2). Tote ohne `kin_house` (Phase 2–6, „von außerhalb", S1–S4) bekommen keinen Besuch, nur am Lichtgang eine Kerze von dir (§2.7.2).
- Je Angehörigem ein **Wohlwollen** 0…10 (Start 5, gespeichert in `Visitors`), nicht als Zahl angezeigt, nur als Wort im Grab-Tooltip („Die Kehrs: zufrieden"). Es bestimmt die Trinkgeldhöhe (§2.2.5) und ob ein Wunsch kommt (≥ 2).

#### 2.2.2 Besuchsplan
- `Visitors.plan_day(day)` legt um **06:00** fest, wer heute kommt (deterministisch aus Tag, Grab-Seeds und dem Zustand um 06:00; gespeichert, damit Laden bitgleich bleibt). Regeln (`VisitorConfig`):
  - **Erster Besuch** am Tag nach der Bestattung (`first_delay_days 1`), immer mit Blumen.
  - **Trauerzeit** 21 Tage ab Bestattung (`mourning_days 21`): Abstand **3 Tage** (+ 0/1 aus dem Seed, `interval_mourning 3`); danach **7 Tage** (`interval_late 7`).
  - **Bei der Öffnung** (`p8_open`) bekommen Gräber, deren Trauerzeit noch läuft, ihren nächsten Besuch ab `p8_open_day`, nach Seed auf die ersten drei Tage verteilt; ältere Gräber mit Angehörigen ab `p8_open_day` + Seed mod 7.
  - Hat ein Haushalt mehrere Gräber, geht er bei einem Besuch alle ab (eine Runde, je Grab ≈ 15 Min).
  - Höchstens **3 Besuche am Tag** (`max_visits_day 3`) in drei Zeitfenstern **09:30 · 12:30 · 15:00** (`slots`), höchstens **2 Besucher zugleich** (`max_concurrent 2`); Überzählige verschieben sich auf morgen. Bewohner haben ihre eigenen Zeiten (§2.1.4) und zählen mit.
  - Kein Besuch bei Nacht, am Lichtgang-Tag (dann kommen alle abends), vor `p8_open` oder an einem Grab im Zustand `DUG`.
- *Begründung:* Mit 8–14 Gräbern mit Angehörigen ergibt das 1–3 Besuche am Tag: genug, dass jeden Tag jemand kommt, zu wenig, dass der Friedhof voll wirkt.

#### 2.2.3 Ablauf eines Besuchs (sichtbar, Zeitplan aus `ScheduleBuilder`, §3.4)
| Phase | Dauer (Spielmin) | Was man sieht | Animation (§8.2) |
|---|---|---|---|
| Ankommen | ≈ 8 | vom Wegende `road_end` den Kutschweg herauf, durch das Tor | `walk` (Männer nehmen am Tor den Hut ab: Kindmesh `hat_head` → `hat_hand`) |
| Zum Grab | 3–10 | über die gebackene Route `visitor_routes[plot]` zum Besucherplatz `gv_<plot>` am Fußende, Blick zum Stein | `walk` |
| Blumen ablegen | 2 | beugt sich vor und legt den Strauß auf den Hügel (Kindmesh `bouquet` wandert aus der Hand auf das Grab) | `lay_flowers` |
| Trauern | 30 | Frauen knien, Männer stehen mit gesenktem Kopf und dem Hut vor dem Bauch; keine Tränen, keine Laute außer Kleiderrascheln und Atem | `kneel_in` → `kneel` → `kneel_out` bzw. `mourn_stand` |
| Ansehen | 2 | richtet sich auf, sieht über das Grab; Sprechblase mit der Zeile nach dem Zustand (§2.2.4) | `idle_low` |
| Warten | **(G8 Runde 1 angepasst)** immer (`wait_always`): Haushalte bis 100 (`wait_minutes`), nie über 16:30 (`wait_until_minute`, Novemberdämmerung), mindestens 10; 3 Min nach dem Gespräch gehen sie (`leave_after_talk_minutes`); Bewohner 18 (`wait_minutes_villager`) | bleibt am Grab stehen; kommt der Totengräber auf 4 m, dreht sie sich zu ihm („[E] Mit Martha Kehr reden") | `idle` / `talk` |
| Gehen | ≈ 12 | denselben Weg zurück | `walk` |
- Ein Besuch dauert 60–90 Spielminuten (30–45 s Echtzeit) **(G8 Runde 1 angepasst: mit dem Warten bis ≈ 160 Min, wenn niemand kommt; der Plan rechnet mit der vollen Länge, höchstens 2 zugleich)**. Ein Gespräch ist in jeder Phase möglich; eine Kniende steht dafür erst auf.
- **Torglocke (G8 Runde 1 angepasst, B8-1):** Am östlichen Torpfeiler hängt ein Glöckchen (`ph_prop_gate_bell`, Layout `phase8.gate_bell`, Entität `GateBell`). Kommt ein Besuch herauf (Phase `arriving`, Haushalte und Bewohner), läutet es (Cue `gate_bell`, hörbar ≈ 70 m), das Glöckchen schwingt, und ist der Totengräber auf dem Friedhof (auch in einem Raum dort), steht im HUD „Am Tor läutet es – Martha Kehr kommt herauf." Ein Laden läutet nicht nach. Der Karten-Marker des Besuchs bleibt.
- **Ruhe am Grab:** Läuft eine laute Handlung (Graben, Fällen, Hauen, Hämmern, Sägen, Steinbruch; ✦ Stichwort `noisy` der TimedAction) **≤ 8 m** von einer trauernden Person, gibt es einmal je Besuch eine Blase und **Ruf −1** (`visit_noise`, höchstens einmal je Tag). Jakob arbeitet nie an einem Grab, an dem gerade jemand trauert („Jakob lässt die Kehr in Ruhe.").
- **Trinkgeld ohne Gespräch:** Ist der Totengräber nicht da, legt der Besucher die Münzen auf den Stein (Kindmesh `coins` am Marker `inscription`) mit einem Zettel: „[E] Zwei Münzen auf dem Stein (Martha Kehr)". Sie bleiben liegen, bis man sie nimmt (Geister und Grabräuber nehmen nichts).

#### 2.2.4 Wie das Grab angesehen wird (`GraveView`, einmal je Besuch und Grab)
| Zustand (Vorrang von oben) | Bedingung | Ruf | Wohlwollen | Leitzeile |
|---|---|---|---|---|
| aufgewühlt | ✦ `GraveRecord.disturbed` | **−3** (`visit_disturbed`) | −4 | „Wer war das? Wer war an ihm?" |
| verwahrlost | Pflegestelle des Grabs ≥ Stufe 2 | −1 (`visit_neglected`) | −1 | „Das Unkraut ist schneller als du." |
| ohne Stein | kein Zeichen | 0 | 0 | „Noch kein Name. Das kommt, sagt man." |
| gepflegt | Pflegestelle ≤ 1 und Zeichen | +1 (`visit_pleased`, höchstens 2 je Tag) | +1 | „Sauber. Das hätte ihm gefallen." |
| zusätzlich: frische Blumen, Kerze letzte Nacht oder Vase | §2.3 | – | +1 (einmal) | „Jemand hat ihr ein Licht hingestellt." |
| zusätzlich: ein Präparat dieses Toten wurde verkauft (einmal je Toter) | `Specimens` Zustand `sold` | −1 (`visit_specimen_rumor`) | −3 | „Beim Quast, sagen sie, steht ein Glas. Mit seinem Namen." |
| **(G8 Runde 1 angepasst, B8-3)** Gerede dorfweit: je ein Präparat verkauft (Stat `specimens_sold` > 0) | `VisitorConfig.rumor_stat` | – | – | jedes Trinkgeld −1 (`rumor_tip_malus`; aus 1 wird nur Dank) |
- Präparate, die ins Grab zurückgelegt sind (Phase 7 „beisetzen"), zählen nicht. Wer seine Toten würdig hält, gewinnt am Tag 1–2 Ruf; wer sie verwahrlosen lässt, verliert so viel wie bei einem schlechten Grabzeichen.

#### 2.2.5 Wünsche & Trinkgeld
| Art (`WishData.kind`) | Bitte (Leittext) | Erfüllt beim nächsten Besuch, wenn … | Weg |
|---|---|---|---|
| `tend` | „Hältst du es sauber, bis ich wiederkomme?" | Pflegestelle des Grabs ≤ Stufe 1 | Pflege (Phase 3) oder Jakob |
| `flowers` | „Ein paar Blumen. Heide, wenn's geht, die hält den Winter." | frische Grabblumen auf dem Grab (§2.3) | Setzen + Gießen oder Jakob |
| `candle` | „Stell ihm einmal ein Licht hin. Er hatte Angst im Dunkeln." | seit dem Wunsch mindestens eine Nacht mit brennender Grabkerze | selbst oder Jakob |
| `line` | „Kannst du ‚Ruhe sanft' darunter setzen?" (Zeile aus `WishData.line_text`, 6 Vorlagen) | die Zeile steht auf dem Stein | „[E] Zeile nachmeißeln (30 Min, 1 Tinte)" am Grab; nur bei gestaltetem Stein mit < 4 Zeilen, sonst wird `line` nicht gewählt |
| `vase` | **(G8 Runde 1 angepasst, B8-2)** „Eine Vase aus Stein, damit die Blumen nicht umfallen. So eine, wie du sie an deiner Werkbank machst." | eine Grabvase (`decor_grave_vase`) ≤ 1,5 m vom Grab | Werkbank (Rezept `decor_grave_vase`, 15 Min, 1 Stein + 1 Samen; Samen bei Theres), dann Baumodus (Phase 3). Die Wunschkarte nennt es: „Woher: …" (`WishData.source_text`) |
- **Angebot:** im Gespräch mit einem wartenden Besucher (Wohlwollen ≥ 2). Gewählt wird die erste noch nicht erfüllte Art in der Reihenfolge [`tend` (nur wenn verwahrlost), `flowers`, `candle`, `line`, `vase`], mit dem Seed des Grabs gedreht. Höchstens **ein offener Wunsch je Grab**, **3 offene insgesamt** (`max_open 3`). Karte im Dialog mit „Das mache ich." / „Ich kann es nicht versprechen." (ohne Folgen). **Frist:** der nächste Besuch (3–7 Tage).
- **Lohn beim erfüllten Besuch:** Trinkgeld **1** (`tip_base`) **+1** bei Wohlwollen ≥ 6 **+1** bei Grabqualität ≥ 15 → **1–3 Münzen**, höchstens **4 Münzen am Tag** (`tip_cap_day 4`, darüber nur Dank); Ruf **+1** (`wish_done`); Wohlwollen +2; `stats.wishes_done`, `stats.tips_coins`. Bewohner zahlen kein Geld: **Beziehung +4** (`wish_done_villager`); Esch legt einmal 2 `iron_fittings` hin. **Nicht erfüllt:** Wohlwollen −2, der Wunsch verfällt (`stats.wishes_failed`), kein Ruf-Abzug.
- *Begründung Trinkgeld:* Im Bogen A kommen ≈ 9 erfüllte Wünsche zusammen, davon ≈ 8 mit Geld, zusammen **≈ 18 Münzen**: etwa ein Sechstel der neuen Einnahmen (9 % des Verfügbaren, §2.10) und die Hälfte des Pflegegelds (36). Die Tageskappe verhindert, dass ein Abend mit vielen Besuchern zur Kasse wird. Die eigentliche Belohnung ist der Ruf, der über Bezahlung und Pflegegeld weiterwirkt (Phase 3). Eine echte Preisdynamik bleibt Phase 10.

### 2.3 Grabpflege neu: Blumen, Kerzen, Grabgitter (`data/config/grave_care_config.tres` – `GraveCareConfig`)
**Entscheidung: vier kleine Zustände je Grab im neuen System `GraveCare`, getrennt von Zier (Phase 3) und Qualität (sie ändern die Qualität nicht).** *Begründung:* Die Grabqualität ist mit dem Zeichen abgeschlossen (Phase 3–5). Blumen und Kerzen sind das, was danach kommt: Pflege für die Lebenden und die Geister, nicht für die Abrechnung.
| Zustand | Wie | Hält | Wirkung | Kosten |
|---|---|---|---|---|
| **Grabblumen** (Winterheide und Christrosen) | „[E] Grabblumen setzen (15 Min)" auf `FILLED`/`MARKED` | **frisch** 2 Tage ab dem letzten Gießen (`flower_fresh_minutes 2880`), **welk** bis Tag 4 (`flower_wilt_minutes 5760`), danach verdorrt und fort | frisch: Geist **+1** (`care`), Besucher +1 Wohlwollen, Wunsch `flowers` | 1 `flower_seedlings` (Theres 2, Hanne 2) |
| Gießen | „[E] Blumen gießen (5 Min)" | setzt „frisch" | – | `watering_can` (Esch 4, Hanne 4), 6 Füllungen, „[E] Gießkanne füllen" am **Regenfass** an der Hütte (2 Min) |
| **Strauß der Besucher** | legt der Besucher ab (§2.2.3) | 2 Tage | Geist +1 (nicht zusätzlich zu Grabblumen) | – |
| **Grabkerze** (Kerze im Glas) | „[E] Grabkerze anzünden (3 Min)" ab 15:00 | bis 07:00 | Geist **+1** in dieser Nacht, Wunsch `candle`, **der Grabräuber meidet das Grab** | 1 `grave_candle` (Theres 1, Hanne 1; Lenz schickt 12 zum Lichtgang) |
| **Grabgitter** (eisernes Gitter über dem Hügel, wie es 1834 gegen Leichenräuber üblich war) | „[E] Grabgitter aufsetzen (20 Min)" | bis man es abnimmt, frühestens nach **10 Tagen** („bis die Erde sich gesetzt hat") | der Grabräuber kommt an dieses Grab nie; Pflege und Blumen gehen durch das Gitter | 1 `mortsafe` (Esch **12** ab `robber_known`, mit Esch Schritt 2 **8**; wiederverwendbar) |
| **Aufgewühlt** | der Grabräuber war ungestört bis 05:00 (§2.6.3) | bis man es schließt: „[E] Grab wieder schließen (30 Min)" | Geist **−3**, Pflegestelle Stufe 3, Besucher Ruf −3 | – |
- Der Pflegeanteil an der Geisterstimmung ist **höchstens +2** (Blumen oder Strauß +1, Kerze +1; ✦ `GhostMood.score(…, care)`); beraubte Seelen bleiben wie in Phase 6/7 höchstens gleichmütig.
- Die Leiche bleibt **immer** im Grab. *Begründung:* Phase 8 entfernt keine Toten; der Nachtgräber kommt vor dem Morgen nicht tief genug, und das soll so bleiben, bis ein späterer Vertrag es anders will (§13).

### 2.4 Freundschafts-Geschichten, Gefallen & Gegengefallen (`data/friendship/stories/<npc_id>.tres` – `FriendStoryData`, `data/friendship/favors/<id>.tres` – `FavorData`)
**Entscheidung: je Bewohner eine kleine Geschichte in drei Schritten, über der Phase-7-Beziehung, ohne neue Währung.** Die sieben lebenden Bewohner (Wiebke Hagedorn ist seit Phase 7 tot; ihre Geschichte ist erzählt) haben je drei Schritte. Jeder Schritt ist ein Gespräch, eine kleine Aufgabe mit bestehenden oder zwei neuen Auftragsarten (`meet`, `task`, §3.4) und ein Abschluss. *Begründung:* Die Beziehung aus Phase 7 zählt, wie gut man sich kennt. Die Geschichte erzählt, **was** man voneinander weiß. Die drei Besucher der Sterbenden (Lenz, Quast, Liesel) tragen in ihrer Geschichte den Geheimnis-Faden (§1.6); die anderen vier erzählen vom Dorf.

**Regeln**
- **Schwellen:** Schritt 1 ab „Vertraut" (≥ 40) · Schritt 2 ab **55** und frühestens einen Tag nach Schritt 1 · Schritt 3 ab „Befreundet" (≥ 70) und nach Schritt 2. Angeboten im Gespräch (Zeile „[Geschichte] …"), nicht bei Laune „gereizt".
- **Lohn:** Beziehung **+6 / +8 / +10**, bei einzelnen Schritten Ruf +1; **keine Münzen** außer den genannten kleinen Sachgaben. Freundschafts-Aufgaben sind Aufträge der Kategorie `friend` (✦ `OrderData.category`) und zählen **nicht** gegen die vier aktiven Aufträge aus Phase 7 (eigene Grenze `max_active_friend 2`).
- **Ohne Frist,** außer wo ein Ereignis sie setzt (Lichtgang, Totenwache). Verpasst man ein Ereignis, kommt ein Ersatztermin (Spalte „Ersatz").
- *Nachrechnung:* Am Phase-7-Ende stehen im Bogen A alle acht auf „Vertraut" (G7 `neighbor7`: 8 Vertraute), die meisten zwischen 40 und 55. Schritt 1 + Schritt 2 bringen +14, dazu Gespräche (+1/+2 je Tag), Wünsche der Bewohner (+4), Geschenke (+4) und Zuhören (+3). In zehn Tagen schaffen so **3–4 Geschichten Schritt 2** und **1–2 Geschichten Schritt 3**; das Kapitel verlangt 6 Schritte und eine ganze Geschichte (§1.5).

| Bewohner | Schritt 1 (≥ 40) | Schritt 2 (≥ 55) | Schritt 3 (≥ 70) → Gefallen |
|---|---|---|---|
| **Rosine** Wackernagel | **„Der Junge"** – Jakob, 14, „seit der Tinktur nicht mehr zu halten", soll etwas lernen, „das nicht nach Bier riecht". Aufgabe: Jakob einstellen (erste Arbeitsliste schreiben); erledigt an seinem ersten Arbeitstag. **Schaltet den Lehrling frei** (§2.5). | **„Konrads Name"** – ihr Mann Konrad ertrank im Fährwinter 1831 und wurde nie gefunden; er hat kein Grab. Aufgabe `task`: eine **Namenstafel** an der Steinmetzbank (Rezept `memorial_plate`: 1 `workstone`, 1 `ink`, 1 `gold_leaf`, 40 Min) und sie Lenz bringen (`deliver` → priest). Die Tafel hängt danach sichtbar am Gedenkbrett der Kirche. Ruf +1. | **„Oben bei Jakob"** – Rosine kommt zum ersten Mal den Hügel herauf (15:00–15:40, Bank an der Hütte, `meet`) und sieht Jakob arbeiten. Braucht Jakob „Geübt" in einer Aufgabe. „Er hält den Rechen wie du. Das hat er nicht von mir." → **„Ein Wort im Krug"** |
| **Ulrich Esch** | **„Meister Gratz"** – bei seinem Besuch an `old_01` erzählt er vom Lehrmeister. Aufgabe `tend`: `old_01` an 3 Morgen in Folge sauber. | **„Ein Gitter für die Frischen"** (ab `robber_known`) – er will ein Grabgitter nach Stadtmuster schmieden. Aufgabe `deliver`: 4 `iron_bar`, 2 `charcoal`. Danach Grabgitter **8** statt 12, das erste geschenkt. | **„Feierabend unter der Linde"** – an zwei verschiedenen Abenden mit ihm auf der Bank sitzen (17:34–19:00, je 20 Min, `meet` ×2). Er erzählt von seiner Frau, die im Kindbett starb: „Quast war dabei. Er hat getan, was er konnte. Das sag ich jedem." → **„Umsonst geschmiedet"** |
| **Theres** Mangold | **„Mutters Grab"** – bei ihrem Besuch an `old_08`: Christrosen setzen und bis zu ihrem nächsten Besuch frisch halten (`flowers`, wie ein Wunsch). | **„Das Anschreibebuch"** – im Buch ihrer Mutter stehen noch Schulden von Toten. Sie will die Seiten am Lichtgang verbrennen, aber erst wissen, wer davon oben liegt. Aufgabe `task`: in der Hütte am Grabregister die Namen abschreiben („[E] Namen für Theres abschreiben (20 Min, 1 Tinte)" → `register_extract`) und abgeben. Am Lichtgang verbrennt sie die Seiten am Kirchhof (Szene, Glut ohne Licht). Ersatz: am Abend danach am Brunnen. | **„Für die ohne Namen"** – sie gibt 3 Töpfe Christrosen für drei Gräber **ohne** Angehörige; setzen und frisch halten bis zum dritten Morgen (`flowers` ×3). Ruf +1. → **„Aus der Stadt bestellt"** |
| **Pfarrer Lenz** | **„Die Namen im Buch"** – er bittet um Namen und Tage der Lindenacker-Toten fürs Sterbebuch (`deliver` `register_extract`). Beim Abgeben sieht er, dass du den Dreistrich kennst: „Tinte ist Tinte, Totengräber. Manchmal ist sie eben früher da." | **„Das Archiv"** – hilf ihm, das Pfarrarchiv in der Kirche zu ordnen (16:00–18:00, `task archive_help` 60 Min neben ihm). Du findest **Lorenz' zweite Kladde** (`c_n_kladde`, §1.6). Lenz sieht es nicht, oder er tut so. | **„Das Wort am Lichtgang"** – am Lichtgang neben ihm am Kirchhof die Namen der Toten ohne Angehörige vorlesen (`task lights_names`, 10 Min, 17:40). Ersatz: am Abend danach in der Kirche („Dann lesen wir sie eben drinnen."). → **„Fürbitte"** |
| **Schultheiß Fenner** | **„Die Beine"** – die Wassersucht wird schlimmer; er bittet diskret um einen Wacholderumschlag: 2 `juniper` + 1 `linen` (`deliver`; ein `dropsy_powder` aus Phase 7 zählt auch). | **„Ein Platz mit Blick"** – er kommt um 16:00 herauf (statt Gemeindetafel) und will sich in der dritten Reihe eine Stelle **vormerken**, „mit Blick aufs Amtshaus, falls man das von oben sieht" (`meet` an `l_12`; nur ein Vermerk im Register, keine Sperre). Er gibt dir den **Gemeindeschlüssel zum Archiv** („Die Hälfte der Akten da drin gehört der Gemeinde."): **zweiter Weg zur Kladde** (`task archive_help` allein, Kirche 08:00–18:00). | **„Eine Runde von mir"** – abends im Holderkrug gibt er dir ein Bier aus (18:05–21:00, `meet`) und erzählt von seiner Frau, die unten auf dem alten Kirchhof bei St. Gallus liegt, „wo kein Totengräber mehr gräbt". → **„Der Nachtwächter"** |
| **Severin Quast** | **„Unter Kollegen"** – 2 `wound_salve` für die Wöchnerin bei den Siebers (`deliver`). Auch ohne Anatomie lösbar. | **„Die Kiste für die Stadt"** – eine versiegelte Kiste (`quast_crate`) morgens bis 07:40 zu Osrics Karren an der Bahre bringen (`deliver` → carter). Unterwegs: „[E] Hineinsehen" (freiwillig, nur Text): „Gläser, in Stroh. Auf jedem ein Name. Einige kennst du." | **„Was ich nicht aufschreibe"** – abends an der Holderbrücke (18:06–19:30, `meet`). Er erzählt, dass er seit dem Fährwinter zu jedem Krankenlicht geht, „auch wenn mich keiner holt". Mit `c_v_still_heart` (Phase 7) zwei Zeilen mehr über die stillen Herzen. → **„Arznei umsonst"** |
| **Liesel** Dorn | **„Kaspar"** (mit `insight_not_lorenz`) – an S5 „Lorenz Aschau (?)": Kaspars richtigen Namen auf den Stein setzen („[E] Namen nachmeißeln (40 Min, 1 Tinte)", nur gestalteter Stein; sonst `stone`-Auftrag für S5). **Ohne** die Erkenntnis: **„Wiebke"** – das Grab der Hagedorn 3 Morgen sauber und eine Nacht mit Kerze. | **„Die Totenwache"** – sie bittet dich, einmal mit ihr Totenwache zu halten: an einem Abend mit einer Leiche in der Gruft kommt sie um 21:30 die Treppe herab und sitzt eine Stunde bei ihr (`task vigil` 60 Min, du sitzt mit). Sie erzählt vom Waschen der Gezeichneten. Ersatz: die nächste Leiche. | **„Das Gesangbuch"** – sie zeigt dir ihr Gesangbuch mit den Namen der Gezeichneten seit dem Fährwinter. „Wenn ich sterbe, kommt es mit mir hinunter. Versprich es." (Flag `promise_liesel_book`, Haken Phase 18). Mit `i_underlined` eine stille Zeile mehr: „Sie schlägt die letzte Seite auf und wieder zu, bevor du lesen kannst." → **„Totenwäsche"** |

**Gefallen & Gegengefallen** (`FavorData`; erbitten im Gespräch „[Gefallen] …", einmal je **5 Tage** je Person, `favor_cooldown_days 5`)
| Gefallen | Wirkung | Gegengefallen (am Tag danach angeboten, 3 Tage Frist; Pool, einer gewählt) |
|---|---|---|
| Rosine „Ein Wort im Krug" | das nächste Ruf-Minus aus Gerede binnen 5 Tagen (`lecture_rumor`, `visit_*`, `grave_disturbed`) fällt weg; Rosine redet es klein | 6 `elderberries` · Jakob einen Tag freigeben (Lohn trotzdem) |
| Esch „Umsonst geschmiedet" | nach Wahl 3 `iron_fittings`, 1 `steel_rod` oder ein Grabgitter geliehen (10 Tage) | 6 `charcoal` · 2 `workstone` |
| Theres „Aus der Stadt bestellt" | eine Ware aus Hannes Kiepe außerhalb ihres Tages, am nächsten Morgen im Laden, zu Hannes Preis | 8 `herbs` · 4 `yarn` |
| Lenz „Fürbitte" | ein Grab nach Wahl: Geist +3 für 3 Nächte (beraubte Seelen höchstens gleichmütig, Phase 6) | 4 `altar_candle` · ein Grab ohne Angehörige mit frischen Blumen |
| Fenner „Der Nachtwächter" | eine Nacht nach Wahl kommt kein Grabräuber; Ruf +1 (`fenner_watch`) | 10 `wood` für den Gemeindezaun · 5 Münzen in die Armenkasse |
| Quast „Arznei umsonst" | 2 `fever_tincture` | 2 `herb_bundle` · 1 `spirits` |
| Liesel „Totenwäsche" | sie kommt um 09:40 in die Gruft und wäscht und kleidet die Leiche auf dem Gruft-Tisch, **sichtbar 60 Min** (`work`); die Herrichten-Schritte „waschen" und „einkleiden" sind danach erledigt (Leinen bzw. Totenhemd aus deinem Inventar) | 2 `linen` · 4 `yarn` |
- Erwidert: Beziehung **+4**. Nicht erwidert: **−6**, und der Gefallen ruht 7 Tage. Gegengefallen sind Aufträge der Kategorie `friend`. Kein Gefallen kostet oder bringt Münzen. *Begründung:* Ein Gefallen ist kein Kauf. Er wird erst zu etwas, wenn man ihn zurückgibt; wer nur nimmt, merkt es an der Beziehung.

### 2.5 Der Lehrling (`data/config/apprentice_config.tres` – `ApprenticeConfig`, `data/apprentice/tasks/<id>.tres` – `ApprenticeTaskData`)
#### 2.5.1 Jakob Wackernagel
- **Jakob Wackernagel**, 14, Rosines Sohn. In Phase 7 hatte er Fieber (`o_rosine_tincture`); jetzt ist er „nicht mehr zu halten". Aussehen: schmal, zu großer Kittel der Mutter mit hochgekrempelten Ärmeln, Wollmütze, rote Ohren, Sommersprossen, Holzschuhe; kleiner als der Totengräber (≈ 1,45 m). Stimme: eifrig, fragt nach, sagt „Herr Totengräber" und vergisst es nach drei Tagen. Pfeift bei der Arbeit, wenn er gut gelaunt ist.
- **Einstellen:** über Rosine Schritt 1 (§2.4). Vorher fragt er selbst nicht. Kein zweiter Lehrling.
- **Arbeitstag** (Friedhofs-Npc `npc_apprentice`, Zeitplan täglich aus der Arbeitsliste gebaut, §3.4):
  | Zeit | Ort | Tätigkeit |
  |---|---|---|
  | 07:30–07:45 | Dorf, Holderkrug | frühstückt, dann zur Brücke (Dorf-Npc `npc_apprentice_v`) |
  | 08:15 | Friedhof, Wegende | kommt den Kutschweg herauf |
  | 08:25–08:30 | Kreidetafel an der Hütte | liest die Liste (`read_board`), nimmt Werkzeug aus seiner Kiste (Werkzeug am Knochen `tool`) |
  | 08:30–12:00 | nach Liste | Arbeit (§2.5.2) |
  | 12:00–12:30 | Bank an der Hütte | Brotzeit (`sit_eat`) |
  | 12:30–15:30 | nach Liste | Arbeit; Kerzen erst ab 15:00 |
  | 15:30–15:40 | Kiste | Werkzeug zurück, Lohn aus der Lohndose (§2.5.5) |
  | 15:40 | Tor → Kutschweg | geht heim |
  | 17:00–21:00 | Dorf, Gaststube | hilft Rosine (Gespräch möglich: „Morgen wieder?") |
- **Freie Tage:** jeder siebte Tag (`day % 7 == 2`, „Jakob hilft heute im Krug": den ganzen Tag in der Gaststube; im Bogen A fällt er auf den Lichtgang), Festtage (am Lichtgang kommt er abends mit dem Zug), und nach 3 unbezahlten Tagen (§2.5.5). Bei Nacht, in der Gruft, in der Kapelle, im Schuppen und in der Hütte ist er nie.

#### 2.5.2 Aufgaben
| Aufgabe | Was | Stellen | Min je Stelle: Angelernt / Geübt (Spieler zum Vergleich) | Braucht (in seiner Kiste) | Typischer Fehler |
|---|---|---|---|---|---|
| `rake` **Laub harken** | Pflegestellen der Art `leaves` | Stufe ≥ 1 | **15 / 10** (Spieler 10) | `apprentice_rake` (Kinderrechen, Esch 3) | harkt das Laub aufs Nachbargrab: dort +1 Stufe Laub („Oh. Das war nicht das richtige.") |
| `weed` **Unkraut jäten** | Pflegestellen der Art `weeds` | Stufe ≥ 1 | **30 / 20** (Spieler 15–25) | – (Hände) | reißt frische Grabblumen mit aus, wenn welche da sind (sonst kein Fehler) |
| `water` **Blumen gießen** | Gräber mit Grabblumen, die heute oder morgen welken würden | – | **7 / 5** (Spieler 5) | `watering_can` (füllt am Regenfass nach, sichtbarer Gang) | tritt ins Beet: die Blumen sind sofort welk |
| `candle` **Grabkerzen** | Gräber im Abschnitt ohne brennende Kerze – Schalter „alle" oder „nur mit Wunsch" | ab 15:00 | **5 / 4** (Spieler 3) | `grave_candle` | die Kerze bricht: eine Kerze fort, das Licht brennt trotzdem |
- **Ungelernt** kann er die Aufgabe nicht („Das hast du mir noch nicht gezeigt."). **Fehlerquote** Angelernt **8 %**, Geübt **2 %**, deterministisch aus Tag, Stelle und Aufgabe (`ApprenticeRules.mistake`). Nach jedem Fehler eine Sprechblase; der Fehler steht in der Tageszusammenfassung.
- **Wege:** er geht wirklich von Stelle zu Stelle (Strecke über die Friedhofs-Wegpunkte; 1,6 m/s Echtzeit ≙ 3,2 m je Spielminute) und arbeitet mit dem Werkzeug in der Hand (`rake`, `weed`, `water`, `candle`, §8.2). Die Wirkung (Pflegestelle sauber, Blumen frisch, Kerze brennt) tritt **am Ende** der Arbeit an der Stelle ein, über dieselben Aufrufe wie beim Spieler (`CleanlinessManager.tend`, `GraveCare.water/light`).

#### 2.5.3 Die Arbeitsliste (Kreidetafel an der Hütte, Panel `&"apprentice_board"`)
- Bis zu **3 Zeilen**: Aufgabe + Bereich (`yard`, `east`, `north`, `elder`, `linden`, „alle" bzw. für Kerzen „nur mit Wunsch"). Jakob arbeitet die Zeilen von oben nach unten ab, innerhalb einer Zeile immer die **nächste** Stelle, die es braucht. Bleibt Zeit, fegt er den Kiesweg vor der Hütte (`sweep`, ohne Wirkung) und pfeift.
- Die Liste gilt, bis man sie ändert. Änderungen vor 08:25 gelten heute, danach ab der nächsten Stelle. Die Tafel zeigt Jakobs Stufen je Aufgabe als Kreidestriche (1 = Angelernt, 2 = Geübt) und die Münzen in der Lohndose.
- Jakob überspringt Gräber, an denen gerade jemand trauert (§2.2.3), und Stellen in gesperrten Abschnitten.
- *Kapazität:* 08:30–15:30 abzüglich Brotzeit = 390 Min; mit Wegen ≈ 12–16 Laubstellen oder 8–10 Unkrautstellen oder eine Mischung. Das nimmt dem Spieler **2–3 Stunden Pflege am Tag** ab.

#### 2.5.4 Anlernen
- **Ungelernt → Angelernt: einmal vormachen.** Im Gespräch: „Ich zeig dir, wie man Laub harkt." Jakob kommt auf 2 m heran und schaut zu (`watch`, Kopf folgt den Händen); die **nächste** fertige Handlung dieser Art des Spielers (Pflege Laub / Unkraut, Gießen, Kerze) schließt das Anlernen ab, sofern Jakob noch ≤ 4 m entfernt ist. Blase: „Ah. Von unten nach oben, nicht hin und her."
- **Angelernt → Geübt: Übung.** Nach **12** selbst erledigten Stellen dieser Aufgabe (`practice_jobs 12`).
- **Loben und Tadeln** (einmal je Tag im Gespräch): „Gut gemacht." → Zufriedenheit +1 (0…5, Start 3) · nach einem Fehler „Pass besser auf." → Zufriedenheit −1, Fehlerquote am nächsten Tag ×0,5, Rosine −1 (Ereignis `jakob_scolded`). Zufriedenheit ≥ 4: −10 % Minuten; ≤ 1: +20 %, und er pfeift nicht mehr.
- *Begründung:* Kein Erfahrungsbalken. Man sieht, was er kann (Kreidestriche), und hört, wie es ihm geht (Pfeifen, Blasen).

#### 2.5.5 Lohn & Kosten
- **3 Münzen je Arbeitstag**, um 15:30 aus der **Lohndose** in seiner Kiste (`ApprenticeBox`, 6 Plätze + Münzfach; der Spieler legt Münzen hinein). Ausgabe `coins_spent(3, &"apprentice")`. *Begründung:* knapp unter dem Pflegegeld (4/Tag): Er kostet fast, was die Gemeinde für die Pflege zahlt, und gibt dafür die Stunden zurück.
- Dose leer: „Jakob geht heute ohne Lohn heim." Rosine −2. Nach **3** unbezahlten Tagen in Folge bleibt er daheim, bis die ganze Schuld in der Dose liegt (dann kommt er am nächsten Morgen). Zufriedenheit −2 je unbezahltem Tag.
- **Einmalig:** Kinderrechen (Esch 3) und Gießkanne (Esch oder Hanne 4) in seine Kiste. Kerzen und Setzlinge nimmt er aus der Kiste; fehlen sie, lässt er die Zeile aus und sagt es abends an der Tafel („Keine Kerzen mehr.").

#### 2.5.6 Was er nicht tut – Grenze zu Phase 14
- Jakob **fasst keine Leiche an**, gräbt kein Grab, schließt keines, setzt keinen Stein, baut nichts, stellt keine Zier, arbeitet an keiner Station, holt nichts aus dem Schuppen, geht nicht in die Gruft, nicht in die Kapelle und nicht nach Hollerbrück für dich; er arbeitet **nur bei Tag** und nur nach der Liste. Er bringt kein Pflegegeld und keinen Ruf. „Die Toten fasst du an. Das hat Mutter gesagt."
- **Phase 14 („Untote Arbeiter")** übernimmt, was ein Mensch nicht tun soll oder nicht tun kann: graben, tragen, Nachtwache, Arbeit ohne Lohn und ohne Feierabend. Der Lehrling bleibt ein Mensch mit Arbeitszeit, Lohn, Mutter, Laune und Fehlern. Phase 14 darf `ApprenticeTaskData` und den Planer (`ApprenticePlanner`) wiederverwenden; **kein Phase-8-System kennt Phase 14**, und Jakob wird nie untot.

### 2.6 Neue Figuren (`data/village/wanderers/<id>.tres` – `WandererData`, `data/shops/peddler.tres`, `data/config/robber_config.tres` – `RobberConfig`)
**Entscheidung: drei neue Figuren, alle mit eigenem Zweck für die anderen drei Schwerpunkte; der Pilger bleibt draußen (§13).** *Begründung:* Veit trägt das Geheimnis (Zeuge der Nacht), Hanne die Grabpflege (Ware, die es sonst nicht gibt), Lambert die Nacht auf dem Friedhof (Grund für Kerzen, Gitter und Wache). Ein Pilger hätte nur Text.
| id | Name | Rolle | Aussehen (gemalt, Palette der Figuren) | Stimme | Wo man sie trifft |
|---|---|---|---|---|---|
| `beggar` | **Veit Ammer**, 58 | Bettler, früher Fährknecht der Holderfähre, die im Winter 1831 kenterte; er hat überlebt, sein Bruder nicht | lange, geflickte Joppe, Fischerkappe, steifes rechtes Bein mit Stock, Blechbecher, grauer Stoppelbart, wache helle Augen | nüchtern, genau, redet in Wasserwörtern; bedankt sich nie, nickt | Dorf: Kirchtür 08:00–11:30 (sitzend) · an ungeraden Tagen 13:40–16:00 **außen am Friedhofstor** (sitzend) · sonst 13:00–17:00 Holderbrücke · 18:06–19:30 Holderbrücke · **21:00–23:30 Brunnenbank** (im Dunkeln, gesprächsbereit) · schläft in Osrics Remise |
| `peddler` | **Hanne Vogelsang**, 39 | Wanderhändlerin mit Kiepe, kommt aus dem Tal und geht über den Hügel weiter | hohe Kiepe mit Bändern, Blechzeug und Glöckchen, Kopftuch, grober Wollrock, Wanderstab, wettergegerbtes, lachendes Gesicht | schnell, rechnet laut, nennt jeden „Herzchen" außer dem Totengräber („Sie nicht. Sie sind zu ernst.") | jeden 6. Tag (`day % 6 == 1`): 09:30 über die Holderbrücke · **10:00–14:00 am Brunnen** (Laden) · 15:40–16:20 **außen am Friedhofstor** (Laden) · danach den Waldweg nach Westen hinauf (Ilses Weg) |
| `robber` | **Lambert Grell**, 33 | Nachtgräber, früher Tagelöhner in Ellbach | hager, dunkle Kapuzenjoppe, Halstuch, Blendlaterne mit einem Spalt Licht (nur leuchtendes Material, kein Licht), Spaten am Knochen `tool`, leerer Sack über der Schulter | leise, verlegen, höflich, wenn gestellt; schämt sich, aber nicht genug | nur nachts auf dem Friedhof (§2.6.3) |

#### 2.6.1 Veit Ammer – der Zeuge
- **Almosen:** „[E] Veit eine Münze geben" einmal je Tag (`coins_spent(1, &"alms")`), Pietät **+1** (`alms`), `stats.alms_given` +1. Keine Beziehung mit Zahl; Veit zählt nur Almosen und Gespräche.
- Nach dem **dritten Almosen** an verschiedenen Tagen (oder Zuhören + zwei Almosen) erzählt er von den drei Nachtgängern → `c_n_veit` (§1.6). Ab `robber_known` weiß er auch: „Der Grell kommt von unten, durch den Wald hinter dem Lindenacker. Er kommt, wenn die Erde frisch ist und kein Licht brennt." (Hinweis auf Kerzen, kein Hinweis-Objekt).
- Nachts an der Brunnenbank sagt er, wo heute Krankenlicht brennt („Bei den Otts. Seit gestern.").
- Am Lichtgang trägt er keine Kerze („Meine liegen im Wasser.") und steht am Tor.

#### 2.6.2 Hanne Vogelsang – die Kiepe (`ShopData` `peddler`, Ladenregeln wie Phase 7 §2.3, keine Beziehungsrabatte)
| verkauft (Preis · Vorrat je Besuch) | kauft (Preis · höchstens je Besuch) |
|---|---|
| `flower_seedlings` 2 · 6 · `grave_candle` 1 · 8 · `watering_can` 4 · 1 · `wax_wreath` 5 · 1 · `gold_leaf` 6 · 1 · `ink` 2 · 3 | `yarn` 1 · 6 · `wound_salve` 4 · 2 · `herb_bundle` 3 · 3 · `elder_wine` 3 · 2 |
- **Wachskranz** (`wax_wreath`): zählt als Blumen für Wünsche, welkt nie, aber **Geist +0** („Wachs riecht nicht."). Eine bewusste Wahl zwischen Pflege und Bequemlichkeit.
- Vorrat und Ankauf gelten für den ganzen Besuchstag (Dorf und Tor zusammen), Neuladen füllt nichts auf. Einnahmen „Verkauf an Hanne", Ausgaben Zweck `&"peddler"`.
- Im Gespräch: Neuigkeiten aus dem Tal (wechselnd, 8 Zeilen), über Ellbach und die offenen Gräber dort. Haken Phase 9: Briefe (`peddler_letters`, nur Daten).

#### 2.6.3 Lambert Grell – der Nachtgräber (`RobberConfig`, System `NightRobber`)
- **Wann:** frühestens in der Nacht nach `p8_open_day + 4`. Eine Nacht kommt in Frage, wenn es ein **Zielgrab** gibt: bestattet vor ≤ **5 Tagen** (`fresh_days 5`), `FILLED`/`MARKED`, **ohne Grabgitter**, **ohne brennende Grabkerze**, keine Nachtwächter-Nacht (Fenners Gefallen), Lamberts Geschichte noch offen. Die **erste** solche Nacht kommt er sicher (`first_guaranteed`), danach mit **35 %** (`chance 0.35`) und frühestens nach 2 Nächten Pause (`min_gap_nights 2`); deterministisch aus Tag und Seed. Ziel ist das frischeste Grab.
- **Ablauf (sichtbar):** 01:30 aus dem Wald südlich hinter dem Lindenacker (Wegpunkte `robber_far` → `robber_fence_out`), über den Südzaun, 01:50 am Grab; **gräbt** bis 05:00 (`dig_night`, Spaten in der Hand, gedämpftes Graben hörbar ≤ 25 m). Ungestört bis 05:00: er geht, das Grab ist **aufgewühlt** (§2.3), Ereignis `grave_disturbed`, Notiz am Morgen: „Am Grab von Hedwig Lamprecht ist die Erde aufgeworfen. Ein Spaten war hier, nicht deiner."
- **Begegnung:** Ist der Totengräber in der Friedhofs-Region **≤ 10 m** von ihm, während er gräbt, schreckt er auf (`startle`) und läuft (`run`) zum Südzaun des Lindenackers und in den Wald. Das Grab ist nur angegraben (Pflegestelle +1 Stufe, nicht aufgewühlt). `robber_encounters` +1.
- **Zweite Begegnung:** Er stolpert über den Aushub und bleibt sitzen. Dialog `robber`:
  - „Wer zahlt dich?" → „Ein Herr mit einem Koffer. Er riecht nach Branntwein und zahlt für Frische. Er sagt, für die Wissenschaft. Mehr weiß ich nicht." → Hinweis `c_n_robber` (kein Teil von `i_underlined`; Haken Phase 9 „Wer kauft Frische?").
  - „Steh auf. Wir gehen zum Schultheiß." → `robber_reported`: Ruf **+3**, Fenner **+4**; Lambert ist fort (in der Stadt), am nächsten Tag dankt Fenner.
  - „Lauf. Und komm nicht wieder." → `robber_let_go`: Pietät **+2**, Liesel **+2**, Fenner **−2** (er hört es von Veit); Lambert ist fort. Später Veit: „Der Grell hat Arbeit in der Ziegelei. Er lässt grüßen. Nicht dich, aber er meint dich."
- **Nie gestellt:** Nach der **dritten** aufgewühlten Nacht fängt ihn Fenners Nachtwächter (`robber_caught_watch`, kein Ruf). Fenner: „Drei offene Gräber, Totengräber. Drei." Danach ist Ruhe.
- Er nimmt nichts, er kämpft nicht, er tut dem Totengräber nichts. Eine Leiche verlässt das Grab nie (§2.3). Er kommt nicht in der Nacht nach dem Lichtgang und nie an ein Grab mit brennender Kerze.

### 2.7 Dorffeste (`data/festivals/<id>.tres` – `FestivalData`)
**Entscheidung: zwei Feste, die zum Kalender passen (Spieltag 1 = 3. Gilbhart 1834, Phase 5): der Kathreintanz und der Lichtgang** (Bestätigung §14.3). *Begründung:* Phase 8 beginnt Ende Nebelung (Bogen A: 24. Nebelung). Erntedank und Kirchweih (St. Gallus, 16. Gilbhart) sind dann vorbei. „Kathrein stellt den Tanz ein" ist der letzte Tanz vor dem Advent, und der Lichtgang ist ein **eigener Hollerbrücker Brauch**, der aus der Geschichte des Dorfes kommt (Fährwinter) und genau zum Friedhof passt. Kein Fest ist Pflicht fürs Kapitel (§1.5).

#### 2.7.1 Kathreintanz (`fest_kathrein`, 25. Nebelung = Spieltag 54, Priorität B)
- **19:00–23:00 in der Gaststube.** Ein Spielmann vom „Stumpf" sitzt mit der Fiedel am Ofen (`ph_chr_fiddler`, sitzend, ohne Rig, Bogenarm als Kindmesh in einem einfachen GDScript-Wiegen), Musik `ph_mus_dance` (Kontext `fest`, ersetzt die Dorfmusik). Tische an die Wand gerückt, Tannengrün und Bänder an den Balken (Kathrein-Schmuck nur an diesem Tag, §4.7).
- Da sind (Fest-Einträge mit `today_flag fest_kathrein_day`): Rosine, Esch, Theres, Fenner, Osric, Jakob, Lenz (19:00–20:00, „bis die Musik zu schnell wird"), Liesel (20:00–21:00), Hanne, wenn ihr Tag ist; Quast nicht. Paare tanzen auf der freien Fläche (`dance`, langsames Drehen und Wiegen; die starren Arme liegen auf den Schultern, §8.2).
- **Spieler:** ≥ 30 Min in der Gaststube → +2 bei allen Anwesenden (einmal, wie die Runde aus Phase 7) · „[E] Mit Theres tanzen (15 Min)" mit Partnern ≥ „Bekannt", höchstens 2, je **+3** (`kathrein_danced`) · die Runde (5) wie in Phase 7. Um 23:00: Rosine „Kathrein stellt den Tanz ein. Bis Weihnachten wird hier gesessen."
- Liegt Spieltag 54 vor `p8_open_day`, fällt der Kathreintanz in diesem Spiel aus (keine Verschiebung).

#### 2.7.2 Lichtgang (`fest_lights`, Vorabend des ersten Advents, 29. Nebelung = Spieltag 58, Priorität A)
- **Der Brauch:** Seit dem Fährwinter tragen die Hollerbrücker am Abend vor dem ersten Advent Lichter zu ihren Toten hinauf, „damit die, die im Wasser geblieben sind, den Weg sehen". Bis Lorenz fortging, war der Hügel an diesem Abend voller Lichter; letztes Jahr ging niemand hinauf.
- **Ablauf (alles sichtbar):**
  | Zeit | Ort | Geschehen |
  |---|---|---|
  | 07:40 | Bahre | Osric bringt 12 `grave_candle` vom Pfarrer: „Für die, zu denen keiner hinaufgeht." |
  | 16:00 | Dorf, Holderbrücke | alle sammeln sich mit Laternen (leuchtendes Material, kein Licht an Figuren) |
  | 16:45–17:00 | Friedhof, Kutschweg → Tor | der Zug kommt herauf: Lenz vorn, dann Haushalte und Bewohner, Jakob trägt die Laterne für seine Mutter (Region-Übergang an `road_end` wie bei Besuchen) |
  | 17:00–17:40 | an den Gräbern | jede Familie stellt ihre Lichter auf ihre Gräber und steht oder kniet 10 Min (Besuchsablauf §2.2.3 ohne Wunsch); Theres verbrennt am Kirchhof die Seiten (wenn Schritt 2) |
  | 17:40 | Kirchhof vor der Kapelle | Lenz spricht drei Sätze (kein Predigt-Minispiel): „Wir zünden kein Licht für Gott an. Der sieht auch so. Wir zünden es für die an, die den Weg vergessen haben." Glocke der Kapelle (ab Stufe 2, sonst Handglocke). Lenz Schritt 3: du liest die Namen. |
  | 18:00–18:30 | Tor → Kutschweg | der Zug geht hinunter; die Lichter brennen bis 07:00 |
- **Spieler:** Lenz' 12 Kerzen auf Gräber **ohne** Angehörige stellen und anzünden (3 Min je Grab; Jakob nicht, er hat frei). Die Zielzeile zählt mit: „Kein Grab ohne Licht: 31/34". Brennt um **18:00** auf jedem belegten Grab ein Licht → `lights_all`: **Ruf +3**, alle Bewohner **+2**, Lenz +3, jeder Haushalt Wohlwollen +2, Pietät +2. Sonst bei ≥ der Hälfte `lights_some`: Ruf +1. (Bogen A: ≈ 34 belegte Gräber, davon ≈ 14 mit Angehörigen; 12 Kerzen von Lenz + ≥ 8 eigene.)
- **Geister:** Auf Gräbern mit Licht zeigen sich die Geister in dieser Nacht schon ab 17:00, eine halbe Stunde lang nur als blasser Schimmer (Alpha 0,35, nur der Totengräber sieht sie; `GhostManager.early_window`, reine Darstellung), danach normal. Ihre Stimmung bekommt für diese Nacht +2 statt +1 für die Kerze. Eigener Zeilen-Pool `by_lights`.
- **Kein Grabräuber, keine Besuche bei Tag, Jakob frei, Ilse kommt nicht** („Am Lichtgang? Zu viel Licht für eine wie mich.").
- **Verschiebung (einmal je Spiel):** Liegt Spieltag 58 **vor** `p8_open_day + 3`, findet der Lichtgang an `p8_open_day + 3` statt. Lenz: „Wir haben ihn verschoben. Der Hügel war nicht so weit." Flag `lights_held` nach dem Fest; danach kein zweiter Lichtgang in Phase 8.

### 2.8 Die dritte Reihe im Lindenacker (`data/sections/linden.tres` erweitert, Bestätigung §14.2)
**Vorschlag: Fenner gibt vier weitere Stellen `l_09…l_12` als dritte Reihe am Südrand des Lindenackers.** *Begründung:* Am Phase-7-Ende ist der Lindenacker voll (G7: alle Bots), es kommen keine Lieferungen mehr. Ohne neue Tote gäbe es in Phase 8 keine ersten Besuche, keinen Grund für den Nachtgräber und keinen Platz für D2. Vier Stellen tragen ≈ 4 Lieferungen im Bogen A, eine davon ist für D2 reserviert. Der Acker ist schon geweiht („Geweiht ist der ganze Acker, nicht die Reihe." – Lenz).
- Freigabe: erstes Gespräch mit Fenner ab `p8_open` (Flag `linden_row3_granted`, Notiz „Die Gemeinde gibt dir die dritte Reihe am Lindenacker."). Hindernisse ab der Freigabe: 1 Baumstumpf (`stump`, 30 Min, Axt-Faktor) und 1 Brombeere (`bramble`, 40 Min) = 70 Min. Die Plots öffnen, sobald beide geräumt sind (`ExpansionManager.try_unlock`, die Weihe gilt schon).
- Lage, Zaun und versetzte Elemente: §4.7 (L10–L13). Ohne Freigabe durch den Benutzer (§14.2 Option a) gibt es nur **eine** Stelle `l_09` am Westrand für D2, und der Bogen hat 1 statt 4 Lieferungen.

### 2.9 D2 Gerhard Ott (Geschichts-Leiche, `data/story/d2_ott.tres`, `data/finds/f_d2_*.tres`)
- **Gerhard Ott**, 74, Altbauer, `old_age` (laut Osric „das Herz, sagt Quast"), Merkmal `strange_wound` (gezeichnet), Look alter Mann (`ph_prop_corpse_03`), keine Wertsachen. Reihenfolge 7 nach D1. ✦ `StoryCorpseData.due_flag &"ott_dead"` setzt `NightPaths` in der Todesnacht (02:10); geliefert am Morgen danach (Osric 07:40), nur mit freier Stelle (in der dritten Reihe reserviert, Phase-4-Reservierungsregel). `kin_house` = `house_ott` (Gesa Ott besucht ab dem Tag nach der Bestattung).
- Osric bei der Ankunft: „Der alte Ott. Heute Nacht. Liesel war schon da, als ich kam. Sie ist immer schon da."
- **Funde** (Phase-4-Untersuchung): `f_d2_bottle` (Taschen, 0,0) „Ein Fläschchen, halb leer. Auf dem Etikett: ‚nach Quast – drei Tropfen am Abend'." · `f_d2_wax` (Kleidung, 0,0) „Ein Wachstropfen am Kragen. Kirchenkerzen tropfen so." · `f_d2_shirt` (Kleidung, 0,0) „Das Hemd unter dem Kittel ist frisch gewaschen und gestärkt. Wer wäscht einen Mann, bevor er tot ist?" · `f_d2_mark` (Wunden, 0,3, **ersetzt** `f_mark`) „Das Zeichen über dem Herzen, verheilt seit gut drei Wochen. Wie bei der Hagedorn." Sind `f_d2_bottle`, `f_d2_wax` und `f_d2_shirt` aufgedeckt → Hinweis `c_n_ott_three` (§1.6).
- Geist (`by_story`): „Drei waren da. Einer hat gebetet, einer hat gezählt, eine hat gewartet." · „Gesa hat Strohblumen gebracht. Die halten länger als ich."

### 2.10 Münzrechnung (würdevoller Spieler, Bogen A)
**Ausgangslage (G7, `qa_playthrough.md`):** `neighbor7` endet mit **60** Münzen, `anatomist7` mit **71** (G7 Runde 2). Phase 8 bringt **wenig neue Einnahmen** (4 Bestattungen in der dritten Reihe, Trinkgeld, Verkäufe an Hanne) und **laufende, kleine Ausgaben** (Lehrling 3/Tag, Kerzen, Setzlinge, Almosen, Grabgitter). Ziel: Der Beutel wächst nicht schneller als in Phase 7 (dort +40 in 13 Tagen), und **Trinkgeld bleibt bei höchstens einem Sechstel der neuen Einnahmen**.

| Einnahmen (10 Tage) | Rechnung | Münzen |
|---|---|---|
| Start (B1 früh) | W0-Messung | ≈ 60 |
| Pflegegeld | 9 × 4 (B2–B10) | 36 |
| Bestattungen in der dritten Reihe | 4 × ≈ 13 (G6/G7: ≈ 13 je Grab mit Stele) | 52 |
| Aussegnungsgebühren | 3 × 5 | 15 |
| **Trinkgeld** | 8 Wünsche mit Geld, je 2 (Kappe 4/Tag) | **18** |
| Verkäufe im Dorf und an Hanne (Kräuter, Garn, Wundsalbe) | gedeckelt je Tag (Phase 7 §2.3) | 25 |
| Geistergaben | Lichtgang, Andächtig | 5 |
| **Verfügbar** | | **≈ 211** |

| Ausgaben | Münzen |
|---|---|
| Lehrling: Lohn 8 Arbeitstage × 3 · Kinderrechen 3 · Gießkanne 4 | 24 · 7 |
| Grabblumen (4 Setzlinge) · Grabkerzen (14 eigene) · Wachskranz | 8 · 14 · 5 |
| Grabgitter (freiwillig) | 12 |
| Almosen (4 Tage) · Runde am Kathreintanz · Geschenke | 4 · 5 · 12 |
| Namenstafel (Tinte + Blattgold, Rosine Schritt 2) | 7 |
| Bestattungsware (Leinen, Wacholder, Altarkerzen für 4 Leichen) | 24 |
| Kleinkram (Tinte für Inschrift-Wünsche) | 1 |
| **Summe** | **123 (58 %)** |

| | B1 | B2 | B3 | B4 | B5 | B6 | B7 | B8 | B9 | B10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Morgens (+4 ab B2) | 60 | 57 | 56 | 65 | 67 | 64 | 70 | 82 | 83 | 90 |
| Ausgaben | 7 | 8 | 19 | 8 | 22 | 5 | 16 | 12 | 19 | 7 |
| Einnahmen (ohne Pflegegeld) | 0 | 3 | 24 | 6 | 15 | 7 | 24 | 9 | 22 | 5 |
| Abends | 53 | 52 | 61 | 63 | 60 | 66 | 78 | 79 | 86 | **88** |
- Morgens nie unter **56**; Ende ≈ **88** (+28 in 10 Tagen, langsamer als Phase 7). Ohne Grabgitter und Wachskranz ≈ 105, ohne Lehrling ≈ 119 (dafür ≈ 25 Stunden mehr Pflege). Trinkgeld = **16 %** der neuen Einnahmen ohne Start, 9 % des Verfügbaren.
- **Andere Wege (Erwartung für W3):**
  | Weg | Start | Ende (≈ 10 Tage) | Bemerkung |
  |---|---|---|---|
  | `kindly8` (v6 neighbor) | 60 | 75–100 | Bogen A; Kapitel B8–B10 |
  | `anatomist8` (v6 anatomist) | 71 | 80–110 | Präparate an 3 Lieferungen; Trinkgeld kleiner (Gerede §2.2.4), Lenz und Liesel höchstens „Bekannt": Kladde über Fenner |
  | `lazy8` (v6 neighbor, kein Lehrling, keine Wünsche angenommen) | 60 | 95–125 | Kapitel **nicht** erreicht (gewollt: Bedingungen 1 und 2) – bis zum Abbruch keine Fehler |
  | `night8` (v6 neighbor, jede Nacht wach, nie ein Gitter) | 60 | 85–110 | alle Beobachtungen, Lambert gestellt (beide Ausgänge über zwei Läufe), Kapitel erreicht |
  | `founder8` (v6 founder, neues Spiel) | ≈ 40–90 | wie A | Kapitel ≤ Tag 68, Lichtgang ggf. verschoben |
- **(G8 Runde 1 angepasst, E8-2 – Benutzer: „jetzt ausgleichen")** Gemessen lagen nur `kindly8` unter Start + 50 (anatomist8 +66, night8 +65, lazy8 +122): Einnahmen aus Phase 5–7 ohne Phase-8-Ausgaben. Zwei Phase-8-Regeln in den Daten (Phase-2–7-Werte unverändert):
  - **Pflegegeld nach Bedarf:** Ab `p8_open` zahlt die Gemeinde das Pflegegeld (Phase-3-Staffel 0…4) nur, wenn der Totengräber zu Tagesbeginn **weniger als 80 Münzen** hat – Beutel, Truhen und Jakobs Lohndose zusammen (`ReputationConfig.stipend_purse_cap 80`, `stipend_cap_flag p8_open`); sonst Notiz „Das Pflegegeld bleibt heute in der Gemeindekasse. Fenner: „Wer 80 Münzen im Kasten hat, braucht keins.“" *Begründung:* trifft nur, wer spart; wer pflegt und kauft, bleibt darunter (`kindly8` morgens höchstens 75).
  - **Gerede dorfweit (B8-3):** jedes Trinkgeld −1, sobald je ein Präparat verkauft wurde (§2.2.4).
  - Gemessen (Bot, 10 Tage): `kindly8` +20, `anatomist8` +43 (Trinkgeld 5 statt 12; `kindly8` 10), `night8` +53 (kein Gitter, keine Kerzen – die Nachtwache ersetzt sie), `lazy8` +92 (absichtlich untätig: kein Lohn, keine Pflegeware; vorher +122), `founder8` +5 (baut und kauft); morgens nie < 24, alle aktiven Wege erreichen das Kapitel.
- *Prüfregel:* Ende ≤ Start + 50 bei allen Wegen, Morgen nie < 5, Trinkgeld ≤ 25 je Bogen. **(G8 Runde 1 angepasst)** Band der aktiven Wege Start +15…+50 (grob; `night8` bis +55), `lazy8` ≤ +100; `anatomist8` Trinkgeld < `kindly8`; `kindly8` verpasst ≤ 20 % der Besuche. Liegt `kindly8` über Start + 50, senkt P2 zuerst `tip_cap_day` auf 3, danach P3 den Lohn nicht (er ist die Senke), sondern P2 die Hanne-Ankaufspreise um 1.

### 2.11 Items, Ruf, Pietät, Geister, Statistik
**Neue Items** (`data/items/*`, Phase 8)
| id | Name | Kategorie | Stapel | Herkunft | Zweck |
|---|---|---|---|---|---|
| `flower_seedlings` | Grabblumen (Heide, Christrosen im Topf) | MATERIAL | 10 | Theres 2, Hanne 2 | §2.3 |
| `grave_candle` | Grabkerze im Glas | MATERIAL | 10 | Theres 1, Hanne 1, Lenz (Lichtgang) | §2.3 |
| `watering_can` | Gießkanne | TOOL | 1 | Esch 4, Hanne 4 | Gießen (Füllstand in `GraveCare`) |
| `apprentice_rake` | Kinderrechen | TOOL | 1 | Esch 3 | nur in Jakobs Kiste sinnvoll |
| `mortsafe` | Grabgitter | GOODS | 4 | Esch 12 / 8 | §2.3 |
| `wax_wreath` | Wachskranz | GOODS | 5 | Hanne 5 | §2.6.2 |
| `register_extract` | Abschrift aus dem Grabregister | GOODS | 5 | Hütte, Register (20 Min, 1 Tinte) | Theres 2, Lenz 1 |
| `memorial_plate` | Namenstafel „Konrad Wackernagel" | CRAFTED | 1 | Steinmetzbank, 40 Min | Rosine 2 |
| `quast_crate` | versiegelte Kiste für die Stadt | GOODS | 1 | Quast | Quast 2 |
| `lorenz_ledger_2` | Lorenz' zweite Kladde | GOODS | 1 | Pfarrarchiv | im Merkbuch lesen → `c_n_kladde`; kann nicht verkauft werden |
- Neues Rezept `memorial_plate` (Station Steinmetzbank, `requires_flag friend_innkeeper_2`). Neue Laden-Einträge: Theres + `flower_seedlings` 2 · 4, `grave_candle` 1 · 6; Esch + `watering_can` 4 · 1, `apprentice_rake` 3 · 1, `mortsafe` 12 · 2 (ab `robber_known`, 8 nach Esch Schritt 2).

**Ruf** (`ReputationConfig.event_points` +): `visit_pleased +1`, `visit_neglected −1`, `visit_disturbed −3`, `visit_noise −1`, `visit_specimen_rumor −1`, `wish_done +1`, `robber_reported +3`, `lights_all +3`, `lights_some +1`, `fenner_watch +1`. Tageskappe für `visit_pleased` 2.
**Pietät** (`PietyConfig.events` +): `alms +1`, `listen +1` (Zuhören), `robber_let_go +2`, `lights_all +2`. Kein neues Minus: die Folgen des Verwahrlosens trägt der Ruf.
**Beziehung** (`RelationshipConfig.gains` +): `talk_cheerful 2`, `listen 3`, `danced 3`, `kathrein 2`, `wish_done_villager 4`, `friend_step_1/2/3` 6/8/10, `favor_returned 4`, `favor_unreturned −6`, `lights_all 2`, `jakob_scolded −1` (Rosine), `jakob_unpaid −2` (Rosine).
**Geister:** `GhostMood.score(…, care)` mit `care` ≤ +2 (Blumen/Strauß +1, Kerze +1, am Lichtgang Kerze +2, Lenz' Fürbitte +3 als eigener Posten `prayer`, gedeckelt wie Andacht Phase 6), `disturbed −3`. Neue Pools in `GhostLines`: `by_flowers` („Es riecht nach Heide. Das kenne ich vom Hof."), `by_candle` („Ein Licht. Für mich?"), `by_visited` („Sie war da. Sie hat nicht geweint. Das ist ihre Art."), `by_disturbed` („Jemand war an mir. Nicht du. Du gräbst anders."), `by_lights` („So viele Lichter. Ich dachte, ich bin allein hier oben."). Vorrang: `disturbed` > `robbed_organ` (P7) > `robbed` > `lights` > `visited` > `candle` > `flowers` > bisherige.
**Statistik** (`GameState.DEFAULT_STATS` +): `visits_seen`, `visits_total`, `wishes_done`, `wishes_failed`, `tips_coins`, `flowers_planted`, `candles_lit`, `mortsafes_set`, `graves_disturbed`, `graves_closed`, `apprentice_days`, `apprentice_jobs`, `apprentice_mistakes`, `apprentice_wage`, `friend_steps`, `favors_used`, `favors_returned`, `alms_given`, `chatters_seen`, `listens`, `dances`, `night_visits_observed`, `robber_encounters`, `coins_spent_apprentice`, `coins_spent_alms`, `coins_spent_peddler`.
**Münz-Zwecke** (`GameState.COIN_REASONS` +): `&"apprentice"`, `&"alms"`, `&"peddler"`. Einnahmen-Gründe: „Trinkgeld", „Verkauf an Hanne".

### 2.12 Osric und Ilse
- **Osric** (`carter.tres`, `carter_village.tres`, P6): `p8_intro` (§1.2) · Lichtgang-Kerzen (§2.7.2) · nach der ersten Nacht des Nachtgräbers: „Ich hab auf dem Weg einen gesehen, um zwei, mit Spaten. Ich hab nicht angehalten. Ich halte nie an." (setzt `robber_known`, falls noch nicht) · D2 (§2.9) · im Dorf über Jakob: „Der Junge fragt mir Löcher in den Bauch. Wie tief, wie lang, wie schwer. Ich sag ihm: frag den da oben." Keine Beziehung in Phase 8 (wie Phase 7).
- **Ilse** (`trader.tres`, P6), neue Fragen ab `p8_open`: „Kennst du einen Grell?" (ab `robber_known`) → „Der gräbt für die Stadt. Ich kaufe nur, was über der Erde liegt. Das ist ein Unterschied, auch wenn du ihn nicht siehst." · „Was weißt du über Veit?" → „Veit sieht alles und verkauft nichts davon. Das mag ich an ihm." · Am Lichtgang kommt sie nicht (Eintrag mit `today_flag fest_lights_day` verbirgt sie). Ilse bleibt ohne Beziehung und ohne Besuch am Grab.

### 2.13 Dialog-Leittexte (P6 schreibt aus, darf glätten; Ton: trocken-melancholisch, würdig)
**Jakob**
- Einstellung (Rosine 1, beim ersten Treffen auf dem Hügel): „Mutter sagt, ich soll lernen, was die Leute brauchen, auch wenn sie es nicht wollen. Wo fang ich an?"
- Erster Morgen an der Tafel: „Laub, Alter Hof. Das kann ich lesen. Das andere zeig ich mir dann, wenn du's mir zeigst."
- Nach dem Vormachen: „Ah. Von unten nach oben, nicht hin und her." · „Du ziehst das Unkraut, als ob es weh tut. Tut es weh?"
- Fehler: „Oh. Das war nicht das richtige Grab." · „Die Kerze ist mir gebrochen. Sie brennt trotzdem. Ein bisschen schief."
- Gelobt: „Sag's Mutter. Nein, sag's ihr nicht, sonst wird sie stolz, und dann ist sie unerträglich." · Getadelt: „Ja, Herr Totengräber." (am nächsten Tag ohne Pfeifen)
- Ohne Lohn: „Die Dose war leer. Ich komm morgen trotzdem. Übermorgen vielleicht nicht."
- Grenze: „Die Toten fasst du an. Das hat Mutter gesagt. Ich mach das Laub."
- Am Lichtgang, mit der Laterne der Mutter: „Für Vater. Der liegt nicht hier. Ich stell sie trotzdem hin."
**Besucher** (je Haushalt eigene Fassungen; Beispiele Martha Kehr)
- Begrüßung: „Grüß Gott. Ich bleib nicht lange. Er hat auch nie lange gestanden."
- nach dem Ansehen, gepflegt: „Sauber. Das hätte ihm gefallen. Er hat nie was sauber gehabt." · verwahrlost: „Das Unkraut ist schneller als du, Totengräber. Bei ihm war es auch so." · aufgewühlt: „Wer war das? Wer war an ihm?"
- Wunsch: „Ein paar Blumen. Heide, wenn's geht, die hält den Winter. Ich komm in drei Tagen wieder." · erfüllt: „Heide. Du hast es nicht vergessen. Hier, nimm. Nein, nimm es." · verfehlt: „Nichts. Na ja. Du hast viele."
- Gesa Ott (nach D2): „War er schwer? Ich mein nicht beim Tragen. Ich mein am Ende." · Johann Sieber (zum Grab, nicht zu dir): „So, Grete. Der Totengräber hat gefegt. Jetzt hast du es besser als ich."
**Veit Ammer**
- Almosen: „Hm." (nickt) · beim dritten: „Du gibst, ohne zu fragen, was ich damit mache. Lorenz hat auch nie gefragt. Setz dich, wenn du willst."
- Nachts an der Brunnenbank: „Bei den Otts brennt Licht. Seit gestern. Heute kommt einer, vielleicht zwei."
- Über die Fähre: „Das Wasser hat siebzehn genommen und mich wieder ausgespuckt. Seitdem schlaf ich schlecht. Man sieht viel, wenn man schlecht schläft."
**Hanne Vogelsang**
- „Grabkerzen, Herzchen – nein, Sie nicht, Sie sind zu ernst. Grabkerzen, Totengräber. Eine Münze das Stück, und sie brennen bis zum Hahnenschrei."
- Neuigkeit: „In Ellbach haben sie wieder eins offen gefunden. Leer war es nicht, nur offen. Das macht es nicht besser."
**Lambert Grell** (gestellt)
- „Ich nehm nichts. Ich hab noch nie was genommen. Ich komm nicht tief genug, bevor es hell wird. Das weiß er, und er zahlt trotzdem."
- „Wer zahlt dich?" → „Ein Herr mit einem Koffer. Er riecht nach Branntwein und zahlt für Frische. Er sagt, für die Wissenschaft."
**Lenz am Lichtgang** (am Kirchhof, drei Sätze, dann Glocke)
- „Wir zünden kein Licht für Gott an. Der sieht auch so. Wir zünden es für die an, die den Weg vergessen haben. Und für die, die noch hier unten sind und ihn suchen."
**Geschichten (Anfänge)**
- Rosine 1: „Du hast Augen wie einer, der nicht viel schläft. Gut. Mein Jakob schläft zu viel. Nimm ihn mit hinauf. Er soll lernen, was die Leute brauchen, auch wenn sie es nicht wollen."
- Fenner 2: „Ich möchte mir einen Platz ansehen. Für später. Sehr viel später, verstehen Sie. Mit Blick aufs Amtshaus, wenn man das von oben sieht."
- Quast 3: „Ich gehe zu jedem Licht im Fenster, Totengräber. Auch wenn mich keiner holt. Seit dem Fährwinter. Ich war zu spät damals. Siebzehnmal."
- Liesel 3: „Hier stehen sie alle. Die mit dem Zeichen. Ich hab sie gewaschen und hineingeschrieben, damit sie nicht nur bei mir sind. Wenn ich sterbe, kommt das Buch mit mir hinunter. Versprich es."
- Kapitel-Schlusszeile (Standard): „Früher kam nur Osric den Hügel herauf. Jetzt muss man am Tor manchmal warten, bis einer vorbei ist."

---

## 3. Architektur

### 3.1 Neue Knoten
**Systemknoten** (unter `WorldRoot/Systems`, vom Welt-Builder angelegt; keine neuen Autoloads):
| Knoten | Klasse | Gruppen | save_id / save_order |
|---|---|---|---|
| `NpcLife` | `NpcLife` | `npc_life`, `saveable` | `npc_life` / **70** |
| `Visitors` | `Visitors` | `visitors`, `saveable` | `visitors` / **71** |
| `GraveCare` | `GraveCare` | `grave_care`, `saveable` | `grave_care` / **72** |
| `Apprentice` | `Apprentice` | `apprentice`, `saveable` | `apprentice` / **73** |
| `Friendship` | `Friendship` | `friendship`, `saveable` | `friendship` / **74** |
| `Festivals` | `Festivals` | `festivals`, `saveable` | `festivals` / **75** |
| `Wanderers` | `Wanderers` | `wanderers`, `saveable` | `wanderers` / **76** |
| `NightRobber` | `NightRobber` | `night_robber`, `saveable` | `night_robber` / **77** |
| `NightPaths` | `NightPaths` | `night_paths`, `saveable` | `night_paths` / **78** |
| `ChatterRunner` | `ChatterRunner` | `chatter` | – (nicht gespeichert) |

**Entitäten** – Friedhof: `Entities/npc_apprentice`, `npc_kin_kehr|brandt|ott|sieber`, `npc_innkeeper_g`, `npc_smith_g`, `npc_grocer_g`, `npc_mayor_g`, `npc_washer_g` (der Pfarrer nutzt `npc_priest` aus Phase 7), `npc_beggar_g`, `npc_peddler_g`, `npc_robber` (alle `Npc`, Region graveyard; ohne Plan unsichtbar wie verborgene Npc), `apprentice_board` (`ApprenticeBoard`), `apprentice_box` (`ApprenticeBox extends Chest`, saveable `apprentice_box` / **79**), `rain_barrel` (`RainBarrel`), je Grab ein `TipStone` (Kind des `GravePlot`, ohne eigenes Speichern – Zustand in `Visitors`), Abschnitt-Erweiterung `linden` (Plots `l_09…l_12`, 2 Hindernisse). Dorf: `npc_apprentice_v`, `npc_beggar`, `npc_peddler` (Region village), `WatchSpot` × 2 (`watch_ott`, `watch_kehr`), `SickLight` × 2 (an den Fenstermarkern der Häuser), in der Gaststube `FestDecor` (Kathrein) + `ph_chr_fiddler`, in der Kirche `ArchiveCabinet` (`src/entities/archive_cabinet/*`) und die Namenstafel am Gedenkbrett (`MemorialPlate`, sichtbar ab Rosine 2).

### 3.2 Module & Besitz (Phase 8)
| Modul | Besitzt (Pfade) |
|---|---|
| **Lead** (W0 + laufend) | `project.godot`, `src/core/*` (EventBus, Database), alle **Datenklassen ✦**, alle **Stubs** (bis zur Übergabe), `tests/run_tests.gd`, `tests/framework/*`, `tests/fixtures/*` (inkl. **`saves_v6/*`**, `phase8/*`), `tests/integration/test_saves_v6_load.gd`, `tests/unit/test_phase8_scaffold.gd`, `docs/*`, `CLAUDE.md` |
| **P1 Dorfleben & Figurenlast** | `src/systems/npc_life/{npc_life,mood_rules,chatter_runner,reaction_rules}.gd` (neu), `src/systems/npc/{schedule_builder,npc_lod,schedule_resolver}.gd`, `src/entities/npc/{npc,npc_pose}.gd` (Laufzeit-Zeitplan, Hut-/Strauß-Kindmeshes, `idle_low`, LOD-Kappen je Region), `src/systems/village/relationships.gd` (nur Gerede-Vorrang „Ereignis" und die neuen `gains`), `data/config/{npc_life_config,npc_config,relationship_config}.tres`, `data/village/villagers/*` (`circle`, `mood_lines`, Reaktions-Gerede), `tests/unit/{test_moods,test_chatter,test_schedule_builder,test_npc_lod,test_reactions}.gd` |
| **P2 Besucher, Wünsche & Grabpflege** | `src/systems/visitors/{visitors,visit_rules,wish_rules,grave_view}.gd` (neu), `src/systems/grave_care/{grave_care,grave_care_rules}.gd` (neu), `src/entities/{tip_stone,rain_barrel}/*` (neu), `src/entities/grave/{grave_plot,grave_plot_visuals}.gd` (alle neuen Prompts und Kindmeshes: Blumen, Kerze, Gitter, aufgewühlt, Münzen, Zeile nachmeißeln), `src/systems/graveyard/graveyard.gd` (nur `disturbed`, `append_inscription`, `replace_name_line`), `src/systems/ghosts/{ghost_mood,ghost_manager}.gd` (`care`, `disturbed`, `prayer`, `early_window`, neue Pools), `src/systems/corpse/corpse_manager.gd` (nur `kin_house` bei der Lieferung), `data/visitors/*`, `data/config/{visitor_config,grave_care_config,reputation_config,piety_config,ghost_config}.tres`, `data/ghosts/ghost_lines.tres`, `tests/unit/{test_visitors,test_wishes,test_grave_view,test_grave_care,test_ghosts}.gd` |
| **P3 Lehrling** | `src/systems/apprentice/{apprentice,apprentice_rules,apprentice_planner}.gd` (neu), `src/entities/{apprentice_board,apprentice_box}/*` (neu), `src/systems/cleanliness/cleanliness_manager.gd` (nur `tend_by(spot_id, actor)` ohne Inventar-Prüfung), `data/apprentice/*`, `data/config/apprentice_config.tres`, `tests/unit/{test_apprentice,test_apprentice_planner,test_apprentice_rules}.gd`, `tests/integration/test_apprentice_day.gd` |
| **P4 Freundschaft, Gefallen & Feste** | `src/systems/friendship/{friendship,friend_rules,favor_rules}.gd` (neu), `src/systems/festivals/{festivals,festival_rules}.gd` (neu), `src/systems/village/{orders,order_rules}.gd` (Kategorie `friend`, Arten `meet`/`task`, `max_active_friend`), `src/entities/{fest_decor,memorial_plate,archive_cabinet,fiddler}/*` (neu), `data/friendship/*`, `data/festivals/*`, `data/orders/of_*.tres` (Freundschafts- und Gegengefallen-Aufträge), `data/recipes/memorial_plate.tres`, `data/config/orders_config.tres`, `tests/unit/{test_friendship,test_favors,test_festivals,test_orders}.gd`, `tests/integration/test_lights_evening.gd` |
| **P5 Assets** | `tools/blender/{asset_apprentice,asset_mourners,asset_wanderers,asset_props_phase8}.py` (neu), `tools/blender/{asset_villagers,asset_character,asset_items}.py` (nur neue Clips bzw. Icons), `tools/blender/rig.py` (nur neue Pose-Helfer, additiv), `tools/blender/build_all.py`, `assets/models/**` (nur Phase-8-Dateien und die neu exportierten Figuren mit Zusatz-Clips), `art_source/blender/**` (Phase 8), `tests/unit/test_assets_phase8.gd`, `docs/reviews/phase8_assets/*` |
| **P6 Dialog, Geschichte & Speichern** | `data/dialogue/*` (alle bestehenden + neu `v_apprentice`, `beggar`, `peddler`, `robber`, `kin_{kehr,brandt,ott,sieber}`, `lights_lenz`), `data/npc_life/chatter/*` (Texte), `data/npc/*_schedule.tres` (neue Figuren, Fest-, Besuchs- und Nachtweg-Einträge), `src/systems/dialogue/{dialogue_conditions,dialogue_actions}.gd`, `src/systems/journal/journal_manager.gd` (nur `any_clues`), `src/systems/story/story_director.gd` (D2), `src/systems/village/village.gd` (nur `mourning_house_for` als statische Funktion), `data/story/d2_ott.tres`, `data/finds/f_d2_*.tres`, `data/journal/{clues,insights}/*` (Phase 8, alle drei Varianten von `i_underlined`), `src/systems/save/{save_migration,save_file_io,save_manager}.gd`, `src/systems/game_state/game_state.gd` (Stats, Zwecke), `data/config/story_config.tres` (`underlined`), `tests/unit/{test_dialogue,test_save,test_save_migration,test_story,test_journal,test_game_state}.gd`, `tests/integration/test_phase7_save_upgrade.gd` |
| **P7 Nacht & Wanderer** | `src/systems/night/{night_robber,robber_rules,night_paths,night_path_rules}.gd` (neu), `src/systems/village/wanderers.gd` (neu), `src/entities/{watch_spot,sick_light}/*` (neu), `data/night/*`, `data/village/wanderers/*`, `data/shops/*` (Hanne neu; Theres/Esch-Zusätze), `data/config/robber_config.tres`, `data/items/*` (Phase-8-Items), `tests/unit/{test_night_robber,test_night_paths,test_wanderers,test_shops_phase8}.gd`, `tests/integration/test_night_watch.gd` |
| **W-Welt** (W2) | `data/world/graveyard_layout.json` (dritte Reihe, Besucherplätze, Routen, Lehrlingsecke, Regenfass, Räuberweg, Veit-/Hanne-Plätze §4.7), `data/world/village_layout.json` (Krankenlicht-Marker, Beobachtungsplätze, Veit/Hanne), `data/world/interiors/{inn,church}_layout.json` (Kathrein-Schmuck, Spielmann, Archivschrank, Namenstafel), `src/world/graveyard/*` (neu `graveyard_build_phase8.gd`, `graveyard_shots_phase8.gd`), `src/world/village/*` (neu `village_build_phase8.gd`; `village_shots.gd` + `--phase8`), `src/world/interiors/*`, `tools/blender/asset_ground_graveyard.py` (nur Lindenacker-Reihe 3), `tests/integration/{test_graveyard_world,test_village_world,test_phase8_loop,test_interiors,test_visit_routes}.gd`, `docs/reviews/phase8_round1/*` |
| **W-UI** (W2) | `src/ui/**` (neu `panels/{apprentice_board_panel,wish_card,favor_panel,fest_panel}.gd`, `hud/{chatter_bubbles,fest_banner}.gd`, `phase8_texts.gd`; Merkbuch-Seiten „Angehörige", „Hollerbrück" (+ Laune, Geschichtspunkte), Grab-Tooltip, Tageszusammenfassung, Abschluss-Panel; `src/ui/map/*` Marker §7.8), `src/debug/*` (neu `debug_commands_phase8.gd`; außer `asset_preview.gd`, `screenshot_capture.gd`), `tests/unit/{test_ui_phase8,test_objective,test_map_phase8}.gd`, `tests/integration/test_ui_flow.gd` |
| **W-Ton** (W2, Agent 17) | `tools/audio/build_audio.py` (nur neue Cues), `assets/audio/**` (nur neue `ph_*`), `data/audio/{audio_config,audio_events}.tres`, `data/audio/cues_*.tres` (generiert), `src/systems/audio/{audio_world,audio_events}.gd` (nur neue Emitter/Regeln), `tests/unit/test_audio_phase8.gd`, `docs/reviews/phase8_round1/audio_list.md` |
| **W3 QA** | `tests/integration/{phase3_bot,…,phase7_bot,phase8_bot,test_phase8_playthrough,test_phase8_qa,test_save_fuzzer}.gd`, `docs/reviews/phase8_wip/*` |
| **Eingefroren** | `src/world/art_prototype/*`, `src/entities/player/player_proto.*`, `data/art_prototype/*`, **Maler-Shader**, `data/atmosphere/*`, `lib_faces.py` (nur benutzen), alle Gebäude, Innenräume außer den genannten Einträgen in `inn`/`church`, Abschnitte I–V außer der Lindenacker-Reihe 3, Dorf-Plan außer den Markern §4.7, Präparate- und Anatomie-Systeme aus Phase 7 |

✦ **Datenklassen (W0, Lead):** `NpcLifeConfig`, `ChatterData`, `VisitorConfig`, `KinData`, `WishData`, `GraveCareConfig`, `ApprenticeConfig`, `ApprenticeTaskData`, `FriendStoryData`, `FriendStepData`, `FavorData`, `FestivalData`, `WandererData`, `RobberConfig`, `NightPathData`, `NightVisitData`. Erweiterungen: `NpcConfig` (+ `walk_m_per_minute 3.2`, `max_visible_graveyard 9`, `max_visible_fest 16`, `stand_rest_distance 26.0`, `fest_reduced_interval 0.33`), `VillagerData` (+ `circle`, `mood_lines`, `story_id`, `favor_id`, `visit_grave`, `visit_every_days`, `graveyard_npc`), `OrderData` (+ `category`, Arten `meet`/`task`), `OrdersConfig` (+ `max_active_friend`), `CorpseRecord` (+ `kin_house`), `GraveRecord` (+ `disturbed`, `extra_lines`), `InsightData` (+ `any_clues`, `any_count`), `ActionConfig`-Stichwörter (+ `noisy`), `ReputationConfig.event_points` (+ 10), `PietyConfig.events` (+ 4), `RelationshipConfig.gains` (+ 13), `GhostLines` (+ 5 Pools), `StoryConfig` (+ `underlined`).
Bei nur fünf Agents: **P1 + P3** (beide bauen Laufzeit-Zeitpläne), **P2 + P7** (Grab und Nacht hängen am selben Grabzustand), P4, P5, P6.

### 3.2.1 Klassen → Dateien
| Klasse | Datei | Art |
|---|---|---|
| `NpcLifeConfig`, `ChatterData` | `src/systems/npc_life/{npc_life_config,chatter_data}.gd` | ✦ |
| `NpcLife`, `MoodRules`, `ChatterRunner`, `ReactionRules` | `src/systems/npc_life/{npc_life,mood_rules,chatter_runner,reaction_rules}.gd` | Stub (P1) |
| `ScheduleBuilder` | `src/systems/npc/schedule_builder.gd` | Stub (P1) |
| `VisitorConfig`, `KinData`, `WishData` | `src/systems/visitors/{visitor_config,kin_data,wish_data}.gd` | ✦ |
| `Visitors`, `VisitRules`, `WishRules`, `GraveView` | `src/systems/visitors/{visitors,visit_rules,wish_rules,grave_view}.gd` | Stub (P2) |
| `GraveCareConfig` | `src/systems/grave_care/grave_care_config.gd` | ✦ |
| `GraveCare`, `GraveCareRules` | `src/systems/grave_care/{grave_care,grave_care_rules}.gd` | Stub (P2) |
| `TipStone`, `RainBarrel` | `src/entities/{tip_stone,rain_barrel}/*.gd` (+ `.tscn`) | Stub (P2) |
| `ApprenticeConfig`, `ApprenticeTaskData` | `src/systems/apprentice/{apprentice_config,apprentice_task_data}.gd` | ✦ |
| `Apprentice`, `ApprenticeRules`, `ApprenticePlanner` | `src/systems/apprentice/{apprentice,apprentice_rules,apprentice_planner}.gd` | Stub (P3) |
| `ApprenticeBoard`, `ApprenticeBox` | `src/entities/{apprentice_board,apprentice_box}/*.gd` (+ `.tscn`; Box `extends Chest`) | Stub (P3) |
| `FriendStoryData`, `FriendStepData`, `FavorData`, `FestivalData` | `src/systems/friendship/{friend_story_data,friend_step_data,favor_data}.gd`, `src/systems/festivals/festival_data.gd` | ✦ |
| `Friendship`, `FriendRules`, `FavorRules`, `Festivals`, `FestivalRules` | `src/systems/friendship/*.gd`, `src/systems/festivals/*.gd` | Stub (P4) |
| `FestDecor`, `MemorialPlate`, `ArchiveCabinet`, `Fiddler` | `src/entities/{fest_decor,memorial_plate,archive_cabinet,fiddler}/*.gd` (+ `.tscn`) | Stub (P4) |
| `WandererData`, `RobberConfig`, `NightPathData`, `NightVisitData` | `src/systems/village/wanderer_data.gd`, `src/systems/night/{robber_config,night_path_data,night_visit_data}.gd` | ✦ |
| `Wanderers`, `NightRobber`, `RobberRules`, `NightPaths`, `NightPathRules` | `src/systems/village/wanderers.gd`, `src/systems/night/*.gd` | Stub (P7) |
| `WatchSpot`, `SickLight` | `src/entities/{watch_spot,sick_light}/*.gd` (+ `.tscn`) | Stub (P7) |
| `ApprenticeBoardPanel`, `WishCard`, `FavorPanel`, `FestPanel`, `ChatterBubbles`, `FestBanner` | `src/ui/panels/*.gd`, `src/ui/hud/*.gd` | W-UI |

### 3.3 EventBus – neue Signale (Ergänzung `src/core/event_bus.gd`)
```gdscript
# Dorfleben (NpcLife, ChatterRunner)
signal moods_rolled(day: int)
signal chatter_line(chatter_id: StringName, npc_id: StringName, text: String)
# Besucher (Visitors); phase: &"arriving" | &"mourning" | &"waiting" | &"leaving" | &"gone"
signal visitor_changed(visit_id: String, kin_id: StringName, grave_id: String, phase: StringName)
signal grave_viewed(grave_id: String, kin_id: StringName, view: StringName)
# Wünsche (Visitors); state: &"offered" | &"accepted" | &"done" | &"failed"
signal wish_changed(wish_id: String, state: StringName)
# Grabpflege (GraveCare); kind: &"flowers" | &"bouquet" | &"candle" | &"mortsafe" | &"disturbed" | &"tip"
signal grave_care_changed(grave_id: String, kind: StringName, active: bool)
# Lehrling (Apprentice)
signal apprentice_job_done(task_id: StringName, spot_id: String, mistake: bool)
signal apprentice_level_changed(task_id: StringName, level: int)
# Freundschaft (Friendship); state: &"used" | &"returned" | &"unreturned"
signal friend_step_completed(npc_id: StringName, step: int)
signal favor_changed(npc_id: StringName, favor_id: StringName, state: StringName)
# Feste (Festivals); state: &"announced" | &"running" | &"ended" | &"cancelled"
signal festival_changed(fest_id: StringName, state: StringName)
# Nacht (NightRobber; kind: &"arrived" | &"seen" | &"fled" | &"caught" | &"disturbed" | &"gone") und Krankenlicht (NightPaths)
signal robber_event(kind: StringName, grave_id: String)
signal night_visit(path_id: StringName, npc_id: StringName, phase: StringName)   # &"enter" | &"leave" | &"observed"
```
Regel wie Phase 3–7: **Listener ändern keinen Spielzustand.** Wer ändert, ruft direkt auf: `Visitors` (Uhr, Npc-Plan) → `GraveView.view` → `Reputation.event`, eigenes Wohlwollen; Dialog → `Visitors.accept_wish/hand_tip`; `Visitors.on_visit_end` → `WishRules.check` → `payment_received(tip, "Trinkgeld")`, `Relationships.add` (Bewohner), `NpcLife.check_goal`; `GravePlot` → `GraveCare.plant/water/light/set_mortsafe/close_disturbed`, `Graveyard.append_inscription`; `Apprentice` (Ende einer Stelle) → `CleanlinessManager.tend_by`, `GraveCare.water/light`, `NpcLife.check_goal`; `Apprentice.pay_wage` → `GameState.note_coins_spent(3, &"apprentice")`; `DialogueActions` → `Friendship.offer/accept_step/use_favor`, `Apprentice.hire/teach/praise/scold`, `Wanderers.give_alms`, `NightRobber.resolve`, `Festivals.dance`; `Orders.complete` (Kategorie `friend`) → `Friendship.note_order_done` → `Relationships.add`, `NpcLife.check_goal`; `Festivals.apply_minute` → `Festivals.evaluate_lights` → `Reputation.event`, `Relationships.add`, `Visitors.add_goodwill`, `GhostManager.set_early_window`; `NightRobber.apply_minute` → `GraveCare.set_disturbed`, `CleanlinessManager.set_level`; `NightPaths.apply_minute` → `GameState.set_flag(ott_dead)`, `JournalManager.add_clue`; `StoryDirector` liest `ott_dead` (D2). `coins_spent` erhöht `stats.coins_spent` im Sender über `GameState.note_coins_spent`.

### 3.4 Logik-Klassen (Signaturen = Vertrag)

**Dorfleben & Figurenlast (P1)**
```gdscript
class_name NpcLifeConfig extends Resource            # ✦ data/config/npc_life_config.tres
@export var open_flag: StringName = &"p8_open"; @export var open_day_flag: StringName = &"p8_open_day"
@export var unlock_flag: StringName = &"name_in_village_complete"; @export var intro_minute: int = 360
@export var moods: Array[StringName] = [&"plain", &"cheerful", &"low", &"cross"]
@export var mood_weights: Dictionary[StringName, int] = {&"plain": 70, &"cheerful": 15, &"low": 10, &"cross": 5}
@export var mood_rules: Array[Dictionary] = []       # [{trigger, mood, npcs}] in Vorrang-Reihenfolge §2.1.1
@export var talk_gain_by_mood: Dictionary[StringName, int] = {&"plain": 1, &"cheerful": 2, &"low": 1, &"cross": 0}
@export var listen_minutes: int = 10
@export var chatter_distance: float = 10.0; @export var chatter_line_seconds: float = 3.5
@export var reactions: Dictionary[StringName, int] = {}   # Ereignis → Tage gültig (2)
@export var goal_levels: int = 2; @export var goal_wishes: int = 5; @export var goal_kin: int = 3
@export var goal_steps: int = 6; @export var goal_full_stories: int = 1; @export var goal_insight: StringName = &"i_underlined"
@export var chapter_id: StringName = &"who_comes_up"; @export var goal_flag: StringName = &"who_comes_up_complete"
class_name MoodRules extends RefCounted
static func roll(npc_id: StringName, day: int, cfg: NpcLifeConfig) -> StringName
static func apply_rules(base: StringName, npc_id: StringName, day: int, events: Dictionary, cfg: NpcLifeConfig, villager: VillagerData) -> StringName
class_name NpcLife extends Node                       # Gruppe npc_life, saveable npc_life / 70
func is_open() -> bool; func open_day() -> int
func apply_morning(day: int) -> void                  # 06:00: p8_open (idempotent), Launen würfeln, moods_rolled
func post_load() -> void                              # v6 mit name_in_village_complete → p8_open sofort
func mood(npc_id: StringName) -> StringName           # heutige Laune (abgeleitet, nicht gespeichert)
func note_event(event: StringName, npcs: Array[StringName] = []) -> void   # merkt Tag + Ereignis (Launen/Reaktionen)
func reaction_for(npc_id: StringName) -> StringName   # jüngstes gültiges Ereignis oder &""
func listen_block_reason(npc_id: StringName) -> String; func listen(npc_id: StringName) -> bool
func check_goal() -> bool                             # §1.5, genau einmal
func goal_progress() -> Dictionary                    # {levels, wishes, kin, steps, full, insight} für die Zielzeile
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
class_name ChatterData extends Resource               # ✦ data/npc_life/chatter/<id>.tres
@export var id: StringName; @export var region: StringName = &"village"; @export var npcs: Array[StringName] = []   # [a, b]
@export var place: StringName                          # Wegpunkt
@export var window: Vector2i                           # Minuten [von, bis]
@export var conditions: PackedStringArray = []        # Dialog-Syntax; + mood:<npc>:<mood>, fest_day:<id>, sick_light
@export var lines: PackedStringArray = []             # abwechselnd a/b, 2–4
@export var sets_flag: StringName = &""               # nur ch_rumor_robber
class_name ChatterRunner extends Node                 # Gruppe chatter, 2 Hz, eine Begegnung je Region zugleich
func update_now() -> void; func running(region_id: StringName) -> StringName
func seen_today(chatter_id: StringName) -> bool       # aus Tag + gespeicherter Liste in NpcLife (once/day)
class_name ReactionRules extends RefCounted
static func remark_key(npc_id: StringName, life: NpcLife, rel: Relationships) -> StringName   # Ereignis > friend > piety > rep
class_name ScheduleBuilder extends RefCounted         # Laufzeit-Zeitpläne (Besuche, Lehrling, Feste, Räuber)
static func walk(from_wp: StringName, path: PackedStringArray, start_minute: int, region: StringName, world: Node) -> ScheduleEntry
#   travel_minutes aus der Polylinie: Länge / NpcConfig.walk_m_per_minute (3,2)
static func stay(at_wp: StringName, start_minute: int, animation: StringName, dialogue_id: StringName = &"", visible := true) -> ScheduleEntry
static func build(entries: Array[ScheduleEntry]) -> NpcSchedule   # sortiert, Lücken = unsichtbar
# Npc (P1): func set_runtime_schedule(s: NpcSchedule) -> void   # ersetzt den Daten-Zeitplan bis clear_runtime_schedule(); nicht gespeichert
#           func clear_runtime_schedule() -> void
#   Kindmeshes nach Animation: Meta `show_with` am Kindmesh (hat_hand nur in mourn_stand/kneel, bouquet bis lay_flowers-Ende,
#   lantern_prop am Lichtgang) – Muster ToolProps, ohne neue Knoten zur Laufzeit
# NpcLod (P1): Kappen je Region: NpcConfig.max_full (6) bleibt; + max_visible_graveyard 9 (Lichtgang 16), Rang nach Abstand;
#   Stufe 2 für stehende Figuren (idle/kneel/mourn) ab 26 m statt 40 m; Lichtgang: Stufe-1-Rate 3 Hz
# ScheduleResolver (P1): unverändert; Laufzeit-Zeitpläne nutzen dieselbe Auswertung
# Relationships (P1): remark_text() fragt zuerst ReactionRules; note_talk() nutzt NpcLife.mood → talk_gain_by_mood
```

**Besucher, Wünsche & Grabpflege (P2)**
```gdscript
class_name VisitorConfig extends Resource            # ✦ data/config/visitor_config.tres
@export var first_delay_days: int = 1; @export var mourning_days: int = 21
@export var interval_mourning: int = 3; @export var interval_late: int = 7
@export var max_visits_day: int = 3; @export var max_concurrent: int = 2
@export var slots: PackedInt32Array = [570, 750, 900]
@export var flowers_chance_late: float = 0.4; @export var mourn_minutes: int = 30; @export var wait_minutes: int = 10
@export var noise_distance: float = 8.0; @export var talk_distance: float = 4.0
@export var goodwill_start: int = 5; @export var goodwill_wish_min: int = 2
@export var view_effects: Dictionary[StringName, Dictionary] = {}   # disturbed/neglected/bare/kept/bonus/specimen → {rep_event, goodwill}
@export var pleased_cap_day: int = 2
@export var max_open: int = 3; @export var tip_base: int = 1; @export var tip_goodwill_min: int = 6
@export var tip_quality_min: int = 15; @export var tip_cap_day: int = 4
@export var wish_goodwill: int = 2; @export var wish_fail_goodwill: int = -2; @export var villager_wish_rel: int = 4
class_name KinData extends Resource                  # ✦ data/visitors/kin/<id>.tres
@export var kin_id: StringName; @export var display_name: String; @export var house: StringName
@export var npc_path_id: StringName                  # Npc-Layout-Id auf dem Friedhof (npc_kin_kehr …) bzw. npc_<villager>_g
@export var villager_id: StringName = &""            # gesetzt: Bewohner (zahlt mit Beziehung)
@export var kneels: bool = true; @export var bouquet_model: StringName = &""; @export var dialogue_id: StringName
@export var fixed_graves: PackedStringArray = []     # old_01, old_08, D1-/S5-Grab
@export var visit_every_days: int = 0; @export var visit_minute: int = 0   # Bewohner (§2.1.4); 0 = Haushalt nach Plan
@export var first_offset: int = 0                    # erster Besuchstag = p8_open_day + first_offset (Esch 2, Theres 2, Liesel 1)
class_name WishData extends Resource                 # ✦ data/visitors/wishes/<id>.tres
@export var id: StringName; @export var kind: StringName   # &"tend" | &"flowers" | &"candle" | &"line" | &"vase"
@export var ask_text: String; @export var done_text: String; @export var failed_text: String
@export var line_text: String = ""                   # nur kind line
class_name Visitors extends Node                     # Gruppe visitors, saveable visitors / 71
func plan_day(day: int) -> Array[Dictionary]         # 06:00, deterministisch; [{visit_id, kin_id, graves, slot}] gespeichert
func visit_of(kin_id: StringName) -> Dictionary; func active_visits() -> Array[Dictionary]
func goodwill(kin_id: StringName) -> int; func add_goodwill(kin_id: StringName, delta: int) -> void
func kin_for_grave(grave_id: String) -> StringName
func offer_wish(visit_id: String) -> Dictionary      # {} | {wish_id, kind, grave_id, text}
func accept_wish(wish_id: String) -> bool
func open_wishes() -> Array[Dictionary]
func hand_tip(visit_id: String, inv: Inventory) -> int   # im Gespräch; sonst TipStone
func tip_on_stone(grave_id: String) -> Vector2i       # (Münzen, Angehörige-Index) oder (0, -1)
func take_tip(grave_id: String, inv: Inventory) -> int
func note_noise(pos: Vector3, action_id: StringName) -> void   # Player-TimedAction mit Stichwort noisy
func on_visit_phase(visit_id: String, phase: StringName) -> void   # vom Npc-Plan (Ansehen, Ende)
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
class_name GraveView extends RefCounted
static func view(grave_id: String, tree: SceneTree, cfg: VisitorConfig) -> Dictionary   # {view, bonus, specimen_rumor}
class_name WishRules extends RefCounted
static func choose(grave_id: String, kin_id: StringName, day: int, tree: SceneTree) -> StringName   # Wunsch-Id oder &""
static func fulfilled(wish: Dictionary, tree: SceneTree) -> bool
static func tip(goodwill: int, quality: int, paid_today: int, cfg: VisitorConfig) -> int
class_name GraveCareConfig extends Resource          # ✦
@export var flower_item: StringName = &"flower_seedlings"; @export var plant_minutes: int = 15
@export var flower_fresh_minutes: int = 2880; @export var flower_wilt_minutes: int = 5760
@export var water_minutes: int = 5; @export var can_item: StringName = &"watering_can"; @export var can_fills: int = 6; @export var refill_minutes: int = 2
@export var bouquet_minutes: int = 2880; @export var wreath_item: StringName = &"wax_wreath"
@export var candle_item: StringName = &"grave_candle"; @export var candle_minutes: int = 3; @export var candle_from_minute: int = 900; @export var candle_until_minute: int = 420
@export var mortsafe_item: StringName = &"mortsafe"; @export var mortsafe_set_minutes: int = 20; @export var mortsafe_remove_minutes: int = 10; @export var mortsafe_min_days: int = 10
@export var close_minutes: int = 30; @export var line_minutes: int = 30; @export var line_item: StringName = &"ink"
@export var care_cap: int = 2; @export var disturbed_mood: int = -3; @export var lights_candle_mood: int = 2
class_name GraveCare extends Node                    # Gruppe grave_care, saveable grave_care / 72
func flowers_state(grave_id: String) -> StringName  # &"" | &"fresh" | &"wilted" | &"wreath"
func plant_block_reason(grave_id: String, inv: Inventory) -> String; func plant(grave_id: String, inv: Inventory) -> bool
func water(grave_id: String, by_apprentice := false) -> bool
func can_fill(owner: StringName = &"player") -> int; func refill(owner: StringName = &"player") -> void
func place_bouquet(grave_id: String) -> void
func candle_lit(grave_id: String) -> bool; func light(grave_id: String, inv: Inventory) -> bool   # Apprentice übergibt seine Kiste
func lit_last_night(grave_id: String) -> bool
func has_mortsafe(grave_id: String) -> bool; func set_mortsafe(grave_id: String, on: bool, inv: Inventory) -> bool
func is_disturbed(grave_id: String) -> bool; func set_disturbed(grave_id: String) -> void; func close_disturbed(grave_id: String) -> bool
func care_bonus(grave_id: String) -> int             # ≤ care_cap; GhostMood liest es
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
# Graveyard (P2): + func append_inscription(grave_id: String, line: String) -> bool   # GraveRecord.extra_lines, StoneVisual neu
#                 + func replace_name_line(grave_id: String, name: String) -> bool     # Liesel 1 (S5 → Kaspar Dorn)
# GraveRecord ✦ + var disturbed: bool = false; var extra_lines: PackedStringArray = []   # tolerant
# GravePlot (P2): Prompts in dieser Reihenfolge nach den Phase-3–7-Prompts: Münzen nehmen · Grab schließen (aufgewühlt) ·
#   Blumen gießen · Grabblumen setzen / Wachskranz legen · Grabkerze anzünden · Grabgitter auf/ab · Zeile nachmeißeln
# GhostMood (P2): static func score(quality, dirt_level, decor_bonus, clean, cfg, robbed := 0, devotion := 0, care := 0) -> int
# GhostManager (P2): func set_early_window(from_minute: int, minutes: int, graves: PackedStringArray) -> void   # Lichtgang, Darstellung
# CorpseRecord ✦ + var kin_house: StringName = &""; CorpseManager (P2) setzt es bei der Lieferung ab village_open
# TipStone (P2): Kindmesh coins am Marker inscription; „[E] %d Münzen auf dem Stein (%s)" → Visitors.take_tip(grave_id, inv)
# RainBarrel (P2): „[E] Gießkanne füllen (2 Min)" → GraveCare.refill
```

**Lehrling (P3)**
```gdscript
class_name ApprenticeConfig extends Resource         # ✦ data/config/apprentice_config.tres
@export var npc_id: StringName = &"apprentice"; @export var hire_flag: StringName = &"apprentice_hired"
@export var arrive_minute: int = 495; @export var start_minute: int = 510; @export var lunch: Vector2i = Vector2i(720, 750)
@export var end_minute: int = 930; @export var wage: int = 3; @export var unpaid_limit: int = 3
@export var day_off_mod: int = 7; @export var day_off_rest: int = 2
@export var practice_jobs: int = 12; @export var teach_distance: float = 4.0
@export var mistake_rate: PackedFloat32Array = [1.0, 0.08, 0.02]   # Stufe 0 nie (kann nicht), 1, 2
@export var morale_start: int = 3; @export var morale_fast: int = 4; @export var morale_slow: int = 1
@export var fast_factor: float = 0.9; @export var slow_factor: float = 1.2; @export var scold_mistake_factor: float = 0.5
@export var board_lines: int = 3; @export var box_slots: int = 6
class_name ApprenticeTaskData extends Resource       # ✦ data/apprentice/tasks/<id>.tres
@export var id: StringName                           # rake | weed | water | candle
@export var label: String; @export var minutes: PackedInt32Array = [0, 15, 10]
@export var tool_item: StringName = &""; @export var consumes: StringName = &""
@export var spot_kind: StringName                    # leaves | weeds | flowers | candle
@export var from_minute: int = 0                     # candle 900
@export var animation: StringName; @export var mistake_kind: StringName; @export var mistake_text: String
class_name ApprenticeRules extends RefCounted
static func minutes_for(task: ApprenticeTaskData, level: int, morale: int, cfg: ApprenticeConfig) -> int
static func mistake(task_id: StringName, spot_id: String, day: int, level: int, scolded: bool, cfg: ApprenticeConfig) -> bool
static func works_today(day: int, hired: bool, unpaid: int, fest_today: bool, cfg: ApprenticeConfig) -> bool
class_name ApprenticePlanner extends RefCounted     # reine Planung, wiederverwendbar (Phase 14)
static func plan(day: int, from_minute: int, lines: Array[Dictionary], state: Dictionary, tree: SceneTree, cfg: ApprenticeConfig) -> Array[Dictionary]
#   [{task, spot_id, grave_id, start, work_minutes, path}] – nächste Stelle zuerst, überspringt trauernde Gräber, fügt Regenfass-Gänge ein
class_name Apprentice extends Node                   # Gruppe apprentice, saveable apprentice / 73
func is_hired() -> bool; func hire() -> void         # Rosine 1
func level(task_id: StringName) -> int; func jobs(task_id: StringName) -> int
func board_lines() -> Array[Dictionary]; func set_board_lines(lines: Array[Dictionary]) -> void   # [{task, area}]
func teach_block_reason(task_id: StringName, player: Player) -> String; func start_teach(task_id: StringName) -> void
func note_player_job(task_kind: StringName, pos: Vector3) -> void   # Spieler fertig → ggf. Angelernt
func praise() -> bool; func scold() -> bool; func morale() -> int
func unpaid_days() -> int; func pay_wage() -> bool  # 15:30 aus ApprenticeBox.coins
func today_plan() -> Array[Dictionary]               # aus Liste + Zustand um start_minute, gespeichert mit Fortschritt
func apply_minute(day: int, minute: int) -> void     # Ende einer Stelle → Wirkung, apprentice_job_done; Npc-Laufzeitplan
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
# ApprenticeBox extends Chest: saveable apprentice_box / 79, 6 Plätze + var coins: int; Panel &"chest" mit Münzfach
# ApprenticeBoard: „[E] Arbeitsliste für Jakob" → Panel &"apprentice_board"; vor hire: „Eine leere Kreidetafel."
# CleanlinessManager (P3): + func tend_by(spot_id: String, actor: StringName) -> bool   # ohne Inventar, gleiche Wirkung wie tend
```

**Freundschaft, Gefallen & Feste (P4)**
```gdscript
class_name FriendStepData extends Resource          # ✦ (Unterressource)
@export var step: int; @export var title: String; @export var min_value: int
@export var conditions: PackedStringArray = []      # Dialog-Syntax (insight_not_lorenz, robber_known, apprentice_level_gte:2 …)
@export var order_ids: Array[StringName] = []       # of_<npc>_<n>[_alt]; erste erfüllbare Variante
@export var start_node: StringName; @export var end_node: StringName
@export var reward_rel: int; @export var reward_rep: int = 0; @export var reward_flag: StringName = &""
@export var gap_days: int = 1; @export var fallback_event: StringName = &""   # Ersatztermin
class_name FriendStoryData extends Resource         # ✦ data/friendship/stories/<npc_id>.tres
@export var npc_id: StringName; @export var steps: Array[FriendStepData] = []; @export var favor_id: StringName
class_name FavorData extends Resource               # ✦ data/friendship/favors/<id>.tres
@export var id: StringName; @export var npc_id: StringName; @export var label: String
@export var effect: StringName                      # rumor_shield | free_iron | order_ware | prayer | night_watch | free_medicine | corpse_wash
@export var params: Dictionary = {}; @export var cooldown_days: int = 5
@export var return_orders: Array[StringName] = []; @export var return_after_days: int = 1; @export var return_days: int = 3
@export var returned_rel: int = 4; @export var unreturned_rel: int = -6; @export var lock_days: int = 7
class_name Friendship extends Node                  # Gruppe friendship, saveable friendship / 74
func step_done(npc_id: StringName) -> int           # 0…3
func offerable_step(npc_id: StringName) -> int      # 0 = keiner (Schwelle, Laune gereizt, Abstand)
func accept_step(npc_id: StringName) -> bool        # nimmt den Auftrag of_* an
func note_order_done(order_id: StringName) -> void  # Orders → Schritt fertig → friend_step_completed, Lohn
func steps_total() -> int; func full_stories() -> int
func favor_block_reason(npc_id: StringName) -> String
func use_favor(npc_id: StringName, choice: StringName = &"") -> bool
func favor_shield_active() -> bool; func consume_shield(event: StringName) -> bool   # Rosine
func night_watch_tonight() -> bool                  # Fenner
func apply_morning(day: int) -> void                # Gegengefallen anbieten / verfallen lassen
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
# OrderData ✦ + @export var category: StringName = &""   # &"" = Phase 7 | &"friend"
#   kind + &"meet" (conditions {npc, place, window, times}) und &"task" (conditions {action_id, place})
# OrdersConfig ✦ + @export var max_active_friend: int = 2
# Orders (P4): category friend zählt getrennt; func note_meet(npc_id, place_id) -> void; func note_task(action_id: StringName) -> void
class_name FestivalData extends Resource            # ✦ data/festivals/<id>.tres
@export var id: StringName; @export var calendar_day: int                       # 54 / 58 (Spieltag)
@export var shift_rule: StringName = &"none"         # &"none" | &"open_plus" (Lichtgang: p8_open_day + shift_days)
@export var shift_days: int = 3; @export var day_flag: StringName              # fest_kathrein_day / fest_lights_day
@export var window: Vector2i; @export var region: StringName; @export var music_context: StringName
@export var effects: Dictionary = {}                 # §2.7: presence_rel, dance_rel, lights_all {...}
class_name Festivals extends Node                    # Gruppe festivals, saveable festivals / 75
func fest_day(fest_id: StringName) -> int            # wirksamer Tag (nach Verschiebung) oder −1
func today() -> StringName; func running() -> StringName
func apply_morning(day: int) -> void                 # day_flag setzen, Ankündigung, Osrics Kerzen (Lichtgang)
func apply_minute(day: int, minute: int) -> void     # Fenster, 18:00 Auswertung, Ende
func dance_block_reason(npc_id: StringName) -> String; func dance(npc_id: StringName) -> bool
func lights_count() -> Vector2i                      # (brennend, belegt) für die Zielzeile
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
# ArchiveCabinet (P4): Kirche, „[E] Im Archiv helfen (60 Min)" mit Lenz-Schritt 2 oder Gemeindeschlüssel → Orders.note_task(&"archive_help")
#   → Item lorenz_ledger_2; ohne beides: „Das Archiv ist verschlossen."
# MemorialPlate (P4): sichtbar ab friend_innkeeper_2; Fiddler (P4): sitzend, Bogenarm-Wiegen nur im Fest-Fenster
```

**Nacht & Wanderer (P7)**
```gdscript
class_name WandererData extends Resource            # ✦ data/village/wanderers/<id>.tres
@export var id: StringName; @export var display_name: String; @export var dialogue_id: StringName
@export var shop_id: StringName = &""; @export var every_days: int = 0; @export var day_rest: int = 0   # Hanne 6 / 1
@export var alms_coins: int = 0; @export var alms_piety: StringName = &""; @export var alms_for_clue: int = 0   # Veit 1 / alms / 3
@export var clue_id: StringName = &""
class_name Wanderers extends Node                    # Gruppe wanderers, saveable wanderers / 76
func present(id: StringName) -> bool; func peddler_day(day: int) -> bool
func alms_block_reason(inv: Inventory) -> String; func give_alms(inv: Inventory) -> bool   # Pietät, Zähler, ggf. c_n_veit
func alms_count() -> int
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
class_name RobberConfig extends Resource            # ✦ data/config/robber_config.tres
@export var start_offset_days: int = 4; @export var fresh_days: int = 5; @export var chance: float = 0.35
@export var min_gap_nights: int = 2; @export var first_guaranteed: bool = true
@export var arrive_minute: int = 90; @export var dig_from: int = 110; @export var dig_until: int = 300
@export var notice_distance: float = 10.0; @export var watch_catch_after: int = 3
@export var report_rep: StringName = &"robber_reported"; @export var let_go_piety: StringName = &"robber_let_go"
class_name NightRobber extends Node                  # Gruppe night_robber, saveable night_robber / 77
func tonight_target(day: int) -> String              # Grab-Id oder "" (deterministisch, gespeichert ab 00:00)
func apply_minute(day: int, minute: int) -> void     # Auftritt, Graben, Bemerken, 05:00 aufgewühlt
func encounters() -> int; func fate() -> StringName  # &"" | &"reported" | &"let_go" | &"caught_watch"
func resolve(choice: StringName) -> void             # Dialog robber (2. Begegnung)
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
class_name NightVisitData extends Resource          # ✦ Unterressource
@export var npc_id: StringName; @export var night_offset: int; @export var enter_minute: int; @export var leave_minute: int
@export var clue_id: StringName; @export var animation: StringName = &"walk"
class_name NightPathData extends Resource           # ✦ data/night/paths/<id>.tres
@export var id: StringName; @export var house: StringName; @export var patient: String
@export var start_offset: int; @export var end_offset: int; @export var visits: Array[NightVisitData] = []
@export var death_offset: int = -1; @export var death_minute: int = 130; @export var death_flag: StringName = &""
@export var watch_spot: StringName
class_name NightPaths extends Node                   # Gruppe night_paths, saveable night_paths / 78
func sick_houses(day: int, minute: int) -> PackedStringArray   # für SickLight, Karte (ab c_n_veit), Launen
func next_visit(path_id: StringName, day: int, minute: int) -> Dictionary
func wait_minutes(spot_id: StringName) -> int        # WatchSpot: bis 10 Min vor dem nächsten Besuch, ≤ 120
func apply_minute(day: int, minute: int) -> void     # Tod (Flag), Beobachtung beim Hinausgehen (≤ 12 m, Region village)
func observed(clue_id: StringName) -> bool
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
```

**Dialog, Geschichte & Speichern (P6)**
```gdscript
# DialogueConditions (P6) +: mood:<npc>:<mood> · step_gte:<npc>:<n> · step_offerable:<npc> · favor_ready:<npc> · favor_owed:<npc>
#   · apprentice_hired · apprentice_level_gte:<task>:<n> · apprentice_mistake_today · wish_offerable · visit_waiting
#   · fest_today:<id> · fest_running:<id> · alms_gte:<n> · robber_known · robber_fate:<f> · sick_light:<house> · observed:<clue>
#   · p8_open · insight:<id> (bestehend) · underlined:<npc>
# DialogueActions (P6) +: listen:<npc> · step_accept:<npc> · favor_use:<npc>[:<choice>] · apprentice_hire · apprentice_teach:<task>
#   · apprentice_praise · apprentice_scold · wish_offer · wish_accept · tip_hand · alms · dance:<npc> · robber_resolve:<choice>
#   · give_item:<id>:<n> (bestehend) · meet:<place> (Orders.note_meet)
# InsightData ✦ + @export var any_clues: Array[StringName] = []; @export var any_count: int = 0
#   JournalManager (P6): Erkenntnis verknüpfbar, wenn alle clues und ≥ any_count aus any_clues gefunden sind (Panel zeigt beide Gruppen)
# StoryConfig ✦ + @export var underlined: StringName = &"washer"   # priest | surgeon | washer (§14.1); wählt die Textvariante
# StoryDirector (P6): D2 über bestehende due_flag-Regel (ott_dead), Reservierung im Abschnitt linden (Reihe 3)
# SaveMigration (P6): CURRENT := 7; + static func migrate_6_to_7(state: Dictionary, meta: Dictionary) -> Dictionary
#   V7_EMPTY_NODES := ["npc_life", "visitors", "grave_care", "apprentice", "friendship", "festivals", "wanderers", "night_robber", "night_paths", "apprentice_box"]
# SaveFileIO.FORMAT_VERSION = 7; read_doc akzeptiert 1…7
# GameState.DEFAULT_STATS + die 26 Stats aus §2.11; COIN_REASONS + &"apprentice", &"alms", &"peddler"
# ActionConfig ✦ + @export var noisy_actions: Array[StringName] = [&"dig", &"chop", &"pick", &"hammer", &"chisel", &"saw", &"quarry"]
```

### 3.5 Database (Lead)
Neue Listen (wie Phase 7 W0-Notiz 9): `chatter(s)` (`data/npc_life/chatter`, nach id), `kin` (`data/visitors/kin`, Schlüssel `kin_id`), `wish(es)` (`data/visitors/wishes`, nach id), `apprentice_task(s)` (`data/apprentice/tasks`, Reihenfolge rake, weed, water, candle über `order`), `friend_story(ies)` (`data/friendship/stories`, Schlüssel `npc_id`), `favor(s)`, `festival(s)` (nach `calendar_day`), `wanderer(s)`, `night_path(s)` (nach `start_offset`). Leere/fehlende Ordner = leere Listen.

### 3.6 Eingaben
Keine neuen Tasten. Alles läuft über [E], Dialoge und Panels. Die Kreidetafel, die Lohndose und die Gefallen sind normale Interaktionen.

---

## 4. Welt, Orte & Sichtprüfungen (W-Welt)

### 4.1 Grundsatz
Phase 8 baut **keine neue Region und keinen neuen Raum**. Friedhof, Dorf und die Innenräume bekommen Marker, Plätze, Wege und wenige Requisiten; einzig der Lindenacker wächst um eine Reihe (§4.4, Bestätigung §14.2). Die Kamera-Regel aus Phase 6/7 gilt weiter: Was südlich steht, verdeckt; deshalb liegen die neuen Plätze an den Gräbern **am Fußende zur Kamera**, und keine neue Requisite ist höher als 1,4 m.

### 4.2 Besucherplätze und Besucherrouten (Friedhof)
- **Besucherplatz** `gv_<plot_id>` für **jede** Grabstelle und jedes Altgrab (`plot_01…12`, `h_01…06`, `l_01…12`, `old_01…08`): 0,9 m vor dem Fußende des Hügels, Blick zum Stein, beim Welt-Bau aus der Lage des Plots berechnet und ins Layout geschrieben (`visitor_spots`). Kniende Figur: Kopf 0,95 m, stehende 1,6 m.
- **Route** `visitor_routes[plot_id]`: Wegpunkt-Polylinie `road_end → road_mid → gate_outside → gate_inside → …` über die bestehenden Hofwege und Durchgänge (Ostwiese `w_east_pass`, Birkenhang-Durchgang, Pförtchen Holunderwinkel, Lindenacker-Pforte `w_linden_n`) bis `gv_<plot_id>`. W-Welt backt sie (Flood-Fill-Pfad, geglättet auf Wegpunkte) und legt fehlende Zwischenpunkte `vw_*` an. Rückweg = umgekehrt.
- **Lichtgang-Plätze:** `lights_lenz` (Kirchhof, 1,5 m vor der Kapellentür, Blick nach Süden), `lights_crowd_1…8` (Halbkreis auf dem Kirchhof-Vorplatz, je ≥ 0,9 m Abstand), `lights_gate` (Veit, außen am Tor).

### 4.3 Lehrlingsecke an der Hütte und Plätze am Tor
| # | Element | Lage | Hinweise |
|---|---|---|---|
| A1 | Kreidetafel `apprentice_board` (`ph_prop_chalkboard`) | an der Hüttenwand rechts neben der Tür, ≤ 2 m von ihr, auf der Kameraseite | Marker `use`; Bau-Maske gesperrt (Footprint + 0,4 m) |
| A2 | Jakobs Kiste `apprentice_box` (`ph_prop_apprentice_box`, Kiste mit Blechdose für den Lohn) | neben der Tafel | `extends Chest`, Kollision |
| A3 | Bank für die Brotzeit (`ph_prop_apprentice_bench`, schmale Bank unter der Traufe) | an der Hüttenwand neben der Kiste | Sitzplatz `apprentice_lunch` |
| A4 | Regenfass `rain_barrel` (`ph_prop_rain_barrel`) | an der Hüttenecke unter der Dachrinne, nicht im Zugang der Werkbank | Marker `use` |
| G1 | Veits Platz am Tor `veit_gate` | außen am westlichen Torpfeiler (−0,4 \| 9,6), 0,8 m südlich, außerhalb des Torwegs | Sitzplatz, Blick nach Osten |
| G2 | Hannes Platz am Tor `peddler_gate` | außen am östlichen Torpfeiler (2,6 \| 9,6), 1,0 m südlich | Kiepe abgestellt (Kindmesh), Laden-Marker `counter` |
- Die Wege Hüttentür ↔ Werkbank, ↔ Gruft, ↔ Tor und der Gang zum Pförtchen bleiben ≥ 1,5 m frei (Flood-Fill wie Phase 5/6).

### 4.4 Die dritte Reihe im Lindenacker (Bestätigung §14.2)
```
 z  9,6 ════ Ostwiese-Südzaun ════[LINDENACKER-PFORTE]══════════════
 z 12,8 │  l_01   l_02   l_03   l_04        (Phase 7, unverändert)   │
 z 16,9 │  l_05   l_06   l_07   l_08                                 │
 z 21,0 │  l_09   l_10   l_11   l_12        NEU (x 13,6 · 15,9 · 18,2 · 20,5)
 z 22,8 └══ Südzaun (verschoben von z 19,6) ══════════════════════════┘
   x 11,5                                                        x 21,5   · Wegstein (8,4|24,4) unverändert westlich
```
| # | Element | vorher | nachher | Grund |
|---|---|---|---|---|
| L10 | Plots `l_09…l_12` | – | Reihe 3 bei z 21,0 im Raster der Reihen 1–2 (Abstand 4,1 m), W-Welt ±0,4 m | §2.8 |
| L11 | Südzaun Lindenacker | [[11,5, 19,6], [21,5, 19,6]] | [[11,5, 22,8], [21,5, 22,8]], West- und Ostzaun bis z 22,8 verlängert, `extra_walls` auf denselben Linien | Platz für Reihe 3 + Südstreifen 0,8 m |
| L12 | Waldbaum `forest.trees[7]` | Phase-7-Lage (16,5 \| 22,0, ggf. nach L6 versetzt) | **(16,5 \| 27,5)**, außerhalb der Laufgrenze | stand in Reihe 3 |
| L13 | Hindernisse | – | `obs_l_stump_9` (Baumstumpf bei `l_10`), `obs_l_bramble_9` (Brombeere bei `l_12`) | §2.8 |
| L14 | Bau-Maske, Gras, Boden | Lindenacker bis z 19,6 | Rechteck bis z 22,8, neu gebacken; Boden unter Reihe 3 geglättet, `ph_env_ground_graveyard` neu exportiert (Größe unverändert) | – |
| L15 | Kameragrenze | `camera_bounds.max.z` 23 | **24**, nur wenn Reihe 3 bei Zoom 12 sonst den Kopf am Südrand abschneidet (Prüfung §4.8) | bedingt |
- `walkable_bounds` bleiben (max z 25,2). Die Route Bahre ↔ Wegstein und der Kutschweg bleiben unberührt.

### 4.5 Wege der Nacht (Friedhof)
- **Räuberweg:** `robber_far` (27,5 \| 28,0, Wald südöstlich hinter dem Lindenacker, außerhalb der Laufgrenze) → `robber_fence_out` (17,0 \| 23,6) → über den Südzaun des Lindenackers (sichtbar: steigt hinüber, Clip `climb`, 2 s) → `robber_fence_in` (17,0 \| 22,0) → über den Südstreifen bzw. die Lindenacker-Pforte und die Besucherrouten bis `gv_<ziel>`. Flucht umgekehrt im Laufschritt. *Begründung:* Die frischen Gräber liegen in der dritten Reihe gleich hinter dem Zaun, und der Weg bleibt weit weg von Ilses Platz an der Westmauer (−12,1 \| −2,6), wo sie bis 03:20 steht.
- Der Räuber gräbt am Besucherplatz `gv_<plot>` mit Blick zum Grab; der Aushub (`ph_prop_grave_disturbed`) liegt am Fußende.

### 4.6 Dorf und Innenräume
| # | Element | Lage | Hinweise |
|---|---|---|---|
| D1 | Türplätze der Krankenlicht-Häuser `v_ott_door`, `v_kehr_door` | am Rand der Laufgrenze vor `house_ott` (26,5 \| 3) bzw. `house_kehr` (−25,5 \| −12): (23,4 \| 3,0) und (−24,6 \| −10,2) | Besucher gehen hin, „klopfen" (`knock`, 1 s) und gehen hinein (Zeitplan-Sprung hinter die Laufgrenze, wie Phase-7-Hausbesuche) |
| D2 | Beobachtungsplätze `watch_ott`, `watch_kehr` (`WatchSpot`) | im Schatten unter der Remisen-Traufe (19,5 \| 5,4) bzw. an der Westecke des Amtshauses (−20,0 \| −9,6) | ≤ 12 m bis zum Türplatz, frei sichtbar (§4.8); Prompt nur in Krankenlicht-Nächten |
| D3 | Krankenlicht `SickLight` | Marker `light_window` von `house_ott`/`house_kehr` | das vorhandene Fensterlicht bleibt die ganze Nacht an, dazu eine Kerze als leuchtendes Material im Fenster (kein neues Licht) |
| D4 | Veits Plätze | Kirchtür-Stufe `v_church_step` (1,6 \| −10,8), Brückenplatz `v_bridge_sit` (−23,8 \| 2,6), Brunnenbank (bestehend `v_well_bench`) | sitzend |
| D5 | Hannes Stand `v_well_peddler` | (−1,8 \| −1,2) am Brunnen, Kiepe abgestellt | Laden-Marker `counter` |
| D6 | Gaststube (`inn_layout.json`) | Kathrein-Schmuck (Tannengrün, Bänder an zwei Balken, Tische an der Wand: zweite Möbelstellung mit `fest_flag`), Spielmann-Platz am Ofen, Tanzfläche 3 × 2,5 m | `FestDecor`, `min/max_level` → `fest_flag` (✦ Layout-Feld, nur Darstellung) |
| D7 | Kirche (`church_layout.json`) | Archivschrank `ArchiveCabinet` an der Nordwand neben der Sakristeitür (`ph_int_church_archive`), Namenstafel `MemorialPlate` am bestehenden Gedenkbrett | Raum hell wie G7 |
- Dorf-Wegpunkte für Jakob (`v_in_inn_jakob`), Veit (`v_remise_sleep`, unsichtbar), Hanne (`v_peddler_in` an der Brücke, `v_peddler_out` = Brückenportal) und die Lichtgang-Sammlung (`v_lights_gather`, Holderbrücke).

### 4.7 Eingriffe am Friedhof und im Dorf (vollständig; Layout-Diff-Test gegen `tests/fixtures/phase8/layout_p7.json` und `village_layout_p7.json`)
Friedhof: **L10–L15** (§4.4), **A1–A4**, **G1–G2** (§4.3), Besucherplätze und -routen (§4.2, nur neue Einträge `visitor_spots`, `visitor_routes`, `vw_*`), Räuberweg (§4.5, neue Wegpunkte), Lichtgang-Plätze, neue Npc-Einträge (§3.1). Dorf: **D1–D5** (neue Marker und Wegpunkte), Räume: **D6–D7**. **Nicht bewegt:** alles andere, insbesondere Hütte, Tor, Bahre, Gruft, Kapelle, Schuppen, Werkhof, alle Gräber der Phasen 2–7, Pflegestellen, Ilses Platz, die Dorfhäuser und alle Phase-7-Wegpunkte.

### 4.8 Sichtprüfung und Wege (Kamerastrahl-Test, Pflicht; Verfahren Phase 6 §4.5)
1. **Besucher:** an **jedem** Besucherplatz Kopf kniend (0,95 m) und stehend (1,6 m) frei bei Zoom 12, 22, 24 (Spielerkamera mit Fokus auf dem Platz). Scheitert ein Platz (z. B. unter der Eichenkrone), verschiebt W-Welt ihn seitlich neben den Hügel (±0,7 m) und meldet es.
2. **Lehrling:** an jeder Pflegestelle und jedem Grab, an dem er gießt oder Kerzen setzt, sein Kopf (1,4 m) frei bei Zoom 22; Tafel, Kiste, Bank und Regenfass bei Zoom 22 im Bild.
3. **Nacht:** Zielplätze des Räubers (alle Gräber der Reihen 2–3 im Lindenacker und der jüngsten 6 Gräber) bei Zoom 22 frei; der Südzaun an `robber_fence_*` im Bild.
4. **Dorf:** Beobachtungsplätze → Türplätze frei (Strahl in Kopfhöhe); Türplätze aus der Spielkamera am Beobachtungsplatz im Bild; Veit und Hanne an allen Plätzen frei.
5. **Lichtgang:** Übersicht Zoom 24 über Alter Hof + Kirchhof, mindestens 70 % der Grabkerzen frei sichtbar; Lenz an `lights_lenz` frei.
6. **Wege** (Flood-Fill 1,5 m): jede Besucherroute frei (Strahl in Hüfthöhe, Toleranz 0,3 m), Hüttentür ↔ Tafel ↔ Regenfass, Reihe 3 ↔ Pforte; kein Platz in einer Kollision. Bilder `p8_vis_*` (§11).

### 4.9 Licht
- **Grabkerzen:** Glas mit Flamme als leuchtendes Material (`mat_emissive_warm`, Flackern über `flame_glow.gdshader` aus G7, kein `TIME`-Overhead pro Kerze: ein gemeinsamer Parameter). Dazu ein **Pool von 6 Omni-Lichtern** (`#F2A93B`, Energie 0,5, Reichweite 2,2 m, **ohne Schatten**), die `GraveCare` den 6 brennenden Kerzen nächst dem Kamerafokus zuteilt (2 Hz). Alle übrigen Kerzen leuchten nur über das Material. Gilt auch am Lichtgang.
- **Laternen im Lichtgang-Zug:** nur leuchtendes Material (Regel Phase 7: keine Lichter an Figuren). Jakobs Laterne ebenso. Lambert: ein leuchtender Spalt in der Blendlaterne.
- **Krankenlicht:** vorhandenes Fensterlicht bleibt an (kein neues Licht).
- **Gaststube am Kathreintanz:** Licht wie Phase 7 Abend; der Ofen flackert wie gehabt. Räume bleiben auf den hellen G7-Werten (Forward+ und Web-Gamma).

---

## 5. Speichern & Migration (P6)

### 5.1 Format v7 (Ergänzungen)
```
format_version: 7
data.autoloads.GameState.stats   + visits_seen, visits_total, wishes_done, wishes_failed, tips_coins, flowers_planted, candles_lit,
                                   mortsafes_set, graves_disturbed, graves_closed, apprentice_days, apprentice_jobs, apprentice_mistakes,
                                   apprentice_wage, friend_steps, favors_used, favors_returned, alms_given, chatters_seen, listens, dances,
                                   night_visits_observed, robber_encounters, coins_spent_apprentice, coins_spent_alms, coins_spent_peddler
data.autoloads.GameState.flags   + p8_open, p8_open_day: 53, linden_row3_granted, apprentice_hired, robber_known, ott_dead,
                                   fest_kathrein_day: 54, fest_lights_day: 58, lights_held, lights_all, visit_<npc>_day, friend_<npc>_<n>,
                                   promise_liesel_book, insight_underlined, who_comes_up_complete, clue_c_n_* (bestehendes Muster)
data.nodes.corpse_manager.records[] + kin_house: "house_kehr"
data.nodes.graveyard.graves[]    + disturbed: false, extra_lines: ["Ruhe sanft"]; + l_09…l_12 (aus dem Layout, LOCKED bis geräumt)
data.nodes.npc_life              {"open_day": 53, "events": {"apprentice_hired": 54, …}, "event_npcs": {…}, "listened": {"washer": 56},
                                  "chatter_day": {"ch_inn_carter": 55}, "goal_done": false}
data.nodes.visitors              {"plan_day": 57, "plan": [{"visit_id": "v_57_1", "kin_id": "kin_kehr", "graves": ["l_02"], "slot": 570}],
                                  "goodwill": {"kin_kehr": 7}, "last_visit": {"l_02": 55}, "wishes": [{"wish_id": "w_0003", "kind": "flowers",
                                  "grave_id": "l_02", "kin_id": "kin_kehr", "state": "accepted", "day": 55, "candle_seen": false}],
                                  "tips_today": {"day": 57, "coins": 2}, "tips_on_stone": {"l_02": [2, "kin_kehr"]}, "pleased_today": 1,
                                  "noise_day": 0, "rumor_seen": ["corpse_0031"], "next_wish": 4}
data.nodes.grave_care            {"flowers": {"l_02": {"planted": 79200, "watered": 81600, "wreath": false}}, "bouquets": {"l_02": 80100},
                                  "candles": {"l_05": 82500}, "lit_nights": {"l_05": 57}, "mortsafes": {"l_10": 81000}, "disturbed": [],
                                  "can_fill": {"player": 4, "apprentice": 6}, "light_pool": []}
data.nodes.apprentice            {"hired": true, "hire_day": 53, "levels": {"rake": 2, "weed": 1}, "jobs": {"rake": 13}, "teach": "",
                                  "board": [{"task": "rake", "area": "yard"}, …], "plan_day": 57, "plan": […], "progress": 3,
                                  "morale": 4, "unpaid": 0, "praised_day": 56, "scolded_day": 0, "mistakes_today": 1}
data.nodes.apprentice_box        {"storage": Inventory.save_state(), "coins": 9}
data.nodes.friendship            {"steps": {"innkeeper": 2, …}, "step_day": {…}, "favor_day": {"smith": 58}, "owed": {"smith": "of_esch_return_1"},
                                  "locked_until": {}, "shield": 0, "watch_night": 0}
data.nodes.festivals             {"days": {"fest_kathrein": 54, "fest_lights": 58}, "state": {"fest_kathrein": "ended"}, "presence": {…},
                                  "danced": ["grocer"], "lights_result": "all"}
data.nodes.wanderers             {"alms": 3, "alms_day": 56, "talks": {"peddler": 2}, "peddler_stock": {"day": 55, "left": {…}, "bought": {…}}}
data.nodes.night_robber          {"target_day": 58, "target": "l_09", "encounters": 1, "disturbed": 0, "last_night": 58, "fate": ""}
data.nodes.night_paths           {"observed": ["c_n_quast_visit"], "deaths": {"np_ott": 58}}
```
Nicht gespeichert: Laufzeit-Zeitpläne (aus Plan + Uhr), Launen (aus Tag + Ereignissen), Begegnungen, die gerade laufen, Licht-Pool, LOD-Stufen. Speichern ist während einer TimedAction gesperrt (wie bisher), sonst überall erlaubt, auch während eines Besuchs oder am Lichtgang: Nach dem Laden stehen alle Figuren dort, wo Plan und Uhr sie hinsetzen (bitgleich).

### 5.2 Migration v6 → v7 (Phase-7-Spielstände müssen laden)
`SaveMigration.migrate_6_to_7` läuft in `read_doc` nach `decode_state` (Kette 1→…→7), rein, auf einer tiefen Kopie.
1. **Leichen:** alle Records + `kin_house`. Für Records mit Grab im Abschnitt `linden` und Ankunft ab `village_open_day` berechnet die Migration ihn über die reine statische Funktion `Village.mourning_house_for(arrival_day: int, seed: int, houses: PackedStringArray) -> StringName` (aus `Village.mourning_house` herausgezogen, Ergebnis bitgleich zum Phase-7-Trauerflor; P6); sonst "".
2. **Gräber:** + `disturbed false`, `extra_lines []`. Die Plots `l_09…l_12` fehlen im v6-Stand und entstehen beim Laden aus dem Layout als `LOCKED` (tolerante Graveyard-Regel aus Phase 4).
3. `nodes.npc_life = {}`, `visitors`, `grave_care`, `apprentice`, `apprentice_box`, `friendship`, `festivals`, `wanderers`, `night_robber`, `night_paths` = `{}` über `SaveMigration.V7_EMPTY_NODES`, eingefügt erst, wenn W-Welt die Knoten anlegt (wie Phase 4–7).
4. Stats (§2.11) = 0. Flags: keine. `p8_open` setzt `NpcLife.post_load` zur Laufzeit, wenn `name_in_village_complete` gilt.
5. Spieler, Inventare, Präparate, Aufträge der Phase 7: unverändert. Phase-7-Aufträge behalten `category ""`.
6. Die Bau-Maske wächst um Reihe 3; im v6-Stand liegt dort keine Zier (vorher Zaun und Wald), es muss nichts geräumt werden.

**Fixtures (W0, Lead, vor jeder Phase-8-Code-Änderung mit dem Stand G7 + Gruft-Umbau erzeugt, über `Phase7Bot` + echte Systeme):** `tests/fixtures/saves_v6/`
- `slot_p7_day53_neighbor.json`: `neighbor7`-Endstand, 07:00 Tag 53, `name_in_village_complete`, Lindenacker voll, alle acht „Vertraut", Münzen gemessen (≈ 60). Start für `kindly8`, `lazy8`, `night8`, `save_load8`.
- `slot_p7_day53_anatomist.json`: `anatomist7`-Endstand (≈ 71, Präparate verkauft – auch von Lindenacker-Toten mit Angehörigen). Start für `anatomist8`.
- `slot_p7_day50_eve.json`: `neighbor7` am Abend des Kapiteltags (Öffnung am nächsten Morgen).
- `slot_p7_founder.json`: `founder7`-Endstand (neues Spiel). Start für `founder8`.
- `slot_p7_mid_inn.json`: mitten in Phase 7, Spieler in der Gaststube, Kapitel offen (Phase 8 bleibt zu, Begegnungen laufen).
- `slot_p7_crypt_corpse.json`: Leiche auf dem Gruft-Tisch (Stand mit Gruft-Umbau), Spieler in der Gruft – Liesels „Totenwäsche" und Totenwache nach der Migration möglich.
Dazu `make_v6_saves.gd` + `_driver.gd` (historisches Werkzeug) und `tests/fixtures/phase8/{layout_p7,village_layout_p7}.json` (bytegleich zum Stand). Lade-Wächter `tests/integration/test_saves_v6_load.gd` (Lead). v5…v1-Fixtures laden weiter (Kette bis 7).

---

## 6. Debug-Konsole (W-UI) – neue Befehle
`p8 open` · `moods` (heute) · `mood <npc> <plain|cheerful|low|cross>` · `chatter <id>` (jetzt abspielen) · `react <event>` · `visits` (Plan heute) · `visit <kin|npc> [grave]` (jetzt, mit echtem Weg) · `goodwill <kin> <n>` · `wish <grave> <kind>` · `wishes` · `tip <grave> <n>` · `flowers <grave> [fresh|wilted|wreath]` · `candle <grave|all>` · `mortsafe <grave>` · `disturb <grave>` · `apprentice hire` · `apprentice level <task> <0-2>` · `apprentice plan` · `apprentice morale <0-5>` · `box coins <n>` · `step <npc> <0-3>` · `favor <npc>` (Abklingzeit zurücksetzen) · `fest <kathrein|lights> [today|now]` · `lights all` · `peddler` (Hanne heute) · `alms <n>` · `robber <tonight|now|second|gone>` · `nightpath <ott|kehr> [now]` · `observe <clue>` · `underlined <priest|surgeon|washer>` · `d2` (Ott morgen fällig) · `vis8` (Sichtprüfung §4.8 im laufenden Spiel) · `goal8`. Bestehend und weiter nutzbar: `npclod`, `tp`, `time`, `rel`.

---

## 7. UI (W-UI)

### 7.1 Kreidetafel – Arbeitsliste (`&"apprentice_board"`)
Kreidegrau auf Schiefer (eigene Formensprache, Pergament-Rahmen wie die übrigen Panels): oben „Jakob – Arbeitsliste", drei Zeilen mit Auswahl Aufgabe (nur Angelernte wählbar, Ungelernte grau mit „noch nicht gezeigt") und Bereich; rechts Jakobs Stufen als Kreidestriche je Aufgabe (|, ||) mit „noch 4 Stellen bis Geübt" als Fußzeile; unten Lohndose „9 Münzen (3 Tage)" mit Knopf „Münzen einlegen" und Zustand („bezahlt bis morgen" / „schuldet 6"). Darunter die geschätzte Arbeit: „≈ 12 Laubstellen, dann Unkraut im Lindenacker" (aus dem Planer). Knopf „Zeig mir, was du heute geschafft hast" öffnet die Liste der heutigen Stellen.

### 7.2 Wunsch-Karte (im Dialog mit Besuchern) und Grab-Tooltip
- **Wunsch-Karte:** Name des Besuchers, Grab („Hedwig Lamprecht, Lindenacker"), Bitte als Zitat, Art als Symbol (Blume, Kerze, Rechen, Meißel, Vase), Frist „bis zum nächsten Besuch (≈ in 3 Tagen)", Lohnzeile ohne Zahl („Die Kehrs werden es dir danken."), Knöpfe „Das mache ich." / „Ich kann es nicht versprechen." Höchstens drei offene: sonst gedimmt mit „Drei Wünsche sind schon offen."
- **Grab-Tooltip** (bestehend, erweitert): Blumen frisch/welk („gießen in ≈ 1 Tag"), Kerze brennt, Grabgitter seit n Tagen, aufgewühlt, Angehörige mit Wort („Die Kehrs: zufrieden"), offener Wunsch, Münzen auf dem Stein.

### 7.3 Gefallen
Dialogzeile „[Gefallen] …" mit Abklingzeit („in 3 Tagen wieder"); bei Wahl (Esch, Lenz, Fenner) ein kleines Auswahl-Panel `&"favor"` (Gegenstand, Grab oder Nacht). Offene Gegengefallen stehen unter „Aufträge" mit eigener Überschrift „Was du schuldest".

### 7.4 Merkbuch
- **„Hollerbrück"** (Phase 7) je Karte zusätzlich: heutige Laune als Wort („heute bedrückt"), **drei Geschichtspunkte** (gefüllt = erledigt, umrandet = jetzt möglich) mit dem Titel des nächsten Schritts, „Gefallen bereit" bzw. „in 2 Tagen". Neue Karten: Jakob (Stufen je Aufgabe, Zufriedenheit als Satz), Veit (Almosen gegeben n), Hanne („nächster Besuch in 4 Tagen").
- **Neue Seite „Angehörige":** je Haushalt und Bewohner mit Toten oben: Name, Haus, Gräber, Wohlwollen als Wort (5 Wörter: „verbittert", „enttäuscht", „ruhig", „zufrieden", „dankbar"), letzter und nächster Besuch („kommt in ≈ 2 Tagen"), offene Wünsche mit Häkchen-Zustand („Blumen ✓ · frisch bis morgen").
- **„Aufträge":** Kategorie „Freundschaft" getrennt von den Phase-7-Aufträgen.
- **Merkbuch-Erkenntnis** `i_underlined`: zeigt die Pflicht-Hinweise und „zwei von vier" als eigene Gruppe mit Zähler.

### 7.5 HUD
- **Begegnungs-Blasen** wie Gerede (`chatter_bubbles.gd`, eine Begegnung zugleich, Namen der Sprechenden klein darunter).
- **Fest-Banner** (`fest_banner.gd`) um 06:00 und 15:00 am Festtag, 4 s: „Heute Abend: Lichtgang" / „Kathreintanz im Holderkrug (ab 19:00)".
- **Zielzeilen** (`ObjectiveResolver`, nach den Ketten aus Phase 4–7): „Sprich mit Osric" · „Rosine will dich sprechen" · „Kreidetafel: Arbeitsliste für Jakob" · „Zeig Jakob, wie man harkt" · „Martha Kehr wartet am Grab" (solange ein Besucher wartet und der Spieler auf dem Friedhof ist) · „Wunsch: Blumen für Hedwig Lamprecht (≈ 2 Tage)" (dringendster) · „Lohndose leer – Jakob arbeitet morgen umsonst" · „Hanne Vogelsang ist am Tor (bis 16:20)" · „Heute Abend ist Lichtgang" → „Kein Grab ohne Licht: 31/34" · „Merkbuch: Wer geht nachts zu den Kranken?" · „Bei den Otts brennt Licht" (nach `c_n_veit`) · „Ein Grab ist aufgewühlt" · „Wer heraufkommt: 3/4" · danach „Die Gemeindetafel hat neue Bitten".
- **Prompts:** „[E] Mit Martha Kehr reden" · „[E] Zwei Münzen auf dem Stein (Martha Kehr)" · „[E] Grabblumen setzen (15 Min)" · „[E] Blumen gießen (5 Min)" / gedimmt „Die Gießkanne ist leer." · „[E] Gießkanne füllen" · „[E] Grabkerze anzünden (3 Min)" / vor 15:00 gedimmt „Erst am Nachmittag." · „[E] Grabgitter aufsetzen (20 Min)" · „[E] Grab wieder schließen (30 Min)" · „[E] Zeile nachmeißeln: ‚Ruhe sanft' (30 Min)" · „[E] Arbeitsliste für Jakob" · „[E] Jakobs Kiste" · „[E] Veit eine Münze geben" · „[E] Im Schatten warten (bis ≈ 22:20)" · „[E] Im Archiv helfen (60 Min)" · „[E] Namen für Theres abschreiben (20 Min)".

### 7.6 Tageszusammenfassung und Register
- **Tageszusammenfassung** + „Besuche" (wer, an welchem Grab, wie es aussah), „Wünsche" (erfüllt, neu, verfallen), „Trinkgeld", „Jakob" (Stellen je Aufgabe, Fehler mit Ort, Lohn, „Morgen: …"), „Die Nacht" (Grabräuber gesehen / verscheucht / Grab aufgewühlt, Krankenlicht).
- **Grabregister:** Spalte „Angehörige" (Haus) und Symbole für Blumen, Kerze, Gitter; der Vermerk „vorgemerkt: Fenner" an `l_12` (Fenner 2).

### 7.7 Abschluss-Panel
Variante `&"who_comes_up"` (§1.5).

### 7.8 Karte (Phase-7-`MapCanvas`, Marker-Ebene – kein Neubacken des Blatts außer für Reihe 3 und die neuen Requisiten)
| Marker | Wo | Wann |
|---|---|---|
| Besucher (kleine dunkle Figur, Name im Tooltip) | an ihrem Grab bzw. auf dem Weg | während des Besuchs |
| Jakob (Figur mit Rechen, Tooltip „harkt im Alten Hof") | aktuelle Stelle | Arbeitszeit |
| Wünsche (Blüte am Grab, Tooltip mit Frist) | Grab | offen |
| Münzen auf dem Stein | Grab | bis genommen |
| Hanne (Kiepe, Tooltip Zeiten) | Brunnen / Tor | ihr Tag; im Kalender-Tooltip „nächster Besuch" |
| Veit (Becher) | aktueller Platz | sichtbar |
| Krankenlicht (Fenster) | Haus | erst ab `c_n_veit` |
| Fest (Laterne / Fiedel) | Friedhof + Brücke / Holderkrug | am Festtag |
| Aufgewühltes Grab (offene Erde) | Grab | bis geschlossen |
| Grabräuber | **nie** (man muss nachts selbst hinsehen) | – |

---

## 8. Figuren, Animationen, Assets & Ton (P5, W-Ton; Stil gesperrt, alle `ph_`, `lib_painted.py` / `lib_faces.py` / geteilte Materialien)

### 8.1 Neue Figuren
| Asset | Wer | Rig | Dreiecke | Hinweise |
|---|---|---|---|---|
| `ph_chr_apprentice` | Jakob Wackernagel | gemeinsames Rig **mit `tool`** (9 Knochen, wie der Totengräber seit G7 Runde 2) | ≤ 8 000 | ≈ 1,45 m, 4,5 Kopfhöhen; Gesicht über `lib_faces._head()` (rund, große Augen, Sommersprossen als Vertex-Farbe, keine Falten); Kittel bis zum Knie (verdeckt die starren Beine beim Bücken); Werkzeug-Meshes am `tool`: Kinderrechen, Gießkanne, Besen, Laterne (Lichtgang) – Sichtbarkeit nach Clip wie `ToolProps` |
| `ph_chr_mourner_w_a`, `_w_b` | Martha Kehr, Gesa Ott | 8 Knochen | je ≤ 7 500 | ein Aufbau mit zwei Parametersätzen (Alter, Tuch, Rocklänge bodenlang – **Knien nur mit langem Rock**), Kindmesh `bouquet` (Heidekraut bzw. Strohblumen) an `arm_r`, `basket` an `arm_l` (Martha) |
| `ph_chr_mourner_m_a`, `_m_b` | Hinrich Brandt, Johann Sieber | 8 Knochen | je ≤ 7 500 | Kindmeshes `hat_head` / `hat_hand` (Hut auf dem Kopf bzw. in der Hand vor dem Bauch), Johann mit Stock (`arm_l`), Hinrich mit Tannengrün |
| `ph_chr_beggar` | Veit Ammer | 8 Knochen | ≤ 8 500 | steifes rechtes Bein (in der Ruhehaltung gestreckt), Stock, Blechbecher (Kindmesh), Fischerkappe; sitzt an Mauer und Stufe (`sit_beg`) |
| `ph_chr_peddler` | Hanne Vogelsang | 8 Knochen | ≤ 9 000 (Kiepe ≤ 1 800 davon) | Kiepe als Teil des Rückens (`spine`), Glöckchen als eigene kleine Teile, Wanderstab an `arm_l`; zum Verkaufen steht die Kiepe neben ihr (`ph_prop_peddler_kiepe`, Wechsel über `show_with`) |
| `ph_chr_robber` | Lambert Grell | 9 Knochen mit `tool` | ≤ 8 500 | Kapuze, Halstuch (Kindmesh, beim Stellen heruntergezogen: das Gesicht ist dann lesbar und „schön" im Sinne von G7 – müde, jung, nicht böse), Spaten am `tool`, Blendlaterne an `arm_l` (leuchtender Spalt, kein Licht), Sack über der Schulter |
| `ph_chr_fiddler` | Spielmann vom „Stumpf" | **ohne Rig**, sitzend | ≤ 2 500 | Kindmesh `bow` (Bogenarm), das Wiegen macht GDScript im Fest-Fenster |
- **Gesichter:** alle über den gemeinsamen Aufbau `lib_faces.py` (G7 Änderungsrunde 1, eingefroren: nur neue Parameter-Sätze). Nachweis wie G7: Aufstellung aller neuen Figuren neben den acht Dorfbewohnern und dem Totengräber, gleiche Kamera, Tag und Laternenlicht (`docs/reviews/phase8_assets/faces_lineup.jpg`).
- **Starre Arme ohne Ellbogen, Beine ohne Knie** (Rig-Grenze, bewusst): Jede Pose muss mit ganzen Arm- und Beinteilen lesbar sein. Knien = Hüfte tief, Beine über die Fuß-Regel in Rock oder Mantel geschoben, Oberkörper vor; Hände „gefaltet" = beide Arme schräg nach vorn-innen, die Hände treffen sich vor dem Bauch; nichts wird an die Brust oder ans Gesicht geführt.

### 8.2 Neue Animationen (Clips; `-loop` wird geschleift)
| Gruppe | Clips (Frames bei 30 fps) | Für |
|---|---|---|
| **Besuch & Trauer** (8 Knochen, Pose-Helfer in `rig.py`, additiv) | `idle_low-loop` 90 (Kopf −14°, Schultern vor) · `kneel_in` 24 · `kneel-loop` 90 (Atmen, Kopf gesenkt) · `kneel_out` 24 · `lay_flowers` 45 (Bücken 35°, `arm_r` vor 70°, Strauß bei Frame 30 abgelegt) · `mourn_stand-loop` 90 (Hut vor dem Bauch, Kopf gesenkt, Gewicht wechselt) · `knock` 20 · `lantern_walk-loop` 22 (`arm_l` 30° vor mit Laterne) | Angehörige; Theres, Liesel, Rosine (knien), Esch, Fenner, Lenz (stehen); alle acht Bewohner `idle_low`, `lantern_walk`; Lenz, Quast, Liesel `knock` |
| **Fest** (8 und 9 Knochen) | `dance-loop` 48 (Wiegen und Schritt auf der Stelle, Arme auf den Schultern des Gegenübers; das Drehen um die Paarmitte macht der Npc-Code langsam) · `clap-loop` 24 (Zuschauer) | Rosine, Esch, Theres, Fenner, Liesel, Hanne, Jakob, Totengräber |
| **Jakob** (9 Knochen) | `idle-loop`, `walk-loop`, `talk-loop` · `rake-loop` 40 (Rechen am `tool`, beide Arme vor, Ziehen zum Körper) · `weed-loop` 36 (Bücken 50°, Hüfte −0,2 m, `arm_r` zum Boden) · `water-loop` 40 (Kanne am `tool` 35° geneigt) · `candle` 45 (Bücken, `arm_r` tief vor) · `watch-loop` 72 (Arme leicht zurück, Kopf folgt) · `read_board` 40 · `sit_eat-loop` 72 · `sweep-loop` 36 (Besen) · `carry_can_walk-loop` 20 · `oops` 18 (Schreck nach einem Fehler) · `whistle-loop` 72 (Kopf schräg) | Lehrling |
| **Wanderer** (8 Knochen) | Veit: `sit_beg-loop` 90, `stand_up` 30, `walk_stiff-loop` 24 (steifes Bein) · Hanne: `offer-loop` 60 (wie Ilses `offer`), `kiepe_off` 30 / `kiepe_on` 30 | Veit, Hanne |
| **Nacht** (9 Knochen) | Lambert: `dig_night-loop` 39 (wie `dig` des Totengräbers, gebückter), `startle` 15, `run-loop` 14, `climb` 60, `sit_ground-loop` 72 (gestellt), `talk-loop` | Grabräuber |
| **Totengräber** (9 Knochen, nur additiv) | `kneel_place` 45 (Kerze/Blumen ans Grab) · `water-loop` 40 (Kanne am `tool`) · `sit_bench-loop` 90 (Bank unter der Linde, Totenwache) · `dance-loop` 48 | Spieler |
- Die acht Dorfbewohner werden mit den Zusatz-Clips **neu exportiert**; Geometrie, Gesichter, Materialien und die bestehenden Clips bleiben bitgleich (Test vergleicht Mesh-Hash und Clip-Liste). Osric tanzt nicht („Ich fahr nur."), Quast kniet nicht.
- Bilder je Clip als Kontaktbogen (Spielkamera + nah) in `docs/reviews/phase8_assets/anim_*.jpg`, wie die Bestatten-Bildfolge in G7 Runde 2.

### 8.3 Ton (W-Ton, `tools/audio/build_audio.py`, alles prozedural und eigenständig)
| Cue | Art | Auslöser | Hinweise |
|---|---|---|---|
| `rake_leaves` · `weed_pull` | sfx 3D | Harken / Jäten (Spieler und Jakob) | bestehende Pflege-Klänge wiederverwenden, wenn vorhanden; sonst neu |
| `water_pour` · `barrel_fill` | sfx 3D | Gießen · Regenfass | 2–3 Varianten, ±1,5 dB |
| `match_strike` + `candle_glass` | sfx 3D | Grabkerze anzünden | leise |
| `cloth_kneel` · `flowers_lay` | sfx 3D | Knien/Aufstehen · Strauß | sehr leise (−6 dB unter Schritten), kein Weinen, keine Stimme |
| `coins_stone` | sfx 3D | Münzen auf dem Stein ablegen/nehmen | |
| `chalk_write` | ui | Arbeitsliste | |
| `whistle_tune` | sfx 3D | Jakob bei guter Laune, höchstens alle 30 s | 3 eigene kurze Melodien (keine bekannten Lieder) |
| `tin_cup` | sfx 3D | Almosen | |
| `kiepe_bells` | Emitter-Schleife ≤ 12 m | Hanne unterwegs | stoppt beim Stehen |
| `spade_night` | sfx 3D ≤ 25 m | Grabräuber gräbt | gedämpfter als das eigene Graben |
| `run_gravel` · `climb_wall` | sfx 3D | Flucht, Mauer | |
| `knock_door` | sfx 3D | Nachtbesuch im Dorf | |
| `mortsafe_set` | sfx 3D | Grabgitter | Eisen auf Erde |
| `mus_dance` | Musik (Vorbis) | Kathreintanz, Kontext `fest` | eigene Fiedel-Melodie im Dreiertakt |
| `amb_inn_fest` | Atmosphäre (Vorbis) | Gaststube am Fest, ersetzt das Gaststuben-Bett | Stimmengewirr ohne Wörter, Stampfen im Takt |
| `mus_lights` | Musik (Vorbis) | Lichtgang 16:30–18:30 | langsame, gestrichene Töne, ruhig, kein Choral |
| Glocke | bestehend | Lichtgang 17:40 | Kapellenglocke bzw. Handglocke |
- Einzelklänge als WAV (Import QOA), Schleifen und Musik Vorbis; Lautheit nach `target_lufs` (G7 Runde 2); Klangliste `docs/reviews/phase8_round1/audio_list.md`, Hörprobe `audio_preview_p8.ogg`. **Budget:** keine neuen Stimmen-Pools, höchstens 3 neue Emitter gleichzeitig, eine Musik zugleich (der Kontext `fest` ersetzt die Dorf- bzw. Friedhofsmusik), keine Knoten-Neuerzeugung beim Abspielen.

- **(G8 Runde 1 angepasst)** `gate_bell` – das Glöckchen am Tor: Schnurknarzen, drei Schläge einer kleinen Bronzeglocke, im Freien (positional, ≈ 70 m, `assets/audio/sfx/ph_gate_bell.wav`).

### 8.4 Requisiten und Icons
- **(G8 Runde 1 angepasst)** `ph_prop_gate_bell`: schmiedeeiserner Arm mit Schnecke an der Innenseite des östlichen Torpfeilers, Bronzeglöckchen (Ø 20 cm) mit Zugschnur und Holzknebel; Kindmesh `bell` (Drehpunkt am Joch) schwingt; 1,78 m hoch (Pfeiler 1,85 m), ≤ 600 Dreiecke, keine Kollision.
| Asset | Zweck | Dreiecke | Hinweise |
|---|---|---|---|
| `ph_prop_grave_flowers`, `_grave_flowers_wilted` | Winterheide und Christrosen auf dem Hügel | je ≤ 500 | welk = dieselbe Form, braun-grau gemalt, Blüten hängend |
| `ph_prop_wax_wreath` | Wachskranz | ≤ 600 | blasse, zu glatte Blüten |
| `ph_prop_bouquet_heath`, `_fir`, `_straw`, `_rose` | Sträuße der Besucher (Kindmesh und abgelegt) | je ≤ 250 | |
| `ph_prop_grave_candle` | Grabkerze im Glas | ≤ 120 | MultiMesh-tauglich; Flamme `mat_emissive_warm` |
| `ph_prop_mortsafe` | eisernes Grabgitter | ≤ 1 200 | Höhe ≤ 1,1 m, Gitterstäbe als Flachbänder |
| `ph_prop_grave_disturbed` | aufgeworfene Erde am Fußende, Spatenspuren | ≤ 800 | `mat_ground`, kein Loch bis zur Leiche |
| `ph_prop_tip_coins` | zwei, drei Münzen und ein gefalteter Zettel auf dem Stein | ≤ 150 | |
| `ph_prop_chalkboard`, `_apprentice_box`, `_apprentice_bench`, `_rain_barrel` | Lehrlingsecke | ≤ 600 / 500 / 400 / 600 | Tafel mit Kreidestrichen (Textur ohne lesbaren Text außer „Jakob") |
| `ph_tool_rake_small`, `_watering_can`, `_broom`, `_lantern_hand`, `_spade_robber`, `_lantern_blind` | Werkzeug-Meshes am `tool` | je ≤ 300 | |
| `ph_prop_peddler_kiepe`, `ph_prop_tin_cup` | abgestellte Kiepe, Becher | ≤ 1 500 / 100 | |
| `ph_int_church_archive`, `ph_int_memorial_plate`, `ph_int_inn_fest_decor` | Archivschrank, Namenstafel, Tannengrün und Bänder | ≤ 1 200 / 200 / 800 | |
| `ph_item_flower_seedlings`, `_grave_candle`, `_watering_can`, `_apprentice_rake`, `_mortsafe`, `_wax_wreath`, `_register_extract`, `_memorial_plate`, `_quast_crate`, `_lorenz_ledger_2` | Item-Icons | ≤ 800 | Kladde: schmales, abgegriffenes Heft mit Faden, kein lesbarer Text |
- **Wiederverwenden:** Zaun, Baumstumpf, Brombeere (Reihe 3), Grabvase (Zier), Laternenpfahl, Trauergäste-Haltung, `ph_prop_grave_mound_fresh`, Phase-7-Gaststube.
- **Kein Gore, kein Grusel um seiner selbst willen:** Das aufgewühlte Grab zeigt nur Erde, nie den Toten. Trauer ist Haltung, kein Ausdruck. Kein Rot außer dem kleinen Band an Hannes Kiepe.

## 9. Performance-Budget (Phase 8; Messung mit `graveyard_shots_phase8.gd --cpu`, `village_shots.gd --phase8` und `perf_probe_run.gd` + Web `--perf-probe`)
| Größe | Budget | Begründung |
|---|---|---|
| FPS | 60 @ 1080p Mittelklasse-GPU; **Web (Compatibility)** ohne Frame > 50 ms beim Beginn eines Besuchs, des Lichtgangs und des Kathreintanzes | G7-Lehre Browser |
| Figuren mit Skelett, Friedhof | **≤ 9** im Alltag (Osric, Ilse nachts, Jakob, 2 Besucher, 1–2 Bewohner, Veit, Hanne, Lambert nachts); **≤ 16 am Lichtgang** | `NpcLod`: `max_full 6` bleibt; stehende Figuren ab 26 m Stufe 2; am Lichtgang Stufe-1-Rate 3 Hz |
| Figuren, Dorf / Gaststube am Fest | ≤ 12 / ≤ 10 + Spielmann | wie Phase 7 |
| Kamera-Dreiecke inkl. Gras (Spiel-Zoom) | < 500 k, auch Lichtgang Übersicht | 16 Figuren × ≤ 9 k ≈ 140 k – Prüfbild `perf_p8_03` |
| Draw Calls Friedhof | ≤ 650 Alltag, **≤ 750 Lichtgang** | Grabkerzen als **ein** MultiMesh (Glas + Flamme), Blumen je Grab ≤ 40 Meshes |
| Lichter | Schatten ≤ 4 (unverändert), sichtbar ≤ 25; **Kerzen-Pool 6 Omni ohne Schatten** | Compatibility-Renderer: ≤ 8 Lichter je Mesh; der Pool hält jedes Grab unter 3 Kerzenlichtern |
| Partikel | ≤ 60 (unverändert) | neu nur 3 Erdbröckchen beim Räuber, 4 Funken beim Anzünden |
| Skripte CPU/Frame (headless, Uhr läuft, Median über ≥ 3 Läufe, relativ in derselben Messung) | Friedhof Tag mit Jakob und 2 Besuchern: Phase-8-Anteil **≤ +0,2 ms** · Lichtgang **≤ +0,5 ms** · Dorf **≤ +0,1 ms** | Planer nur um 06:00 / 08:25 / bei Listenänderung (≤ 2 ms, notfalls auf 2 Frames verteilt wie die Karte in G7); `ChatterRunner` und Licht-Pool 2 Hz; Besucher, Lehrling, Feste, Nacht ereignis- bzw. minutengetrieben ohne `_process` |
| Audio | ≤ 26 Einmal-Stimmen, ≤ 3 neue Emitter, 1 Musik | Web: Mischen auf dem Hauptthread (G7) |
| Lichtgang-Zug | 12 Npc wechseln gleichzeitig die Region → ≤ 4 ms in einem Frame | `refresh()` je Npc ≤ 0,3 ms; der Zug startet gestaffelt (alle 20 Spielsekunden einer) |
| Spielstand / Laden | < 400 kB (+ ≈ 8 kB) / < 1 s | |
*Plan B (in dieser Reihenfolge, bevor Inhalte fallen):* `max_full` 4, Lichtgang Stufe-1-Rate 2 Hz, Kerzen-Pool 4, Lichtgang-Zug nur Angehörige + Lenz + 4 Bewohner.

## 10. Tests
Regeln wie Phase 3–7 (Fixtures statt fremder Moduldaten, Fehler-Logger, Watchdog). **Alle 2 472 bestehenden Tests bleiben grün** (plus die Tests des Gruft-Umbaus); Anpassungen nur durch den Besitzer (z. B. Item-Zählungen, Clip-Listen der Bewohner, Laufgrenzen/Layout-Diff im Welt-Test, Zahl der Gerede-Vorränge).

**Unit**
| Datei | Besitzer | Prüft |
|---|---|---|
| `test_moods.gd` / `test_reactions.gd` | P1 | Würfeln deterministisch (Tag, `npc_id`), Gewichte, Vorrangregeln 1–5, Wirkung erst ab `p8_open`, Gespräch +2/+1/0, „gereizt" bietet nichts an, Zuhören einmal je Tag (+3, Pietät +1), Ereignis-Gerede 2 Tage, Vorrang Ereignis > friend > piety > rep |
| `test_chatter.gd` | P1 | Auslösen nur bei beiden anwesend + Spieler ≤ 10 m in derselben Region, eine zugleich je Region, einmal je Tag, Bedingungen, `ch_rumor_robber` setzt `robber_known`, ab `village_open` (Phase-7-Stand) ohne Spielwert-Änderung |
| `test_schedule_builder.gd` / `test_npc_lod.gd` (+) | P1 | Wegzeit aus Polylinie (3,2 m/Min), Lücken unsichtbar, Laufzeit-Zeitplan ersetzt und kehrt zurück, Speichern/Laden ohne Plan-Daten bitgleich (Positionen aus Plan + Uhr), Kindmeshes `show_with`; LOD-Kappen (9 / 16 am Lichtgang), stehende Figuren Stufe 2 ab 26 m |
| `test_visitors.gd` / `test_wishes.gd` / `test_grave_view.gd` | P2 | Plan um 06:00 deterministisch (erster Besuch Tag + 1, Trauerzeit 3 Tage, danach 7, Haushalt geht alle Gräber ab, max 3 / 2 zugleich, keiner nachts/am Lichtgang/vor `p8_open`/an `DUG`), `kin_house` bei der Lieferung, Bewohner-Besuche mit `visit_<npc>_day` und verborgenen Dorf-Einträgen; Ansicht (Vorrang, Ruf, Wohlwollen, Tageskappe gepflegt 2, Präparat-Gerede einmal je Toter, zurückgelegte zählen nicht); Lärm ≤ 8 m einmal je Besuch/Tag; Wunsch-Wahl (Reihenfolge, Seed, einer je Grab, 3 offen, `line` nur bei Stein < 4 Zeilen, Wohlwollen ≥ 2), Erfüllung je Art, Trinkgeld 1–3 mit Kappe 4/Tag, Münzen auf dem Stein bleiben und sind einmal nehmbar, Bewohner +4 statt Geld, Verfall ohne Ruf; Save/Load |
| `test_grave_care.gd` / `test_ghosts.gd` (+) | P2 | Blumen frisch 2 Tage / welk bis 4 / fort, Gießen und Füllungen, Regenfass, Strauß 2 Tage ohne Stapeln, Wachskranz (Wunsch ja, Geist 0), Kerze 15:00–07:00, `lit_last_night`, Gitter ≥ 10 Tage, aufgewühlt + schließen; `care` ≤ 2, Lichtgang +2, Fürbitte gedeckelt, beraubt höchstens gleichmütig, neue Pools mit Vorrang, `early_window` nur Darstellung |
| `test_apprentice.gd` / `test_apprentice_planner.gd` / `test_apprentice_rules.gd` | P3 | Einstellen nur über Rosine 1, Arbeitstag 08:15–15:40, freie Tage (`day % 7 == 2`, Feste, 3 unbezahlt), Liste 3 Zeilen, nächste Stelle zuerst, überspringt trauernde Gräber und gesperrte Abschnitte, Kerzen erst ab 15:00, Regenfass-Gänge; Minuten je Stufe und Laune, Fehler deterministisch 8 %/2 % (×0,5 nach Tadel), Fehlerwirkungen (Nachbargrab, Blumen, Kerze); Vormachen nur ≤ 4 m und nur für Ungelernte, Geübt nach 12; Lohn 3 aus der Dose um 15:30, unbezahlt (Rosine −2, nach 3 daheim, Rückkehr nach Zahlung); Wirkung über `tend_by`/`GraveCare` = Wirkung des Spielers; Grenzen (nie Leiche, Grab, Stein, Station, Gebäude, Nacht); Save/Load mitten in einer Stelle |
| `test_friendship.gd` / `test_favors.gd` / `test_orders.gd` (+) | P4 | Schwellen 40/55/70 + Abstand + Laune, Varianten (Liesel mit/ohne `insight_not_lorenz`), Aufträge `meet`/`task`, Kategorie `friend` getrennt (max 2), Lohn je Schritt, Ersatztermine; Gefallen-Wirkungen (Schild, Eisen, Bestellung, Fürbitte, Nachtwächter, Arznei, Totenwäsche), Abklingzeit 5, Gegengefallen +4 / −6 + Sperre 7; Save/Load |
| `test_festivals.gd` | P4 | Kalendertag 54/58, Verschiebung Lichtgang auf `p8_open_day + 3` genau einmal, Kathrein fällt aus, Fest-Flags, Anwesenheit ≥ 30 Min (+2 einmal), Tanz (≥ Bekannt, 2 Partner, +3), 18:00-Auswertung `lights_all`/`lights_some` mit allen Folgen, Osrics 12 Kerzen, Jakob frei, kein Räuber, Ilse fehlt |
| `test_night_robber.gd` / `test_night_paths.gd` / `test_wanderers.gd` / `test_shops_phase8.gd` | P7 | Räuber: frühestens Nacht `p8_open_day + 4`, Ziel (frisch ≤ 5 Tage, kein Gitter, keine Kerze, keine Wache), erste sicher, dann 35 % mit Pause 2, deterministisch; Bemerken ≤ 10 m, Flucht, angegraben; zweite Begegnung → Dialog-Ausgänge mit Folgen; 05:00 aufgewühlt; nach 3 Nachtwächter; nie eine Leiche fort. Nachtwege: Folgen `np_ott`/`np_kehr` relativ zu `p8_open_day`, Krankenlicht-Zeiten, Tod 02:10 → `ott_dead`, Beobachtung beim Hinausgehen ≤ 12 m nur in der Dorf-Region, Warten bis 10 Min vorher (≤ 120). Veit: Almosen einmal je Tag, Pietät, `c_n_veit` nach 3 (oder Zuhören + 2). Hanne: Tag `day % 6 == 1`, Vorrat je Tag über beide Stände, Preise, Ankauf |
| `test_dialogue.gd` (+) / `test_story.gd` / `test_journal.gd` (+) / `test_save_migration.gd` (+) / `test_save.gd` (+) / `test_game_state.gd` (+) | P6 | neue Bedingungen und Aktionen; Osric `p8_intro` einmal; D2 nach `ott_dead` mit Reservierung in Reihe 3; Funde → `c_n_ott_three`; `InsightData.any_clues` (alle Pflicht + 2 von 4, Reihenfolge egal); `StoryConfig.underlined` wählt Text und Variante; **6 v6-, 7 v5-, 7 v4-, 6 v3-, 4 v2-, 3 v1-Fixtures laden ohne Fehler/Warnungen**; `kin_house` nach der Migration = Phase-7-Trauerflor; v7-Roundtrip identisch; Version 8 → abgelehnt |
| `test_assets_phase8.gd` | P5 | Modelle vorhanden, Budgets §8, Rig (8 bzw. 9 Knochen mit `tool`), Clip-Listen je Figur, Bewohner-Re-Export: Mesh-Hash und alte Clips unverändert, Kindmeshes (`hat_head`/`hat_hand`, `bouquet`, `basket`, Werkzeuge), Gesichter über `lib_faces` (Markerknoten), Höhen (Jakob ≈ 1,45 m, Grabgitter ≤ 1,1 m, keine Requisite > 1,4 m), Icons |
| `test_audio_phase8.gd` | W-Ton | alle neuen Cues vorhanden, Lautheit im Ziel, Emitter-Reichweiten, Kontext `fest` ersetzt die Musik, keine neue Stimmen-Pool-Größe, Web-Einstellungen unverändert |
| `test_ui_phase8.gd` / `test_map_phase8.gd` | W-UI | Kreidetafel (Werte = Systeme, nur Angelernte wählbar, Lohndose), Wunsch-Karte, Gefallen-Panel, Merkbuch „Angehörige"/„Hollerbrück" (Laune, drei Punkte), Zielzeilen-Kette, Fest-Banner, Begegnungs-Blasen, Prompts, Tageszusammenfassung, Abschluss-Panel; Karten-Marker (Besucher, Jakob, Wünsche, Münzen, Hanne, Veit, Krankenlicht erst ab `c_n_veit`, Fest, aufgewühlt; **nie** der Räuber), statisches Blatt backt nur bei Reihe 3/Requisiten neu |

**Integration**
- `test_apprentice_day.gd` (P3): echter Friedhof, Liste „Laub Alter Hof · Unkraut Lindenacker", ein ganzer Arbeitstag mit echtem Laufen, Werkzeug sichtbar (Meta), Wirkungen an den Pflegestellen, ein Fehler am festen Seed, Lohn aus der Dose; Roundtrip um 10:17 mitten in einer Stelle → Weiterarbeit bitgleich.
- `test_lights_evening.gd` (P4): Lichtgang mit echtem Zug (Region-Übergang, gestaffelt), Kerzen der Angehörigen, 12 Kerzen von Lenz, `lights_all`, Glocke, frühe Geister, Abzug 18:30; Roundtrip um 17:20.
- `test_night_watch.gd` (P7): frisches Grab, erste Räubernacht, Spieler wacht → Flucht; zweite Nacht ohne Kerze → gestellt (beide Ausgänge in zwei Läufen); dritte Variante ungestört → aufgewühlt, Besuch am Morgen mit Ruf −3, schließen. Krankenlicht `np_ott`: drei Beobachtungen mit echter Reise, Tod, D2-Lieferung.
- `test_phase8_loop.gd` (W-Welt): v6-Fixture `slot_p7_day53_neighbor` laden → `p8_open` → Osric `p8_intro` (echter `DialogueRunner`) → Rosine 1 → Kreidetafel → Jakob vormachen → Besuch Martha Kehr mit Wunsch → Blumen setzen, gießen → nächster Besuch: Trinkgeld auf dem Stein → Fenner: Reihe 3 räumen → Lieferung → Hanne am Tor → Veit dreimal → Krankenlicht beobachten → Lichtgang (Debug-Tag) → D2 → Pfarrarchiv → Kladde → `i_underlined` → sechs Geschichtsschritte (Debug-Hilfe nur für Zeit und Beziehung) → **Kapitel**. **Roundtrip** `collect_state()` identisch nach `save_game`/`load_game` an 7 Momenten: Besucher kniet; Jakob mitten in einer Stelle; Münzen auf dem Stein; Lichtgang 17:20; Räuber gräbt (02:30); Kathreintanz 20:00 in der Gaststube; nach dem Kapitel.
- `test_phase7_save_upgrade.gd` (P6): `slot_p7_mid_inn` → Phase 8 bleibt zu, Begegnungen laufen; `slot_p7_crypt_corpse` → Totenwache und Totenwäsche möglich; `slot_p7_day53_anatomist` → Besucher hören vom verkauften Glas (Wohlwollen −3 einmal).
- `test_graveyard_world.gd` (+) / `test_village_world.gd` (+) / `test_interiors.gd` (+) / `test_visit_routes.gd` (W-Welt): Layout-Diff nur L10–L15, A1–A4, G1–G2, D1–D7 und neue Einträge; Sichtprüfungen §4.8 vollständig; jede Besucherroute frei; Archivschrank und Spielmann-Platz im Raum.
- **Playthrough-Bot (W3):** `phase8_bot.gd` erweitert `Phase7Bot` um Besuche (auf Besucher zugehen, Wünsche annehmen und erfüllen, Münzen nehmen), Grabpflege (Setzen, Gießen, Kerzen, Gitter), die Kreidetafel, Vormachen, Loben, Lohndose, Geschichtsschritte, Gefallen und Gegengefallen, Almosen, Hanne, Feste (Tanz, Kerzen am Lichtgang), Nachtwache und Beobachtung (echtes Warten und Reisen). **Münzbuch je Strategie** (+ Zwecke `apprentice`, `alms`, `peddler`; Einnahmen „Trinkgeld", „Verkauf an Hanne").
  | Strategie | Start | Tage | Verhalten | Erwartung |
  |---|---|---|---|---|
  | `kindly8` | v6 `day53_neighbor` | 10 | Bogen A §1.4, Grabgitter, alle Wünsche, Jakob ab B2 | Kapitel B8–B10; Ende 75–100; morgens nie < 5; ≥ 6 Wünsche, Trinkgeld ≤ 25; `lights_all` |
  | `anatomist8` | v6 `day53_anatomist` | 10 | Präparate an 3 Lieferungen (nicht D2), Kladde über Fenner | Kapitel erreicht; Lenz und Liesel ≤ „Bekannt"; Trinkgeld < `kindly8`; Ende ≤ Start + 50 |
  | `lazy8` | v6 `day53_neighbor` | 10 | kein Lehrling, nimmt keinen Wunsch an, pflegt selbst | **kein** Kapitel (Bedingung 1/2), keine Fehler/Warnungen, Ruf sinkt höchstens um eine Stufe |
  | `night8` | v6 `day53_neighbor` | 10 | jede Nacht wach am frischen Grab bzw. im Dorf am Krankenlicht, kein Gitter, keine Kerzen | alle 4 Beobachtungsklassen, Lambert gestellt (Ausgang `reported`; zweiter Lauf `let_go`), Kapitel erreicht |
  | `founder8` | v6 `founder` | 14 | neues Spiel, Phase 8 nach Phase 7 | Kapitel ≤ Tag 68; Lichtgang ggf. verschoben; alte Kapitel unverändert |
  | `save_load8` | wie `kindly8` | 10 | lädt jeden Morgen, einmal während eines Besuchs, einmal am Lichtgang, einmal nachts beim Räuber | bitgleich zu `kindly8` |
  - **(G8 Runde 1 angepasst)** Grenzen relativ zum gemessenen Start: `kindly8` +15…+40, `anatomist8` +15…+50 und Trinkgeld < `kindly8`, `night8`/`night8b` +25…+55, `lazy8` +35…+100, `founder8` ≤ +50; `kindly8` verpasst ≤ 20 % der Besuche (der Bot beendet das Gespräch über `Visitors.note_talked`).
  - Phase-3/4/5/6/7-Bots unverändert grün: Sie sehen nach ihrem Kapitel `p8_open` (bzw. Begegnungen ab `village_open`), nehmen aber keinen Lehrling und keinen Wunsch an. **Wichtig:** Besuche, Ansicht und Räuber laufen bei ihnen nicht, weil sie vor `name_in_village` enden (Phase 3–6) bzw. am Kapiteltag stoppen (Phase 7).
- **Save-Fuzzer (W3):** + echter v7-Stand mitten in Phase 8 (Besucher kniet, Jakob arbeitet, Wunsch offen, Münzen auf dem Stein, Kerzen brennen, Gitter, aufgewühltes Grab, Räubernacht, Lichtgang) mit gezielten Mutationen (`plan` kaputt, Wunsch auf unbekanntem Grab, `kin_house` unbekannt, Level außerhalb 0…2, Münzen in der Dose negativ, `steps` > 3, Fest-Tag in der Vergangenheit) + alle v6…v1-Fixtures. Neu in der Konsistenzprüfung: ein Wunsch je Grab, höchstens 3 offen, Plan nur für den aktuellen Tag (sonst neu planen), kein Gitter auf einem `EMPTY`-Grab, `disturbed` nur auf belegten Gräbern.
- Art-Prototyp-Regression: `test_art_prototype.gd` unverändert grün.

## 11. Screenshot-Liste Gate G8 (`graveyard_shots_phase8.gd -- --out=/abs/dir`, `village_shots.gd --phase8 -- --out=/abs/dir` + `ui_screenshots.gd --phase8`, 1280×720, echter Renderer, dazu je eine Web-Aufnahme der Motive 08, 12, 22 → `docs/reviews/phase8_round1/`)
| # | Motiv |
|---|---|
| p8_00 | Kontaktbogen aller neuen Figuren neben dem Totengräber und zwei Dorfbewohnern (idle, gleiche Kamera, Tag und Laternenlicht, Namen darunter) |
| p8_01 | Gesichter nah: Jakob, Veit, Hanne, Lambert (gestellt, Halstuch unten), Martha, Gesa, Hinrich, Johann |
| p8_02 | Martha Kehr kommt den Kutschweg herauf, Korb mit Heidekraut, Morgen |
| p8_03 | Martha kniet am Grab im Lindenacker, Strauß auf dem Hügel (Spielkamera Zoom 22) |
| p8_04 | Hinrich Brandt steht mit dem Hut in der Hand am Grab, Nachmittag |
| p8_05 | Gesprächsbild: Wunsch-Karte „Ein paar Blumen …" |
| p8_06 | Zwei Münzen und ein Zettel auf dem Stein, Prompt sichtbar |
| p8_07 | Grabblumen frisch / welk / Wachskranz nebeneinander, Gießkanne am Regenfass |
| p8_08 | Jakob harkt im Alten Hof mit dem Rechen in der Hand, die Eiche im Hintergrund |
| p8_09 | Jakob schaut zu, wie der Totengräber jätet (Vormachen) |
| p8_10 | Jakob gießt (Kanne am `tool`) · Jakob setzt eine Kerze in der Dämmerung |
| p8_11 | Kreidetafel-Panel mit drei Zeilen, Kreidestrichen und Lohndose |
| p8_12 | Brotzeit: Jakob auf der Bank an der Hütte |
| p8_13 | Esch an `old_01`, Theres kniet an `old_08` mit Christrosen |
| p8_14 | Begegnung am Brunnen (Theres und Liesel, zwei Blasen) |
| p8_15 | Laune: Lenz bedrückt an der Kirchtür (`idle_low`) und die Zeile „[Zuhören]" |
| p8_16 | Veit am Friedhofstor sitzend, Becher; Hanne am östlichen Torpfeiler mit Kiepe |
| p8_17 | Hanne am Brunnen im Dorf, Laden-Panel |
| p8_18 | Dorf nachts: Krankenlicht bei den Otts, Spieler am Beobachtungsplatz, Lenz mit Laterne an der Tür |
| p8_19 | Liesel kommt zur Totenwache (02:40), das Licht brennt noch |
| p8_20 | Kathreintanz: Gaststube geschmückt, Spielmann, zwei tanzende Paare, Totengräber tanzt mit Theres |
| p8_21 | Lichtgang 1: der Zug mit Laternen auf dem Kutschweg in der Dämmerung |
| p8_22 | Lichtgang 2: Übersicht Alter Hof + Kirchhof, jedes Grab mit Licht, Lenz am Kirchhof (Zoom 24) |
| p8_23 | Lichtgang 3: blasse Geister über den beleuchteten Gräbern, nur der Totengräber sieht sie |
| p8_24 | Nacht: Lambert gräbt am frischen Grab, Blendlaterne |
| p8_25 | Lambert läuft zum Südzaun des Lindenackers (Flucht) · gestellt: sitzt im Aushub, Dialog |
| p8_26 | Aufgewühltes Grab am Morgen und Grabgitter auf einem anderen frischen Grab |
| p8_27 | Dritte Reihe im Lindenacker vorher (Stumpf, Brombeere) / belegt mit Steinen |
| p8_28 | Pfarrarchiv in der Kirche, Spieler am Schrank, Lenz daneben; Namenstafel „Konrad Wackernagel" am Gedenkbrett |
| p8_29 | Merkbuch „Angehörige" und „Hollerbrück" mit Laune und drei Geschichtspunkten |
| p8_30 | Merkbuch: Erkenntnis „Der unterstrichene Name" (Pflicht-Gruppe + zwei von vier) |
| p8_31 | Liesels Totenwäsche am Gruft-Tisch (Gefallen) |
| p8_32 | Karte Friedhof mit Besucher-, Jakob-, Wunsch- und Münz-Markern · Karte Dorf mit Krankenlicht und Hanne |
| p8_33 | Abschluss-Panel „Wer heraufkommt" |
| p8_vis_visitors / _apprentice / _night / _village | Sichtprüfung §4.8 mit eingezeichneten Strahlen (frei grün, verdeckt rot), Zoom 12/22/24 |
Dazu Asset-Tafeln und Animations-Kontaktbögen `docs/reviews/phase8_assets/` (Figuren mit Rig-Posen, alle neuen Clips, Requisiten, Icons) und eine Performance-Tabelle (`perf_p8_01…05`: Friedhof Tag mit Jakob und 2 Besuchern · Friedhof nachts mit Räuber und Kerzen · **Lichtgang Übersicht** · Gaststube am Kathreintanz · Dorf nachts mit Krankenlicht), Web-Sonde mit Szenario Lichtgang.

## 12. Wellenplan
### 12.1 Wellen
| Welle | Agents (parallel) | Inhalt | Ende |
|---|---|---|---|
| **W0** | Lead | **Zuerst v6-Fixtures** (6 Stände §5.2, Stand G7 + Gruft-Umbau, eigener Commit vor jedem Gerüst) und `tests/fixtures/phase8/{layout_p7,village_layout_p7}.json`. Dann: Datenklassen ✦ (inkl. Erweiterungen), Stubs mit exakten Signaturen, 13 EventBus-Signale, Database-Ordner, `SaveMigration.CURRENT = 7` mit `migrate_6_to_7` als Identität (fail-safe), Config-Fixtures `tests/fixtures/phase8/` (+ `Phase8Fixtures`, u. a. `kin_grave(kin, plot, buried_day)`, `visit_now(kin, grave, phase)`, `wish_open(grave, kind)`, `flowers(grave, state)`, `apprentice_with(levels, board, coins)`, `story_at(npc, step)`, `fest_today(id)`, `robber_night(grave)`, `sick_light(path, offset)`, `p8_open(tree, day)`), `test_phase8_scaffold.gd`, `test_saves_v6_load.gd` | Import + alle Tests grün → Commit |
| **W1** | **7 Pakete:** P1, P2, P3, P4, P5, P6, P7 (bei 5 Agents: P1 + P3 · P2 + P7 · P4 · P5 · P6) | Systeme mit Unit-Tests gegen Fixtures (ohne Welt): Dorfleben, Laufzeit-Zeitpläne, LOD (P1) · Besucher, Ansicht, Wünsche, Trinkgeld, Grabpflege, Geister (P2) · Lehrling mit Planer, Anlernen, Lohn (P3) · Freundschaft, Gefallen, Feste, neue Auftragsarten (P4) · **Figuren zuerst**, dann Clips, Requisiten, Icons (P5) · Dialoge, Begegnungstexte, Zeitpläne, D2, Merkbuch `any_clues`, Migration v7 (P6) · Nachtgräber, Krankenlicht, Veit, Hanne, Läden, Items (P7) | je Modul: Tests grün → Merge durch Lead, danach `--import` |
| **W2** | W-Welt, W-UI, W-Ton (3 parallel) | Reihe 3, Besucherplätze und -routen, Lehrlingsecke, Räuberweg, Dorf-Marker, Räume (Kathrein, Archiv), alle neuen Npc in der Welt, **Sichtprüfungen §4.8**, `test_phase8_loop`; alle Panels, Merkbuch-Seiten, HUD, Zielzeilen, Karte, Debug, Icons; alle Klänge, Musik, Emitter, Lautheit | Integration + Roundtrips grün, Screenshots erstellt |
| **W3** | QA (19), Art (04), Audio (17), Lead | `phase8_bot.gd` (6 Strategien, Münzbuch), Save-Fuzzer v7, Performance relativ + Web-Sonde (§9), Stil-, Gesichts-, Animations- und Ton-Prüfung (Würde der Trauer, Werkzeug in der Hand, keine Teleports, helle Räume), Befunde beheben (Besitzer), Gate-Protokoll in `QUALITY_GATE_STATUS.md` | **STOPP – Benutzerprüfung G8** |

### 12.2 Abhängigkeiten
- **P1 liefert zuerst** (Tag 1–2): `ScheduleBuilder`, `Npc.set_runtime_schedule` und die `show_with`-Kindmeshes. P2 (Besuche), P3 (Jakob), P4 (Feste) und P7 (Räuber, Nachtwege) bauen ihre Zeitpläne darauf. Bis dahin arbeiten sie gegen `Phase8Fixtures` mit Daten-Zeitplänen.
- **P2 liefert zuerst** `GraveCare` (Blumen, Kerzen, Gitter, aufgewühlt) – P3 (Gießen, Kerzen) und P7 (Ziel, aufgewühlt) hängen daran.
- **P5 liefert zuerst** Jakob und eine Trauernde (Rig, `idle/walk/kneel/rake`) – **Blocker** für die Sichtprüfung und die Bildserien. Bis dahin graue Platzhalter-Quader in Modellmaß und Ilses Figur als Stellvertreterin (nur Tests, nie in Screenshots).
- **P6** braucht von P4 nur die Auftrags-Ids (`of_*`) und von P7 die Hinweis-Ids; die Texte stehen hier in §1.6, §2.4, §2.13.
- `grave_plot.gd`, `graveyard.gd`, `ghost_*`: nur P2. `npc.gd`, `npc_lod.gd`, `relationships.gd`: nur P1. `orders*.gd`: nur P4. `dialogue_*`, `save_*`, `game_state.gd`, `journal_manager.gd`: nur P6. `cleanliness_manager.gd`: nur P3. `data/shops/*`, `data/items/*`: nur P7.
- **Lastverteilung W1** (Richtwert Arbeitstage): P1 3 · P2 4 · P3 3 · P4 3 · P5 6 (größtes Paket: 8 Figuren, ≈ 45 Clips, Re-Export der Bewohner) · P6 4 · P7 3.

### 12.3 Texte
P6 besitzt alle Dialoge, Begegnungen und Zeitpläne; P2 die Wunsch-, Ansichts- und Geisterzeilen; P1 die Launen- und Reaktionszeilen in `VillagerData`; P4 die Auftrags- und Festtexte, P3 Jakobs Fehler- und Tafeltexte, P7 Veit-, Hanne-, Räuber- und Nachtweg-Texte. Die Leittexte stehen in §1–§2; wer sie ändert, meldet es dem Lead.

### 12.4 Prioritäten (Umfang „mittel")
| Prio | Inhalt | Wenn W1 eng wird |
|---|---|---|
| **A** (Gate) | Besucher mit Ablauf und Ansicht · Wünsche `tend`/`flowers`/`candle` + Trinkgeld · Grabblumen und Grabkerzen · Lehrling mit `rake`/`weed`/`water` · Launen + Zuhören · 8 Begegnungen · Geschichten Rosine, Lenz, Liesel, Quast · Lichtgang · Veit · Krankenlicht `np_ott` · D2 · Kladde · `i_underlined` · dritte Reihe · Save v7 | – |
| **B** (geplant) | Geschichten Esch, Theres, Fenner · Gefallen und Gegengefallen · Wünsche `line`/`vase` · Lehrling `candle` · Kathreintanz · Hanne · Lambert mit Gitter · `np_kehr` · weitere 8 Begegnungen | in dieser Reihenfolge von unten streichen → §13, Benutzer wird informiert |
| **C** (gestrichen) | Pilger, Wochentage, Bettel-Aufträge, Briefe, zweiter Lehrling | §13 |

## 13. Nicht in Phase 8
- Pilger und weitere Wanderer, Fremde aus der Stadt als Figuren, der „Herr mit dem Koffer" als Person (Phase 9), Briefe und Botengänge (Phase 9)
- Freie Gespräche, Gerüchte-Netz mit Weitergabe, NPC-Bedürfnisse, Wegfindungs-KI, Tagesabläufe, die sich dauerhaft nach dem Spieler richten; Wochentage und Sonntage (ein eigener Kalender-Vertrag)
- Romanzen, Werben, Hochzeiten, Kinder, Geburtstage, Geschenk-Kalender; eine Beziehung zu Osric, Ilse, Veit, Hanne oder den Angehörigen als Zahl
- Weitere Feste (Advent, Weihnachten, Neujahr, Fastnacht), Märkte, Messen, Predigten, Beichte, Prozessionen außer dem Lichtgang; Tanz- oder Musik-Minispiele
- Ein zweiter Lehrling, Gesellen, Mägde, bezahlte Helfer aus dem Dorf; Lehrling bei Nacht, in Gebäuden, an Leichen, Gräbern oder Stationen; Lehrling, der stirbt, kündigt oder untot wird; alles aus Phase 14
- Leichenraub mit fortgetragener Leiche, leere Gräber, Exhumieren, Verfolgung, Kampf, Fallen, Hunde, Strafen, Gericht, Verhaftung durch den Spieler; der Auftraggeber des Nachtgräbers
- Die Auflösung, wer zeichnet; Lorenz' Aufenthalt; Liesels Gesangbuch lesen; das Gitter in der Gruft (Phase 12)
- Wetter, Frost, Schnee, Jahreszeiten-Wechsel der Grabblumen; Pflanzensorten-Auswahl, Beete, Gartenbau
- Neue Gebäude, neue Innenräume, Begehbarkeit der Dorfhäuser außer den Phase-7-Räumen; neue Abschnitte außer der dritten Reihe; Zier im Dorf
- Preisdynamik, Steuern, Pacht, Kredit, Trinkgeld als Einnahmequelle mit Wachstum (Phase 10)
- Änderungen am Maler-Shader, an den Atmosphären-Presets, am Gesichtsaufbau `lib_faces.py`, am Rig (Knochenzahl), an den freigegebenen Abschnitten, Gebäuden und Räumen (außer §4.7)

## 14. Offene Fragen an den Benutzer (Entscheidung vor W0)
1. **Wen hat Lorenz unterstrichen?** (§1.6; Phase 8 zeigt nur den Verdacht, nicht die Wahrheit)
   - (a) **Pfarrer Lenz** – der Naheliegende: sein Sterbebuch, sein Versehgang, die Tinte, die „früher da ist".
   - (b) **Wundarzt Quast** – die Gläser, die stillen Herzen, der „Herr mit dem Koffer" könnte zu ihm passen.
   - (c) **Seelfrau Liesel Dorn** – die Wendung: Sie hat Lorenz jedes Zeichen gemeldet, und sie „kommt, bevor man ruft". Der Spieler kommt ihr in Phase 8 nahe; die Erkenntnis lässt offen, ob Lorenz sie verdächtigte oder schützen wollte, und Liesel weiß nichts davon.
   - **Vorschlag: (c)** – die stärkste Spannung für die Phasen 9–18, ohne etwas aufzulösen. Alle drei Textfassungen werden geschrieben (`StoryConfig.underlined`), damit die Wahl bis W2 änderbar bleibt.
2. **Neue Grabstellen in Phase 8?** (§2.8)
   - (a) keine – nur eine Stelle `l_09` für D2; Besuche nur an bestehenden Gräbern, kaum frische Gräber für den Nachtgräber, ≈ 1 Lieferung im Bogen.
   - (b) **eine dritte Reihe im Lindenacker mit 4 Stellen** (Südzaun 3,2 m nach Süden, ein Waldbaum versetzt).
   - (c) zwei neue Reihen (8 Stellen) – mehr Lieferungen und Münzen (≈ +50 im Bogen), größerer Welt-Eingriff, mehr Sichtprüfung.
   - **Vorschlag: (b)** – genug frische Gräber für erste Besuche, den Nachtgräber und D2, ohne die Münzrechnung zu kippen.
3. **Welche Feste?** (§2.7; der Spielkalender steht Ende Nebelung)
   - (a) **Kathreintanz (25. Nebelung) und Lichtgang (Vorabend des ersten Advents, eigener Hollerbrücker Brauch)** – kalendertreu, der Lichtgang gehört zum Friedhof.
   - (b) Kirchweih und Erntedank wie vorgeschlagen, als „nachgeholt" oder ohne Kalenderbezug – passt nicht zum November und zu den Inschriften-Daten.
   - (c) nur der Lichtgang – spart Fest-Gaststube, Tanz-Clips und Fiedelmusik.
   - **Vorschlag: (a)**, der Kathreintanz als Priorität B (§12.4).
4. **Der nächtliche Grabräuber – wie hart?** (§2.6.3)
   - (a) **wie beschrieben:** nicht kämpferisch, gräbt sichtbar, die Leiche bleibt immer im Grab; Schutz durch Grabkerze, Grabgitter oder Fenners Nachtwächter; zweimal ertappt → zum Schultheiß oder laufen lassen; nie gestellt → nach drei offenen Gräbern fängt ihn der Nachtwächter.
   - (b) sanfter: man sieht ihn nie, nur die Spuren am Morgen; Schutz wie (a).
   - (c) streichen und für Phase 15 aufheben; Grabgitter entfallen.
   - **Vorschlag: (a)** – ein Grund, nachts auf den eigenen Friedhof zu sehen, ohne Kampf und ohne Leichenverlust.
5. **Der Lehrling – wer und zu welchem Preis?** (§2.5)
   - (a) **Jakob Wackernagel**, Rosines Sohn (das Fieber-Kind aus Phase 7), **3 Münzen je Arbeitstag** aus der Lohndose.
   - (b) ein fremder Waisenjunge aus Ellbach, der im Schuppen schläft – kein Lohn, dafür 2 Münzen Kost je Tag; ohne Rosine-Geschichte.
   - (c) Jakob, aber Rosine bezahlt ihn – einfacher, aber ohne Münzsenke (Ende Bogen A ≈ 112 statt 88).
   - **Vorschlag: (a)** – er hat schon ein Gesicht im Dorf, und sein Lohn ist die wichtigste Senke gegen das Trinkgeld.
6. **Umfang der Freundschafts-Geschichten** (§2.4, §12.4)
   - (a) **alle sieben lebenden Bewohner × 3 Schritte** (21 Schritte), Esch, Theres, Fenner als Priorität B.
   - (b) nur Rosine, Lenz, Quast und Liesel (12 Schritte, Lehrling und Geheimnis); Esch, Theres und Fenner bekommen ihre Geschichten in Phase 9. Spart ≈ 20 % in P4 und P6.
   - **Vorschlag: (a)** – das Dorf wirkt nur lebendig, wenn nicht nur die drei Verdächtigen eine Geschichte haben; die Prioritäten halten den Umfang „mittel".

### §14 Benutzerentscheidungen (bindend, 04.10.2026)
1. **Unterstrichener Name:** (c) **Seelfrau Liesel Dorn** – `StoryConfig.underlined = &"washer"`; Phase 8 zeigt nur den Verdacht.
2. **Neue Grabstellen:** (b) **dritte Reihe im Lindenacker, 4 Stellen** (Südzaun 3,2 m nach Süden, ein Waldbaum versetzt).
3. **Feste:** (a) **Kathreintanz (25. Nebelung) + Lichtgang (Vorabend des ersten Advents)**; Kathreintanz Priorität B.
4. **Nachtgräber:** (a) **sichtbar, ohne Kampf**, Leiche bleibt immer im Grab; Schutz Grabkerze/Grabgitter/Nachtwächter; zweimal ertappt → Schultheiß oder laufen lassen.
5. **Lehrling:** (a) **Jakob Wackernagel**, Rosines Sohn, **3 Münzen je Arbeitstag** aus der Lohndose.
6. **Freundschafts-Geschichten:** (a) **alle sieben lebenden Bewohner × 3 Schritte**; Esch, Theres, Fenner Priorität B.

---

### G8 Runde 1 – Benutzerentscheidungen (bindend, 11.10.2026: „die 4 offenen Punkte kannst du alle machen")
1. **E8-1 Licht – vom Benutzer bestätigt:** die kürzeren Novembertage (Zeit-Schlüssel ab Tag 50 → 56: Tag bis 15:00, Dämmerung 16:40, Nacht 18:10) und das hellere Krankenlicht (2,2 / 6 m) bleiben wie gebaut.
2. **B8-1 Besuche:** Besucher warten länger und immer auf ein Wort (§2.2.3), Torglocke am Tor mit HUD-Notiz (§2.2.3, §8.3, §8.4). Ziel `kindly8` ≤ 20 % verpasst – gemessen 5 % (1 von 19, vorher 10 von 19).
3. **E8-2 / B8-3 Münzen:** jetzt ausgeglichen – Pflegegeld nach Bedarf (ab 80 Münzen) und Gerede dorfweit (§2.2.4, §2.10).
4. **B8-2 Vase:** Wunschtext und Wunschkarte nennen die Werkbank und Theres' Samen (§2.2.5).

## W0-Notizen (Lead, Welle 0 – verbindlich für W1)
1. **v6-Fixtures** `tests/fixtures/saves_v6/*.json` wurden **vor** jeder Phase-8-Code-Änderung auf Stand **a499aa8** erzeugt (= G7 9353b74 + Gruft-Umbau 6da74c7/8be6c31 + `stench_exempt_min_level = 2`) – über `Phase7Bot` + echte Systeme (`make_v6_saves.gd` + `_driver.gd`, historisches Werkzeug; `-- --out=/abs/dir [--only=neighbor,anatomist,eve,founder,inn,crypt]`; auf einem Phase-8-Stand schriebe es v7). Eigener Commit **6866450**, zusammen mit `tests/fixtures/phase8/{layout_p7,village_layout_p7}.json` (= `data/world/{graveyard,village}_layout.json` von a499aa8, bytegleich). Die Endstände setzen `slot_p6_day40_reverent` mit denselben 13 Bot-Tagen fort wie `test_phase7_playthrough.gd`. Gemessen (sha256-Präfix):
   - *day53_neighbor* (`neighbor7`, 07:00 Tag 53, `170faf0a41ce`): Kapitel `name_in_village` an Tag 50, Gruft 3 · Kapelle 3 · Schuppen 2, 32 Gräber `MARKED`, Lindenacker voll (0 frei), **alle acht „Vertraut“** (Hagedorns Wert zählt mit), Ruf 100, Pietät 100, 11 Aufträge, **48 Münzen** (§1.4/§2.10 rechnen mit ≈ 60 – die Münzrechnung von W3 startet bei 48).
   - *day53_anatomist* (`anatomist7`, `614d07dc9088`): die letzte Vorlesungsnacht geht über Mitternacht, die 13 Bot-Tage enden deshalb um **07:00 Tag 54** (Dateiname nach Vertrag beibehalten). Kapitel erreicht, `anatomy_known`, 16 Präparate genommen / 8 verkauft (auch von Lindenacker-Toten), **60 Münzen** (§2.10: ≈ 71), Ruf 95, Pietät −40, 5 „Vertraut“. Siehe Befund Punkt 12.
   - *day50_eve* (`neighbor7`, `eeac8cb77b96`): Kapiteltag 50, gespeichert **23:05** (der Bot arbeitet bis in die Nacht; geprüft wird „Abend des Kapiteltags“), Region graveyard, 36 Münzen.
   - *founder* (`founder7`, `330df1f67f56`): `Phase7Bot` kennt keinen `founder7` – der Treiber definiert ihn nach Phase-7-Vertrag §10 („crafter + Phase 7“ = Phase-6-`founder`-Flags mit `keep_p5`, optional Gruft/Kapelle) und spielt ab `slot_p6_day37_founder` bis zum Kapitel (Tag 47) → **07:00 Tag 48**, alle vier Kapitel, 52 Münzen, Ruf 100, Pietät 100.
   - *mid_inn* (`neighbor7`, `bac031a2a80d`): **Tag 44, 14:17** in der Gaststube (Region village, Raum inn), `village_open`, Kapitel offen, 54 Münzen.
   - *crypt_corpse* (`neighbor7`, `856597492cb9`): **Tag 42, 08:04**, `corpse_0024` auf dem Gruft-Tisch (`room crypt`), nicht untersucht, **nicht gewaschen, nicht eingekleidet**, Spieler in der Gruft, Phase 7 offen.
2. **Speicherformat v7 schon in W0:** `SaveMigration.CURRENT = 7` (`SaveFileIO`/`SaveManager.FORMAT_VERSION` folgen), Kette 1→…→7. `migrate_6_to_7(state, meta)` ist **Identität auf einer tiefen Kopie** (`## STUB (P6)`, fail-safe wie §12). `V7_EMPTY_NODES` = die zehn Ids aus §3.4 (`npc_life, visitors, grave_care, apprentice, friendship, festivals, wanderers, night_robber, night_paths, apprentice_box`), in W0 **nicht** eingefügt. **Abweichung zu Phase 7:** `SaveManager.without_absent_defaults` kennt V7 **schon jetzt** (wirkungslos, solange nichts eingefügt wird; P6 muss es nicht mehr ergänzen). `CorpseRecord.kin_house` und `GraveRecord.disturbed`/`extra_lines` werden **ab W0 gespeichert** (39 Record-Felder, 10 Grab-Felder; `from_dict` tolerant: `disturbed` nur echtes `true`, `extra_lines` nur nicht leere Strings). **Nicht** in W0: `GameState.DEFAULT_STATS`/`COIN_REASONS` (+ 26 Stats, 3 Zwecke → P6, wie Phase 5–7). Lade-Wächter `tests/integration/test_saves_v6_load.gd`: 6 v6-Fixtures laden ohne Warnung (eine bekannte Ausnahme, Punkt 12), Zustand erhalten, Neuspeichern v7, Roundtrip identisch.
3. **Datenklassen ✦ vollständig** (§3.2.1): `NpcLifeConfig`, `ChatterData`, `VisitorConfig`, `KinData`, `WishData`, `GraveCareConfig`, `ApprenticeConfig`, `ApprenticeTaskData`, `FriendStoryData`, `FriendStepData`, `FavorData`, `FestivalData`, `WandererData`, `RobberConfig`, `NightPathData`, `NightVisitData`. Die Config-Defaults tragen die **Vertragstabellen** (nicht `[]`/`{}` der Kurzschreibweise §3.4): `NpcLifeConfig.mood_rules` = §2.1.1 als `[{trigger, mood, npcs, days, events}]` (Trigger `festival`, `mourning_circle`, `own_step`, `rumor` ×2 – Pfarrer/Liesel mit `lecture_rumor`/`specimen_sold_villager`, Fenner mit `grave_disturbed` –, `sick_light`; `npcs []` = alle bzw. der Kreis bzw. die Person; `days` 0 = heute, 1 = gestern, 2 = heute oder gestern), `reactions` = die 9 Ereignisse aus §2.1.3 je 2 Tage, `VisitorConfig.view_effects` = §2.2.4 (`disturbed`, `neglected`, `bare`, `kept`, `bonus`, `specimen` → `{rep_event, goodwill}`). Rein additive Zusätze: `WishData.KINDS`, `FavorData.EFFECTS`, `FestivalData.SHIFT_NONE/OPEN_PLUS`, `OrderData.CATEGORY_FRIEND`, **`ApprenticeTaskData.order`** (§3.5 sortiert „über `order`“, das Feld fehlte), **`RecipeData.requires_flag`** (§2.11 `memorial_plate`; ungelesen – wer die Rezeptliste der Steinmetzbank filtert, vergibt §3.2 nicht: P4 meldet sich beim Lead).
4. **Erweiterungen bestehender Datenklassen – Klassen-Default und `data/config/*.tres` gemeinsam** (anders als Phase 7): `NpcConfig` (+ 5, `npc_config.tres`), `RelationshipConfig.gains` (+ 13, `relationship_config.tres`), `OrdersConfig.max_active_friend` (`orders_config.tres`), `ReputationConfig.event_points` (+ 10) und `PietyConfig.events` (+ 4) samt `.tres`, `StoryConfig.underlined = &"washer"` (§14.1, `story_config.tres`). Die Phase-8-Fixtures dieser Configs sind der W0-Stand der Daten (`EXTENDED_CONFIG_NAMES`); der Phase-7-Scaffold führt `gains` in `DATA_CHANGED_AFTER_W0`, `test_piety`/`test_reputation` vergleichen die Daten jetzt mit der Phase-8-Fixture. Nur Klassen-Default (die `.tres` setzen den Wert nicht ausdrücklich): `ActionConfig.noisy_actions`, `VillagerData` (+ 7, leer; Daten bei P1), `OrderData.category` (+ `KINDS` `meet`, `task` angehängt), `InsightData.any_clues/any_count`, `GhostLines` (+ 5 Pools, leer – `ghost_lines.tres` bleibt bei P2, die Leitzeilen stehen in der Fixture), `CorpseRecord`/`GraveRecord` (oben).
5. **Neue Config-Dateien** = Klassen-Default, ausdrücklich geschrieben: `data/config/{npc_life_config (→ P1), visitor_config (→ P2), grave_care_config (→ P2), apprentice_config (→ P3), robber_config (→ P7)}.tres`; identische Kopien in `tests/fixtures/phase8/*_fixture.tres`. Scaffold-Test: data == Fixture == Klassen-Default bis zur Übergabe (erweiterte Configs: data == Fixture). Weicht ein Besitzer danach ab, setzt er Default und `.tres` gemeinsam und trägt die Eigenschaft in `DATA_CHANGED_AFTER_W0` (`test_phase8_scaffold.gd`) ein – die Fixture bleibt.
6. **Nicht** in W0 angelegt (Besitzer, W1): `data/npc_life/chatter/*` (P1, Texte P6), Phase-8-Felder in `data/village/villagers/*` (P1), `data/visitors/*`, `ghost_lines.tres` (P2), `data/apprentice/tasks/*` (P3), `data/friendship/*`, `data/festivals/*`, `data/orders/of_*`, `data/recipes/memorial_plate.tres` (P4), `data/village/wanderers/*`, `data/night/paths/*`, `data/shops/*` (Hanne + Zusätze), `data/items/*` (10 Phase-8-Items) (P7), `data/story/d2_ott.tres`, `data/finds/f_d2_*`, `data/journal/*`, `data/dialogue/*`, `data/npc/*_schedule.tres` (P6). Die Fixtures sind **vollständige Vorlagen** mit den Leittexten aus §1–§2 (kopieren erlaubt). Neue Items in `data/items` ändern ggf. Item-Zählungen in fremden Tests – der Besitzer passt sie an (Lead-genehmigt). Zeitplan-Fixtures gibt es in Phase 8 **nicht** (Besuche, Lehrling, Feste, Räuber laufen über `ScheduleBuilder`; Veit/Hanne schreibt P6 mit den Wegpunkten von W-Welt).
7. **Stubs** (`## STUB (P<n>)`, Signaturen exakt §3.4; Liste `IMPLEMENTED` in `tests/unit/test_phase8_scaffold.gd` füllen die Besitzer). **Fett = antwortet schon aus `load_state` (Format §5.1)** bzw. aus GameState, damit W1-Tests fremder Pakete vor dem Merge Zustände setzen können (`Phase8Fixtures`):
   - **P1:** `NpcLife` (Gruppen `npc_life`/`saveable`, 70; **`is_open()`/`open_day()` lesen die Flags `p8_open`/`p8_open_day`**, `mood()` = `plain`), `MoodRules`, `ChatterRunner` (Gruppe `chatter`, nicht gespeichert), `ReactionRules`, `ScheduleBuilder` (liefert leere `ScheduleEntry`/`NpcSchedule`). An `Npc`: `set_runtime_schedule(s)`, `clear_runtime_schedule()` (inert).
   - **P2:** `Visitors` (71; **`visit_of`/`active_visits`/`goodwill`/`open_wishes`/`tip_on_stone`** aus `{"plan", "goodwill", "wishes", "tips_on_stone"}`; ein Plan-Eintrag trägt in W0 den Testschlüssel **`"phase"`** – `active_visits` = Phase gesetzt und ≠ `gone`; leitet P2 die Phase aus Uhr + Plan ab, lässt es `Phase8Fixtures.visit_now` vom Lead anpassen; `tip_on_stone` liefert als Index die Stelle der Kin-Id in `Database.kin_list()`), `VisitRules`, `WishRules`, `GraveView`, `GraveCare` (72; **`flowers_state`** nach Uhr und Config aus `flowers{planted, watered, wreath}`, **`candle_lit`/`has_mortsafe`/`is_disturbed`/`can_fill`**), `GraveCareRules`, `TipStone`, `RainBarrel` (je `.tscn` mit `Interactable`). An bestehenden Klassen: `Graveyard.append_inscription/replace_name_line` (false; Parameter `_name`, weil `name` den Node-Namen verschatten würde – Stelligkeit gleich), **`GhostMood.score(…, care := 0)`** (achter Parameter, in W0 ignoriert – Phase-7-Wert bitgleich), `GhostManager.set_early_window` (inert).
   - **P3:** `Apprentice` (73; **`is_hired`/`level`/`jobs`/`board_lines`/`morale`/`unpaid_days`**), `ApprenticeRules`, `ApprenticePlanner`, `ApprenticeBoard` (+ `.tscn`, `PANEL &"apprentice_board"`), **`ApprenticeBox extends Chest`** (+ `.tscn` mit `Interactable` + `Storage`, `"apprentice_box"`/79, `SLOT_COUNT 6` – die Platzzahl setzt P3; **`coins` geht schon durch `save_state`/`load_state`** `{storage, coins}`, nie negativ). An `CleanlinessManager`: `tend_by(spot_id, actor)` (false) und **`set_level(spot_id: String, level: int)`** (inert) – §3.3 ruft es für den Räuber auf, §3.4 nennt keine Signatur: W0 legt sie fest, P3 füllt, P7 ruft.
   - **P4:** `Friendship` (74; **`step_done`/`steps_total`/`full_stories`** aus `{"steps"}`), `FriendRules`, `FavorRules`, `Festivals` (75; **`fest_day`/`today`** aus `{"days"}`), `FestivalRules`, `FestDecor`, `MemorialPlate`, `Fiddler` (ohne `Interactable`, `refresh()`), `ArchiveCabinet` (+ `Interactable`). An `Orders`: `note_meet(npc_id, place_id)`, `note_task(action_id)` (inert).
   - **P6:** `SaveMigration.migrate_6_to_7` (Identität), `V7_EMPTY_NODES`; **`Village.mourning_house_for(arrival_day, seed, houses)`** (statisch, `&""` – P6 zieht es aus `mourning_house` heraus: `houses[posmod(hash([arrival_day, seed]), houses.size())]`).
   - **P7:** `Wanderers` (76; **`alms_count`**), `NightRobber` (77; **`tonight_target(day)`** nur für `target_day`, **`encounters`/`fate`**), `RobberRules`, `NightPaths` (78; **`observed`**), `NightPathRules`, `WatchSpot` (+ `Interactable`), `SickLight`.
   - **Hüllen ohne Vertragssignatur** (§3.2.1 nennt die Klassen, §3.4 keine Methoden): `VisitRules`, `GraveCareRules`, `FriendRules`, `FavorRules`, `FestivalRules`, `RobberRules`, `NightPathRules` – leer; die Besitzer legen reine statische Funktionen an und tragen sie beim Entfernen der Stub-Markierung in `METHODS` ein.
   - P5: keine Stubs. W-UI/W-Welt: Panels, Builder, Szenen nicht als Stub (W2).
8. **EventBus:** die 13 Signale aus §3.3 (Block „Phase 8“). **Eingaben:** keine neuen. **Database** (§3.5): `chatter/chatters` (nach id), **`kin(kin_id)` / `kin_list()`** (der Vertrag nennt die Liste nur „kin“ – Lead-Entscheidung), `wish/wishes`, `apprentice_task/apprentice_tasks` (nach `order`), `friend_story/friend_stories` (Schlüssel `npc_id`), `favor/favors`, `festival/festivals` (nach `calendar_day`), `wanderer/wanderers`, `night_path/night_paths` (nach `start_offset`); Ordner wie §3.5, leer/fehlend = leere Liste.
9. **Fixtures für W1:** `tests/fixtures/phase8/` – erzeugt von `make_phase8_fixtures.gd` (+ `_driver.gd`, historisch; schreibt jede Eigenschaft ausdrücklich): Configs (Punkt 5) + erweiterte Configs (W0-Stand) + `ghost_lines_fixture.tres` (Phase-7-Fixture + 5 Pools mit den Leitzeilen §2.11 + `by_story.d2_ott`); `villagers/*` (Daten zum W0-Stand + Phase-8-Felder: `circle` – Rosine Kehr/Brandt, Esch Brandt, Theres Sieber/Kehr, Fenner Sieber, Liesel beide Katen, Lenz/Quast leer –, je 2 `mood_lines` je Laune (W0-Entwürfe, P1 schreibt), `story_id = npc_id`, `favor_id = fav_<npc_id>`, `visit_grave`/`visit_every_days` (Esch `old_01`/6, Theres `old_08`/5, Liesel –/4), `graveyard_npc` (`npc_<id>_g`, Lenz `npc_priest`, Quast keiner), Reaktions-Gerede unter **`remarks["event_<ereignis>"]`** mit den Leitzeilen §2.1.3); `kin/*` (7: `kin_kehr|brandt|ott|sieber` + **`kin_smith`, `kin_grocer`, `kin_washer`** mit `villager_id`; Liesel `house cottage_dorn`, die zweite Kate zählt über `circle`); `wishes/*` (`w_tend`, `w_flowers`, `w_candle`, `w_vase`, `w_line_1…6`); `chatter/*` (16; Orte: bestehende Dorf-Wegpunkte, Friedhof `gate_outside`/`peddler_gate`; `ch_grave_kehr` `place ""` = das Grab der Besucherin); `apprentice/tasks/*` (4); `friendship/stories/*` (7 × 3 Schritte) und `favors/fav_*` (7); `orders/of_*` (22 Geschichts-Aufträge + 14 Gegengefallen, `category friend`); `festivals/*` (2), `wanderers/*` (2), `night/paths/*` (2), `recipes/memorial_plate.tres`, `shops/{peddler,grocer,smith}.tres` (Hanne neu, Theres/Esch = Daten + Zusätze), `clues/c_n_*` (7), `insights/i_underlined.tres` (Variante washer) + `i_underlined_{priest,surgeon}.tres` (andere Texte, **dieselbe Id** – P6 wählt über `StoryConfig.underlined`), `story/d2_ott.tres`, `finds/f_d2_*` (4); `tests/fixtures/items/` + 10 Phase-8-Items. Zugriff `Phase8Fixtures`, u. a. `p8_open(tree, day)` (setzt `village_open`, `name_in_village_complete`, `p8_open`, `p8_open_day`, liefert `NpcLife`), `kin_grave(kin, plot, buried_day)` → `{record, grave}` (reine Daten), `visit_now(kin, grave, phase, tree, day)`, `wish_open(grave, kind, tree, kin, state, day)`, `flowers(grave, state, tree)`, `apprentice_with(levels, lines, coins, tree)` → `{apprentice, box}`, `story_at(npc, step, tree, more)`, `fest_today(id, tree, day)` (setzt auch das Tages-Flag), `robber_night(grave, tree, day, encounters)`, `sick_light(path, offset, open_day)` → `{day, path, visits, burning}`, `install_save_v6`, `save_v6_path`, `layout_p7()`, `village_layout_p7()`, ID-Listen, `SAVEABLES`, `ORDER_NAMES`.
10. **Lücken, pragmatisch entschieden** (Besitzer dürfen in ihrem Paket glätten und melden es):
    - **Auftrags-Ids:** `of_<rosine|esch|mangold|lenz|fenner|quast|liesel>_<n>[_alt]` (Namensschema der Phase-7-Aufträge, passt zu `of_esch_return_1` in §5.1), Gegengefallen `of_<name>_return_<1|2>`; Flags `friend_<npc_id>_<n>` (§2.11 `friend_innkeeper_2`). `conditions`-Schlüssel (P4 liest): `task {action_id (apprentice_first_day, flowers_fresh, archive_help, lights_names, name_line, vigil, jakob_day_off), place, window, minute, minutes, count, kinless, mornings, until, gives, item}`, `meet {npc, place, window, times, minutes, gives_flag}`, `deliver` + `or_items` (Fenners `dropsy_powder`), `by_minute` (Quasts Kiste bis 07:40). Liesel 1 „Kaspar“ = `of_liesel_1` mit `requires_flag insight_not_lorenz`, sonst `of_liesel_1_alt` „Wiebke“ (`tend`). Fenners Gemeindeschlüssel = Flag `archive_key`. Orte ohne Vertragsangabe: Rosine 3 `apprentice_lunch`, Liesel 3 `v_dorn_door`. `thanks_text` sind Platzhalter.
    - **Neue Bedingungsschlüssel der Begegnungen** (§3.4 nennt sie nicht; P6 setzt sie in `DialogueConditions` um oder P1 prüft sie im `ChatterRunner`): `open_days_gte:<n>` (`ch_rumor_robber` ab `p8_open_day + 2`), `fest_eve:<id>`, `fest_after:<id>`.
    - **Nachtwege:** eine Minute < 06:00 gehört zur Nacht, die am Vorabend begann – Liesels Totenwache 02:40–05:30 hat `night_offset 4`, der Tod `death_offset 4`, 02:10 (§1.4: B6 02:10 = Nacht nach B5).
    - **Feste:** `effects`-Schlüssel sind Vorschläge (Kathrein `presence_minutes/presence_rel/dance_*`, Lichtgang `candles 12`, `check_minute 1080`, `lights_all {rep_event, rel_all, rel, goodwill, piety_event}`, `lights_some {rep_event, share}`, `early_ghosts`, Rede- und Verschiebungstext).
    - **Läden:** Esch `mortsafe` mit `requires_flag robber_known` und `price_after_flag {flag friend_smith_2, price 8}` (neue Eintrags-Schlüssel, P7 liest).
    - **D2:** `look 2` (= `ph_prop_corpse_03`, alter Mann), `section linden`, `requires_flag p8_open`, `due_flag ott_dead` (setzt NightPaths; StoryDirector liest, P6).
    - Texte der Stubs (`[E] Jakobs Kiste`, `[E] Im Schatten warten (bis ≈ %s)` …), Item-Beschreibungen, Launen-, Wunsch- und Gegengefallen-Texte außerhalb der Leittexte sind W0-Entwürfe – die Besitzer formulieren.
11. **Gemeinsame Dateien / Reihenfolge:** `ScheduleBuilder`/`Npc.set_runtime_schedule` (P1) und `GraveCare` (P2) zuerst (§12.2); bis dahin arbeiten P2/P3/P4/P7 gegen die `load_state`-Stubs oben. `cleanliness_manager.gd` nur P3 (inkl. `set_level` für P7), `grave_plot*.gd`/`graveyard.gd`/`ghost_*` nur P2, `orders*.gd` nur P4, `village.gd` nur P6 (`mourning_house_for`), `save_*`/`game_state.gd` nur P6, `data/items/*`/`data/shops/*` nur P7, `npc.gd`/`npc_lod.gd`/`relationships.gd` nur P1.
12. **Befund (Phase-7-Fehler, durch die Fixture sichtbar):** `Orders.turn_in` übergibt das Herz-Glas von `o_quast_specimen` mit `Specimens.consume(uid, inv, &"sold")`; `consume` nimmt nur `lectured`/`used`, der Rückfall `remove_uid` leert den Platz, der Record bleibt `held` → **jedes Laden des Anatomen-Stands warnt** „[Specimens] held specimen sp_0001 has no inventory slot“. `test_saves_v6_load.gd` führt die Warnung als bekannte Ausnahme `KNOWN_ORPHAN` (schlägt fehl, sobald sie verschwindet). **Behebung: P4** (`orders.gd`, z. B. Zustand `used` bzw. ein Verkaufsweg über `Specimens`; `specimens.gd` ist eingefroren) – danach die Ausnahme streichen; der Fixture-Stand bleibt (Laden muss ihn vertragen).
13. **Lead-Anpassungen an fremden Tests (mechanisch, nur Version / Feldzahl / Listenlänge / Fixture-Stand):** `test_phase3/4/5/6/7_scaffold.gd` (v7; „aktuell“ = `CURRENT`, „neuer“ = `CURRENT + 1`; Phase 6: `GhostMood.score` 8 Argumente; Phase 7: `OrderData.KINDS` erste sechs, 39 Record-Felder, `gains` in `DATA_CHANGED_AFTER_W0`), `test_save_migration.gd` (v7; `migrate(v6, CURRENT + 1)` abgelehnt), `test_saves_v4_load.gd`, `test_saves_v5_load.gd`, `test_save_fuzzer.gd`, `test_phase6_save_upgrade.gd` (Format 7 bzw. „aktuelles Format“), `test_corpse.gd` (39 Record-Felder), `test_graveyard.gd` (`to_dict` + `disturbed`, `extra_lines`), `test_piety.gd`/`test_reputation.gd` (Daten = Phase-8-Fixture).
14. **Testzahl:** vor W0 2 475, nach W0 **2 505** (+ `test_phase8_scaffold.gd` 22, `test_saves_v6_load.gd` 8), alle grün.

## W1-Anschlüsse (Lead, nach dem Merge aller W1-Pakete, 2786 Tests grün)
Offene Verbindungen, die W2 (W-Welt / W-UI / W-Ton) bzw. W3 schließen – Besitzer laut §3.2, sonst W-Welt:
1. **Welt-Builder (W-Welt):** Systemknoten anlegen: NpcLife, ChatterRunner, Apprentice, Visitors, GraveCare, Wanderers, NightRobber, NightPaths, Friendship, Festivals (+ TipStone als Kind von GravePlot, RainBarrel, ApprenticeBoard/-Box, WatchSpot, SickLight, FestDecor, Fiddler, MemorialPlate, ArchiveCabinet). Npcs: `npc_apprentice` (Friedhof) / `npc_apprentice_v` (Dorf, beide `npc_id apprentice`, ohne Daten-Zeitplan), `npc_kin_*`, `npc_robber`, Veit, Hanne. Jakob/Veit/Hanne vor `p8_open` verbergen.
2. **Wegpunkte (W-Welt):** Friedhof `gv_<plot>`, `road_end`, `gate_inside`/`gate_outside`/`gate_*`, `apprentice_board`, `apprentice_box`, `apprentice_lunch`, `apprentice_sweep`, `rain_barrel`, `robber_far`, `robber_fence_*`, `peddler_gate`; Dorf `v_in_inn_jakob`, `v_inn_door`, `v_bridge`, `v_road_in`, `v_<haus>_door`, `v_lights_gather` (P6 nutzt vorläufig `v_bridge`), Tanzplätze `v_in_inn_fest_1…3`; optional `world.visitor_route(plot)`.
3. **Lärm am Grab:** `Visitors.note_noise(pos, action_id)` kommt bisher nur von GravePlot. Fällen, Hacken, Hämmern, Sägen und Steinbruch (Player-TimedActions / ToolAnimConfig) anschließen.
4. **Namenstafel:** Rezept `memorial_plate` existiert, aber die Steinmetzbank hat keine Rezeptliste und `RecipeData.requires_flag` wird nirgends gelesen → herstellbar machen (Werkbank/Steinmetzbank-Panel liest `requires_flag`).
5. **Gießkanne des Totengräbers:** kein Mesh im Modell (Tri-Budget); beim Clip `water` `ph_tool_watering_can` per Code an Marker `can_grip` hängen.
6. **P4 ↔ andere:** `offerable_step` soll `NpcLife.offer_block_reason` (gereizt) beachten; Festivals ruft `NpcLife.note_event(&"lights_all")` und `(&"kathrein_danced", [Partner, innkeeper])`; NightRobber ruft `note_event(robber_reported|robber_let_go, npcs)`; Visitors ruft `note_event(&"wish_done", …)` und `(&"noise_at_grave", …)`; GraveCare bietet `wilt_flowers(grave)`/`tear_flowers(grave)` für Lehrlingsfehler; Liesels sichtbare Totenwäsche (`Friendship.wash_pending()`) zeigen; GhostManager-Frühfenster nach Laden neu setzen.
7. **DEFAULT_STATS:** `listens`, `chatters_seen`, `apprentice_days`, `apprentice_jobs`, `apprentice_mistakes`, `apprentice_wage` ergänzen (P6-Datei, Lead genehmigt W-UI/W3).
8. **Fuzzer (W3):** Prüfungen „disturbed nur auf belegten Gräbern“ und „kein Gitter auf EMPTY“ ergänzen, sobald Graveyard/GraveCare bereinigen.
9. **Hanne am Kathreintanz** fehlt (Zeitplan kann nicht zwei Tages-Flags prüfen) – W-Welt/P6-Lösung erlaubt (z. B. eigener Flag `kathrein_peddler`).
10. **Münzbilanz:** Start Phase 8 laut v6-Fixture 48 (neighbor) / 60 (anatomist); Ziel Ende ≈ +28 (Bogen). W3 misst, ggf. `tip_cap_day` senken.
11. **Aus W2 (W-UI/W-Ton) für W3:** Lenz-/Theres-Dialog sollen `open_panel:favor` statt `favor_use:<npc>` ohne Auswahl aufrufen (Panel fertig); `Apprentice.today_plan()` gibt im leeren Zweig untypisiertes `[]` zurück (typisieren); TipStone-Prompt „Zwei Münzen" statt „2 Münzen"; `Workbench` prüft `requires_flag` nicht serverseitig (nur UI); W-Ton erwartet Npc-Ids `apprentice`, `peddler`, `beggar`, `robber`, `priest` und Wegpunkte `robber_fence_in`/`_out`; optional `ToolAnimConfig.beat_cues` `water` für Gießen im Takt; W-Ton-Placeholder in QUALITY_GATE_STATUS nachtragen.
