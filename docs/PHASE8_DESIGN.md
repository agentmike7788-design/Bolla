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
