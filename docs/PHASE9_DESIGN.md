# Phase 9 – Quests – Vertrag v1

Status: **v1 – verbindlich für die Umsetzung (§14 vom Benutzer am 17.10.2026 entschieden)** · Verantwortlich: Agent 01 (Lead), Agent 02 (Game Design), Agent 03 (World Design), Agent 06 (Character Art), Agent 07 (Animation), Agent 08 (Godot Core), Agent 12 (NPC/AI), Agent 13 (Quest/Story), Agent 14 (Crafting/Economy), Agent 17 (Audio), Agent 18 (UI/UX), Agent 19 (QA)
Baut auf `docs/PHASE8_DESIGN.md` (Vertrag v1, freigegeben 17.10.2026 nach Runde 6, inkl. „G8 Runde 6 – Bitten vom Hügel“), `docs/PHASE7_DESIGN.md`, `docs/PHASE6_DESIGN.md`, `docs/PHASE5_DESIGN.md`, `docs/PHASE4_DESIGN.md`, `docs/PHASE3_DESIGN.md` und `docs/VERTICAL_SLICE_DESIGN.md` auf. Was dieses Dokument nicht ändert, gilt dort unverändert weiter. Referenz-Build: **10e310e** (Gate G8 freigegeben, 3 016 Tests, Browser-Testversion v18). Der Lead trägt in den W0-Notizen den Hash ein, auf dem die v7-Fixtures entstehen (§5.3).
Gameplay-Werte sind **Vorschläge**; der Benutzer prüft sie beim Gate G9. ART STYLE LOCK „Gemaltes Diorama“ ist aktiv: Phase 9 ändert den Stil nicht. Maler-Shader (`painted.gdshader`, `painted_common.gdshaderinc`, `painted_foliage.gdshader`), Atmosphären-Presets, Flackerlicht, der gemeinsame Gesichtsaufbau (`tools/blender/lib_faces.py`) und das Rig (9 Knochen mit `tool`) bleiben unverändert und werden für die neue Figur **wiederverwendet**. Friedhof, Dorf, alle Gebäude und Innenräume bleiben bitgleich, **außer** den in §4.6 vollständig aufgezählten Eingriffen (vierte Reihe im Lindenacker, Krankenlicht-Fenster und Klopftür bei den Siebers, Stehplätze des Herrn mit dem Koffer, großer Bitt-Bogen an der Torafel und an der Gemeindetafel).

**Benutzerentscheidungen (verbindlich, 17.10.2026)**
- **Inhalt, alle vier Teile:**
  1. **Hauptkette „Wer weiß, wann?“:** Lorenz' zweite Kladde endet mit einer Liste von Daten. Zu jedem Datum gehört ein Toter auf dem Hügel und ein Fenster mit einem Licht, das jemand gesehen hat. Anschluss an Phase 8: `i_underlined` „Der unterstrichene Name“, die Seelfrau Liesel Dorn, Quast, Lenz, Gerhard Ott/D2, das Krankenlicht (PHASE8 §1.6).
  2. **Briefe und Botengänge:** Briefe in den Taschen der Toten, die man zustellen, vorlesen oder verbrennen kann; Botengänge zwischen Friedhof und Dorf mit kleinen Entscheidungen.
  3. **Der Herr mit dem Koffer:** eine neue Figur aus der Stadt, die seltsame Fragen stellt und Dinge kaufen will; eine eigene Kette mit moralischen Entscheidungen (in Phase 8 nur erwähnt: Lamberts Auftraggeber, PHASE8 §2.6.3, §13).
  4. **Größere Bitten:** mehrteilige Bitten am Tor und im Dorf, die einen halben Nachmittag füllen. Aufbau auf „Bitten vom Hügel“ (G8 Runde 6: `HillRequests`, `data/hill_requests/`, `OrderData` mit `category hill`). Die Bot-Messung dort zeigte nur **−12 % Leerlauf an Tag 2–12**; das soll deutlich besser werden (Ziel §2.3.6).
- **Umfang: mittel**, etwa wie Phase 8: **eine Hauptkette mit 6 Schritten**, **zwei Nebenketten** („Briefe ohne Antwort“, „Der Herr mit dem Koffer“) und ein **Quest-Überblick im Merkbuch** („Vorhaben“). Weil alle vier Inhalte gewählt sind, ist sauber priorisiert (A = Pflicht fürs Gate, B = geplant, C = gestrichen; §12.4 mit Begründung und Streichreihenfolge).
- **Entscheidungen haben spürbare Folgen:** Beziehungen, Ruf, Pietät („Frömmigkeit“), Texte der Dorfbewohner und spätere Quests; die Hauptkette hat **drei Enden** (§2.2.7) und eine stille Rückfallvariante.
- **Ton** (GDD): melancholisch, warm, trockener Humor, übernatürliche Geheimnisse; „Tod ist Handwerk, nicht Horror“. Nur eigene Inhalte.
- **Angeln bleibt Phase 11.** ART STYLE LOCK „Gemaltes Diorama“ gilt.

**Lehren aus G8 (verbindlich für alle Pakete)**
- **Sichtbare, würdige Abläufe.** Keine Abblende und kein Teleport als Ersatz für eine Handlung. Wer geht, geht sichtbar den Weg (Johann mit Hanne den Waldweg hinauf, der Herr mit dem Koffer über die Holderbrücke). Erlaubt bleiben nur die G7/G8-Übergänge (Portale, Warten vor einem Ereignis).
- **Eigene Bewegung je Handgriff** (G8 Runde 3/4): Brief lesen, schreiben, verbrennen, vorlesen am Grab, Kladde vergleichen, Erde nehmen – jeder Handgriff hat seinen Clip und sein Requisit am Marker `tool_hand`/`tool` (§8.2). Dorfbewohner unterbrechen ihre Arbeit und wenden sich zu (G8 Runde 4).
- **Fenster angedockt** (G8 Runde 4/5): alle neuen Panels rechts unter der HUD-Leiste (`UIPanel.dock_right`, `UIRoot.dock_top`), ohne Abdunklung, während einer daraus gestarteten Arbeit ausgeblendet; Maus und Tastatur.
- **Hören, was passiert** (G8 Runde 3): Ereignisse am Tor melden sich mit Ton und HUD-Zeile (Torglocke, „Osric hat eine Bitte ans Tor geheftet.“). Neu: der Herr mit dem Koffer läutet die Torglocke einmal kurz (§2.5.2).
- **Browser-Export:** Text-Ressourcen bleiben Text (`export/convert_text_resources_to_binary=false`, G8 Runde 3). Neue Daten nutzen dieselben Muster (keine Ströme außer Musik, Einzelklänge WAV/QOA, Leistungsbudget §9). Jede Welle prüft den Ablauf **auch im exportierten pck** (Compatibility).
- **Deterministisch:** Keine globale Zufallszahl; alle Auswahlen über `hash([Tag, …])`. Bestehende Bots (Phase 3–8 und `HillBot`) nehmen keine Phase-9-Inhalte an und laufen **bitgleich**.

**Regeln für alle Agents** (wie Phase 3–8)
- Klassen, Signaturen, Dateipfade, Signale und Datenformate hier sind **fest**. Änderungen nur über den Lead.
- Der Lead legt in **Welle 0** alle Datenklassen (✦) vollständig und alle Logikklassen als **Stubs mit exakten Signaturen** an. Die Besitzer füllen die Körper und benennen nichts um.
- Nach jedem neuen Worktree und nach jedem Merge: `godot --headless --path . --import`.
- Jede Datei hat genau einen Besitzer (§3.2). Fremde Dateien nicht ändern; Bedarf an den Lead melden.
- Alle neuen Assets tragen `ph_` und kommen in die Placeholder-Liste (`docs/QUALITY_GATE_STATUS.md`).
- Keine Mechaniken, Namen oder Texte anderer Spiele übernehmen. Ausdrücklich **nicht**: Ausrufe- oder Fragezeichen über Köpfen, Questmarker-Pfeile, Kompass mit Zielpunkten; Erfahrungspunkte, Stufen, Belohnungs-Auswahlbildschirme mit Beute; Moral-Leisten, Gut/Böse-Farben an Dialogzeilen, angekündigte Folgen in Zahlen („+5 Ruf“) vor der Wahl; Fraktions-Ruf als eigene Währung; Tagesquests mit Sofortbelohnung (die Bitten bleiben „Gemeinde-Bitten mit Frist und Abklingzeit“, PHASE8 Runde 6); Brieftauben, Briefkasten-Minispiele, Siegel-Rätsel; ein Händler, dessen Angebot sich durch Neuladen ändert; Leichenhandel als Mechanik.
- **Eigene Identität dieser Phase: „Wer weiß, wann?“** In Phase 7 ging der Totengräber zu den Lebenden hinunter, in Phase 8 kamen sie herauf. Jetzt fängt er an, Fragen zu stellen, die man in Hollerbrück nicht stellt: Wer hat das Licht angezündet? Für wen ist dieser Brief? Was hat der Herr in seinem Koffer? Ein Totengräber weiß, **dass** jeder kommt. Phase 9 handelt davon, dass einer im Dorf weiß, **wann**.
- Sprache: alle Spieltexte eigenständig auf Deutsch, trocken-melancholisch und würdig. Briefe klingen wie Menschen von 1834, die selten schreiben: kurz, unbeholfen, ehrlich. Der Herr mit dem Koffer spricht höflich, genau und ein wenig zu freundlich; Johann Sieber redet langsam und hat es nicht eilig. Keine Schauerprosa über das Zeichen, kein Spott über Sterbende.

---

## 1. Spielablauf & Progression

### 1.1 Erweiterter Kern-Loop
```
AB TAG 2 (jedes Spiel, unabhängig von Phase 9): GRÖSSERE BITTEN an der Torafel (ab village_open auch an der Gemeindetafel)
  └ eine große Bitte = 2–4 Teile (säubern, Zier, Werkbank, Holz, Untersuchen, Herrichten, Stein, Geist, Roden, Gänge) ≈ 150–240 Spielminuten
  └ Teil für Teil im HUD („Bitte: Die Gräber der Fähre – 2/3: Zwei Zierstücke im Alten Hof“), Lohn klein, Frist 2–3 Tage

Freischaltung (Kapitel „Wer heraufkommt“) → Osric p9_intro: „Der Pfarrer fragt, ob du das Heft vom Aschau noch hast.“
  → HAUPTKETTE „Wer weiß, wann?“ (6 Schritte, §2.2)
       H1 Die Rückseite (Kladde an der Hütte lesen: sechs Daten, je ein Buchstabe)
       H2 Wer liegt unter dem Datum? (Grabregister vergleichen, an fünf Gräbern das Datum prüfen → immer drei Wochen)
       H3 Wer hat das Licht gesehen? (Zeugen: Liesel, Osric, Rosine, Theres, Gesa Ott → Erkenntnis „Das Licht vorher“)
       H4 „S.“ (unter dem letzten Datum liegt noch keiner – Veit, die Siebers, Johann zeigt das Zeichen)
       H5 Wem sagst du es? (Lenz · Quast · Liesel · niemandem)
       H6 Was wird aus Johann? → ENDE A „Über den Hügel“ · B „Bei Grete“ · C „Vor der Gemeinde“ (· still: „Geschwiegen“)
  → NEBENKETTE „Briefe ohne Antwort“ (§2.4): Briefe in den Taschen der Toten · Post für die Toten · Botengänge
       └ je Brief: ZUSTELLEN · VORLESEN · VERBRENNEN (· ins Grab legen) → Beziehung, Pietät, Ruf, Geister, Texte
  → NEBENKETTE „Der Herr mit dem Koffer“ (§2.5): Cornelius Brenneisen, Kommissionär aus der Stadt
       └ Fragen am Tor · was er kaufen will · wer zahlt für Frische · der Koffer · was er mitnimmt (Fenner · Handel · Ilse)
  → VIERTE REIHE im Lindenacker (Fenner) → neue Tote, neue Briefe, Platz für D3
  → MERKBUCH „Vorhaben“: alle Ketten, Bitten, Aufträge, Freundschaft, Schulden an einem Ort; eins „verfolgen“ → HUD
```
Alle Handgriffe aus Phase 2–8 bleiben **unverändert**. Wer keine Kette anfängt, spielt weiter wie bisher; er verpasst nur Texte, Folgen und das Kapitel. Die Größeren Bitten sind freiwillig wie die kleinen.

### 1.2 Freischaltung
- **Größere Bitten:** in **jedem** Spiel ab **Tag 2** an der Torafel, ab `village_open` zusätzlich an der Gemeindetafel (Linde, Hollerbrück). Laufende v7-Stände bekommen am nächsten Morgen um 07:44 ihre erste große Bitte (Bestätigung §14.2). Sie hängen **nicht** an `p9_open`, weil das Leerlauf-Loch an Tag 2–12 liegt (PHASE8 Runde 6).
- **Ketten (Hauptkette, Briefe, Koffer), vierte Reihe, Briefe in Taschen:** öffnen mit dem Phase-8-Kapitel `who_comes_up_complete`. Am ersten Morgen danach (erste Minute ≥ 06:00, idempotent) setzt `Quests.apply_morning` das Flag `p9_open` und speichert den Tag in `p9_open_day`.
- **Migrierte Stände (v7):** Ist `who_comes_up_complete` gesetzt, setzt `Quests.post_load` `p9_open` sofort (auch nach 06:00). Bei einem v8-Stand gilt die Morgenregel (Speichern → Laden bitgleich, wie Phase 6–8).
- **Vor `p9_open`:** keine Ketten, kein Herr mit dem Koffer, keine Phase-9-Briefe (Taschenfunde bleiben der Phase-4-Fund `f_letter` mit `c_warning_letter`), keine vierte Reihe. Der Merkbuch-Reiter „Vorhaben“ erscheint schon mit der ersten großen Bitte (ohne Ketten-Gruppen).
- Osric `p9_intro` (Leittext, P6 darf glätten): „Der Pfarrer hat gefragt, ob du das Heft vom Aschau noch hast. Ich hab gesagt, ich frag nicht nach Heften. Und Fenner sagt, es gibt noch eine Reihe am Lindenacker. Die letzte, sagt er. Das hat er bei der dritten auch gesagt.“ Danach als Menüpunkt „Wer liest eigentlich die Post für die Toten?“ (§2.4.3).

### 1.3 Zeitkosten (Spielminuten; TimedAction wie bisher, 0,5 s Echtzeit je Spielminute auf der Uhr)
| Handlung | Min | Braucht | Abbrechbar |
|---|---|---|---|
| Lorenz' Kladde lesen (Hütte, Schreibpult `Desk`) | 20 | `lorenz_ledger_2` im Inventar oder in einer Truhe | ja |
| Grabregister mit der Liste vergleichen (Hütte, `Desk`) | 30 | H1 erledigt | ja |
| Datum am Grab vergleichen | 5 je Grab | H2 offen, Grab eines Listen-Toten | – |
| Zeugen fragen, bei den Siebers anklopfen, Johann sprechen | 0 (Dialog modal) | – | – |
| Brief ohne Namen schreiben (Ende A, Lorenz' Weg) | 20 | 1 `ink`, Hütte `Desk` | ja |
| Am Abend bei Johann sitzen (Ende B) | 30 je Abend | Bank vor dem Sieber-Haus, 18:00–20:00 | nein |
| Brief lesen (Merkbuch / Brief-Karte) | 0 | Brief im Inventar | – |
| Brief am Grab vorlesen | 10 | Brief (Tasche oder Post) des Toten / an den Toten | ja |
| Antwort schreiben | 20 | 1 `ink`, Hütte `Desk` | ja |
| Brief verbrennen (Hüttenofen, Esse) | 2 | – | – |
| Brief mit ins Grab legen | 2 | beim Bestatten des Absenders (Prompt am offenen Grab) | – |
| Post aufgeben (Hanne am Tor/Brunnen, Osric am Karren) | 0 | 1 Münze Postgeld (`post`) | – |
| Eine Handvoll Erde nehmen (Herr mit dem Koffer, K2) | 2 | frisches Grab ≤ 5 Tage, Angebot offen | – |
| Den Koffer tragen (K4) | Weg | Koffer im Inventar (1 Platz, kein Schuppen) | – |
| Vierte Reihe roden (Stumpf, Brombeere) | 30 + 40 | Axt-Faktor Phase 5 | ja |
| Teile einer großen Bitte | Zeit der jeweiligen Handlung (Phase 2–8) | – | wie die Handlung |

*Begründung:* Die Ketten kosten kaum eigene Zeit, sie schicken den Spieler an Orte und zu Menschen. Die Zeit füllen die **Größeren Bitten** (§2.3) und die Wege zwischen Friedhof und Dorf (30 Min je Richtung, Phase 7).

### 1.4 Tagesbogen
**A) Referenz: Phase-8-Endstand (`kindly8`, v7-Fixture `slot_p8_day63_kindly`, Tag 63 = 4. Julmond 1834, 07:00; gemessen Kapitel B10 an Tag 62, ≈ 70 Münzen, Jakob „Geübt“, Lindenacker voll).** Der Bogen dauert **12 Tage** (B1 = Tag 63 … B12 = Tag 74), das Kapitel fällt an **B10–B11**. Richtwert Mensch; der Bot `kindly9` spielt ihn nach (§10). Daten im Bogen A: **Licht bei den Siebers** am 22. Nebelung (Tag 51 = `p9_open_day − 12`), Johanns Tod am 13. Julmond (Tag 72 = Licht + 21, Luciatag), Hanne-Tage 67 und 73, der Herr mit dem Koffer an Tag 65–67 und 70–72.

| Tag (Bogen) | Geschehen | Münzen früh → abends (§2.8) | Zielzeile (Beispiel) |
|---|---|---|---|
| 63 (B1) | Osric `p9_intro`. **H1** in der Hütte: Kladde lesen → „Die Liste“ im Merkbuch. Fenner gibt die **vierte Reihe** (`l_13…l_16`). Große Bitte „Die Gräber der Fähre“ am Tor. | 70 → 74 | „Sprich mit Osric“ → „Lies Lorenz' Kladde (Hütte)“ |
| 64 (B2) | **H2:** Register vergleichen (vier Namen), an fünf Gräbern das Datum prüfen → „Immer drei Wochen“. Reihe 4 roden. Große Bitte Teil 1–2. | 78 → 72 | „Die Liste: 3/5 Gräber verglichen“ |
| 65 (B3) | Lieferung 1 (Reihe 4) mit **Brief L1** in der Tasche → Briefe S1. **H3:** Osric (Quendel). **Der Herr mit dem Koffer** läutet am Tor (14:10) → **K1**. Große Bitte erfüllt. | 76 → 90 | „Ein Herr wartet am Tor“ |
| 66 (B4) | Post für die Toten (Osric): Brief an Marthe Quendel → am Grab vorlesen (S2). **H3:** Rosine (Wernstein), Theres (Hagedorn) → mit Osric drei Zeugen → Erkenntnis **„Das Licht vorher“**. **H4** am Abend: Veit an der Brunnenbank → „Bei den Siebers.“ → anklopfen (Anna). **K2:** Erde / Registerabschrift. Gesa Ott am Grab ihres Vaters: Botengang E1. Lieferung 2 (Brief L2). | 94 → 90 | „Wer ist ‚S.‘?“ |
| 67 (B5) | Johann an Gretes Grab (10:00) zeigt das Zeichen → **H4** erledigt. **H5:** Liesel. Hanne-Tag: Gesas Brief mit Hanne in die Stadt (E1 → L3). Lieferung 3 (Brief L3). Abends an der Hütte den **Brief ohne Namen** schreiben, 21:00 an die Tür der Siebers stecken. | 90 → 96 | „Was wird aus Johann? (bis morgen Abend)“ |
| 68 (B6) | **H6** an Gretes Grab: **Ende A** (Frist heute). Keine Lieferung (die vierte Stelle ist zurückgehalten). An der Hütte die **Antwort** an die Schwester aus L2 schreiben (S4). Große Bitte 2 (Dorf). | 96 → 93 | „Bitte: Steine für die Holderbrücke“ |
| 69 (B7) | 10:00 Johann hinten auf **Osrics Karren** nach Ellbach (Hanne kommt erst an Tag 73, nach der Frist). Morgennotiz „An der Hüttentür steckt ein Zettel“ (die schräge Hand antwortet). Antwort mit Osric aufgegeben → **L4**. Botengang „Fenners Siegel“ (E2). | 93 → 95 | „Briefe ohne Antwort: 4/5“ |
| 70 (B8) | Der Herr mit dem Koffer kommt wieder → **K3** (Veit: „Der war schon bei Lorenz.“). (B/C: Krankenlicht bei den Siebers, Quast 22:30.) | 95 → 92 | „Wer zahlt für Frische?“ |
| 71 (B9) | **K4:** Rosine gibt dir den vergessenen Koffer → zum Tor tragen (hineinsehen?). (B/C: Lenz' Versehgang 21:00.) | 92 → 97 | „Den Koffer zum Tor bringen“ |
| 72 (B10) | (B/C: Johann stirbt 02:10, Liesel 02:40.) **K5:** Fenner, Handel oder Ilse. Ende A: **Kapitel „Wer weiß, wann?“** | 97 → 95 | „Wer weiß, wann? 3/3“ |
| 73 (B11) | (B/C: **D3 Johann Sieber** kommt, Bestattung neben Grete, so nah es geht → Kapitel.) Hanne: Brief „An L. Aschau“ (S5, Prio B). | 95 → 104 | „Johann Sieber – bestatten“ |
| 74 (B12) | Freies Spiel. Reaktionen im Dorf auf das gewählte Ende (§2.2.8). | 104 → 101 | „Die Gemeindetafel hat eine große Bitte“ |

Im Bogen A fällt Hannes Tag (67) vor die Entscheidung, deshalb fährt Johann mit Osric; liegt Hannes Tag zwischen Entscheidung und Licht + 18, geht er mit ihr den Waldweg hinauf (Bild p9_09, Test §10).

**B) Neues Spiel:** `who_comes_up` fällt je nach Spielweise an Tag 55–70 (G8: `founder8` Tag 63). Der Bogen läuft danach wie A; alle Daten der Kette sind relativ zu `p9_open_day` (Licht = `p9_open_day − 12`, §2.2.2), deshalb passt jede Öffnung. Hanne und der Herr mit dem Koffer kommen nach ihrem eigenen Takt (§2.5.2); fällt Hannes Tag nicht vor die Entscheidungsfrist, nimmt Osric Johann mit (§2.2.7). Die Größeren Bitten laufen in jedem neuen Spiel ab Tag 2 (§2.3).

### 1.5 Phasenziel – Kapitel „Wer weiß, wann?“ (`who_knows_when`)
Erfüllt, sobald **alle** gelten (geprüft von `Quests.check_goal` bei `quest_changed`, `letter_changed`, `hill_request_changed`):
1. Die **Hauptkette** `q_who_knows` ist mit einem Ende **abgeschlossen** (A, B, C oder still; §2.2.7) – Ende A, sobald Johann fort ist (`sieber_gone`); B, C und still, sobald D3 Johann Sieber bestattet ist (Grabzeichen).
2. Die Nebenkette **„Briefe ohne Antwort“** ist bis **Schritt 4** erledigt, und mindestens **5 Briefe** sind entschieden (zugestellt, vorgelesen, beantwortet, verbrannt oder ins Grab gelegt; §2.4).
3. Mindestens **2 Größere Bitten** sind **seit `p9_open`** erfüllt (§2.3).

Der Herr mit dem Koffer ist **nicht** Pflicht (Priorität B). Dann: Flag `who_knows_when_complete`, `chapter_completed(&"who_knows_when")`, Abschluss-Panel Variante `who_knows_when`. Es zeigt: Tage seit `p9_open`, das Ende der Hauptkette mit einem Satz, wem du es gesagt hast, die Liste mit allen sechs Einträgen (Datum · Name · Zeuge), Briefe nach Entscheidung (zugestellt / vorgelesen / beantwortet / verbrannt / ins Grab), Botengänge, Größere Bitten (erfüllt / halb / versäumt, Teile gesamt), der Herr mit dem Koffer (was er bekam, wie er ging), Erkenntnisse der Phase. Schlusszeile je Ende (4 Varianten, P6), Standard (Ende B): „Johann hat sich nicht beeilt. Du hast ihm die Erde so tief gemacht, wie man es kann. Wann der Nächste kommt, steht in keinem Heft, das du hast.“ Danach läuft das Spiel frei weiter. **Gate-Ziel:** Alle Bot-Strategien außer `lazy9` erreichen das Kapitel, auch der stille Weg und der verwertende Weg; kein Ende ist „richtig“, und keines sperrt das Kapitel.

### 1.6 Das Geheimnis – Phase-9-Ausschnitt „Wer weiß, wann?“
**Leitplanke (Autorenwissen, Phase 18 entscheidet endgültig):** Der Gesamtbogen aus PHASE4 §1.4 bleibt. Lorenz lebt unter dem Birkenhang und schreibt weiter (`i_still_writing`). Wer zeichnet, bleibt offen (Phase 13–18). Phase 9 klärt **eine Regel** des Zeichens, nicht seinen Urheber: **In der Nacht, in der einer gezeichnet wird, brennt in seinem Haus ein Licht, das keiner aus dem Haus angezündet hat. Drei Wochen später stirbt er.** Wer das Licht sieht, weiß, wann. Lorenz hat die Lichter gezählt; die letzten Einträge stehen in frischerer Tinte als die ersten (er schreibt nach seinem Verschwinden weiter – Haken Phase 12). Phase 9 zeigt **nicht**, wer das Licht anzündet, und keiner der drei Verdächtigen (Lenz, Quast, Liesel) kommt in der Nacht des Lichts. Der Herr mit dem Koffer **zeichnet nicht**; er weiß nur, dass die Gezeichneten „etwas haben, das die Stadt sehen will“ (§2.5).
- `StoryConfig.underlined` (Phase 8: `washer`) färbt nur Zeilen (Liesel als Zeugin ihres eigenen Hauses, §2.2.4); die Regel ist für alle drei Varianten gleich.
- **Belohnung wie Phase 4/7/8:** Text, Flag, Zeile im Abschluss-Panel, keine Münzen.
- **Nächster Erzählschritt (Phase 12, benannt): „Unter dem Birkenhang ist es nicht still.“** Wer Lorenz' Brief (§2.4.5) ungeöffnet aufhebt oder die Kladde nicht verkauft, hat dort etwas in der Hand.

---

## 2. Spielwerte (Vorschläge, alle in `data/`)

### 2.1 Quest-Kern & Merkbuch „Vorhaben“ (`data/config/quest_config.tres` – `QuestConfig`, `data/quests/<id>.tres` – `QuestData`)
**Entscheidung: ein schlanker Ketten-Kern über den bestehenden Systemen, keine zweite Auftragswelt.** Eine Kette (`QuestData`) ist eine geordnete Liste von Schritten (`QuestStepData`). Ein Schritt ist erledigt, wenn ein **schon vorhandenes** Ereignis eintritt: ein Flag, ein Hinweis, eine Erkenntnis, ein Auftrag der Kategorie `quest` (Phase-7-`Orders` mit allen Arten `deliver`, `bury`, `stone`, `tend`, `meet`, `task` …), eine Notiz aus einem Prompt (`Quests.note(key, arg)`), eine Wahl oder ein Ende. Wahlen und ihre Folgen sind **Dialog-Aktionen** in der bestehenden Syntax (`DialogueActions`), damit ein Ende genau so geschrieben wird wie jede andere Zeile. *Begründung:* Phase 7 und 8 haben Aufträge, Freundschafts-Schritte, Gefallen, Wünsche und Bitten gebaut; was fehlt, ist der Faden, der sie zu einer Geschichte mit Folgen verbindet, und ein Ort, an dem der Spieler alles sieht. Eine eigene Quest-Engine mit eigenen Zielen würde jede dieser Mechaniken doppeln.

**Regeln**
- **Ketten:** `q_who_knows` (Hauptkette, 6 Schritte, §2.2), `q_letters` (Nebenkette, 5 Schritte, §2.4), `q_case` (Nebenkette, 5 Schritte, §2.5). Öffnen mit `open_conditions` (Dialog-Syntax, z. B. `p9_open`).
- **Schrittfolge:** streng nacheinander; ein Schritt wird erst „sichtbar“ (Merkbuch, HUD), wenn der vorige erledigt ist. Ereignisse, die vorher eintreten, zählen trotzdem (Zeugen, die man zufällig schon gefragt hat; Briefe, die schon entschieden sind) – ein Schritt prüft beim Sichtbarwerden sofort.
- **Wahlen:** ein Wahl-Schritt hat 2–4 `QuestChoiceData`; die Wahl fällt in einem Dialog (`quest_choose:<quest>:<step>:<choice>`) oder an einem Prompt. Gewählt ist gewählt (kein Zurück). Die Folgen werden **nie vorher als Zahl** gezeigt.
- **Fristen:** ein Schritt kann eine Frist haben (`deadline_flag` + `deadline_offset`, geprüft um 06:00 wie Aufträge); verstreicht sie, gilt `fallback_choice` (Hauptkette: still, §2.2.7).
- **Aufträge der Kategorie `quest`** (✦ `OrderData.CATEGORY_QUEST`): Botengänge und Ketten-Aufgaben. Sie zählen **nicht** für „6 Aufträge von 4 Gebern“, nicht für `stats.orders_done` und nicht gegen die 4 normalen bzw. 2 Freundschafts-Aufträge; eigene Grenze `OrdersConfig.max_active_quest 3`.
- **Kein Lohn in Münzen** für Ketten-Schritte (außer kleinen Botenlöhnen, §2.4.4); der Lohn sind Folgen, Texte, Beziehung, Ruf und Pietät.

**Merkbuch „Vorhaben“** (neuer Reiter, Leser `QuestLog`, §7.1): eine Liste in Gruppen – **Hauptkette**, **Nebenketten**, **Große Bitten**, **Bitten** (Runde 6), **Aufträge** (Phase 7), **Freundschaft** (Phase 8), **Was du schuldest** (Gegengefallen). Je Eintrag: Titel, Geber, aktueller Schritt als Satz, Frist („noch 2 Tage“), bei Ketten die erledigten Schritte als Sätze („Du hast es Liesel gesagt.“) und der nächste als Andeutung; zukünftige Schritte bleiben verborgen („…“). Knopf **„Verfolgen“** heftet genau einen Eintrag an die HUD-Zielzeile (`QuestConfig.max_pinned 1`, gespeichert). Der Reiter „Bitten“ (Runde 6) bleibt als Verlauf; „Aufträge“ bleibt. *Begründung:* Seit Phase 8 laufen bis zu sechs Arten von Vorhaben nebeneinander; der Spieler fragt „Was wollte ich heute noch?“, nicht „Welches System war das?“.

### 2.2 Hauptkette „Wer weiß, wann?“ (`data/quests/q_who_knows.tres`, `data/quests/who_knows/list.tres` – `LightListData`, System `WhoKnows`)

#### 2.2.1 Die Rückseite der Kladde
Die Seite mit den drei Namen (Phase 8, `c_n_kladde`) hat eine Rückseite, die man im Pfarrarchiv übersehen hat. Darauf, in Lorenz' Hand, **sechs Einträge**: ein Datum und ein Buchstabe, sonst nichts. Die ersten Einträge sind in brauner, alter Tinte, die späteren in schwarzer, frischer („als wäre sie nach seinem Verschwinden geschrieben“). Darunter: „Licht. Drei Wochen.“ – und durchgestrichen: „Wer weiß, wann?“

| Eintrag (`LightEntryData.id`) | Buchstabe | Datum | Tinte | Toter auf dem Hügel | Zeuge des Lichts | Hinweis |
|---|---|---|---|---|---|---|
| `e_dorn` | D. | **2. Julmond 1833** (fest) | alt | S5 „Lorenz Aschau (?)“ = Kaspar Dorn (Holunderwinkel) | **Liesel Dorn** (ihr eigenes Haus) | `c_q_light_dorn` |
| `e_quendel` | Q. | Tod von S1 − 21 Tage | frisch | S1 Marthe Quendel | **Osric** (fährt nachts vorbei) | `c_q_light_quendel` |
| `e_wernstein` | W. | Tod von S3 − 21 | frisch | S3 Ida Wernstein | **Rosine** (Ida schenkte bei ihr aus) | `c_q_light_wernstein` |
| `e_hagedorn` | H. | Tod von D1 − 21 | frisch | D1 Wiebke Hagedorn | **Theres** (sah es vom Laden aus) | `c_q_light_hagedorn` |
| `e_ott` | O. | Tod von D2 − 21 | frisch | D2 Gerhard Ott | **Gesa Ott** | `c_q_light_ott` |
| `e_open` | S. | **`p9_open_day − 12`** | frisch, kaum trocken | – „Unter diesem Datum liegt noch keiner.“ | **Veit Ammer** (Brunnenbank), Anna Sieber (hinter der Tür) | `c_q_sieber` |
- **Daten** rechnet `LightRules.light_day` aus den gespeicherten Records: Todestag = Ankunftstag − 1 (gestorben in der Nacht vor der Lieferung, Phase 2), D2 aus `night_paths.deaths.np_ott`; Text über `StoneCalendar.date_text` (Monatsnamen Hartung … Julmond). Damit passen die Daten in jedem Spielstand zu den Toten, die **dieser** Spieler begraben hat. Fehlt ein Toter (nie geliefert, nicht auf dem Hügel), zeigt der Eintrag ein Ersatzdatum (`StoryCorpseData.earliest_day − 22`) und den Buchstaben und gilt in H2 über Lenz' Sterbebuch als zugeordnet (Text „Im Sterbebuch steht er. Bei dir liegt er nicht.“).
- **Warum S1, S3, S5, D1, D2:** genau die Geschichts-Toten mit dem Zeichen (`strange_wound`). Zufällig gezeichnete Lieferungen bekommen **keinen** Eintrag (§13, gestrichen).
- **Warum `p9_open_day − 12`:** Der offene Eintrag ist zwölf Tage alt, wenn die Kette beginnt; Johanns Tod (Licht + 21) fällt auf `p9_open_day + 9`. Das ist im Bogen (B10) und lässt dem Spieler 5–6 Tage für H2–H6. *Begründung:* Ein fester Kalendertag würde bei später Öffnung (neues Spiel, B) schon verstrichen sein.

#### 2.2.2 Feste Zeitpunkte der Kette (alle aus `q_light_day` = `p9_open_day − 12`, `data/config/who_knows_config.tres` – `WhoKnowsConfig`)
| Wert | Rechnung | Bogen A |
|---|---|---|
| Licht bei den Siebers | `p9_open_day − 12` (`open_light_offset −12`) | Tag 51 (22. Nebelung) |
| Entscheidungsfrist H6 | Licht + 17 (`decide_offset 17`), 23:59 | Tag 68 (B6) |
| Krankenlicht `np_sieber` (nur Ende B/C) | Licht + 19 (Quast 22:30–23:10) · Licht + 20 (Lenz 21:00–21:40) | Tag 70 · 71 |
| Johanns Tod (nur B/C) | Licht + 21, 02:10 (`death_offset 21`); Liesel 02:40–05:30 | Tag 72 (13. Julmond) |
| D3 Johann Sieber geliefert | Todestag + 1, 07:40 | Tag 73 (B11) |

#### 2.2.3 Die sechs Schritte
| Schritt | Titel | Wie (alles sichtbar, Handlungen mit Clip §8.2) | Erledigt durch | Lohn / Folge |
|---|---|---|---|---|
| **H1** | „Die Rückseite“ | An der Hütte „[E] Lorenz' Kladde lesen (20 Min)“ (`Desk`, Clip `read_book`); die Liste öffnet sich im Merkbuch als eigene Seite „Die Liste“. Fehlt die Kladde (in keiner Truhe), gibt Lenz sie zurück: „Sie lag im Archiv. Sie haben sie liegen lassen. Ich nicht.“ | Notiz `kladde_read` → Hinweis `c_q_dates` | – |
| **H2** | „Wer liegt unter dem Datum?“ | (a) „[E] Grabregister mit der Liste vergleichen (30 Min)“ an der Hütte: für jeden Eintrag mit Record steht der Name daneben („Q. → Marthe Quendel, gestorben 21 Tage später“). (b) An jedem der fünf Gräber „[E] Datum vergleichen (5 Min)“ (Clip `kneel_read`, Kladde am `tool_hand`). Kaspars Eintrag: der Tote aus dem Moor; mit `i_not_lorenz` steht „Kaspar Dorn“ da, sonst „der Tote aus dem Moor (S5)“. | Notiz `date_grave` für alle 5 Einträge (oder Sterbebuch-Rückfall) → `c_q_three_weeks` „Immer drei Wochen. Nie zwanzig Tage, nie zweiundzwanzig.“ | Ruf 0, Pietät 0 |
| **H3** | „Wer hat das Licht gesehen?“ | Dialogzeile „[Die Liste] …“ bei den fünf Zeugen (§2.2.4). Jeder erzählt von einem Licht in einem Haus, in dem keiner krank war, und dass keiner aus dem Haus es angezündet hat. | Erkenntnis **`i_light_before`** „Das Licht vorher“ = `c_q_dates` + `c_q_three_weeks` + **3 von 5** Zeugen-Hinweisen (`InsightData.any_clues`, Phase 8) | Flag `insight_light_before`; jeder Zeuge Beziehung **+2** (`witness`) |
| **H4** | „S.“ | Drei Häuser mit S: die **Siebers**, die **Schmiede** (Esch), der **Schultheiß** (Fenner). Veit (Brunnenbank 21:00–23:30 oder Kirchtür): „Das Licht? Bei den Siebers. Oben beim Alten. In der Nacht nach … da war's kalt.“ Esch und Fenner verneinen (eigene Zeilen). An der Haustür der Siebers „[E] Anklopfen“ (`KnockDoor`, §4.6): Anna Sieber hinter der Tür: „Bei Vater oben brannte es. Er sagt, er war's nicht. Er lügt nie, der Alte. Er ist zu langsam zum Lügen.“ Johann (jetzt **täglich** an Gretes Grab 10:00–11:00, im Dorf 14:00–16:00 auf der Bank vor dem Haus) zeigt auf Nachfrage das Zeichen: „Da. Juckt nicht. Grete hatte so was nicht.“ | Flag `q_sieber_marked` → Hinweis `c_q_sieber` | Johann Wohlwollen +1 |
| **H5** | „Wem sagst du es?“ | Wahl im Gespräch mit **Lenz**, **Quast** oder **Liesel** („[Die Liste] Ich muss Ihnen etwas zeigen.“) – oder **niemandem** (Knopf auf der Merkbuch-Seite „Die Liste“, oder H6 direkt anfangen). Je Person eigene Antwort und eigenes Angebot für H6 (§2.2.6). | Wahl `confide_priest` · `confide_surgeon` · `confide_washer` · `confide_none` | Vertraute(r) **+4** (`confided`), Flag `q_confide_<wahl>` |
| **H6** | „Was wird aus Johann?“ | Gespräch mit Johann (Grab oder Bank): „[Die Liste] Es geht um das Licht, Johann.“ Drei Wege (§2.2.7). Frist: Licht + 17 (Bogen A: B6, 23:59). | Wahl `away` · `stay` · `public`; ohne Wahl bis zur Frist → `silent` | §2.2.7, §2.2.8 |

#### 2.2.4 Die Zeugen (Leittexte, P6 schreibt aus; je eine Zeile mehr mit Beziehung „Befreundet“)
- **Liesel** (`e_dorn`): „Bei uns brannte ein Licht in der Kammer. Kaspar hat gesagt, das war ich. Ich hab gesagt, das war er. Drei Wochen später ist er ins Moor gegangen und nicht wiedergekommen. Wir haben uns nie geeinigt, wer es war.“ Mit `underlined washer`: „Sie sieht dich an, als wüsste sie, was auf der anderen Seite der Seite steht.“
- **Osric** (`e_quendel`): „Bei der Quendel brannte Licht, oben, um eins. Ich fahr da nachts vorbei, wenn ich aus Ellbach komme. Ich hab gedacht, die kann nicht schlafen. Ich halte nie an. Diesmal hätte ich vielleicht sollen.“
- **Rosine** (`e_wernstein`): „Die Ida hat bei mir ausgeschenkt, bis sie wegwollte. Sie kam eines Morgens und sagte, in ihrer Kammer hätte die ganze Nacht ein Licht gebrannt, und sie hätte keins angezündet. Am nächsten Tag lag ein Brief unter ihrer Tür. Da hat sie gepackt.“ (Anschluss an den Warnbrief S3, Phase 4.)
- **Theres** (`e_hagedorn`): „Ich seh vom Laden aus zur Hagedorn hinüber. Da brannte es, und die Alte war gesund wie ein Pferd. Ich hab mir nichts gedacht. Man denkt sich bei Licht nichts. Das ist ja das Schlimme.“
- **Gesa Ott** (`e_ott`): „Drei Wochen vorher brannte schon mal eins. In Vaters Kammer. Da war er noch gesund. Er hat gesagt, er war's nicht. Wir haben gelacht. Ich lach da nicht mehr.“
- **Veit** (`e_open`): „Bei den Siebers. Oben beim Alten. Ich sitz nachts am Brunnen, ich seh die Fenster. Keiner hat es angezündet. Es war einfach da, und um fünf war es weg.“

#### 2.2.5 Johann Sieber
- **Johann Sieber**, 71, Altknecht (`kin_sieber`, Figur `ph_chr_mourner_m_b` aus Phase 8: Stock, langer Mantel, Schlapphut). Redet mit dem Grab seiner Frau, nicht mit dir („So, Grete.“). Lebt im Altenteil bei Sohn und Schwiegertochter (Anna, die Wöchnerin aus Quasts Phase-8-Schritt; nur als Stimme hinter der Tür). Er kann nicht lesen.
- Ab H4 kommt er **täglich** (statt alle 7 Tage) an Gretes Grab (`Visitors.set_kin_interval(&"kin_sieber", 1)`, 10:00–11:00), und er sitzt im Dorf 14:00–16:00 auf der Bank vor dem Haus (neuer Dorf-Npc `npc_kin_sieber_v`, §3.1). Er weiß, was das Zeichen heißt: „Die Hagedorn hatte es auch. Und der Ott. Man redet nicht darüber, man zählt.“

#### 2.2.6 Was die Vertrauten anbieten (H5)
| Vertraute(r) | Antwort (Leittext) | Angebot in H6 | Folge in Ende C |
|---|---|---|---|
| **Lenz** | „Ein Licht, das keiner anzündet. Das steht in keinem Buch, das ich habe. Ich gehe zu ihm, wenn es so weit ist. Früher als sonst, wenn Sie wollen.“ | Ende B: Lenz kommt am ersten Abend mit (Versehgang vor dem Krankenlicht), Lenz +3 | ausgenommen vom −4 |
| **Quast** | „Drei Wochen. Ich habe es gezählt, bei den stillen Herzen. Ich hätte es aufschreiben sollen. Es gibt einen Mann aus der Stadt, der dafür zahlen würde. Geben Sie ihm nichts.“ (Haken K3: er nennt Brenneisen) | Ende B: Quast lässt Tropfen für die Schmerzen da (`fever_tincture` −1 aus seinem Laden, kostenlos); K3 sofort erfüllbar | ausgenommen vom −4 |
| **Liesel** | „Ich wasche ihn, wenn es so weit ist. Vorher nicht. Vorher ist er noch Johann.“ Mit `underlined washer` zusätzlich: „Sie fragt nicht, woher du es weißt.“ | Ende B: Liesel sitzt am zweiten Abend mit; ihre Totenwache bei Johann ist sichtbar wie bei Ott | ausgenommen vom −4 |
| **niemand** | – | – | alle drei −4 |

#### 2.2.7 Die drei Enden (H6)
**Ende A – „Über den Hügel“ (`away`, Lorenz' Weg).** Du rätst Johann zu gehen. Er will nicht („Ich hab's nicht eilig. Grete wartet, die wartet gern.“) – bis du ihm den Brief zeigst, den du ihm in der Nacht zuvor geschrieben hast, ohne Namen, wie Lorenz (Voraussetzung: „[E] Brief ohne Namen schreiben (20 Min, 1 Tinte)“ an der Hütte, dann „[E] Brief an die Tür der Siebers stecken“ nachts an der `KnockDoor`; ohne Brief ist Ende A **nicht** wählbar, die Zeile ist gedimmt: „Er glaubt dir nicht. Er würde einem Brief glauben.“). Er liest ihn nicht (er kann nicht lesen), aber er erkennt die Form: „So einen hatte die Ida auch.“ Er geht **mit Hanne** an ihrem nächsten Tag, wenn der zwischen der Wahl und Licht + 18 liegt und sie das Tor noch nicht verlassen hat (sichtbar: 16:20 vom Friedhofstor mit ihr den Waldweg hinauf, Bündel über der Schulter, `walk_bundle`), sonst am Morgen nach der Wahl mit **Osric** auf dem Karren nach Ellbach (10:00; die Frist Licht + 17 garantiert, dass das vor dem Krankenlicht liegt; sitzt hinten auf der Ladefläche: „Bis Ellbach. Weiter fahr ich nicht.“).
- Folgen: Flag `q_end_away`, `sieber_gone` (seine Npc sind verborgen, `hide_flag`); `np_sieber` fällt aus (`cancel_flag`); **kein D3**. Pietät **+3** (`sent_away`), Ruf **−2** (`sent_away_rumor`: „Der Totengräber schickt die Alten fort.“), Sieber-Haushalt Wohlwollen +2, Hanne bzw. Osric eine Zeile. Am Morgen danach steckt an der Hüttentür ein Zettel in der schrägen Hand der Warnbriefe: „Du schreibst wie er. Gut.“ → Hinweis `c_q_hand_answers` (Haken Phase 12). Gretes Grab hat ab jetzt keinen Besucher mehr; Jakob pflegt es, wenn es auf der Liste steht. Ob Johann ankommt, bleibt offen (Bestätigung §14.5).

**Ende B – „Bei Grete“ (`stay`).** Johann bleibt. Du versprichst ihm ein Grab so nah an Grete wie möglich (die zurückgehaltene Stelle der vierten Reihe, §2.6) und sitzt an **zwei Abenden** mit ihm auf der Bank (Aufträge `oq_johann_evening` ×2, `meet`, 18:00–20:00, je 30 Min; der Vertraute aus H5 kommt mit, §2.2.6). Dann kommt das Krankenlicht (`np_sieber`, Nachtwege wie Phase 8), Quast und Lenz kommen wie immer, Johann stirbt um 02:10, Liesel kommt um 02:40. Am Morgen danach bringt Osric **D3 Johann Sieber** (§2.7).
- Folgen: Flag `q_end_stay`; Pietät **+3** (`kept_promise`, bei der Bestattung, wenn er in der vierten Reihe liegt), Ruf **+1**, Sieber-Haushalt Wohlwollen +4, Vertraute(r) +3; Johanns Geist (`by_story`): „Grete hat gesagt, ich soll mich nicht beeilen. Ich hab mich nicht beeilt.“

**Ende C – „Vor der Gemeinde“ (`public`).** Du gehst mit der Liste zu **Fenner**. Fenner macht es zur Gemeindesache: ein Nachtwächter (Laterne an der Sieber-Haustür, Licht-Requisit ohne Figur; mit Prio B als Figur, §12.4) wacht jede Nacht bis zum Ende, und Fenner schreibt mit, wer kommt. Es kommen dieselben wie immer: Quast, Lenz, Liesel. Johann stirbt trotzdem. Fenner am Morgen: „Der Wächter hat niemanden gesehen, der nicht hingehört. Er hat auch nicht geschlafen, sagt er.“ D3 kommt wie in B.
- Folgen: Flag `q_end_public`; Ruf **+3** (`public_duty`), Pietät **−1** (`made_public`: „Du hast einen Sterbenden zur Gemeindesache gemacht.“), Fenner +4; **Lenz, Quast und Liesel je −4** (`named_publicly`, außer dem Vertrauten aus H5: „Sie haben es mir vorher gesagt. Das rechne ich Ihnen an.“); die drei sind am Tag danach „gereizt“ (Launen-Vorrang 4, Phase 8 §2.1.1); Sieber-Haushalt Wohlwollen −1 („Jetzt weiß es das ganze Dorf.“). Fenner legt ein **Lichterbuch** an (Flag `fenner_lightbook`, Haken Phase 10/18).

**Still – „Geschwiegen“ (`silent`, Rückfall bei verstrichener Frist).** Johann bleibt, ohne Versprechen. Das Krankenlicht kommt, D3 kommt. Johann am letzten Abend (Bank, Blase, wenn du in der Nähe bist): „Du hast nichts gesagt. Das ist auch eine Antwort.“ Folgen: Flag `q_end_silent`; keine Ruf-, Pietät- oder Beziehungsänderung; zählt fürs Kapitel als Ende. *Begründung:* Wer die Kette liegen lässt, soll nicht bestraft, aber auch nicht belohnt werden; das Dorf hat seinen eigenen Lauf.

#### 2.2.8 Folgen-Matrix (was sich danach im Spiel ändert)
| Folge | A „Über den Hügel“ | B „Bei Grete“ | C „Vor der Gemeinde“ | still |
|---|---|---|---|---|
| Johann | geht sichtbar, kein D3 | stirbt Licht + 21, D3 | stirbt, D3, Wächter-Protokoll | stirbt, D3 |
| Ruf · Pietät | −2 · +3 | +1 · +3 | +3 · −1 | 0 · 0 |
| Beziehungen | Sieber-Wohlwollen +2; Liesel (Reaktion) | Vertraute(r) +3, Sieber +4 | Fenner +4, die drei −4 (außer Vertraute) | – |
| Gerede (Reaktionen, `NpcLifeConfig.reactions`, 3 Tage) | `q_sent_away` – Fenner: „Leute fortschicken ist nicht Ihr Amt, Totengräber. Es ist auch nicht meins.“ · Liesel: „Lorenz hat sie auch fortgeschickt. Nicht alle sind angekommen.“ | `q_stayed` – Rosine: „Du hast beim Sieber gesessen, sagt Anna. Zwei Abende. Das macht keiner.“ | `q_public` – Rosine: „Fenner hat einen Wächter vor die Siebers gestellt. Jetzt schließen alle ihre Läden zu.“ · Lenz: „Sie haben mich vor Fenner gestellt. Ich war trotzdem da. Ich bin immer da.“ | – |
| Launen | – | – | Lenz, Quast, Liesel 1 Tag „gereizt“; alle mit Kreis Sieber 2 Tage „bedrückt“ | – |
| Spätere Quests in Phase 9 | Botengang E3 „Ein Bündel für die Siebers“ entfällt; Brief von Johann (§14.5) | E3 wird zur Totenhemd-Szene; Johanns Taschenbrief „An Grete“ (§2.4.2) | Briefe-Schritt E2 „Fenners Siegel“ wird zur Bekanntmachung „Wer ein Licht sieht, meldet es dem Schultheiß.“ | wie B ohne Versprechen |
| Haken danach (nur Flags) | `c_q_hand_answers` (Phase 12) | `kept_promise_sieber` | `fenner_lightbook` (Phase 10/18) | – |

### 2.3 Größere Bitten (`data/config/hill_requests_config.tres` erweitert, `data/hill_requests/large/<id>.tres` – `OrderData` mit `size large`)

#### 2.3.1 Ausgangslage
G8 Runde 6 (Bot `HillBot`, Pflicht-Spieler, Tag 2–12): Leerlauf **2820 → 2483 min (−12 %)**; die kleinen Bitten bringen ≈ 40 Spielminuten Arbeit je Tag. Gegen Mittag ist an vielen Tagen alles getan, der Nachmittag (12:00–18:00 = 360 Min) bleibt halb leer. Eine Bitte, die **150–240 Minuten** bindet, füllt einen halben Nachmittag.

#### 2.3.2 Regeln (alle Werte in `HillRequestsConfig`, ✦ neue Felder)
| Wert | vor `village_open` | ab `village_open` |
|---|---|---|
| Plätze für große Bitten | **1 am Tor** (`large_slots_gate 1`) | 1 am Tor + **1 an der Gemeindetafel** (`large_slots_village 1`) |
| gleichzeitig angenommen | **1** (`large_max_active 1`, zusätzlich zu den kleinen) | 1 |
| freier Platz wird neu belegt | am **nächsten** Morgen (`large_refill_days_early 1`) | am **zweiten** Morgen (`large_refill_days_village 2`) |
| erste große Bitte | Tag 2, 07:44 (`large_start_day 2`) | – |
- **Ablauf:** Osric heftet eine große Bitte um 07:44 mit den kleinen an („… und einen großen Bogen“ – HUD), offen höchstens 2 Tage (`large_offer_days 2`), angenommen mit **Frist 2–3 Tage** (`OrderData.days_limit`, Prüfung 06:00). Die Teile (`parts`, 2–4) gelten **in beliebiger Reihenfolge**, außer `parts_in_order` ist gesetzt (z. B. erst untersuchen, dann bestatten). Jeder erledigte Teil gibt eine HUD-Zeile („Die Gräber der Fähre: 2 von 3“) und ein Häkchen auf dem Bogen.
- **Halb erfüllt:** Ist bei der Frist mindestens die Hälfte der Teile erledigt, gilt die Bitte als **halb erfüllt**: halber Münzlohn (abgerundet), Ruf 0, eine Dankesnotiz ohne Vorwurf. Sonst **versäumt**: Ruf −2 (`large_fail_rep`). *Begründung:* Eine große Bitte ist ein halber Nachmittag; wer zwei Drittel schafft, hat gearbeitet.
- **Lohn:** Ruf **+2**, **3–5 Münzen** (Schnitt 4), dazu oft ein Ding, das der Spieler in dieser Zeit braucht (1–2 Leinen, ein Rechen-Stiel, 2 Kerzen …; `conditions.reward_items`); ab `village_open` Beziehung **+3** zum Geber (`large_reward_rel 3`). Große Bitten zählen wie die kleinen **nicht** als Aufträge.
- **Wiederholung:** Abklingzeit je großer Bitte 8–10 Tage; nie zwei Bitten desselben Gebers zugleich (klein oder groß). Auswahl deterministisch `hash([Tag, Platz, id])`. Kein Angebot, das man nicht lösen kann (Angebotsbedingungen wie Runde 6 je Teil: schmutzige Stellen, Rechen, freie Grabstelle, Abschnitt mit Hindernis, Grab mit Zeichen, Werkbank-Rezept bekannt).
- **Neue Teil-Arten** (zusätzlich zu `deliver`, `tend`, `exam`, `prep`, `marker`, `ghost`, `clear`, `decor` aus Runde 6):
  | Art | Erfüllung | `conditions` |
  |---|---|---|
  | `craft` | ✦ `EventBus.craft_finished` (Werkbank, Steinmetzbank, Pult) | `recipe`, `amount` |
  | `gather` | `resource_gathered` (Fällen, Sammeln, Steinbruch) | `item`, `amount` |
  | `ghosts` | `ghost_spoke` × n in **einer** Nacht | `times`, `section` |
  | `visit` | der Spieler steht im Fenster an einem Wegpunkt (≤ 3 m) und hält „[E] …“ (Text der Bitte, 10–40 Min, TimedAction) | `place`, `minutes`, `window`, `label` |
  | `meet` | eine Person an einem Ort im Fenster sprechen (wie `Orders.note_meet`) | `npc`, `place`, `window` |
  | `devotion` | `devotion_held` in der Kapelle | – |
  | `flowers` | `grave_care_changed(…, flowers, true)` auf Gräbern der Bitte (ab Phase 8) | `graves` |

#### 2.3.3 Pool (12 große Bitten; Texte P6/P2, Ton „Tod ist Handwerk“)
| id | Ort · ab | Geber | Teile | Frist | Lohn | ≈ Min |
|---|---|---|---|---|---|---|
| `hrl_ferry_graves` | Tor · Tag 2 | Pfarrer Lenz (über Osric) | „Die Gräber der Fähre“: die 4 Pflegestellen im Alten Hof säubern · 2 Zierstücke im Alten Hof aufstellen · nachts einem Geist im Alten Hof zuhören | 3 | 4 · Ruf +2 · 2 Altarkerzen | 190 |
| `hrl_crosses` | Tor · Tag 2 | Fenner | „Drei Kreuze für den Hohlweg“: 3 Holzkreuze an der Werkbank · bei Osric abgeben | 3 | 4 · Ruf +2 | 150 |
| `hrl_proper_grave` | Tor · Tag 3 | Osric | „Ein Grab, wie es sich gehört“ (in Reihe): die nächste Lieferung gründlich untersuchen · gewaschen, gekleidet, aufgebahrt bestatten · Grabstein · die zwei Nachbargräber säubern | 3 | 5 · Ruf +2 · 1 Leinen | 210 |
| `hrl_bench_path` | Tor · Tag 3 | Theres | „Ein Platz zum Ausruhen“: ein Hindernis im Birkenhang oder Holunderwinkel roden · eine Bank an der Werkbank · am Weg aufstellen · das Laub ringsum harken | 3 | 4 · Ruf +2 · 1 Samen | 220 |
| `hrl_restless` | Tor · Tag 4 | Liesel | „Eine Nacht für die Unruhigen“: drei Geistern in einer Nacht zuhören · am Morgen deren Gräber säubern | 2 | 3 · Ruf +2 · 1 Leinen | 160 |
| `hrl_widow_wood` | Tor · Tag 2 | Martha Kehr | „Holz für die Witwen“: 10 Holz schlagen oder roden · bei Osric abgeben | 2 | 4 · Ruf +2 | 170 |
| `hrl_lantern_path` | Tor · Tag 5 | Osric | „Licht am Kutschweg“: 2 Laternenpfähle (Zier, Werkbank) · am Tor aufstellen · nachts am Tor stehen, bis Osric vorbeifährt (`visit`, 20 Min, 21:30–23:00) | 3 | 4 · Ruf +2 | 180 |
| `hrl_old_names` | Tor · Tag 6 | Pfarrer Lenz | „Namen, die man noch lesen kann“: 2 Steine (Steinmetzbank, sobald gebaut; sonst Holzkreuze) für Altgräber · die Grabstellen säubern · einem dieser Geister zuhören | 3 | 5 · Ruf +2 | 230 |
| `hrv_bridge_stones` | Gemeindetafel · `village_open` | Fenner | „Steine für die Holderbrücke“: 8 Steine sammeln · 2 Werksteine (Steinbruch) · an der Brücke abladen (`visit bridge`, 20 Min) | 3 | 5 · Ruf +2 · Fenner +3 | 200 |
| `hrv_paul_day` | Gemeindetafel · `p8_open` | Martha Kehr | „Ein Tag für Paul“: 2 Kräuterbündel an Quast · Grabblumen auf die Gräber der Kehrs · Martha am Grab treffen | 3 | 3 · Ruf +2 · Martha Wohlwollen +2 | 160 |
| `hrv_inn_cellar` | Gemeindetafel · `village_open` | Rosine | „Der Keller im Holderkrug“: 6 Holunderbeeren · 4 Holz · im Keller helfen (`visit inn_cellar`, 40 Min, 14:00–17:00) | 2 | 4 · Ruf +1 · Rosine +3 · 1 Holunderwein | 180 |
| `hrv_church_candles` | Gemeindetafel · `buildings_open` | Pfarrer Lenz | „Kerzen für St. Gallus“: 4 Altarkerzen besorgen und Lenz bringen (`deliver`; kein Rezept – Theres, Lenz, Osric verkaufen sie, W0) · eine Andacht in der Kapelle · Lenz in der Kirche treffen (16:00–18:00) | 3 | 4 · Ruf +2 · Lenz +3 | 170 |
- Die acht Tor-Bitten sind **alle mit den Mitteln von Tag 2–13** lösbar (wie Runde 6); `hrl_old_names` wählt Holzkreuze, solange keine Steinmetzbank steht. Zierstücke, Bank und Laternenpfahl sind bestehende Werkbank-Rezepte (W0 prüft die Ids; fehlt eines, ersetzt der Lead es durch ein vorhandenes).
- **(W0 geprüft):** Zierstücke = `decor_flowerbed` / `decor_grave_vase` / `decor_lantern`, Bank = `decor_bench_wood`, Laternenpfahl = `decor_lantern` („Grablaterne“), alle Werkbank. Der einfache Grabstein `gravestone_simple` ist ebenfalls ein Werkbank-Rezept – die Holzkreuz-Ausweichregel von `hrl_old_names` ist damit kaum nötig (P2 entscheidet). Für Altarkerzen gibt es **kein Rezept**: `hrv_church_candles` verlangt sie als Abgabe (gekauft), siehe Tabelle.

#### 2.3.4 Darstellung
- **Torafel:** unter den kleinen Zetteln ein großer, gefalteter Bogen mit Siegelfaden (`ph_notice_sheet`, Code-Mesh wie `ph_notice_slip`); „[E] Bitten am Tor lesen“ zeigt ihn als erste Karte. **Gemeindetafel** (Phase 7 `VillageBoard`): derselbe Bogen am rechten Rand; „[E] Gemeindetafel lesen“ zeigt die Aufträge wie bisher und darüber eine Karte „Große Bitte“ (Panel `&"hill_requests"` mit `place village`).
- **Karte der großen Bitte:** Titel, Geber, Text, **Teile als Liste mit Häkchen** (erledigt ✓, offen ○), Frist, Lohn ohne Zahl im Ruf („Die Gemeinde wird es dir danken. 4 Münzen.“), „Annehmen“ oder Grund.
- **HUD:** „Bitte: Die Gräber der Fähre – Zwei Zierstücke im Alten Hof (1/2)“ (nächster offener Teil); im Leerlauf vor dem Feierabend „Eine große Bitte am Tor wartet“.

#### 2.3.5 Münzen früh im Spiel
Kleine Bitten (Runde 6) brachten dem Pflicht-Spieler 32 Münzen in 13 Tagen. Große Bitten bringen bei ≈ 5 erfüllten in Tag 2–14 **≈ 20 Münzen** dazu. Ziel: Tag-14-Münzen des Pflicht-Spielers **≤ 130** (heute 105), des andächtigen **≤ 110** (heute 91). *Begründung:* Die Phase-5-Münzsenke (108 Pflicht) wird etwas früher erreicht, aber nicht übersprungen; der Hauptlohn sind Ruf und Dinge. Liegt die Messung darüber, senkt P2 zuerst die Münzen der Tor-Bitten auf 3 (Schnitt), dann `large_refill_days_early` auf 2.

#### 2.3.6 Messziel (Bot `HillBot`, neues Spiel, Tag 1–14, `test_hill_requests_bot.gd`, P2)
| Spieler | Leerlauf Tag 2–12 vorher (R6) | **Ziel Phase 9** | weitere Grenzen |
|---|---|---|---|
| Pflicht (nimmt alle kleinen und großen Bitten an) | 2483 min (2820 ohne Bitten) | **≤ 1700 min** (−40 % gegen 2820), Band 1450–1800 | höchstens 3 von 11 Tagen mit > 240 min Leerlauf; ≤ 1 große Bitte versäumt; Tag 14 ≤ 130 Münzen |
| Andächtig | 1581 min | 1350–1750 (nicht überladen) | ≤ 2 große Bitten halb/versäumt; Tag 14 ≤ 110 Münzen |
| alle bisherigen Bots (Phase 3–8) | – | **bitgleich** (nehmen keine Bitte an) | – |

### 2.4 Briefe und Botengänge (`data/config/letters_config.tres` – `LettersConfig`, `data/letters/<id>.tres` – `LetterData`, System `Letters`)

#### 2.4.1 Grundsatz
**Entscheidung: zwei Richtungen von Briefen und ein Brief je Handlung.** Briefe **von** den Toten liegen in ihren Taschen (Untersuchung, Schritt „Taschen & Säume“, Phase 4) und wollen zu Lebenden. Briefe **an** die Toten bringt die Post (Osric am Morgen, Hanne an ihrem Tag), weil die Post nicht weiß, dass sie tot sind („Die Post weiß das nicht. Ich schon.“ – Osric). Der Totengräber ist der Einzige, der beides in der Hand hat. *Begründung:* Phase 4 hat den Brief als Merkmal eingeführt (`letter`, 25 %) und nur als Hinweis genutzt; jetzt wird er zu einer Entscheidung, die man mit Menschen und mit den Toten teilt.

#### 2.4.2 Briefe in den Taschen
- **Ab `p9_open`** bekommt jede Lieferung mit Merkmal `letter` (25 %, Phase 4) einen Brief aus dem Pool (✦ `CorpseRecord.letter_id`, gesetzt bei der Lieferung, deterministisch aus dem Leichen-Seed, keiner doppelt). Die **ersten drei Lieferungen nach `p9_open`** tragen sicher je einen der drei Ketten-Briefe L1–L3 (`forced_after_open 3`), auch ohne Merkmal. Ältere Leichen und Stände behalten den Phase-4-Fund (`f_letter` → `c_warning_letter`).
- **Fund:** Beim Schritt „Taschen“ erscheint die Karte „Ein Brief. ‹Außen: An Rosine Wackernagel, Holderkrug›“ und das Item `letter` (Einzelstück, `uid` = Brief-Uid `lt_0001`) im Inventar; versiegelte Briefe zeigen nur die Aufschrift.
- **Entscheidungen** (Brief-Karte, Panel `&"letter"`, aus dem Inventar oder dem Merkbuch):
  | Wahl | Wo | Wirkung (Standard; je Brief überschreibbar) |
  |---|---|---|
  | **Zustellen** | Empfänger im Dorf („[Brief] Das lag in seiner Tasche.“) bzw. **Post** in die Stadt bei Hanne oder Osric (1 Münze Postgeld) | Empfänger Beziehung **+3** (`letter_delivered`), Ruf +1 (höchstens 1 je Tag), Reaktions-Gerede 2 Tage; bei Haushalten Wohlwollen +2 |
  | **Vorlesen** | (a) dir selbst (Karte „Öffnen und lesen“) – versiegelt und nicht an dich: Pietät **−1** (`letter_read_sealed`), außer der Brief bittet darum; (b) dem Empfänger, der nicht lesen kann (Johann, Veit, Martha Kehr): kostenlos und zählt als zugestellt; (c) am Grab des Absenders (10 Min) | (c): Geist +1 in dieser Nacht, Geisterzeile `by_letter`, Pietät +1 (`letter_read_grave`) |
  | **Verbrennen** | Hüttenofen oder Esse (2 Min, Clip `burn_letter`) | bittet der Brief darum („Ungelesen verbrennen“): Pietät **+1**; sonst Pietät −1 und der Empfänger erfährt nie davon |
  | **Ins Grab legen** | beim Bestatten des Absenders (Prompt am offenen Grab, 2 Min) | Geist +1 dauerhaft (Zier-Posten wie eine Grabbeigabe, ≤ +1), Pietät +1 |
- Ein Brief ist danach **entschieden** (`stats.letters_decided`); er kann nicht zweimal entschieden werden (zugestellt ist fort, gelesen bleibt im Merkbuch als Abschrift „Briefe“).
- **Pool** (`data/letters/`, Texte P6; je 2–5 Sätze):
  | id | Absender (Toter) → Empfänger | Art | bittet | Inhalt (Kern) und besondere Folge |
  |---|---|---|---|---|
  | `lp_l1_carter` | ein Fuhrknecht aus Ellbach → **Rosine** | Kette L1 | – | „Ich zahl die zwei Bier, wenn ich wiederkomme. Heb sie mir auf.“ Zustellen: Rosine lacht, dann nicht mehr. Rosine +3, sie hängt den Brief hinter den Schanktisch (Requisit). |
  | `lp_l2_sister` | eine Magd → ihre Schwester **in der Stadt** | Kette L2 | – | „Sag Mutter nichts. Ich komm zu Lichtmess.“ Nur Post (1 Münze); mit Antwort-Möglichkeit (§2.4.3), Absenderin bekommt in Phase 9 eine Antwort zurück (S4). |
  | `lp_l3_burn` | ein Tagelöhner → „an niemanden“, außen: **„Ungelesen verbrennen“** | Kette L3 | `burn` | Verbrennen: Pietät +1. Lesen: ein Warnbrief in der schrägen Hand – „komm nicht zurück nach Hollerbrück“ – er kam trotzdem (Hinweis `c_warning_letter`, falls noch nicht). |
  | `lg_priest` | Altbauer → **Lenz** | Pool | – | Ein Geständnis über 3 Gulden aus dem Opferstock, 1829, „zurückgelegt, mit Zins“. Lenz +3: „Der Zins war zu hoch. Ich verbuche ihn als Spende.“ |
  | `lg_grocer` | Base → **Theres** | Pool | – | ein Rezept für Holunderwein „wie bei Mutter“. Theres +3, 1 Holunderwein im Laden zum halben Preis (einmal). |
  | `lg_wife` | Ehemann → Frau (Haushalt `kin_house` des Toten) | Pool | – | „Der Rock hängt im Schrank. Verkauf ihn nicht unter zwei Gulden.“ Wohlwollen +2, Trinkgeld beim nächsten erfüllten Wunsch +1. |
  | `lg_nobody` | – → „an den, der das findet“ | Pool | `grave` | „Ich hatte keine Angst. Sag es keinem, sonst glaubt es keiner.“ Ins Grab legen: Geist „ruhig“-Zeile. |
  | `lg_town` | Händler → ein Kontor in der Stadt | Pool | – | Post (1 Münze): beim nächsten Hanne-Tag 2 Münzen Botenlohn zurück („Das Kontor dankt.“). |
  | `lg_smith` | Lehrling → **Esch** | Pool | – | „Ich hab die Zange mitgenommen. Sie ist im Graben bei der Mühle.“ Esch +3, 1 `iron_fittings`. |
  | `lg_lambert` | Ziegler → **Lambert Grell** | Pool, nur `robber_fate let_go` | – | Veit trägt ihn hin („Ich geh da sowieso vorbei.“). Pietät +1. |
  | `lp_d3_grete` | **Johann Sieber → „An Grete“** | nur D3 (Ende B/C/still) | `grave` | Er kann nicht schreiben; es ist ein Zettel mit einem gemalten Kreuz und einer Haarlocke. Auf Gretes Grab legen (Prompt am Grab, 2 Min): Pietät +2, beide Geister „ruhig“. |

#### 2.4.3 Post für die Toten
- **Osric** bringt an `p9_open_day + 3`, `+ 6`, `+ 9` (Bogen A: B4, B7, B10) je einen Brief **an** einen begrabenen Toten mit, falls dessen Grab belegt ist (`post_offsets`), **Hanne** an ihrem ersten Tag ab `l4`-Erledigung den Brief „An L. Aschau“ (§2.4.5). Notiz: „Osric hat Post für Marthe Quendel. ‚Die Post weiß das nicht. Ich schon.‘“
- **Wahlen:** **am Grab vorlesen** (10 Min; Geist +1 heute Nacht, Pietät +1, Zeile `by_letter`), **antworten** (Hütte, „[E] Antwort schreiben (20 Min, 1 Tinte)“ → Item `letter_reply`, dann Post 1 Münze; Pietät +1 `letter_answered`), **den Angehörigen geben** (wenn das Grab einen Haushalt hat: Wohlwollen +2), **verbrennen**.
- **Pool (4, Texte P6):** `lpo_quendel` (von ihrer Schwester aus Ellbach: „Du schreibst nicht mehr. Bist du mir böse?“), `lpo_wernstein` (an Ida Wernstein von einer Herrschaft in der Stadt: „Die Stelle als Köchin ist Ihre, wenn Sie bis Martini kommen.“ – sie wollte weg und kam nicht), `lpo_ott` (an Gerhard Ott von seinem Sohn beim Militär; den Angehörigen geben: Gesa +4 und eine eigene Szene am Grab), `lpo_hagedorn` (an Wiebke Hagedorn vom Gesangverein, „ob sie zu Weihnachten wieder die zweite Stimme…“).

#### 2.4.4 Botengänge (Aufträge der Kategorie `quest`, Art `deliver`, mit Empfänger und kleiner Entscheidung)
| id | Prio | Geber → Empfänger | Was | Entscheidung unterwegs | Folgen |
|---|---|---|---|---|---|
| `oq_gesa_brother` (**E1**, Kette L3) | A | Gesa Ott → Post (Hanne/Osric) | ein Brief an ihren Bruder beim Militär | Postgeld selbst zahlen (1 Münze) oder Gesa fragen („Ich hab keine Münze. Ich hab Strohblumen.“ – 1 Strohblumen-Strauß, wirkt wie Grabblumen 2 Tage) | Gesa +3; selbst gezahlt: Pietät +1 |
| `oq_fenner_seal` (**E2**) | A | Fenner → Lenz | eine versiegelte Bekanntmachung der Gemeinde | „[E] Hineinsehen“ (das Siegel bricht; Fenner merkt es immer: −3, „Das Siegel ist ab. Ich seh's ja.“) oder nicht | Lenz +2, Fenner +2; Inhalt je nach Ende C (§2.2.8) |
| `oq_liesel_bundle` (**E3**) | B | Liesel → Anna Sieber | ein Bündel Leinen „für später“ | Johann sagen, was darin ist, oder nicht | entfällt bei Ende A; Johann: „Gut. Dann muss Anna nicht nähen.“ |
| `oq_jakob_father` (**E4**) | B | Jakob → „an Vater“ (Konrad Wackernagel, ertrunken, ohne Grab) | ein Kinderbrief | an die Namenstafel in der Kirche stecken oder an der Holderbrücke ins Wasser legen | Rosine +3 / Jakob Laune „heiter“ 1 Tag, eigene Zeile |
- Botengänge zahlen keine Münzen (außer Postgeld-Rückgaben in `lg_town`); jeder erledigte zählt `stats.errands_done`.

#### 2.4.5 Die Nebenkette „Briefe ohne Antwort“ (`q_letters`)
| Schritt | Titel | Erledigt durch | Prio |
|---|---|---|---|
| **L1** | „Ein Brief in der Tasche“ | den ersten Taschenbrief (L1) entschieden | A |
| **L2** | „Post für den Hügel“ | den ersten Brief an einen Toten entschieden | A |
| **L3** | „Für den Bruder“ | Botengang `oq_gesa_brother` erledigt (E1) | A |
| **L4** | „Eine Antwort“ | eine Antwort geschrieben und aufgegeben (an einen Absender eines Post-Briefs oder an `lp_l2_sister`); am Tag danach kommt ein Gegenbrief („Danke, dass Sie es mir geschrieben haben. Jetzt weiß ich es wenigstens.“) | A |
| **L5** | „An L. Aschau“ | Hanne bringt einen Brief „An L. Aschau, Totengräber zu Hollerbrück“, gesiegelt mit **Anker und Schlange** (die Moorfährleute, Phase 4). Wahl: **öffnen** („Die Fähre geht wieder. Sag, wann.“ → Hinweis `c_q_ferry_letter`, Pietät −1) · **versiegelt aufheben** (Truhe; Flag `lorenz_letter_kept`, Haken Phase 12) · **Liesel geben** (Liesel +4, sie steckt ihn ins Gesangbuch, Flag `lorenz_letter_liesel`) · **verbrennen** (Flag `lorenz_letter_burned`) | B |

### 2.5 Der Herr mit dem Koffer (`data/config/stranger_config.tres` – `StrangerConfig`, `data/stranger/offers/<id>.tres` – `StrangerOfferData`, System `Stranger`, Kette `q_case`)

#### 2.5.1 Die Figur
| id | Name | Rolle | Aussehen (gemalt, Palette der Figuren) | Stimme |
|---|---|---|---|---|
| `stranger` | **Cornelius Brenneisen**, 52 | „Kommissionär“ aus der Stadt; kauft für ein anatomisches Kabinett und für „private Sammler“; hat Lambert Grell für Nachrichten über frische Gräber bezahlt (`c_n_robber`) | dunkler Stadtrock mit Samtkragen, Zylinder mit stumpfem Band, Brille an einer Kette, glänzende Schuhe, die nicht für den Hügel gemacht sind; ein brauner Lederkoffer mit Messingschloss (Kindmesh `case`, am Knochen `tool`); riecht nach Branntwein (er reinigt seine Instrumente damit, sagt er) | höflich, genau, nennt jeden beim Nachnamen, schreibt in ein kleines Buch, fragt Dinge, die man nicht fragt („Wie schwer ist ein Mann nach drei Tagen im November?“), zahlt immer passend |
- **Wann:** erstmals an `p9_open_day + 2` (Bogen A: B3), danach alle 5 Tage für **3 Tage** (`arrive_offset 2`, `return_every 5`, `stay_days 3`), bis seine Kette endet. Er kommt über die Holderbrücke zu Fuß (09:30), wohnt im Holderkrug (Gaststube 18:00–21:00 an einem Tisch, schreibt), geht 13:30 den Kutschweg hinauf und steht **14:10–15:30 außen am Friedhofstor** (läutet einmal kurz die Torglocke, HUD „Ein Herr in einem Stadtrock wartet am Tor.“). Er betritt den Friedhof **nie** („Ich warte hier. Ich bin nicht eingeladen.“).

#### 2.5.2 Die fünf Schritte
| Schritt | Titel | Inhalt | Wahlen und Folgen | Prio |
|---|---|---|---|---|
| **K1** | „Fragen am Tor“ | Drei Fragen (je Besuch eine neue aus 6, P6): „Wie tief graben Sie im Frost?“ · „Wer kommt zuerst, wenn einer stirbt?“ · „Haben Sie je einen gesehen, der drei Wochen vorher wusste, dass er geht?“ | **offen antworten** (er zahlt 1 Münze „für die Auskunft“, `question_coin`; schreibt) · **ausweichen** (nichts) · **nicht antworten** (Pietät +1 einmal: „Die Toten haben ein Recht auf Ruhe. Die Fragen auch.“) | A-leicht (Auftritt), B (Folgen) |
| **K2** | „Was er kaufen will“ | Angebote (Panel `&"stranger"`, rechts angedockt): **Erde von einem frischen Grab** (3 Münzen; „[E] Eine Handvoll Erde nehmen (2 Min)“) · **Abschrift des Grabregisters** (`register_extract`, 10 Münzen) · **Präparate** (falls im Inventar, `anatomy_known`: Quasts Preis × 1,5) | Erde: harmlos, unheimlich, Pietät −1 (`soil_sold`). Register: **Pietät −3**, Lenz −4 und Fenner −2 **zwei Tage später** (Rosine erzählt es), Gerede `register_sold`. Präparat: Phase-7-Folgen + `visit_specimen_rumor` dorfweit. Ablehnen: nichts. | B |
| **K3** | „Wer zahlt für Frische?“ | Mit `c_n_robber` (Phase 8) erkennst du ihn; ohne: Veit („Der mit dem Koffer war schon mal da. Vor einem Jahr. Bei Lorenz. Lorenz hat ihn vom Hügel gejagt, mit der Schaufel.“) oder Quast (H5 Vertrauter). Gespräch am Tor. | Er gibt zu, Grell bezahlt zu haben, „für Nachrichten, nicht für Leiber – der Mann hat es falsch verstanden“. Hinweis `c_q_case_lorenz`. Er bietet **15 Münzen für dein Schweigen**: annehmen (Pietät −3, Flag `case_bribe`) · ablehnen. | B |
| **K4** | „Der Koffer“ | Er vergisst seinen Koffer im Holderkrug; Rosine gibt ihn dir („Bring ihn rauf, er wartet am Tor. Ich fass das Ding nicht an.“; Botengang `oq_case_return`, Item `stranger_case`). | „[E] Hineinsehen“: Instrumente in Samt, Gläser, ein Brief von Quast („Die beiden letzten, wie besprochen.“) und ein Blatt: „Hollerbrück – Gezeichnete. Herzen still. Zahle das Doppelte.“ → Hinweis `c_q_case_list`, Pietät 0, er merkt es (Schloss offen): Ende „Handel“ teurer für ihn. **Fenner geben** statt ihm (Beweis; führt direkt zu K5 „Fenner“). **Ihm bringen** ungeöffnet: er zahlt 2 Münzen Botenlohn. | B |
| **K5** | „Was er mitnimmt“ (Ende der Nebenkette) | am letzten Tag seines zweiten Besuchs (oder früher mit K4) | **Fenner:** du zeigst ihn an → Fenner und der Nachtwächter bringen ihn über die Brücke (sichtbar), er kommt nie wieder; Ruf **+3**, Fenner +4, **Quast −6** („Sie haben mir meinen einzigen Käufer genommen. Vielleicht war das gut. Ich weiß es nicht.“), Flag `case_end_fenner`. · **Handel:** du verkaufst ihm, was er will, im Rahmen (Erde, Register, Präparate) und er bietet **40 Münzen für Lorenz' Kladde** (nur nach Ende der Hauptkette): verkaufen → Münzen +40, **Pietät −8**, Flag `kladde_sold` (Haken Phase 12), die Liste bleibt als Abschrift im Merkbuch; nicht verkaufen → er lässt eine Karte da („Falls Sie es sich überlegen.“ – `case_card`, Haken Phase 10), Flag `case_end_deal`. · **Ilse:** du sagst ihm, an der Westmauer kaufe nachts eine Frau „alles, was über der Erde liegt“ → er geht in der Nacht hin; am Morgen ist er fort. Ilse in der nächsten Nacht: „Er ist in die Stadt zurück. Er kommt nicht wieder. Frag nicht, was ich ihm verkauft habe.“ Pietät +2, keine Münzen, Flag `case_end_ilse`. | B |
- **Verbindungen:** Lamberts Verbleib färbt K3 (`let_go`: Lambert grüßt über Veit und bestätigt „der war's“; `reported`: Fenner kennt den Namen schon aus dem Protokoll). Ist er während H6 da, bietet er Johann an, ihn „zu einem Arzt in der Stadt“ mitzunehmen; Johann: „Mit dem? Der riecht nach Keller.“ (nur Text, keine Wahl). Er **kauft nie eine Leiche** und fragt nicht danach (§13); Grabräuberei bleibt Phase 8.

### 2.6 Die vierte Reihe im Lindenacker (`data/sections/linden_row4.tres`, Bestätigung §14.3)
**Vorschlag: Fenner gibt vier Stellen `l_13…l_16` als vierte Reihe am Südrand.** *Begründung:* Am Phase-8-Ende ist der Lindenacker voll (G8: alle Bots), Osric liefert nicht mehr. Ohne neue Tote gäbe es keine Taschenbriefe L1–L3, keinen Platz für D3 und keine Lieferung für `hrl_proper_grave`. Vier Stellen tragen ≈ 3 Lieferungen im Bogen A (B3–B5); die **vierte hält Fenner ab `p9_open` zurück** („Eine halte ich zurück. Für den Fall.“ – `WhoKnows` reserviert sie mit der Phase-4-Reservierungsregel, Osric: „Heute nichts. Aber halt eine Grube frei.“), bis das Ende abgeschlossen ist: D3 bei Ende B/C/still, bei Ende A wird sie frei (nächste Lieferung). Freigabe: erstes Gespräch mit Fenner ab `p9_open` (Flag `linden_row4_granted`, Notiz „Die Gemeinde gibt dir die vierte Reihe. Die letzte, sagt Fenner.“); Hindernisse 1 Stumpf (30 Min) + 1 Brombeere (40 Min), dann `ExpansionManager.try_unlock`. Lage, Zaun und versetzte Elemente: §4.6 (L16–L19).

### 2.7 D3 Johann Sieber (Geschichts-Leiche, `data/story/d3_sieber.tres`, `data/finds/f_d3_*.tres`)
- **Johann Sieber**, 71, `old_age`, Merkmal `strange_wound`, Look alter Mann (`ph_prop_corpse_03`), keine Wertsachen. Reihenfolge 8 nach D2. `requires_flag &"q_sieber_dies"` (gesetzt bei Ende B, C oder still), `due_flag &"sieber_dead"` setzt `NightPaths` in der Todesnacht (`np_sieber`, 02:10); geliefert am Morgen danach, Reservierung in `linden_row4`. `kin_house` = `house_sieber`.
- Osric: „Der alte Sieber. Heute Nacht. Liesel war schon da. Er hat gesagt, ich soll dir sagen: nicht beeilen. Ich hab's ausgerichtet.“
- **Funde:** `f_d3_mark` (Wunden, 0,3) „Das Zeichen über dem Herzen, verheilt seit drei Wochen. Auf den Tag.“ · `f_d3_ribbon` (Taschen) „Ein Band aus Gretes Haube.“ · Taschenbrief `lp_d3_grete` (§2.4.2).
- Geist (`by_story`): Ende B „Grete hat gesagt, ich soll mich nicht beeilen. Ich hab mich nicht beeilt.“ · C „Da stand einer mit einer Laterne vor meiner Tür. Für mich hat noch nie einer Wache gestanden.“ · still „Keiner hat was gesagt. Ich auch nicht. Das hatten wir so in der Familie.“

### 2.8 Münzrechnung (Bogen A, `kindly9`, Ende A)
**Ausgangslage:** `kindly8` endet mit **≈ 70** Münzen (G8, Start 48). Phase 9 bringt **wenig neue Einnahmen** (3 Bestattungen in Reihe 4, Größere Bitten, kleine Botenlöhne) und **kleine Ausgaben** (Postgeld, Tinte, Jakobs Lohn wie bisher). Ziel: Der Beutel wächst nicht schneller als in Phase 8 (dort +22 in 10 Tagen); der Herr mit dem Koffer ist die **einzige Versuchung**, die ihn sprengen kann, und kostet dafür Pietät.

| Einnahmen (12 Tage) | Rechnung | Münzen |
|---|---|---|
| Start (B1 früh) | W0-Messung | ≈ 70 |
| Pflegegeld nach Bedarf (Phase 8: nur unter 80) | ≈ 6 × 4 | 24 |
| Bestattungen in Reihe 4 | 3 × ≈ 13 | 39 |
| Aussegnungen | 2 × 5 | 10 |
| Größere Bitten (seit `p9_open`) | 3 × 4 | 12 |
| Trinkgeld (Phase 8, gedeckelt) | | 10 |
| Verkäufe im Dorf / an Hanne | gedeckelt | 15 |
| Botenlöhne, Fragen des Herrn | | 3 |
| **Verfügbar** | | **≈ 183** |

| Ausgaben | Münzen |
|---|---|
| Lehrling 9 Arbeitstage × 3 | 27 |
| Postgeld (5 Briefe) · Tinte (Brief ohne Namen, 2 Antworten) | 5 · 6 |
| Bestattungsware für 3 Leichen | 18 |
| Grabkerzen, Setzlinge, Almosen | 14 |
| Geschenke, Runde | 10 |
| **Summe** | **80 (44 %)** |
- Ende ≈ **103** (+33 in 12 Tagen; die Pflegegeld-Kappe bei 80 bremst ab B5). Ende B/C: + D3 (≈ 13) + Aussegnung (5) − Ware (6) ≈ 115. Mit dem Herrn: Handel ohne Kladde ≈ +16, **mit Kladde ≈ +56**.
- **Prüfregel:** aktive Wege Ende ≤ Start + 50; `trader9` (Handel + Kladde) ≤ Start + 100 und Pietät −15 oder tiefer gegenüber `kindly9`; Morgen nie < 5. Liegt `kindly9` über Start + 50, senkt P2 zuerst die Münzen der Dorf-Bitten (§2.3.3) um 1.

### 2.9 Items, Ruf, Pietät, Beziehung, Geister, Statistik
**Neue Items** (`data/items/*`, Phase 9; Besitzer P3)
| id | Name | Kategorie | Stapel | Herkunft | Zweck |
|---|---|---|---|---|---|
| `letter` | Brief | GOODS, **unique** | 1 je Platz | Taschen, Post | §2.4 (Uid → `Letters`) |
| `letter_reply` | Antwort | GOODS, unique | 1 | Hütte, Antwort schreiben | Post |
| `nameless_letter` | Brief ohne Namen | GOODS | 1 | Hütte (Ende A) | an die Tür der Siebers |
| `stranger_case` | ein Lederkoffer | GOODS | 1 | Rosine (K4) | zurückbringen / Fenner geben; kann nicht in den Schuppen |
| `case_card` | Visitenkarte „C. Brenneisen, Commissionär“ | GOODS | 1 | K5 Handel | Haken Phase 10 |
| `soil_pouch` | eine Handvoll Grabeserde im Tuch | GOODS | 3 | frisches Grab (K2) | nur an Brenneisen |
| `straw_bouquet` | Strohblumen-Strauß | MATERIAL | 3 | Gesa (E1) | wirkt wie Grabblumen 2 Tage |
- `lorenz_ledger_2` (Phase 8) bekommt den Text der Rückseite; `register_extract` (Phase 8) ist verkaufbar an Brenneisen.

**Ruf** (`ReputationConfig.event_points` +): `letter_delivered +1` (Kappe 1/Tag), `large_request_done +2`, `large_request_failed −2`, `sent_away_rumor −2`, `kept_promise +1`, `public_duty +3`, `register_sold_rumor −1`, `case_reported +3`.
**Pietät** (`PietyConfig.events` +): `letter_read_sealed −1`, `letter_read_grave +1`, `letter_burned_asked +1`, `letter_burned_unasked −1`, `letter_buried +1`, `letter_answered +1`, `sent_away +3`, `kept_promise +3`, `made_public −1`, `soil_sold −1`, `register_sold −3`, `case_bribe −3`, `kladde_sold −8`, `case_to_ilse +2`, `stranger_refused +1`, `postage_paid +1`.
**Beziehung** (`RelationshipConfig.gains` +): `witness 2`, `confided 4`, `letter_delivered 3`, `errand_done 2`, `named_publicly −4`, `large_request_village 3`, `case_reported_fenner 4`, `case_reported_quast −6`, `register_sold_lenz −4`, `register_sold_fenner −2`, `seal_broken −3`.
**Geister:** neuer Pool `by_letter` („Du hast es mir vorgelesen. Sie schreibt immer noch so schief.“ · „Das war für Martha. Bring es ihr. Nein – lies es mir noch einmal.“); Grabbeigabe Brief ≤ +1 (Zier-Posten, gedeckelt wie Phase 3). Vorrang nach `lights` (Phase 8).
**Statistik** (`GameState.DEFAULT_STATS` +): `quest_steps`, `quest_choices`, `letters_found`, `letters_decided`, `letters_delivered`, `letters_read`, `letters_burned`, `letters_buried`, `letters_answered`, `post_received`, `errands_done`, `large_requests_done`, `large_requests_half`, `large_requests_failed`, `large_request_parts`, `stranger_talks`, `stranger_coins`, `coins_spent_post`.
**Münz-Zwecke** (`GameState.COIN_REASONS` +): `&"post"`. Einnahmen-Gründe: „Große Bitte: …“, „Botenlohn“, „Verkauf an den Herrn mit dem Koffer“.

### 2.10 Osric, Ilse, Veit, Hanne, Lambert, Jakob
- **Osric** (`carter.tres`, P6): `p9_intro` · bringt die Post für die Toten (§2.4.3) · Zeuge `e_quendel` · nimmt bei Ende A Johann mit, wenn Hanne nicht vorher kommt · D3 · nimmt Briefe in die Stadt mit (1 Münze: „Bis Ellbach. Von da läuft's allein.“).
- **Ilse** (`trader.tres`): ab `p9_open` neue Frage „Kennst du einen Brenneisen?“ → „Einer, der unter der Erde kauft und über der Erde zahlt. Schick ihn zu mir, wenn du ihn loswerden willst.“ · Ende K5 „Ilse“ · zur Liste: „Lichter. Ja. Lorenz hat sie gezählt. Ich hab ihm gesagt, er soll aufhören zu zählen und anfangen zu gehen.“ Ilse bleibt ohne Beziehung.
- **Veit:** Zeuge `e_open`; K3; trägt `lg_lambert`. **Hanne:** nimmt Post (1 Münze), bringt den Aschau-Brief, nimmt bei Ende A Johann über den Hügel mit („Ich nehm ihn bis zur Straße. Weiter tragen ihn seine Beine, sagt er. Ich glaub's ihm.“). **Lambert:** nur über Veit bzw. Fenners Protokoll. **Jakob:** E4; bei Ende A steht Gretes Grab auf seiner Liste, wenn der Spieler es wählt („Für den Sieber. Der hat mich immer gegrüßt.“).

### 2.11 Dialog-Leittexte (P6 schreibt aus, darf glätten; Ton: trocken-melancholisch, würdig)
**Johann Sieber**
- Begrüßung (am Grab, zu Grete): „So, Grete. Er ist wieder da. Er will was. Ich seh's ihm an.“
- Zeichen: „Da. Juckt nicht. Grete hatte so was nicht. Grete hatte nur Rücken.“
- H6, Ende A angeboten: „Fort? Ich war nie fort. Ich war einmal in Ellbach, da hat es geregnet.“ – mit dem Brief: „So einen hatte die Ida auch. Die ist gegangen. Na gut. Dann geh ich ein Stück.“
- H6, Ende B: „Neben Grete. Oder so nah, wie du kannst. Sie mag es nicht, wenn man drängelt.“
- H6, Ende C: „Zum Fenner? Der schreibt alles auf. Dann steht wenigstens was über mich in einem Buch.“
- letzter Abend (B): „Weißt du, was das Schlimme ist? Ich hab es nicht eilig. Und es hat es auch nicht eilig. Wir warten beide.“
**Cornelius Brenneisen**
- Erster Auftritt: „Brenneisen. Aus der Stadt. Ich störe nicht lange. Ich frage nur. Fragen kostet nichts, Antworten zahle ich.“
- Angebot Erde: „Eine Handvoll. Von einem, der noch keine Woche liegt. Für die Wissenschaft. Sie würden staunen, was die Erde weiß.“
- Gestellt (K3): „Ich habe den Mann für Nachrichten bezahlt, nicht für Leiber. Er hat es falsch verstanden. Leute vom Land verstehen Geld immer wörtlich.“
- Kladde: „Die Liste brauchen Sie nicht mehr. Sie wissen ja jetzt, was sie bedeutet. Ich nicht. Vierzig.“
- Abgang (Fenner): „Ich gehe. Aber die Stadt bleibt, Herr Totengräber. Die Stadt bleibt immer.“
**Lenz, Quast, Liesel** (H5, §2.2.6) · **Zeugen** (§2.2.4) · **Fenner** (Ende C): „Ein Licht, das keiner anzündet. Das schreibe ich auf. Was man aufschreibt, ist kein Gespenst mehr, sondern eine Akte.“
**Kapitel-Schlusszeilen** (Ende A): „Johann ist über den Hügel gegangen. Ob er angekommen ist, steht in keinem Brief, den du bekommen hast. Noch nicht.“ · (C): „Fenner hat jetzt ein Buch für Lichter. Es hat sechs Einträge. Lorenz hatte auch sechs.“ · (still): „Du hast die Liste gelesen und zugeklappt. Das Dorf hat sie nie gesehen. Das Licht schon.“

---

## 3. Architektur

### 3.1 Neue Knoten
**Systemknoten** (unter `WorldRoot/Systems`, vom Welt-Builder angelegt; keine neuen Autoloads):
| Knoten | Klasse | Gruppen | save_id / save_order |
|---|---|---|---|
| `Quests` | `Quests` | `quests`, `saveable` | `quests` / **81** |
| `WhoKnows` | `WhoKnows` | `who_knows`, `saveable` | `who_knows` / **82** |
| `Letters` | `Letters` | `letters`, `saveable` | `letters` / **83** |
| `Stranger` | `Stranger` | `stranger`, `saveable` | `stranger` / **84** |
`HillRequests` (80) bleibt und wird erweitert (§3.4). **Entitäten** – Friedhof: `npc_stranger_g` (außen am Tor, Region graveyard), `Desk` (Hütte, neue Prompts), `Stove` (Hütte, „Brief verbrennen“), Abschnitt-Erweiterung `linden_row4` (Plots `l_13…l_16`, 2 Hindernisse), großer Bogen an `NoticeBoard`. Dorf: `npc_stranger` (Region village), `npc_kin_sieber_v` (Bank vor dem Sieber-Haus), `KnockDoor` `door_sieber` (`src/entities/knock_door/*`), `SickLight` am Fenster des Sieber-Altenteils, `WatchSpot` `watch_sieber`, Nachtwächter-Laterne `ph_prop_watch_lantern` (Ende C), großer Bogen an `VillageBoard`, Wegpunkte `v_bridge_unload`, `v_inn_cellar_help` (Gaststube), `v_sieber_bench`.

### 3.2 Module & Besitz (Phase 9)
| Modul | Besitzt (Pfade) |
|---|---|
| **Lead** (W0 + laufend) | `project.godot`, `src/core/*` (EventBus, Database), alle **Datenklassen ✦**, alle **Stubs** (bis zur Übergabe), `tests/run_tests.gd`, `tests/framework/*`, `tests/fixtures/*` (inkl. **`saves_v7/*`**, `phase9/*`), `tests/integration/test_saves_v7_load.gd`, `tests/unit/test_phase9_scaffold.gd`, `docs/*`, `CLAUDE.md` |
| **P1 Quest-Kern & Vorhaben** | `src/systems/quests/{quests,quest_rules,quest_log}.gd` (neu), `src/systems/village/{orders,order_rules}.gd` (nur Kategorie `quest`, `max_active_quest`), `data/quests/{q_who_knows,q_letters,q_case}.tres` (Struktur: Schritte, Bedingungen, Wahlen; Texte P6), `data/config/{quest_config,orders_config}.tres`, `data/orders/oq_*.tres`, `tests/unit/{test_quests,test_quest_rules,test_quest_log,test_orders}.gd` |
| **P2 Größere Bitten** | `src/systems/hill_requests/{hill_requests,hill_rules}.gd` (Teile, Größe, Ort, neue Teil-Arten, halb erfüllt), `src/entities/{notice_board,village_board}/*` (nur großer Bogen und Karte), `src/systems/crafting/crafting_system.gd` (nur `EventBus.craft_finished` senden), `data/hill_requests/large/*`, `data/config/hill_requests_config.tres`, `tests/unit/{test_hill_rules,test_hill_large}.gd`, `tests/integration/{test_hill_requests,test_hill_requests_bot}.gd` (Messung §2.3.6) |
| **P3 Briefe & Botengänge** | `src/systems/letters/{letters,letter_rules}.gd` (neu), `src/systems/corpse/corpse_manager.gd` (nur `letter_id` bei der Lieferung), `src/systems/corpse/corpse_care.gd` (nur der Aufruf `Letters.on_found` im Schritt Taschen), `src/entities/{desk,stove}/*` (alle neuen Prompts, auch die von P4: Kladde lesen, Register vergleichen, Brief ohne Namen), `src/entities/grave/grave_plot.gd` (Prompts: Datum vergleichen → `WhoKnows`, Brief vorlesen, Brief ins Grab, Erde nehmen → `Stranger`), `src/systems/ghosts/ghost_mood.gd` (nur Brief-Beigabe, `by_letter`), `data/letters/*`, `data/items/*` (Phase-9-Items), `data/config/{letters_config,piety_config,reputation_config,ghost_config}.tres`, `data/ghosts/ghost_lines.tres`, `tests/unit/{test_letters,test_letter_rules,test_items_phase9}.gd`, `tests/integration/test_letters_flow.gd` |
| **P4 Hauptkette** | `src/systems/quests/who_knows/{who_knows,light_rules}.gd` (neu), `src/systems/night/{night_paths,night_path_rules}.gd` (nur `anchor_flag`, `cancel_flag`, `np_sieber`), `src/systems/visitors/visitors.gd` (nur `set_kin_interval`), `src/entities/knock_door/*` (neu), `data/quests/who_knows/*` (Liste, Einträge), `data/config/who_knows_config.tres`, `data/night/paths/np_sieber.tres`, `data/sections/linden_row4.tres`, `data/clearables/*` (Reihe 4), `tests/unit/{test_who_knows,test_light_rules,test_night_paths}.gd`, `tests/integration/test_who_knows_endings.gd` |
| **P5 Der Herr mit dem Koffer** | `src/systems/stranger/{stranger,stranger_rules}.gd` (neu), `data/stranger/*`, `data/config/stranger_config.tres`, `data/shops/*` (nur Ankaufpreise für Brenneisen), `tests/unit/{test_stranger,test_stranger_rules}.gd`, `tests/integration/test_stranger_chain.gd` |
| **P6 Dialog, Merkbuch, Geschichte & Speichern** | `data/dialogue/*` (alle bestehenden + neu `stranger`, `kin_sieber_v`, `sieber_door`, `witness_*`-Zeilen in den Bewohner-Dialogen), `data/npc/*_schedule.tres` (Brenneisen, Johann im Dorf, Abgang mit Hanne/Osric, Nachtwächter-Laterne), `src/systems/dialogue/{dialogue_conditions,dialogue_actions}.gd`, `src/systems/journal/journal_manager.gd` (Seite „Die Liste“, Brief-Abschriften), `src/systems/story/story_director.gd` (D3), `data/story/d3_sieber.tres`, `data/finds/f_d3_*.tres`, `data/journal/{clues,insights}/*` (Phase 9), `src/systems/npc_life/*` nur Daten `data/config/npc_life_config.tres` (Reaktionen, Launen-Regeln §2.2.8), `src/systems/save/{save_migration,save_file_io,save_manager}.gd`, `src/systems/game_state/game_state.gd`, alle Texte der Ketten in `data/quests/*` (Felder `title`, `hint`, `summary`, Wahl-Labels), `tests/unit/{test_dialogue,test_save,test_save_migration,test_story,test_journal,test_game_state}.gd`, `tests/integration/test_phase8_save_upgrade.gd` |
| **P7 Assets** | `tools/blender/{asset_stranger,asset_props_phase9}.py` (neu), `tools/blender/{asset_mourners,asset_character,asset_wanderers,asset_items}.py` (nur neue Clips bzw. Icons), `tools/blender/rig.py` (nur neue Pose-Helfer, additiv), `tools/blender/build_all.py`, `assets/models/**` (nur Phase-9-Dateien und re-exportierte Figuren mit Zusatz-Clips), `art_source/blender/**` (Phase 9), `tests/unit/test_assets_phase9.gd`, `docs/reviews/phase9_assets/*` |
| **W-Welt** (W2) | `data/world/graveyard_layout.json` (Reihe 4, Brenneisens Stehplatz, Bogen an der Torafel §4.6), `data/world/village_layout.json` (Sieber-Fenster, Klopftür, Bank, Beobachtungsplatz, Brückenplatz, Bogen an der Gemeindetafel), `data/world/interiors/inn_layout.json` (Brenneisens Tisch, Kellerplatz), `src/world/graveyard/*` (neu `graveyard_build_phase9.gd`, `graveyard_shots_phase9.gd`), `src/world/village/*` (`village_build_phase9.gd`, `village_shots.gd --phase9`), `src/world/interiors/*`, `tools/blender/asset_ground_graveyard.py` (nur Reihe 4), `tests/integration/{test_graveyard_world,test_village_world,test_phase9_loop,test_interiors}.gd`, `docs/reviews/phase9_round1/*` |
| **W-UI** (W2) | `src/ui/**` (neu `panels/{letter_panel,stranger_panel}.gd`, `panels/journal_pages_phase9.gd` (Vorhaben, Die Liste, Briefe), Erweiterung `hill_requests_panel.gd` (Teile), `hud/objective_resolver.gd` (Verfolgen, Teile), Abschluss-Panel, Tageszusammenfassung; `src/ui/map/*` Marker §7.6), `src/debug/*` (neu `debug_commands_phase9.gd`), `tests/unit/{test_ui_phase9,test_objective,test_map_phase9}.gd`, `tests/integration/test_ui_flow.gd` |
| **W-Ton** (W2, Agent 17) | `tools/audio/build_audio.py` (nur neue Cues), `assets/audio/**` (nur neue `ph_*`), `data/audio/*` (neue Regeln), `src/systems/audio/{audio_world,audio_events}.gd` (nur neue Emitter/Regeln), `tests/unit/test_audio_phase9.gd` |
| **W3 QA** | `tests/integration/{phase9_bot,test_phase9_playthrough,test_phase9_qa,test_save_fuzzer}.gd`, `docs/reviews/phase9_wip/*` |
| **Eingefroren** | `src/world/art_prototype/*`, Maler-Shader, `data/atmosphere/*`, `lib_faces.py` (nur benutzen), Rig (Knochenzahl), alle Gebäude und Innenräume außer `inn` (Tisch, Keller-Platz), alle Abschnitte außer Reihe 4, Dorf-Plan außer den Markern §4.6, Phase-8-Systeme außer den genannten Einzelfunktionen |

✦ **Datenklassen (W0, Lead):** `QuestConfig`, `QuestData`, `QuestStepData`, `QuestChoiceData`, `QuestEndingData`, `WhoKnowsConfig`, `LightListData`, `LightEntryData`, `LettersConfig`, `LetterData`, `StrangerConfig`, `StrangerOfferData`. Erweiterungen: `OrderData` (+ `CATEGORY_QUEST`, `parts`, `size`, `place`, `parts_in_order`; Teil-Arten §2.3.2), `OrdersConfig` (+ `max_active_quest`), `HillRequestsConfig` (+ `large_*`), `NightPathData` (+ `anchor_flag`, `cancel_flag`), `CorpseRecord` (+ `letter_id`), `ReputationConfig.event_points` (+ 8), `PietyConfig.events` (+ 16), `RelationshipConfig.gains` (+ 11), `GhostLines` (+ `by_letter`), `NpcLifeConfig.reactions` (+ Ereignisse §2.2.8).
Bei nur fünf Agents: **P1 + P4** (Hauptkette ist der erste Nutzer des Kerns), **P3 + P5** (Briefe und Brenneisen teilen Panels und Prompts), P2, P6, P7.

### 3.2.1 Klassen → Dateien
| Klasse | Datei | Art |
|---|---|---|
| `QuestConfig`, `QuestData`, `QuestStepData`, `QuestChoiceData`, `QuestEndingData` | `src/systems/quests/{quest_config,quest_data,quest_step_data,quest_choice_data,quest_ending_data}.gd` | ✦ |
| `Quests`, `QuestRules`, `QuestLog` | `src/systems/quests/{quests,quest_rules,quest_log}.gd` | Stub (P1) |
| `WhoKnowsConfig`, `LightListData`, `LightEntryData` | `src/systems/quests/who_knows/{who_knows_config,light_list_data,light_entry_data}.gd` | ✦ |
| `WhoKnows`, `LightRules` | `src/systems/quests/who_knows/{who_knows,light_rules}.gd` | Stub (P4) |
| `KnockDoor` | `src/entities/knock_door/knock_door.gd` (+ `.tscn`) | Stub (P4) |
| `LettersConfig`, `LetterData` | `src/systems/letters/{letters_config,letter_data}.gd` | ✦ |
| `Letters`, `LetterRules` | `src/systems/letters/{letters,letter_rules}.gd` | Stub (P3) |
| `StrangerConfig`, `StrangerOfferData` | `src/systems/stranger/{stranger_config,stranger_offer_data}.gd` | ✦ |
| `Stranger`, `StrangerRules` | `src/systems/stranger/{stranger,stranger_rules}.gd` | Stub (P5) |
| `LetterPanel`, `StrangerPanel`, `JournalPagesPhase9` | `src/ui/panels/*.gd` | W-UI |

### 3.3 EventBus – neue Signale (Ergänzung `src/core/event_bus.gd`)
```gdscript
# Ketten (Quests); state: &"opened" | &"step" | &"chosen" | &"ended"
signal quest_changed(quest_id: StringName, step_id: StringName, state: StringName)
# Hauptkette (WhoKnows); kind: &"matched" | &"witnessed" | &"marked" | &"departed"
signal light_entry_changed(entry_id: StringName, kind: StringName)
# Briefe (Letters); state: &"found" | &"posted" | &"delivered" | &"read" | &"read_grave" | &"answered" | &"burned" | &"buried" | &"received"
signal letter_changed(letter_uid: String, letter_id: StringName, state: StringName)
# Der Herr mit dem Koffer (Stranger); kind: &"arrived" | &"asked" | &"sold" | &"bribed" | &"case" | &"left" | &"expelled"
signal stranger_event(kind: StringName, detail: String)
# Größere Bitten (HillRequests): ein Teil erledigt; Werkbank & Co. (Crafting)
signal hill_request_part(request_id: StringName, part: int, done: bool)
signal craft_finished(station_id: StringName, recipe_id: StringName, amount: int)
```
Regel wie Phase 3–8: **Listener ändern keinen fremden Spielzustand** (ein System darf auf ein Signal hin nur seinen eigenen Zustand fortschreiben, wie `HillRequests` seit Runde 6). Wer fremden Zustand ändert, ruft direkt auf: Dialog → `Quests.choose/note`, `WhoKnows.witness`, `Letters.decide`, `Stranger.answer/sell/resolve`; Prompts (`Desk`, `GravePlot`, `Stove`, `KnockDoor`) → `WhoKnows.read_kladde/compare_register/compare_grave/post_letter`, `Letters.decide`, `Stranger.take_soil`; `Quests` hört auf `order_changed`, `clue_found`, `insight_unlocked`, `letter_changed`, `light_entry_changed`, `hill_request_changed` und prüft Schritte (`QuestRules.step_complete`) → `Quests.apply_choice` → `DialogueActions.run(choice.actions)` → `Relationships.add`, `Reputation.event`, `Piety.event`, `GameState.set_flag`, `Visitors.add_goodwill`; `WhoKnows.apply_morning` (Frist) → `Quests.choose(…, fallback)`; `WhoKnows` (Ende A) → Npc-Laufzeitplan Abgang, `GameState.set_flag(sieber_gone)`; `NightPaths.apply_minute` (`np_sieber`) → `GameState.set_flag(sieber_dead)`; `StoryDirector` liest `sieber_dead` (D3); `CorpseManager` (Lieferung) → `Letters.assign(record)`; Untersuchung Taschen → `Letters.on_found`; `HillRequests` (neue Teil-Arten) → eigener Zustand, `hill_request_part`; `Crafting` sendet `craft_finished`. `coins_spent` erhöht `stats.coins_spent` im Sender über `GameState.note_coins_spent` (Postgeld `&"post"`).

### 3.4 Logik-Klassen (Signaturen = Vertrag)

**Quest-Kern (P1)**
```gdscript
class_name QuestConfig extends Resource              # ✦ data/config/quest_config.tres
@export var open_flag: StringName = &"p9_open"; @export var open_day_flag: StringName = &"p9_open_day"
@export var unlock_flag: StringName = &"who_comes_up_complete"; @export var intro_minute: int = 360
@export var chapter_id: StringName = &"who_knows_when"; @export var goal_flag: StringName = &"who_knows_when_complete"
@export var goal_main: StringName = &"q_who_knows"; @export var goal_letters: StringName = &"q_letters"
@export var goal_letters_step: StringName = &"l4"; @export var goal_letters_decided: int = 5; @export var goal_large_requests: int = 2
@export var max_pinned: int = 1
class_name QuestData extends Resource                # ✦ data/quests/<id>.tres
@export var id: StringName; @export var kind: StringName = &"side"      # &"main" | &"side"
@export var title: String; @export var summary: String; @export var giver: StringName = &""
@export var open_conditions: PackedStringArray = []   # Dialog-Syntax
@export var steps: Array[QuestStepData] = []; @export var endings: Array[QuestEndingData] = []
@export var order: int = 0
class_name QuestStepData extends Resource            # ✦ Unterressource
@export var id: StringName; @export var title: String; @export var hint: String   # Merkbuch + HUD
@export var complete_on: StringName                  # &"flag" | &"clue" | &"insight" | &"order" | &"note" | &"choice" | &"ending"
@export var complete_ids: Array[StringName] = []     # Flags / Hinweise / Aufträge / Notiz-Schlüssel
@export var complete_count: int = 0                  # 0 = alle; sonst ≥ n (Notizen: verschiedene Argumente)
@export var order_ids: Array[StringName] = []        # Aufträge der Kategorie quest, die mit dem Schritt angeboten werden
@export var choices: Array[QuestChoiceData] = []
@export var deadline_flag: StringName = &""; @export var deadline_offset: int = 0; @export var fallback_choice: StringName = &""
class_name QuestChoiceData extends Resource          # ✦
@export var id: StringName; @export var label: String; @export var conditions: PackedStringArray = []
@export var block_text: String = ""                  # gedimmt mit Grund (Ende A ohne Brief)
@export var actions: PackedStringArray = []          # DialogueActions-Syntax (rel_add, rep_event, piety_event, set_flag, goodwill …)
@export var ending: StringName = &""                 # setzt das Ende der Kette (sonst nächster Schritt)
class_name QuestEndingData extends Resource          # ✦
@export var id: StringName; @export var title: String; @export var summary: String
@export var flag: StringName; @export var settle_on: StringName = &""   # Flag, mit dem das Ende „abgeschlossen“ ist (sieber_gone / d3 bestattet)
@export var closing_line: String
class_name QuestRules extends RefCounted
static func step_complete(step: QuestStepData, state: Dictionary, tree: SceneTree) -> bool
static func next_step(quest: QuestData, done: Array[StringName]) -> QuestStepData
static func deadline_day(step: QuestStepData) -> int    # aus GameState-Flag + Offset; −1 = keine
static func choice_block_reason(choice: QuestChoiceData, context: Dictionary) -> String
class_name Quests extends Node                       # Gruppe quests, saveable quests / 81
func is_open() -> bool; func open_day() -> int
func apply_morning(day: int) -> void                 # 06:00: p9_open (idempotent), Fristen, Aufträge der Schritte anbieten
func post_load() -> void                             # v7 mit who_comes_up_complete → p9_open sofort
func state(quest_id: StringName) -> StringName       # &"" | &"open" | &"ended" | &"settled"
func current_step(quest_id: StringName) -> StringName; func steps_done(quest_id: StringName) -> Array[StringName]
func choice_of(quest_id: StringName, step_id: StringName) -> StringName; func ending(quest_id: StringName) -> StringName
func choose(quest_id: StringName, step_id: StringName, choice_id: StringName) -> bool
func note(key: StringName, arg: String) -> void; func notes(key: StringName) -> PackedStringArray
func pin(entry_id: StringName) -> void; func pinned() -> StringName
func check_goal() -> bool; func goal_progress() -> Dictionary   # {main, letters_step, letters_decided, large}
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
class_name QuestLog extends RefCounted               # Leser für das Merkbuch „Vorhaben“ und das HUD
static func entries(tree: SceneTree) -> Array[Dictionary]   # {group, id, title, giver, line, days_left, steps, pinned}
static func objective(tree: SceneTree) -> Dictionary        # verfolgter Eintrag → HUD-Zeile
# OrderData ✦ + const CATEGORY_QUEST := &"quest"; Orders (P1): Kategorie quest zählt getrennt (OrdersConfig.max_active_quest 3),
#   nie für village/stats.orders_done; Botengänge/Abende/Koffer sind Aufträge dieser Kategorie
```

**Hauptkette (P4)**
```gdscript
class_name WhoKnowsConfig extends Resource           # ✦ data/config/who_knows_config.tres
@export var open_light_offset: int = -12; @export var death_offset: int = 21; @export var decide_offset: int = 17
@export var light_flag: StringName = &"q_light_day"; @export var marked_flag: StringName = &"q_sieber_marked"
@export var kin_id: StringName = &"kin_sieber"; @export var house: StringName = &"house_sieber"
@export var daily_visit_from_step: StringName = &"h4"; @export var bench_window: Vector2i = Vector2i(840, 960)
@export var kladde_minutes: int = 20; @export var register_minutes: int = 30; @export var grave_minutes: int = 5
@export var letter_minutes: int = 20; @export var letter_item: StringName = &"ink"
@export var depart_with_peddler_minute: int = 980; @export var depart_with_carter_minute: int = 600
@export var witness_count: int = 3; @export var reserve_section: StringName = &"linden_row4"
class_name LightEntryData extends Resource           # ✦ Unterressource
@export var id: StringName; @export var initial: String; @export var ink: StringName = &"fresh"   # &"old" | &"fresh"
@export var story_id: StringName = &""; @export var fixed_text: String = ""   # e_dorn: „2. Julmond 1833“
@export var open: bool = false; @export var witness_npc: StringName; @export var witness_clue: StringName
class_name LightListData extends Resource            # ✦ data/quests/who_knows/list.tres
@export var entries: Array[LightEntryData] = []; @export var footer: String; @export var struck: String
class_name LightRules extends RefCounted
static func light_day(entry: LightEntryData, tree: SceneTree, cfg: WhoKnowsConfig) -> int   # Tod − 21; fest/fehlend → INT_MIN
static func entry_text(entry: LightEntryData, tree: SceneTree, cfg: WhoKnowsConfig) -> String  # über StoneCalendar.date_text
static func open_light_day(open_day: int, cfg: WhoKnowsConfig) -> int
static func death_day(light_day: int, cfg: WhoKnowsConfig) -> int; static func decide_day(light_day: int, cfg: WhoKnowsConfig) -> int
class_name WhoKnows extends Node                     # Gruppe who_knows, saveable who_knows / 82
func read_block_reason(inv: Inventory) -> String; func read_kladde() -> void          # H1 (Desk, TimedAction danach)
func compare_register() -> PackedStringArray         # H2: zugeordnete Einträge
func can_compare(grave_id: String) -> bool; func compare_grave(grave_id: String) -> bool
func matched(entry_id: StringName) -> bool; func witness(entry_id: StringName) -> bool   # Dialog-Aktion
func witnessed() -> Array[StringName]
func mark_seen() -> void                             # H4 (Johann zeigt es)
func letter_posted() -> bool; func post_letter(inv: Inventory) -> bool   # Ende A: Brief an die Tür (nachts)
func apply_morning(day: int) -> void                 # Frist → still; Abgang (Hanne/Osric), Laufzeit-Zeitpläne
func depart_plan() -> Dictionary                     # {day, minute, with: &"peddler" | &"carter"} | {}
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
# NightPathData ✦ + @export var anchor_flag: StringName = &""   # Offsets relativ zum Tag in diesem Flag ("" = p8_open_day)
#                 + @export var cancel_flag: StringName = &""   # gesetzt → die Folge läuft nicht (Ende A)
# Visitors (P4): + func set_kin_interval(kin_id: StringName, days: int) -> void   # gespeichert in visitors.kin_interval
# KnockDoor: „[E] Bei den Siebers anklopfen“ → Dialog sieber_door; nachts mit nameless_letter: „[E] Brief an die Tür stecken“
```

**Briefe (P3)**
```gdscript
class_name LettersConfig extends Resource            # ✦ data/config/letters_config.tres
@export var open_flag: StringName = &"p9_open"; @export var forced_after_open: int = 3
@export var forced_ids: Array[StringName] = [&"lp_l1_carter", &"lp_l2_sister", &"lp_l3_burn"]
@export var post_offsets: PackedInt32Array = [3, 6, 9]; @export var aschau_letter: StringName = &"lpo_aschau"
@export var postage: int = 1; @export var read_grave_minutes: int = 10; @export var answer_minutes: int = 20
@export var burn_minutes: int = 2; @export var bury_minutes: int = 2; @export var answer_item: StringName = &"ink"
@export var rep_cap_day: int = 1; @export var reply_after_days: int = 1
class_name LetterData extends Resource               # ✦ data/letters/<id>.tres
@export var id: StringName; @export var kind: StringName = &"pocket"   # &"pocket" | &"post"
@export var outside: String; @export_multiline var text: String; @export var sealed: bool = true
@export var sender: String; @export var recipient: StringName = &""   # npc_id | kin_id | &"town" | &"none" | &"grave"
@export var asks: StringName = &""                   # &"" | &"burn" | &"grave" | &"read"
@export var conditions: PackedStringArray = []       # Pool-Bedingungen (robber_fate:let_go …)
@export var choice_actions: Dictionary[StringName, PackedStringArray] = {}   # deliver/read/read_grave/answer/burn/bury → Aktionen
@export var choice_texts: Dictionary[StringName, String] = {}
@export var reply_text: String = ""; @export var story_id: StringName = &""   # post: an welchen Toten
class_name LetterRules extends RefCounted
static func pick(seed: int, day: int, used: Array[StringName], pool: Array[LetterData], tree: SceneTree) -> StringName
static func choice_block_reason(letter: LetterData, choice: StringName, context: Dictionary) -> String
static func piety_event(letter: LetterData, choice: StringName) -> StringName
class_name Letters extends Node                      # Gruppe letters, saveable letters / 83
func assign(record: CorpseRecord) -> void            # bei der Lieferung (forced / Pool)
func on_found(corpse_id: String, inv: Inventory) -> String   # Taschen → Uid
func letter(uid: String) -> LetterData; func state(uid: String) -> StringName; func corpse_of(uid: String) -> String
func choices(uid: String, context: Dictionary) -> Array[Dictionary]   # {id, label, reason}
func decide(uid: String, choice: StringName, context: Dictionary) -> bool
func post_today(day: int) -> Array[String]           # Post für die Toten (Osric 07:40, Hanne)
func give_to_carrier(uid: String, carrier: StringName, inv: Inventory) -> bool   # 1 Münze, &"peddler" | &"carter"
func decided_count() -> int; func delivered_count() -> int
func apply_morning(day: int) -> void                 # Post, Gegenbriefe
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
# CorpseRecord ✦ + var letter_id: StringName = &""   # tolerant; CorpseManager (P3) ruft Letters.assign ab p9_open
```

**Der Herr mit dem Koffer (P5)**
```gdscript
class_name StrangerConfig extends Resource           # ✦ data/config/stranger_config.tres
@export var npc_id: StringName = &"stranger"; @export var arrive_offset: int = 2; @export var return_every: int = 5; @export var stay_days: int = 3
@export var gate_window: Vector2i = Vector2i(850, 930); @export var inn_window: Vector2i = Vector2i(1080, 1260)
@export var question_coin: int = 1; @export var bribe_coins: int = 15; @export var case_tip: int = 2; @export var kladde_price: int = 40
@export var specimen_factor: float = 1.5; @export var rumor_delay_days: int = 2
@export var questions: PackedStringArray = []        # 6 Fragen (Text P6)
class_name StrangerOfferData extends Resource       # ✦ data/stranger/offers/<id>.tres
@export var id: StringName; @export var label: String; @export var item: StringName; @export var price: int
@export var conditions: PackedStringArray = []; @export var actions: PackedStringArray = []   # Folgen (Pietät, Gerede, Flags)
@export var note: String                             # Zeile im Panel („Lenz wird es erfahren.“ – ohne Zahl)
class_name StrangerRules extends RefCounted
static func visit_days(open_day: int, cfg: StrangerConfig) -> PackedInt32Array
static func present(day: int, minute: int, region: StringName, state: Dictionary, cfg: StrangerConfig) -> bool
static func offer_block_reason(offer: StrangerOfferData, inv: Inventory, context: Dictionary) -> String
class_name Stranger extends Node                     # Gruppe stranger, saveable stranger / 84
func present(region: StringName) -> bool; func gone() -> bool
func answer(kind: StringName) -> void                # &"frank" | &"evade" | &"refuse"
func offers(inv: Inventory) -> Array[Dictionary]; func sell(offer_id: StringName, inv: Inventory) -> bool
func take_soil(grave_id: String, inv: Inventory) -> bool
func bribe(accept: bool, inv: Inventory) -> void; func case_holder() -> StringName   # &"inn" | &"player" | &"fenner" | &"stranger"
func resolve(choice: StringName) -> void             # &"fenner" | &"deal" | &"ilse"
func apply_morning(day: int) -> void; func apply_minute(day: int, minute: int) -> void
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
```

**Größere Bitten (P2)**
```gdscript
# OrderData ✦ + @export var parts: Array[Resource] = []   # Inhalt: OrderData (Teile; Selbstbezug als Resource typisiert, W0 prüft)
#             + @export var size: StringName = &""          # &"" klein | &"large"
#             + @export var place: StringName = &"gate"     # &"gate" | &"village"
#             + @export var parts_in_order: bool = false
#   Teil-Arten zusätzlich zu Runde 6: craft, gather, ghosts, visit, meet, devotion, flowers (§2.3.2)
# HillRequestsConfig ✦ + large_start_day 2, large_slots_gate 1, large_slots_village 1, large_max_active 1,
#   large_refill_days_early 1, large_refill_days_village 2, large_offer_days 2, large_fail_rep -2, large_reward_rel 3, half_ratio 0.5
# HillRequests (P2): + func parts_done(id: StringName) -> Array[bool]; func large_board(place: StringName) -> Array[StringName]
#   + func visit_block_reason(id: StringName, player: Player) -> String; func start_visit(id: StringName) -> void   # Teil visit
#   + func half_done(id: StringName) -> bool; save_state + {large_board, parts, large_refill, large_ended, ghost_night}
# HillRules (P2): + static func part_done(part: OrderData, event: StringName, args: Dictionary, state: Dictionary) -> bool
#   + static func large_offerable(o: OrderData, context: Dictionary) -> bool   # jedes Teil lösbar
```

**Dialog, Geschichte & Speichern (P6)**
```gdscript
# DialogueConditions (P6) +: p9_open · quest:<id>:<state> · quest_step:<id>:<step> · quest_done:<id>:<step>
#   · quest_choice:<id>:<step>:<choice> · quest_ending:<id>:<end> · light:<entry>:<matched|witnessed> · sieber_marked
#   · sieber_gone · letter_for:<npc> (der Spieler hält einen Brief an den Sprecher) · post_for:<kin> · letter_posted
#   · stranger_here · stranger_step:<k> · stranger_ending:<e> · large_ready:<giver> · confided:<npc>
# DialogueActions (P6) +: quest_note:<key>:<arg> · quest_choose:<quest>:<step>:<choice> · witness:<entry> · mark_seen
#   · letter_deliver · letter_read_aloud · letter_post:<carrier> · stranger_answer:<kind> · stranger_offers
#   · stranger_bribe:<yes|no> · stranger_resolve:<e> · large_turn_in:<giver> · rep_event:<id> · piety_event:<id> · goodwill:<kin>:<n>
# StoryDirector (P6): D3 über due_flag sieber_dead + requires_flag q_sieber_dies, Reservierung in linden_row4
# JournalManager (P6): Seite „Die Liste“ (Einträge über LightRules), Brief-Abschriften („Briefe“), i_light_before (any_clues 3 von 5)
# SaveMigration (P6): CURRENT := 8; + static func migrate_7_to_8(state: Dictionary, meta: Dictionary) -> Dictionary
#   V8_EMPTY_NODES := ["quests", "who_knows", "letters", "stranger"]; V8_NEW_STATS (§2.9); V8_RECORD_DEFAULTS := {"letter_id": ""}
# SaveFileIO.FORMAT_VERSION = 8; read_doc akzeptiert 1…8
# GameState.DEFAULT_STATS + die 18 Stats aus §2.9; COIN_REASONS + &"post"
```

### 3.5 Database (Lead)
Neue Listen: `quest(s)` (`data/quests`, nach `order`), `letter(s)` (`data/letters`, nach id; `pocket_letters()` / `post_letters()`), `stranger_offer(s)` (`data/stranger/offers`, nach id), `large_request(s)` (`data/hill_requests/large`, getrennt von `hill_requests()` – die kleinen bleiben, wie sie sind). Leere/fehlende Ordner = leere Listen.

### 3.6 Eingaben
Keine neuen Tasten. Alles läuft über [E], Dialoge und Panels; im Merkbuch „Verfolgen“ per Knopf bzw. Enter.

---

## 4. Welt, Orte & Sichtprüfungen (W-Welt)

### 4.1 Grundsatz
Phase 9 ist eine Erzähl- und Aufgaben-Phase: **kein neues Gebäude, kein neuer Raum, kein neuer Abschnitt außer der vierten Reihe.** Jeder Eingriff steht in §4.6 und wird gegen `tests/fixtures/phase9/{layout_p8,village_layout_p8}.json` (bytegleich zum Referenzstand) geprüft.

### 4.2 Die vierte Reihe im Lindenacker (Bestätigung §14.3)
- Vier Plots `l_13…l_16` am Südrand, Abstand wie Reihe 3 (Muster PHASE8 §4.4); der Südzaun rückt **3,2 m** nach Süden; der Waldweg des Nachtgräbers (PHASE8 §4.5) wird um dieselbe Strecke verlängert (nur Wegpunkte `robber_fence_out`, `robber_far`), ein Waldbaum wird versetzt (W-Welt wählt, Sichtprüfung). Hindernisse: 1 Stumpf, 1 Brombeere.
- Bau-Maske wächst um Reihe 4 (im v7-Stand liegt dort keine Zier).

### 4.3 Bei den Siebers (Dorf)
- **Fenster des Altenteils** (Obergeschoss, zum Anger): Marker `win_sieber_attic` mit `SickLight` (Muster Phase 8, 2,2 / 6 m), sichtbar vom Brunnen (Veits Bank) und vom Beobachtungsplatz `watch_sieber`.
- **Klopftür** `door_sieber` an der vorhandenen Haustür (kein Innenraum): `KnockDoor` mit `Interactable`, Klopfgeräusch, Anna antwortet als Stimme (Sprechblase an der Tür).
- **Bank** `v_sieber_bench` vor dem Haus (bestehendes Bank-Modell aus Phase 7, 1 Stück).

### 4.4 Der Herr mit dem Koffer
- Friedhof: Stehplatz `stranger_gate` **außen** am Tor, östlich neben Veits Platz (nie auf demselben Fleck wie Veit oder Hanne; Sichtprüfung mit allen dreien gleichzeitig). Dorf: Weg Holderbrücke → Holderkrug; Tisch in der Gaststube (`inn_layout.json`, freier Ecktisch).

### 4.5 Wege der Abreise (Ende A)
- Mit Hanne: Brunnen → Kutschweg → Friedhofstor (15:40–16:20 wie Hanne) → **Waldweg nach Westen** (Hannes bestehender Weg); Johann geht 1,5 m hinter ihr (eigener Laufzeit-Plan, gleiche Wegpunkte, versetzte Startzeit).
- Mit Osric: Johann sitzt auf der Ladefläche (Pose `sit_cart`, Kindmesh `bundle`), Osric fährt um 10:00 den Kutschweg hinunter (bestehende Abfahrt).

### 4.6 Eingriffe am Friedhof und im Dorf (vollständig)
| # | Ort | Eingriff |
|---|---|---|
| L16 | Lindenacker | Plots `l_13…l_16`, Pfosten der Reihe |
| L17 | Lindenacker | Südzaun 3,2 m nach Süden, Zaunenden |
| L18 | Wald südlich | ein Waldbaum versetzt; Räuberweg-Wegpunkte verlängert |
| L19 | Lindenacker | Stumpf + Brombeere (Hindernisse Reihe 4) |
| G3 | Torafel | großer Bogen `ph_notice_sheet` (Kindmesh, nur sichtbar mit großer Bitte) |
| G4 | außen am Tor | Stehplatz `stranger_gate` (nur Wegpunkt) |
| D8 | Sieber-Haus | Fenster-Marker + `SickLight`, `KnockDoor`, Bank `v_sieber_bench`, `watch_sieber` |
| D9 | Gemeindetafel | großer Bogen (Kindmesh) |
| D10 | Holderbrücke | Wegpunkt `v_bridge_unload` (Steine abladen) |
| D11 | Gaststube | Brenneisens Tisch (Requisiten Buch, Glas), Platz `v_inn_cellar_help` an der Kellerluke |
| D12 | Sieber-Haustür | Laterne des Nachtwächters `ph_prop_watch_lantern` (nur Ende C, Nacht) |

### 4.7 Sichtprüfung und Wege (Kamerastrahl-Test, Pflicht; Verfahren Phase 6 §4.5)
- Reihe 4 (Zoom 12/22/24), Brenneisen am Tor neben Veit und Hanne, Sieber-Fenster vom Brunnen und vom Beobachtungsplatz, Johann auf der Bank, der Abgang mit Hanne bis zum Waldrand, Johann auf Osrics Karren, die Laterne an der Tür, der große Bogen an beiden Tafeln. Jede neue Route (Johann, Brenneisen, Bitt-Wegpunkte) frei (Physik-Test wie G8 Runde 5).

### 4.8 Licht
- Sieber-Fenster wie das Krankenlicht (warm, kein Schatten); das „falsche“ Licht von H4 ist nicht im Bild (es liegt zwölf Tage zurück). Nachtwächter-Laterne: ein Omni ohne Schatten aus dem bestehenden Pool. Keine neuen Schatten-Lichter.

---

## 5. Speichern & Migration (P6)

### 5.1 Format v8 (Ergänzungen)
```
format_version: 8
data.autoloads.GameState.stats   + quest_steps, quest_choices, letters_found, letters_decided, letters_delivered, letters_read,
                                   letters_burned, letters_buried, letters_answered, post_received, errands_done, large_requests_done,
                                   large_requests_half, large_requests_failed, large_request_parts, stranger_talks, stranger_coins,
                                   coins_spent_post
data.autoloads.GameState.flags   + p9_open, p9_open_day: 63, linden_row4_granted, kladde_read, q_light_day: 51, q_sieber_marked,
                                   q_confide_<npc|none>, q_end_<away|stay|public|silent>, q_sieber_dies, sieber_gone, sieber_dead,
                                   insight_light_before, fenner_lightbook, case_end_<fenner|deal|ilse>, case_bribe, kladde_sold,
                                   lorenz_letter_<kept|liesel|burned|opened>, who_knows_when_complete, clue_c_q_* (bestehendes Muster)
data.nodes.corpse_manager.records[] + letter_id: "lp_l1_carter"
data.nodes.graveyard.graves[]    + l_13…l_16 (aus dem Layout, LOCKED bis geräumt)
data.nodes.quests                {"open_day": 63, "open": ["q_who_knows", "q_letters"], "step": {"q_who_knows": "h3"},
                                  "done": {"q_who_knows": ["h1", "h2"]}, "step_day": {…}, "choices": {"q_who_knows": {"h5": "confide_washer"}},
                                  "ending": {}, "settled": [], "notes": {"date_grave": ["e_ott", "e_quendel"]}, "pinned": "q_who_knows",
                                  "goal_done": false}
data.nodes.who_knows             {"light_day": 51, "matched": ["e_ott"], "witnessed": ["e_quendel"], "marked_seen": false,
                                  "letter_posted": false, "depart": {}, "fallback_day": 0}
data.nodes.letters               {"next_uid": 4, "records": {"lt_0001": {"id": "lp_l1_carter", "corpse": "corpse_0041", "state": "delivered",
                                  "day": 65}}, "forced_used": 1, "post_done": [3], "replies": [{"uid": "lt_0003", "due": 69}], "rep_day": 65}
data.nodes.stranger              {"visits": [65, 70], "answers": ["frank"], "sold": {"soil": 1}, "bribe": "", "case": "inn",
                                  "ending": "", "rumors": [{"event": "register_sold", "day": 68}]}
data.nodes.hill_requests         + {"large_board": {"gate": ["hrl_ferry_graves"], "village": []}, "parts": {"hrl_ferry_graves": [true, false, false]},
                                  "large_refill": {"gate": [64]}, "large_ended": {…}, "ghost_night": {"night": 64, "count": 1}}
data.nodes.visitors              + "kin_interval": {"kin_sieber": 1}
```
Nicht gespeichert: Laufzeit-Zeitpläne (Johann, Brenneisen, Abgang; aus Plan + Uhr), der Inhalt der Liste (aus Records berechnet), `QuestLog` (Leser). Speichern ist während einer TimedAction gesperrt (wie bisher), sonst überall erlaubt – auch während Johann mit Hanne geht oder Brenneisen am Tor steht: Nach dem Laden stehen alle dort, wo Plan und Uhr sie hinsetzen (bitgleich).

### 5.2 Migration v7 → v8 (Phase-8-Spielstände müssen laden)
`SaveMigration.migrate_7_to_8` läuft in `read_doc` nach `decode_state` (Kette 1→…→8), rein, auf einer tiefen Kopie.
1. **Leichen:** alle Records + `letter_id ""` (Phase-4-Briefe bleiben Hinweise).
2. **Gräber:** die Plots `l_13…l_16` fehlen und entstehen beim Laden aus dem Layout als `LOCKED` (tolerante Graveyard-Regel).
3. `nodes.quests`, `who_knows`, `letters`, `stranger` = `{}` über `V8_EMPTY_NODES`, eingefügt erst, wenn W-Welt die Knoten anlegt (wie Phase 4–8).
4. `nodes.hill_requests`: bleibt (`save_optional`); fehlende `large_*`-Schlüssel lädt `HillRequests.load_state` still als Grundzustand. Ein Stand ohne den Knoten (vor G8 Runde 6) lädt wie bisher.
5. Stats (§2.9) = 0. Flags: keine. `p9_open` setzt `Quests.post_load`, wenn `who_comes_up_complete` gilt.
6. Spieler, Inventare, Aufträge, Freundschaft, Besucher, Lehrling: unverändert (`visitors.kin_interval` fehlt = leer).

### 5.3 Fixtures (W0, Lead, vor jeder Phase-9-Code-Änderung auf dem Referenzstand über `Phase8Bot`/`HillBot` + echte Systeme)
`tests/fixtures/saves_v7/`:
- `slot_p8_day63_kindly.json`: `kindly8`-Endstand, 07:00 Tag 63, `who_comes_up_complete`, Lindenacker voll, ≈ 70 Münzen. Start für `kindly9`, `stay9`, `public9`, `silent9`, `letters9`, `lazy9`, `save_load9`.
- `slot_p8_day63_anatomist.json`: `anatomist8`-Endstand (Präparate im Inventar, `anatomy_known`). Start für `trader9`.
- `slot_p8_day63_letgo.json`: `night8b`-Endstand (Lambert laufen gelassen, `c_n_robber`) – K3 über Lambert, `lg_lambert`.
- `slot_p8_founder.json`: `founder8`-Endstand (neues Spiel). Start für `founder9`.
- `slot_p8_mid.json`: mitten in Phase 8, Kapitel offen (Phase 9 bleibt zu, große Bitten laufen).
- `slot_p8_day2_hill.json`: neues Spiel Tag 2, 10:00, zwei kleine Bitten angeheftet, eine angenommen (Runde-6-Zustand).
- `slot_p8_day30_village_hill.json`: Dorf offen, eine kleine Bitte angenommen.
Dazu `make_v7_saves.gd` + `_driver.gd` (historisches Werkzeug) und `tests/fixtures/phase9/{layout_p8,village_layout_p8}.json`. Lade-Wächter `tests/integration/test_saves_v7_load.gd` (Lead). v6…v1-Fixtures laden weiter (Kette bis 8).

---

## 6. Debug-Konsole (W-UI) – neue Befehle
`p9 open` · `quest <id> [step]` (Schritt setzen) · `quest choose <quest> <step> <choice>` · `ending <away|stay|public|silent>` · `kladde` (Liste anzeigen) · `witness <entry>` · `match <entry>` · `sieber <marked|leave|die|now>` · `lightday <n>` · `letter <id> [corpse]` (Brief ins Inventar) · `letters` · `post <id>` · `stranger <arrive|now|step <k>|gone>` · `large <id>` (anheften) · `large part <id> <n>` · `large board` · `goal9` · `vis9`. Bestehend und weiter nutzbar: `p8 open`, `nightpath`, `tp`, `time`, `rel`, `fest`.

---

## 7. UI (W-UI)

### 7.1 Merkbuch „Vorhaben“ (neuer Reiter, vor „Aufträge“)
Pergamentseite, links die Gruppen (§2.1) mit Einträgen, rechts der gewählte Eintrag: Titel, Geber, Zusammenfassung in zwei Sätzen, **erledigte Schritte als Sätze** (Tinte), der aktuelle mit Hinweis (Bleistift, „Frag die, die nachts die Fenster sehen.“), Frist, zukünftige als „…“; Wahlen als Satz („Du hast es Liesel gesagt.“), das Ende mit Titel und Schlusszeile. Knopf „Verfolgen“ (ein Eintrag; „Nicht mehr verfolgen“). Maus + Tastatur (↑/↓, Enter, Tab zwischen Spalten). Sichtbar ab der ersten großen Bitte; die Ketten-Gruppen ab `p9_open`.

### 7.2 Merkbuch „Die Liste“ (Seite der Hauptkette) und „Briefe“
- **Die Liste:** die Rückseite der Kladde als Abbild (zwei Tinten), sechs Zeilen: Datum · Buchstabe · Name (sobald zugeordnet) · Zeuge (Häkchen, sobald gefragt); unten „Licht. Drei Wochen.“ und der durchgestrichene Satz. Knopf „Niemandem sagen“ (H5) erst nach H4.
- **Briefe:** Abschriften gelesener Briefe, Zustand je Brief („Rosine hat ihn hinter den Schanktisch gehängt.“), offene Briefe im Inventar mit „Entscheiden …“.

### 7.3 Brief-Karte (`&"letter"`, rechts angedockt)
Aufschrift in Handschrift-Farbe, bei geöffneten Briefen der Text; darunter die erlaubten Wahlen als Knöpfe mit Ort („Zustellen – Rosine im Holderkrug“, „Am Grab vorlesen – Lindenacker, l_14“, „Verbrennen – Ofen in der Hütte“); gedimmte Wahlen mit Grund („Versiegelt. Er ist nicht an dich.“ als Hinweis, nicht als Sperre). Keine Zahlen.

### 7.4 Panel des Herrn mit dem Koffer (`&"stranger"`, rechts angedockt)
Kopf „C. Brenneisen, Commissionär“, seine Angebote als Karten (Ding, Preis, eine Zeile Folge ohne Zahl: „Lenz wird es erfahren.“), „Verkaufen“/„Nein“. Kein Verhandeln, kein Feilschen-Minispiel.

### 7.5 HUD und Prompts
- **Zielzeilen** (`ObjectiveResolver`): verfolgter Eintrag zuerst, sonst nach den Pflichten des Tages: „Sprich mit Osric“ · „Lies Lorenz' Kladde (Hütte)“ · „Die Liste: 3/5 Gräber verglichen“ · „Wer hat das Licht gesehen? 2/3“ · „Wer ist ‚S.‘?“ · „Wem sagst du es?“ · „Was wird aus Johann? (bis morgen Abend)“ · „Johann Sieber – bestatten“ · „Ein Herr wartet am Tor“ · „Ein Brief: an Rosine Wackernagel“ · „Bitte: Die Gräber der Fähre – Zwei Zierstücke (1/2)“ · „Wer weiß, wann? 2/3“.
- **Notizen:** „Osric hat Post für Marthe Quendel.“ · „Ein Herr in einem Stadtrock wartet am Tor.“ · „Die Gräber der Fähre: 2 von 3.“ · „Am Hüttentür steckt ein Zettel.“ · „Bei den Siebers brennt Licht.“ (B/C, Nacht).
- **Prompts:** „[E] Lorenz' Kladde lesen (20 Min)“ · „[E] Grabregister mit der Liste vergleichen (30 Min)“ · „[E] Datum vergleichen (5 Min)“ · „[E] Bei den Siebers anklopfen“ · „[E] Brief ohne Namen schreiben (20 Min)“ · „[E] Brief an die Tür stecken“ · „[E] Brief am Grab vorlesen (10 Min)“ · „[E] Antwort schreiben (20 Min)“ · „[E] Brief verbrennen (2 Min)“ · „[E] Brief mit ins Grab legen“ · „[E] Eine Handvoll Erde nehmen (2 Min)“ · „[E] Steine abladen (20 Min)“ · „[E] Rosine im Keller helfen (40 Min)“.

### 7.6 Karte, Tageszusammenfassung, Register, Abschluss
- **Karte** (Marker-Ebene): verfolgter Eintrag als kleines Lesezeichen am Ort des nächsten Schritts, **nur wenn der Ort fest ist** (Hütte, Grab, Haus, Tor) – kein Pfeil, keine Entfernung; Brenneisen (Zylinder) an seinem Tag; große Bitte (Bogen) an Torafel/Gemeindetafel; Sieber-Fenster mit Licht (B/C, nachts).
- **Tageszusammenfassung** + „Briefe“ (gefunden, entschieden, Post), „Bitten“ (Teile, erfüllt/halb), „Der Herr mit dem Koffer“ (was er fragte, was er bekam).
- **Grabregister:** Spalte „Brief“ (Symbol) und der Vermerk „Licht: 22. Nebelung“ bei den Listen-Toten nach H2.
- **Abschluss-Panel** Variante `&"who_knows_when"` (§1.5).

---

## 8. Figuren, Animationen, Assets & Ton (P7, W-Ton; Stil gesperrt, alle `ph_`, `lib_painted.py` / `lib_faces.py` / geteilte Materialien)

### 8.1 Neue Figur
| Datei | Figur | Budget | Besonderheiten |
|---|---|---|---|
| `ph_chr_stranger` | Cornelius Brenneisen | ≤ 9 000 Dreiecke, gemeinsames Rig (9 Knochen) | Zylinder (Kindmesh `hat_head`/`hat_hand` wie Phase 8), Brille, Koffer `case` am `tool`, Notizbuch `notebook` am `tool_hand`; Gesicht über `lib_faces.py` (schmal, glatt rasiert, kleine Augen hinter Gläsern, freundlich-wachsam) |
Johann Sieber nutzt `ph_chr_mourner_m_b` (Phase 8) mit Zusatz-Clips; Körper- und alte Clip-Hashes bleiben gleich.

### 8.2 Neue Animationen (Clips; `-loop` wird geschleift)
| Figur | Clips |
|---|---|
| Totengräber | `read_book` (Kladde am Pult), `kneel_read` (Datum am Grab, Kladde in der Hand), `write_letter` (Feder, Pult), `read_letter` (stehend, Brief zwischen beiden Händen), `read_aloud_grave` (kniend, Brief), `burn_letter` (Ofen, Hand vor), `slip_letter` (Brief an die Tür), `knock` (Klopfen), `take_soil` (kniend, Tuch), `carry_case` (Koffer am `tool`) |
| Johann | `sit_bench-loop`, `show_mark` (Hemd kurz öffnen, ohne Haut-Detail: nur die Geste, das Zeichen bleibt Text), `walk_bundle-loop`, `sit_cart-loop` |
| Brenneisen | `idle`, `walk`, `talk`, `write_notebook-loop`, `tip_hat`, `wait_gate-loop` (Koffer abgestellt), `sit_inn-loop` |
| Hanne, Osric | keine neuen (Johann folgt Hannes Weg; Osric fährt wie immer) |

### 8.3 Ton (W-Ton, `tools/audio/build_audio.py`, alles prozedural und eigenständig)
`letter_unfold`, `letter_seal_break`, `quill_scratch-loop`, `paper_burn`, `knock_door`, `case_latch`, `soil_handful`, `gate_bell_short` (eine Schlag-Variante der Torglocke für Brenneisen), `notice_sheet` (Bogen anheften). Keine neue Musik; Kontext unverändert. Lautheit wie Phase 8.

### 8.4 Requisiten und Icons
`ph_notice_sheet` (Bogen mit Siegelfaden, Code-Mesh), `ph_prop_letter` (gefaltet, Siegel), `ph_prop_letter_open`, `ph_prop_case` (Lederkoffer mit Messingschloss, ≤ 0,5 m), `ph_prop_notebook`, `ph_prop_watch_lantern`, `ph_prop_bundle` (Johanns Bündel), `ph_prop_soil_pouch`; Icons für `letter`, `letter_reply`, `nameless_letter`, `stranger_case`, `case_card`, `soil_pouch`, `straw_bouquet`. Höhen: keine Requisite > 1,4 m.

---

## 9. Performance-Budget (Phase 9; Messung mit `graveyard_shots_phase9.gd --cpu`, `village_shots.gd --phase9`, `perf_probe_run.gd` + Web `--perf-probe`)
| Größe | Budget | Begründung |
|---|---|---|
| FPS | 60 @ 1080p Mittelklasse-GPU; **Web (Compatibility)** ohne Frame > 50 ms beim Öffnen von Merkbuch „Vorhaben“, Brief-Karte und Brenneisen-Panel | G7/G8-Lehre Browser |
| Figuren mit Skelett, Friedhof | ≤ 9 im Alltag (Brenneisen ersetzt am Tor zeitlich Hanne/Veit nicht – höchstens 3 am Tor) | `NpcLod` unverändert |
| Figuren, Dorf | ≤ 12 (+ Brenneisen, + Johann auf der Bank) | wie Phase 8 |
| Draw Calls Friedhof | ≤ 650 (unverändert) | Bogen und Zettel als Kindmeshes |
| Lichter | Sieber-Fenster und Wächter-Laterne aus dem bestehenden Pool; keine neuen Schatten | |
| Skripte CPU/Frame (headless, relativ) | Phase-9-Anteil **≤ +0,1 ms** (Friedhof Tag mit großer Bitte, Dorf mit Brenneisen) | `Quests`, `Letters`, `Stranger`, `WhoKnows` ereignis- und minutengetrieben ohne `_process`; `visit`-Teile prüfen nur mit offenem Teil 1 Hz |
| Merkbuch „Vorhaben“ | Aufbau ≤ 4 ms bei 30 Einträgen | `QuestLog.entries` liest nur Zustände |
| Spielstand / Laden | < 420 kB (+ ≈ 8 kB) / < 1 s | |
*Plan B:* Merkbuch-Liste begrenzt auf 12 sichtbare Einträge mit Rollen; Brenneisen nur am Tor, nicht in der Gaststube.

## 10. Tests
Regeln wie Phase 3–8 (Fixtures statt fremder Moduldaten, Fehler-Logger, Watchdog). **Alle 3 016 bestehenden Tests bleiben grün**; Anpassungen nur durch den Besitzer (Item-Zählungen, Clip-Listen, Layout-Diff, Zahl der Merkbuch-Reiter, Bitten-Zähler).

**Unit**
| Datei | Besitzer | Prüft |
|---|---|---|
| `test_quests.gd` / `test_quest_rules.gd` / `test_quest_log.gd` | P1 | Öffnung `p9_open` am Morgen (idempotent) und sofort nach v7-Laden; Schrittfolge; jede `complete_on`-Art; Ereignisse vor dem Sichtbarwerden zählen; Wahl einmalig, Aktionen ausgeführt; Frist → `fallback_choice`; Ende „abgeschlossen“ über `settle_on`; Kapitelziel (alle drei Bedingungen, genau einmal); Verfolgen (max. 1); `QuestLog` sammelt Ketten, große/kleine Bitten, Aufträge, Freundschaft, Schulden; Kategorie `quest` zählt nie fürs Dorf-Kapitel; Save/Load |
| `test_orders.gd` (+) | P1 | `max_active_quest 3`, getrennt von 4/2, `stats.orders_done` unverändert |
| `test_hill_rules.gd` (+) / `test_hill_large.gd` | P2 | große Bitte: Plätze Tor/Gemeindetafel, 1 aktiv, Neubelegung 1/2 Tage, Teile in beliebiger Reihenfolge bzw. `parts_in_order`, jede neue Teil-Art (`craft` über `craft_finished`, `gather`, `ghosts` in einer Nacht, `visit` mit Fenster und TimedAction, `meet`, `devotion`, `flowers`), halb erfüllt (halber Lohn, Ruf 0), versäumt (−2), Lohn + Beziehung ab `village_open`, Angebotsbedingungen je Teil, deterministische Auswahl; Save/Load mitten in einer Bitte; kleine Bitten bitgleich |
| `test_letters.gd` / `test_letter_rules.gd` / `test_items_phase9.gd` | P3 | Zuordnung bei der Lieferung (erst ab `p9_open`, forced 3, dann Pool bei Merkmal, keiner doppelt, Bedingungen); Fund bei Taschen; jede Wahl mit Folgen (Pietät je Bitte/Siegel, Beziehung, Ruf-Kappe 1/Tag, Geist +1, Beigabe ≤ +1); Analphabeten (Vorlesen = Zustellen); Post Osric/Hanne nach Offsets, nur an belegte Gräber; Antwort und Gegenbrief; Postgeld; Items unique |
| `test_who_knows.gd` / `test_light_rules.gd` / `test_night_paths.gd` (+) | P4 | Daten aus Records (Tod − 21, D2 aus `night_paths`), fehlender Toter → Sterbebuch-Rückfall, `e_dorn` fest; offenes Licht `p9_open_day − 12`; H2 Register + Gräber; Zeugen → `i_light_before` (3 von 5); H4 drei Häuser, Johann täglich; Frist Licht + 17 → still; Ende A nur mit Brief an der Tür; Abgang mit Hanne vor der Frist, sonst Osric; `np_sieber` relativ zu `q_light_day`, fällt bei `sieber_gone` aus; Tod Licht + 21 → `sieber_dead`; Folgen-Matrix §2.2.8 vollständig |
| `test_stranger.gd` / `test_stranger_rules.gd` | P5 | Besuchstage (`p9_open_day + 2`, alle 5, 3 Tage), Tor-/Gaststuben-Fenster, betritt den Friedhof nie; Fragen (Münze, Pietät einmal); Angebote und Bedingungen (Präparate × 1,5, Register, Erde nur frisch); Gerede nach 2 Tagen; K3 über `c_n_robber`, Veit oder Quast; Bestechung; Koffer (Halter, Hineinsehen, Fenner); drei Enden mit Folgen; Kladde nur nach Ende der Hauptkette, 40, Pietät −8; nach dem Ende kein Auftritt mehr |
| `test_dialogue.gd` (+) / `test_story.gd` / `test_journal.gd` (+) / `test_save_migration.gd` (+) / `test_save.gd` (+) / `test_game_state.gd` (+) | P6 | neue Bedingungen und Aktionen; Osric `p9_intro` einmal; D3 nach `sieber_dead` mit Reservierung in Reihe 4, nie bei Ende A; Liste im Merkbuch; Zeugen-Varianten (`i_not_lorenz`, `underlined`); **7 v7-, 6 v6-, 7 v5-, 7 v4-, 6 v3-, 4 v2-, 3 v1-Fixtures laden ohne Fehler/Warnungen**; `letter_id ""` nach Migration; v8-Roundtrip identisch; Version 9 → abgelehnt |
| `test_assets_phase9.gd` | P7 | Brenneisen vorhanden, Budget, Rig, Clip-Liste, Kindmeshes (`hat_*`, `case`, `notebook`), Gesicht über `lib_faces`; Johann-Re-Export: Mesh-Hash und alte Clips unverändert; Requisiten-Höhen; Icons |
| `test_audio_phase9.gd` | W-Ton | neue Cues vorhanden, Lautheit im Ziel, Web-Einstellungen unverändert |
| `test_ui_phase9.gd` / `test_map_phase9.gd` | W-UI | „Vorhaben“ (Gruppen, Sätze, Verfolgen, verborgene Schritte), „Die Liste“, „Briefe“, Brief-Karte (Wahlen mit Ort, gedimmte mit Grund), Brenneisen-Panel, große Bitten mit Teilen, alle angedockt bei 1280 × 720 … 1920 × 1080, Zielzeilen-Kette, Abschluss-Panel; Karten-Lesezeichen nur bei festen Orten, nie als Pfeil |

**Integration**
- `test_who_knows_endings.gd` (P4): v7-Fixture `slot_p8_day63_kindly` → H1–H5 mit echtem `DialogueRunner` und echten Wegen; **vier Läufe** für A (mit Hanne; zweiter Lauf mit Osric bei später Wahl), B, C und still (Frist); je Lauf: Folgen-Matrix, Npc sichtbar/verborgen, `np_sieber` an/aus, D3 ja/nein, Bestattung, Roundtrip am Abgang bzw. in der Todesnacht.
- `test_letters_flow.gd` (P3): drei Lieferungen nach `p9_open` mit L1–L3, jede Wahl einmal, Post am Grab vorlesen (Geist in der Nacht), Antwort + Gegenbrief, Botengänge E1/E2 mit beiden Entscheidungen.
- `test_stranger_chain.gd` (P5): drei Läufe (Fenner, Handel mit Kladde, Ilse) über zwei Besuche; Lambert-Varianten über `slot_p8_day63_letgo`.
- `test_hill_requests.gd` (+) / `test_hill_requests_bot.gd` (+) (P2): echte Welt, neues Spiel; **Messung §2.3.6** mit `HillBot` (Pflicht/Andächtig, Tag 1–14) als Tabelle in `docs/reviews/phase9_round1/bitten_gross.md`; alte Messung bleibt als Vergleich.
- `test_phase9_loop.gd` (W-Welt): v7 laden → `p9_open` → Osric → Kladde → Register → Gräber → Zeugen → Veit → Siebers → Johann → Liesel → Ende B → zwei Abende → Krankenlicht → D3 → Briefe L1–L4 → zwei große Bitten → **Kapitel**. **Roundtrip** an 7 Momenten: Kladde lesen (TimedAction vorbei), Brenneisen am Tor, Johann auf der Bank, Abgang mit Hanne (Ende A, eigener Lauf), große Bitte mit 2/3 Teilen, Todesnacht 02:20, nach dem Kapitel.
- `test_phase8_save_upgrade.gd` (P6): `slot_p8_mid` → Phase 9 bleibt zu, große Bitten laufen; `slot_p8_day2_hill`/`day30_village_hill` → kleine Bitten unverändert, große ab dem nächsten Morgen.
- `test_graveyard_world.gd` (+) / `test_village_world.gd` (+) / `test_interiors.gd` (+): Layout-Diff nur L16–L19, G3–G4, D8–D12; Sichtprüfungen §4.7; Routen frei.
- **Playthrough-Bot (W3):** `phase9_bot.gd` erweitert `Phase8Bot` um Ketten (echte Gespräche, Prompts, Wege), Briefe (jede Wahl), Brenneisen und große Bitten. **Münzbuch je Strategie** (+ Zweck `post`; Einnahmen „Große Bitte“, „Botenlohn“, „Verkauf an den Herrn mit dem Koffer“).
  | Strategie | Start | Tage | Verhalten | Erwartung |
  |---|---|---|---|---|
  | `kindly9` | v7 `day63_kindly` | 12 | Bogen A §1.4, Ende **A** (mit Osric), Vertraute Liesel, Briefe zustellen, große Bitten, Brenneisen → Fenner | Kapitel B9–B11; Ende ≤ Start + 50; Pietät steigt |
  | `stay9` | v7 `day63_kindly` | 12 | Ende **B**, Vertrauter Lenz, Briefe am Grab vorlesen | Kapitel nach D3 (B11–B12); D3 bestattet in Reihe 4 |
  | `public9` | v7 `day63_kindly` | 12 | Ende **C**, niemandem gesagt | Lenz/Quast/Liesel −4, Launen gereizt, Kapitel erreicht |
  | `silent9` | v7 `day63_kindly` | 12 | H1–H4, dann nichts bis zur Frist | Ende still, Kapitel erreicht (Briefe und Bitten erledigt) |
  | `letters9` | v7 `day63_kindly` | 12 | öffnet und liest jeden Brief, verbrennt die ungelesenen nie | Pietät-Verlust ≤ 6; Kapitel erreicht |
  | `trader9` | v7 `day63_anatomist` | 12 | Brenneisen: alles verkaufen, Bestechung, Kladde | Kapitel erreicht; Ende ≤ Start + 100; Pietät ≤ `kindly9` − 15 |
  | `lazy9` | v7 `day63_kindly` | 12 | keine Kette, keine Bitte | **kein** Kapitel, keine Fehler/Warnungen |
  | `founder9` | v7 `founder` | 16 | neues Spiel nach Phase 8 | Kapitel; alte Kapitel unverändert |
  | `save_load9` | wie `kindly9` | 12 | lädt jeden Morgen, einmal beim Abgang, einmal mit Brenneisen am Tor, einmal mitten in einer großen Bitte | bitgleich zu `kindly9` |
  - Phase-3–8-Bots und `HillBot` (Runde 6) unverändert grün; sie öffnen nie eine Kette und nehmen keine große Bitte an.
- **Save-Fuzzer (W3):** + echter v8-Stand mitten in Phase 9 (Kette bei H4, Brief offen, Post wartet, Brenneisen da, große Bitte 2/3, Johann auf der Bank) mit gezielten Mutationen (`step` unbekannt, Wahl ohne Schritt, Brief-Uid ohne Record, `letter_id` unbekannt, Teile-Liste kürzer als die Bitte, Brenneisen-Ende unbekannt, `light_day` in der Zukunft) + alle v7…v1-Fixtures. Neu in der Konsistenzprüfung: höchstens ein Ende je Kette, kein D3 bei `sieber_gone`, ein Brief höchstens einmal entschieden, höchstens eine große Bitte angenommen.
- Art-Prototyp-Regression: `test_art_prototype.gd` unverändert grün.

## 11. Screenshot-Liste Gate G9 (`graveyard_shots_phase9.gd -- --out=/abs/dir`, `village_shots.gd --phase9 -- --out=/abs/dir` + `ui_screenshots.gd --phase9`, 1280×720, echter Renderer, dazu je eine Web-Aufnahme der Motive 03, 09, 14 → `docs/reviews/phase9_round1/`)
| # | Motiv |
|---|---|
| p9_00 | Kontaktbogen: Brenneisen neben dem Totengräber, Johann, Veit und Hanne (idle, gleiche Kamera, Tag) |
| p9_01 | Gesicht nah: Brenneisen (Zylinder, Brille), Johann |
| p9_02 | Hütte: der Totengräber liest die Kladde am Pult (Clip `read_book`) |
| p9_03 | Merkbuch „Die Liste“ mit zwei Tinten, zwei Namen zugeordnet, ein Zeuge |
| p9_04 | Am Grab: Datum vergleichen, kniend, Kladde in der Hand (Lindenacker) |
| p9_05 | Gesa Ott am Grab ihres Vaters, Gesprächsbild „Drei Wochen vorher brannte schon mal eins.“ |
| p9_06 | Dorf: Veit an der Brunnenbank, im Hintergrund das Fenster der Siebers (Tag, ohne Licht) |
| p9_07 | Klopftür der Siebers, Sprechblase von Anna |
| p9_08 | Johann auf der Bank vor dem Haus, der Totengräber neben ihm (Abend) |
| p9_09 | Ende A: Johann geht mit Hanne den Waldweg hinauf, Bündel über der Schulter (16:20) |
| p9_10 | Ende A (Variante): Johann hinten auf Osrics Karren |
| p9_11 | Ende C: Nachtwächter-Laterne an der Sieber-Tür, Krankenlicht oben |
| p9_12 | Merkbuch „Vorhaben“ mit allen Gruppen, Hauptkette gewählt, „Verfolgen“ |
| p9_13 | Brief-Karte: ein Taschenbrief mit drei Wahlen und Orten |
| p9_14 | Am Grab einen Brief vorlesen (Clip `read_aloud_grave`), Dämmerung |
| p9_15 | Brief im Hüttenofen verbrennen |
| p9_16 | Rosine hinter dem Schanktisch, der Brief hängt an der Wand |
| p9_17 | Brenneisen außen am Tor, Koffer abgestellt, Veit daneben sitzend |
| p9_18 | Brenneisen-Panel mit drei Angeboten |
| p9_19 | Brenneisen in der Gaststube am Ecktisch, schreibend |
| p9_20 | Der offene Koffer (Hineinsehen), Text-Karte |
| p9_21 | Torafel mit großem Bogen und zwei kleinen Zetteln |
| p9_22 | Panel der großen Bitte mit Teile-Liste (1 ✓, 2 ○) |
| p9_23 | Gemeindetafel mit großem Bogen, Fenner daneben |
| p9_24 | Vierte Reihe vorher (Stumpf, Brombeere) / belegt mit Steinen |
| p9_25 | D3 am Gruft-Tisch, Taschenbrief „An Grete“ |
| p9_26 | Abschluss-Panel „Wer weiß, wann?“ (Ende B) |
| p9_vis_row4 / _gate / _sieber / _departure | Sichtprüfung §4.7 mit eingezeichneten Strahlen |
Dazu Asset-Tafeln und Animations-Kontaktbögen `docs/reviews/phase9_assets/` und eine Performance-Tabelle (`perf_p9_01…03`: Friedhof Tag mit großer Bitte und Brenneisen am Tor · Dorf mit Brenneisen und Johann · Merkbuch „Vorhaben“ offen), Web-Sonde.

## 12. Wellenplan
### 12.1 Wellen
| Welle | Agents (parallel) | Inhalt | Ende |
|---|---|---|---|
| **W0** | Lead | **Zuerst v7-Fixtures** (7 Stände §5.3, eigener Commit vor jedem Gerüst) und `tests/fixtures/phase9/{layout_p8,village_layout_p8}.json`. Dann: Datenklassen ✦ (inkl. Erweiterungen), Stubs mit exakten Signaturen, 6 EventBus-Signale, Database-Ordner, `SaveMigration.CURRENT = 8` mit `migrate_7_to_8` als Identität (fail-safe), Config-Fixtures `tests/fixtures/phase9/` (+ `Phase9Fixtures`: `p9_open(tree, day)`, `quest_at(quest, step)`, `light_list(tree)`, `witnessed(entries)`, `sieber_marked()`, `ending(e)`, `letter_in(inv, id)`, `post_waiting(id)`, `stranger_day(k)`, `large_pinned(id, parts_done)`), `test_phase9_scaffold.gd`, `test_saves_v7_load.gd`; W0 prüft die Werkbank-Rezept-Ids der großen Bitten (§2.3.3) und die Grab-Ids der Listen-Toten in den Fixtures | Import + alle Tests grün → Commit |
| **W1** | **7 Pakete:** P1 … P7 (bei 5 Agents: P1 + P4 · P3 + P5 · P2 · P6 · P7) | Systeme mit Unit-Tests gegen Fixtures (ohne Welt): Quest-Kern, Kategorie `quest`, `QuestLog` (P1) · große Bitten, Teil-Arten, `craft_finished`, Messung (P2) · Briefe, Post, Botengänge, Prompts an Pult/Ofen/Grab (P3) · Liste, Zeugen, Johann, Enden, `np_sieber`, Reihe 4 (P4) · Brenneisen mit Angeboten und Enden (P5) · Dialoge, Merkbuch-Texte, D3, Migration v8 (P6) · **Brenneisen zuerst**, dann Clips, Requisiten, Icons (P7) | je Modul: Tests grün → Merge durch Lead, danach `--import` |
| **W2** | W-Welt, W-UI, W-Ton (3 parallel) | Reihe 4, Sieber-Haus, Brenneisens Plätze, Bögen an beiden Tafeln, Abgangswege, alle neuen Npc in der Welt, **Sichtprüfungen §4.7**, `test_phase9_loop`; Merkbuch „Vorhaben“/„Die Liste“/„Briefe“, Brief-Karte, Brenneisen-Panel, große Bitten im Panel, HUD, Karte, Debug; alle Klänge | Integration + Roundtrips grün, Screenshots erstellt |
| **W3** | QA (19), Art (04), Audio (17), Lead | `phase9_bot.gd` (9 Strategien, Münzbuch), `HillBot`-Messung §2.3.6, Save-Fuzzer v8, Performance relativ + Web-Sonde, Prüfung im exportierten pck (Compatibility), Stil-, Gesichts-, Animations- und Ton-Prüfung (Würde, keine Teleports, angedockte Fenster), Befunde beheben (Besitzer), Gate-Protokoll in `QUALITY_GATE_STATUS.md` | **STOPP – Benutzerprüfung G9** |

### 12.2 Abhängigkeiten
- **P1 liefert zuerst** (Tag 1–2): `Quests` mit `note`, `choose`, `complete_on` und Kategorie `quest`. P3, P4, P5 bauen ihre Ketten darauf; bis dahin arbeiten sie gegen `Phase9Fixtures`.
- **P4 liefert früh** `LightRules` (Daten) – P6 braucht sie für die Seite „Die Liste“ und die Zeugen-Bedingungen.
- **P7 liefert zuerst** Brenneisen (Rig, `idle/walk/talk/wait_gate`) und Johanns `sit_bench`/`walk_bundle` – Blocker für Sichtprüfung und Bildserien.
- `grave_plot.gd`, `desk.gd`, `stove.gd`, `corpse_manager.gd`, `corpse_care.gd` (ein Aufruf): nur P3 (ruft P4/P5 über die festen Signaturen). `orders*.gd`: nur P1. `hill_*`, `crafting_system.gd` (ein Signal): nur P2. `corpse_record.gd`/`corpse_save_codec.gd` (Feld `letter_id`): Lead in W0. `night_paths*`, `visitors.gd` (eine Funktion): nur P4. `dialogue_*`, `save_*`, `game_state.gd`, `journal_manager.gd`, `story_director.gd`: nur P6. `data/items/*`: nur P3.
- **Lastverteilung W1** (Richtwert Arbeitstage): P1 3 · P2 4 · P3 4 · P4 4 · P5 3 · P6 5 (meiste Texte: 6 Zeugen, 11+4 Briefe, Brenneisen, Johann, 4 Enden) · P7 4.

### 12.3 Texte
P6 besitzt alle Dialoge, Merkbuch- und Kettentexte; P3 die Brief-, Post- und Botengang-Texte (in `data/letters/*`, `data/orders/oq_*` über P1 → Text P3); P2 die Texte der großen Bitten; P5 die Angebotszeilen; P4 die Listen-Einträge. Die Leittexte stehen in §1–§2; wer sie ändert, meldet es dem Lead.

### 12.4 Prioritäten (Umfang „mittel“)
| Prio | Inhalt | Wenn W1 eng wird |
|---|---|---|
| **A** (Gate) | Quest-Kern + Merkbuch „Vorhaben“ mit Verfolgen · **Hauptkette H1–H6 mit Enden A, B, C, still** und ihren Kernfolgen (Flags, Ruf, Pietät, Beziehung, Johann geht / D3) · Liste mit 6 Einträgen und 5 Zeugen · **Größere Bitten am Tor** (8 Tor-Bitten, Teil-Arten `craft`, `gather`, `ghosts`, `visit`; Messziel §2.3.6) · **Briefe-Kern:** Taschenbriefe L1–L3 + 5 Pool-Briefe, drei Wahlen (Zustellen, Vorlesen, Verbrennen), Post für die Toten (2 Briefe), Botengänge E1/E2, Kette L1–L4 · vierte Reihe · D3 · Save v8 · Brenneisen **als Figur mit K1** (er fragt am Tor; ohne Angebote) | – |
| **B** (geplant) | **Der Herr mit dem Koffer vollständig** (K2–K5, Panel, drei Enden, Kladde-Verkauf) · Briefe L5 „An L. Aschau“ · Post-Briefe 3–4 · Pool-Briefe 6–8 · Wahl „ins Grab legen“ · Botengänge E3/E4 · **Größere Bitten im Dorf** (4 an der Gemeindetafel, Teil-Arten `meet`, `devotion`, `flowers`) · Nachtwächter als Figur (Ende C) · Reaktions-Gerede aller acht Bewohner (A: Liesel, Lenz, Fenner, Rosine) · Karten-Lesezeichen | **in dieser Reihenfolge von unten streichen** → §13, Benutzer wird informiert: Karten-Lesezeichen → Gerede der übrigen vier → Nachtwächter-Figur → Dorf-Bitten → E3/E4 → „ins Grab legen“ → Pool-Briefe 6–8 → Post-Briefe 3–4 → L5 → Brenneisen K4–K5 (dann endet seine Kette nach K3 mit „Er reist ab.“) → Brenneisen K2–K3 (dann bleibt nur K1) |
| **C** (gestrichen) | Zufällig gezeichnete Lieferungen auf der Liste · freie Briefe schreiben mit Texteingabe · Postlaufzeiten und Briefwechsel über Wochen · Brenneisen kauft ganze Leichen · neue Feste (Barbara, Lucia, Weihnachten) · ein zweiter Herr aus der Stadt · Johann-Rettung durch Arznei · Questmarker, Kompass | §13 |
*Begründung:* Die **Hauptkette** ist das Rückgrat des Geheimnisses und die Bühne für die verlangten spürbaren Folgen; ohne sie gäbe es kein Kapitel. Die **Größeren Bitten** antworten direkt auf die Benutzerkritik aus G8 Runde 6 und sind messbar (§2.3.6) – sie gehören ins Gate, weil der Benutzer sie im echten Spiel ab Tag 2 sieht. Der **Briefe-Kern** ist billig (ein System, Daten, wenige Clips), speist Botengänge und Lieferungen und trägt die Entscheidungen in den Alltag; sein Kern ist Kapitelbedingung. **Der Herr mit dem Koffer** braucht eine neue Figur (größter Asset-Posten), ein Handels-Panel und die meisten Sonderfälle (Präparate, Lambert-Varianten, Kladde) – er ist die erste Streichmasse, aber als Figur mit K1 bleibt er in A, damit er in Phase 9 wenigstens auftritt und Lamberts Spur nicht ins Leere läuft.

## 13. Nicht in Phase 9
- **Angeln, der Mühlteich, neue Orte** (Phase 11); Stadtbesuche, Ellbach als Ort, Kutschfahrten mit dem Spieler
- Die Auflösung, **wer zeichnet** und wer das Licht anzündet; Lorenz unter dem Birkenhang, das Gitter in der Gruft, der Brief an Lorenz zugestellt (Phase 12); ob Johann (Ende A) ankommt (§14.5)
- Zufällig gezeichnete Lieferungen auf der Liste; weitere Listen, weitere „Lichter“ nach Johann; eine Regel, mit der man den Tod verhindert (außer fortgehen, wie bei Lorenz)
- Freies Briefeschreiben mit Texteingabe, Briefwechsel über viele Wochen, ein Postamt, Briefmarken, Zustellzeiten als System; Briefe als Ware
- Leichenhandel (Brenneisen kauft keine Leiche, kein Körper verlässt den Friedhof), Exhumieren, Verhaftung, Gericht, Kampf; Brenneisen als Gegner
- Quest-Belohnungsbaum, Erfahrungspunkte, Stufen, Fraktionen, Moral-Leisten, Questmarker über Köpfen, Kompass, Tagesquests mit Sofortbelohnung
- Neue Feste (Barbara, Lucia, Advent, Weihnachten), Wochentage, Sonntage, Wetter, Schnee (ein eigener Kalender-Vertrag)
- Neue Gebäude, neue Innenräume (auch das Sieber-Haus bleibt Fassade mit Klopftür), neue Abschnitte außer Reihe 4; Zier im Dorf
- Preisdynamik, Steuern, Pacht, Kredit, Brenneisen als dauernder Händler (Phase 10: nur die Karte `case_card` als Haken)
- Ein zweiter Lehrling, Jakob in den Ketten über E4 hinaus; Phase-14-Arbeiter
- Änderungen am Maler-Shader, an den Atmosphären-Presets, an `lib_faces.py`, am Rig, an den freigegebenen Abschnitten, Gebäuden und Räumen (außer §4.6)

## 14. Offene Fragen an den Benutzer (Entscheidung vor W0)
1. **Wer ist „S.“ – wem gilt das offene Licht?** (§2.2.1, §2.2.5)
   - (a) **Johann Sieber**, 71, der alte Trauernde, der mit Gretes Grab redet – man kennt ihn aus Phase 8, er ist ruhig und hat es nicht eilig; drei Enden (fortgehen, bleiben, öffentlich).
   - (b) **Schultheiß Fenner** (Wassersucht) – stärker, weil ein Bewohner mit Amt und Geschichte betroffen ist; Ende A würde den Schultheiß aus dem Dorf nehmen (Gemeindetafel, Aufträge und Reihe 4 bräuchten einen Ersatz – deutlich mehr Arbeit).
   - (c) **niemand in Phase 9:** der Eintrag bleibt offen, das Licht kommt erst später; die Kette endet mit der Vertrauensfrage (H5) und zwei Enden ohne Tod.
   - **Vorschlag: (a)** – eine bekannte, warme Figur, deren Tod oder Abschied man spürt, ohne das Dorf umzubauen.
2. **Ab wann gibt es Größere Bitten?** (§1.2, §2.3)
   - (a) **ab Tag 2 in jedem Spiel** am Tor, ab `village_open` auch an der Gemeindetafel – trifft genau das Leerlauf-Loch an Tag 2–12 (Ziel ≤ 1700 min statt 2483).
   - (b) erst ab `p9_open` (Spätspiel) – das Loch an Tag 2–12 bliebe wie nach Runde 6.
   - (c) ab Tag 2, aber nur am Tor; Dorf-Bitten erst ab `p9_open`.
   - **Vorschlag: (a)** – das war die Kritik; die alten Bots bleiben bitgleich, weil sie keine Bitte annehmen.
3. **Neue Grabstellen in Phase 9?** (§2.6, §4.2)
   - (a) keine – dann gibt es im Bogen keine Lieferungen: keine Taschenbriefe L1–L3 (nur Post), kein `hrl_proper_grave`, und D3 braucht eine durch Umbetten frei gewordene Stelle.
   - (b) **eine vierte Reihe im Lindenacker mit 4 Stellen** (Südzaun noch einmal 3,2 m nach Süden, ein Waldbaum versetzt).
   - (c) 6 Stellen am Kirchhof neben der Kapelle (neuer Grabbereich am Kamm, von Lenz geweiht) – würdiger Ort für D3, aber ein Eingriff in den freigegebenen Kirchhof (Phase 6) und mehr Sichtprüfung.
   - **Vorschlag: (b)** – genug Tote für Briefe und D3, dasselbe Muster wie Phase 8, kleiner Eingriff.
4. **Wie weit geht der Herr mit dem Koffer?** (§2.5)
   - (a) **Händler mit moralischen Angeboten:** Fragen, Grabeserde, Registerabschrift, Präparate, Bestechung, die Kladde für 40 Münzen; **keine Leichen**; drei Enden (Fenner, Handel, Ilse).
   - (b) sanfter: nur Fragen und ein einziges Angebot (die Kladde), zwei Enden (Fenner, abweisen) – spart ≈ 40 % von P5.
   - (c) härter: er will eine frische Leiche kaufen, und man kann sie ihm verkaufen (ein Körper verlässt den Friedhof) – bricht die Phase-8-Regel „die Leiche bleibt“ und den Ton; nicht empfohlen.
   - **Vorschlag: (a)** – Versuchung mit spürbarem Preis, ohne die Würde der Toten aufzugeben.
5. **Ende A „Über den Hügel“ – erfährt man, ob Johann ankommt?** (§2.2.7)
   - (a) **offen:** er geht, und ob er ankommt, erfährt man frühestens in Phase 10 (wie bei Lorenz' Nachtfähre: „Nicht alle kamen an.“).
   - (b) tröstlich: am Ende von Phase 9 kommt mit Hanne ein Zettel „Angekommen. J. S.“ (von einem anderen geschrieben, er kann nicht schreiben).
   - (c) bitter: er kommt nach fünf Tagen zurück („Grete wartet.“) und stirbt doch – Ende A wird zu B.
   - **Vorschlag: (a)** – die Frage bleibt im Spieler, und Phase 10/12 haben etwas zu erzählen.
6. **Was kostet das Lesen fremder Briefe?** (§2.4.2)
   - (a) **versiegelte Briefe, die nicht an dich sind, öffnen kostet Pietät −1**, außer der Brief bittet darum; der Text bleibt im Merkbuch.
   - (b) Lesen kostet nichts (nur Text, keine Folge).
   - (c) versiegelte Briefe lassen sich gar nicht öffnen, nur zustellen oder verbrennen.
   - **Vorschlag: (a)** – eine kleine, ehrliche Versuchung, die zum Moralsystem aus Phase 4 passt.
7. **Wie groß soll der Merkbuch-Überblick sein?** (§2.1, §7.1)
   - (a) **ein Reiter „Vorhaben“ für alles** (Ketten, große und kleine Bitten, Aufträge, Freundschaft, Schulden) mit „Verfolgen“ für die HUD-Zeile; die bisherigen Reiter bleiben als Verlauf.
   - (b) nur die drei Ketten; Bitten, Aufträge und Freundschaft bleiben in ihren Reitern.
   - (c) wie (a), zusätzlich ein Lesezeichen auf der Karte am Ort des verfolgten Schritts (Prio B, §7.6).
   - **Vorschlag: (a)**, das Karten-Lesezeichen aus (c) als Priorität B.

---

### §14 Benutzerentscheidungen (bindend, 17.10.2026)
1. **„S.“ = Johann Sieber** (a) – drei Enden: über den Hügel, bei Grete, vor der Gemeinde (+ still).
2. **Größere Bitten ab Tag 2** (a) – am Tor in jedem Spiel, ab `village_open` auch an der Gemeindetafel; Messziel HillBot Pflicht Leerlauf Tag 2–12 ≤ 1700 min.
3. **Vierte Reihe im Lindenacker** (b) – 4 Stellen `l_13…l_16`, Südzaun 3,2 m nach Süden, ein Waldbaum versetzt.
4. **Brenneisen: moralische Angebote** (a) – Fragen, Grabeserde, Registerabschrift, Präparate, Bestechung, Kladde für 40 Münzen; **nie Leichen**; drei Enden (Fenner, Handel, Ilse).
5. **Ende A bleibt offen** (a) – ob Johann ankommt, frühestens in einer späteren Phase.
6. **Fremde versiegelte Briefe öffnen: Pietät −1** (a), außer der Brief bittet darum; Text bleibt im Merkbuch.
7. **Merkbuch-Reiter „Vorhaben“ für alles** (a) mit „Verfolgen“ für die HUD-Zeile; Karten-Lesezeichen Priorität B.

---

## W0-Notizen (Lead, Welle 0 – verbindlich für W1)
1. **v7-Fixtures** `tests/fixtures/saves_v7/*.json` wurden **vor** jeder Phase-9-Code-Änderung auf dem unveränderten Referenzstand erzeugt (Code = **10e310e**, Branch-Stand dda8bde = nur Vertrag/Roadmap) – über `Phase8Bot` / `HillBot` / `Phase7Bot` + echte Systeme (`make_v7_saves.gd` + `_driver.gd`, historisches Werkzeug; `-- --out=/abs/dir [--only=kindly,anatomist,letgo,founder,mid,day2,village]`; auf einem Phase-9-Stand schriebe es v8). Eigener Commit **34b3c40**, zusammen mit `tests/fixtures/phase9/{layout_p8,village_layout_p8}.json` (= `data/world/{graveyard,village}_layout.json` von 10e310e, bytegleich, sha256 `b4c06080a83f…` / `5e191c6d484b…`). Die Endstände setzen die v6-Fixtures mit denselben Bot-Tagen fort wie `test_phase8_playthrough.gd`, danach 07:00 des nächsten Morgens. Gemessen (sha256-Präfix; Münzen = Beutel + Lohnkasse Jakobs):
   - *day63_kindly* (`kindly8`, 10 Tage ab `slot_p7_day53_neighbor`, **07:00 Tag 63**, `a032c7b222ed`): Kapitel `who_comes_up` an **Tag 62** (B10), `p8_open_day 53`, 36 Gräber `MARKED`, Lindenacker inkl. Reihe 3 voll (0 frei), Ruf 100, Pietät 100, **68 Münzen** (59 + 9; §1.4/§2.8 rechnen mit ≈ 70). Kein Bitt-Zettel am Tor.
   - *day63_anatomist* (`anatomist8`, 10 Tage ab `slot_p7_day53_anatomist`): der v6-Stand beginnt an Tag 54, deshalb **07:00 Tag 64** (Dateiname nach Vertrag beibehalten), `150c1280701d`. Kapitel Tag 61, `anatomy_known`, 20 Präparate genommen, **103 Münzen** (91 + 12), Ruf 100, Pietät −45.
   - *day63_letgo* (`night8b`, 10 Tage ab `slot_p7_day53_neighbor`, **07:00 Tag 63**, `69cb0753c8df`): Lambert laufen gelassen (`fate let_go`), Kapitel Tag 61, 101 Münzen (92 + 9). **Abweichung:** `night8b` fragt Lambert nie „Wer zahlt dich?“ und hätte kein `c_n_robber`; der Treiber (`AskLetGoBot`) führt beim Sitzen zuerst die Aktion des Dialogknotens `who` aus (`add_clue:c_n_robber`) und lässt ihn dann wie `night8b` laufen.
   - *founder* (`founder8`, ab `slot_p7_founder` bis zum Kapitel, `9d9d37162a7c`): Kapitel an **Tag 60**, gespeichert **07:00 Tag 61**, `p8_open_day 48`, alle fünf Kapitel, 57 Münzen (48 + 9), Ruf/Pietät 100. Ein kleiner Bitt-Zettel (`hr_lenz_ghost`, angeboten) hängt.
   - *mid* (`kindly8`, 5 Tage, **07:00 Tag 58**, `a6bf7948845a`): Phase 8 offen, Kapitel offen, D2 noch nicht geliefert, 70 Münzen; `hr_osric_wood` hängt angeboten.
   - *day2_hill* (neues Spiel, `HillBot duty_requests` Tag 1, dann Tag 2: Tafel nach 07:44 gelesen, die erste annehmbare Bitte angenommen, **10:00 Tag 2**, `9cd2a9957d99`): Tafel `hr_lenz_stone` (angenommen) + `hr_esch_stone` (angeboten), 10 Münzen. Die Lieferung des Tages liegt noch an der Bahre (der Treiber wartet bis 10:00).
   - *day30_village_hill* (`2bec5859e610`): **Abweichung:** vor Tag 37 ist das Dorf in keinem Stand offen (frühester `village_open_day` = 37, v5-`founder`). Der Stand ist `slot_p6_day37_founder` + ein `founder7`-Tag (Treiber-Definition wie `make_v6_saves_driver.gd`) → Tag 38: Tafel nach 07:44 gelesen, `hr_liesel_paths` angenommen (Dorf-Regel: 1 Platz), **10:00 Tag 38**, 31 Münzen. Dateiname nach Vertrag beibehalten.
   - **Grab-Ids der Listen-Toten** (alle vier Endstände gleich; geprüft in `test_phase9_scaffold.gd::test_list_dead_in_the_kindly_fixture`, `Phase9Fixtures.LIST_DEAD`): S1 Marthe Quendel `plot_06` (Ankunft Tag 6), S3 Ida Wernstein `h_01` (13), S5 Kaspar Dorn `h_06` (19, Name schon „Kaspar Dorn“), D1 Wiebke Hagedorn `l_07` (48; founder 45), D2 Gerhard Ott `l_12` (59; anatomist 60, founder 54), `night_paths.deaths.np_ott` 58 (anatomist 59, founder 53). **Lichttage in `kindly`:** S1 5 − 21 = **−16**, S3 12 − 21 = **−9** (vor Spieltag 1!), D1 47 − 21 = 26, D2 58 − 21 = 37, offenes Licht 63 − 12 = **51** (22. Nebelung), Tod Johann 72 (13. Julmond).
   - Lade-Wächter `tests/integration/test_saves_v7_load.gd`: alle 7 laden ohne Warnung, Zustand erhalten, `letter_id ""`, Phase-9-Stats 0, Neuspeichern v8, Roundtrip identisch.
2. **Speicherformat v8 schon in W0:** `SaveMigration.CURRENT = 8` (`SaveFileIO`/`SaveManager.FORMAT_VERSION` folgen), Kette 1→…→8, `read_doc` nimmt 1…8. **Abweichung zu §12.1 („Identität“), Auftrag des Lead:** `migrate_7_to_8(state, meta)` ist schon die vollständige §5.2-Migration auf einer tiefen Kopie (rein, idempotent): `letter_id ""` an jedem Record (`V8_RECORD_DEFAULTS`), `V8_EMPTY_NODES = ["quests", "who_knows", "letters", "stranger"]` als `{}` (wie V4–V7 eingefügt; `SaveManager.without_absent_defaults` kennt V8 und wirft sie weg, solange die Welt die Knoten nicht hat), `V8_NEW_STATS` (18, §2.9) = 0; keine Flags, Gräber/`hill_requests`/Spieler/Besucher unverändert. **Ebenfalls schon W0:** `GameState.DEFAULT_STATS` + 18 Stats (angehängt) und `COIN_REASONS` + `&"post"` (Stat `coins_spent_post`); `CorpseRecord.letter_id` wird gespeichert (**40** Record-Felder, `from_dict` tolerant). P6 besitzt die Dateien weiter und darf glätten. Die Plots `l_13…l_16` entstehen beim Laden nach der vorhandenen toleranten Graveyard-Regel als `LOCKED`, sobald W-Welt sie ins Layout und P4 `data/sections/linden_row4.tres` (Vorlage in den Fixtures) anlegen – `test_saves_v7_load::test_row4_plots_follow_the_layout` prüft das dann mit. `hill_requests`: fehlende `large_*`-Schlüssel = Grundzustand (W0: die Stub-Speicher lesen `large_board`/`parts` tolerant, speichern sie noch nicht).
3. **Datenklassen ✦ vollständig** (§3.2.1): `QuestConfig`, `QuestData`, `QuestStepData`, `QuestChoiceData`, `QuestEndingData`, `WhoKnowsConfig`, `LightListData`, `LightEntryData`, `LettersConfig`, `LetterData`, `StrangerConfig`, `StrangerOfferData` – Felder und Defaults exakt §3.4. Rein additive Zusätze: Konstanten `QuestData.KIND_*`, `QuestStepData.COMPLETE_ON`/`ON_*`, `LightEntryData.INK_*`, `LetterData.KINDS/CHOICES/ASKS`. Erweiterungen: `OrderData` (+ `CATEGORY_QUEST`, `SIZE_LARGE`, `PLACE_GATE/VILLAGE`, **`PART_KINDS`** = die 7 neuen Teil-Arten, `parts: Array[Resource]` wie Vertrag – die Teile sind eingebettete `OrderData`-Unterressourcen, das lädt und speichert ohne Selbstbezug, `size`, `place`, `parts_in_order`), `NightPathData` (+ `anchor_flag`, `cancel_flag`), `GhostLines.by_letter`.
4. **Erweiterungen bestehender Configs – Klassen-Default und `data/config/*.tres` gemeinsam:** `OrdersConfig.max_active_quest 3`, `HillRequestsConfig` (+ 9 `large_*` + `half_ratio`), `ReputationConfig.event_points` (+ 8), `PietyConfig.events` (+ 16), `RelationshipConfig.gains` (+ 11), `NpcLifeConfig.reactions` (+ `q_sent_away`, `q_stayed`, `q_public` je 3 Tage, `letter_delivered`, `register_sold` je 2 Tage; die Launen-Regeln §2.2.8 bleiben P6). Die Phase-9-Fixtures dieser Configs sind der W0-Stand (`Phase9Fixtures.EXTENDED_CONFIG_NAMES`); `test_phase8_scaffold.gd` führt `gains`, `event_points`, `events`, `reactions` jetzt in `DATA_CHANGED_AFTER_W0`, `test_piety`/`test_reputation` vergleichen mit der Phase-9-Fixture. Nur Klassen-Default: `GhostLines.by_letter` (leer; `ghost_lines.tres` gehört P3, die Leitzeilen stehen in `ghost_lines_fixture.tres`).
5. **Neue Config-Dateien** = Klassen-Default, ausdrücklich geschrieben: `data/config/{quest_config (→ P1), who_knows_config (→ P4), letters_config (→ P3), stranger_config (→ P5)}.tres`; Kopien in `tests/fixtures/phase9/*_fixture.tres`. **Einzige Ausnahme:** `stranger_config.tres` trägt die 6 Fragen (3 aus §2.5.2 K1, „Wie schwer ist ein Mann nach drei Tagen im November?“ aus §2.5.1 und 2 W0-Entwürfe), der Klassen-Default bleibt `[]` wie §3.4. Weicht ein Besitzer ab, setzt er Default und `.tres` gemeinsam und trägt die Eigenschaft in `DATA_CHANGED_AFTER_W0` (`test_phase9_scaffold.gd`) ein – die Fixture bleibt.
6. **Nicht** in W0 angelegt (Besitzer, W1): `data/quests/*` (P1 Struktur, P4 `who_knows/list.tres`, Texte P6), `data/orders/oq_*` (P1, Texte P3), `data/hill_requests/large/*` (P2), `data/letters/*`, `data/items/*` (7 Phase-9-Items) (P3), `data/stranger/*` (P5), `data/night/paths/np_sieber.tres`, `data/sections/linden_row4.tres`, `data/clearables/*` (P4), `data/story/d3_sieber.tres`, `data/finds/f_d3_*`, `data/journal/*`, `data/dialogue/*`, `data/npc/*_schedule.tres` (P6). Die Fixtures sind **vollständige Vorlagen** mit den Leittexten aus §1–§2 (kopieren erlaubt). Neue Items in `data/items` ändern Item-Zählungen fremder Tests (`test_inventory.ITEMS`) – P3 passt sie an (Lead-genehmigt).
7. **Stubs** (`## STUB (P<n>)`, Signaturen exakt §3.4; Liste `IMPLEMENTED` in `tests/unit/test_phase9_scaffold.gd` füllen die Besitzer). **Fett = antwortet schon aus `load_state` (Format §5.1)** bzw. GameState, damit W1-Tests fremder Pakete Zustände setzen können (`Phase9Fixtures`):
   - **P1:** `Quests` (Gruppen `quests`/`saveable`, 81; **`is_open()`/`open_day()` lesen `p9_open`/`p9_open_day`**, **`state`/`current_step`/`steps_done`/`choice_of`/`ending`/`notes`/`pinned`** aus `{open, step, done, choices, ending, settled, notes, pinned}`; `goal_progress` = `{main false, letters_step false, letters_decided 0, large 0}`), `QuestRules`, `QuestLog` (+ Gruppen-Konstanten `GROUP_*`).
   - **P2:** an `HillRequests`: `parts_done`/`large_board` (**aus den W0-Speichern `large_board`/`parts` von `load_state`**, nicht gespeichert), `visit_block_reason`, `start_visit`, `half_done` (false); an `HillRules`: `part_done`, `large_offerable` (false).
   - **P3:** `Letters` (83; **`letter`/`state`/`corpse_of`/`decided_count`/`delivered_count`** aus `{records}`; `letter_table` für Fixtures; W0-Lesart „entschieden“ = `posted|delivered|read|read_grave|answered|burned|buried`, „zugestellt“ = `posted|delivered` – P3 legt fest), `LetterRules`.
   - **P4:** `WhoKnows` (82; **`matched`/`witnessed`/`letter_posted`/`depart_plan`** aus `{matched, witnessed, marked_seen, letter_posted, depart}`), `LightRules` (`NO_DAY` = „INT_MIN“ §3.4), `KnockDoor` (+ `.tscn` mit `Interactable`, `door_id`, `dialogue_id sieber_door`); an `Visitors`: `set_kin_interval` (inert).
   - **P5:** `Stranger` (84; **`gone()`/`case_holder()`** aus `{ending, case}`), `StrangerRules`.
   - **P6:** keine Stubs – `migrate_7_to_8` ist fertig (Punkt 2); Dialog-Bedingungen/-Aktionen, D3, Merkbuch-Seiten nach §3.4.
   - P7, W-Welt, W-UI: keine Stubs (Panels, Builder, Szenen in W2). Die Systemknoten werden in W0 **nicht** in die Welt gehängt (W-Welt, wie Phase 4–8).
8. **EventBus:** die 6 Signale aus §3.3 (Block „Phase 9“). **Eingaben:** keine neuen. **Database** (§3.5): `quest/quests` (nach `order`), `letter/letters` (nach id) + `pocket_letters()`/`post_letters()` (Filter `kind`), `stranger_offer/stranger_offers` (nach id), `large_request/large_requests` (`data/hill_requests/large`, nach `order`; `hill_requests()` liest den Ordner nicht rekursiv und bleibt bei den kleinen). Leer/fehlend = leere Liste.
9. **Fixtures für W1:** `tests/fixtures/phase9/` – erzeugt von `make_phase9_fixtures.gd` (+ `_driver.gd`, historisch): Configs (Punkt 4/5) + `ghost_lines_fixture.tres` (Phase-8-Fixture + `by_letter` 2 Zeilen + `by_story.d3_sieber` 3 Zeilen B/C/still); `quests/{q_who_knows,q_letters,q_case}.tres` (Schritte, Wahlen mit Aktionen, Enden), `quests/who_knows/list.tres` (6 Einträge), `letters/*` (11 Taschen + 5 Post inkl. `lpo_aschau`), `stranger/offers/{so_soil,so_register,so_specimen,so_kladde}`, `hill_requests/large/*` (12, mit Teilen), `orders/oq_*` (6, `category quest`), `clues/c_q_*` (12), `insights/i_light_before.tres` (`requires c_q_dates + c_q_three_weeks`, `any_clues` = 5 Zeugen-Hinweise, `any_count 3`), `story/d3_sieber.tres`, `finds/f_d3_{mark,ribbon}`, `night/paths/np_sieber.tres`, `sections/linden_row4.tres`; `tests/fixtures/items/` + 7 Items (`letter`/`letter_reply` unique). Zugriff `Phase9Fixtures`: `p9_open(tree, day)` (setzt `village_open`, `name_in_village_complete`, `p8_open`, `who_comes_up_complete`, `p9_open`, `p9_open_day`, `q_light_day`; liefert `Quests`), `quest_at(quest, step)`, `light_list(tree)` (+ `WhoKnows` im Baum, wenn `tree`), `list_records()`, `witnessed(entries)`, `sieber_marked()`, `ending(e)`, `letter_in(inv, id)` → `{letters, uid}` (setzt die Fixture-Items in die Database, **`remove_injected_items()` im `after_each`**), `post_waiting(id)` → `{letters, uid}` (Zustand `received`), `stranger_day(k)` (65, 70, …), `large_pinned(id, parts_done)` → `HillRequests`, `install_save_v7`, `save_v7_path`, `layout_p8()`, `village_layout_p8()`, ID-Listen, `SAVEABLES`, `LIST_DEAD`.
10. **Lücken, pragmatisch entschieden** (Besitzer dürfen in ihrem Paket glätten und melden es):
    - **Rezept-Ids der großen Bitten (§2.3.3, W0-Prüfung):** Zierstücke = `decor_flowerbed`/`decor_grave_vase`/`decor_lantern` (Werkbank), Bank = `decor_bench_wood` (Werkbank), Laternenpfahl = `decor_lantern` („Grablaterne“, Werkbank), Holzkreuz `wooden_cross`, Grabstein `gravestone_simple` – **ist schon ein Werkbank-Rezept**; die Holzkreuz-Ausweichregel von `hrl_old_names` (`alt_recipe`/`alt_unless_station mason` in der Fixture) ist deshalb wohl unnötig (P2 entscheidet). **Altarkerzen haben kein Rezept** (`altar_candle` kauft man bei Theres, Lenz, Osric): `hrv_church_candles` Teil 1 ist deshalb `deliver` 4 `altar_candle` an Lenz statt `craft` (das Lohn-Ding „2 Altarkerzen“ bei `hrl_ferry_graves` bleibt, das Item gibt es).
    - **Große Bitten (Fixture-Form):** Container `kind &"large"`, `size large`, `category hill`, Ort `place`; Teile sind `OrderData` mit `kind` aus `HillRules.KINDS + OrderData.PART_KINDS`, `title` = HUD-Zeile. Neue `conditions`-Schlüssel der Teile (P2 liest): `decor {decor, section, amount, near}`, `tend {spots | grave: neighbors | ghosts_tonight | old_dirty, count, requires_item}`, `craft {recipe, amount, alt_recipe, alt_unless_station}`, `gather {item, amount}`, `ghosts {times}`, `ghost {section | grave}`, `visit {place, minutes, window, label}`, `meet {npc, place (kin_grave = Grab der Kehrs), window}`, `flowers {graves: kin_kehr}`; Bitte: `requires_flag` (Feld) `village_open` / `p8_open` / `buildings_open`, `conditions.min_day`, `reward_items`, `reward_goodwill {kin_kehr: 2}`. Wegpunkte `gate_outside` (vorhanden), `v_bridge_unload`, `v_inn_cellar_help` (W-Welt). Geberin Martha Kehr = `kin_kehr`.
    - **Ketten (Fixture-Form, P1/P4/P3/P5):** H1 `note kladde_read`, H2 `note date_grave` × 5 (Argumente = Eintrags-Ids), H3 `insight i_light_before`, H4 `flag q_sieber_marked`, H5/H6 `choice`; L1 `note pocket_decided`, L2 `note post_decided`, L3 `order oq_gesa_brother`, L4 `note answer_posted`, L5 `choice` (Ende `done`, Flag `q_letters_done`); K1 `note stranger_answered`, K2 `note stranger_offers_seen`, K3 `clue c_q_case_lorenz`, K4 `order oq_case_return`, K5 `choice`. Wer die Ereignisse meldet, ruft `Quests.note(key, arg)` (Letters, Stranger, WhoKnows). Ende A `settle_on sieber_gone`, B/C/still **`settle_on sieber_buried`** (neues Flag, gesetzt, wenn D3s Grabzeichen steht – P6/StoryDirector; §5.1 nennt es nicht). H6-Wahl `away` mit Bedingung `letter_posted` und `block_text`; Frist `q_light_day + 17`, `fallback_choice silent`. Aktionen in der vorhandenen Syntax (`rel_add:<npc>:<n>`, `set_flag`, `add_clue`, `note_event`) + den neuen P6-Aktionen `rep_event`, `piety_event`, `goodwill:<kin>:<n>` (§3.4); `open_conditions` = `flag:p9_open`.
    - **Briefe:** `lg_wife` hat `recipient ""` + Bedingung `kin_house` (= der Haushalt des Toten), `lg_lambert` `recipient robber` + `robber_fate:let_go`, `lp_d3_grete` `recipient grave` + `story:d3_sieber`, Post-Briefe `recipient grave` bzw. `kin_ott` (`lpo_ott`, Gesa +4); `lpo_aschau` `recipient none`. Neue Bedingungsschlüssel `kin_house`, `story:<id>`, `robber_fate:<f>` (P3 liest bzw. P6 in `DialogueConditions`).
    - **Brenneisen-Angebote:** `so_soil` (3, `fresh_grave_days:5`), `so_register` (10, `has_item:register_extract`), `so_specimen` (Preis 0 = Quasts Preis × `specimen_factor`, `flag:anatomy_known`), `so_kladde` (40, `quest_ended:q_who_knows`) – neue Bedingungen `fresh_grave_days:<n>`, `quest_ended:<id>` (P5).
    - **Zeugen:** `e_ott` Zeugin Gesa Ott = `kin_ott`, `e_open` Veit = `beggar`; der Hinweis von H4 ist `c_q_sieber` (= `witness_clue` von `e_open`).
    - **`np_sieber`:** `start_offset 19`, `end_offset 20`, Besuche Quast 19 22:30–23:10, Lenz 20 21:00–21:40, Liesel 20 02:40–05:30 (Nacht-Regel aus Phase 8: eine Minute < 06:00 gehört zur Nacht vom Vorabend), Tod `death_offset 20` 02:10 (= Licht + 21), `death_flag sieber_dead`, `anchor_flag q_light_day`, `cancel_flag sieber_gone`, `watch_spot watch_sieber`, Besuche ohne Hinweis (`clue_id ""`).
    - **D3:** `order 8`, `look 2` (alter Mann), `section linden_row4`, `requires_flag q_sieber_dies`, `due_flag sieber_dead`; Haushalt `house_sieber` über `CorpseManager.STORY_KIN` (P3/P6).
    - **Vierte Reihe:** Fixture `linden_row4` = Kopie von `linden_row3` (`order 10`, `requires_flag`/`unlock_flag linden_row4_granted`).
    - Texte der Stubs, Item-Beschreibungen, Hinweis-, Zeugen- und Bitt-Texte außerhalb der Leittexte sind W0-Entwürfe – die Besitzer formulieren.
11. **Hinweise je Paket (W1):**
    - **P1:** `Quests.post_load` muss bei v7-Ständen mit `who_comes_up_complete` sofort `p9_open` + `p9_open_day = TimeManager.day` setzen (Endstände: Tag 63 / 64 / 63 / 61). `Orders` zählt `category quest` nur gegen `max_active_quest`. `QuestLog` muss ohne Quests-Knoten (W0-Welt) leere Gruppen liefern.
    - **P2:** Messziel §2.3.6 gegen die alte Messung (2820 / 2483 min). Die alten Bots (inkl. `HillBot` ohne große Bitten) müssen bitgleich bleiben – große Bitten nur annehmen, wenn eine Strategie es will. `craft_finished` sendet `CraftingSystem` (Stonemasonry, Station `mason`, nach Bedarf). Die W0-Speicher `_large_board`/`_parts` in `hill_requests.gd` ersetzen und `save_state` erweitern (§5.1) – dann `test_phase9_scaffold::test_fixture_helpers` („W0: not saved yet“) anpassen.
    - **P3:** Die 7 Items nach `data/items/` (+ `test_inventory.ITEMS`), `Letters.assign` erst ab `p9_open`; die ersten drei Lieferungen nach `p9_open` tragen L1–L3. Reihe 4 hat 4 Plätze, einer ist für D3 reserviert → im Bogen A genau 3 Lieferungen (B3–B5).
    - **P4:** **`StoneCalendar.date_text` klemmt Tage < 1 auf Tag 1** (3. Gilbhart 1834) – S1 (−16) und S3 (−9) liegen vor dem Spielstart. `LightRules.entry_text` muss rückwärts zählen (eigene reine Funktion; `StoneCalendar` bleibt unverändert, sonst ändern sich Grabinschriften). D2s Tod aus `night_paths.deaths.np_ott`, nicht aus der Ankunft. `NightPaths` muss `anchor_flag`/`cancel_flag` lesen, ohne `np_ott`/`np_kehr` zu verändern (Feld leer = `p8_open_day`).
    - **P5:** Brenneisen betritt den Friedhof nie (Region graveyard nur außen am Tor); `Stranger.gone()` liest in W0 `ending` – die Bedeutung bleibt.
    - **P6:** `DialogueConditions`/`DialogueActions` nach §3.4 + die Bedingungsschlüssel aus Punkt 10; `sieber_buried` setzen; `JournalManager` für `i_light_before` (`any_clues` 3 von 5); `migrate_7_to_8` darf erweitert werden (`test_save_migration.gd` hat die W0-Prüfungen `test_v7_fixtures_migrate_to_v8`, `test_v6_fixtures_chain_to_v8`, `test_v8_round_trip_is_identical`).
    - **P7:** keine W0-Vorgaben über §8 hinaus; die neue Figur `ph_chr_stranger` zuerst (§12.2).
12. **Lead-Anpassungen an fremden Tests (mechanisch, nur Version / Feldzahl / Fixture-Stand):** `test_phase3…8_scaffold.gd` (v8; „aktuell“ = `CURRENT`, „neuer“ = `CURRENT + 1`; Phase 5: + V8-Knoten in der Kette; Phase 7/8: 40 Record-Felder; Phase 8: `DATA_CHANGED_AFTER_W0` + `gains`/`event_points`/`events`/`reactions`), `test_save_migration.gd` (v8; `read_doc` 6 → 7 → 8; Ketten-Prüfungen + V8-Knoten/`letter_id`; neu: v7-Fixtures → v8, Toleranz, v6 → v8, v8-Roundtrip, Version 9 abgelehnt, leere Phase-9-Knoten verworfen), `test_saves_v4/v5/v6_load.gd`, `test_save_fuzzer.gd` (Format 8; **neu** `test_fuzz_v7_fixtures`, `test_fuzz_v8_phase9_parts`, Konsistenz: `letter_id` ein Name, Phase-9-Stats ganzzahlig), `test_hill_requests.gd`, `test_cart_delivery.gd` („aktuelles Format“), `test_corpse.gd` (40 Felder), `test_piety.gd`/`test_reputation.gd` (Daten = Phase-9-Fixture).
13. **Testzahl:** vor W0 3 016, nach W0 **3 059** (+ `test_phase9_scaffold.gd` 24, `test_saves_v7_load.gd` 10, `test_save_migration.gd` + 7, `test_save_fuzzer.gd` + 2), alle grün. Die alten Bots (Phase 3–8, `HillBot`) laufen unverändert grün.

## W1-Anschlüsse (Lead, 18.10.2026 – verbindlich für W2)
Alle W1-Pakete sind gemergt (P1+P4, P7, P3+P5, P2, P6; volle Suite auf dem gemergten Stand 3258/3258). Offene Anschlüsse aus den Berichten, je Besitzer in W2:

**W-Welt**
1. Systemknoten unter `Systems`: `Quests` (81), `WhoKnows` (82), `Letters` (83), `Stranger` (84).
2. `KnockDoor` an `door_sieber`; Reihe 4 (`l_13…l_16`) mit den Hindernissen `stump_row4` und `bramble_row4` (nicht dem alten Stumpf).
3. Wegpunkte `v_sieber_door`, `v_sieber_bench`, `v_in_inn_stranger` (inn_layout), `stranger_gate`, `sieber_gate`; Friedhofs-Variante für Johanns Abgangsweg.
4. Npc `npc_kin_sieber_v` (npc_id `kin_sieber_v`) und `stranger` (Brenneisen, nur auf `stranger_gate`, Regionen laut `StrangerRules.present`), Nachtwächter mit `ph_prop_watch_lantern`.
5. Prompt-Entitäten für Besuchsteile der großen Bitten an `gate_outside`, `v_bridge_unload`, `v_inn_cellar_help` (`HillRequests.visit_here/visit_prompt/start_visit`); Bögen an beiden Tafeln im Bild prüfen.
6. Esse: Brief-verbrennen-Prompt mit `place: &"forge"`.
7. P7-Hinweise: Brenneisens Kindmesh `case` bei K4 per Code ausblenden; `sit_inn` Wurzel auf Sitzmarker; `sit_cart` Sitz 0,45 m über der Wurzel.

**W-UI**
8. Icons der sieben `ph_item_*` (`icon_renderer.MODELS`, danach `--import`).
9. Merkbuch „Vorhaben“ (QuestLog) mit Verfolgen → HUD, „Die Liste“ (`JournalManager.list_page`), „Briefe“ (`letter_pages`); Brief-Panel (`Letters.choices/decide`), Brenneisen-Panel (`Stranger.offers`), große Bitten in `hill_requests_panel`/Orders-Panel (`large_card`, `ctx.large_cards`, `hill_place`), HUD `objective_state().large/large_waiting/large_line`; Stempel „halb“.
10. Player/ToolAnimConfig: `action_clips` `desk_read_book`, `desk_write_letter`, `stove_burn_letter`, `grave_kneel_read`, `grave_read_aloud`, `grave_lay_letter`, `grave_take_soil` auf P7-Clips; `ph_tool_*` nach `asset_character.HOLD_PROPS` an `hold_r`/`hold_l` (Schaufel bleibt auf dem Rücken).
11. Debug-Befehle laut §6 (u. a. `pin_large`, `set_part`, `large_board`, Ketten springen).

**Lead-Rest (eigenes W2-Paket „Anschlüsse“)**
12. GhostManager: `Letters.ghost_bonus(grave)` zu `care`, `GhostMood.letter_care_key(key, letters.letter_tonight(grave))`.
13. Launen bei Ende C (§2.2.8): `NpcLifeConfig` + zwei Regeln nach `own_step` (`{rumor, cross, [priest, surgeon, washer], days 1, events [q_public]}`, `{rumor, low, [grocer, mayor], days 2, events [q_public]}`), `test_phase8_scaffold`/`DATA_CHANGED_AFTER_W0` nachziehen; Ausnahme für den Vertrauten im Code.
14. Zeitplan-Flags: `sieber_depart_peddler_day`/`sieber_depart_carter_day` (aus `depart_plan()`), `sieber_watch_day`, `sieber_evening_day` (solange `oq_johann_evening` läuft), `stranger_day`/`stranger_arrive_day`.
15. `CorpseManager.STORY_KIN`: `d3_sieber → house_sieber`; D3-Geisterzeilen je Ende in `ghost_lines.tres`.
16. Werte aus dem Code nach `data/` (`WhoKnowsConfig`): `GONE_AFTER_MINUTES 40`, `B_CONFIDANT_REL 3`, `DEATH_PATHS`, `q_who_knows`.
17. `LetterData.KINDS` um `errand`/`reply`; Phase-4-Fund `f_letter` nicht zusätzlich bei Pool-Briefen; Strohblumen wirken zwei Tage wie Grabblumen (GraveCare); Koffer nicht in den Schuppen; Quasts Tropfen in Ende B (`fever_tincture`) im Laden.
18. Johanns Besuchsfenster 10:00–11:00 erzwingen; Liesels sichtbare Totenwache (Ende B).

**Entscheidung offen (Benutzer):** Messziel große Bitten – gemessen 1887 min statt ≤ 1700 (Tag 14: 129 Münzen); Alternative 2 Plätze/Abklingzeit 6 ≈ 1795 min bei ≈ 140 Münzen.

## W3-Restbedarf (Lead, 18.10.2026 – Anpassungen am Vertrag; Notiz und Bilder `docs/reviews/phase9_round1/fixes/fixes.md`)
1. **Grab-Prompts (§7.5):** „[E] Datum vergleichen“ kommt vor Blumen, Kranz, Strohblumen und der übrigen Pflege (nur Münzen auf dem Stein und „Grab wieder schließen“ davor); „[E] Strohblumen aufs Grab legen“ (`CARE_STRAW`) mit Test. Die Brief-Karte öffnet sich an Pult/Ofen/Grab **nicht** – die Orts-Prompts erledigen ihre Wahl direkt (ein Tastendruck), die Karte bleibt im Merkbuch „Briefe“.
2. **Nachtwege `np_sieber` (§2.2.7):** Quast (`night_np_sieber_surgeon_day`, Licht + 19, 22:30–23:10) und Lenz mit Laterne (`night_np_sieber_priest_day`, Licht + 20, 21:00–21:40) gehen wie zu den Otts über Brunnen, Holderbrücke und `v_sieber_lane_n/e/s`/`v_sieber_yard` zur Tür (je 40 Min Weg); Physik-Wegtest grün.
3. **Ende B (§2.2.6/§2.2.7):** der Vertraute aus H5 sitzt mit – Lenz am ersten, Liesel am zweiten Abend (`sieber_evening_priest_day` / `sieber_evening_washer_day`, gesetzt von `WhoKnows` über `Orders.meetings_before(oq_johann_evening)`), Platz `v_sieber_bench_2` (0,55 m neben Johann), neue Clips `sit_bench` für `ph_chr_v_priest`/`ph_chr_v_washer` (Körper und alte Clips hash-gleich). Quast kommt nicht (Tropfen).
4. **Nachtwächter (§12.4 Prio B, D12):** jetzt Figur `ph_chr_watchman` (Aufbau wie Johann, `asset_mourners.py`; Mantel, Mütze, Stock, Laterne rechts mit Marker `light_lantern`; Clips idle, walk, talk, stand_watch; 6674 Dreiecke) auf `v_sieber_watch` neben der Tür; kommt 20:20 vom Amtshaus, geht 06:00 zurück. `ph_prop_watch_lantern` bleibt als Requisit, ist aber nicht mehr in der Welt.
5. **Hannes Weg (§4.7):** `gather_alder_1` und `forest.bushes[0]` 2 m nach Süden, dazu `gather_alder_2`/`_3` 1 m nach Süden und die Eiche `forest.trees[0]` 1 m nach Westen und Süden – der Abgang ist bei Zoom 12/22/24 **ohne Aussparung** frei (`test_w3_departure_free_without_the_cutout`, 0 Strahlen verdeckt).
6. `LettersConfig.read_minutes` = 5 (Brief-Karte „Lesen“).
7. **UI (§7.6):** Karten-Legende ab `p9_open` mit Brenneisen, großem Bogen, Lesezeichen (Krankenlicht-Zeile nennt das Licht bei den Siebers); Gräber/Leute auf der Karte größer (`grave_radius` 5, `person_radius` 8); Grabregister „Licht: …“ in eigener Zeile der Spalte „Angehörige“; Brenneisen-Panel kompakt (700 px, alle vier Angebote bei 1280 × 720 ohne Rollen sichtbar).
8. **Johann auf dem Karren (§4.5):** mittig auf der Stirnwand gegenüber von Osric (Oberkante 0,83 m), Rücken zur Ladefläche, die Beine über der Kante, Blick den Weg hinab – vorher saß er an der rechten hinteren Ecke 0,6 m außerhalb in der Luft.
