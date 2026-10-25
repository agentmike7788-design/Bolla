# Phase 10 – Wirtschaft – Vertrag v1

Status: **v1 – verbindlich für die Umsetzung (§14 vom Benutzer am 24.10.2026 entschieden)** · Verantwortlich: Agent 01 (Lead), Agent 02 (Game Design), Agent 03 (World Design), Agent 06 (Character Art), Agent 07 (Animation), Agent 08 (Godot Core), Agent 12 (NPC/AI), Agent 13 (Quest/Story), **Agent 14 (Crafting/Economy, federführend für die Balance)**, Agent 17 (Audio), Agent 18 (UI/UX), Agent 19 (QA)
Baut auf `docs/PHASE9_DESIGN.md` (Vertrag v1, freigegeben 24.10.2026 inkl. W3-Restbedarf, QA-Fix und G9-Entscheidungen), `docs/PHASE8_DESIGN.md`, `docs/PHASE7_DESIGN.md`, `docs/PHASE6_DESIGN.md`, `docs/PHASE5_DESIGN.md`, `docs/PHASE4_DESIGN.md`, `docs/PHASE3_DESIGN.md` und `docs/VERTICAL_SLICE_DESIGN.md` auf. Was dieses Dokument nicht ändert, gilt dort unverändert weiter. Referenz-Build: **6f0bd9c** (Gate G9 freigegeben, 3 394 Tests, Browser-Testversion v19). Der Lead trägt in den W0-Notizen den Hash ein, auf dem die v8-Fixtures entstehen (§5.3).
Gameplay-Werte sind **Vorschläge**; der Benutzer prüft sie beim Gate G10. ART STYLE LOCK „Gemaltes Diorama“ ist aktiv: Phase 10 ändert den Stil nicht. Maler-Shader (`painted.gdshader`, `painted_common.gdshaderinc`, `painted_foliage.gdshader`), Atmosphären-Presets, Flackerlicht, der gemeinsame Gesichtsaufbau (`tools/blender/lib_faces.py`) und das Rig (9 Knochen mit `tool`) bleiben unverändert und werden für die neue Figur **wiederverwendet**. Friedhof, Dorf, alle Gebäude und Innenräume bleiben bitgleich, **außer** den in §4.5 vollständig aufgezählten Eingriffen (Marktplätze auf dem Anger, Opferstock am Friedhofstor, Kassenbuch auf dem Hüttenpult, Marktzettel an der Gemeindetafel, Weg der Marktfahrerin).

**Benutzerentscheidungen (verbindlich, 24.10.2026)**
- **Inhalt:**
  1. **Preise & Balance.** Alle Einnahmen und Ausgaben werden neu abgestimmt: Bestattungslohn, Bitten (klein und groß), Briefe, Präparate, Läden, Verwerten usw. Das Geld soll **bis ins späte Spiel spannend** bleiben. Einbezogen werden die offenen Punkte aus früheren Gates: G5 „Münzausgleich Verwerten → Phase 10“, G8 E8-2 „Münzausgleich“, G9 Nr. 3 „Phase-9-Bogen +55 bis +64 Münzen statt ≤ +50 – Abstimmung in Phase 10“ und die Messwerte der Bots aus Phase 3–9 (§2.1).
  2. **Markt & Handel.** Ein **Wochenmarkt** im Dorf mit wechselnden Preisen und Angeboten. Der Spieler verkauft eigene Waren, z. B. Holzkreuze, Kräuter, Kerzen, Grabschmuck.
  3. **Friedhofskasse & Gemeinde.** Die Gemeinde zahlt **nach Friedhofsqualität**; dazu **Steuern, Pacht und Spenden**; ein kleines **Kassenbuch mit Monatsabrechnung**.
- **Nicht gewählt:** „Ausgaben & Verschleiß“ (Werkzeugabnutzung, Gebäudeunterhalt, höherer Lehrlingslohn) → §13.
- **Umfang: mittel**, etwa wie Phase 8/9: die Balance wird **überall** neu abgestimmt, dazu **zwei neue Systeme** (Gemeindekasse mit Kassenbuch, Wochenmarkt). Sauber nach A/B/C priorisiert mit Begründung und Streichreihenfolge (§12.4).
- **Schwierigkeit: „Gemütlich knapp“.** Man kommt immer zurecht, muss aber wählen, was man zuerst kauft oder baut. **Kein Scheitern durch Geldnot, keine Schuldenspirale.**
- **Ton:** melancholisch, warm, trockener Humor; „Tod ist Handwerk, nicht Horror“. Nur eigene Inhalte. ART STYLE LOCK gilt. **Angeln bleibt Phase 11.**

**Lehren aus G9 (verbindlich für alle Pakete)**
- **Eine Auswahl, wo ein Ort mehr als eine Sache kann** (W3 QA-Fix, `ActionChoicePanel`): Marktstand (aufbauen · verkaufen · abbauen), Hüttenpult (Kladde · Kassenbuch · Antwort), Opferstock am Tor (leeren · selbst geben) zeigen „[E] …“ mit kurzer Auswahl; die Hauptaktion hat den Fokus. Kein Tastendruck tut etwas, das man nicht zurücknehmen kann, ohne dass es dasteht.
- **Natürliches Gehtempo** (G9 Nr. 1): neue Wege (Marktfahrerin, Marktgäste, Haushalte an ihren Ständen) rechnen ihre Zeit aus der Polylinie (`NpcConfig.walk_m_per_minute` 0,8; Karren 0,55) – „Ankunft bleibt, Abfahrt früher“. Die Generatoren (`tools/dialogue/build_phase*_schedules.py`, `walk_tempo.py`) bekommen die Samstagswege; `test_walk_tempo` prüft sie mit.
- **Keine verborgene Uhr** (G9 Nr. 5): Eine Frist läuft erst, wenn der Spieler davon weiß. Die erste Monatsabrechnung zählt erst ab der Eröffnung des Kassenbuchs; die Zahlfrist steht im HUD und im Merkbuch.
- **Alle Menüvarianten gleich** (QA9-T1): Wo eine Figur ein warmes und ein kühles Menü hat (Osric `menu`/`menu_cold`, Fenner nach Ruf), bekommen **beide** die Phase-10-Zeilen (Friedhofsgeld, Abgaben zahlen, Marktstand).
- **Gemessene Bänder statt Wunschzahlen** (G9 Nr. 3/4/6): Jede Münzgrenze dieses Vertrags ist ein Band, das W1 misst und W3 bestätigt; liegt eine Messung daneben, gilt die Stellschrauben-Reihenfolge (§2.4.4), danach entscheidet der Benutzer.
- **Sichtbar, angedockt, hörbar, exportfest** (G8): Wer zum Markt kommt, kommt sichtbar über die Holderbrücke; neue Panels rechts angedockt unter der HUD-Leiste, ohne Abdunklung; Ereignisse mit Ton und HUD-Zeile (Handglocke „Markt ist offen“, Münzen im Opferstock); Text-Ressourcen bleiben Text, jede Welle prüft auch das exportierte pck (Compatibility).
- **Deterministisch:** Keine globale Zufallszahl. Marktlage, Angebote und Kundschaft über `hash([Woche, Stand, Ware])`; nichts ändert sich durch Neuladen.

**Regeln für alle Agents** (wie Phase 3–9)
- Klassen, Signaturen, Dateipfade, Signale und Datenformate hier sind **fest**. Änderungen nur über den Lead.
- Der Lead legt in **Welle 0** alle Datenklassen (✦) vollständig und alle Logikklassen als **Stubs mit exakten Signaturen** an. Die Besitzer füllen die Körper und benennen nichts um.
- Nach jedem neuen Worktree und nach jedem Merge: `godot --headless --path . --import`.
- Jede Datei hat genau einen Besitzer (§3.2). Fremde Dateien nicht ändern; Bedarf an den Lead melden.
- **Alle Spielwerte in `data/`.** Kein Preis, keine Quote, kein Schwellwert steht im Code. Das Tarifblatt (§2.4) wird aus den Daten erzeugt und geprüft (`tools/economy/tariff_report.py`, `test_tariff_sheet.gd`).
- Alle neuen Assets tragen `ph_` und kommen in die Placeholder-Liste (`docs/QUALITY_GATE_STATUS.md`).
- Keine Mechaniken, Namen oder Texte anderer Spiele übernehmen. Ausdrücklich **nicht**: Feilsch-Minispiele mit Balken oder Würfeln, Börsenkurse mit Diagramm-Ticker, Kredite und Zinsen, Schuldenspiralen, Pfändung, Gefängnis, Bankrott-Bildschirm; ein Händler, dessen Angebot sich durch Neuladen ändert; Kaufrausch-Belohnungen („Kaufe 10, erhalte 1“); Ladenstufen und Geschäftsimperium; Preise, die der Spieler beliebig setzt (es gibt drei Preisschilder, §2.7.5); Leichenhandel als Mechanik.
- **Eigene Identität dieser Phase: „Soll und Haben“.** In Phase 9 fragte der Totengräber, wer weiß, wann einer stirbt. Jetzt fragt das Dorf, was ein Totengräber kostet – und was er wert ist. Wenn der Hügel voll ist, lebt er von seinem Handwerk und von dem, was die Gemeinde an seinem Friedhof sieht. Fenner führt ein Buch; der Totengräber bekommt ein eigenes.
- Sprache: alle Spieltexte eigenständig auf Deutsch, trocken-melancholisch und würdig. Fenner spricht wie ein Mann, der lieber eine Akte hat als eine Meinung; die Marktfahrerin redet schnell und rechnet laut; die Trauernden kaufen Kerzen, als würden sie sich entschuldigen. Kein Spott über Arme, keine Gier-Komik.

---

## 1. Spielablauf & Progression

### 1.1 Erweiterter Kern-Loop
```
JEDES SPIEL, AB TAG 1: neuer Tarif (§2.4) · Kassenbuch im Merkbuch „Kasse“ (§2.6)
  └ jede Münze, die kommt oder geht, steht mit Quelle bzw. Zweck im Buch; was ohne Buchung in den Beutel kommt, steht „ohne Beleg“

JEDE WOCHE (Wochentage ab Phase 10, §2.7.1; Tag 1 = Freitag, 3. Gilbhart 1834)
  So 18:00  FRIEDHOFSSCHAU: Friedhofsstufe + Pflege der Gräber → Friedhofsgeld (+ Bedarfszulage, Notgroschen)
  Mo 07:40  Osric bringt das Friedhofsgeld mit („Fenner hat's gezählt. Ich hab's nicht.“)
  Do        MARKTZETTEL an der Gemeindetafel: was am Samstag gefragt ist, was reichlich da ist (ab village_open)
  Sa 08:00–12:30 WOCHENMARKT auf dem Anger (ab village_open)
       └ Stände: Agathe Wendel (Ellbach, Stadtware), Hof Kehr (Wachs, Honig, Saat), Hof Brandt (Holz, Flachs, Garn)
       └ EIGENER STAND (Fenner gibt den Platz, Standgeld 1): Holzkreuze, Kräuter, Grabkerzen, Wachskränze
            aufbauen → Preisschild je Ware (günstig · recht · teuer) → am Stand stehen → Kundschaft kauft → abbauen

JEDER MONATSERSTE, 06:00: MONATSABRECHNUNG (Fenner; vor village_open bringt Osric den Zettel)
  └ Einnahmen nach Quelle · Ausgaben nach Zweck · Friedhofsgeld · Spenden
  └ Abgaben: PACHT (Bruch und Werkhof) · GEMEINDEABGABE „der Zehnte“ (auf belegte Einnahmen) · SCHÄTZUNG (auf „ohne Beleg“)
  └ zahlen bis zum 7. bei Fenner (Amtsstube) oder Osric (Karren) → sonst AUFSCHUB ohne Zins → nach einem Monat ERLASS
AM TOR: OPFERSTOCK „Für den Gottesacker“ – zufriedene Besucher werfen eine Münze ein; der Totengräber leert ihn (Spenden)
```
Alle Handgriffe aus Phase 2–9 bleiben **unverändert**; nur ihre Preise und Löhne folgen dem Tarif (§2.4). Wer nie auf den Markt geht, spielt weiter wie bisher – mit weniger Einnahmen im Spätspiel und ohne das Kapitel.

### 1.2 Freischaltung
- **Tarif, Kassenbuch, Friedhofsgeld, Opferstock:** in **jedem** Spiel ab Tag 1 (neues Spiel) bzw. ab dem Laden (alter Stand). Das Kassenbuch beginnt mit dem ersten Tag, den es sieht (`cash_book.open_day`); ältere Tage rekonstruiert es nicht („Was vorher war, steht in Lorenz' Buch. Das hat keiner.“).
- **Monatsabrechnung:** am ersten Monatsersten **nach** der Bucheröffnung (neues Spiel: Tag 30 = 1. Nebelung). Pacht erst ab dem **Pachtbrief** (früher Steinbruchbrief, Phase 5 – §2.5.5), Zehnt und Schätzung erst ab `village_open` („Die Gemeinde kennt dich noch nicht. Sie zählt dich aber schon.“). Der erste Monat wird **anteilig** gerechnet (Tage seit Bucheröffnung).
- **Wochenmarkt:** ab `village_open`, jeden Samstag. Der **eigene Stand** ab dem ersten Gespräch mit Fenner nach `village_open` („[Markt] Kann ich am Samstag einen Stand haben?“, Flag `market_stall_granted`).
- **Kapitel „Soll und Haben“** (§1.5): öffnet mit dem Phase-9-Kapitel `who_knows_when_complete`. Am ersten Morgen danach (erste Minute ≥ 06:00, idempotent) setzt `Treasury.apply_morning` das Flag `p10_open` und speichert `p10_open_day`. **Migrierte v8-Stände:** Ist `who_knows_when_complete` gesetzt, setzt `Treasury.post_load` `p10_open` sofort (Muster Phase 6–9).
- Osric `p10_intro` (Leittext, P5 darf glätten): „Fenner hat sich ein Buch gekauft. Ein dickes. Er sagt, ab jetzt wird gerechnet. Ich hab gesagt, gerechnet wird immer. Er sagt: aufgeschrieben. Er will dich sprechen. Bring Zeit mit, er hat Spalten.“

### 1.3 Zeitkosten (Spielminuten; TimedAction wie bisher, 0,5 s Echtzeit je Spielminute)
| Handlung | Min | Braucht | Abbrechbar |
|---|---|---|---|
| Kassenbuch lesen (Merkbuch „Kasse“) | 0 | – | – |
| Monatsabrechnung durchsehen (Hütte, Pult `Desk`, Clip `write`) | 10 | Abrechnung liegt vor | ja |
| Abgaben zahlen (Fenner im Amt, Osric am Karren) | 0 (Dialog) | Münzen | – |
| Opferstock leeren (Tor) | 2 | – | – |
| Stand aufbauen (Anger, Samstag 07:30–12:00) | 10 | `market_stall_granted`, Standgeld 1, Waren | ja |
| Am Stand verkaufen (in Takten zu 30 Min bis 12:30) | 30 je Takt | Stand aufgebaut | ja (nach jedem Takt) |
| Stand abbauen | 5 | – | – |
| Bei einem Marktstand kaufen | 0 (Panel) | – | – |
| Grabkerzen ziehen (Werkbank, neues Rezept) | 20 | 1 Bienenwachs + 1 Garn → 4 | ja |
| Wachskranz binden (Werkbank, neues Rezept) | 25 | 2 Bienenwachs + 1 Wacholder + 1 Garn → 1 | ja |
| Rosenstock aufs Grab setzen | 10 | `rose_bush`, Grab belegt | ja |
| Weg Friedhof ↔ Dorf | 30 je Richtung (Phase 7) | – | – |

*Begründung:* Der Markt kostet einen **Vormittag** (Weg 30 + Aufbau 10 + 2–8 Takte + Abbau 5 + Weg 30) und die Werkbankzeit für die Waren davor. Damit ist er eine Wahl gegen Pflege, Bitten und Werkhof – genau das „Was mache ich zuerst?“ des Benutzers.

### 1.4 Tagesbogen
**A) Referenz: Phase-9-Endstand (`kindly9`, v8-Fixture `slot_p9_day75_kindly`, Tag 75 = Dienstag, 16. Julmond 1834, 07:00; gemessen G9: Kapitel an Tag 69, Ende A mit Osric, ≈ 132 Münzen, Reihe 4 bis auf eine Stelle belegt).** Der Bogen dauert **17 Tage** (B1 = Tag 75 … B17 = Tag 91 = 1. Hartung 1835), weil das Kapitel eine echte Monatsabrechnung braucht und die erste nach Bucheröffnung am Monatsersten fällt (Bestätigung §14.2). Er enthält **zwei Markttage** (B5, B12), **zwei Friedhofsschauen** (B6, B13) mit Auszahlung (B7, B14) und die **Monatsabrechnung Julmond** (B17). Richtwert Mensch; der Bot `kindly10` spielt ihn nach (§10). Weihnachten (B10) und Silvester (B16) sind Kalendertage ohne Fest-Mechanik (§13).

| Tag (Bogen) | Wochentag | Geschehen | Münzen früh → abends (§2.9) | Zielzeile (Beispiel) |
|---|---|---|---|---|
| 75 (B1) | Di | Osric `p10_intro`. Im Dorf: Fenner eröffnet das Kassenbuch („Jeden Sonntag schau ich, am Ersten rechnen wir ab.“), gibt den Marktplatz (`market_stall_granted`). Bei Theres 8 Bienenwachs. | 132 → 124 | „Sprich mit Fenner (Amtsstube)“ |
| 76 (B2) | Mi | Werkbank: 8 Grabkerzen, 2 Wachskränze. Große Bitte am Tor. | 124 → 124 | „Waren für den Markt (Werkbank)“ |
| 77 (B3) | Do | Lieferung auf die letzte freie Stelle (Reihe 4), Bestattung, Aussegnung. **Marktzettel:** „Gefragt: Kerzen. Reichlich: Holz.“ | 124 → 135 | „Marktzettel lesen (Gemeindetafel)“ |
| 78 (B4) | Fr | 3 Holzkreuze, 3 Kräuterbündel. Abends HUD „Morgen ist Markt in Hollerbrück.“ Opferstock leeren. | 135 → 134 | „Morgen ist Markt“ |
| 79 (B5) | Sa | **Markt 1:** Stand aufbauen, Preisschilder (Kerzen „teuer“, Kreuze „günstig“), 4 Takte am Stand (≈ 22). Bei Agathe: Rosenstock, Messinglaterne. | 134 → 130 | „Am Stand: 6 Kerzen, 2 Kränze, 3 Kreuze“ |
| 80 (B6) | So | Rosenstock auf Paul Kehrs Grab. **Friedhofsschau** 18:00 („Ehrwürdig, gepflegt“). | 130 → 131 | „Friedhofsschau heute Abend“ |
| 81 (B7) | Mo | Osric bringt das **Friedhofsgeld** (anteilig, 12). | 131 → 135 | – |
| 82 (B8) | Di | Auftrag im Dorf, kleine Bitte. | 135 → 135 | – |
| 83 (B9) | Mi | Heiligabend: Lenz hat „heute keine Zeit für Tote, nur für einen“. Almosen. | 135 → 132 | – |
| 84 (B10) | Do | Weihnachten. **Marktzettel 2** (Fenner hängt ihn auch heute aus: „Ordnung kennt keine Feiertage.“): „Gefragt: Holz (Frost). Reichlich: Kerzen.“ | 132 → 132 | „Marktzettel lesen“ |
| 85 (B11) | Fr | Holzkreuze statt Kerzen (die Marktlage lesen lohnt). | 132 → 130 | „Morgen ist Markt“ |
| 86 (B12) | Sa | **Markt 2** (≈ 18), zweiter Rosenstock. | 130 → 132 | „Am Stand: …“ |
| 87 (B13) | So | Friedhofsschau 2. | 132 → 131 | – |
| 88 (B14) | Mo | Friedhofsgeld 2 (14). Große Bitte im Dorf erfüllt. | 131 → 143 | – |
| 89 (B15) | Di | Wünsche der Trauernden, Kerzen. | 143 → 140 | – |
| 90 (B16) | Mi | Silvester. Fenner: „Morgen rechnen wir ab. Bringen Sie keine Ausreden mit, ich hab genug eigene.“ Runde im Holderkrug (freiwillig). | 140 → 134 | „Morgen: Monatsabrechnung“ |
| 91 (B17) | Do | **Monatsabrechnung Julmond** am Hüttenpult (10 Min), **Abgaben** 13 bei Osric gezahlt → **Kapitel „Soll und Haben“**. | 134 → 119 | „Abgaben bis 7. Hartung: 13 Münzen“ |

**B) Neues Spiel:** Alle Werte aus §2.4 gelten ab Tag 1. Erste Friedhofsschau Tag 3 (Sonntag, anteilig), erste Auszahlung Tag 4, erste Monatsabrechnung **Tag 30** (1. Nebelung; nur Pacht, falls der Pachtbrief schon da ist), Markt ab `village_open` (G7/G8: Tag 37–42), Kapitel nach `who_knows_when` (G9: `founder9` Tag 67) an der nächsten Monatsabrechnung mit Markt (≈ Tag 91 oder 121). Die Zielkurve über das ganze Spiel misst `curve10` (§2.3, §10).

### 1.5 Phasenziel – Kapitel „Soll und Haben“ (`debit_credit`)
Erfüllt, sobald **alle** gelten (geprüft von `Treasury.check_goal` bei `settlement_changed`, `market_changed`, `parish_paid`), jeweils **seit `p10_open`**:
1. Eine **Monatsabrechnung ist abgeschlossen** – bezahlt, aufgeschoben oder erlassen (§2.5.7). Wer nicht zahlen kann, verliert das Kapitel nicht.
2. An **zwei Markttagen** am eigenen Stand verkauft (je mindestens ein Stück).
3. Eine **Friedhofsschau** mit Stufe **„Würdevoll“ oder höher** (§2.5.2).

Dann: Flag `debit_credit_complete`, `chapter_completed(&"debit_credit")`, Abschluss-Panel Variante `debit_credit`. Es zeigt: Tage seit `p10_open`, Einnahmen nach Quelle und Ausgaben nach Zweck (aus dem Kassenbuch), Friedhofsgeld je Woche mit Stufe, die Abrechnung(en) mit Pacht, Zehnt, Schätzung und wie sie ausging, Markttage (verkauft je Ware, gekauft), Spenden aus dem Opferstock, „ohne Beleg“ als eigene Zeile, das Polster am Anfang und am Ende. Schlusszeile (P5): „Soll und Haben stimmen. Das Buch weiß nicht, was ein Grab wert ist. Du schon.“ Danach läuft das Spiel frei weiter. **Gate-Ziel:** alle Bot-Strategien außer `lazy10` erreichen das Kapitel, auch `poor10` (Aufschub) und `trader10` (verwertend); keine sperrt es durch Geldnot.

### 1.6 Erzählfaden (klein, Priorität B)
Phase 10 hat **keine neue Kette**. Zwei Haken, beide nur Text und Flag:
- **Lorenz' Pacht:** In der ersten Monatsabrechnung, die Pacht verlangt, steht bei „Pacht Bruch und Werkhof“: „bezahlt bis Lichtmess 1835 – L. A., eingegangen im Gilbhart 1834“. Fenner: „Er hat im Voraus gezahlt. Im Gilbhart. Da waren Sie schon hier und er schon fort. Ich buche nur, ich frage nicht.“ → Hinweis `c_k_rent_paid`, Pacht für diesen und den nächsten Monat 0 (Haken Phase 12 zu `i_still_writing`).
- **Fenners Lichterbuch** (Ende C, Phase 9): eine Zeile in der Abrechnung „Lichterbuch: keine neuen Einträge.“ – sonst nichts.
- Belohnung wie Phase 4/7/8/9: Text, Flag, Zeile im Abschluss-Panel.

---

## 2. Spielwerte (Vorschläge, alle in `data/`)

### 2.1 Ist-Ökonomie (Messungen der Bots, Phase 3–9)
Quellen: `docs/reviews/phase3_wip/qa_playthrough.md` … `phase9_wip/qa_g9.md`, `phase8_round6/bitten.md`, `phase9_round1/bitten_gross.md`, Vertragsrechnungen PHASE4 §2.15, PHASE5 §2.8, PHASE6 §2.8/§2.8a, PHASE7 §2.10, PHASE8 §2.10, PHASE9 §2.8. „Münzen“ = Beutel + Truhen + Lohndose. Wo eine Phase nachgemessen wurde, steht der letzte Stand.

| Abschnitt · Bot | Tage | Start → Ende (Δ) | Einnahmen (größte Quellen) | Ausgaben (größte Zwecke) | Ausgabequote | morgens min. |
|---|---|---|---|---|---|---|
| P3 `diligent` (neues Spiel) | 1–14 | 5 → 58 (+53) | 172 (Bestattung ≈ 138 = 12 × 11,5, Geistergaben 24, Pflegegeld ≈ 10) | 119 (Leinen, Saat, Zier) | 69 % | – |
| P3 `hoarder` | 1–14 | 5 → 52 | 140 | 93 | 66 % | – |
| HillBot Pflicht, ohne Bitten (G8 R6) | 1–14 | 5 → 51 | – | – | – | – |
| HillBot Pflicht + kleine Bitten (G8 R6) | 1–14 | 5 → 105 | + 32 aus 18 kleinen Bitten | – | – | – |
| HillBot Pflicht + kleine + große Bitten (G9) | 1–14 | 5 → **129** | + ≈ 20 aus großen Bitten | – | – | – |
| HillBot andächtig (G9) | 1–14 | 5 → 99 | – | – | – | – |
| P4 `reverent` | 10–24 | → 129 (Tag 24) | 11,0 je Grab, Pflegegeld 4/Tag | Totenhemd, Wacholder | – | – |
| P4 `harvester` | 10–28 | → **183** (Tag 28) | 4,4 je Grab + Ilse ≈ 11 je Leiche + Wertsachen 38 | Leinen bei Ilse | – | – |
| P5 `reverent5` | 20–30 | 125 → 27 (−98) | 40 (Pflegegeld) | 138 (Brief 20, Bau 50, Osric 50, Ilse 18) | 345 % | 17 |
| P5 `harvester5` | 25–35 | 178 → **102** (−76) | 26 | 102 (nur Pflicht) | 392 % | – |
| P5 `crafter` (neues Spiel) | 1–30 | 5 → 53 (+48) | 342 (Bestattung 198, Pflegegeld 105, Gaben 39) | 294 (Osric 139, Ilse 85, Brief 20, Bau 50) | 86 % | 15 |
| P6 `reverent6` (nach §2.8a) | 30–40 | 27 → 42 (+15) | ≈ 151 (Bestattung 67, Pflegegeld 40, Umbettgeld 20, Gaben 15, Aussegnung 9) | ≈ 136 (Gebäude 115, Osric 12, Ilse 16) | ≈ 90 % | 14 |
| P6 `harvester6` | 35–45 | 102 → 63 | 188 (Ilse 55, Wertsachen 11, Bestattung 46) | 227 | 121 % | 90 |
| P6 `founder` (neues Spiel) | 1–36 | 5 → 40 (+35) | 481 (Bestattung 269, Pflegegeld 129, Gaben 54) | 446 (Osric 145, Ilse 101, Bau 50, Gebäude 130, Brief 20) | 93 % | 16 |
| P7 `neighbor7` (G7 R2) | 40–53 | 20 → 60 (+40) | 318 (Bestattung 117, Aufträge 56, Pflegegeld 52, Aussegnung 37, Gaben 27, Dorf-Verkauf 25) | 278 (Dorf 61, Spenden 42, Ilse 44, Gebäude 75, Runden 20) | 87 % | 12 |
| P7 `anatomist7` (G7 R2) | 40–53 | 20 → 71 (+51) | 381 (… Präparate 88, Vorlesung 7, Sammlung 8) | 330 | 87 % | 13 |
| P8 `kindly8` (G8 R1) | 53–62 | 48 → 68 (+20) | ≈ 168 (Bestattung 53, Pflegegeld 40, Aussegnung 21, Aufträge 19, Dorf-Verkauf 15, Gaben 12, Trinkgeld 10) | ≈ 148 (Dorf 82, Ilse 22, Lehrling 21, Spenden 10, Almosen 7) | 88 % | 24 |
| P8 `anatomist8` (G8 R1) | 53–62 | 60 → 103 (**+43**) | Präparate 47, Pflegegeld 24, Trinkgeld 5 | 144 | – | 47 |
| P8 `night8` (G8 R1) | 53–62 | 48 → 101 (+53) | Pflegegeld 28 | 107 | – | 28 |
| P8 `lazy8` (G8 R1) | 53–62 | 48 → **140 (+92)** | 173 − 32 Pflegegeld-Kappe | 51 | 29 % | 48 |
| P8 `founder8` (G8 R1) | 48–60 | 52 → 57 (+5) | 238 | 249 (Dorf 152) | 105 % | 52 |
| P9 `kindly9` | 63–74 | 68 → **132 (+64)** | 140 (Bestattung 55, Aufträge 25, Trinkgeld 18, Aussegnung 14, Gaben 12, Pflegegeld 8, große Bitten 8) | 76 (Lehrling 30, Dorf 25, Almosen 11, Ilse 4, Osric 4, Post 2) | **54 %** | 67 |
| P9 `stay9` / `public9` / `silent9` | 63–74 | 68 → 131 (+63) | wie `kindly9` | wie `kindly9` | – | 67 |
| P9 `lazy9` | 63–74 | 68 → **161 (+93)** | – | – | – | 68 |
| P9 `founder9` | 61–67 | 57 → 127 (+70 in 7 Tagen) | – | – | – | 57 |
| P9 `trader9` | 64–75 | 103 → 112 (+9) | Kladde 40, Präparate, Brenneisen | – | – | 83 |

**Je Tag (Mittel):** Einnahmen P3 12,3 · P5 `crafter` 11,4 · P6 `founder` 13,4 · P7 24,5 · P8 16,8 · P9 11,7. Ausgaben P7 21,4 · P8 14,8 · **P9 6,3**. Anteile über `crafter`/`founder`: Bestattung 55–58 %, Pflegegeld 27–31 %, Geistergaben 11 %.

### 2.2 Befund (was die Messungen sagen)
1. **Die Bestattung trägt das Spiel, solange es freie Gräber gibt** (55–58 % der Einnahmen). Ist der Hügel voll (Ende Phase 9: Reihe 4 belegt), fällt die Hauptquelle weg. Das Spätspiel braucht deshalb eine **ruhige Grundlast** (Gemeinde) und **Handwerk** (Markt), die nicht an Toten hängen.
2. **Das Pflegegeld ist eine Klippe.** 4 Münzen täglich ohne Bezug zum Friedhof, seit G8 R1 an Tagen ab 80 Münzen ganz weg (`kindly9`: 8 statt ≈ 48 in 12 Tagen). Wer 79 hat, bekommt alles; wer 80 hat, nichts. Das belohnt Ausgeben kurz vor dem Morgen, nicht Pflege.
3. **Die Senken sind ungleich verteilt.** Phase 5 (108 Pflicht) und Phase 6 (115) ziehen den Beutel auf 14–17 Münzen – das ist „knapp“ und wurde nie kritisiert. Ab Phase 7 gibt es **keine bleibende Anschaffung mehr** außer Gruft 3/Kapelle 3; Phase 8 hat Verbrauch (Lehrling 3/Tag, Kerzen), Phase 9 fast nichts (Post 1). Folge: Ausgabequote 54 % (`kindly9`), Polster +64 in 12 Tagen (QA9-B1).
4. **Die Bitten haben das frühe Spiel reich gemacht.** HillBot Tag 14: 51 → 105 → 129 Münzen. Damit ist die Phase-5-Senke (108) schon an Tag 14 bezahlt, bevor der Werkhof überhaupt aufgeht – die Wahl „Werkzeug oder Station?“ entfällt.
5. **Faulheit lohnt.** `lazy8` +92 und `lazy9` +93 – mehr als jeder aktive Weg, weil Bestattungen und Aufträge weiterlaufen und nichts gekauft wird. Die Pflegegeld-Kappe hat nur 32 davon abgefangen.
6. **Verwerten bleibt reicher** (G5 E5, G8): `harvester` +54 gegen `reverent` (P4, Tag 24–28), `harvester5` 102 gegen 27, `anatomist7` +11 (gewollt +14), `anatomist8` +43 gegen +20. Die Geister und der Ruf kosten, aber nicht genug Münzen.
7. **Die Einzelpreise stimmen meistens.** Leinen 3, Kerze 2, Stationen 10–25, Gebäude 25–40 sind gelernt und tragen Phasen-Kapitel; sie werden **nicht** umgeworfen. Neu abgestimmt werden die **Flüsse**: woher Münzen kommen, wann sie gehen und was man im Spätspiel mit ihnen will.

### 2.3 Zielkurve „gemütlich knapp“
**Grundsätze (alle messbar, §10):**
1. **Boden – man kommt immer zurecht.** Jeder Bot hat morgens ≥ 5 Münzen; der würdevolle Weg ab Tag 7 ≥ 8. Die Gemeinde füllt unter 10 auf (Notgroschen, §2.5.3); Abgaben, die man nicht zahlen kann, werden aufgeschoben und nach einem Monat erlassen (§2.5.7). Es gibt keine negative Münze, keinen Zins, keine Sperre.
2. **Wahl – es gibt mehr zu kaufen, als hereinkommt.** An den Prüfpunkten (Tag 14, 30, 45, 60, 75, 91) kostet die **offene Wunschliste** (bleibende, sinnvolle Anschaffungen, die der Spieler noch nicht hat: Stationen, Stufen, Werkzeuge, Zier, Gitter, Gold, Rosenstöcke, Marktgüter; `data/economy/wishlist.tres`, §3.4) **mindestens das 1,3-Fache** der Einnahmen der nächsten 14 Tage. Wer alles will, muss wählen.
3. **Fluss – Geld wird ausgegeben.** Der würdevolle Weg gibt je Abschnitt **≥ 75 %** seiner Einnahmen aus (heute P9: 54 %).
4. **Kein Davonlaufen nach oben.** Polster und Zuwachs je Abschnitt im Band (Tabelle). Der faule Weg wird nicht reicher als der würdevolle plus **35** je Abschnitt (heute +29 … +72).
5. **Verwerten lohnt, aber wenig.** Der verwertende/anatomische Weg liegt je Abschnitt höchstens **15 % seiner Einnahmen** über dem würdevollen (heute bis +43 Münzen in 10 Tagen). Er bezahlt das mit Ruf, Pietät, Geistern – und mit der Schätzung (§2.5.6).
6. **Rhythmus.** Die Woche hat einen Zahltag (Montag), einen Markttag (Samstag); der Monat einen Abrechnungstag. Das Polster atmet: nach dem Markt und dem Friedhofsgeld voller, nach der Abrechnung leerer.

**Zielkurve (neues Spiel, Kette `curve10` = würdevolle Gründer-Bots Phase 3 → 10 auf dem neuen Tarif, morgens; §10):**
| Abschnitt | Tage (etwa) | Ist heute (Messung) | **Ziel Polster morgens** | **Ziel Δ im Abschnitt** | Ausgabequote | Wahl in diesem Abschnitt (Beispiel) |
|---|---|---|---|---|---|---|
| Ankunft & Friedhof (P2–3) | 1–14 | 5 → 58 (`diligent`), HillBot 129 | 5–60; **Tag 14: 30–60** | +25 … +55 | ≥ 60 % | Leinen oder Holzkreuz? Rechen oder Zier? |
| Leichen (P4) | 15–24 | → 129 / 183 (harvester) | 25–100 | +20 … +50 (Sparen auf den Werkhof) | ≥ 60 % | Totenhemd oder Tuch? Ilse? |
| Werkhof (P5) | 20–30 | 125 → 27, min 17 | 10–80; **min ≥ 10** | −60 … −20 | ≥ 85 % | Esse oder Spitzhacke zuerst? |
| Gebäude (P6) | 30–40 | 27 → 42, min 14 | 10–60; **min ≥ 8** | 0 … +25 | ≥ 85 % | Gruft 2 oder Kapelle? |
| Dorf (P7) | 40–53 | 20 → 60, min 12 | 15–70 | +15 … +40 | ≥ 80 % | Weihe, Spende, Runde, Pult |
| Leute (P8) | 53–63 | 48 → 68; lazy 140 | 25–80 | 0 … +20 | ≥ 80 % | Lehrling, Gitter, Kerzen |
| Fragen (P9) | 63–75 | 68 → 132 (+64); lazy +93 | 30–85 | 0 … +20 | ≥ 75 % | Post, Bitten, Brenneisen |
| **Wirtschaft (P10)** | 75–91 | – | **30–90** | **−20 … +15** | **≥ 85 %** | Rosen, Laterne, Waren, Abgaben |
| danach, Hügel voll | ab 92 | – | 30–90 | je 30 Tage −15 … +25 | ≥ 75 % | Rosen für alle, Gold, Stufen 3 |

**Für die Fixture-Bots** (Start aus dem alten Tarif, z. B. `kindly9` mit 132): Es gelten nur die **Δ-Bänder** und die Grundsätze 1, 3–5; die absoluten Bänder prüft allein `curve10`. *Begründung:* Die v8-Endstände tragen den Überschuss des alten Tarifs; Phase 10 soll ihn sichtbar in Markt und Gemeinde abfließen lassen (wie Phase 5 den Überschuss aus Phase 4), nicht wegnehmen.

### 2.4 Tarifblatt – die Balance-Änderungen (P1, alle Werte in `data/`, Übersicht erzeugt von `tools/economy/tariff_report.py`)
**Entscheidung: Einzelpreise bleiben, Flüsse werden neu gefasst.** Geändert wird, was die Messungen als Ursache zeigen (§2.2): die tägliche Gemeinde-Zahlung, die frühen Bitt-Münzen, die Verwertungs-Erlöse, die fehlenden Spätspiel-Senken. Was trägt (Stationen, Gebäude, Leinen, Kerzen), bleibt.

#### 2.4.1 Einnahmen
| # | Posten | Ort (`data/…`) | heute | **Phase 10** | Begründung · erwartete Wirkung |
|---|---|---|---|---|---|
| E1 | Pflegegeld der Gemeinde (täglich nach Ruf) | `config/reputation_config.tres` `stipend` | 0/1/2/3/4 je Tag | **0** (entfällt) | ersetzt durch E2; die Klippe bei 80 (`stipend_purse_cap`) entfällt mit (→ 0) |
| E2 | **Friedhofsgeld** (wöchentlich nach Friedhofsqualität, neu) | `config/treasury_config.tres` | – | Stufe 0/4/7/10/12 + Pflege 0–3, ≤ 15 je Woche · **Bedarfszulage** + ⌈(60 − Polster)/4⌉, ≤ 15 · Notgroschen bis 10 | §2.5; früh ≈ 1,7–2,7/Tag (heute ≈ 3), spät ≈ 2/Tag (heute 0,7 mit Kappe) |
| E3 | Bestattungslohn Grund (je Ursache) | `corpses/corpse_tables.tres` `base_payment` | 2–4 | **bleibt** | trägt das frühe Spiel |
| E4 | Bestattungslohn je Qualitätspunkt | `config/economy_config.tres` `payment_per_quality` | 0,5 | **bleibt** | – |
| E5 | Ruf-Zuschlag auf den Lohn | `config/reputation_config.tres` `pay_bonus` | −2/0/1/2/3 | **−2/0/1/2/2** | „Gerühmt“ −1 je Grab; spät ≈ −4 je Bogen |
| E6 | Aussegnung (Kapelle 1/2/3) | `config/chapel_config.tres` `service_fee_by_level` | 3/5/7 | **3/5/6** | P9 gemessen über Schätzung (14 statt 10) |
| E7 | Umbettgeld · Geistergabe · Weihe | `config/*` | 4 · 2 · 10/5/0 | **bleiben** | einmalig, sinnvoll |
| E8 | Kleine Bitten | `hill_requests/hr_*.tres` `reward_coins` | 1–3 (Ø 1,8) | **1–2 (Ø 1,2):** 1 für Bitten bis 40 Min Arbeit, 2 für längere | §2.2 Nr. 4; HillBot Tag 14 −10 |
| E9 | Große Bitten Tor · Dorf | `hill_requests/large/*` | 2–3 · 3–5 | **2 · 3–4** (`hrv_bridge_stones` 5 → 4); Dinge als Lohn bleiben | HillBot Tag 14 −8; Ruf/Beziehung bleiben der Hauptlohn |
| E10 | Aufträge im Dorf | `orders/o_*.tres`, `ob_*` | 3–11 | **bleiben** (G7 R2 abgestimmt) | – |
| E11 | Trinkgeld am Stein | `config/visitor_config.tres` `tip_cap_day` | Kappe 4/Tag | **Kappe 3/Tag**; dazu **1 Münze in den Opferstock** je zufriedenem Besuch (Kappe 2/Tag, §2.5.8) | Trinkgeld bleibt Lob, Spenden werden sichtbar |
| E12 | Ilse: Zopf · Zähne · Aufschlag „Abgebrüht“ | `config/utilization_config.tres` `sell_prices`, Aufschlag dort oder in `trader_config.tres` (W0 prüft den Ort) | 4 · 5 · +2 | **3 · 4 · +1** | G5 „Münzausgleich Verwerten“ |
| E13 | Wertsachen im Saum | `corpses/corpse_tables.tres` `valuables_coins_min/max` | 5–8 | **4–7** | G5; bleibt eine echte Versuchung |
| E14 | Quast: Augen · Hand · Herz (Grundpreis) | `config/anatomy_config.tres` | 11 · 12 · 9 | **10 · 11 · 8**; Vorlesungshonorar 4 bleibt | G8 (`anatomist8` +43 gegen +20) |
| E15 | Brenneisen (Fragen 1, Erde 3, Register 10, Schweigen 15, Kladde 40) | `config/stranger_config.tres`, `stranger/offers/*` | – | **bleiben** | Geschichte; die Versuchung soll groß sein |
| E16 | Botenlohn · Gegenbrief | `config/letters_config.tres` | 2 | **bleibt** | – |
| E17 | Läden kaufen an (Theres, Esch, Rosine, Quast, Liesel, Hanne) | `shops/*.tres` `buys` | 1–8 | **bleiben** (werktags); der Markt zahlt nach Marktlage (§2.7) | der Laden ist bequem, der Markt besser, wenn man die Lage liest |
| E18 | **Eigener Marktstand** (neu) | `market/wares/*.tres` | – | Grundwerte §2.7.5, Nachfrage gedeckelt | spät ≈ 15–30 je Markttag |

#### 2.4.2 Ausgaben
| # | Posten | Ort | heute | **Phase 10** | Begründung |
|---|---|---|---|---|---|
| A1 | Steinbruchbrief (Osric, Phase 5) | `dialogue/carter.tres` `p5_license` | 20 einmalig | **Pachtbrief 0** + **Pacht** (A7) | senkt die Phase-5-Pflicht von 108 auf 88 (früher Tarif knapper); die Münzen fließen langsam über Monate (Bestätigung §14.4) |
| A2 | Stationen · Gebäude · Werkzeuge | `stations/*`, `buildings/*`, `carter.tres` | 10–40 | **bleiben** | die Senken aus Phase 5/6 wirken (Ausgabequote 86–93 %) |
| A3 | Ladenpreise (Leinen 3, Kerzen 2, Setzlinge 2, Gitter 12 …) | `shops/*.tres` `sells` | – | **bleiben**, außer **Honigkuchen 1 → 2** | ein Geschenk für +4 Beziehung war zu billig (Bot-Gewohnheit „täglich Honigkuchen“, G9) |
| A4 | Lehrling | `config/apprentice_config.tres` `wage` | 3/Tag | **bleibt** (nicht gewählt, §13) | – |
| A5 | Runde · Spende · Almosen · Postgeld | `config/village_config.tres`, `letters_config` | 5 · 5er-Schritte · 1 · 1 | **bleiben** | – |
| A6 | Ilses Nachtware (Leinen 2, Wacholder 1, Gold 6) | `config/trader_config.tres` | – | **bleibt** | billig ist ihr Wesen |
| A7 | **Pacht** „Bruch und Werkhof“ (neu) | `config/treasury_config.tres` `rent` | – | **8 je Monat** ab dem Pachtbrief, anteilig im ersten Monat | §2.5.5 |
| A8 | **Gemeindeabgabe „der Zehnte“** (neu) | `treasury_config` `tithe_percent`, `tithe_cap` | – | **10 % der belegten Einnahmen** des Monats, abgerundet, ≤ 25, ab `village_open` | §2.5.6; wer viel verdient, gibt mehr |
| A9 | **Schätzung** (neu) | `treasury_config` `estimate_*` | – | **10 % von „ohne Beleg“**, wenn > 20 im Monat, ≤ 15, ab `village_open` | §2.5.6; der G5/G8-Ausgleich für Verwerten |
| A10 | **Standgeld** (neu) | `config/market_config.tres` `stall_fee` | – | **1 je Markttag** | Fenner ist Marktmeister |
| A11 | **Marktgüter** (neu) | `market/stalls/*.tres` | – | wechselnde Angebote (§2.7.4); bleibend: **Rosenstock 12**, **Messinglaterne 10** | die fehlende Spätspiel-Senke mit sichtbarem Gewinn |

#### 2.4.3 Erwartete Wirkung je Abschnitt (Rechnung P1, W1 misst nach)
| Abschnitt | Hebel | Δ gegenüber heute (Schätzung) |
|---|---|---|
| Tag 1–14 | E1/E2 (≈ −1/Tag), E8/E9 (−18 mit Bitten) | `diligent` Tag 14 58 → ≈ 45; HillBot Pflicht 129 → ≈ 85 |
| Tag 15–30 | E1/E2, E12/E13 (harvester −15), A1 (+20 Spielraum), A7 ab Pachtbrief (−8/Monat) | `reverent5` min 17 → ≈ 12; `harvester5` Ende 102 → ≈ 80 |
| Tag 30–53 | E1/E2, E5, E6, E14, A7, A8 ab `village_open` | `neighbor7` +40 → ≈ +25; `anatomist7` +51 → ≈ +30 |
| Tag 53–75 | E2 statt Kappe (+), E5, E11, A3, A7–A9, kein Markt-Einkauf der alten Bots | `kindly9` +64 → ≈ +45 (alte Bots kaufen nicht am Markt); `lazy9` +93 → ≈ +60 |
| Tag 75–91 | Markt (Einnahme + Senke), Abgaben | `kindly10` ≈ −13 (§2.9) |
*Hinweis:* Die alten Bots (Phase 3–9) gehen nie auf den Markt und zahlen keine Abgaben aktiv (Aufschub → Erlass, §2.5.7). Ihre Δ-Bänder werden deshalb **nach** der W1-Messung neu gesetzt (§10.3); die Zielkurve prüft `curve10`, der Markt und Abgaben spielt.

#### 2.4.4 Stellschrauben-Reihenfolge (wenn eine Messung außerhalb des Bands liegt)
1. Friedhofsgeld-Stufen (E2) und Bedarfsschwelle (60) · 2. Bitt-Münzen (E8/E9) · 3. Zehnt-Prozent und Pacht (A7/A8) · 4. Nachfrage am Markt (§2.7.5) · 5. Preise der Marktgüter (A11) · 6. Aussegnung/Ruf-Zuschlag (E5/E6) · 7. erst dann Stationen/Gebäude (A2, nur wenn ein Morgen in P5/P6 unter das Band fällt; zuerst Gruft 2 35 → 30). Jede Änderung mit Grund in `docs/reviews/phase10_wip/balance.md`; mehr als drei Schritte auf einem Hebel → Benutzerentscheidung.

### 2.5 Gemeindekasse (`data/config/treasury_config.tres` – `TreasuryConfig`, System `Treasury`)

#### 2.5.1 Grundsatz
**Entscheidung: Die Gemeinde zahlt, was sie sieht, und rechnet einmal im Monat ab.** Fenner ist Schultheiß, Kassenwart und Marktmeister in einer Person; vor `village_open` kennt man ihn nur als Absender, Osric bringt Geld und Zettel. *Begründung:* Das Pflegegeld war Geld ohne Anlass. Der Friedhof ist das, wofür die Gemeinde den Totengräber hält; also zahlt sie nach dem Friedhof. Die Abgaben geben dem Spätspiel einen festen Abfluss, ohne Verschleiß (nicht gewählt) einzuführen.

#### 2.5.2 Friedhofsschau und Friedhofsgeld (wöchentlich)
- **Schau:** jeden **Sonntag 18:00** (`schau_weekday 6`, `schau_minute 1080`), berechnet aus dem Zustand (B: sichtbar als Gang von Fenner und Lenz 14:00–15:00 über den Hügel, §12.4).
- **Qualitätsgeld** = Grundbetrag der **Friedhofsstufe** (`CemeteryRating`) + **Pflegezuschlag** − gestörte Gräber, höchstens `quality_cap 15`:
  | Stufe | Verwahrlost | Ordentlich | Gepflegt | Würdevoll | Ehrwürdig |
  |---|---|---|---|---|---|
  | Grundbetrag/Woche (`tier_pay`) | 0 | 4 | 7 | 10 | 12 |
  Pflegezuschlag nach dem Anteil **gepflegter** belegter Gräber (kein Unkraut/Laub der Pflegestellen am Grab, keine verwelkten Blumen, nicht aufgewühlt; `TreasuryRules.care_share`): ≥ 50 % **+1**, ≥ 75 % **+2**, ≥ 95 % **+3** (`care_steps`). Je aufgewühltem Grab (Phase 8, `disturbed`) **−1**.
- **Bedarfszulage** (`need_threshold 60`, `need_divisor 4`, `need_cap 15`): Liegt das Polster (Beutel + Truhen + Lohndose, `Reputation.holdings`) bei der Schau unter 60, zahlt die Gemeinde ⌈(60 − Polster) / 4⌉ dazu. *Begründung:* „Pflegegeld nach Bedarf“ (G8 E8-2) ohne Klippe: wer wenig hat, bekommt mehr; wer 59 hat, 1.
- **Notgroschen** (`hardship_floor 10`, `hardship_cap 8`): Liegt das Polster danach noch unter 10, füllt die Gemeinde auf 10 auf (höchstens 8). Fenner: „Die Gemeinde lässt ihren Totengräber nicht hungern. Wer sollte uns sonst begraben?“
- **Auszahlung:** Montag 07:40 durch Osric (`pay_weekday 0`, `pay_minute 460`; HUD und Torglocke wie eine Lieferung, Dialogzeile). Ist der Totengräber nicht am Tor (Zeitsprung, Schlaf, Dorf), legt Osric es in die **Hüttentruhe** (`pay_fallback_chest hut_chest`, Notiz „Osric hat das Friedhofsgeld in die Truhe gelegt.“) – nie in die Lohndose, damit Jakobs Lohn nicht verrechnet wird. Erste Woche anteilig (Tage seit Bucheröffnung / 7, aufgerundet).
- **Beispiele:** neues Spiel Tag 3 (Ordentlich, 30 % gepflegt, Polster 12): 4 + 0 + 12 = 16 × 3/7 → **7**. Tag 24 (Gepflegt, 80 %, Polster 70): 7 + 2 = **9**. Spätspiel (Ehrwürdig, 90 %, Polster 130): 12 + 2 = **14**. `lazy` mit vernachlässigten Gräbern (Würdevoll, 40 %): **10**.

#### 2.5.3 Kein Scheitern (Zusammenfassung der Schutzregeln)
| Lage | Regel | Folge |
|---|---|---|
| Polster < 60 bei der Schau | Bedarfszulage | bis +15 je Woche |
| Polster < 10 nach der Schau | Notgroschen | auf 10 aufgefüllt |
| Abgaben > Polster − 10 am 7. | Aufschub | ohne Zins, ohne Ruf-Verlust |
| Aufschub älter als ein Monat | Erlass | „unter Barmherzigkeit verbucht“, keine Folge außer einer Zeile |
| Lehrling ohne Lohn | Phase 8 (er bleibt nach 3 Tagen daheim) | unverändert |
Kein Laden verweigert den Handel, kein Kapitel hängt an einem Betrag, kein System nimmt Münzen, die nicht da sind.

#### 2.5.4 Monatsabrechnung
- **Wann:** am **Monatsersten 06:00** (`settle_minute 360`) für den Vormonat, ab dem ersten Monatsersten nach der Bucheröffnung. Fenner schreibt sie; ab `village_open` hängt sie an der Gemeindetafel und steckt an der Hüttentür (Zettel wie Ilses, `ph_notice_bill`), vorher bringt Osric sie. HUD: „Die Monatsabrechnung für den Julmond liegt in der Hütte.“
- **Durchsehen:** „[E] Monatsabrechnung durchsehen (10 Min)“ am Hüttenpult (Clip `write`, Kassenbuch `ph_prop_cash_book` aufgeschlagen) öffnet das Panel `&"settlement"` (§7.2). Man kann auch ohne Durchsehen zahlen.
- **Inhalt:** Einnahmen nach Quelle (belegt / ohne Beleg), Ausgaben nach Zweck, Friedhofsgeld je Woche mit Stufe, Spenden, dann **die Abgaben** (A7–A9) mit Summe, offener Aufschub aus dem Vormonat, „Zu zahlen bis zum 7. Hartung: 13 Münzen“.
- **Zahlen:** bei **Fenner** (Amtsstube, Dialog „[Abrechnung] Ich bring die Abgaben.“) oder **Osric** (am Karren, „[Abrechnung] Nimmst du die Abgaben für Fenner mit?“ – „Ich trag Tote. Geld trag ich auch. Das ist leichter, aber man wird öfter gefragt.“). Bis zum **7. des Monats, 23:59** (`due_days 6`). Pünktlich: Ruf **+1** (`dues_paid`), Fenner **+2**.
- **Aufschub:** Ist am 7. nicht gezahlt, schreibt Fenner es an (`deferred`): ohne Zins. Man kann jederzeit nachzahlen. Ist der Aufschub beim nächsten Monatsersten noch offen, wird er **erlassen** (`waive_after_months 1`): „Ich hab's unter ‚Barmherzigkeit‘ verbucht. Das Konto ist größer, als man denkt.“ Höchstens ein Monat Abgaben steht je offen; nie mehr.
- **Sofort aufschieben:** Im Panel „Aufschieben“ (z. B. weil Samstag Markt ist) – Fenner: „Aufgeschrieben ist nicht vergessen. Aber es ist auch nicht eilig.“
- **Ab `p10_open`** zählt die abgeschlossene Abrechnung fürs Kapitel (§1.5).

#### 2.5.5 Pacht
- **„Pacht für Bruch und Werkhof“** an die Gemeinde: **8 je Monat** (`rent 8`) ab dem **Pachtbrief** (`rent_flag bruch_license`). Der Steinbruchbrief aus Phase 5 heißt jetzt **Pachtbrief** und kostet bei Osric **0** („Fenner verpachtet den Bruch jetzt, statt ihn zu verkaufen. Er sagt, das rechnet sich. Für ihn.“). Erster Monat anteilig (⌈8 × Tage / Monatslänge⌉).
- Hütte, Friedhof, Kapelle, Gruft und Schuppen sind Dienstsachen und kosten keine Pacht (kein Gebäudeunterhalt, §13).
- Lorenz' vorausbezahlte Pacht: §1.6 (B).

#### 2.5.6 Gemeindeabgabe („der Zehnte“) und Schätzung
- **Belegt** sind Einnahmen, die durch ein Buch gehen: Bestattung, Aussegnung, Umbettgeld, Aufträge, Bitten, Botenlohn, Läden, Markt (`CashBookConfig.sources[…].receipt = true`). **Nicht belegt** und **nicht abgabepflichtig**: Friedhofsgeld, Bedarf, Notgroschen, Trinkgeld, Spenden, Geistergaben.
- **Zehnt:** 10 % der belegten Einnahmen des Monats, abgerundet, höchstens 25 (`tithe_percent 10`, `tithe_cap 25`), ab `village_open`.
- **„Ohne Beleg“:** alles, was ins Polster kommt, ohne gebucht zu sein (Wertsachen aus dem Saum, Ilses Münzen, Quasts Präparate, Vorlesungshonorar, Sammlung, Brenneisen) – das Kassenbuch rechnet es aus (Zuwachs des Polsters − gebuchte Einnahmen + gebuchte Ausgaben, §2.6). Ist es im Monat **> 20**, setzt Fenner eine **Schätzung** von 10 % davon fest, höchstens 15 (`estimate_*`): „Ihr Beutel ist schwerer als Ihr Buch, Totengräber. Ich frag nicht, woher. Ich schätze nur.“ Ruf −1 (`estimated`) beim ersten Mal je Monat.
- *Begründung:* Der Zehnt trifft den, der viel verdient (progressiv, gedeckelt), der Schätzwert den, der nachts verdient – das ist der gewünschte Münzausgleich für Verwerten (G5/G8), ohne Verwerten zu verbieten. Wer würdevoll arbeitet und wenig verdient, zahlt fast nur die Pacht.

#### 2.5.7 Rechenbeispiel Spätspiel (kindly, ein Monat mit Markt)
Belegt 180 → Zehnt 18 · Pacht 8 · ohne Beleg 0 → **26**; Friedhofsgeld im selben Monat 4 × 14 = 56. Die Gemeinde gibt also mehr, als sie nimmt, wenn der Friedhof ehrwürdig ist – aber nicht viel mehr. Verwertend (ohne Beleg 60, belegt 150): Zehnt 15 + Pacht 8 + Schätzung 6 = **29**, Friedhofsgeld wegen beraubter Gräber (Stufe Würdevoll, Pflege 60 %) 4 × 11 = 44.

#### 2.5.8 Spenden
- **Opferstock** „Für den Gottesacker“ am östlichen Torpfeiler (`ph_prop_offering_box`, §4.5): Jeder **zufriedene Besuch** (Phase 8 `visit_pleased`) wirft beim Gehen **1 Münze** hinein (Kappe 2 je Tag, `poor_box_cap_day`), sichtbar: die Figur bleibt 2 s am Stock stehen (Clip `lay_flowers` aus Phase 8), Klang `poor_box_coin`. Dorfbewohner auf Grabbesuch ebenso.
- **Leeren:** „[E] Opferstock leeren (2 Min)“ → Münzen ins Polster, im Buch **„Spenden“** (nicht abgabepflichtig). Bis zum Leeren liegen sie im Stock (gespeichert), höchstens 30 (`poor_box_max`); voller Stock: „Der Opferstock ist voll. Die Leute legen jetzt Knöpfe hinein.“
- **Selbst geben:** am Stock „[E] Etwas hineinlegen“ (1 Münze, Pietät +1 einmal je Woche, `poor_box_give`). Die Armenkasse bei Fenner (Phase 7) bleibt.
- **Stiftungen** (B): Haushalte mit Wohlwollen ≥ 8 (Phase 8) geben zur Monatsabrechnung 2–3 Münzen „für Kerzen und Blumen“ (`stipends_households`).

### 2.6 Kassenbuch (`data/config/cash_book_config.tres` – `CashBookConfig`, System `CashBook`, Merkbuch-Reiter „Kasse“)
- **Was es bucht:** jede Einnahme (`EventBus.payment_received`, `trader_trade`, `shop_trade`) mit **Quelle** und jede Ausgabe (`EventBus.coins_spent`) mit **Zweck**. Die Quelle ergibt sich aus dem Grundtext über eine Tabelle von Präfixen in den Daten (`CashBookConfig.sources`: `burial` „Bestattung von “, `service` Aussegnung, `reinter`, `parish` Friedhofsgeld, `need` Bedarf/Notgroschen, `order` „Auftrag: “, `request` Bitten, `errand` Botenlohn, `tip` „Trinkgeld“, `donation_in` Spenden, `gift` Geistergabe, `shop_sale` „Verkauf im Dorf“/„Verkauf an Hanne“, `market_sale`, `specimen`, `lecture`, `collection`, `night` (Ilse), `stranger`, `other`). Die Zwecke sind `GameState.COIN_REASONS` (+ `market`, `rent`, `tax`, `stall`).
- **Ohne Beleg:** Einmal je Spielstunde und beim Tageswechsel vergleicht das Buch das Polster mit seinen Buchungen; die Differenz bucht es als **„ohne Beleg“** (Quelle `untracked`, positiv oder negativ, z. B. Wertsachen). Quellen mit `receipt = false` (`specimen`, `lecture`, `collection`, `night`, `stranger`) zählen ebenfalls als „ohne Beleg“ für die Schätzung.
- **Aufbewahrung:** Tagesseiten der letzten **62 Tage** (`keep_days`), Monatsseiten unbegrenzt (je ≈ 0,3 kB). Kein Einzelposten-Protokoll (nur Summen je Quelle/Zweck und Tag), damit der Spielstand klein bleibt (§9).
- **Seiten** (Merkbuch „Kasse“, §7.1): **Heute** · **Woche** (Mo–So, mit Friedhofsschau) · **Monat** (laufend und frühere Abrechnungen) · **Abgaben** (fällig, aufgeschoben, erlassen) · **Markt** (letzter Markttag: verkauft/gekauft, nächster: Marktlage, sobald der Zettel hängt).
- **Ton:** Das Buch schreibt in der Hand des Totengräbers (Zahlen in Tinte, „ohne Beleg“ in Bleistift). Spalte „Soll“ / „Haben“. Am Monatsende die Zeile „Übertrag“.

### 2.7 Wochenmarkt (`data/config/market_config.tres` – `MarketConfig`, `data/market/stalls/<id>.tres` – `MarketStallData`, `data/market/wares/<item>.tres` – `MarketWareData`, System `Market`)

#### 2.7.1 Kalender: Wochentage (✦ `CalendarRules`, Lead)
- **Tag 1 = Freitag, 3. Gilbhart 1834** (historisch richtig). Wochentag = (Tag − 1 + 4) mod 7 mit 0 = Montag. Samstage: Tag 2, 9, … 79, 86; Sonntage: 3, 10, … 80, 87; Monatserste: Tag 30 (1. Nebelung, Sa), 60 (1. Julmond, Mo), 91 (1. Hartung 1835, Do), 122 (1. Hornung).
- Reine Funktionen über `StoneCalendar.date_of` (`StoneCalendar` bleibt unverändert, PHASE9 W0 Nr. 11). HUD zeigt künftig „Sa, 20. Julmond 1834“.
- **Keine** Sonntagsruhe als Mechanik, keine neuen Feste (§13); Läden haben ihre Zeiten wie bisher.

#### 2.7.2 Ablauf eines Markttags (Samstag, ab `village_open`)
| Uhrzeit | Was (sichtbar) |
|---|---|
| 06:20–07:00 | Agathe Wendel kommt mit ihrem Handkarren über die Holderbrücke (Weg nach Gehtempo, Abfahrt in Ellbach außerhalb des Bildes) |
| 07:00–07:50 | Die Stände stehen (Kindmeshes sichtbar nur am Markttag 06:30–13:30), Agathe, Martha Kehr und Hinrich Brandt legen aus (Clip `arrange_wares`) |
| 08:00 | Fenner läutet am Brunnen die Handglocke: „Markt ist offen!“ (Klang `hand_bell`, HUD im Dorf) |
| 08:00–12:30 | Markt: Dorfbewohner und Trauernde gehen zwischen den Ständen (Zeitpläne, je 30–60 Min), kaufen, reden |
| 12:30 | Schluss; eigener Stand: unverkaufte Ware zurück ins Inventar, was nicht passt, in die Hüttentruhe („Fenner hat dir die Kiste vor die Hütte stellen lassen.“) |
| 13:30 | Agathe fährt zurück über die Brücke |
- **Marktzettel:** ab **Donnerstag** 07:44 an der Gemeindetafel (`ph_notice_market`, Kindmesh wie `ph_notice_slip`): „Samstag Markt auf dem Anger. Gefragt: Kerzen. Reichlich: Holz. – Fenner, Marktmeister“. Zusätzlich Gerede (Theres, Rosine, Esch je eine Zeile zur Lage) und am Freitagabend HUD „Morgen ist Markt in Hollerbrück.“

#### 2.7.3 Marktlage (deterministisch, `MarketRules.group_state`)
- **Warengruppen** (`MarketConfig.groups`): `candles` (Grabkerze, Altarkerze, Bienenwachs) · `grave_goods` (Holzkreuz, Wachskranz, Grabvase, Strohblumen, Rosenstock, Messinglaterne) · `herbs` (Kräuter, Kräuterbündel, Holunderbeeren, Wundsalbe) · `textiles` (Leinen, Garn, Flachs, Totenhemd) · `wood_iron` (Holz, Holzkohle, Eisenbeschläge, Stahl) · `pantry` (Honigkuchen, Holunderwein, Branntwein, Saat, Setzlinge).
- **Zustände** je Gruppe und Markttag: **gefragt** (`scarce`: Preis × 1,3, Nachfrage × 1,5) · **normal** · **reichlich** (`glut`: Preis × 0,75, Nachfrage × 0,6).
- **Bestimmung:** Grundzustand aus `hash([Woche, Gruppe])` (Gewichte 25/50/25 %); dann Regeln in Stufen (`season_rules`, `event_rules`, je +1/−1 Stufe, geklemmt):
  - **Frost** (Julmond, Hartung, Hornung): `wood_iron` +1.
  - **Trauerwoche:** ≥ 3 Lieferungen/Todesfälle in den 7 Tagen davor: `candles` und `grave_goods` +1 („Es wird viel gestorben. Man kauft Licht.“).
  - **Übersättigt:** Hat der Spieler am letzten Markt ≥ 6 Stück einer Gruppe verkauft, diese Gruppe −1 („Der Markt hat noch deine Kreuze.“).
  - **Hanne war da** (Hannes Tag in den 6 Tagen davor): `pantry` −1.
- Die Lage steht ab dem Zettel fest (Donnerstag) und ändert sich durch Laden nicht. *Begründung:* Lesen und Vorausplanen ist der Reiz („Kerzen am Mittwoch ziehen, weil Samstag Kerzen gefragt sind“), kein Glücksspiel.

#### 2.7.4 Die Stände und ihre Angebote
| Stand (`MarketStallData.id`) | Wer | verkauft (Pool, je Markt `picks` Stück gezogen; Preis = Grundpreis × Lage, ganzzahlig, nie < 1) | kauft vom Spieler |
|---|---|---|---|
| `ms_agathe` | **Agathe Wendel**, Marktfahrerin aus Ellbach (neue Figur, §2.11) | **Stadtware**, 5 aus 12: Rosenstock 12 (2) · Messinglaterne 10 (1) · Blattgold 6 (2, ohne „Befreundet“) · Stahlstab 5 (2) · Eisenbarren 5 (2) · kleines Präparatglas 3 (3) · Branntwein 3 (3) · Tinte 2 (3) · Wachskranz 5 (2) · gebrauchtes Grabgitter 9 (1, nur `robber_known`) · Bienenwachs 1 (6) · feine Leinwand = Leinen 3 (4) | Wachskränze, Grabkerzen (Stadt: „In Ellbach zahlt man für Wachs.“) |
| `ms_kehr` | **Martha Kehr** (Hof Kehr, Figur `ph_chr_mourner_w_a`) | 4 aus 7: Bienenwachs 1 (8) · Honigkuchen 2 (4) · Samen 1 (6) · Setzlinge 2 (4) · Wacholder 2 (4) · Holunderwein 2 (2) · Kerzenstummel = Grabkerze 1 (6) | Kräuter, Kräuterbündel |
| `ms_brandt` | **Hinrich Brandt** (Hof Brandt, Figur `ph_chr_mourner_m_a`) | 4 aus 6: Holz 1 (10) · Holzkohle 1 (6) · Flachs 1 (6) · Garn 1 (6) · Stein 1 (6) · Eisenbeschlag 3 (3) | Holzkreuze („Für den Feldrain. Und für später.“) |
- Kaufen über das bestehende Laden-Panel (`&"shop"`) mit Marktzusatz: neben dem Preis der Hinweis „sonst 3“ bzw. „gefragt“/„reichlich“ (kein Pfeil-Ticker). Vorrat je Markt, atomar (Muster `VillageShops`). Die Läden im Dorf bleiben werktags unverändert (B: Theres richtet ihre Preise um ±1 nach der Lage, §12.4).
- **Neue bleibende Güter (A):** **Rosenstock** (`rose_bush`): aufs Grab gesetzt wirkt er **dauerhaft wie Grabblumen** (Phase 8, kein Gießen, kein Welken), zählt als gepflegt (§2.5.2) und für Besucher-Wünsche „Blumen“; je Grab einer. **Messinglaterne** (`brass_lantern`): Zier wie die Grablaterne, Zier-Wert +1 höher (`data/decor/brass_lantern.tres`), leuchtet nachts wie `decor_lantern`. *Begründung:* Phase 5/6 zeigten: Bleibende Gewinne machen Ausgaben leicht. „Rosen für alle Gräber“ ist eine lange, schöne, freiwillige Senke (60 Gräber × 12).

#### 2.7.5 Der eigene Stand
- **Platz:** `market_stall_own` am Rand des Angers (Linde im Rücken, §4.5). Freigabe Fenner (`market_stall_granted`): „Ein Stand am Samstag? Ein Totengräber, der Kreuze verkauft. Na gut. Die Leute kaufen ja ohnehin bei Ihnen. Nur später.“
- **Aufbauen** (10 Min, Standgeld 1, Clip `stall_arrange`): Panel `&"market_stall"` (§7.3), bis zu **6 Warenstapel** (`stall_slots`) aus dem Inventar, je Ware ein **Preisschild**:
  | Schild | Preis | Nachfrage |
  |---|---|---|
  | günstig (`cheap`) | × 0,8 | × 1,4 |
  | recht (`fair`) | × 1,0 | × 1,0 |
  | teuer (`dear`) | × 1,25 | × 0,6 |
  Die Waren liegen sichtbar auf dem Stand (Kindmesh-Plätze `goods_1…6` mit den Item-Modellen).
- **Verkaufen:** „[E] Am Stand verkaufen“ → TimedAction in **Takten zu 30 Min** bis 12:30 (Clip `stall_offer-loop`, nach jedem Takt abbrechbar). Je Takt kommt eine Kundschaft (Figur aus dem Marktgang geht an den Stand, Clip `buy_hand_over`), kauft 1–3 Stück einer Ware nach der verbleibenden Nachfrage; Münzen sofort, Zeile im HUD („Martha Kehr kauft einen Wachskranz. ‚Für Paul. Er hat Wachs nie gemocht, aber er sagt ja nichts mehr dagegen.‘“). Wer den Stand verlässt, verkauft nichts (kein Diebstahl, kein Verkauf ohne Totengräber).
- **Nachfrage** je Ware und Markt = ⌊`demand` × Lage × Schild × Ruf × Pietät⌉: Ruf „Verrufen“ × 0,7, „Gerühmt“ × 1,1; Pietät „Hartherzig“ × 0,7 bei `grave_goods` („Kerzen vom Totengräber, der Zähne zieht?“), „Andächtig“ × 1,1. Erlös je Kauf = round(Grundwert × Stück × Lage × Schild), mindestens 1.
- **Waren des Totengräbers (A)** (`data/market/wares/*`):
  | Ware | Grundwert | Nachfrage/Markt | Herkunft · Material | Anmerkung |
  |---|---|---|---|---|
  | Holzkreuz `wooden_cross` | 4 | 2 | Werkbank, 3 Holz (selbst geschlagen) | bester Erlös aus eigenem Holz |
  | Kräuter `herbs` | 1 | 6 | Sammelstellen | Theres zahlt werktags auch 1 |
  | Kräuterbündel `herb_bundle` | 3 | 3 | Werkbank, 3 Kräuter | |
  | Grabkerze `grave_candle` | 1 | 8 | **neues Rezept:** 1 Bienenwachs + 1 Garn → 4 (20 Min) | Gewinn nur mit eigenem Garn oder bei „gefragt“ |
  | Wachskranz `wax_wreath` | 6 | 2 | **neues Rezept:** 2 Bienenwachs + 1 Wacholder + 1 Garn → 1 (25 Min) | Hanne verkauft ihn für 5 |
  B: Grabvase 4 (1), Strohblumen 2 (3), Holunderwein 3 (2), Garn 1 (4).
- **Erwartung:** ein vorbereiteter Stand bringt **15–30 Münzen** je Markt bei 2–4 Stunden (Theorie-Höchstwert bei voller Nachfrage, alles „gefragt“: ≈ 45). Material kostet bei gekauftem Wachs 30–50 % des Erlöses; aus eigenem Holz, Kräutern und Garn fast nichts. *Begründung:* Der Stand ist das Spätspiel-Einkommen des Handwerkers – genug, um Rosen und Abgaben zu tragen, zu wenig, um die Bestattung zu ersetzen.

### 2.8 Neue Items und Rezepte (Besitzer P4)
| id | Name | Kategorie | Stapel | Herkunft | Zweck |
|---|---|---|---|---|---|
| `rose_bush` | Rosenstock | MATERIAL | 4 | Agathe (12) | aufs Grab: dauerhafte Grabblumen (§2.7.4) |
| `brass_lantern` | Messinglaterne | DECOR | 4 | Agathe (10) | Zier (Baumodus), Wert +1 über `decor_lantern` |
- Neue Rezepte (`data/recipes/`): `grave_candle_poured` (Werkbank, 20 Min, `beeswax` 1 + `yarn` 1 → `grave_candle` 4), `wax_wreath_bound` (Werkbank, 25 Min, `beeswax` 2 + `juniper` 1 + `yarn` 1 → `wax_wreath` 1). Beide ab `village_open` (`requires_flag`; Bienenwachs gibt es bei Theres erst im Dorf).
- Keine neuen Ressourcen, keine neuen Sammelstellen.

### 2.9 Münzrechnung (Bogen A, `kindly10`, 17 Tage)
**Ausgangslage:** `kindly9` endet mit **132** (G9). Der Hügel ist bis auf eine Stelle voll, also kaum noch Bestattungen. Phase 10 bringt **neue Einnahmen** (Friedhofsgeld, Markt, Spenden) und **neue Ausgaben** (Abgaben, Marktgüter, Material). Ziel: Der Überschuss aus Phase 9 hört auf zu wachsen und fließt sichtbar in den Friedhof (Rosen, Laterne) und in die Gemeinde.

| Einnahmen (17 Tage) | Rechnung | Münzen |
|---|---|---|
| Start (B1 früh) | W0-Messung | ≈ 132 |
| Friedhofsgeld | 12 (anteilig) + 14 | 26 |
| Bestattung + Aussegnung + Geistergabe (letzte Stelle in Reihe 4) | 11 + 4 + 2 | 17 |
| Kleine und große Bitten | ≈ 7 × 1,2 + 2 + 4 | 14 |
| Aufträge | | 8 |
| Trinkgeld · Opferstock | Kappe 3 · 1 je zufriedenem Besuch | 14 · 5 |
| Läden (Kräuter werktags) | | 6 |
| **Eigener Stand** | Markt 1 ≈ 22 · Markt 2 ≈ 18 | **40** |
| **Summe Einnahmen** | | **130** |

| Ausgaben | Münzen |
|---|---|
| Lehrling 14 Arbeitstage × 3 | 42 |
| Material für den Stand (12 Bienenwachs, 2 Wacholder) | 16 |
| Standgeld 2 × 1 | 2 |
| **Marktgüter:** 2 Rosenstöcke · 1 Messinglaterne | **24 · 10** |
| Bestattungsware (Leinen, Altarkerze) | 5 |
| Wünsche (Kerzen, Setzlinge) · Almosen | 8 · 5 |
| Geschenke, Runden (Silvester) | 16 |
| Post, Kleinkram | 2 |
| **Abgaben Julmond** (anteilig ab B1): Pacht ⌈8 × 16/31⌉ = 5 · Zehnt 10 % von 83 belegten = 8 | **13** |
| **Summe Ausgaben** | **143 (110 %)** |

| | B1 | B2 | B3 | B4 | B5 | B6 | B7 | B8 | B9 | B10 | B11 | B12 | B13 | B14 | B15 | B16 | B17 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Morgens | 132 | 124 | 124 | 135 | 134 | 130 | 131 | 135 | 135 | 132 | 132 | 130 | 132 | 131 | 143 | 140 | 134 |
| Ausgaben | 11 | 7 | 8 | 4 | 26 | 3 | 8 | 5 | 5 | 3 | 7 | 16 | 3 | 6 | 7 | 8 | 16 |
| Einnahmen | 3 | 7 | 19 | 3 | 22 | 4 | 12 | 5 | 2 | 3 | 5 | 18 | 2 | 18 | 4 | 2 | 1 |
| Abends | 124 | 124 | 135 | 134 | 130 | 131 | 135 | 135 | 132 | 132 | 130 | 132 | 131 | 143 | 140 | 134 | **119** |
- Ende ≈ **119** (Δ **−13**), morgens nie unter 124. Ohne Marktgüter ≈ +21, ohne Markt (weder Stand noch Kauf) ≈ +11. Das Friedhofsgeld (26) und der Stand (40) tragen zusammen den Lehrling (42) und die Abgaben (13).
- **Prüfregeln (§10):** `kindly10` Δ **−30 … +10**, Ausgabequote ≥ 85 %; `lazy10` Δ ≤ `kindly10` Δ + 35 und ≤ +35; `trader10` Δ ≤ `kindly10` Δ + 15 % seiner Einnahmen; `poor10` morgens nie < 5, Kapitel erreicht; alle morgens ≥ 5; Münzbuch = Kassenbuch (Summen gleich).

### 2.10 Ruf, Pietät, Beziehung, Statistik, Münz-Zwecke
**Ruf** (`ReputationConfig.event_points` +): `dues_paid +1` (pünktlich, einmal je Monat), `estimated −1` (Schätzung, einmal je Monat), `market_stall +0` (keiner – der Markt ist Handwerk, kein Lob).
**Pietät** (`PietyConfig.events` +): `poor_box_give +1` (einmal je Woche), `rose_planted +1` (je Rosenstock auf einem fremden Grab ohne Wunsch, höchstens 1 je Tag).
**Beziehung** (`RelationshipConfig.gains` +): `dues_paid_fenner 2`, `market_buy 1` (erster Kauf des Tages an einem Hof-Stand: Haushalt Wohlwollen +1, Phase 8), `market_sale_kin 1` (ein Haushalt kauft am Stand: Wohlwollen +1, höchstens 1 je Markt).
**Statistik** (`GameState.DEFAULT_STATS` +): `parish_weeks`, `parish_paid`, `need_paid`, `hardship_paid`, `settlements`, `dues_paid`, `dues_deferred`, `dues_waived`, `rent_paid`, `tithe_paid`, `estimate_paid`, `donations_received`, `poor_box_emptied`, `market_days`, `market_stall_days`, `market_items_sold`, `market_coins`, `market_items_bought`, `roses_planted`, `coins_spent_market`, `coins_spent_rent`, `coins_spent_tax`, `coins_spent_stall` (23).
**Münz-Zwecke** (`GameState.COIN_REASONS` +): `&"market"` (Kauf am Markt), `&"rent"` (Pacht), `&"tax"` (Zehnt und Schätzung), `&"stall"` (Standgeld). Einnahmen-Gründe: „Friedhofsgeld“, „Bedarfszulage der Gemeinde“, „Notgroschen der Gemeinde“, „Spenden aus dem Opferstock“, „Verkauf am Marktstand“.

### 2.11 Figuren-Rollen
- **Fenner** (`mayor`): Kassenbuch-Eröffnung, Marktmeister (Platz, Glocke 08:00, Marktzettel), Abrechnung, Zahlung, Aufschub, Erlass, Schätzung. Beide Menüs nach Ruf mit den Phase-10-Zeilen.
- **Osric** (`carter`): `p10_intro`; bringt montags das Friedhofsgeld, vor `village_open` die Abrechnung; nimmt Abgaben mit (warm und `menu_cold`). Pachtbrief statt Steinbruchbrief.
- **Agathe Wendel** (`marketwoman`, neu): 46, Marktfahrerin aus Ellbach, Witwe eines Wachsziehers; breites Gesicht, rote Hände, Strickjacke über dem Wollkleid, Kopftuch, Lederschürze mit Geldkatze, Handkarren mit Plane. Schnell, rechnet laut, nennt Preise wie Neuigkeiten. Kommt nur samstags. Über Kerzen: „Sie verkaufen auch Kerzen? Meine sind für Stuben. Ihre für die anderen. Wir kommen uns nicht in die Quere.“
- **Martha Kehr**, **Hinrich Brandt** (Phase 8, Haushalte): stehen samstags an ihren Hof-Ständen; als Kundschaft kaufen sie für die Gräber ihrer Toten (B: am Sonntag liegt der Kranz sichtbar auf dem Grab).
- **Theres, Rosine, Esch, Liesel, Lenz, Gesa Ott**: Marktgang (je 30–60 Min, Zeitpläne P5), Kundschaft, Gerede zur Marktlage. **Quast** geht nicht auf den Markt („Was ich kaufe, verkauft man nicht auf dem Anger.“). **Jakob** bittet samstags um einen freien Vormittag (Liste wie sonst ab 13:00, B).
- **Ilse, Hanne, Brenneisen:** unverändert; Hanne kauft am Stand nicht (sie ist Konkurrenz und sagt es: „Herzchen – nein, Sie nicht. Sie sind zu ernst für Rabatt.“, eine Zeile, B).

### 2.12 Dialog-Leittexte (P5 schreibt aus, darf glätten)
**Fenner**
- Eröffnung: „Totengräber. Die Gemeinde zahlt Ihnen künftig nach dem, was sie sieht. Jeden Sonntag schau ich, am Ersten rechnen wir ab. Pacht für den Bruch, der Zehnte für die Gemeinde. Wer nicht zahlen kann, bekommt Aufschub. Wer nicht zahlen will, bekommt meinen Blick.“
- Pünktlich gezahlt: „Auf den Tag. Das hat zuletzt der Lehrer gemacht, und der ist nach Ellbach gezogen.“
- Aufschub: „Dann schreib ich's an. Ohne Zins. Zinsen sind was für Leute, die nicht sterben.“
- Erlass: „Ich hab's unter ‚Barmherzigkeit‘ verbucht. Das Konto ist größer, als man denkt.“
- Schätzung: „Ihr Beutel ist schwerer als Ihr Buch, Totengräber. Ich frag nicht, woher. Ich schätze nur.“
- Glocke: „Markt ist offen! Und wer anschreiben will, geht zu Rosine.“
**Osric:** Friedhofsgeld: „Von der Gemeinde. Fenner hat's gezählt. Ich hab's nicht. Wenn's nicht stimmt, war's der Weg.“ · Pachtbrief: „Fenner verpachtet den Bruch jetzt, statt ihn zu verkaufen. Er sagt, das rechnet sich. Für ihn.“
**Agathe Wendel:** erster Markt: „Wendel, aus Ellbach. Wachs, Messing, Rosen und was die Stadt so wegwirft. Sie sind der vom Hügel? Dann brauchen Sie Kerzen. Alle vom Hügel brauchen Kerzen.“ · Rosenstock: „Eine Rose fragt nicht, wer drunter liegt. Gießen müssen Sie sie auch nicht, das macht der Himmel, und der schickt keine Rechnung.“ · Abschied: „Nächsten Samstag. Wenn ich nicht komme, hat der Karren gewonnen.“
**Kundschaft (Auswahl, `MarketWareData.lines`):** Holzkreuz – Hinrich Brandt: „Für den Feldrain. Und für später. Man soll vorsorgen.“ · Grabkerze – Gesa Ott: „Drei. Eine für Vater. Zwei, damit er nicht allein brennt.“ · Kräuter – Rosine: „Für den Krug. Gegen das, was die Leute nach dem dritten Bier haben.“
**Opferstock:** Inschrift „Für den Gottesacker“ · Leeren: „Drei Münzen und ein Knopf. Der Knopf ist auch eine Spende.“
**Kapitel-Schlusszeilen** (Standard): „Soll und Haben stimmen. Das Buch weiß nicht, was ein Grab wert ist. Du schon.“ · (mit Aufschub/Erlass): „Fenner hat Barmherzigkeit gebucht. Es ist das einzige Konto, das nie ausgeglichen ist.“ · (mit Schätzung): „Das Buch hat eine Bleistiftspalte. Fenner liest sie mit.“

---

## 3. Architektur

### 3.1 Neue Knoten
**Systemknoten** (unter `WorldRoot/Systems`, vom Welt-Builder angelegt; keine neuen Autoloads):
| Knoten | Klasse | Gruppen | save_id / save_order |
|---|---|---|---|
| `Treasury` | `Treasury` | `treasury`, `saveable` | `treasury` / **85** |
| `CashBook` | `CashBook` | `cash_book`, `saveable` | `cash_book` / **86** |
| `Market` | `Market` | `market`, `saveable` | `market` / **87** |
**Entitäten** – Friedhof: `OfferingBox` `poor_box_gate` (östlicher Torpfeiler), Kassenbuch-Prompt am `Desk` (Hütte, Auswahl). Dorf: `MarketStall` × 4 (`ms_agathe`, `ms_kehr`, `ms_brandt`, `market_stall_own`; Kindmeshes nur am Markttag), `npc_marketwoman` (Agathe, Region village), `npc_kin_kehr_v`, `npc_kin_brandt_v` (Hof-Stände, nur samstags), Marktzettel an `VillageBoard`, Handglocke am Brunnen (Wegpunkt `v_market_bell`, Fenner), Wegpunkte `v_market_*`.

### 3.2 Module & Besitz (Phase 10)
| Modul | Besitzt (Pfade) |
|---|---|
| **Lead** (W0 + laufend) | `project.godot`, `src/core/*` (EventBus, Database), alle **Datenklassen ✦**, alle **Stubs** (bis zur Übergabe), **`src/systems/time/calendar_rules.gd`** (✦, vollständig in W0), `tests/run_tests.gd`, `tests/framework/*`, `tests/fixtures/*` (inkl. **`saves_v8/*`**, `phase10/*`), `tests/integration/test_saves_v8_load.gd`, `tests/unit/test_phase10_scaffold.gd`, `docs/*`, `CLAUDE.md` |
| **P1 Tarif & Zielkurve** (Agent 14 + 02) | **nur die Münzwerte** in: `data/config/{economy_config,reputation_config,chapel_config,visitor_config,utilization_config,trader_config,anatomy_config}.tres`, `data/corpses/corpse_tables.tres` (`valuables_coins_*`), `data/hill_requests/**` (`reward_coins`), `data/orders/*` (`reward_coins`), `data/shops/*` (`price`), `data/stations/*`, `data/buildings/*` (nur Stellschraube 7); `data/economy/wishlist.tres` (neu), `tools/economy/tariff_report.py` (neu), `tests/unit/{test_tariff_sheet,test_wishlist}.gd`, `tests/integration/{economy_curve_bot,test_economy_curve}.gd`, **Neu-Bänder** der Münz-Assertions in `tests/integration/test_phase{3..9}_playthrough.gd` und `test_hill_requests_bot.gd` (nur Zahlen, Lead-genehmigt, §10.3), `docs/reviews/phase10_wip/balance.md` |
| **P2 Gemeindekasse** | `src/systems/treasury/{treasury,treasury_rules,offering_box}.gd` (neu), `src/entities/offering_box/*` (neu), `src/systems/reputation/reputation.gd` (nur: Pflegegeld aus, `holdings` öffentlich lassen), `src/systems/visitors/visitors.gd` (nur der Einwurf in den Opferstock, Aufruf `Treasury.drop_in_poor_box`), `data/config/treasury_config.tres`, `tests/unit/{test_treasury,test_treasury_rules,test_offering_box}.gd`, `tests/integration/test_treasury_month.gd` |
| **P3 Kassenbuch** | `src/systems/treasury/{cash_book,cash_book_rules}.gd` (neu), `data/config/cash_book_config.tres`, `tests/unit/{test_cash_book,test_cash_book_rules}.gd`, `tests/integration/test_cash_book_ledger.gd` (Kassenbuch = Münzbuch der Bots) |
| **P4 Wochenmarkt & Waren** | `src/systems/market/{market,market_rules}.gd` (neu), `src/entities/market_stall/*` (neu), `src/systems/village/village_shops.gd` (nur Marktzusatz im Panel-Kontext: Lage, „sonst“-Preis), `src/systems/grave_care/grave_care.gd` (nur Pflegeart `rose`), `data/market/**`, `data/config/market_config.tres`, `data/items/{rose_bush,brass_lantern}.tres`, `data/recipes/{grave_candle_poured,wax_wreath_bound}.tres`, `data/decor/brass_lantern.tres`, `tests/unit/{test_market,test_market_rules,test_market_stall,test_items_phase10}.gd`, `tests/integration/test_market_day.gd` |
| **P5 Dialog, Merkbuch, Zeitpläne & Speichern** (Agent 13 + 08) | `data/dialogue/*` (Fenner, Osric `p10_intro`/Pachtbrief/Friedhofsgeld/Abgaben in **beiden** Menüs, Agathe `marketwoman` neu, Hof-Stände, Gerede), `data/npc/*_schedule.tres` + `tools/dialogue/build_phase10_schedules.py` (Samstagswege, Agathe, Hof-Stände, Glocke; Gehtempo), `src/systems/dialogue/{dialogue_conditions,dialogue_actions}.gd`, `src/systems/journal/journal_manager.gd` (Hinweis `c_k_rent_paid`, B), `data/journal/clues/c_k_*`, `src/systems/save/{save_migration,save_file_io,save_manager}.gd`, `src/systems/game_state/game_state.gd`, `data/config/npc_life_config.tres` (Gerede zur Marktlage), `tests/unit/{test_dialogue,test_save,test_save_migration,test_game_state,test_schedule}.gd`, `tests/integration/test_phase9_save_upgrade.gd` (neu) |
| **P6 Assets** | `tools/blender/{asset_marketwoman,asset_props_phase10}.py` (neu), `tools/blender/{asset_character,asset_mourners,asset_items}.py` (nur neue Clips bzw. Icons), `tools/blender/build_all.py`, `assets/models/**` (nur Phase-10-Dateien und re-exportierte Figuren mit Zusatz-Clips), `art_source/blender/**` (Phase 10), `tests/unit/test_assets_phase10.gd`, `docs/reviews/phase10_assets/*` |
| **W-Welt** (W2) | `data/world/village_layout.json` (Marktplätze, Agathes Weg, Glocke, Gang-Wegpunkte), `data/world/graveyard_layout.json` (Opferstock), `data/world/hut_layout*` bzw. Innenraum-Daten (Kassenbuch auf dem Pult), `src/world/village/*` (`village_build_phase10.gd`, `village_shots.gd --phase10`), `src/world/graveyard/*` (`graveyard_build_phase10.gd`, `graveyard_shots_phase10.gd`), `tests/integration/{test_village_world,test_graveyard_world,test_phase10_loop}.gd`, `docs/reviews/phase10_round1/*` |
| **W-UI** (W2) | `src/ui/**` (neu `panels/{settlement_panel,market_stall_panel}.gd`, `panels/journal_pages_phase10.gd` (Kasse), Marktzusatz im Laden-Panel, HUD-Datum mit Wochentag, Zielzeilen, Tageszusammenfassung, Abschluss-Panel, Karte §7.6), `src/debug/*` (neu `debug_commands_phase10.gd`), `tests/unit/{test_ui_phase10,test_objective,test_map_phase10}.gd`, `tests/integration/test_ui_flow.gd` |
| **W-Ton** (W2, Agent 17) | `tools/audio/build_audio.py` (nur neue Cues), `assets/audio/**` (nur neue `ph_*`), `data/audio/*`, `src/systems/audio/{audio_world,audio_events}.gd` (nur neue Emitter), `tests/unit/test_audio_phase10.gd` |
| **W3 QA** | `tests/integration/{phase10_bot,test_phase10_playthrough,test_phase10_qa,test_save_fuzzer}.gd`, `docs/reviews/phase10_wip/*` |
| **Eingefroren** | `src/world/art_prototype/*`, Maler-Shader, `data/atmosphere/*`, `lib_faces.py` (nur benutzen), Rig (Knochenzahl), `StoneCalendar`, alle Gebäude und Innenräume, alle Abschnitte und Gräber, Dorf-Plan außer den Markern §4.5, Phase-3–9-Systeme außer den genannten Einzelfunktionen, **alle Mengen-, Zeit- und Beziehungswerte** (Phase 10 stimmt Münzen ab, nicht Minuten) |

✦ **Datenklassen (W0, Lead):** `TreasuryConfig`, `CashBookConfig`, `MarketConfig`, `MarketStallData`, `MarketOfferData`, `MarketWareData`, `WishlistData`, `WishlistEntryData`. Erweiterungen: `ReputationConfig` (Pflegegeld-Tabelle bleibt, Daten 0), `VisitorConfig` (+ `poor_box_coin 1`, `poor_box_cap_day 2`), `RelationshipConfig.gains` (+ 3), `ReputationConfig.event_points` (+ 2), `PietyConfig.events` (+ 2), `NpcLifeConfig.reactions` (+ `market_lage`, 1 Tag), `DecorData` (keine neuen Felder; Messinglaterne ist ein Datensatz).
Bei nur fünf Agents: **P2 + P3** (Kasse und Buch teilen Daten und Signale), **P1**, **P4**, **P5**, **P6**.

### 3.2.1 Klassen → Dateien
| Klasse | Datei | Art |
|---|---|---|
| `CalendarRules` | `src/systems/time/calendar_rules.gd` | ✦ vollständig (Lead W0) |
| `TreasuryConfig` | `src/systems/treasury/treasury_config.gd` | ✦ |
| `Treasury`, `TreasuryRules`, `OfferingBox` | `src/systems/treasury/{treasury,treasury_rules}.gd`, `src/entities/offering_box/offering_box.gd` (+ `.tscn`) | Stub (P2) |
| `CashBookConfig` | `src/systems/treasury/cash_book_config.gd` | ✦ |
| `CashBook`, `CashBookRules` | `src/systems/treasury/{cash_book,cash_book_rules}.gd` | Stub (P3) |
| `MarketConfig`, `MarketStallData`, `MarketOfferData`, `MarketWareData` | `src/systems/market/{market_config,market_stall_data,market_offer_data,market_ware_data}.gd` | ✦ |
| `Market`, `MarketRules`, `MarketStall` | `src/systems/market/{market,market_rules}.gd`, `src/entities/market_stall/market_stall.gd` (+ `.tscn`) | Stub (P4) |
| `WishlistData`, `WishlistEntryData`, `WishlistProbe` | `src/systems/economy/{wishlist_data,wishlist_entry_data,wishlist_probe}.gd` | ✦ / Stub (P1) |
| `SettlementPanel`, `MarketStallPanel`, `JournalPagesPhase10` | `src/ui/panels/*.gd` | W-UI |

### 3.3 EventBus – neue Signale (Ergänzung `src/core/event_bus.gd`)
```gdscript
# Gemeindekasse (Treasury): Friedhofsschau ausgewertet / Friedhofsgeld ausgezahlt
signal parish_schau(week: int, tier: StringName, care: float, coins: int)
signal parish_paid(week: int, coins: int, parts: Dictionary)          # {quality, need, hardship}
# Monatsabrechnung; state: &"due" | &"paid" | &"deferred" | &"waived"
signal settlement_changed(month_key: String, state: StringName, amount: int)
# Opferstock: Münzen darin nach der Änderung
signal poor_box_changed(coins: int)
# Kassenbuch: eine Buchung (amount > 0 Einnahme, < 0 Ausgabe)
signal cash_booked(day: int, source: StringName, amount: int)
# Wochenmarkt; kind: &"notice" | &"opened" | &"closed" | &"stall_set" | &"sold" | &"bought" | &"stall_cleared"
signal market_changed(day: int, kind: StringName, detail: Dictionary)
```
Regel wie Phase 3–9: **Listener ändern keinen fremden Spielzustand.** `CashBook` hört auf `payment_received`, `coins_spent`, `trader_trade`, `shop_trade`, `day_started` und bucht nur in seinem eigenen Zustand. Wer fremden Zustand ändert, ruft direkt auf: `Treasury.apply_minute` → `Inventory.add` (Friedhofsgeld), `GameState.note_coins_spent(n, &"rent" | &"tax")`, `Reputation.event`, `Relationships.add`; Dialog → `Treasury.pay_dues/defer_dues`, `Market.grant_stall`; `Visitors` (zufriedener Besuch) → `Treasury.drop_in_poor_box(1, who)`; `OfferingBox` → `Treasury.empty_poor_box/give`; `MarketStall` → `Market.set_up/start_selling/take_down`; Laden-Panel → `Market.buy`; `GraveCare` (Rosenstock) wie die Grabblumen. Einnahmen aus Phase 10 laufen über `EventBus.payment_received(n, reason)`, Ausgaben über `GameState.note_coins_spent(n, reason)` (Münzbuch-Regel seit QA5-01).

### 3.4 Logik-Klassen (Signaturen = Vertrag)

**Kalender (Lead, W0 vollständig)**
```gdscript
class_name CalendarRules extends RefCounted
const WEEKDAY_NAMES: PackedStringArray = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]
const DAY1_WEEKDAY := 4                               # Tag 1 = Freitag, 3. Gilbhart 1834
static func weekday(day: int) -> int                  # 0 = Montag … 6 = Sonntag
static func weekday_name(day: int, short: bool = false) -> String   # "Samstag" | "Sa"
static func week_of(day: int) -> int                  # Woche Mo–So; Tag 1–3 = Woche 0
static func month_key(day: int, cfg: StoneConfig = null) -> String      # "1834-12"
static func month_title(key: String, cfg: StoneConfig = null) -> String # "Julmond 1834"
static func is_first_of_month(day: int, cfg: StoneConfig = null) -> bool
static func first_day_of_month(key: String, cfg: StoneConfig = null) -> int
static func days_in_month(key: String, cfg: StoneConfig = null) -> int
static func next_weekday(day: int, weekday: int) -> int   # der nächste Tag ≥ day mit diesem Wochentag
```

**Gemeindekasse (P2)**
```gdscript
class_name TreasuryConfig extends Resource            # ✦ data/config/treasury_config.tres
@export var schau_weekday: int = 6; @export var schau_minute: int = 1080
@export var pay_weekday: int = 0; @export var pay_minute: int = 460; @export var pay_fallback_chest: StringName = &"hut_chest"
@export var tier_pay: Dictionary[StringName, int] = {&"neglected": 0, &"orderly": 4, &"tended": 7, &"dignified": 10, &"venerable": 12}
@export var care_steps: PackedFloat32Array = [0.5, 0.75, 0.95]; @export var disturbed_malus: int = 1; @export var quality_cap: int = 15
@export var need_threshold: int = 60; @export var need_divisor: int = 4; @export var need_cap: int = 15
@export var hardship_floor: int = 10; @export var hardship_cap: int = 8
@export var settle_minute: int = 360; @export var due_days: int = 6; @export var waive_after_months: int = 1
@export var rent: int = 8; @export var rent_flag: StringName = &"bruch_license"
@export var tithe_percent: int = 10; @export var tithe_cap: int = 25; @export var levy_flag: StringName = &"village_open"
@export var estimate_percent: int = 10; @export var estimate_min_untracked: int = 20; @export var estimate_cap: int = 15
@export var poor_box_max: int = 30; @export var poor_box_give: int = 1
@export var open_flag: StringName = &"p10_open"; @export var open_day_flag: StringName = &"p10_open_day"
@export var unlock_flag: StringName = &"who_knows_when_complete"
@export var chapter_id: StringName = &"debit_credit"; @export var goal_flag: StringName = &"debit_credit_complete"
@export var goal_market_days: int = 2; @export var goal_min_tier: StringName = &"dignified"
@export var prepaid_rent_months: int = 2              # §1.6 (B); 0 = aus
class_name TreasuryRules extends RefCounted
static func care_share(graves: Array, tree: SceneTree) -> float                 # Anteil gepflegter belegter Gräber
static func parish_pay(tier: StringName, care: float, disturbed: int, holdings: int, cfg: TreasuryConfig) -> Dictionary   # {quality, need, hardship, total}
static func prorate(amount: int, days: int, of_days: int) -> int                # aufgerundet
static func rent_due(month_key: String, book_start: int, flags: Dictionary, cfg: TreasuryConfig) -> int
static func tithe(booked_income: int, cfg: TreasuryConfig) -> int
static func estimate(untracked: int, cfg: TreasuryConfig) -> int
static func dues_block_reason(amount: int, holdings: int) -> String
class_name Treasury extends Node                      # Gruppe treasury, saveable treasury / 85
func is_open() -> bool; func open_day() -> int
func apply_morning(day: int) -> void                  # p10_open (idempotent), Monatserster 06:00 Abrechnung, Aufschub am 8., Erlass
func apply_minute(day: int, minute: int) -> void      # So 18:00 Schau, Mo 07:40 Auszahlung (Osric oder Truhe)
func post_load() -> void                              # v8 mit who_knows_when_complete → p10_open sofort
func last_schau() -> Dictionary                       # {week, day, tier, care, disturbed, quality, need, hardship, paid}
func pending_pay() -> Dictionary                      # Schau ausgewertet, noch nicht ausgezahlt
func settlement(month_key: String) -> Dictionary      # {month, day, income, spent, parish, donations, rent, tithe, estimate, deferred_in, total, state, paid_day}
func open_settlement() -> Dictionary                  # fällig oder aufgeschoben; {} = nichts offen
func due_day() -> int
func pay_dues(inv: Inventory, via: StringName) -> bool   # &"mayor" | &"carter"
func defer_dues() -> void
func poor_box_coins() -> int
func drop_in_poor_box(coins: int, who: StringName) -> void
func empty_poor_box(inv: Inventory) -> int
func give_to_poor_box(inv: Inventory) -> bool
func check_goal() -> bool; func goal_progress() -> Dictionary   # {settled, market_days, best_tier}
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
class_name OfferingBox extends StaticBody3D           # Prompts „[E] Opferstock …“ (Auswahl: leeren · etwas hineinlegen)
```

**Kassenbuch (P3)**
```gdscript
class_name CashBookConfig extends Resource            # ✦ data/config/cash_book_config.tres
@export var keep_days: int = 62; @export var check_every_minutes: int = 60
@export var sources: Dictionary[StringName, Dictionary] = {}   # {source: {label, prefixes: PackedStringArray, receipt: bool}}
@export var purpose_labels: Dictionary[StringName, String] = {}  # COIN_REASONS → „Pacht“, „Markt“ …
@export var untracked_label: String = "ohne Beleg"
class_name CashBookRules extends RefCounted
static func source_of(reason: String, cfg: CashBookConfig) -> StringName   # Präfix-Tabelle; unbekannt → &"other"
static func is_receipt(source: StringName, cfg: CashBookConfig) -> bool
static func untracked(holdings_delta: int, booked_in: int, booked_out: int) -> int
class_name CashBook extends Node                      # Gruppe cash_book, saveable cash_book / 86
func open_day() -> int
func day_page(day: int) -> Dictionary                 # {in: {source: n}, out: {purpose: n}, untracked, holdings}
func week_page(week: int) -> Dictionary; func month_page(month_key: String) -> Dictionary
func booked_income(month_key: String, receipt_only: bool) -> int
func untracked_in(month_key: String) -> int
func totals_since(day: int) -> Dictionary             # Kapitel-Panel, Bots
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
```

**Wochenmarkt (P4)**
```gdscript
class_name MarketConfig extends Resource              # ✦ data/config/market_config.tres
@export var open_flag: StringName = &"village_open"; @export var weekday: int = 5
@export var window: Vector2i = Vector2i(480, 750); @export var setup_from: int = 450
@export var stalls_visible: Vector2i = Vector2i(390, 810); @export var notice_weekday: int = 3; @export var notice_minute: int = 464
@export var stall_flag: StringName = &"market_stall_granted"; @export var stall_fee: int = 1; @export var stall_slots: int = 6
@export var tick_minutes: int = 30; @export var setup_minutes: int = 10; @export var takedown_minutes: int = 5
@export var groups: Dictionary[StringName, PackedStringArray] = {}   # Gruppe → Items
@export var states: Dictionary[StringName, Dictionary] = {&"scarce": {"price": 1.3, "demand": 1.5}, &"normal": {"price": 1.0, "demand": 1.0}, &"glut": {"price": 0.75, "demand": 0.6}}
@export var state_weights: PackedFloat32Array = [0.25, 0.5, 0.25]
@export var tags: Dictionary[StringName, Dictionary] = {&"cheap": {"price": 0.8, "demand": 1.4}, &"fair": {"price": 1.0, "demand": 1.0}, &"dear": {"price": 1.25, "demand": 0.6}}
@export var season_rules: Array[Dictionary] = []      # {months: PackedInt32Array, group, step}
@export var mourning_deaths: int = 3; @export var mourning_groups: Array[StringName] = [&"candles", &"grave_goods"]
@export var oversold_threshold: int = 6; @export var peddler_group: StringName = &"pantry"
@export var rep_demand: Dictionary[StringName, float] = {}; @export var piety_demand: Dictionary[StringName, float] = {}
@export var leftover_chest: StringName = &"hut_chest"
class_name MarketOfferData extends Resource           # ✦ Unterressource
@export var item: StringName; @export var price: int = 1; @export var stock: int = 1; @export var weight: float = 1.0
@export var requires_flag: StringName = &""; @export var conditions: PackedStringArray = []
class_name MarketStallData extends Resource           # ✦ data/market/stalls/<id>.tres
@export var id: StringName; @export var npc_id: StringName; @export var place: StringName; @export var title: String
@export var offers: Array[MarketOfferData] = []; @export var picks: int = 4
@export var buys_groups: Array[StringName] = []       # was sie am eigenen Stand des Spielers kaufen (Kundschaft)
class_name MarketWareData extends Resource            # ✦ data/market/wares/<item>.tres
@export var item: StringName; @export var group: StringName; @export var value: float = 1.0; @export var demand: int = 1
@export var lines: Dictionary[StringName, String] = {}   # Käufer → Zeile
class_name MarketRules extends RefCounted
static func is_market_day(day: int, cfg: MarketConfig) -> bool
static func next_market_day(day: int, cfg: MarketConfig) -> int
static func group_state(day: int, group: StringName, context: Dictionary, cfg: MarketConfig) -> StringName   # context {deaths_7, sold_last, peddler_days}
static func offers(stall: MarketStallData, day: int, context: Dictionary, cfg: MarketConfig) -> Array[Dictionary]   # {item, price, base, stock, state}
static func demand(ware: MarketWareData, day: int, tag: StringName, context: Dictionary, cfg: MarketConfig) -> int
static func sale_coins(ware: MarketWareData, n: int, state: StringName, tag: StringName, cfg: MarketConfig) -> int
static func buyer_for(day: int, tick: int, wares: Array[StringName], context: Dictionary) -> Dictionary   # {npc, item, n}
static func notice_text(day: int, context: Dictionary, cfg: MarketConfig) -> String
class_name Market extends Node                        # Gruppe market, saveable market / 87
func is_open() -> bool; func market_day() -> int; func next_market() -> int
func lage(group: StringName) -> StringName; func lage_all() -> Dictionary
func grant_stall() -> void; func stall_granted() -> bool
func stall_offers(stall_id: StringName) -> Array[Dictionary]
func buy(stall_id: StringName, item: StringName, n: int, inv: Inventory) -> bool
func set_up_block_reason(player: Player) -> String
func set_up(goods: Dictionary, tags: Dictionary, inv: Inventory) -> bool      # {item: n}, {item: &"cheap"|&"fair"|&"dear"}
func sell_tick() -> Array[Dictionary]                 # Verkäufe eines Takts {npc, item, n, coins, line}
func take_down(inv: Inventory) -> Dictionary          # zurück ins Inventar, Rest in die Truhe
func stall_goods() -> Dictionary; func sold_on(day: int) -> Dictionary
func apply_minute(day: int, minute: int) -> void      # Zettel Do, Glocke 08:00, Schluss 12:30
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
class_name MarketStall extends StaticBody3D           # eigener Stand: Auswahl aufbauen · verkaufen · abbauen; fremde: „[E] Am Stand von … kaufen“
```

**Wunschliste (P1)**
```gdscript
class_name WishlistEntryData extends Resource         # ✦
@export var id: StringName; @export var kind: StringName  # &"station" | &"building" | &"tool" | &"item" | &"per_grave"
@export var ref: StringName; @export var coins: int; @export var available_flag: StringName = &""; @export var max_count: int = 1
class_name WishlistData extends Resource              # ✦ data/economy/wishlist.tres
@export var entries: Array[WishlistEntryData] = []
class_name WishlistProbe extends RefCounted           # nur Tests/Debug
static func open_cost(tree: SceneTree, data: WishlistData) -> int   # Summe der noch nicht besessenen, verfügbaren Anschaffungen
```

**Dialog, Speichern (P5)**
```gdscript
# DialogueConditions (P5) +: p10_open · dues_open · dues_due · dues_deferred · market_day · market_stall_granted
#   · market_lage:<group>:<state> · parish_pending · schau_tier:<tier>
# DialogueActions (P5) +: pay_dues:<via> · defer_dues · grant_stall · parish_handover (Osric gibt das Friedhofsgeld)
#   · settlement_note (Zettel an die Hüttentür)
# SaveMigration (P5): CURRENT := 9; + static func migrate_8_to_9(state: Dictionary, meta: Dictionary) -> Dictionary
#   V9_EMPTY_NODES := ["treasury", "cash_book", "market"]; V9_NEW_STATS (§2.10, 23)
# SaveFileIO.FORMAT_VERSION = 9; read_doc akzeptiert 1…9
# GameState.DEFAULT_STATS + die 23 Stats aus §2.10; COIN_REASONS + &"market", &"rent", &"tax", &"stall"
```

### 3.5 Database (Lead)
Neue Listen: `market_stall(s)` (`data/market/stalls`, nach id), `market_ware(s)` (`data/market/wares`, nach item), `wishlist()` (`data/economy/wishlist.tres`). Leere/fehlende Ordner = leere Listen.

### 3.6 Eingaben
Keine neuen Tasten. [E], Dialoge, Panels; das Merkbuch „Kasse“ über [J] wie alle Reiter.

---

## 4. Welt, Orte & Sichtprüfungen (W-Welt)

### 4.1 Grundsatz
Phase 10 ist eine Werte- und Handelsphase: **kein neues Gebäude, kein neuer Raum, kein neuer Abschnitt, keine neuen Gräber.** Jeder Eingriff steht in §4.5 und wird gegen `tests/fixtures/phase10/{layout_p9,village_layout_p9}.json` (bytegleich zum Referenzstand) geprüft.

### 4.2 Der Markt auf dem Anger
- Vier Stände im Halbkreis zwischen Brunnen und Linde, Gemeindetafel frei: `ms_agathe` (Handkarren daneben), `ms_kehr`, `ms_brandt`, `market_stall_own` (Rand zur Linde). Kein Stand auf einem Zeitplan-Weg, keiner vor einer Tür; Flood-Fill Brücke ↔ alle Türen, Läden, Tafel, Brunnen frei (Kapselbreite 1,5 m) **mit** aufgebauten Ständen.
- Stände: Tisch, Plane auf zwei Stangen, Kisten, Körbe; Kindmeshes nur am Markttag 06:30–13:30 sichtbar (Muster großer Bogen, Phase 9), sonst stehen auf dem Anger nur zwei Pflöcke je Stand (bitgleich zum Alltag bis auf die Pflöcke – Bestätigung über Bilder).
- Marktgang: Wegpunkte `v_market_1…8` zwischen den Ständen, Stehplätze der Kundschaft vor jedem Stand.

### 4.3 Opferstock am Tor
- `ph_prop_offering_box` (Holzpfosten mit eiserner Kassette, Schlitz, Inschrift „Für den Gottesacker“, ≤ 1,2 m) am **östlichen Torpfeiler innen**, gegenüber der Torglocke; nicht auf Veits, Hannes, Brenneisens Platz außen, nicht im Weg der Bahre und des Karrens (Sichtprüfung mit allen dreien und Osric beim Abladen).

### 4.4 Hütte
- Kassenbuch `ph_prop_cash_book` auf dem Pult neben Lorenz' Kladde (Phase 9), aufgeschlagen, mit Federkiel; Prompt über die Pult-Auswahl.

### 4.5 Eingriffe (vollständig)
| # | Ort | Eingriff |
|---|---|---|
| D13 | Anger | 4 Marktstände (Kindmeshes, nur Markttag), 8 Pflöcke, Wegpunkte `v_market_*`, Stehplätze |
| D14 | Brunnen | Wegpunkt `v_market_bell` (Fenner mit Handglocke) |
| D15 | Holderbrücke → Anger | Agathes Weg mit Handkarren (nur Wegpunkte), Abstellplatz neben `ms_agathe` |
| D16 | Gemeindetafel | Marktzettel `ph_notice_market` (Kindmesh, Do–Sa) und Abrechnungszettel `ph_notice_bill` (Kindmesh, 1.–7.) |
| G5 | Friedhofstor innen, Ostpfeiler | Opferstock `ph_prop_offering_box` |
| G6 | Hüttentür | Abrechnungszettel `ph_notice_bill` (Kindmesh wie `ph_door_note`, 1.–7.) |
| H1 | Hütte, Pult | Kassenbuch `ph_prop_cash_book` |

### 4.6 Sichtprüfung und Wege (Kamerastrahl-Test, Pflicht; Verfahren Phase 6 §4.5)
- Markt bei Zoom 12/22/24 aus der Spielkamera vom Brunnen und vom eigenen Stand: alle vier Stände, Agathe, der Totengräber hinter seinem Stand, Kundschaft davor; Opferstock mit Besucherin; Kassenbuch am Pult. Jede neue Route (Agathe mit Karren, Hof-Stände, Marktgang, Fenner zur Glocke) frei (Physik-Wegtest wie G8 Runde 5, `test_walk_tempo`).

### 4.7 Licht
- Keine neuen Lichter. Der Markt ist ein Vormittag; Messinglaternen auf dem Friedhof nutzen den bestehenden Laternen-Pool (wie `decor_lantern`).

---

## 5. Speichern & Migration (P5)

### 5.1 Format v9 (Ergänzungen)
```
format_version: 9
data.autoloads.GameState.stats   + parish_weeks, parish_paid, need_paid, hardship_paid, settlements, dues_paid, dues_deferred,
                                   dues_waived, rent_paid, tithe_paid, estimate_paid, donations_received, poor_box_emptied,
                                   market_days, market_stall_days, market_items_sold, market_coins, market_items_bought,
                                   roses_planted, coins_spent_market, coins_spent_rent, coins_spent_tax, coins_spent_stall
data.autoloads.GameState.flags   + p10_open, p10_open_day: 75, market_stall_granted, debit_credit_complete, clue_c_k_rent_paid (B)
data.nodes.treasury              {"book_start": 75, "schau": {"week": 11, "day": 80, "tier": "venerable", "care": 0.82, "disturbed": 0,
                                  "quality": 14, "need": 0, "hardship": 0, "paid": false}, "weeks": [{"week": 10, "paid": 12, "day": 81}],
                                  "settlements": {"1834-12": {"day": 91, "rent": 5, "tithe": 8, "estimate": 0, "deferred_in": 0,
                                  "total": 13, "state": "due", "paid_day": 0, "via": ""}}, "poor_box": 3, "rent_prepaid_until": "",
                                  "goal_done": false}
data.nodes.cash_book             {"open_day": 75, "last_holdings": 124, "last_check": [75, 1380],
                                  "days": {"75": {"in": {"request": 1, "tip": 2}, "out": {"village": 8, "apprentice": 3}, "untracked": 0}},
                                  "months": {"1834-12": {"in": {…}, "out": {…}, "untracked": 0}}}
data.nodes.market                {"granted": true, "stall": {"day": 79, "goods": {"grave_candle": 6}, "tags": {"grave_candle": "dear"},
                                  "ticks": 2}, "sold": {"79": {"grave_candle": 2}}, "bought": {"79": {"ms_agathe:rose_bush": 1}},
                                  "sold_groups_last": {"candles": 2}}
```
Nicht gespeichert: Marktlage und Angebote (aus Tag, Woche, Zählern), Kundschaft (aus `hash`), Laufzeit-Zeitpläne (Agathe, Hof-Stände), Seiten des Merkbuchs (Leser). Speichern ist während einer TimedAction gesperrt (wie bisher), sonst überall erlaubt – auch mit aufgebautem Stand: Nach dem Laden liegen die Waren wieder auf dem Stand, der nächste Takt läuft bitgleich.

### 5.2 Migration v8 → v9 (Phase-9-Spielstände müssen laden)
`SaveMigration.migrate_8_to_9` läuft in `read_doc` nach `decode_state` (Kette 1→…→9), rein, idempotent, auf einer tiefen Kopie.
1. `nodes.treasury`, `cash_book`, `market` = `{}` über `V9_EMPTY_NODES`, eingefügt erst, wenn W-Welt die Knoten anlegt (wie Phase 4–9).
2. Stats (§2.10) = 0. Flags: keine. `p10_open` setzt `Treasury.post_load`, wenn `who_knows_when_complete` gilt.
3. Münzen, Inventare, Truhen, Lohndose **unverändert** (Bestätigung §14.7). Der neue Tarif gilt ab dem Laden; das Kassenbuch beginnt am Ladetag (`book_start` = Tag beim ersten `load_state` mit leerem Knoten), die erste Abrechnung am nächsten Monatsersten, anteilig.
4. Ein laufender Tag mit schon ausgezahltem Pflegegeld bekommt sein Friedhofsgeld erst am nächsten Montag, anteilig ab dem Ladetag (kein doppeltes Geld, kein Loch: das Pflegegeld des Ladetags bleibt).
5. Der Phase-5-Steinbruchbrief ist der Pachtbrief (gleiches Flag `bruch_license`); die Pacht beginnt mit der ersten Abrechnung.
6. Spieler, Gräber, Aufträge, Bitten, Briefe, Ketten: unverändert.

### 5.3 Fixtures (W0, Lead, vor jeder Phase-10-Code-Änderung auf dem Referenzstand über `Phase9Bot`/`HillBot` + echte Systeme)
`tests/fixtures/saves_v8/` (neben dem vorhandenen `slot_p9_mid_h4.json`):
- `slot_p9_day75_kindly.json`: `kindly9`-Endstand, 07:00 Tag 75, `who_knows_when_complete`, Ende A, ≈ 132 Münzen. Start für `kindly10`, `market10`, `frugal10`, `poor10` (Münzen per Treiber auf 3), `lazy10`, `save_load10`.
- `slot_p9_day75_trader.json`: `trader9`-Endstand (verwertend/anatomisch, Pietät ≈ −68). Start für `trader10`.
- `slot_p9_day75_stay.json`: `stay9`-Endstand (Ende B, D3, Reihe 4 voll – kein freies Grab). Start für `stay10`.
- `slot_p9_founder.json`: `founder9`-Endstand (neues Spiel). Start für `founder10`.
- `slot_p9_day38_village.json`: neues Spiel bis `village_open` + 1 Tag über die Phase-3–7-Gründer-Bots (Dorf offen, kein Kapitel 9) – Markt ohne `p10_open`.
- `slot_p9_day29_new.json`: neues Spiel, 23:00 Tag 29 (am Morgen danach die erste Monatsabrechnung, nur Pacht).
Dazu `make_v8_saves.gd` + `_driver.gd` (historisches Werkzeug) und `tests/fixtures/phase10/{layout_p9,village_layout_p9}.json`. Lade-Wächter `tests/integration/test_saves_v8_load.gd` (Lead). v7…v1-Fixtures laden weiter (Kette bis 9).

---

## 6. Debug-Konsole (W-UI) – neue Befehle
`p10 open` · `weekday` · `schau [now]` (Schau sofort auswerten) · `parish pay` · `settle [now|pay|defer|waive]` · `dues` · `poorbox <n>` · `cash [day|week|month] [key]` · `untracked <n>` · `market [now|close]` · `lage <group> <scarce|normal|glut>` · `stall grant` · `stall put <item> <n> [tag]` · `stall tick` · `tariff` (Tarifblatt aus den Daten) · `wish` (offene Wunschliste, Summe) · `goal10`. Bestehend und weiter nutzbar: `time`, `tp`, `rel`, `coins`, `p9 open`.

---

## 7. UI (W-UI)

### 7.1 Merkbuch „Kasse“ (neuer Reiter nach „Vorhaben“)
Pergamentseite in Buchführung: links die Seiten **Heute · Woche · Monat · Abgaben · Markt**, rechts zwei Spalten **Haben** (Einnahmen nach Quelle) und **Soll** (Ausgaben nach Zweck), darunter „ohne Beleg“ in Bleistift, „Übertrag“ und das Polster. Woche: Friedhofsschau mit Stufe, Pflege (Wort, nicht Prozent: „fast alle Gräber gepflegt“), Friedhofsgeld mit Teilen („Stufe 12 · Pflege 2 · Bedarf 0“). Monat: laufend oder abgerechnet mit Abgaben; frühere Monate blätterbar. Abgaben: was fällig ist, bis wann, wo man zahlt; Aufschub/Erlass als Sätze. Markt: nächster Markttag, Lage (ab Donnerstag), letzter Markt (verkauft je Ware, gekauft). Maus + Tastatur (↑/↓, Tab, Enter). Aufbau ≤ 4 ms (§9). Im Reiter „Vorhaben“ (Phase 9) steht unter „Was du schuldest“ zusätzlich „Abgaben bis 7. Hartung: 13 Münzen“.

### 7.2 Monatsabrechnung (`&"settlement"`, rechts angedockt)
Kopf „Abrechnung Julmond 1834 – Gemeinde Hollerbrück“, Haben/Soll in Kurzform, die Abgaben einzeln mit einer Zeile Begründung („Pacht für Bruch und Werkhof, ab dem 16.“), Summe, Frist, offener Aufschub. Knöpfe „Verstanden“ und „Aufschieben“ (Zahlen nur bei Fenner/Osric, damit es sichtbar ist). Keine Ruf-Zahlen.

### 7.3 Eigener Stand (`&"market_stall"`, rechts angedockt)
Links das Inventar (nur verkäufliche Waren, mit „gefragt/normal/reichlich“), rechts sechs Plätze mit Menge und Preisschild (günstig · recht · teuer als drei Knöpfe; daneben der Stückpreis heute und „sonst 4“). Unten Standgeld, „Aufbauen“. Während des Verkaufs ausgeblendet (HUD-Balken „Am Stand: noch 3 Takte“), danach Ergebnis-Karte (verkauft je Ware, Münzen, eine Kundenzeile).

### 7.4 Kaufen an Ständen
Laden-Panel `&"shop"` mit Marktkopf (Stand, Lage-Wort je Ware, „sonst“-Preis). Keine Pfeile, keine Diagramme.

### 7.5 HUD und Prompts
- **Datum** „Sa, 20. Julmond 1834“ (Wochentag kurz).
- **Zielzeilen** (`ObjectiveResolver`): „Sprich mit Fenner (Amtsstube)“ · „Marktzettel lesen (Gemeindetafel)“ · „Morgen ist Markt in Hollerbrück“ · „Am Stand: 6 Kerzen, 2 Kränze, 3 Kreuze“ · „Friedhofsschau heute Abend“ · „Die Monatsabrechnung liegt in der Hütte“ · „Abgaben bis 7. Hartung: 13 Münzen (Fenner oder Osric)“ · „Soll und Haben 2/3“.
- **Notizen:** „Osric bringt das Friedhofsgeld: 14 Münzen.“ · „Die Gemeinde legt 6 Münzen dazu.“ · „Fenner läutet: Markt ist offen.“ · „Martha Kehr kauft einen Wachskranz.“ · „Fenner hat die Abgaben angeschrieben.“ · „Im Opferstock klimpert es.“
- **Prompts:** „[E] Am Pult: Kassenbuch …“ (Auswahl) · „[E] Monatsabrechnung durchsehen (10 Min)“ · „[E] Opferstock: leeren oder etwas hineinlegen“ · „[E] Am Stand: aufbauen“ · „[E] Am Stand verkaufen (30 Min)“ · „[E] Stand abbauen“ · „[E] Am Stand von Agathe Wendel kaufen“ · „[E] Rosenstock setzen (10 Min)“.

### 7.6 Karte, Tageszusammenfassung, Abschluss
- **Karte:** Markt-Symbol auf dem Anger am Samstag (und Freitagabend als „morgen“), Opferstock am Tor; kein Pfeil.
- **Tageszusammenfassung:** Kassenbuch-Zeile („Haben 22 · Soll 26 · Polster 130“), montags das Friedhofsgeld, samstags der Stand.
- **Abschluss-Panel** Variante `&"debit_credit"` (§1.5).

---

## 8. Figuren, Animationen, Assets & Ton (P6, W-Ton; Stil gesperrt, alle `ph_`, `lib_painted.py` / `lib_faces.py` / geteilte Materialien)

### 8.1 Neue Figur
| Datei | Figur | Budget | Besonderheiten |
|---|---|---|---|
| `ph_chr_marketwoman` | Agathe Wendel | ≤ 9 000 Dreiecke, gemeinsames Rig (8 Knochen + `tool`) | Kopftuch, Strickjacke, Lederschürze mit Geldkatze (Kindmesh `purse`), Handkarren-Griff am `tool` (Karren `ph_prop_handcart_small` folgt wie Osrics Karren); Gesicht über `lib_faces.py` (breit, rotwangig, Lachfalten) |

### 8.2 Neue Animationen (Clips; `-loop` wird geschleift)
| Figur | Clips |
|---|---|
| Totengräber | `stall_arrange` (Waren auslegen), `stall_offer-loop` (hinter dem Stand, reicht an), `count_coins` (Münzen in die Hand zählen – auch beim Friedhofsgeld und am Opferstock), `plant_rose` (kniend, Rosenstock setzen) |
| Agathe | `idle`, `walk`, `talk`, `push_cart-loop`, `arrange_wares-loop`, `offer`, `count_coins` |
| Martha Kehr, Hinrich Brandt (Neu-Export) | `stall_tend-loop`, `arrange_wares-loop` |
| Haushalte und Dorfbewohner als Kundschaft (Neu-Export der Figuren mit Bedarf) | `buy_hand_over` (Ware nehmen, Münze geben) |
| Fenner (Neu-Export) | `ring_hand_bell` (Handglocke, Kindmesh `hand_bell`) |
Körper-Meshes und alle alten Clips bleiben hash-gleich.

### 8.3 Ton (W-Ton, prozedural, eigenständig)
`market_murmur-loop` (Anger am Samstag, Stimmengewirr ohne Wörter), `hand_bell`, `coins_count`, `coins_purse`, `ledger_page`, `quill_short`, `stall_cloth` (Plane), `crate_set`, `poor_box_coin`, `handcart_light-loop` (Agathes Karren, Pegel wie Osrics Karren nach der G9-Absenkung −8 dB). Keine neue Musik.

### 8.4 Requisiten und Icons
`ph_prop_market_stall` (Tisch, Plane `awning`, Plätze `goods_1…6`, ≤ 2,4 m), `ph_prop_market_peg`, `ph_prop_market_crate`, `ph_prop_market_basket`, `ph_prop_handcart_small`, `ph_prop_offering_box`, `ph_prop_cash_book` (+ Handrequisit `ph_tool_cash_book` für `count_coins`/Pult), `ph_notice_market`, `ph_notice_bill` (Code-Meshes wie `ph_notice_slip`), `ph_prop_grave_rose` (Rosenstock am Grab, winterlich: Hagebutten, wenig Laub), `ph_deco_lantern_brass`; Icons `rose_bush`, `brass_lantern`. Höhen: keine Requisite > 2,4 m (Stand), Grabschmuck ≤ 0,8 m.

---

## 9. Performance-Budget (Messung mit `village_shots.gd --phase10 --cpu`, `graveyard_shots_phase10.gd --cpu`, `perf_probe_run.gd` + Web `--perf-probe`)
| Größe | Budget | Begründung |
|---|---|---|
| FPS | 60 @ 1080p Mittelklasse-GPU; **Web (Compatibility)** ohne Frame > 50 ms beim Öffnen von „Kasse“, Abrechnung und Stand-Panel | G7–G9 |
| Figuren mit Skelett, Dorf am Markt | **≤ 15** (Agathe, 2 Hof-Stände, Marktgang aus vorhandenen Figuren) | `NpcLod` unverändert; Plan B: Marktgang 4 statt 6 Figuren |
| Draw Calls Dorf | ≤ Phase-9-Wert + 60 am Markttag, + 8 sonst (Pflöcke) | Stände als ein Mesh mit Kindmeshes |
| Lichter | keine neuen | §4.7 |
| Skripte CPU/Frame (headless) | Phase-10-Anteil **≤ +0,1 ms** (Markt läuft, Friedhof mit Opferstock) | `Treasury`, `CashBook`, `Market` minuten- bzw. ereignisgetrieben, ohne `_process`; Kassenbuch-Abgleich einmal je Spielstunde |
| Merkbuch „Kasse“ | Aufbau ≤ 4 ms bei 62 Tagen + 6 Monaten | Seiten lesen nur Summen |
| Spielstand / Laden | < 430 kB (+ ≈ 8 kB) / < 1 s | Tagesseiten auf 62 Tage begrenzt |

## 10. Tests
Regeln wie Phase 3–9 (Fixtures statt fremder Moduldaten, Fehler-Logger, Watchdog). **Alle 3 394 bestehenden Tests bleiben grün**; Anpassungen nur durch den Besitzer: Münzbeträge und -bänder (P1, §10.3), Item-/Rezept-Zählungen (P4), Stat- und Zweck-Listen (P5), Layout-Diff (W-Welt), Zahl der Merkbuch-Reiter (W-UI).

### 10.1 Unit
| Datei | Besitzer | Prüft |
|---|---|---|
| `test_calendar_rules.gd` | Lead | Tag 1 = Freitag, Samstage/Sonntage, Monatserste 30/60/91/122, Monatslängen, Jahreswechsel, `next_weekday`; `StoneCalendar` unverändert |
| `test_tariff_sheet.gd` / `test_wishlist.gd` | P1 | Tarifblatt §2.4 = Daten (jede Zeile); `tariff_report.py` erzeugt dieselbe Tabelle; Wunschliste: nur verfügbare, nicht besessene Einträge, je Grab zählend |
| `test_treasury.gd` / `test_treasury_rules.gd` / `test_offering_box.gd` | P2 | Schau So 18:00, Auszahlung Mo 07:40 (Osric) bzw. Truhe; Stufe × Pflege × gestört, Kappe 15; Bedarf ⌈(60 − P)/4⌉ ≤ 15; Notgroschen auf 10 ≤ 8; erste Woche anteilig; Abrechnung am Monatsersten (anteilig, Pacht ab Pachtbrief, Zehnt/Schätzung ab `village_open`, Kappen); Zahlung Fenner/Osric, pünktlich Ruf +1/Fenner +2; Aufschub am 8., Erlass nach einem Monat, nie mehr als ein Monat offen, nie negativ; Opferstock (Einwurf je zufriedenem Besuch, Kappe 2/Tag, max 30, leeren, geben + Pietät 1/Woche); Kapitelziel (drei Bedingungen, genau einmal); `p10_open` am Morgen (idempotent) und nach v8-Laden; kein Pflegegeld mehr; Save/Load |
| `test_cash_book.gd` / `test_cash_book_rules.gd` | P3 | jede Quelle aus ihrem Grundtext, unbekannt → `other`; Zwecke = `COIN_REASONS`; „ohne Beleg“ aus dem Polster-Abgleich (Wertsachen, Ilse); belegt/unbelegt; Tages-, Wochen-, Monatsseiten; 62-Tage-Grenze; Summe der Buchungen = `stats.coins_spent` bzw. Einnahmen der Bots; Save/Load |
| `test_market.gd` / `test_market_rules.gd` / `test_market_stall.gd` / `test_items_phase10.gd` | P4 | Markttag Samstag ab `village_open`, Fenster 08:00–12:30; Lage deterministisch (gleicher Tag → gleiche Lage, nach Laden gleich), Frost/Trauerwoche/Übersättigung/Hanne-Regel; Angebote je Stand (`picks`, Vorrat, Bedingungen, atomar); eigener Stand: Freigabe, Standgeld, 6 Plätze, Schilder, Takte, Nachfrage (Lage × Schild × Ruf × Pietät), Erlös gerundet ≥ 1, kein Verkauf ohne Totengräber, Rest zurück (Inventar, dann Truhe); Rosenstock wirkt wie Grabblumen dauerhaft, zählt als gepflegt; Messinglaterne Zier-Wert; neue Rezepte; Save/Load mit aufgebautem Stand |
| `test_dialogue.gd` (+) / `test_save_migration.gd` (+) / `test_save.gd` (+) / `test_game_state.gd` (+) / `test_schedule.gd` (+) | P5 | neue Bedingungen und Aktionen; Osric `p10_intro` einmal, in **beiden** Menüs Friedhofsgeld/Abgaben/Pachtbrief; Fenner Eröffnung, Platz, Zahlung, Aufschub; Samstagszeitpläne nach Gehtempo; **7 v8-, 7 v7-, 6 v6-, 7 v5-, 7 v4-, 6 v3-, 4 v2-, 3 v1-Fixtures laden ohne Fehler/Warnungen**; v9-Roundtrip identisch; Version 10 → abgelehnt |
| `test_assets_phase10.gd` | P6 | Agathe vorhanden, Budget, Rig, Clips, Kindmeshes, Gesicht über `lib_faces`; Re-Exporte: Körper und alte Clips hash-gleich; Requisiten-Höhen; Icons |
| `test_audio_phase10.gd` | W-Ton | Cues vorhanden, Lautheit im Ziel (Karren wie Osric nach G9), Web-Einstellungen unverändert |
| `test_ui_phase10.gd` / `test_map_phase10.gd` | W-UI | „Kasse“ (fünf Seiten, Haben/Soll, ohne Beleg, Übertrag), Abrechnung, Stand-Panel (Plätze, Schilder, Ergebnis), Marktkopf im Laden-Panel, HUD-Datum mit Wochentag, Zielzeilen-Kette, alle angedockt bei 1280 × 720 … 1920 × 1080, Abschluss-Panel; Karte ohne Pfeil |

### 10.2 Integration
- `test_treasury_month.gd` (P2): neues Spiel bis Tag 31 (Schauen Tag 3/10/17/24, erste Abrechnung Tag 30 nur mit Pacht, wenn Pachtbrief); `slot_p9_day75_kindly` bis Tag 98: Abrechnung Julmond, zahlen bei Osric, Hartung aufschieben, Hornung Erlass; Roundtrip am Monatsersten 06:00, am 7. 23:59 und am Montag 07:39.
- `test_cash_book_ledger.gd` (P3): zehn Tage mit allen Quellen (Bestattung, Ilse, Wertsachen, Quast, Markt) → Kassenbuch = Münzbuch des Bots, „ohne Beleg“ = Wertsachen + Ilse + Quast.
- `test_market_day.gd` (P4): `slot_p9_day38_village` → Samstag: Agathe kommt sichtbar, Zettel am Donnerstag, Glocke 08:00, Stand aufbauen, vier Takte, Kundschaft geht zum Stand, Abbau, Rest in die Truhe; Roundtrip mit aufgebautem Stand nach Takt 2.
- `test_phase10_loop.gd` (W-Welt): v8 laden → `p10_open` → Osric → Fenner → Waren → Zettel → Markt 1 → Rosenstock → Schau → Friedhofsgeld → Markt 2 → Abrechnung → Zahlung → **Kapitel**. Roundtrip an 6 Momenten (Stand aufgebaut, Schau ausgewertet und nicht ausgezahlt, Abrechnung fällig, Aufschub, Opferstock voll, nach dem Kapitel).
- `test_phase9_save_upgrade.gd` (P5): `slot_p9_mid_h4` → Phase 9 läuft weiter, Tarif und Kassenbuch ab Laden, `p10_open` erst nach dem Phase-9-Kapitel.
- `test_village_world.gd` (+) / `test_graveyard_world.gd` (+) / `test_interiors.gd` (+): Layout-Diff nur D13–D16, G5–G6, H1; Sichtprüfungen §4.6; Routen frei.

### 10.3 Bots und Zielkurve
- **Alte Bots (Phase 3–9, `HillBot`):** spielen weiter ohne Markt und ohne aktive Zahlung (Aufschub → Erlass). P1 setzt ihre **Münz-Bänder** nach der W1-Messung neu (Δ statt absolut, Kommentar „Tarif Phase 10“); **alle anderen Erwartungen bleiben** (Kapiteltage höchstens **±2 Tage**, Strategien, Wege, Leerlauf-Messung `HillBot` ±5 %). `save_load*` bleibt zeilengleich zu seinem Geschwister. Wer ±2 Tage verfehlt, geht über die Stellschrauben (§2.4.4), sonst Benutzerentscheidung (§14.7).
- **`phase10_bot.gd`** (W3) erweitert `Phase9Bot`: Fenner/Osric über den echten `DialogueRunner`, Werkbank (neue Rezepte), Marktzettel lesen, Stand über die echte `MarketStall` + Panel, Kaufen über das Laden-Panel, Rosenstock setzen, Opferstock, Pult (Abrechnung), Zahlung. **Kassenbuch und Münzbuch** je Strategie; der Bot kauft aus einer Wunschliste mit Reserve (kauft nur, wenn danach ≥ 20 bleiben).
  | Strategie | Start | Tage | Verhalten | Erwartung |
  |---|---|---|---|---|
  | `kindly10` | v8 `day75_kindly` | 17 | Bogen A §1.4: Stand an beiden Markttagen, Lage gelesen, 2 Rosen + Laterne, zahlt pünktlich bei Osric | Kapitel B17; Δ −30 … +10; Ausgabequote ≥ 85 %; morgens ≥ 5 |
  | `market10` | v8 `day75_kindly` | 17 | Stand mit allen Takten, Schilder nach Lage, kauft nichts Bleibendes | Stand je Markt 15–30 (≤ 45); Kapitel |
  | `frugal10` | v8 `day75_kindly` | 17 | kauft nur Pflicht, schiebt die Abgaben auf | Kapitel (Aufschub zählt); Fenner unverändert; Δ ≤ `kindly10` + 35 |
  | `poor10` | v8 `day75_kindly`, Münzen per Treiber auf 3 | 17 | wie `kindly10`, kann Abgaben nicht zahlen | **morgens nie < 5** (Bedarf, Notgroschen), Aufschub, Kapitel erreicht, keine Warnung |
  | `trader10` | v8 `day75_trader` | 17 | verwertender Weg, Präparate an Quast, Ilse | Schätzung mindestens einmal; Δ ≤ `kindly10` Δ + 15 % seiner Einnahmen; Kapitel |
  | `stay10` | v8 `day75_stay` | 17 | kein freies Grab | Kapitel; Friedhofsgeld + Stand tragen den Lehrling (Δ ≥ −40) |
  | `lazy10` | v8 `day75_kindly` | 17 | kein Markt, keine Bitte, kein Lehrling | **kein** Kapitel; Δ ≤ +35 und ≤ `kindly10` + 35 |
  | `founder10` | v8 `founder` | bis Kapitel | neues Spiel nach Phase 9 | Kapitel an der nächsten Abrechnung mit zwei Märkten |
  | `save_load10` | wie `kindly10` | 17 | lädt jeden Morgen, einmal mit aufgebautem Stand, einmal am 1. 06:01 | zeilengleich zu `kindly10` |
- **Zielkurve `curve10`** (P1 + W3, `economy_curve_bot.gd`, `test_economy_curve.gd`, Umgebungsvariable `P10_CURVE=1` für den langen Lauf, Gate-Pflicht): neues Spiel → Tag 91 mit den würdevollen Bots der Phasen 3–9 als Kette in einem Lauf auf dem neuen Tarif (Gründer-Linie wie die Fixtures: Phase-3-Verhalten `diligent` bis `cemetery_complete`, dann `reverent` (P4), `crafter` (P5), `founder` (P6), `founder7`, `founder8`, `founder9`, `founder10`; W0 legt die Übergaben fest); Prüfpunkte Tag 14, 30, 45, 60, 75, 91 gegen §2.3 (Polster-Band, Δ, Ausgabequote, Wunschliste ≥ 1,3 × Einnahmen der nächsten 14 Tage, morgens ≥ 5 / ≥ 8). Zweite Kette `curve10_harvest` (verwertend: `harvester` → `harvester5` → `harvester6` → `anatomist7` → `anatomist8` → `trader9` → `trader10`) für Grundsatz 5. Tabelle in `docs/reviews/phase10_round1/zielkurve.md`.
- **Save-Fuzzer (W3):** + echter v9-Stand mitten im Bogen (Stand aufgebaut, Schau ausgewertet, Abrechnung fällig, Aufschub aus dem Vormonat, Opferstock 12) mit gezielten Mutationen (Monat unbekannt, zwei offene Abrechnungen, negativer Opferstock, Ware auf dem Stand, die es nicht gibt, Kassenbuch-Tag in der Zukunft, `book_start` > heute) + alle v8…v1-Fixtures. Neu in der Konsistenzprüfung: höchstens eine offene Abrechnung, Opferstock 0…30, Stand nur am Markttag aufgebaut (sonst beim Laden abgebaut), Kassenbuch-Summen ganzzahlig.
- Art-Prototyp-Regression: `test_art_prototype.gd` unverändert grün.

## 11. Screenshot-Liste Gate G10 (`village_shots.gd --phase10 -- --out=/abs/dir`, `graveyard_shots_phase10.gd -- --out=/abs/dir`, `ui_screenshots.gd --phase10`, 1280×720, echter Renderer, dazu je eine Web-Aufnahme der Motive 02, 05, 12 → `docs/reviews/phase10_round1/`)
| # | Motiv |
|---|---|
| p10_00 | Kontaktbogen: Agathe neben dem Totengräber, Martha Kehr, Hinrich Brandt, Fenner (idle, gleiche Kamera, Tag) |
| p10_01 | Gesicht nah: Agathe |
| p10_02 | Der Markt auf dem Anger, 09:30, alle vier Stände, Marktgang |
| p10_03 | Agathe kommt mit dem Handkarren über die Holderbrücke (06:50) |
| p10_04 | Fenner läutet 08:00 am Brunnen |
| p10_05 | Der Totengräber hinter seinem Stand, Kerzen, Kränze, Kreuze ausgelegt, Martha Kehr kauft |
| p10_06 | Stand-Panel mit Schildern und Lage |
| p10_07 | Laden-Panel am Stand Agathe (Marktkopf, „sonst“) |
| p10_08 | Marktzettel an der Gemeindetafel (Donnerstag) |
| p10_09 | Der Anger am Dienstag (nur Pflöcke) – Vergleich mit p10_02 |
| p10_10 | Rosenstock am Grab (Lindenacker), Totengräber kniend (`plant_rose`) |
| p10_11 | Messinglaterne auf dem Friedhof bei Nacht neben einer Grablaterne |
| p10_12 | Opferstock am Tor, eine Besucherin wirft ein |
| p10_13 | Osric übergibt am Montag das Friedhofsgeld (`count_coins`) |
| p10_14 | Hütte: Kassenbuch am Pult, Abrechnungszettel an der Tür |
| p10_15 | Merkbuch „Kasse“ – Woche mit Friedhofsschau |
| p10_16 | Merkbuch „Kasse“ – Monat mit Abgaben und „ohne Beleg“ |
| p10_17 | Monatsabrechnung Julmond (Panel) |
| p10_18 | Fenner in der Amtsstube nimmt die Abgaben |
| p10_19 | Tageszusammenfassung mit Kassenbuch-Zeile |
| p10_20 | Abschluss-Panel „Soll und Haben“ |
| p10_vis_market / _poorbox | Sichtprüfung §4.6 mit eingezeichneten Strahlen |
Dazu Asset-Tafeln und Animations-Kontaktbögen `docs/reviews/phase10_assets/`, Zielkurve `zielkurve.md` (Tabelle und Kurve als Bild), Tarifblatt `tarifblatt.md` (erzeugt), Performance (`perf_p10_01…03`: Markt 09:30 · Friedhof mit Opferstock · Merkbuch „Kasse“ offen), Web-Sonde.

## 12. Wellenplan
### 12.1 Wellen
| Welle | Agents (parallel) | Inhalt | Ende |
|---|---|---|---|
| **W0** | Lead | **Zuerst v8-Fixtures** (6 Stände §5.3, eigener Commit vor jedem Gerüst) und `tests/fixtures/phase10/{layout_p9,village_layout_p9}.json`; **Ist-Messung des alten Tarifs** über die Kette `curve10` (Werkzeug `economy_curve_bot.gd` als Gerüst, Ausgabe `docs/reviews/phase10_wip/ist_kurve.md` – die Zahlenbasis für P1). Dann: `CalendarRules` vollständig, Datenklassen ✦, Stubs mit exakten Signaturen, 6 EventBus-Signale, Database-Ordner, `SaveMigration.CURRENT = 9` mit `migrate_8_to_9` (vollständig, wie W0 Phase 9), Config-Fixtures (+ `Phase10Fixtures`: `p10_open(tree, day)`, `market_day(tree)`, `stall_with(goods)`, `schau_done(week)`, `settlement_due(month)`, `deferred(month)`, `poor_box(n)`, `cash_day(day, in, out)`), `test_phase10_scaffold.gd`, `test_saves_v8_load.gd` | Import + alle Tests grün → Commit |
| **W1** | **6 Pakete:** P1 … P6 (bei 5 Agents: P2 + P3 · P1 · P4 · P5 · P6) | Tarif in den Daten, Tarifblatt, Wunschliste, **Messung der alten Bots auf dem neuen Tarif** und Neu-Bänder (P1) · Friedhofsschau, Friedhofsgeld, Bedarf, Abrechnung, Abgaben, Aufschub/Erlass, Opferstock (P2) · Kassenbuch mit Quellen und „ohne Beleg“ (P3) · Markt, Lage, Stände, eigener Stand, Rosenstock, Laterne, Rezepte (P4) · Dialoge, Zeitpläne Samstag, Migration v9 (P5) · **Agathe zuerst**, dann Stände, Opferstock, Clips, Icons (P6) | je Modul: Tests grün → Merge durch Lead, danach `--import` |
| **W2** | W-Welt, W-UI, W-Ton (3 parallel) | Marktplätze, Opferstock, Kassenbuch am Pult, Agathes Weg, alle neuen Npc in der Welt, **Sichtprüfungen §4.6**, `test_phase10_loop`; Merkbuch „Kasse“, Abrechnung, Stand-Panel, Marktkopf, HUD-Datum, Zielzeilen, Karte, Debug; alle Klänge | Integration + Roundtrips grün, Screenshots erstellt |
| **W3** | QA (19), Art (04), Audio (17), Economy (14), Lead | `phase10_bot.gd` (9 Strategien, Kassenbuch = Münzbuch), **Zielkurve `curve10` + `curve10_harvest`**, alte Bots mit Neu-Bändern, Save-Fuzzer v9, Performance relativ + Web-Sonde, Prüfung im exportierten pck, Stil-/Gesichts-/Animations-/Ton-Prüfung, Befunde beheben (Besitzer), Gate-Protokoll in `QUALITY_GATE_STATUS.md` | **STOPP – Benutzerprüfung G10** |

### 12.2 Abhängigkeiten
- **P3 liefert zuerst** (Tag 1–2): `CashBook` mit Quellen-Tabelle – P2 braucht `booked_income`/`untracked_in` für die Abrechnung, P1 für die Messung. Bis dahin arbeiten P2/P1 gegen `Phase10Fixtures.cash_day`.
- **P1 misst früh:** Nach dem Tarif in den Daten (Tag 1–2) laufen die alten Bots über Nacht; ihre Abweichungen (Kapiteltage!) gehen an den Lead, bevor P2/P4 ihre Zahlen festlegen.
- **P6 liefert zuerst** Agathe (Rig, `idle/walk/talk/push_cart`) und den Stand – Blocker für Sichtprüfung und Bildserien.
- `reputation.gd` (Pflegegeld aus), `visitors.gd` (Opferstock): nur P2. `village_shops.gd` (Marktkopf), `grave_care.gd` (Rosenstock): nur P4. `dialogue_*`, `save_*`, `game_state.gd`, Zeitpläne: nur P5. `data/items/*`, `data/recipes/*`: nur P4. Münzwerte in fremden Daten: nur P1 (und nur die Münzfelder).
- **Lastverteilung W1** (Richtwert Arbeitstage): P1 4 (viele Messläufe) · P2 4 · P3 2 · P4 5 · P5 4 · P6 4.

### 12.3 Texte
P5 besitzt alle Dialoge, Gerede und Kapiteltexte; P2 die Texte der Abrechnung und des Opferstocks (in `treasury_config.tres`); P4 die Marktzettel, Kundenzeilen und Waren-Texte; P3 die Seitentitel des Kassenbuchs. Die Leittexte stehen in §1–§2; wer sie ändert, meldet es dem Lead.

### 12.4 Prioritäten (Umfang „mittel“)
| Prio | Inhalt | Wenn W1 eng wird |
|---|---|---|
| **A** (Gate) | **Tarif neu** (§2.4 vollständig, alle Daten) mit Tarifblatt und **Zielkurve `curve10`** (würdevoll) · Neu-Bänder der alten Bots · **Gemeindekasse:** Friedhofsschau (berechnet), Friedhofsgeld mit Stufe/Pflege/Bedarf/Notgroschen, Auszahlung über Osric, Monatsabrechnung mit Pacht, Zehnt und Schätzung, Zahlen bei Fenner/Osric, Aufschub und Erlass, **Opferstock** · **Kassenbuch** (Quellen, „ohne Beleg“, Seiten Heute/Woche/Monat/Abgaben) · **Wochenmarkt:** Kalender, Samstag, Lage mit Zettel, drei Stände mit Angeboten, **eigener Stand** mit vier Waren (Holzkreuz, Kräuter/Kräuterbündel, Grabkerze, Wachskranz), Schildern und Takten, zwei neue Rezepte, **Rosenstock und Messinglaterne**, Agathe als Figur · Kapitel „Soll und Haben“ · Save v9 | – |
| **B** (geplant) | Sichtbare Friedhofsschau (Fenner und Lenz gehen sonntags über den Hügel) · `curve10_harvest` als eigene Kette (sonst Grundsatz 5 über die Fixture-Bots `trader10`/`anatomist8`) · Stiftungen der Haushalte · Trauernde tragen am Sonntag sichtbar ihren Kranz aufs Grab · Läden folgen der Marktlage ±1 · weitere Waren (Grabvase, Strohblumen, Holunderwein, Garn) · Gerede aller Bewohner zur Lage · Seite „Markt“ im Kassenbuch · Lorenz' vorausbezahlte Pacht (§1.6) · Jakobs freier Samstagvormittag · Hanne-Zeile · Brenneisen-Zeile bei Agathe (`case_end_deal`: „Ein Herr aus der Stadt hat nach Ihnen gefragt. Er zahlt gut, sagt man. Ich sag: Wer gut zahlt, will was Schlechtes.“) | **in dieser Reihenfolge von unten streichen** → §13, Benutzer wird informiert: Brenneisen-/Hanne-Zeilen → Jakobs Samstag → Lorenz' Pacht → Seite „Markt“ → Gerede der Bewohner → weitere Waren → Läden folgen der Lage → Kranz aufs Grab → Stiftungen → `curve10_harvest` → sichtbare Schau |
| **C** (gestrichen) | Kredit, Zinsen, Schulden über einen Monat, Pfändung · Feilschen-Minispiel · freie Preise · Großhandel, Lager, Spekulation · Markt in Ellbach / Stadtmarkt · Verschleiß, Unterhalt, höherer Lehrlingslohn (nicht gewählt) · Jahresabschluss als eigenes Fest · Brenneisen als dauernder Händler | §13 |
*Begründung:* Der **Tarif mit Zielkurve** ist der Kern des Benutzerauftrags (Punkt 1) und betrifft das ganze Spiel; ohne Messung über alle Phasen wäre „überall neu abgestimmt“ eine Behauptung. Die **Gemeindekasse** ersetzt die Pflegegeld-Klippe, trägt „nach Friedhofsqualität“, „Steuern, Pacht und Spenden“ und das Kassenbuch – und sie ist das Sicherheitsnetz für „kein Scheitern“; ohne sie gäbe es keine Monatsabrechnung und keinen Verwerten-Ausgleich. Der **Markt** ist das Spätspiel-Einkommen und die Spätspiel-Senke zugleich und die sichtbarste neue Welt; er braucht die einzige neue Figur, deshalb liegen seine Ausschmückungen (Gerede, weitere Waren, Läden nach Lage) in B. Die sichtbare Schau ist schön, aber teuer (Zeitpläne, Wege, Bilder), und die Kasse funktioniert ohne sie vollständig – deshalb steht sie in B, wird aber als Letztes gestrichen, weil sie die Gemeinde auf dem Hügel sichtbar macht.

## 13. Nicht in Phase 10
- **Ausgaben & Verschleiß** (nicht gewählt): Werkzeugabnutzung, Reparaturen, Gebäudeunterhalt, Pacht für Gebäude, höherer oder steigender Lehrlingslohn
- **Angeln, der Mühlteich, neue Orte, neue Grabstellen** (Phase 11); Ellbach als Ort, ein Stadtmarkt, Kutschfahrten mit dem Spieler
- Kredit, Zinsen, Schulden über einen Monat hinaus, Pfändung, Gefängnis, Bankrott; Spieler als Geldverleiher
- Feilschen als Minispiel, frei gesetzte Preise, Preisdiagramme, Börse, Spekulation mit Lagerware, Händlerstufen, eigener Laden im Dorf
- Neue Feste und Feiertags-Mechaniken (Weihnachten, Neujahr, Lichtmess bleiben Kalendertage mit einzelnen Zeilen), Sonntagsruhe als Regel, Wetter, Schnee
- Brenneisen als dauernder Händler, Präparate auf dem Markt, Leichenhandel; Ilse auf dem Markt
- Neue Gebäude, neue Innenräume, neue Abschnitte; ein Marktgebäude oder eine Markthalle
- Die Auflösung des Geheimnisses (Phase 12–18); Lorenz' Pacht bleibt ein Haken
- Ein zweiter Lehrling, Arbeiter, untote Hilfe (Phase 14)
- Änderungen am Maler-Shader, an den Atmosphären-Presets, an `lib_faces.py`, am Rig, an `StoneCalendar`, an freigegebenen Abschnitten, Gebäuden und Räumen (außer §4.5); an Zeit-, Mengen- und Beziehungswerten früherer Phasen

## 14. Offene Fragen an den Benutzer (Entscheidung vor W0)
1. **Rhythmus der Gemeindekasse** (§2.5)
   - (a) **wöchentlich Friedhofsgeld** (Schau am Sonntag, Osric bringt es am Montag) und **monatlich die Abrechnung** mit Pacht, Zehnt und Schätzung am Monatsersten.
   - (b) alles monatlich: Friedhofsgeld und Abgaben einmal im Monat in einer Abrechnung (ruhiger, aber früh lange ohne Gemeinde-Geld).
   - (c) Friedhofsgeld weiter täglich (wie das Pflegegeld, aber nach Friedhofsqualität), Abrechnung monatlich.
   - **Vorschlag: (a)** – eine Woche ist kurz genug für „ich sehe, was meine Pflege bringt“, ein Monat lang genug für eine echte Abrechnung.
2. **Wann kommt die erste Monatsabrechnung – und wie lang ist der Bogen?** (§1.2, §1.4)
   - (a) **am nächsten echten Monatsersten** nach der Bucheröffnung: Bogen A **17 Tage** (16. Julmond bis 1. Hartung 1835), mit zwei Märkten und Neujahr als Abrechnungstag.
   - (b) Fenner macht für alte Spielstände eine **Eröffnungsabrechnung** am ersten Sonntag über die letzten 30 Tage: Bogen 12 Tage wie Phase 9, die erste Abrechnung kommt nach 5 Tagen.
   - (c) ein **Kassenmonat von 28 Tagen** ab Bucheröffnung, unabhängig vom Kalender.
   - **Vorschlag: (a)** – Kalendermonate passen zu den Grabinschriften und zum Jahr 1834/35; die Länge ist der Preis einer echten Abrechnung.
3. **Wie schützt die Gemeinde vor Geldnot?** (§2.5.2, §2.5.3)
   - (a) **Bedarfszulage gleitend** (unter 60 Münzen bis +15 je Woche) + **Notgroschen** (Auffüllen auf 10) + Aufschub und Erlass der Abgaben.
   - (b) nur Notgroschen und Aufschub – das frühe Spiel wird deutlich knapper (Tag 14 ≈ 25–35 statt 30–60).
   - (c) die bisherige Kappe bei 80 behalten (kein Friedhofsgeld über 80 Münzen) und nur Notgroschen dazu.
   - **Vorschlag: (a)** – „Pflegegeld nach Bedarf“ aus G8 ohne Klippe; wer wenig hat, bekommt mehr, wer viel hat, bekommt nur, was der Friedhof wert ist.
4. **Wie hoch sind die Abgaben – und wird der Steinbruchbrief zur Pacht?** (§2.4.2 A1/A7–A9, §2.5.5–2.5.6)
   - (a) **Pacht 8 je Monat** (Bruch und Werkhof; der Steinbruchbrief kostet dafür nichts mehr), **Zehnt 10 %** der belegten Einnahmen (≤ 25), **Schätzung 10 %** auf „ohne Beleg“ über 20 (≤ 15).
   - (b) Steinbruchbrief bleibt (20 einmalig), dazu Pacht 8 und Zehnt 10 %, ohne Schätzung – einfacher, aber Verwerten bleibt so reich wie heute.
   - (c) nur Zehnt 15 % (≤ 35), keine Pacht, keine Schätzung – eine Zahl statt drei, trifft aber auch den würdevollen Spieler stärker.
   - **Vorschlag: (a)** – drei kleine, verständliche Posten; die Schätzung ist der verlangte Münzausgleich für Verwerten (G5/G8), ohne es zu verbieten.
5. **Markt: Tag, Stände, neue Figur** (§2.7.2, §2.7.4, §8.1)
   - (a) **Samstag 08:00–12:30**; drei Stände: **Agathe Wendel** (neue Marktfahrerin aus Ellbach mit Stadtware), **Hof Kehr** und **Hof Brandt** (die Trauernden aus Phase 8 als Bauern), dazu der eigene Stand.
   - (b) nur Dorfbewohner an Ständen (Theres, Esch, Liesel), keine neue Figur – billiger, aber die Läden wären samstags zu und das „Neue“ fehlt.
   - (c) zwei neue Händler (Ellbach und ein Wanderhändler mit Rosen und Messing) – mehr Abwechslung, ≈ 40 % mehr P6-Arbeit.
   - **Vorschlag: (a)** – eine neue Figur wie Brenneisen in Phase 9; die Trauernden als Händler und Kundschaft verbinden den Markt mit ihren Gräbern.
6. **Was verkauft der Totengräber – und was kann er Bleibendes kaufen?** (§2.7.5, §2.8)
   - (a) **vier Waren** (Holzkreuz, Kräuter/Kräuterbündel, Grabkerze, Wachskranz) mit **zwei neuen Rezepten** (Kerzen ziehen, Kranz binden), drei Preisschilder; neu am Markt **Rosenstock** (dauerhafte Grabblumen) und **Messinglaterne** (Zier).
   - (b) wie (a), dazu alles Handwerk (Grabvase, Grablaterne, Totenhemd, Holunderwein, Garn) schon in A – mehr Auswahl, aber schwerer abzustimmen.
   - (c) nur die vier Waren ohne neue Rezepte (Kerzen und Kränze vorher kaufen) und ohne neue Güter – der Markt bringt dann fast nur Holzkreuze und Kräuter.
   - **Vorschlag: (a)** – genau die genannten Beispiele, eigene Herstellung lohnt, und „Rosen für alle Gräber“ ist die lange, schöne Senke fürs Spätspiel.
7. **Wie weit darf sich das alte Spiel verschieben?** (§2.4.3, §5.2, §10.3)
   - (a) **Tarif ab Tag 1 in jedem Spiel**; die alten Bots bekommen neue Münz-Bänder, ihre Kapiteltage dürfen sich höchstens **±2 Tage** verschieben; alte Spielstände behalten ihren Beutel, der neue Tarif gilt ab dem Laden.
   - (b) die alten Phasen bleiben **bitgleich**: der neue Tarif gilt erst ab `p10_open` (Spätspiel) – sicherer, aber die frühen Befunde (Bitten-Überschuss Tag 14, Verwerten in Phase 4–6) blieben ungelöst.
   - (c) Tarif ab Tag 1 und alte Spielstände werden beim Laden angeglichen (Fenner verbucht alles über 100 Münzen als „Rücklage der Gemeinde“) – trifft den Spieler, der gespart hat.
   - **Vorschlag: (a)** – das ist „alle Einnahmen und Ausgaben neu abgestimmt“; die ±2 Tage halten die freigegebenen Kapitel stabil.

---

### §14 Benutzerentscheidungen (bindend, 24.10.2026)
1. **Rhythmus:** wöchentliches Friedhofsgeld (Schau sonntags, Osric bringt es montags) + monatliche Abrechnung am Monatsersten (a).
2. **Erste Abrechnung:** am nächsten echten Monatsersten (1. Hartung 1835); Bogen A 17 Tage (a).
3. **Schutz vor Geldnot:** gleitende Bedarfszulage unter 60 (bis +15/Woche) + Notgroschen (auf 10) + Aufschub/Erlass; keine Klippe bei 80 (a).
4. **Abgaben:** Pacht 8/Monat (Steinbruchbrief kostenlos), Zehnt 10 % (≤ 25), Schätzung 10 % auf „ohne Beleg“ (≤ 15) (a).
5. **Markt:** Samstag 08:00–12:30; Agathe Wendel (neu) + Hof Kehr + Hof Brandt + eigener Stand (a).
6. **Waren:** Holzkreuz, Kräuter/Kräuterbündel, Grabkerze, Wachskranz; Rezepte Kerzen ziehen, Kranz binden; neu kaufbar Rosenstock und Messinglaterne; drei Preisschilder (a).
7. **Altes Spiel:** Tarif ab Tag 1 in jedem Spiel; alte Bots neue Münz-Bänder, Kapiteltage höchstens ±2; alte Stände behalten ihren Beutel (a).

---

## W0-Notizen (Lead, Welle 0 – verbindlich für W1)
1. **v8-Fixtures** `tests/fixtures/saves_v8/*.json`:
   - **Wann und worauf:** erzeugt **vor** jeder Phase-10-Code-Änderung, auf dem unveränderten Referenzstand. Code = **6f0bd9c** (G9). Branch-Stand f024103 enthält dazu nur den Vertrag.
   - **Wie:** über `Phase9Bot` / `Phase7Bot` / `Phase5Bot` und die echten Systeme. Werkzeug: `make_v8_saves.gd` + `_driver.gd` (historisch), Aufruf `-- --out=/abs/dir [--only=kindly,trader,stay,founder,village,new]`. Auf einem Phase-10-Stand schriebe es v9.
   - **Commit:** eigener Commit **07ea6c4**, zusammen mit `tests/fixtures/phase10/{layout_p9,village_layout_p9}.json`. Diese sind bytegleich zu `data/world/{graveyard,village}_layout.json` von f024103 (sha256 `26ad61d7bbbc…` / `191fb90f965e…`).
   - **Endstände:** Sie setzen die v7-Fixtures mit denselben Bot-Tagen fort wie `test_phase9_playthrough.gd` (12 Tage; `founder9` bis zum Kapitel), danach 07:00 des nächsten Morgens.
   - **Messwerte** (sha256-Präfix; Münzen = Beutel + Lohndose Jakobs; die Truhen sind in allen Ständen leer):
   - *day75_kindly* (`kindly9`, 12 Tage ab `slot_p8_day63_kindly`, **07:00 Tag 75 = Di, 16. Julmond 1834**, `75c41101094d`):
     - Kapitel `who_knows_when` an **Tag 69** (B7), `p9_open_day 63`; Ende A (`q_end_away`, `sieber_gone`), Brenneisen-Ende Fenner
     - Ruf 100, Pietät 100; **129 Münzen** (120 + 9; §1.4 rechnet mit ≈ 132)
     - **Abweichung: 40 Gräber `MARKED`, 0 frei – Reihe 4 ist voll.** Johann ist fort, die für D3 gehaltene Stelle hat eine Lieferung bekommen. §1.4 B3 „Lieferung auf die letzte freie Stelle“ gibt es daher nicht; im Bogen A ist kein Grab mehr frei (wie `stay`).
   - *day75_trader* (`trader9`, 12 Tage ab `slot_p8_day63_anatomist`, `7ad1b6d8b207`):
     - der v7-Start ist Tag 64, deshalb **07:00 Tag 76** (Mi); Dateiname nach Vertrag beibehalten
     - Kapitel an Tag 72 (B9), `p9_open_day 64`, Ende A, `anatomy_known`
     - Ruf 99, Pietät −60; **120 Münzen** (108 + 12); 0 frei
   - *day75_stay* (`stay9`, 12 Tage ab `slot_p8_day63_kindly`, **07:00 Tag 75**, `032af3756b18`):
     - Kapitel an Tag 74, Ende B (`q_end_stay`, `sieber_dead 72`), D3 in Reihe 4
     - **133 Münzen** (124 + 9); 0 frei
   - *founder* (`founder9` ab `slot_p8_founder` bis zum Kapitel, `d6c8a498a564`):
     - Kapitel an **Tag 67**, gespeichert **07:00 Tag 68** (Di); `p9_open_day 61`, alle sechs Kapitel
     - Ende A, **129 Münzen** (120 + 9); 0 frei
   - *day38_village* (`d2a4cacc32de`):
     - Aufbau: `slot_p6_day37_founder` (v5, Dorf ab Tag 37) + ein `founder7`-Tag (wie Phase 9 `day30_village_hill`), **07:00 Tag 38** (So)
     - `village_open_day 37`, kein `p8_open`, kein Kapitel 9; 31 Münzen; Reihe 4 `LOCKED`
   - *day29_new* (`b80b8bbf26a1`):
     - Aufbau: neues Spiel, **`Phase5Bot crafter`**, 28 Tage, dann Tag 29 bis zum Schlafengehen; er wartet in der Hütte statt im Bett.
     - **Abweichungen:**
       - Uhrzeit **23:05** statt 23:00 – der Abend des Bots läuft bis 23:05.
       - Bot `crafter` statt der Gründer-Bots: `Phase6Bot founder` erreicht auf dem G9-Code `roof_and_earth` – und damit `village_open` – schon vor Tag 29 (Ist-Kurve: Tag 27). §5.3 will an Tag 30 aber nur die Pacht.
     - Zustand: `names_in_stone_complete`, `bruch_license`, kein `village_open`, 43 Münzen.
   - *mid_h4* (vorhanden, W3 Phase 9, `a16bea540edf`): Tag 66 14:30, Phase 9 offen, H4.
   - **Bitgleichheit der alten Bots in W0 geprüft:** `make_v8_saves --only=kindly,new` auf dem fertigen W0-Stand liefert dekodiert denselben Zustand wie die Fixtures. Unterschiede: nur `format_version` 9 und die 23 neuen Stats = 0 (Vergleich ohne diese: 0 Unterschiede).
   - Lade-Wächter `tests/integration/test_saves_v8_load.gd`: alle 7 laden ohne Warnung, Zustand und Münzen bleiben erhalten, Phase-10-Stats sind 0, Neuspeichern ergibt v9, der Roundtrip ist identisch.
2. **Speicherformat v9 schon in W0** (wie W0 Phase 9):
   - `SaveMigration.CURRENT = 9`; `SaveFileIO`/`SaveManager.FORMAT_VERSION` folgen. Kette 1→…→9, `read_doc` nimmt 1…9, Version 10 wird abgelehnt.
   - `migrate_8_to_9(state, meta)` ist die vollständige §5.2-Migration auf einer tiefen Kopie (rein, idempotent):
     - `V9_EMPTY_NODES = ["treasury", "cash_book", "market"]` als `{}`. `SaveManager.without_absent_defaults` kennt V9 und verwirft sie, solange die Welt die Knoten nicht hat.
     - `V9_NEW_STATS` (23, §2.10) = 0
     - keine Flags; Münzen, Inventare, Truhen, Lohndose und alles andere bleiben unverändert (§5.2 Schritt 3, §14.7)
   - **Ebenfalls schon in W0:** `GameState.DEFAULT_STATS` + 23 Stats (angehängt) und `COIN_REASONS` + `&"market"`, `&"rent"`, `&"tax"`, `&"stall"`.
   - P5 besitzt die Dateien weiter und darf glätten. `book_start` (Ladetag) setzen P2/P3 im ersten `load_state` mit leerem Knoten – nicht die Migration.
3. **Kalender** `CalendarRules` (`src/systems/time/calendar_rules.gd`, Lead, vollständig), über `StoneCalendar.date_of` (unverändert):
   - Wochentag = (Tag − 1 + 4) mod 7 (0 = Montag)
   - `week_of(day) = ⌊(day + 3) / 7⌋`: Tag 1–3 = Woche 0, Tag 4 = Woche 1, Tag 80 = Woche 11
   - `month_key` „YYYY-MM“; Tage < 1 zählen wie bei `StoneCalendar` als Tag 1
   - `first_day_of_month` kann ≤ 0 sein (1. Gilbhart 1834 = Tag −1); fehlerhafte Schlüssel → 0 bzw. ""
   - Zusätze: `WEEKDAY_SHORT`, `MONDAY`/`SATURDAY`/`SUNDAY`
   - Geprüft in `test_calendar_rules.gd`: Monatserste 30/60/91/122/150, Tag 75 Di, 84 Do (Weihnachten), 91 Do.
4. **Datenklassen ✦ vollständig** (§3.2.1): `TreasuryConfig`, `CashBookConfig`, `MarketConfig`, `MarketStallData`, `MarketOfferData`, `MarketWareData`, `WishlistData`, `WishlistEntryData`.
   - Felder und Defaults exakt nach §3.4.
   - Rein additiv: `WishlistEntryData.KINDS`.
5. **Erweiterungen bestehender Configs – Klassen-Default und `data/config/*.tres` gemeinsam:**
   - `ReputationConfig.event_points` + `dues_paid 1`, `estimated −1` (kein `market_stall`)
   - `PietyConfig.events` + `poor_box_give 1`, `rose_planted 1`
   - `RelationshipConfig.gains` + `dues_paid_fenner 2`, `market_buy 1`, `market_sale_kin 1`
   - `NpcLifeConfig.reactions` + `market_lage 1`
   - `VisitorConfig` + `poor_box_coin 1`, `poor_box_cap_day 2`
   - Die Phase-10-Fixtures dieser Configs sind der W0-Stand (`Phase10Fixtures.EXTENDED_CONFIG_NAMES`).
   - `test_phase9_scaffold.gd` führt `event_points`, `events`, `gains`, `reactions` jetzt in `DATA_CHANGED_AFTER_W0`; `test_piety`/`test_reputation` vergleichen mit der Phase-10-Fixture.
   - **Nicht in W0 (Tarif = W1, P1/P2):** Pflegegeld `stipend` bleibt 0/1/2/3/4 mit Kappe 80 (E1 → 0 mit `reputation.gd`, P2), `tip_cap_day` bleibt 4 (E11), alle Münzwerte bleiben, `DecorData` ohne neue Felder.
6. **Neue Config-Dateien:** `data/config/{treasury_config (→ P2), cash_book_config (→ P3), market_config (→ P4)}.tres` = Klassen-Default, ausdrücklich geschrieben; Kopien in `tests/fixtures/phase10/*_fixture.tres`.
   - **Ausnahme wie die Fragen Brenneisens in Phase 9:** Die Klassen-Defaults bleiben `{}` / `[]` wie in §3.4. Die `.tres` tragen die Vertragstabellen (`Phase10Fixtures.DATA_TABLES`):
     - `CashBookConfig.sources` (19 Quellen, §2.6) und `purpose_labels` (alle 17 `COIN_REASONS`)
     - `MarketConfig.groups` (§2.7.3), `season_rules` (Frost Julmond/Hartung/Hornung → `wood_iron` +1), `rep_demand` (`disreputable` 0,7, `renowned` 1,1), `piety_demand` (`hardhearted` 0,7, `devout` 1,1)
   - Weicht ein Besitzer ab, setzt er Default und `.tres` gemeinsam und trägt die Eigenschaft in `DATA_CHANGED_AFTER_W0` (`test_phase10_scaffold.gd`) ein – die Fixture bleibt.
7. **Nicht** in W0 angelegt (Besitzer, W1):
   - `data/market/**`, `data/items/{rose_bush,brass_lantern}.tres`, `data/recipes/{grave_candle_poured,wax_wreath_bound}.tres`, `data/decor/brass_lantern.tres` (P4)
   - `data/economy/wishlist.tres`, `tools/economy/tariff_report.py` (P1)
   - Dialoge, Zeitpläne, Hinweise (P5); Texte der Abrechnung/des Opferstocks (P2)
   - Die Fixtures sind **vollständige Vorlagen** (kopieren erlaubt). Neue Items und Rezepte ändern Zählungen fremder Tests (`test_inventory.ITEMS` u. a.) – P4 passt sie an (Lead-genehmigt).
8. **Stubs** (`## STUB (P<n>)`, Signaturen exakt nach §3.4; die Liste `IMPLEMENTED` in `tests/unit/test_phase10_scaffold.gd` füllen die Besitzer). **Fett = antwortet schon aus `load_state` (Format §5.1)**, damit W1-Tests fremder Pakete Zustände setzen können (`Phase10Fixtures`):
   - **P1:** `WishlistProbe.open_cost` (0).
   - **P2:**
     - `Treasury` (85): **`is_open()`/`open_day()` lesen `p10_open`/`p10_open_day`**; **`last_schau`/`pending_pay`/`settlement`/`open_settlement`/`due_day`** (= Tag der Abrechnung + `due_days`) und **`poor_box_coins`** (auf 0…30 geklemmt) aus `{schau, settlements, poor_box}`; `goal_progress` = `{settled false, market_days 0, best_tier &""}`.
     - Konstanten `STATE_*`/`STATES`/`VIA`; dazu `TreasuryRules`.
     - `OfferingBox` (+ `.tscn` mit `Interactable`, `box_id poor_box_gate`, Auswahl-Konstanten, `request_action`).
   - **P3:**
     - `CashBook` (86): **`open_day`/`day_page`/`month_page`/`untracked_in`** aus `{open_day, days, months}`.
     - **`booked_income(month, receipt_only)`** liest das `receipt`-Feld in W0 direkt aus `CashBookConfig.sources`, damit P2 vor P3 rechnen kann.
     - `CashBookRules` (`OTHER`, `UNTRACKED`).
   - **P4:**
     - `Market` (87): **`stall_granted`** (gespeichertes `granted` oder Flag `market_stall_granted`), **`stall_goods`/`sold_on`** aus `{granted, stall, sold}`.
     - Konstanten `KINDS`/`TAGS`/`STATES`/`OWN_STALL`; dazu `MarketRules`.
     - `MarketStall` (+ `.tscn`, `stall_id`, Prompt-/Auswahl-Konstanten, `request_action`, `is_own`).
   - P5, P6, W-Welt, W-UI: keine Stubs. Die Systemknoten hängen in W0 **nicht** in der Welt (W-Welt, wie Phase 4–9).
   - **Abweichung zur Hauskonvention:** `OfferingBox`/`MarketStall` erben laut §3.4 von **`StaticBody3D`** (alle anderen Entitäten von `Node3D`). In W0 haben sie `collision_layer 0` und keine Körperform – Besitzer/W-Welt entscheiden, ob der Stand ein Hindernis ist (Flood-Fill §4.2).
9. **EventBus:** die 6 Signale aus §3.3 (Block „Phase 10“). **Eingaben:** keine neuen. **Database** (§3.5):
   - `market_stall/market_stalls` (`data/market/stalls`, nach id)
   - `market_ware/market_wares` (`data/market/wares`, Schlüssel `item`, nach item)
   - `wishlist()` (`data/economy/wishlist.tres`, `null`, solange P1 sie nicht schreibt)
   - leer/fehlend = leere Liste
10. **Fixtures für W1:** `tests/fixtures/phase10/`, erzeugt von `make_phase10_fixtures.gd` (+ `_driver.gd`, historisch).
    - **Inhalt:**
      - Configs (Punkt 5/6)
      - `market/stalls/{ms_agathe (5 aus 12), ms_kehr (4 aus 7), ms_brandt (4 aus 6)}`, `market/wares/` (die fünf A-Waren mit den Kundenzeilen aus §2.12)
      - `items/{rose_bush (MATERIAL, 4), brass_lantern (DECOR, 4)}`, `recipes/{grave_candle_poured, wax_wreath_bound}` (Werkbank, `requires_flag village_open`)
      - `decor/brass_lantern` (Kopie von `decor_lantern`, Zier +1, Modell vorerst das der Grablaterne)
      - `economy/wishlist.tres` (Muster mit 8 Einträgen)
    - **Zugriff `Phase10Fixtures`:**
      - `p10_open(tree, day)` → `Treasury`; setzt alle Kapitel-Flags bis `who_knows_when_complete`, `p10_open`, `p10_open_day`
      - `market_day(tree)` → `Market`; setzt `village_open` und `market_stall_granted`, stellt die Uhr auf den nächsten Samstag 08:00
      - `stall_with(goods, tags, ticks)`
      - `schau_done(week, tier)`; die Schau liegt auf dem Sonntag `schau_day(week) = 7w + 3`
      - `settlement_due(month)` / `deferred(month)` (Beispiel §5.1: 5 + 8 = 13)
      - `poor_box(n)`
      - `cash_day(day, in, out)` → `CashBook`
      - `install_save_v8`, `save_v8_path`, `layout_p9()`, `village_layout_p9()`, ID-Listen, `SAVEABLES`
11. **Lücken, pragmatisch entschieden** (Besitzer dürfen in ihrem Paket glätten und melden es):
    - **„Belegt“ ≠ „ohne Beleg“ (§2.5.6/§2.6):** `receipt = false` steht sowohl für nicht abgabepflichtige Quellen (Friedhofsgeld, Bedarf, Trinkgeld, Spenden, Geistergaben) als auch für die Quellen, die für die Schätzung als „ohne Beleg“ zählen (`specimen`, `lecture`, `collection`, `night`, `stranger`). W0 gibt jeder Quelle zusätzlich **`estimate: bool`** (das Dictionary ist untypisiert – keine Signaturänderung). `other`: `receipt false`, `estimate false`.
    - **Präfixe = die echten Grundtexte des G9-Codes** (geprüft in `test_phase10_scaffold::test_cash_book_sources_cover_the_reason_texts`, jeder Text → genau eine Quelle):
      - Aussegnung „Die Familie legt …“, Geistergaben „Der Geist deutet …“
      - Bitten auch „Bitte zur Hälfte: “, Läden auch „Verkauf an Hanne“ (Hanne/Wanderers)
      - das alte „Pflegegeld der Gemeinde“ → `parish`
      - Ilse kommt über `trader_trade` (`night`); Wertsachen und Lohndose haben keine Buchung → „ohne Beleg“
      - **Offen für P3/P5:** Brenneisens Trinkgeld für den Koffer bucht unter „Botenlohn“ (`Stranger.REASON_TIP`) und damit als `errand` (belegt).
      - Neue Grundtexte (§2.10): „Friedhofsgeld“, „Bedarfszulage der Gemeinde“, „Notgroschen der Gemeinde“, „Spenden aus dem Opferstock“, „Verkauf am Marktstand“.
    - **Item-Ids der Warengruppen und Stände (§2.7.3/§2.7.4):**
      - Zuordnung: Totenhemd = `burial_gown`, Stahl = `steel_rod`, Eisenbeschläge = `iron_fittings`, Setzlinge = `flower_seedlings`, Samen = `seeds`, Branntwein = `spirits`, Grabvase = `decor_grave_vase`, Strohblumen = `straw_bouquet`, kleines Präparatglas = `prep_jar_small`, gebrauchtes Grabgitter = `mortsafe` (`requires_flag robber_known`), Kerzenstummel = `grave_candle`, feine Leinwand = `linen`
      - Blattgold ohne Bedingung („ohne Befreundet“ gelesen als: keine Freundschaft nötig – P4 entscheidet)
      - `iron_bar` (Eisenbarren bei Agathe) steht in keiner Gruppe (→ „normal“; P4 entscheidet)
      - `piety_demand.hardhearted` gilt laut §2.7.5 nur für `grave_goods` – das kann die Tabelle nicht ausdrücken, P4 setzt es in `MarketRules.demand` um
    - **Stände:**
      - `place` = die Stand-Id (Layout-Id der `MarketStall`); `npc_id` `marketwoman`, `kin_kehr`, `kin_brandt`
      - `buys_groups`: Agathe `candles` + `grave_goods`, Kehr `herbs`, Brandt `grave_goods`
    - **Lesart der Market-Getter:** `Market.is_open()` = Markt jetzt offen (Markttag im Fenster), `market_day()` = heutiger Markttag oder −1, `next_market()` = ≥ heute oder −1.
    - Texte der Stubs, Item-Beschreibungen und Rezeptnamen außerhalb der Leittexte sind W0-Entwürfe.
12. **Ist-Messung des alten Tarifs** (§12.1): `docs/reviews/phase10_wip/ist_kurve.md`, Werkzeug `tests/integration/economy_curve_bot.gd` (`EconomyCurveBot`, P1 übernimmt in W1) + `tools/economy/ist_kurve.gd`.
    - **Kette:** `Phase6Bot founder` → `founder7` → `founder8` → `founder9`; Übergabe am Morgen nach dem Kapitel mit Speichern/Laden wie bei den Fixtures.
    - **Ergebnis (Polster morgens):** Tag 14 = 35, 30 = 20, 45 = 78, 60 = 21, 75 = 12, 91 = 9. Ausgabequote 85–125 % je Abschnitt, morgens min. 1 (Tag 87).
    - **Befund 1:** Die Gründer-Linie ist auf dem G9-Code schneller (Dorf ab Tag 28, `name_in_village` Tag 38).
    - **Befund 2 (offen, P1 vor `curve10`):** `founder8` nimmt in dieser Kette **keinen Freundschaftsschritt**, obwohl jeder nehmbar ist. Deshalb fehlt das Kapitel 8 (und damit 9) bis Tag 91. Auf der Fixture-Linie klappt es; mit und ohne Laden an der Übergabe gleich.
13. **Hinweise je Paket (W1):**
    - **P1:**
      - Tarif in die Daten (E1 Pflegegeld → 0 zusammen mit P2s `reputation.gd`, E11 `tip_cap_day` 3 usw.).
      - `EconomyCurveBot` ist dein Gerüst: `founder10`, Wunschliste, Prüfpunkte und Bänder (§2.3) ergänzen. Befund 12/2 zuerst klären.
      - Die alten Bots sind in W0 bitgleich (Punkt 1); ihre Münzbänder setzt du nach deiner Messung neu (§10.3).
      - `kindly10` startet mit **129** und ohne freies Grab.
    - **P2:**
      - `Treasury.post_load`: v8-Stände mit `who_knows_when_complete` öffnen sofort (`p10_open_day` = Ladetag: kindly/stay 75, trader 76, founder 68).
      - Pacht ab `bruch_license` (in allen Fixtures gesetzt, auch `day29_new`), Zehnt/Schätzung ab `village_open` (`day29_new` hat es nicht → am Tag 30 nur Pacht).
      - Pflegegeld aus (`reputation.gd`), Einwurf in den Opferstock aus `visitors.gd` (`VisitorConfig.poor_box_*`).
      - Szene `offering_box.tscn` ist da.
    - **P3:**
      - Quellen-Tabelle und `estimate`-Schlüssel (Punkt 11), `REASON_TIP`-Frage mit P5.
      - `booked_income` darf über `CashBookRules.is_receipt` laufen.
      - Merkbuch-Seitentitel.
    - **P4:**
      - Items, Rezepte, Dekor, Stände und Waren aus den Fixtures nach `data/`; Zählungen fremder Tests anpassen.
      - Gruppen-Lücken (Punkt 11), `MarketStall` als `StaticBody3D`.
    - **P5:**
      - `migrate_8_to_9` ist fertig (`test_save_migration.gd`: `test_v8_fixtures_migrate_to_v9`, `…_tolerant`, `test_read_doc_migrates_every_v8_fixture`, `test_v7_fixtures_chain_to_v9`, `test_v9_round_trip_is_identical`, `test_version_ten_is_rejected`, `test_absent_phase10_nodes_are_dropped_only_when_empty`).
      - `test_game_state.gd` hat die 23 Stats und die 4 Zwecke (Lead, mechanisch).
    - **P6:** keine W0-Vorgaben über §8 hinaus (Agathe zuerst, §12.2).
    - **W-UI (W2):** `Phase5Texts.SPENT_LABELS` kennt `post` noch nicht, ebenso wenig `market`/`rent`/`tax`/`stall` (Tageszusammenfassung) – die Labels stehen in `cash_book_config.tres` `purpose_labels`.
14. **Lead-Anpassungen an fremden Tests** (mechanisch, nur Version / Fixture-Stand / Listen):
    - `test_phase3…9_scaffold.gd` (v9; Phase 5 + V9-Knoten in der Kette; Phase 9: `DATA_CHANGED_AFTER_W0`, `post` nach `peddler`, `migrate(state, 8)` = 8 → 9)
    - `test_save_migration.gd` (v9; Ketten 5/6/7 → 9; „Version 9 abgelehnt“ heißt jetzt `CURRENT + 1`; neu siehe P5)
    - `test_saves_v4/v5/v6_load.gd`, `test_hill_requests.gd`
    - `test_save_fuzzer.gd` (aktuelles Format; **neu** `test_fuzz_v8_fixtures`, `test_fuzz_v9_phase10_parts`; Konsistenz: Phase-10-Stats ganzzahlig)
    - `test_game_state.gd`, `test_piety.gd`/`test_reputation.gd` (Daten = Phase-10-Fixture)
15. **Testzahl:** vor W0 3 394, nach W0 **3 441**, alle grün. Neu: `test_phase10_scaffold.gd` 19, `test_calendar_rules.gd` 8, `test_saves_v8_load.gd` 9, `test_save_migration.gd` + 7, `test_save_fuzzer.gd` + 2, `test_game_state.gd` + 2. Die Münzbuch-Erwartungen in `test_game_state.gd`/`test_dialogue.gd` kennen die vier neuen Zwecke (= 0).

## W1-Anschlüsse (Lead, 25.10.2026)
1. **P1 gemergt** (Tarif ohne E1/A1, Tarifblatt, Wunschliste, `curve10`, Neu-Bänder). Details: `docs/reviews/phase10_wip/balance.md`.
2. **Band anatomist7** Präparate ≥ 9 → **≥ 7** genehmigt (Münzfolge von E14/A3, §10.3).
3. **E12 „Abgebrüht“** bleibt in `piety_config.buyer_bonus_by_tier` (+1 je Stück).
4. **E1 (Pflegegeld → 0)** mergt P2 mit dem Patch aus `balance.md` §6. Gegen den Ausfall von `mender6` (Kapitel 6) und den Tiefstand von reverent6: erste Friedhofsgeld-Woche **nicht anteilig**, Notgroschen auch montags prüfen; reicht das nicht, hebt P2 die Bedarfsschwelle und meldet es. §14.7 (Kapiteltage ±2) bleibt hart.
5. **A1 (Pachtbrief 0)** setzt P5 um (`carter.tres`, `test_dialogue`).
6. **Freundschafts-Fehler** (founder8, `balance.md` §4): P5 bindet die Gegengefallen-Wahlen an `favor_owed:<npc>` und lässt `Friendship.step_block_reason` das Limit `max_active_friend` prüfen (Einzelfunktion im Phase-8-System freigegeben).
7. **Wunschliste:** P4 benennt die Abfrage `GraveCare.has_rose(grave_id)`. Prüfpunkt Tag 14 (0,6×, nichts Bleibendes vor dem Werkhof) wird als Ausnahme akzeptiert; das Band gilt ab Tag 30.
8. **Nachmessung** von `curve10` (früh zu knapp, spät zu reich) erst nach P2- und P4-Merge, strikt in W3.
