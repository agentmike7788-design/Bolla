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
| 55 (B3) | Lieferung 1 (Reihe 3). Esch besucht `old_01` → **Esch Schritt 1**. Jakob: vormachen „Jäten". **Hanne** am Friedhofstor (15:40): Grabblumen, Grabkerzen. Gerücht vom Nachtgräber (Begegnung Rosine–Osric). | 56 → 61 | „Hanne Vogelsang ist am Tor (bis 16:20)" |
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

Dann: Flag `who_comes_up_complete`, `chapter_completed(&"who_comes_up")`, Abschluss-Panel Variante `who_comes_up`. Es zeigt: Tage seit `p8_open`, Besuche (nach Angehörigen), Wünsche erfüllt / verfehlt, Trinkgeld gesamt, Jakobs Stufen je Aufgabe und seine erledigten Stellen, Fehler, Lohn gezahlt, Freundschafts-Schritte je Bewohner (drei Punkte), Gefallen genutzt / erwidert, Feste besucht, Lichter am Lichtgang („Kein Grab ohne Licht" ja/nein), Begegnungen mit dem Nachtgräber und sein Verbleib, beobachtete Nachtwege, Erkenntnisse der Phase. Schlusszeile nach Pietät-Stufe (5 Varianten, P6), Standard: „Früher kam nur Osric den Hügel herauf. Jetzt muss man am Tor manchmal warten, bis einer vorbei ist." Danach läuft das Spiel frei weiter. **Gate-Ziel:** Alle Bot-Strategien erreichen das Kapitel, auch der verwertende Weg (Lenz und Liesel höchstens „Bekannt") und ein Spieler ohne Grabgitter; **kein Fest ist Pflicht** (Kalender, §2.7), kein Präparat wird verlangt oder verboten, kein Grabräuber muss gestellt werden.

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
| Warten | 10 (nur mit Wunsch oder Trinkgeld) | bleibt am Grab stehen; kommt der Totengräber auf 4 m, dreht sie sich zu ihm („[E] Mit Martha Kehr reden") | `idle` / `talk` |
| Gehen | ≈ 12 | denselben Weg zurück | `walk` |
- Ein Besuch dauert 60–90 Spielminuten (30–45 s Echtzeit). Ein Gespräch ist in jeder Phase möglich; eine Kniende steht dafür erst auf.
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
- Präparate, die ins Grab zurückgelegt sind (Phase 7 „beisetzen"), zählen nicht. Wer seine Toten würdig hält, gewinnt am Tag 1–2 Ruf; wer sie verwahrlosen lässt, verliert so viel wie bei einem schlechten Grabzeichen.

#### 2.2.5 Wünsche & Trinkgeld
| Art (`WishData.kind`) | Bitte (Leittext) | Erfüllt beim nächsten Besuch, wenn … | Weg |
|---|---|---|---|
| `tend` | „Hältst du es sauber, bis ich wiederkomme?" | Pflegestelle des Grabs ≤ Stufe 1 | Pflege (Phase 3) oder Jakob |
| `flowers` | „Ein paar Blumen. Heide, wenn's geht, die hält den Winter." | frische Grabblumen auf dem Grab (§2.3) | Setzen + Gießen oder Jakob |
| `candle` | „Stell ihm einmal ein Licht hin. Er hatte Angst im Dunkeln." | seit dem Wunsch mindestens eine Nacht mit brennender Grabkerze | selbst oder Jakob |
| `line` | „Kannst du ‚Ruhe sanft' darunter setzen?" (Zeile aus `WishData.line_text`, 6 Vorlagen) | die Zeile steht auf dem Stein | „[E] Zeile nachmeißeln (30 Min, 1 Tinte)" am Grab; nur bei gestaltetem Stein mit < 4 Zeilen, sonst wird `line` nicht gewählt |
| `vase` | „Eine Vase, damit die Blumen nicht umfallen." | eine Grabvase (`deco_grave_vase`) ≤ 1,5 m vom Grab | Baumodus (Phase 3) |
- **Angebot:** im Gespräch mit einem wartenden Besucher (Wohlwollen ≥ 2). Gewählt wird die erste noch nicht erfüllte Art in der Reihenfolge [`tend` (nur wenn verwahrlost), `flowers`, `candle`, `line`, `vase`], mit dem Seed des Grabs gedreht. Höchstens **ein offener Wunsch je Grab**, **3 offene insgesamt** (`max_open 3`). Karte im Dialog mit „Das mache ich." / „Ich kann es nicht versprechen." (ohne Folgen). **Frist:** der nächste Besuch (3–7 Tage).
- **Lohn beim erfüllten Besuch:** Trinkgeld **1** (`tip_base`) **+1** bei Wohlwollen ≥ 6 **+1** bei Grabqualität ≥ 15 → **1–3 Münzen**, höchstens **4 Münzen am Tag** (`tip_cap_day 4`, darüber nur Dank); Ruf **+1** (`wish_done`); Wohlwollen +2; `stats.wishes_done`, `stats.tips_coins`. Bewohner zahlen kein Geld: **Beziehung +4** (`wish_done_villager`); Esch legt einmal 2 `iron_fittings` hin. **Nicht erfüllt:** Wohlwollen −2, der Wunsch verfällt (`stats.wishes_failed`), kein Ruf-Abzug.
- *Begründung Trinkgeld:* Im Bogen A kommen ≈ 9 erfüllte Wünsche zusammen, davon ≈ 8 mit Geld, zusammen **≈ 18 Münzen**: etwa 12 % der Einnahmen und weniger als das Pflegegeld (36). Die Tageskappe verhindert, dass ein Abend mit vielen Besuchern zur Kasse wird. Die eigentliche Belohnung ist der Ruf, der über Bezahlung und Pflegegeld weiterwirkt (Phase 3). Eine echte Preisdynamik bleibt Phase 10.

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
- Nach dem **dritten Almosen** an verschiedenen Tagen (oder Zuhören + zwei Almosen) erzählt er von den drei Nachtgängern → `c_n_veit` (§1.6). Ab `robber_known` weiß er auch: „Der Grell kommt von Westen, durch den Wald hinter dem Holunder. Er kommt, wenn die Erde frisch ist und kein Licht brennt." (Hinweis auf Kerzen, kein Hinweis-Objekt).
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
- **Ablauf (sichtbar):** 01:30 aus dem Wald westlich hinter dem Holunderwinkel (Wegpunkte `robber_far` → `robber_wall`), über die Westmauer, 01:50 am Grab; **gräbt** bis 05:00 (`dig_night`, Spaten in der Hand, gedämpftes Graben hörbar ≤ 25 m). Ungestört bis 05:00: er geht, das Grab ist **aufgewühlt** (§2.3), Ereignis `grave_disturbed`, Notiz am Morgen: „Am Grab von Hedwig Lamprecht ist die Erde aufgeworfen. Ein Spaten war hier, nicht deiner."
- **Begegnung:** Ist der Totengräber in der Friedhofs-Region **≤ 10 m** von ihm, während er gräbt, schreckt er auf (`startle`) und läuft (`run`) zur Westmauer und in den Wald. Das Grab ist nur angegraben (Pflegestelle +1 Stufe, nicht aufgewühlt). `robber_encounters` +1.
- **Zweite Begegnung:** Er stolpert über den Aushub und bleibt sitzen. Dialog `robber`:
  - „Wer zahlt dich?" → „Ein Herr mit einem Koffer. Er riecht nach Branntwein und zahlt für Frische. Er sagt, für die Wissenschaft. Mehr weiß ich nicht." → Hinweis `c_n_robber` (kein Teil von `i_underlined`; Haken Phase 9 „Wer kauft Frische?").
  - „Steh auf. Wir gehen zum Schultheiß." → `robber_reported`: Ruf **+3**, Fenner **+4**; Lambert ist fort (in der Stadt), am nächsten Tag dankt Fenner.
  - „Lauf. Und komm nicht wieder." → `robber_let_go`: Pietät **+2**, Liesel **+2**, Fenner **−2** (er hört es von Veit); Lambert ist fort. Später Veit: „Der Grell hat Arbeit in der Ziegelei. Er lässt grüßen. Nicht dich, aber er meint dich."
- **Nie gestellt:** Nach der **dritten** aufgewühlten Nacht fängt ihn Fenners Nachtwächter (`robber_caught_watch`, kein Ruf). Fenner: „Drei offene Gräber, Totengräber. Drei." Danach ist Ruhe.
- Er nimmt nichts, er kämpft nicht, er tut dem Totengräber nichts. Eine Leiche verlässt das Grab nie (§2.3). Er erscheint nicht am Lichtgang und in keiner Nacht mit Kerze an seinem Ziel.

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
**Ausgangslage (G7, `qa_playthrough.md`):** `neighbor7` endet mit **60** Münzen, `anatomist7` mit **71** (G7 Runde 2). Phase 8 bringt **wenig neue Einnahmen** (4 Bestattungen in der dritten Reihe, Trinkgeld, Verkäufe an Hanne) und **laufende, kleine Ausgaben** (Lehrling 3/Tag, Kerzen, Setzlinge, Almosen, Grabgitter). Ziel: Der Beutel wächst nicht schneller als in Phase 7 (dort +40 in 13 Tagen), und **Trinkgeld bleibt unter 15 % der Einnahmen**.

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
- *Prüfregel:* Ende ≤ Start + 50 bei allen Wegen, Morgen nie < 5, Trinkgeld ≤ 25 je Bogen. Liegt `kindly8` über Start + 50, senkt P2 zuerst `tip_cap_day` auf 3, danach P3 den Lohn nicht (er ist die Senke), sondern P2 die Hanne-Ankaufspreise um 1.

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
