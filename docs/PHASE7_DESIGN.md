# Phase 7 – Dorf – Vertrag v1

Status: **v1 – Entwurf zur Benutzerfreigabe (Vertragsfragen §14 offen), danach verbindlich für die Umsetzung** · Verantwortlich: Agent 01 (Lead), Agent 02 (Game Design), Agent 03 (World Design), Agent 05 (Blender/Gebäude), Agent 06 (Character Art), Agent 08 (Godot Core), Agent 11 (Corpse System), Agent 12 (NPC/AI), Agent 13 (Quest/Story), Agent 14 (Crafting/Economy)
Baut auf `docs/PHASE6_DESIGN.md` (Vertrag v1, freigegeben 03.10.2026), `docs/PHASE5_DESIGN.md`, `docs/PHASE4_DESIGN.md`, `docs/PHASE3_DESIGN.md` und `docs/VERTICAL_SLICE_DESIGN.md` auf. Was dieses Dokument nicht ändert, gilt dort unverändert weiter. Referenz-Build: **705bd5a** (Gate G6 freigegeben, 2 017 Tests).
Gameplay-Werte sind **Vorschläge**; der Benutzer prüft sie beim Gate G7. ART STYLE LOCK „Gemaltes Diorama" ist aktiv: Phase 7 ändert den Stil nicht. Maler-Shader (`painted.gdshader`, `painted_common.gdshaderinc`, `painted_foliage.gdshader`) und die Atmosphären-Presets bleiben unverändert; das Dorf benutzt **dieselbe** Sonne, dieselbe `WorldEnvironment` und dieselben Presets wie der Friedhof. Die freigegebenen Abschnitte I–IV, Werkhof, Kirchhof und alle Phase-6-Gebäude bleiben bitgleich, **außer** den in §4.6 vollständig aufgezählten Eingriffen am Friedhof (Wegstein am Kutschweg, Lindenacker südlich der Ostwiese mit Pforte im Ostwiesen-Südzaun, zwei bzw. drei versetzte Waldbäume, Präparierpult-Platz in der Gruft).

**Benutzerentscheidungen (verbindlich, 03.10.2026)**
- **Inhalt, alle vier Teile:**
  1. **Begehbares Dorf Hollerbrück** am Kutschweg, erreichbar über den Weg vom Friedhofstor: Anger mit Brunnen, Häuser, Dorfeingang. Die Anbindung legt dieser Vertrag fest und begründet sie (§3.4, §4.1).
  2. **Dorfbewohner und Händler** (Wirtin, Schmied, Krämerin, Pfarrer, Schultheiß, Wundarzt/Anatom und weitere), jeder mit Tagesablauf, Laden (Kaufen/Verkaufen) und Dialog, auf dem bestehenden `Npc`-System. Der Pfarrer zeigt sich jetzt im Dorf; Tiefe und eigene Riten bekommt er in Phase 8.
  3. **Wundarzt/Anatom mit Organ-System** (Benutzerwunsch vom 03.10.2026, `docs/ROADMAP.md`): **angedeutet** (Tuch über der Leiche, Abblende, Organe nur als verschlossene Gläser oder Bündel im Inventar, **kein Blut, keine offenen Wunden**), am **Gruft-Tisch** als neue Kategorie mit derselben zweistufigen Bestätigung wie die Verwertung aus Phase 4. Zwecke: (a) Präparate an den Anatomen verkaufen (Münzen; kostet Pietät und Ruf; Geister „beraubt"), (b) Forschung (die wahre Todesursache → Merkbuch), (c) Handwerk an einer neuen Station, (d) Haken für die Auferstehung (Phase 13, nur Daten). **Erweitert durch die Benutzerentscheidung §14.3:** sieben Präparate (Herz, Lunge, Magen, Leber, Nieren, Augen, Hand/Knochen), dazu eine **Präparatesammlung** mit Sätzen, **Arzneien aus Präparaten**, Quasts heimliche **Anatomie-Vorlesung** bei Nacht und die **Todesursachen-Deutung** als kleines Verknüpfen-Spiel im Merkbuch.
  4. **Aufträge und Beziehungen:** kleine Aufträge der Dorfbewohner (liefern, würdig bestatten, einen Stein setzen) und **ein Beziehungswert je Person**. Vorstufe für Phase 8 (NPCs) und Phase 9 (Quests): erweiterbar, aber klein.
- **Umfang: groß.** 12–14 Spieltage auf dem Phase-6-Endstand, mit Kapitelziel (§1.5), in erreichbaren Wellen (W1 mit 7 Paketen, §12).
- **Einbindung:** Das Dorf wird Quelle für neue Tote (über neuen Grund, §2.9) und für Einnahmen und Ausgaben. Die Dorfbewohner reagieren auf Ruf-Stufe und Pietät. Osric wohnt im Dorf, Ilse bleibt die Nachtgestalt an der Westmauer und spricht über das Dorf. Das Geheimnis geht ein Stück weiter: Hinweise darauf, **wer die Sterbenden zeichnet**, ohne Auflösung. Der nächste Erzählschritt wird benannt (§1.6).

**Regeln für alle Agents** (wie Phase 3–6)
- Klassen, Signaturen, Dateipfade, Signale und Datenformate hier sind **fest**. Änderungen nur über den Lead.
- Der Lead legt in **Welle 0** alle Datenklassen (✦) vollständig und alle Logikklassen als **Stubs mit exakten Signaturen** an. Die Besitzer füllen die Körper und benennen nichts um.
- Nach jedem neuen Worktree und nach jedem Merge: `godot --headless --path . --import`.
- Jede Datei hat genau einen Besitzer (§3.2). Fremde Dateien nicht ändern; Bedarf an den Lead melden.
- Alle neuen Assets tragen `ph_` und kommen in die Placeholder-Liste (`docs/QUALITY_GATE_STATUS.md`).
- Keine Mechaniken, Namen oder Texte anderer Spiele übernehmen. Ausdrücklich **nicht**: Fleisch, Blut, Fett, Haut, Gehirn oder Schädel als Ressource; Schädel- oder Knochenpunkte (rot/weiß oder sonst farbig); Körperteil-Wertungen mit Sternen; Organe als Speise oder in Tränken mit Zauberwirkung; Arzneien aus Herz, Augen oder Hand; Beschreibungen der Herstellung einer Arznei; Leichen-Qualitätspunkte, die man „verbessern" kann; Freundschafts-Herzchen; Geschenk-Kalender; Hochzeiten; Tagesquest-Ketten mit Sofortbelohnung; Händler-Reputation als eigene Währung.
- Eigene Identität dieser Phase: **„Drei Meilen hinunter"**. Bisher kamen die Toten den Hügel herauf, und mit ihnen nur Osric. Jetzt geht der Totengräber hinunter zu den Lebenden. Sie kennen ihn nur von seinem Ruf, er kennt sie nur von ihren Toten. Beides ändert sich. Im Dorf hat jeder ein Gesicht und einen Namen, und wer ein Glas mit einem Namen auf dem Etikett verkauft, verkauft ihn an Leute, die diesen Namen kannten.
- Sprache: alle Spieltexte eigenständig auf Deutsch, trocken-melancholisch, im Dorf wärmer und geschwätziger als auf dem Hügel, bei der Anatomie still und sachlich. Kein Spott über die Toten, keine Frömmelei, keine Schauerprosa über das Innere der Leiber.

---

## 1. Spielablauf & Progression

### 1.1 Erweiterter Kern-Loop
```
Freischaltung (Kapitel „Unter Dach und Erde") → Osric p7_intro: „Der Schultheiß lässt fragen, ob du mal runterkommst."
  → WEGSTEIN am Kutschweg „[E] Nach Hollerbrück (30 Min)" → Abblende → Dorfeingang an der Holderbrücke
  → DORF: Anger, Brunnen, Linde mit Gemeindetafel · Leute mit Tagesablauf · Läden (kaufen/verkaufen)
       └ Reden (Beziehung +1 je Tag) · Geschenke · eine Runde im Holderkrug · Spende in die Armenkasse
       └ AUFTRÄGE: Gemeindetafel + persönliche Bitten → liefern · würdig bestatten · Stein setzen · Grab pflegen
  → Schultheiß: der LINDENACKER (8 Grabstellen südlich der Ostwiese) → roden → Pfarrer weiht ihn → Osric liefert wieder
  → Leiche → Gruft-Tisch: Untersuchen · Herrichten · Verwerten (Phase 4) · NEU „Präparate" (Herz, Lunge, Magen, Leber, Nieren, Augen, Hand – höchstens 3 je Leiche)
       └ Tuch, Abblende, 20–30 Min → Glas (Glas + Branntwein) oder Bündel (Leinen, verdirbt) mit Namen auf dem Etikett
       └ Wundarzt Quast: VERKAUFEN (Münzen) · GUTACHTEN (Lehrsatz) · nachts alle 3 Tage: ANATOMIE-VORLESUNG (Honorar, Lehrsatz, Gerede-Gefahr)
       └ PRÄPARIERPULT: begutachten (Befund-Karte) · Arznei ansetzen (Gegengift, Bittertropfen, Wassersuchtpulver) · Schau- und Knochenpräparat · SAMMLUNG (Sätze → Ansehen bei der Universität)
       └ MERKBUCH: TODESURSACHE DEUTEN (Befund + Lehrsatz + Ursache → „Deuten" → wahre Ursache, Hinweis)
       └ oder ins Grab ZURÜCKLEGEN („Präparat beisetzen": der Geist bekommt zurück, was ihm genommen wurde)
  → Grab im Lindenacker → bestatten → Stein → Qualität + Bezahlung · Bestatt-Aufträge erfüllt?
  → nachts: Geister (neue Zeilen „beraubt" / „zurückgelegt") · Ilse spricht über das Dorf
  → GEHEIMNIS: Wer besucht die Sterbenden? (Ilse · Liesel · Sterbebuch) → Erkenntnis „Vorher eingetragen"
```
Alle Handgriffe aus Phase 4–6 bleiben **unverändert**. Die Präparate sind eine neue, vierte Registerkarte am Gruft-Tisch (§2.6). Wer das Dorf nie betritt, spielt den Friedhof weiter wie bisher (ohne neue Grabstellen ruhen die Lieferungen, §2.9).

### 1.2 Freischaltung
- **Neues Spiel:** Phase 7 öffnet sich mit dem Phase-6-Kapitel `roof_and_earth_complete`. Am ersten Morgen danach (erste Minute ≥ 06:00, idempotent) setzt `Village.apply_morning` das Flag `village_open` und speichert den Tag in `village_open_day`. Ab dann hat Osric den Knoten `p7_intro`, und der Wegstein am Kutschweg zeigt seinen Prompt.
- **Migrierte Stände (v5):** Ist `roof_and_earth_complete` gesetzt, setzt `Village.post_load` `village_open` sofort (auch nach 06:00). Bei einem v6-Stand gilt die Morgenregel (Speichern → Laden bitgleich, wie Phase 6).
- Vor `village_open` ist der Wegstein Kulisse ohne Prompt, der Lindenacker bleibt Wald hinter dem unsichtbaren Rand (§4.6), die Präparate-Karte fehlt. Frühere Spielphasen laufen dadurch unverändert.
- Osric `p7_intro` (Leittext, P6 darf glätten): „Der Schultheiß lässt fragen, ob du mal runterkommst, Totengräber. Nicht wegen eines Toten, ausnahmsweise. Er hat ein Stück Land für dich, unten am Waldrand, wo früher die Linde stand. Und die Leute wollen endlich wissen, wer da oben ihre Toten unter die Erde bringt. Den Kutschweg hinunter, über die Holderbrücke. Ich sitze ab Mittag im Holderkrug. Ich zahl dir ein Bier, wenn du mich findest."

### 1.3 Zeitkosten (Spielminuten; TimedAction wie bisher)
| Handlung | Min | Braucht | Abbrechbar |
|---|---|---|---|
| Weg Friedhof ↔ Hollerbrück (Wegstein / Holderbrücke) | **30** (die Uhr springt während der Abblende 0,8 s) | Hände frei (keine Leiche), keine laufende Handlung | – |
| Gang durch eine Haustür im Dorf | 0 (Überblendung 0,5 s wie die Hütte) | Öffnungszeit des Hauses (§2.2) | – |
| Reden, Kaufen, Verkaufen, Auftrag annehmen/abgeben | 0 (Dialog/Panel modal, die Zeit ruht) | Person anwesend | – |
| Geschenk geben | 0 | 1 Item aus `VillagerData.gifts_liked` | – |
| Eine Runde im Holderkrug ausgeben | 15 | 5 Münzen, Wirtin anwesend, einmal je Tag | nein |
| Spende in die Armenkasse (Amtsstube) | 0 | 5 Münzen je Schritt, höchstens 2 Schritte je Tag | – |
| Lindenacker roden (10 Hindernisse, §2.9) | 305 gesamt (Werkzeug-Faktoren aus Phase 5) | Flag `linden_granted` | ja (je Hindernis) |
| Präparat nehmen am Gruft-Tisch (höchstens 3 je Leiche) | **20** (Herz, Lunge, Magen, Leber, Nieren) · **25** (Augen) · **30** (Hand) | `anatomy_case`, Glas (1 `prep_jar` bzw. `prep_jar_small` + 1 `spirits`) oder Bündel (1 `linen`; Hand + 1 `beeswax`) | nein |
| Bündel einlegen (Präparierpult) | 5 | Bündel, 1 `prep_jar`, 1 `spirits` | nein |
| Schaupräparat herrichten (Präparierpult) | 40 | Präparat im Glas, 1 `beeswax`, 1 `ink` | nein |
| Knochenpräparat herrichten (Präparierpult) | 60 | Hand-Bündel, 1 `beeswax`, 1 `linen` | nein |
| Präparat begutachten (Präparierpult) | 20 | Glas/Knochen/Schau, Klarheit ≥ 0,5 | ja |
| Arznei ansetzen (Präparierpult) | 20 / 30 | §2.7 | nein |
| Präparat in die Sammlung stellen / herausnehmen | 0 | Sammlungsregal | – |
| Anatomie-Vorlesung (Wundarztstube, 23:00) | 60 | Präparat (Klarheit ≥ 0,5), jeder dritte Abend | nein |
| Todesursache deuten (Merkbuch) | 0 (Panel, die Zeit ruht) | Befund-Karte des Toten | – |
| Salbe / Tinktur (Präparierpult) | 20 / 30 | Rezept §2.7 | nein |
| Gutachten bei Quast (Wundarztstube; das Präparat bleibt bei ihm) | 30 | Präparat, Quast anwesend | nein |
| Präparat beisetzen (am Grab des Toten) | 10 | Präparat dieses Toten, Grab `FILLED` oder `MARKED` | ja |
| Präparierpult aufstellen (Gruft) | 90 | §2.7 | nein |
| Untersuchen, Herrichten, Verwerten, Räuchern, Aussegnung, Bauen | unverändert (Phase 4–6) | – | unverändert |

*Begründung Weg 30 Min:* Osric sagt „drei Meilen den Kutschweg hinunter"; sein Karren braucht morgens 40 Min für das sichtbare Stück. 30 Min zu Fuß je Richtung machen einen Dorfbesuch zu einer Entscheidung: Hin und zurück kostet eine Stunde, also so viel wie Untersuchen und Herrichten. Wer am Vormittag bestattet und am Nachmittag ins Dorf geht, schafft beides. Wer zweimal am Tag geht, verliert zwei Stunden. Die Uhr springt (wie beim Schlafen), statt dass der Spieler drei Meilen laufen muss.

### 1.4 Tagesbogen
**A) Referenz: Phase-6-Endstand (würdevoll, v5-Fixture `slot_p6_day40_reverent`, Tag 40, ≈ 20 Münzen am Morgen, 24 Gräber belegt, `old_03` noch hebbar, Kapelle 2 · Gruft 2 · Schuppen 2).** Der Bogen dauert **13 Tage**, das Kapitel fällt an B12. Richtwert Mensch; der Bot `neighbor7` spielt ihn nach (§10).

| Tag (Bogen) | Geschehen | Münzen früh → abends (§2.10) | Zielzeile (Beispiel) |
|---|---|---|---|
| 40 (B1) | Osric `p7_intro`. Nachmittags ins Dorf: Schultheiß Fenner (Amtsstube) gibt den **Lindenacker** frei (`o_fenner_linden`) und bittet um Werkstein für die Brunnenfassung (`o_fenner_well`). Holderkrug: Osric, Wirtin Rosine. Abends zurück. | 20 → 21 | „Sprich mit Osric" → „Geh nach Hollerbrück" → „Der Schultheiß erwartet dich in der Amtsstube" |
| 41 (B2) | Lindenacker roden (vormittags ≈ 4 h). Dorf: Werkstein beim Schmied abgeben (+6), Pfarrer Lenz am Kirchplatz: Weihe des Lindenackers bezahlen (10). Krämerin Theres, Wiebke Hagedorn am Brunnen (`o_hagedorn_place`). | 25 → 21 | „Lindenacker: 7/10" → „Bitte den Pfarrer um die Weihe" |
| 42 (B3) | Rest roden, Pforte. **09:20–10:30 Pfarrer Lenz weiht den Lindenacker** (er kommt den Hügel herauf). Wundarzt Quast (Wundarztstube): Vorstellung, Präparierbesteck angeboten (annehmen oder ablehnen). | 25 → 27 | „Der Pfarrer kommt am Vormittag" → „Der Wundarzt will dich sprechen" |
| 43 (B4) | Erste Leiche seit Tagen → Gruft → Lindenacker `l_01`. Aufträge Rosine (Holunderbeeren) und Esch (Holzkohle) abgeben. | 31 → 40 | „Bring die Leiche in die Gruft" |
| 44 (B5) | Leiche 2. **Präparierpult** aufstellen (12). Fiebertinktur für Rosines Sohn. | 44 → 40 | „Gruft: Präparierpult aufstellen" |
| 45 (B6) | Leiche 3 mit Aussegnung (`o_lenz_service`). Stein für Dorothee Mahn (`o_mangold_stone`) an der Steinmetzbank. | 44 → 55 | „Ein Stein für Dorothee Mahn" |
| 46 (B7) | Leiche 4. Ilse (nachts): „Wer besucht im Dorf die Kranken?" → Hinweis *Drei Besucher*. | 59 → 66 | „Merkbuch: Wer besucht die Sterbenden?" |
| 47 (B8) | Leiche 5. Pfarrer **Vertraut** → Sterbebuch → Hinweis *Das Zeichen im Sterbebuch*. Freiwillig: Kapelle 3 (40). | 70 → 41 | – |
| 48 (B9) | **Trauerflor an Wiebke Hagedorns Kate.** Osric bringt sie (Geschichts-Leiche D1, gezeichnet). Totenhemd, Aussegnung, Lindenacker, Stein mit Mohn → `o_hagedorn_place`. | 45 → 63 | „Wiebke Hagedorns letzter Wunsch" |
| 49 (B10) | Leiche 7. Liesel **Vertraut** (ihr Hinweis kommt erst ab B11, s. u.). | 67 → 76 | „Merkbuch: Hinweise passen zusammen" |
| 50 (B11) | Leiche 8 (Lindenacker voll). Liesel → Hinweis *Was die Seelfrau sah* (frühestens 10 Tage nach `village_open`, G7 Runde 2 angepasst) → Erkenntnis **„Vorher eingetragen"**. Stein für Wendel Gratz (`o_esch_stone`). | 80 → 88 | „Drei Bewohner vertraut: 2/3" |
| 51 (B12) | Dritter Bewohner **Vertraut** (Aufträge sind schon 7) → **Kapitel „Ein Name im Dorf"**. Freiwillig: Gruft 3 (35). | 92 → 61 | „Ein Name im Dorf: 4/4" |
| 52 (B13) | Freies Spiel. Keine freie Stelle → keine Lieferung. Gemeindetafel, Tinkturen, Runden. | 65 → 63 | „Die Gemeindetafel hat neue Bitten" |

**B) Neues Spiel:** `roof_and_earth` fällt je nach Spielweise an Tag 29–42 (G6), der Bogen läuft danach wie A. Richtwert Kapitelende „Ein Name im Dorf" ≈ Tag 41–55. Die Kapitel sind voneinander unabhängig: Phase 7 sperrt nichts aus Phase 4–6.

### 1.5 Phasenziel – Kapitel „Ein Name im Dorf" (`name_in_village`)
Erfüllt, sobald **alle** gelten (geprüft von `Village.check_goal` bei `order_completed`, `relationship_changed`, `insight_unlocked` und nach der Weihe):
1. Der **Lindenacker ist geweiht** (`linden_consecrated`).
2. Mindestens **6 Aufträge erledigt**, von mindestens **4 verschiedenen** Auftraggebern (Gemeindetafel zählt als Auftraggeber „Gemeinde").
3. Mindestens **3 Dorfbewohner** stehen auf **„Vertraut"** oder höher (Beziehung ≥ 40, §2.4).
4. Die Erkenntnis **„Vorher eingetragen"** (`i_deathbook`) ist verknüpft.

Dann: Flag `name_in_village_complete`, `chapter_completed(&"name_in_village")`, Abschluss-Panel Variante `name_in_village`. Es zeigt: Tage seit `village_open`, Wege ins Dorf, Aufträge n (nach Auftraggeber), Beziehungen aller acht als Wort, Ruf-Stufe, Bestattungen im Lindenacker, Präparate genommen / verkauft / begutachtet / in Vorlesungen / zu Arzneien / in der Sammlung / zurückgelegt, Deutungen, Ansehen bei der Universität, Münzen im Dorf eingenommen und ausgegeben (nach Zweck), Erkenntnisse der Phase. Schlusszeile je nach Pietät-Stufe (5 Varianten, P6), Standard: „Unten im Dorf kennen sie jetzt deinen Namen. Oben auf dem Hügel kennen sie ihn schon länger." Danach läuft das Spiel frei weiter. **Gate-Ziel:** Alle Bot-Strategien erreichen das Kapitel, auch der verwertende Weg und ein Spieler mit niedrigem Ruf; keine Bedingung verlangt Präparate, keine verbietet sie.

### 1.6 Das Geheimnis – Phase-7-Ausschnitt „Wer besucht die Sterbenden?"
**Leitplanke (Autorenwissen, Phase 18 entscheidet endgültig):** Der Gesamtbogen aus Phase 4 §1.4 bleibt. Lorenz lebt unter dem Birkenhang. Er hatte Ilse gefragt, „wer im Dorf die Kranken besucht" (Phase 4 §2.6). In Phase 7 nimmt der Spieler diese Frage auf. Wer zeichnet, wird **nicht** aufgelöst. Drei Menschen haben Zugang zu den Sterbenden, und alle drei sind hier: der **Pfarrer** (Versehgang), der **Wundarzt** (Krankenbesuch) und die **Seelfrau** (Totenwache). Ausgerechnet die Seelfrau, Liesel Dorn, war Lorenz' Augen im Dorf.

**Was der Spieler herausfinden kann:**
1. *Drei Besucher* (`c_v_three_visitors`, Ilse, nachts): „Ich hab ihm drei genannt: den Pfarrer, den Wundarzt und die Seelfrau. Er hat einen Namen unterstrichen. Welchen, hat er mir nicht gezeigt."
2. *Das Zeichen im Sterbebuch* (`c_v_deathbook`, Pfarrer bei „Vertraut" **oder** die Abschrift in der Amtsstube bei Fenner „Vertraut" oder nach einer Spende): Am Rand des Sterbebuchs steht neben fünf Namen ein kleiner Dreistrich. Die Tinte ist älter als der Eintrag des Todestags. Jemand hat die Namen vorher eingetragen.
3. *Was die Seelfrau sah* (`c_v_washing`, Liesel bei „Vertraut" **oder** wenn man ihr von Kaspar erzählt, nur mit Erkenntnis *Nicht Lorenz*; **beide Wege frühestens am 10. Tag nach `village_open`** (`village_open_days_gte:10`, B11 – nach Wiebke Hagedorns Totenwache), G7 Runde 2 angepasst): Sie hat das Zeichen seit dem Winter, als die Fähre kenterte, an den Toten gesehen und es Lorenz gemeldet, jedes Mal. Seit er fort ist, meldet sie es niemandem mehr. Sie schreibt die Namen in ihr Gesangbuch.
4. *Drei Wochen alt* (`c_v_hagedorn`, Fund an D1 Wiebke Hagedorn, Schritt Wunden, Mindestfrische 0,3): Ihr Zeichen ist frisch verheilt, etwa drei Wochen alt. In ihrer Schürze steckt ein Zettel: „Für den Totengräber. Linde, Mohn, Totenhemd. Und schau nach, wer mich besucht hat. – W. H."

**Erkenntnis (Pflicht fürs Kapitel):** `i_deathbook` „Vorher eingetragen" (Frage: „Wer schreibt die Namen auf?") = `c_v_deathbook` + `c_v_washing` + `c_v_three_visitors`. Text: „Im Sterbebuch steht das Zeichen neben Namen, deren Tod erst Wochen später eingetragen wurde. Liesel hat es an ihren Leibern gesehen, Lorenz hat nach denen gefragt, die die Kranken besuchen. Wer zeichnet, kommt ins Haus, solange sie noch leben, und schreibt sie vorher auf. Drei kommen in Frage. Eine davon hat Lorenz geholfen." Flag `insight_deathbook`.
**Optionale Erkenntnis (nur über die Anatomie):** `i_burn_it` „Verbrennt es" (Frage: „Was wollte der Zettel bei Quast?") = `c_v_still_heart` (die **Deutung** `d_still_heart` eines Herz-Befunds von einem gezeichneten Toten, §2.6.5) + `c_warning_letter` (Phase 4). Text: „Zweimal hat Quast ein gesundes, stilles Herz eines Gezeichneten eingelegt. Beide Male lag am nächsten Morgen ein Zettel vor seiner Tür, in derselben schrägen Hand wie die Warnbriefe: ‚Verbrennt es.' Lorenz will nicht, dass sie aufbewahrt werden." Flag `insight_burn_it`. Wer nie ein Organ nimmt, verpasst nur diese eine Zeile; die Geschichte bleibt lösbar. Die Pflicht-Erkenntnis `i_deathbook` braucht kein Präparat.
- `c_v_hagedorn` ist Hinweis und Stimmung, kein Teil einer Pflicht-Erkenntnis (sie wäre sonst an eine Liefertagsfolge gebunden).
- **Belohnung wie Phase 4:** Text, Flag, Zeile im Abschluss-Panel, keine Münzen.

**Nächster Erzählschritt (Phase 8, benannt): „Der unterstrichene Name".** Phase 8 gibt den drei Besuchern nächtliche Wege (Versehgang, Krankenbesuch, Totenwache) mit eigenen Zeitplänen. Der Spieler kann ihnen folgen und findet in Lorenz' zweiter Kladde (im Pfarrarchiv) die Seite mit den drei Namen, einer davon unterstrichen. Phase 8 zeigt, **wen** Lorenz verdächtigte, nicht, ob er recht hatte. Die Auflösung bleibt Phase 13–18.

---
## 2. Spielwerte (Vorschläge, alle in `data/`)

### 2.1 Die Leute von Hollerbrück (`data/village/villagers/<npc_id>.tres` – `VillagerData`)
**Entscheidung: acht Dorfbewohner mit eigenem Modell, dazu Osric im Dorf.** *Begründung:* Die Namen und Rollen greifen auf, was Osric seit Phase 2 erzählt hat: der Schmied, die Krämerin („Buntes"), der Pfarrer („sagt viel"), der Schultheiß (siegelt den Steinbruchbrief), die zwei Wirtshäuser, die Frauen am Brunnen, die alte Hagedorn („will hier oben liegen"), Kaspar Dorns Schwester. Acht Figuren auf dem gemeinsamen 8-Knochen-Rig sind das CPU- und Asset-Budget, das ein Dorf glaubhaft macht (§9). Weitere Leute erscheinen nur als sitzende Gäste ohne Rig (Phase-6-Trauergäste wiederverwendet, §8).

| npc_id | Name | Rolle | Aussehen (gemalt, Palette der Figuren) | Stimme | mag (`gifts_liked`) | Start |
|---|---|---|---|---|---|---|
| `innkeeper` | **Rosine Wackernagel**, 46 | Wirtin des „Holderkrug" am Anger (das Wirtshaus „für die, die reden") | breit und aufrecht, rostbraune Schürze über grauem Kleid, weißes Kopftuch, Ärmel hochgekrempelt, Schlüsselbund am Gürtel | laut, herzlich, schnell; nennt alle beim Nachnamen, auch die Kinder; weiß alles und sagt die Hälfte | `honey_cake`, `herb_bundle` | 25 |
| `smith` | **Ulrich Esch**, 52 | Schmied („die Hollerbrücker Schmiede", Osrics Eisenbeschläge) | groß, kahler Kopf, grauer Vollbart, Lederschürze, gemalte alte Brandflecken an den Unterarmen, Hammer am Gürtel | wortkarg, misst Leute an ihrer Arbeit; kurze Sätze wie Hammerschläge | `elder_wine`, `iron_ore` | 15 |
| `grocer` | **Theres Mangold** geb. Mahn, 38 | Krämerin, verkauft aus dem Ladenfenster | schmal, flink, Haube, Ärmelschoner, Augenglas an einer Schnur, Bleistift hinter dem Ohr | geschäftig, genau, rechnet laut mit; nennt alles, was sie nicht kennt, „Buntes" | `herbs`, `elderberries` | 20 |
| `priest` | **Pfarrer Ambrosius Lenz**, 61 | Pfarrer von St. Gallus | rundlich, schwarzer Talar, weißes Beffchen, Barett, Brevier unter dem Arm | freundlich, weitschweifig, redet über alles, nur nicht über Lorenz („nach Süden gegangen") | `elder_wine`, `honey_cake` | 25 |
| `mayor` | **Schultheiß Gottlieb Fenner**, 57 | Schultheiß, Gemeinderat, Armenkasse, Abschrift des Sterbebuchs | hager, dunkelgrüner Rock mit Messingknöpfen, Amtsstab, Siegelring, graues Haar im altmodischen Zopf | förmlich, Amtsdeutsch, aber ehrlich gemeint; zählt das Geld der Gemeinde laut | `ink`, `honey_cake` | 30 |
| `surgeon` | **Severin Quast**, 41 | Wundarzt und Geburtshelfer, sammelt Präparate für das anatomische Kabinett der Stadt | schlank, dunkler Gehrock, weißes Halstuch, Ärmelschürze aus Wachstuch, Lederkoffer, gestutzter Backenbart, Lesebrille | leise, höflich, sachlich, unheimlich ruhig; benutzt lateinische Wörter und entschuldigt sich dafür; „Die Toten lehren die Lebenden." | `spirits`, `herb_bundle` | 20 |
| `washer` | **Liesel Dorn**, 44 | Seelfrau (wäscht und kleidet die Toten des Dorfes, hält Totenwache), Spinnerin; Kaspar Dorns Schwester | graues Wolltuch über dem Kopf, schwarzes Kleid, weiße Schürze, Spindel am Gürtel, gerötete Hände | redet viel bei der Arbeit und nichts, wenn man fragt; spricht von den Toten wie von Nachbarn; misstrauisch, dann warm | `linen`, `honey_cake` | 10 |
| `oldwoman` | **Wiebke Hagedorn**, 81 | Altenteilerin, sitzt am Brunnen, will „oben liegen, mit Blick auf die Linde" | klein, gebeugt, Stock, schwarzer Schal, ein Sträußchen getrockneter Mohn am Mieder | spitz, fröhlich, unerschrocken; redet vom Sterben wie vom Wetter | `seeds`, `honey_cake` | 30 |
| (`carter`) | Osric Faulhaber | Leichenkutscher, wohnt in der Remise am Ostende des Angers, sitzt im Holderkrug | unverändert (`ph_chr_carter`), im Dorf ohne Karren (der Karren steht als Requisite in der Remise) | unverändert | – (keine Beziehung in Phase 7) | – |

- **Startwert** beim ersten Gespräch: Spalte „Start" + `RelationshipConfig.rep_start_bonus` nach Ruf-Stufe **[0, +2, +4, +6, +8]** (Verrufen … Gerühmt; G7 Runde 2 angepasst, vorher [−10, −5, 0, +5, +10]: niemand startet über „Bekannt", höchstens 38 – Fenner, Lenz, Hagedorn bei „Gerühmt"/„Andächtig"). Liesel und Pfarrer zusätzlich + `piety_start_bonus` [−5, 0, 0, +3, +5] (Hartherzig … Andächtig). *Begründung:* Das Dorf kennt den Totengräber vorher nur vom Hörensagen. Der Ruf ist genau dieses Hörensagen; die Pietät spüren nur die, die selbst mit Toten umgehen.
- **Ilse Kranich** kommt nie ins Dorf (sie zeigt sich nicht bei Tag, Osric Phase 4). Sie spricht nachts an der Westmauer über das Dorf (§2.12) und bekommt keine Beziehung in Phase 7 (ihre Gespräche zählt weiter `NightTrade.talks`).
- `VillagerData`: `npc_id`, `display_name`, `role`, `dialogue_id` (`v_<npc_id>`), `shop_id` („" = kein Laden), `gifts_liked`, `start_value`, `specimen_delta` (Beziehung je verkauftem Präparat: Pfarrer −4, Liesel −3, Hagedorn −2, Quast +2, sonst 0), `returned_delta` (je zurückgelegtem Präparat: Pfarrer +1, Liesel +2), `remarks` (Gerede §2.4), `home_door` (Haus-Id).

### 2.2 Tagesabläufe & Öffnungszeiten (`data/npc/<npc_id>_schedule.tres`, bestehendes `NpcSchedule`)
Alle Zeitpläne laufen deterministisch aus der Uhr (bestehendes `ScheduleResolver`). Neu ist `ScheduleEntry.region` (✦, „" = Friedhof): Ein `Npc`-Knoten zeigt nur Einträge seiner eigenen Region (§3.4). Wegpunkte `v_*` liegen in der Dorf-Region (§4.4), Innenraum-Wegpunkte `v_in_*` in den Dorf-Innenräumen.
| Person | Tagesablauf (Beginn – Ort – Tätigkeit · Gespräch/Laden) |
|---|---|
| Rosine | 06:00 Weg zum Brunnen (10 Min) · 06:10–06:40 Brunnen, Wasser holen (`talk`) · 06:40 zurück · **06:50–23:30 Gaststube am Schanktisch** (Laden `inn`) · sonst daheim |
| Ulrich Esch | 06:30 Weg zur Schmiede · **06:40–12:00 Amboss** (`work`, Laden `smith`) · 12:00–13:00 Gaststube, Mittagstisch · **13:06–17:30 Amboss** · 17:34–19:00 Bank unter der Linde (nur Gespräch) · danach daheim |
| Theres Mangold | **07:25–14:00 Ladenfenster** (Laden `grocer`) · 14:05–14:30 Brunnen · **14:35–18:00 Ladenfenster** · sonst daheim |
| Pfarrer Lenz | **08:00–11:30 Kirchentür St. Gallus** (Laden `priest`) · 11:30 Versehgang zur Hagedorn-Kate (8 Min, dann im Haus) · 12:38–16:00 Pfarrhaus (unsichtbar) · **16:00–18:00 Kirchentür** · 18:10–20:00 Gaststube · daheim. **Am Weihetag** (§2.9): 08:40–09:20 Kutschweg hinauf, **09:20–10:30 am Lindenacker** (Friedhof), 10:30–11:10 zurück, danach wie sonst ab 11:30 |
| Schultheiß Fenner | **07:55–12:00 Amtsstube** · 12:00–12:20 Runde über den Anger · 12:20–13:00 Gemeindetafel · **13:05–16:00 Amtsstube** · 16:00–18:00 Gemeindetafel · 18:05–21:00 Gaststube · daheim |
| Severin Quast | **07:55–12:00 Wundarztstube** (Laden `surgeon`, Präparate) · 12:00–13:50 Krankenbesuch (geht zu einem der Wohnhäuser, dann im Haus) · **14:00–18:00 Wundarztstube** · 18:06–19:30 Holderbrücke, schaut ins Wasser (nur Gespräch) · daheim |
| Liesel Dorn | 06:38–09:00 Waschplatz am Bach (`work`) · 09:00–12:00 Totenwache (unsichtbar) · **12:00–15:00 vor ihrer Kate, spinnt** (Laden `washer`) · 15:05–16:30 Brunnen · **16:35–19:00 vor ihrer Kate** · daheim |
| Wiebke Hagedorn | 09:06–11:00 Bank am Brunnen · 11:06–14:00 daheim · 14:00–17:00 an ihrer Gartenpforte · daheim. Ab `hagedorn_dead` (§2.9) unsichtbar (`Npc.hide_flag`) |
| Osric (Region Dorf) | 11:10 vom Dorfeingang zur Remise (8 Min) · 11:18–14:00 Remise (Gespräch `carter_village`) · 14:05–17:30 Gaststube · 22:00–23:30 Gaststube · sonst unterwegs oder daheim. **Die Friedhofs-Einträge von `carter_schedule.tres` bleiben bitgleich**; die neuen Einträge haben `region village` und fallen in seine bisherigen „home"-Zeiten (10:40–18:00, ab 21:30) |

**Öffnungszeiten der Häuser** (`HouseDoor`, §3.4): Holderkrug 06:50–23:30 · Wundarztstube 07:55–12:00 und 14:00–18:00 · Amtsstube 07:55–12:00 und 13:05–16:00. Sonst: „Geschlossen. Öffnet um 14:00." Wer drinnen ist, wenn geschlossen wird, darf in Ruhe hinausgehen (kein Rauswurf).
*Begründung:* Jede Person ist an zwei bis drei festen Orten zu finden, zur Mittagszeit ändert sich das Bild des Angers (Brunnen, Linde, Gaststube). Wer morgens bestattet und am Nachmittag (14:00–18:00) ins Dorf geht, trifft alle acht. Wer abends kommt, findet die Wirtschaft voll (Esch, Lenz, Fenner, Osric). Die Hausbesuche von Pfarrer, Quast und Liesel sind sichtbar, aber nicht verfolgbar: das ist der Haken für Phase 8 (§1.6).

### 2.3 Läden (`data/shops/<id>.tres` – `ShopData`, `data/config/village_config.tres`)
**Entscheidung: ein Laden-System für alle Dorfbewohner nach dem Muster von Ilses Nachthandel** (Münzen sofort, Vorrat je Tag, atomar). Ilses `NightTrade` bleibt unverändert. Ladenzeit = die Person steht an ihrem Laden-Ort (Gespräch → „Was hast du da?" → Panel `&"shop"`).

| Laden | verkauft (Preis · Vorrat/Tag) | kauft (Preis · höchstens/Tag) |
|---|---|---|
| `grocer` Theres | `linen` 3 · 6 · `seeds` 1 · 6 · `juniper` 2 · 4 · `altar_candle` 2 · 4 · `prep_jar` 2 · 4 · `beeswax` 1 · 4 · `honey_cake` 1 · 4 · `gold_leaf` 6 · 1 (nur „Befreundet") | `herbs` 1 · 8 · `elderberries` 1 · 8 · `herb_bundle` 3 · 4 · `wound_salve` 4 · 3 · `yarn` 1 · 6 |
| `smith` Esch | `iron_fittings` 3 · 6 · `iron_bar` 6 · 2 · `steel_rod` 6 · 2 (+2 bei „Befreundet") | `iron_ore` 1 · 6 · `charcoal` 1 · 8 |
| `inn` Rosine | `spirits` 3 · 4 · `elder_wine` 2 · 3 | `elderberries` 2 · 10 · `herbs` 1 · 4 |
| `priest` Lenz | `altar_candle` 2 · 6 | – |
| `surgeon` Quast | `prep_jar` 2 · 4 · `spirits` 3 · 2 | `fever_tincture` 6 · 3 · `wound_salve` 5 · 2 · Präparate (eigenes Panel, §2.6) |
| `washer` Liesel | `yarn` 1 · 4 · `linen` 2 · 2 | `burial_gown` 6 · 2 · `shroud` 3 · 2 |

- **Preisregel** (`ShopRules.price`, ganze Münzen, nie unter 1): Grundpreis · Ruf „Verrufen" **+1** je Stück · Beziehung „Vertraut" oder höher **−1** auf Waren ab 4 Münzen. Ankauf: Grundpreis, bei „Befreundet" +1 ab 3 Münzen. Keine weitere Feilscherei.
- **Vorrat** setzt sich jeden Morgen um 06:00 zurück (aus `TimeManager.day` abgeleitet, Laden nie nachfüllbar durch Laden/Speichern wie bei Ilse).
- Münzen fürs Einkaufen laufen über `GameState.note_coins_spent(n, &"village")`, Einnahmen über `payment_received(n, "Verkauf im Dorf")`.
- *Begründung Werte:* Gleiche Waren wie bei Osric kosten gleich viel (Leinen 3, Kerzen 2) – das Dorf ist bequem, nicht billiger. Billiger sind nur Liesels Leinen (2, wenig) und Ilses Nachtware. Das Dorf **kauft** dafür, was der Werkhof aus Phase 5 hergibt (Kräuter, Beeren, Garn, Totenhemden, Salben): Das ist die neue Einnahme für den würdevollen Weg, gedeckelt je Tag, damit keine Sammel-Schleife entsteht (ein voller Kräuter- und Beerentag bringt ≈ 8–12 Münzen). Das Totenhemd kostet aus gekauftem Leinen 9 und bringt 6: lohnt nur aus eigenem Flachs.

### 2.4 Beziehungen (`data/config/relationship_config.tres` – `RelationshipConfig`)
**Ein Wert je Person, 0…100**, gespeichert in `Relationships` (§3.4), offen sichtbar als Wort und fünf Punkte (§7). *Begründung:* Die Pietät ist das Innen und bleibt verborgen; die Beziehung ist das, was zwei Menschen voneinander wissen, und darf gezeigt werden.
| Stufe | id | Bereich | Wirkung |
|---|---|---|---|
| Fremd | `stranger` | 0…14 | Laden normal; nur der erste Auftrag |
| Bekannt | `acquainted` | 15…39 | alle Aufträge der Person ab ihrer Freigabe |
| **Vertraut** | `trusted` | 40…69 | −1 Münze auf Waren ab 4; Geschichts-Hinweise (Pfarrer: Sterbebuch, Liesel: Seelfrau, Fenner: Abschrift); zählt fürs Kapitel |
| Befreundet | `friend` | 70…100 | Sonderware (Blattgold bei Theres, +2 Stahl bei Esch), Quast zahlt +1 je Präparat, eigene Abschiedszeile |

**Änderungen** (`RelationshipConfig.gains`, direkt vom auslösenden System über `Relationships.add`):
| Ereignis | Wert | Regel |
|---|---|---|
| `talk` | +1 | erstes Gespräch des Tages mit dieser Person |
| `gift` | +4 | ein Item aus `gifts_liked`, einmal je Tag und Person; anderes wird höflich abgelehnt („Das brauch ich nicht, aber danke.") |
| `round` | +2 | „Eine Runde für alle" im Holderkrug (5 Münzen, einmal je Tag): alle Dorfbewohner, die gerade in der Gaststube sind |
| `donation` | +1 (Fenner) | je 5 Münzen in die Armenkasse, höchstens 2 Schritte je Tag; dazu Ruf +1 je Schritt |
| `order_done` | `OrderData.reward_rel` (+6…+10), dazu `extra_rel` | §2.5 |
| `order_failed` | −4 | Frist verstrichen oder Bedingung gebrochen (Hagedorn: Liesel −10, Pfarrer −5) |
| `specimen_sold` | `VillagerData.specimen_delta` | je an Quast verkauftem Präparat (Pfarrer −4, Liesel −3, Hagedorn −2, Quast +2) – „Im Dorf redet man." |
| `specimen_returned` | `returned_delta` | Pfarrer +1, Liesel +2 |
- Keine tägliche Abnahme, kein Verfall. Wer nicht hingeht, verliert nichts.
- *Nachrechnung:* Von Start 20 bis „Vertraut" (40) braucht es 20 Punkte: zwei erledigte Aufträge (≈ 16) und vier Gesprächstage, oder ein Auftrag, zwei Geschenke und vier Tage. Bei einem Besuch am Tag erreicht man drei Personen auf „Vertraut" um B9–B11 (Bogen A). Liesel (Start 10) ist am schwersten, Fenner (30) am leichtesten. *G7 Runde 2 angepasst:* Mit dem Ruf-Bonus 0…+8 startet niemand „Vertraut"; Aufträge und Geschenke machen Fenner, Rosine und Lenz trotzdem nach 1–3 Dorftagen vertraut. Den Kapiteltag (≈ B11) setzt deshalb der Liesel-Hinweis (§1.6, frühestens 10 Tage nach `village_open`), nicht die Beziehung.

**Ruf und Pietät im Dorf (spürbar, nie sperrend)**
- **Begrüßung** jeder Person nach Ruf-Stufe (5 Zeilen je Person in ihrem Dialog, Bedingung `rep_tier:<id>`), bei Liesel, Pfarrer und Quast zusätzlich nach Pietät (`piety_tier`). Beispiel Rosine: Verrufen „Du bist der vom Hügel. Setz dich ans Fenster, da sieht dich keiner." · Gerühmt „Wackernagel hat für dich einen Stuhl am Ofen frei. Den kriegt sonst nur der Pfarrer."
- **Gerede** (`VillagerData.remarks`, `villager_remarked`): Kommt der Totengräber einer Person im Dorf auf 4 m nahe, sagt sie einmal am Tag eine Zeile als Sprechblase (wie die Geister, ohne Dialog). Die Zeile hängt von Ruf-Stufe, Pietät-Stufe und Beziehung ab (Vorrang: Beziehung „Befreundet" → Pietät Hartherzig/Andächtig → Ruf). Je Person 6–8 Zeilen. Beispiele: Verrufen „Das ist der, bei dem die Taschen leichter werden." · Geachtet „Der Totengräber. Grüß Gott." · Andächtig (Liesel) „Du riechst nach Wacholder. Das ist ein guter Geruch für einen wie dich." · nach vielen Präparaten (Pfarrer) „Quast hat wieder Post vom Hügel, sagt man."
- **Preise:** Verrufen +1 je Ware (§2.3). Kein Laden verweigert den Handel, kein Auftrag ist gesperrt, kein Kapitelziel hängt am Ruf (§1.5). *Begründung:* Phase 4–6 halten beide Wege spielbar. Ein Verrufener zahlt mehr und hört Unfreundliches, findet aber dieselben Wege.
- Die **Gemeindetafel** zeigt oben: „Totengräber auf dem Hügel – Ruf: Geachtet", darunter die offenen Bitten.

### 2.5 Aufträge (`data/orders/<id>.tres` – `OrderData`, `data/config/orders_config.tres` – `OrdersConfig`)
**Fünf Arten, klein und erweiterbar** (`OrderData.kind`):
| Art | Erfüllt, wenn … | Abgabe |
|---|---|---|
| `deliver` | `items` beim Abgeben im Inventar | im Gespräch mit dem Empfänger (`recipient`, sonst Auftraggeber): „[Auftrag] Hier ist, was du wolltest." – atomar |
| `bury` | eine Leiche (`target`: Geschichts-Id oder „die nächste Lieferung nach Annahme") wird mit den `conditions` bestattet und bekommt ihr Zeichen | von selbst beim Grabzeichen (`Graveyard` ruft `Orders.note_grave_completed` direkt) |
| `stone` | auf dem Grab `target` steht ein gestalteter Stein mit `conditions` (Form, Zierde, vergoldet) | von selbst beim Setzen (`Orders.note_stone_set`) |
| `tend` | alle Gräber von `target` (Abschnitt oder Grab) an `conditions.mornings` Morgen in Folge ohne Pflegeabzug | von selbst bei `apply_morning` |
| `donate` | `items` + `coins` beim Abgeben | im Gespräch: Münzen über `note_coins_spent(…, &"donation")` |
| `section` | der Abschnitt `target` ist vollständig geräumt | von selbst (`Orders.note_section_progress`) |
- **Ablauf:** angeboten (Gespräch oder Gemeindetafel) → angenommen → erledigt / gescheitert. Höchstens **4 aktive** Aufträge (`OrdersConfig.max_active`). Fristen in Spieltagen ab Annahme (`days_limit`, 0 = keine); Prüfung um 06:00. Gescheitert: Beziehung −4, „Bitte" verschwindet; persönliche Aufträge kommen nicht wieder, Tafel-Aufträge nach `cooldown_days 3`.
- **Gemeindetafel** an der Linde (Auftraggeber `council`, „die Gemeinde"): jeden Morgen 2 Angebote aus dem Tafel-Pool (deterministisch aus Tag und Seed, nichts doppelt, Abkühlzeit beachtet), offen bis zum nächsten Morgen.
- **Bestatt-Bedingungen** (`conditions`, alle optional): `dress` (`shroud`/`gown`), `service` (Aussegnung gehalten), `prepared` (voll hergerichtet), `unharvested` (nichts verwertet, auch keine Präparate), `section` (Abschnitt des Grabs), `stone_shape`, `ornament`, `gilded`, `inscription`. Ein Verstoß, der sich nicht mehr heilen lässt (verwertet, falscher Abschnitt), lässt den Auftrag sofort scheitern; ein fehlendes Zeichen wartet.
- **Stein auf einem Ruhezeit-Grab (neu, nur über Aufträge):** `old_01` (Wendel Gratz) und `old_08` (Dorothee Mahn) behalten seit Phase 6 ihren alten Stein („Um die weint noch jemand", Osric). Mit einem aktiven `stone`-Auftrag darf die Steinmetzbank für genau dieses Grab einen gestalteten Stein fertigen; „[E] Neuen Stein setzen (20 Min)" ersetzt den alten (Zustand bleibt `OLD`, das Grab bleibt nicht hebbar, keine Bezahlung, keine Qualität – nur der Auftrag, Ruf `marker_upgrade` +1). Der alte Stein lehnt danach an der Gruft-Treppe (dasselbe Modell, 0,9 ×). *Begründung:* Das sind genau die zwei Gräber, um die im Dorf noch jemand weint. Jetzt bekommen die Weinenden Gesichter.

**Aufträge (Leitdaten, Texte P6/P3 dürfen glätten; Münzlöhne G7 Runde 2 angepasst, B7-2)**
| id | Auftraggeber | Art | Freigabe | Inhalt | Frist | Lohn: Münzen · Beziehung · Ruf |
|---|---|---|---|---|---|---|
| `o_fenner_linden` | Fenner | section | erstes Gespräch | „Der Lindenacker": Pforte, Stümpfe, Brombeeren und Steine räumen (§2.9); setzt `linden_granted` bei Annahme | – | **6** (G7 R2, vorher 0: Rodungslohn der Gemeinde) · +8 · +2 |
| `o_fenner_well` | Fenner | deliver → Esch | erstes Gespräch | 4 `workstone` für die neue Brunnenfassung, beim Schmied abgeben | 4 | 6 · +6 (+4 Esch) · +1 |
| `o_fenner_bridge` | Fenner | donate | `o_fenner_well` erledigt | „Die Holderbrücke": 20 Münzen und 6 `wood` für neue Bohlen | 6 | 0 · +10 · +3 |
| `o_rosine_berries` | Rosine | deliver | erstes Gespräch | 8 `elderberries` für den Holunderwein | 5 | 6 · +8 · 0 |
| `o_rosine_tincture` | Rosine | deliver | `o_rosine_berries` erledigt | 2 `fever_tincture` (oder 2 `bitter_drops`) – „Jakob fiebert, und der Quast nimmt zu viel." | 4 | **6** (G7 R2, vorher 8) · +10 · 0 |
| `o_esch_charcoal` | Esch | deliver | erstes Gespräch | 6 `charcoal` | 5 | 7 · +8 · 0 |
| `o_esch_stone` | Esch | stone | Esch „Bekannt", `o_esch_charcoal` erledigt | „Ein Stein für den Meister": Wendel Gratz (`old_01`), sein Lehrmeister; Bogenstein mit Fackel | 6 | **8** (G7 R2, vorher 10) · +10 · +1 |
| `o_mangold_stone` | Theres | stone | Theres „Bekannt" | „Ein Stein für die Mutter": Dorothee Mahn (`old_08`); Stele mit Mohn und Inschrift | 6 | **10** (G7 R2, vorher 12) · +10 · +1 |
| `o_lenz_service` | Lenz | bury | erstes Gespräch nach der Weihe | die nächste Lieferung nach Annahme: eingekleidet und **ausgesegnet** in der Kapelle (≥ Stufe 2, mit Trauergästen) | 3 | **4** (G7 R2, vorher 6) · +8 · +1 |
| `o_lenz_poor` | Lenz | donate | Lenz „Vertraut" | „Armenspeisung": 12 Münzen und 4 `honey_cake` | 5 | 0 · +8 · +2 |
| `o_quast_tincture` | Quast | deliver | erstes Gespräch | 2 `fever_tincture` | 5 | **7** (G7 R2, vorher 10) · +8 · 0 |
| `o_quast_specimen` | Quast | deliver | `anatomy_known` | „Für das Kabinett": 1 Präparat im Glas (Herz, Lunge, Magen, Leber oder Nieren), Klarheit ≥ 0,6 (§2.6); die Folgen trug schon das Nehmen | 6 | 10 · +10 · 0 |
| `o_quast_antidote` | Quast | deliver | `anatomy_known`, Lehrsatz `l_stomach` | 2 `antidote` – „Der kleine Kehr hat vom Rattengift genascht. Ich habe nicht genug." | 2 | **9** (G7 R2, vorher 12) · +8 (+4 Rosine) · +1 |
| `o_fenner_dropsy` | Fenner | deliver | Fenner „Vertraut", `anatomy_known` | 1 `dropsy_powder` – „Meine Beine, Totengräber. Sagen Sie es keinem." | 5 | **8** (G7 R2, vorher 10) · +8 · 0 |
| `o_quast_cabinet` | Quast | deliver | Ansehen bei der Universität ≥ 2 | 1 `display_specimen` (beliebig) „für das Kabinett der Universität" | 6 | **11** (G7 R2, vorher 14) · +10 · 0 |
| `o_liesel_gowns` | Liesel | deliver | Liesel „Bekannt" | 2 `burial_gown` – „für die, die nicht zu dir hinaufkommen" | 6 | **6** (G7 R2, vorher 8) · +8 · 0 |
| `o_hagedorn_place` | Hagedorn (nach ihrem Tod: Liesel) | bury | erstes Gespräch mit ihr, sonst bei ihrer Ankunft | D1 Wiebke Hagedorn (§2.9): Lindenacker, Totenhemd, Stein mit Mohn, **unverwertet** | 3 Tage ab Ankunft | **6** (G7 R2, vorher 10) · +8 Liesel · +2; gescheitert: Liesel −10, Lenz −5 |
| `ob_wood` | Gemeinde (Tafel) | deliver → Fenner | `village_open` | 10 `wood` „für den Gemeindezaun" | 1 | **4** (G7 R2, vorher 5) · +3 Fenner · 0 |
| `ob_stone` | Gemeinde | deliver → Fenner | `village_open` | 8 `stone` „für den Weg zur Kirche" | 1 | **3** (G7 R2, vorher 5) · +3 Fenner · 0 |
| `ob_herbs` | Gemeinde | deliver → Quast | `village_open` | 4 `herb_bundle` „für die Armen im Winter" | 1 | **6** (G7 R2, vorher 8) · +3 Quast · 0 |
| `ob_yarn` | Gemeinde | deliver → Liesel | `village_open` | 6 `yarn` | 1 | **3** (G7 R2, vorher 5) · +3 Liesel · 0 |
| `ob_gown` | Gemeinde | bury | `linden_consecrated` | die nächste Lieferung im Totenhemd | 2 | **3** (G7 R2, vorher 4) · 0 · +1 |
| `ob_tend` | Gemeinde | tend | `linden_consecrated` | alle belegten Gräber im Lindenacker an 2 Morgen in Folge ohne Pflegeabzug | 4 | **4** (G7 R2, vorher 5) · 0 · +1 |
- Tafel-Aufträge: Frist 1 = „bis morgen früh" (angenommen am Tag der Ausschreibung, abzugeben bis 06:00 des Folgetags) – außer `ob_gown`/`ob_tend` mit eigener Frist.
- **Kapitel** zählt jeden erledigten Auftrag (§1.5). Auftraggeber für „4 verschiedene": Fenner, Rosine, Esch, Theres, Lenz, Quast, Liesel, Hagedorn, Gemeinde.
- Die drei Arznei-Aufträge (`o_quast_antidote`, `o_fenner_dropsy`, Bittertropfen statt Tinktur) sind **zusätzliche** Wege für den anatomischen Spieler; jeder Kräuter-Auftrag bleibt ohne Präparat lösbar, und das Kapitel braucht keinen von ihnen.
- *Begründung Lohn:* Ein Liefer-Auftrag ersetzt einen Laden-Verkauf mit Aufschlag (8 Holunderbeeren: bei Rosine 8–16 Münzen Ankauf, als Auftrag 6 + Beziehung +8). Aufträge lohnen also vor allem über die Beziehung. Steine und Bestattungen bringen mehr, weil sie Stunden kosten. Die zwei Spenden-Aufträge (`donate`) sind die Münzsenke des Dorfes: sie kosten 32 Münzen und bringen Ruf und Beziehung, nie Münzen (§2.10).

### 2.6 Anatomie – Präparate am Gruft-Tisch (`data/config/anatomy_config.tres` – `AnatomyConfig`, `data/anatomy/findings/<id>.tres` – `SpecimenFindingData`)
**Eigene Identität: das Etikett.** Jedes Präparat trägt den Namen des Toten. Es ist kein Rohstoff und hat keine Punkte, sondern ein Einzelstück mit Herkunft: „Herz – Hedwig Lamprecht, 58 – Klarheit gut". Man kann es verkaufen, in Quasts Vorlesung geben (§2.6.4), in der Sammlung aufstellen (§2.7), zu einer Arznei ansetzen (§2.7), begutachten und deuten (§2.6.5) **oder dem Toten zurückgeben**. Darin liegt der Unterschied zu jedem Organhandel: Was hier genommen wird, bleibt jemandes, und der Weg zurück ins Grab steht offen, solange das Stück nicht verkauft, verbraucht oder in der Vorlesung geblieben ist.

**Sieben Präparate** (`AnatomyConfig.organs`; je Leiche jedes höchstens einmal, **höchstens 3 Präparate je Leiche** – `max_per_corpse 3`, „Mehr nimmst du ihr nicht."):
| organ | Etikett | Behältnis | Min | Grundpreis bei Quast | Qualität | Ruf | Pietät | Geist (Stimmung) | Rückgabe: Pietät | zeigt (Befund-Karten §2.6.5) | `res_tag` (nur Daten) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `heart` | Herz | Glas oder Bündel | 20 | **9** (G7 R2, vorher 7) | −2 | −3 | −8 | −5 | +3 | „stilles Herz" bei Gezeichneten, Altersherz | `&"will"` |
| `lung` | Lunge | Glas oder Bündel | 20 | 4 | −2 | −3 | −6 | −5 | +3 | Wasser / kein Wasser, Fieberflecken | `&"breath"` |
| `stomach` | Magen | Glas oder Bündel | 20 | 5 | −2 | −3 | −6 | −5 | +3 | weißer Belag (Gift), leer | `&"hunger"` |
| `liver` | Leber | Glas oder Bündel | 20 | 5 | −2 | −3 | −6 | −5 | +3 | Trunk, Gelbsucht, Gift | `&"blood_heat"` |
| `kidneys` | Nieren | Glas oder Bündel | 20 | 4 | −2 | −3 | −6 | −5 | +3 | Steine, Wassersucht | `&"water"` |
| `eyes` | Augen | **nur Glas** (kleines, dunkles Glas mit zwei Siegeln) | 25 | **11** (G7 R2, vorher 9) | −3 | −5 | **−12** | **−8** | +5 | Moortrübung, Fieberglanz | `&"sight"` |
| `hand` | Hand (Knochen) | **nur Bündel** (in Leinen geschlagen, verschnürt) | 30 | **12** (G7 R2, vorher 10; als Knochenpräparat, §2.7) | −3 | −5 | **−12** | **−8** | +5 | Schwielen (Beruf), Schwurnarbe | `&"grip"` – Lehrpräparat und späterer Auferstehungs-Haken |
*Begründung:* Die inneren Organe sind das Material der Anatomie von 1834 und kosten gleich viel. Das Herz kostet etwas mehr Pietät, weil es das ist, was die Leute „den Menschen" nennen. Augen und Hand sind das, woran man einen Menschen erkennt. Deshalb kosten sie am meisten, zahlen am besten und werden am stillsten dargestellt. Die Grenze von drei Präparaten je Leiche verhindert, dass eine Leiche ausgeschlachtet wird, und hält die Anatomie als Einnahme unter der Bestattung (§2.10).

**Nehmen (Registerkarte „Präparate" am Gruft-Tisch, §7)**
- Sichtbar erst ab Flag `anatomy_known` (Quast gibt das **Präparierbesteck** `anatomy_case`, §2.12), nur am Tisch mit `room &"crypt"`. Vorher gibt es keine Karte.
- Voraussetzungen: Leiche nicht eingekleidet (wie Haar/Zähne: „Nach dem Einkleiden nicht mehr zugänglich."), dieses Präparat noch nicht genommen, weniger als 3 genommen, Frische ≥ **0,3** („Zu spät. Daran lässt sich nichts mehr zeigen."), Werkzeug `anatomy_case` („Werkzeug fehlt – Quast hat es."), Behältnis: **Glas** (1 `prep_jar` + 1 `spirits`; Augen: 1 `prep_jar_small` + 1 `spirits`) oder **Bündel** (1 `linen`; Hand: 1 `linen` + 1 `beeswax`) nach Wahl in der Zeile, wo erlaubt, und Platz für ein Einzelstück.
- **Zweistufige Bestätigung** wie die Verwertung aus Phase 4 (`CorpseExamTabs.press_harvest`, `confirm_seconds 3`). Für Augen und Hand steht beim ersten Druck die längere Zeile „Das bleibt ihr fehlen. Wirklich? Noch einmal drücken."
- **Darstellung (angedeutet):** Beim Start legt sich das **Tuch** über die ganze Leiche, auch über Gesicht und Hände (Modellwechsel auf `ph_prop_corpse_shrouded`). Die Figur beugt sich über den Tisch (`interact`). Ein leises **Werkzeuggeräusch** ist als Ton-Haken vorgesehen (`AnatomyConfig.sound_cue &"anatomy_tool"`; Agent 17 ist inaktiv, Phase 7 spielt nichts ab). Über 0,6 s wird der Bildschirm zu einem **dunklen Schleier** (85 %, `screen_veil_changed(true)`); nur der Aktionsbalken und eine Zeile bleiben lesbar: „Du ziehst das Tuch über sie und arbeitest, ohne hinzusehen." Bei Augen: „Du legst ihr ein Tuch über das Gesicht, bevor du anfängst." Bei der Hand: „Du schlägst sie in Leinen, bevor du sie ansiehst." Am Ende hebt sich der Schleier, das Tuch verschwindet, und es kommt die Zeile „Ein Glas mehr. Auf dem Etikett steht ihr Name." bzw. „Ein Bündel in Leinen. Es hält nicht lange." Kein Blut, keine Wunde, keine sichtbare Veränderung am Körper danach; die Leiche wird ohnehin eingekleidet bestattet.
- **Wirkung sofort:** Item ins Inventar (Einzelstück, §3.4), `record.harvested` + Organ (`CorpseRecord.HARVEST_KINDS` angehängt), Ruf `organ_taken` bzw. `organ_taken_grave` (Augen/Hand), Pietät nach Tabelle, `stats.specimens_taken` +1, Flag `piety_used_day`. Die Qualität erscheint beim Grabzeichen (`EconomyConfig.harvest_malus`). Kein „Voll hergerichtet"-Bonus für diese Leiche (Phase-5-Regel). Die Geisterstimmung sinkt je Organ nach Tabelle (`AnatomyConfig.organs[*].mood`).
- **Klarheit** = Frische der Leiche am Ende der Handlung (0,3…1,0), im Etikett als Wort: ≥ 0,8 „sehr gut" · ≥ 0,6 „gut" · ≥ 0,45 „trüb" · darunter „kaum lesbar".

**Glas oder Bündel – Verderben**
- **Glas** (`specimen_jar`): verschlossen, in Branntwein. Die Klarheit bleibt für immer.
- **Bündel** (`specimen_bundle`, in Leinen): Die Klarheit sinkt linear auf 0 in **600 Min** (10 h). Im **Kühlfach des Präparierpults** (§2.7) läuft die Zeit × **0,25** (≈ 40 h). Bei 0 ist es **verdorben**: nicht verkäuflich, nicht begutachtbar, nicht mehr einlegbar. Es bleibt nur das Zurücklegen ins Grab. Einmal je Bündel kommt die Notiz „Das Bündel von <Name> ist verdorben."
- **Einlegen** am Präparierpult (5 Min, 1 `prep_jar` + 1 `spirits`): Bündel → Glas mit der Klarheit dieses Augenblicks. Die **Hand** wird nicht eingelegt, sondern zum **Knochenpräparat** hergerichtet (§2.7, 60 Min) und verdirbt danach nicht mehr.
- Die Rechnung nutzt Fenster wie die Kühle der Gruft (`SpecimenRecord.cold_windows`, Faktor‰), rein aus der Minutendifferenz, Raster 1e-6.
- *Begründung:* Das Glas kostet 5 Münzen Ware (Glas 2 + Branntwein 3), das kleine Augenglas 6 (3 + 3). Das macht das Nehmen teuer und bewusst. Das Bündel ist der billige, eilige Weg und bestraft Eile mit Verfall, genau wie die Leichen selbst. Die Kälte der Gruft hilft auch hier, aber nur am Pult.

#### 2.6.1 Verkaufen an Quast (Wundarztstube, Panel `&"anatomist"`, Münzen sofort)
- Preis je Stück: `round(Grundpreis × (0,5 + 0,5 × Klarheit))`; Bündel × 0,5; Schaupräparat × 1,5 + 2; Knochenpräparat (Hand) = Grundpreis; dazu + **Ansehen bei der Universität** (§2.7, +1 je Stufe, höchstens +2) und Quast „Befreundet" +1. Beispiele (Grundpreise G7 Runde 2 angepasst): Herz im Glas bei 0,9 → 9 · Augen bei 0,8 → 10 · Leber-Bündel nach 3 h (0,63) → 2 · Hand als Knochenpräparat → 12 · Herz-Schaupräparat → ≈ 16.
- Folgen des Verkaufs (nur Beziehung, §2.4): Pfarrer −4, Liesel −3, Hagedorn −2, Quast +2 (Augen/Hand: Pfarrer −6, Liesel −5). Ruf und Pietät trugen schon das Nehmen. `stats.specimens_sold` +1. Das Präparat ist danach für immer fort (`state sold`); der Totenzettel vermerkt „an Quast verkauft".
- **Ilse nimmt keine Präparate** („Gläser nehme ich nicht. Was in Branntwein liegt, gehört schon dem Wundarzt."). Haar und Zähne bleiben bei ihr.

#### 2.6.2 Zurücklegen ins Grab („Präparat beisetzen")
- Am Grab des Toten (Zustand `FILLED` oder `MARKED`): „[E] Präparat beisetzen: Herz von Hedwig Lamprecht (10 Min)". Möglich für Glas, Bündel (auch verdorben), Schaupräparat, Knochenpräparat und Stücke aus der Sammlung (vorher herausnehmen). Nicht möglich nach Verkauf, Vorlesung oder Arznei.
- Wirkung: `record.returned` + Organ → der Geist zählt dieses Organ nicht mehr als „beraubt" (Stimmung zurück nach Tabelle), Pietät `specimen_returned` (+3, Augen/Hand +5), Pfarrer +1, Liesel +2, `stats.specimens_returned` +1. Die **Qualität bleibt** (der Stein steht schon, die Bezahlung ist geflossen), der Ruf auch. In der nächsten Nacht kommt eine Geisterzeile aus `by_returned`. Glas, Branntwein und Leinen sind verbraucht.
- *Begründung:* Phase 5 sagte: „Ein Stein gibt nicht zurück, was genommen wurde." Ein Präparat kann es. Das gibt dem Spieler, der aus Neugier oder Not genommen hat, einen würdigen Ausweg, der etwas kostet (Ware, Zeit, die entgangenen Münzen) und nicht alles heilt.

#### 2.6.3 Befunde (`SpecimenFindingData`) und verborgene Ursachen
- **Verborgene Ursachen** (✦ `CorpseTables.hidden_causes`, nur Zufallsleichen, deterministisch aus dem Seed): `fever` → `arsenic` mit 12 % · `drowned_millpond` → `dead_before_water` mit 15 % · `old_age` → `drink` mit 15 % (nur Stimmung, keine Geschichte). Ohne Deutung (§2.6.5) bleibt die angezeigte Ursache die von Osric.
- Ein Befund ist eine **Karte** („Befund-Karte"), die man durch **Begutachten** am Pult (§2.7) oder durch **Quasts Gutachten** erhält. Sie sagt, was zu sehen ist, nicht, was es bedeutet. Die Bedeutung findet der Spieler in der Deutung.
| Befund | Präparat · Bedingung | Karte (P4 darf glätten) |
|---|---|---|
| `b_still_heart` | Herz · gezeichnet (`strange_wound`) | „Ein gesundes Herz. Keine Narbe, kein Fett, keine Schwäche." |
| `b_old_heart` | Herz · `old_age` | „Ein großes, müdes Herz." |
| `b_white_stomach` | Magen · `arsenic` oder `poisoned` | „Ein weißlicher Belag. Es riecht nach Knoblauch." |
| `b_empty_stomach` | Magen · sonst | „Leer. Die letzten Tage kaum gegessen." |
| `b_dry_lungs` | Lunge · `dead_before_water` | „Die Lunge ist trocken." |
| `b_wet_lungs` | Lunge · `drowned_millpond` | „Die Lunge ist schwer von Wasser." |
| `b_spotted_lungs` | Lunge · `fever` | „Fleckig, mit kleinen dunklen Herden." |
| `b_hard_liver` | Leber · `drink` | „Hart und gelblich, mit kleinen Knoten." |
| `b_pale_liver` | Leber · `arsenic` oder `poisoned` | „Blass, mit feinen weißen Streifen." |
| `b_stones` | Nieren · Seed 1 von 4 | „Zwei Steine, so groß wie Erbsen." |
| `b_moor_eyes` | Augen · `moor_cold` oder `drowned_millpond` | „Die Augen sind trüb, mit einem braunen Schleier." |
| `b_fever_eyes` | Augen · `fever` | „Gelblich und glasig." |
| `b_worker_hand` | Hand · immer | „Schwielen an Daumen und Zeigefinger. Ein Handwerk." (Beruf aus dem Seed: Spinnerin, Schmied, Knecht, Wäscherin) |
| `b_oath_hand` | Hand · Merkmal `tattoo` | „Eine alte Schnittnarbe quer über der Handfläche." |
| `b_plain` | jedes · sonst | „Nichts Auffälliges." |

#### 2.6.4 Die Anatomie-Vorlesung (nachts in der Wundarztstube, `data/config/anatomy_config.tres` – Block `lecture`)
**Entscheidung: alle drei Nächte, in der Wundarztstube, bei verschlossenen Läden.** Quast unterrichtet heimlich drei Studenten aus der Stadt, die mit Osrics Morgenfuhre kommen und gehen. 1834 waren Leichen für den Unterricht knapp; das ist der Grund für die Heimlichkeit.
- **Wann:** an jedem Tag mit `Tag % 3 == 0`, von **23:00 bis 00:30** (`lecture_every_days 3`, `lecture_start 1380`, `lecture_minutes 60`). Die Haustür der Wundarztstube öffnet dann für den Totengräber (`HouseDoor.open_windows` + Bedingung `lecture_tonight`), sonst ist sie nachts zu. Quast steht am Behandlungstisch, drei Studenten sitzen auf zwei Bänken (`ph_chr_student_a/b/c`, ohne Rig, sitzend). Freigabe: `anatomy_known`, Quast mindestens „Bekannt" und das erste verkaufte oder begutachtete Präparat (dann lädt Quast ein: „Dienstags … nein, jeden dritten Abend. Kommen Sie nach elf. Klopfen Sie nicht.").
- **Ablauf:** Mit Quast sprechen → „Ein Präparat für heute Abend" → Präparat wählen (Glas, Knochen- oder Schaupräparat, Klarheit ≥ 0,5, nicht verdorben; **kein Bündel**) → TimedAction **60 Min** mit leichtem Schleier (60 %), Quast spricht zur Bank, das Glas steht auf dem Lesepult, der Behandlungstisch bleibt unter dem weißen Tuch leer. Höchstens **eine Vorlesung je Abend**.
- **Lohn:** **Honorar** 4 Münzen + Organzuschlag (Herz 2, Augen 3, Hand 4, sonst 1) + 1 je Stufe Ansehen bei der Universität. Dazu die **Mitschrift**: der **Lehrsatz** dieses Organs (§2.6.5) ins Merkbuch, wenn er noch fehlt, sonst eine Zeile Stimmung. Das Präparat bleibt im Kabinett (`state lectured`). `stats.lectures_attended` +1, Quast +3.
- **Kosten:** Pietät `lecture_attended` **−3** je Abend. **Entdeckung:** Mit 25 % (bei Ruf „Geschätzt" oder höher 10 %; deterministisch aus Tag und Seed) hat jemand Licht gesehen. Dann gibt es am nächsten Morgen Ruf `lecture_rumor` **−4**, Pfarrer −3, Liesel −2 und das Gerede „Bei Quast brannte wieder Licht bis nach Mitternacht." Vorher sagt Quast, ob die Nacht ruhig ist: „Der Nachtwächter ist heute bei seiner Schwester." (10/25 % stehen nicht im Text, nur die Stimmung).
- *Begründung:* Die Vorlesung bringt einem Präparat 5–9 Münzen statt 4–10 beim Verkauf, dazu Wissen für die Deutung. Sie kostet eine Nacht (30 Min Weg hin, 60 Min, 30 Min zurück, also ≈ bis 01:30) und Pietät, und sie ist ein Risiko für den Ruf. Alle drei Tage heißt höchstens ≈ 4 Abende in Bogen A: genug für die Lehrsätze, zu wenig für eine Einnahmequelle.

#### 2.6.5 Todesursachen-Deutung (Merkbuch, Panel `&"deduction"`, `data/anatomy/deductions/<id>.tres` – `DeductionData`, `data/anatomy/teachings/<id>.tres` – `TeachingData`)
**Entscheidung: Der Spieler deutet selbst, mit der Verknüpfen-Mechanik des Merkbuchs (Phase 4 §2.12).** Quast sagt nicht mehr „Arsenik", er zeigt, was zu sehen ist.
- **Karten:** *Befund-Karten* (§2.6.3, je Toter), *Funde* aus der Untersuchung (Phase 4, z. B. „Bläuliche Fingernägel", die bestehenden Ursachen-Details), *Lehrsätze* (Wissen, gespeichert) und eine Liste möglicher **Ursachen** (die sieben aus `CorpseTables` + `arsenic`, `dead_before_water`, `drink`, `unexplained` „kein natürlicher Tod").
- **Ablauf:** Merkbuch → Totenzettel → „Ursache deuten" (nur wenn der Tote mindestens eine Befund-Karte hat) → Karten wählen (2–3) und eine Ursache → **„Deuten"**. Stimmt die Menge (`DeductionData.needs` ⊆ gewählt, die Ursache stimmt), dann: wahre Ursache im Totenzettel („gedeutet: Arsenik"), Hinweis der Deutung ins Merkbuch, `stats.deductions` +1, Notiz „Du hast es selbst gesehen." **Falsch:** „Das passt nicht zusammen." – kostenlos, nicht gezählt, beliebig oft.
- **Lehrsätze** (`TeachingData`): `l_lung` „Wer ertrinkt, atmet Wasser." und `l_liver` „Der Trunk macht die Leber hart." gibt Quast mit dem Besteck. `l_heart` „Ein gesundes Herz bleibt nicht ohne Grund stehen." · `l_stomach` „Arsenik bleicht den Magen und riecht nach Knoblauch." · `l_kidneys` „Steine machen Schmerzen, aber selten den Tod." · `l_eyes` „Das Moor färbt die Augen." · `l_hand` „Die Hand erzählt das Handwerk." kommen aus der **Vorlesung** des jeweiligen Organs oder aus **Quasts Gutachten** (30 Min, das Präparat bleibt bei ihm, §2.7).

| Deutung | Karten (alle nötig) | Ursache | Ergebnis |
|---|---|---|---|
| `d_arsenic` | `b_white_stomach` **oder** `b_pale_liver`, `l_stomach` | `arsenic` | wahre Ursache; Hinweis `c_v_arsenic` „Arsenik im Fieber" (erstes Mal) |
| `d_dry_lungs` | `b_dry_lungs`, `l_lung` | `dead_before_water` | wahre Ursache; Hinweis `c_v_dry_lungs` „Trockene Lungen" (erstes Mal) |
| `d_still_heart` | `b_still_heart`, `l_heart`, Fund `f_mark` (Zeichen) | `unexplained` | Hinweis `c_v_still_heart` „Ein Herz ohne Krankheit"; Quast sagt danach: „Ich habe so ein Herz schon zweimal eingelegt. Beide Male lag morgens ein Zettel vor meiner Tür." |
| `d_drink` | `b_hard_liver`, `l_liver` | `drink` | wahre Ursache (Stimmung) |
| `d_moor` | `b_moor_eyes`, `l_eyes`, Ursache-Fund `f_cause_moor_cold` oder `f_cause_drowned_millpond` | (gezeigte Ursache) | bestätigt; bei S-Leichen nichts Neues (Flavor) |
- `c_v_arsenic` und `c_v_dry_lungs` bilden in Phase 7 **keine** Erkenntnis. Sie stehen unter „Offen" mit der Randnotiz „Im Dorf stirbt man nicht immer an dem, was Osric sagt." (Haken für Phase 9). `c_v_still_heart` führt zur optionalen Erkenntnis `i_burn_it` (§1.6).
- *Begründung:* Die Deutung nutzt das bestehende Verknüpfen (gleiche Fehlerregel, gleiche Darstellung) und macht die Anatomie zu Erkenntnis statt zu Ansage. Wer nie ein Präparat nimmt, verpasst nur Nebenfäden.

**Haken für Phase 13 (nur Daten, keine Logik):** `AnatomyConfig.organs[*].res_tag` und `res_weight` (Herz 3, Hand 3, Augen 2, sonst 1); die Hand ist als Knochenpräparat ausdrücklich „Lehrpräparat und Bauteil" markiert (`res_role &"frame"`). `Specimens.kept(organ) -> int` zählt gehaltene, nicht verdorbene Präparate, die Sammlung eingeschlossen. Keine Phase-7-Logik liest sie.

`AnatomyConfig` (Kurzform): `organs {heart, lung, stomach, liver, kidneys, eyes, hand: {label, containers, minutes, base_price, quality, reputation_event, piety, mood, return_piety, sell_rel {priest, washer, oldwoman}, lecture_bonus, res_tag, res_weight}}`, `max_per_corpse 3`, `tool_item &"anatomy_case"`, `room_id &"crypt"`, `min_freshness 0.3`, `jar_inputs {prep_jar: 1, spirits: 1}`, `small_jar_inputs {prep_jar_small: 1, spirits: 1}`, `bundle_inputs {linen: 1}`, `hand_inputs {linen: 1, beeswax: 1}`, `bundle_minutes 600`, `pult_cold_factor 0.25`, `clarity_words [0.8, 0.6, 0.45]`, `inspect_minutes 20`, `expertise_minutes 30`, `inspect_min_clarity 0.5`, `bundle_price_factor 0.5`, `display_price_factor 1.5`, `display_price_bonus 2`, `friend_price_bonus 1`, `return_minutes 10`, `seal_minutes 5`, `display_minutes 40`, `bone_minutes 60`, `veil_seconds 0.6`, `veil_alpha 0.85`, `sound_cue &"anatomy_tool"`, `known_flag &"anatomy_known"`, `lecture {every_days 3, start 1380, minutes 60, fee 4, standing_bonus 1, piety −3, rumor_chance 0.25, rumor_chance_esteemed 0.10, rumor_rep −4, rumor_rel {priest: −3, washer: −2}, veil_alpha 0.6}`.

### 2.7 Das Präparierpult in der Gruft: Arzneien, Sammlung, Kühlfach (`data/stations/pult.tres`, `data/recipes/*`, `data/anatomy/sets/<id>.tres` – `CollectionSetData`)
**Entscheidung: eine Station im Gruft-Raum statt eines neuen Gebäudes.** *Begründung:* Die Gruft ist kalt, still und hat schon Tisch, Waschbecken und Räucherschale. Das Pult gehört dorthin, wo die Präparate entstehen. Es braucht keinen neuen Bauplatz in der vollen Außenwelt, und die Phase-5-Station (`StationData` + `Workbench`, `requires_built`) trägt es ohne neue Mechanik.
- **Aufstellen:** „[E] Präparierpult aufstellen" am Platz `pult` in der Gruft (§4.6 P1), sichtbar ab `village_open` und Gruft ≥ 1: **6 wood, 2 iron_fittings, 2 stone + 12 Münzen** („Glaswaren und Wachstuch von Quast", Zweck `&"build"`), 90 Min. Danach stehen Pult, Kühlfach (Schieferlade) und daneben das **Sammlungsregal** (sieben Fächer hinter Tuchvorhängen).
- **Kräuter-Rezepte** (Werkstatt-Panel `&"crafting"`, Station `pult`; auch ohne Anatomie):
  | Rezept | Zutaten | Min | Ergebnis | Wofür |
  |---|---|---|---|---|
  | `fever_tincture` Fiebertinktur | 2 `herbs`, 1 `elderberries`, 1 `spirits` | 30 | 1 | Quast kauft 6; Aufträge Rosine, Quast |
  | `wound_salve` Wundsalbe | 1 `herb_bundle`, 1 `beeswax` | 20 | 2 | Theres kauft 4, Quast 5 |
  | `corpse_balm` Totensalbe | 2 `herbs`, 1 `beeswax` | 20 | 1 | wie Wacholder beim Räuchern (× 0,25, 18 h; `PrepConfig.balm_items` + `corpse_balm`), ohne Rauch |
- **Arzneien aus Präparaten** (Pult-Panel `&"pult"`, verbrauchen **ein** Einzelstück im Glas, Klarheit ≥ 0,45; nach „Quasts Rezeptbuch", das mit dem Besteck kommt). Die Herstellung wird nicht beschrieben, nur angesetzt und abgefüllt. Ergebnis sind beschriftete Fläschchen und Pulverbriefchen, ohne Bild und ohne Hinweis auf den Inhalt außer dem Etikett „nach Quast":
  | Rezept | Zutaten | Min | Ergebnis | Wirkung / Verwendung | Quast zahlt |
  |---|---|---|---|---|---|
  | `antidote` Gegengift | 1 Magen- **oder** Leberpräparat, 1 `herb_bundle`, 1 `spirits` | 30 | 2 | heilt Vergiftete in Aufträgen (`o_quast_antidote`) | 7 |
  | `bitter_drops` Bittertropfen | 1 Leberpräparat, 2 `herbs`, 1 `spirits` | 30 | 2 | stärker als die Fiebertinktur; ersetzt sie in jedem Fieber-Auftrag | 6 |
  | `dropsy_powder` Wassersuchtpulver | 1 Nierenpräparat, 1 `herbs`, 1 `beeswax` | 20 | 1 | `o_fenner_dropsy` (die Wassersucht des Schultheißen) | 8 |
  - Herz, Augen und Hand dienen keiner Arznei (`AnatomyConfig.organs[*].medicine false`). *Begründung:* Arzneien aus inneren Organen waren 1834 Apothekenpraxis (aus Tieren wie aus Menschen); was den Menschen ausmacht, bleibt davon ausgenommen. Die Arznei macht aus einem Präparat Hilfe für Lebende. Das ist der einzige Weg, auf dem das Nehmen einem Dorfbewohner nützt, und er zahlt besser als der Verkauf (2 Fläschchen ≈ 12–14 Münzen gegen ≈ 4–5), kostet aber Kräuter und Zeit.
- **Weitere Handgriffe am Pult** (Pult-Panel): „Bündel einlegen (5 Min)" · „Schaupräparat herrichten (40 Min)": Glas + 1 `beeswax` + 1 `ink` → `display_specimen` · „Knochenpräparat herrichten (60 Min)": Hand-Bündel + 1 `beeswax` + 1 `linen` → `bone_specimen` (verschnürtes Leinenpaket in einem Holzkasten mit Etikett, verdirbt nicht) · **„Präparat begutachten (20 Min)"**: Glas, Knochen- oder Schaupräparat mit Klarheit ≥ 0,5 → seine Befund-Karte (§2.6.3), das Stück bleibt.
- **Kühlfach** `PultStore` (`extends Chest`, 8 Plätze, Panel `&"chest"`): nimmt alles auf, was die Truhe nimmt; Bündel darin verderben × 0,25 (§2.6).

**Die Präparatesammlung** (Sammlungsregal `CollectionShelf`, Panel `&"collection"`)
- Sieben Fächer, **eines je Organ**. Ins Fach kommen Glas, Schau- oder Knochenpräparat (kein Bündel). Ein aufgestelltes Stück bleibt Eigentum und kann wieder herausgenommen werden (dann auch verkaufen, beisetzen …). In der Sammlung zählt es weiter als genommen: Der Geist bleibt beraubt.
- **Sätze** (`CollectionSetData`), je **einmal** belohnt, sobald alle Fächer des Satzes gleichzeitig belegt sind:
  | Satz | Fächer | Quast zahlt einmal („Die Universität zahlt für die Aufstellung.") | Ansehen bei der Universität |
  |---|---|---|---|
  | `set_chest` „Brustraum" | Herz, Lunge | 5 | +1 |
  | `set_body` „Leib" | Magen, Leber, Nieren | 6 | +1 |
  | `set_senses` „Sinne und Hand" | Augen, Hand | 8 | +1 |
  | `set_complete` „Lehrsammlung" | alle sieben, mindestens eines als Schaupräparat | 15 + Empfehlungsschreiben (`university_letter`, Haken Phase 9/10) | +1 (höchstens 4) |
- **Ansehen bei der Universität** (`stats.university_standing` 0…4, nie sinkend): +1 Münze je Stufe auf jedes verkaufte Präparat (höchstens +2) und +1 je Stufe auf das Vorlesungs-Honorar; ab Stufe 2 bietet Quast den Auftrag `o_quast_cabinet` an (§2.5). Das Regal wird in Quasts Gesprächen erwähnt („Man spricht in der Stadt von Ihrer Sammlung. Nicht laut.").
- *Begründung:* Eine volle Lehrsammlung braucht mindestens drei Leichen (je 3 Präparate) und bindet sieben Stücke, die nicht verkauft werden. Sie lohnt mit ≈ 34 Münzen einmalig und dem Ansehen. Wer sammelt, hat lange beraubte Geister. Die Sammlung ist das Ziel des anatomischen Weges, aber keine Goldgrube.

### 2.8 Neue Items
`ItemData` erhält **`unique: bool`** (✦, Standard false): Einzelstücke liegen je in einem eigenen Platz und tragen eine `uid` (§3.4).
| id | Name | Kategorie | Stapel | Herkunft | Zweck |
|---|---|---|---|---|---|
| `prep_jar` | Präparatglas | MATERIAL | 10 | Theres 2, Quast 2 | Präparat im Glas, Einlegen |
| `prep_jar_small` | kleines Präparatglas (dunkel, zwei Siegel) | MATERIAL | 10 | Quast 3 | nur für Augen |
| `spirits` | Branntwein | MATERIAL | 10 | Rosine 3, Quast 3 | Glas, Fiebertinktur, Geschenk (Quast) |
| `beeswax` | Bienenwachs | MATERIAL | 10 | Theres 1 | Salben, Schaupräparat |
| `anatomy_case` | Präparierbesteck | TOOL | 1 | Quast, einmalig (§2.12) | Präparate nehmen |
| `specimen_jar` | Präparat im Glas | GOODS, **unique** | 1 | Gruft-Tisch | §2.6 |
| `specimen_bundle` | Präparat im Bündel | GOODS, **unique** | 1 | Gruft-Tisch | §2.6, verdirbt |
| `bone_specimen` | Knochenpräparat (Hand, in Leinen verschnürt im Holzkasten) | GOODS, **unique** | 1 | Präparierpult | Verkauf 10, Sammlung, Vorlesung, Rückgabe; verdirbt nicht |
| `antidote` | Gegengift „nach Quast" | CRAFTED | 5 | Pult (Magen/Leber) | `o_quast_antidote`, Quast kauft 7 |
| `bitter_drops` | Bittertropfen „nach Quast" | CRAFTED | 5 | Pult (Leber) | ersetzt Fiebertinktur in Aufträgen, Quast kauft 6 |
| `dropsy_powder` | Wassersuchtpulver „nach Quast" | CRAFTED | 5 | Pult (Nieren) | `o_fenner_dropsy`, Quast kauft 8 |
| `display_specimen` | Schaupräparat | GOODS, **unique** | 1 | Präparierpult | §2.6 |
| `fever_tincture` | Fiebertinktur | CRAFTED | 5 | Pult | Verkauf, Aufträge |
| `wound_salve` | Wundsalbe | CRAFTED | 10 | Pult | Verkauf |
| `corpse_balm` | Totensalbe | MATERIAL | 10 | Pult | Konservieren (wie Wacholder) |
| `honey_cake` | Honigkuchen | GOODS | 10 | Theres 1 | Geschenk, `o_lenz_poor` |
| `elder_wine` | Holunderwein | GOODS | 5 | Rosine 2 | Geschenk (Esch, Lenz) |
- Einzelstücke dürfen in Truhe, Schuppen (nicht über „Überschuss einlagern": `ShedConfig.excluded_items` + die vier), Kühlfach und Sammlungsregal liegen. Das Etikett (Name, Organ, Klarheit) zeigt der Tooltip aus `Specimens`; alle Präparate teilen sich vier Item-Ids (`specimen_jar`, `specimen_bundle`, `display_specimen`, `bone_specimen`), das Organ steht im Record.

### 2.9 Der Lindenacker – neue Grabstellen, das Dorf als Quelle der Toten (`data/sections/linden.tres`, `data/clearables/*`, `data/story/d1_hagedorn.tres`)
**Entscheidung: Die Gemeinde gibt dem Friedhof ein neues Stück Land, den Lindenacker südlich der Ostwiese (8 Grabstellen), und der Pfarrer weiht ihn (Bestätigung §14.2).** *Begründung:* Nach Phase 6 ist der Friedhof wieder voll, es kommen keine Lieferungen (G6: Einnahmen nur Pflegegeld). Das Dorf ist die Quelle der Toten; der Engpass ist der Platz, nicht die Toten. Die bestehende Regel „eine Lieferung je freie Stelle" bleibt; neu ist, dass der Platz vom Dorf kommt: der Schultheiß gibt den Grund, der Pfarrer weiht ihn, die Toten des Dorfes kommen herauf. Der Lindenacker liegt **südlich**, also kameraseitig: Er verdeckt nichts, die Gräber sind niedrig, und hinter ihm liegt nur Wald (§4.6). Grabstellen um die Kapelle wurden geprüft und verworfen: Der Kirchhof ist zwischen Kapelle, Birken und Zaun höchstens 4 m breit, Phase 6 hat ihn als Vorplatz ohne Gräber freigegeben, und neue Steine dort würden den Kapellen-Sichttest gefährden.

| # | id | Name | Grabstellen | Freilegen (10 Hindernisse) | Voraussetzung |
|---|---|---|---|---|---|
| V | `linden` | **Lindenacker** | `l_01…l_08` (2 Reihen à 4) | 1× Pforte im Ostwiesen-Südzaun (`gate_small`, 10 Min), 4× Baumstumpf (`stump`, 30 Min, Axt-Faktor), 3× Brombeere (`bramble`, 40), 2× Feldsteinhaufen (`rubble`, 30) = **310 Min** | Hindernisse ab `linden_granted` (`SectionData.requires_flag`, Text vorher „Hier ist noch Gemeindewald."), Öffnung erst mit `linden_consecrated` (✦ `SectionData.unlock_flag`) |
- `is_burial true`, `counts_for_cemetery false` (die Phase-3-Vollendung bleibt bei Abschnitt I–III), `decor_cap 6`, `order 8`, 3 Pflegestellen + 8 Grab-Pflegestellen, Ruf `section_unlocked` +4 (bestehend) bei der Öffnung, Hinweis keiner.
- **Weihe:** Pfarrer Lenz im Gespräch: „Den Lindenacker weihen? (10 Münzen)" – bei „Vertraut" 5, bei „Befreundet" umsonst (Zweck `&"consecration"`). Setzt `linden_consecration_day` = morgen. Am Weihetag kommt er um 09:20 den Kutschweg herauf (Npc `npc_priest` in der Friedhofs-Region, Einträge mit `today_flag`, §3.4) und steht bis 10:30 an der Lindenacker-Pforte mit Brevier (`bless` = `talk`). Ist der Spieler da, spricht er (`priest_linden`): „Ich segne die Erde, nicht die Arbeit. Die Arbeit segnest du selbst, jeden Tag ein bisschen." Um 10:30 ruft `Village.consecrate()`: Flag `linden_consecrated`, `ground_consecrated(&"linden")`, Notiz „Der Lindenacker ist geweiht." Die Weihe geht auch, bevor geräumt ist („Gott sieht durch Brombeeren."); geöffnet wird der Abschnitt, sobald beides gilt (`ExpansionManager.try_unlock`).
- **Lieferungen:** ab der Öffnung wie bisher (eine je freie Stelle, Osric 07:40). 8 Stellen tragen ≈ 8 Tage. **Eine Stelle bleibt für D1 reserviert**, bis Wiebke Hagedorn bestattet ist (bestehende Reservierungsregel aus Phase 4 §2.11, jetzt mit `StoryCorpseData.section &"linden"`).
- **Trauerflor (nur Darstellung):** An einem Liefertag hängt ab 06:00 an einem der sechs Wohnhäuser des Dorfes ein schwarzes Band an der Tür (`VillageConfig.mourning_houses`, deterministisch aus Tag und Leichen-Seed), bis die Leiche bestattet ist. Osric im Dorf: „Bei den Kehrs hängt der Flor. Ich hab sie dir heute früh gebracht."
- **D1 Wiebke Hagedorn** (Geschichts-Leiche, `d1_hagedorn`, Reihenfolge 6 nach S1–S5): `old_age`, Merkmal `strange_wound`, Look alte Frau (1) mit Mohnsträußchen (Kindmesh `poppy` am bestehenden Modell, §8), keine Wertsachen. Fällig frühestens **8 Tage nach `village_open`** (✦ `StoryCorpseData.after_flag &"village_open_day"`, `after_days 8`), nur mit `linden_consecrated`. Ab 00:00 des Liefertags: Flag `hagedorn_dead` (ihr Npc verschwindet), Trauerflor an ihrer Kate. Osric bei Ankunft: „Die alte Hagedorn. Heute Nacht, im Schlaf, sagt Liesel. Sie hat mir letzte Woche aufgetragen, dir auszurichten: nicht trödeln. Ich richte es aus." Funde: `f_d1_poppy` (Kleidung, 0,0) „Getrockneter Mohn am Mieder, mit einem roten Faden gebunden." · `f_d1_mark` (Wunden, 0,3, **ersetzt** `f_mark`) „Das Zeichen über ihrem Herzen ist frisch verheilt. Drei Wochen, nicht mehr. Sie hat es gewusst." → `c_v_hagedorn` · `f_d1_note` (Taschen, 0,0) „In der Schürze ein Zettel: ‚Für den Totengräber. Linde, Mohn, Totenhemd. Und schau nach, wer mich besucht hat. – W. H.'" Geist (zufrieden/gleichmütig, `by_story`): „Mit Blick auf die Linde. Wie abgemacht." · „Du hast nachgesehen, wer mich besucht hat? Gut. Ich hab's nämlich vergessen."
- **Ohne Phase 7** (kein Gang ins Dorf) bleibt der Lindenacker Wald und die Lieferungen ruhen wie in G6. Das ist gewollt: Das Dorf ist der Weg zu neuen Toten.

### 2.10 Münzrechnung (würdevoller Spieler, Bogen A)
**Ausgangslage (G6, `qa_playthrough.md`):** `reverent6` endet mit **20** Münzen (Tag 39 abends; den Morgenstand der v5-Fixture misst W0). Einnahmen nur Pflegegeld 4/Tag. Phase 6 hat den Beutel fast leer gemacht. Phase 7 bringt **neue Einnahmen** (Bestattungen im Lindenacker, Aufträge, Verkäufe im Dorf) und **neue Ausgaben**, die überwiegend freiwillig und sozial belohnt sind (Runden, Geschenke, Spenden-Aufträge) oder Phase-6-Stufen 3 nachholen, die `reverent6` nicht bezahlen konnte.

| Einnahmen (13 Tage) | Rechnung | Münzen |
|---|---|---|
| Start (B1 früh) | W0-Messung | ≈ 20 |
| Pflegegeld | 12 × 4 (B2–B13) | 48 |
| Bestattungen im Lindenacker | 8 × ≈ 13 (G6: 13,4 je Grab mit Stele) | 104 |
| Aussegnungsgebühren | 4 × 5 (Kapelle 2) | 20 |
| Aufträge (`neighbor7`: 10 Aufträge + Lindenacker, davon 2 Spenden; G7 Runde 2 angepasst) | 6 (Lindenacker) + 6 + 6 + 6 + 7 + 10 + 4 + 7 + 8 + 0 + 0 | 60 |
| Verkäufe im Dorf (Beeren, Kräuter, Salben, Totenhemden) | gedeckelt je Tag (§2.3) | 12 |
| Geistergaben | ≈ 3 × 3 (Andächtig) | 8 |
| **Verfügbar** | | **≈ 277** |

| Ausgaben | Münzen |
|---|---|
| Weihe des Lindenackers (**Pflicht** fürs Kapitel) | 10 |
| Präparierpult (für die Tinkturen) | 12 |
| Spenden-Aufträge (Brücke 20, Armenspeisung 12) | 32 |
| Dorfwaren (Branntwein, Wachs) · Geschenke · 2 Runden | 14 · 14 · 10 |
| Altarkerzen · Leinen und Blattgold für Hemden und Steine · Eisen beim Schmied | 8 · 22 · 12 |
| Freiwillig: **Kapelle 3** (B8) und **Gruft 3** (B12) aus Phase 6 | 40 + 35 |
| Kleinkram | 5 |
| **Summe** | **214 (77 %)** |

| | B1 | B2 | B3 | B4 | B5 | B6 | B7 | B8 | B9 | B10 | B11 | B12 | B13 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Morgens (+4 ab B2) | 20 | 25 | 25 | 31 | 44 | 44 | 59 | 70 | 45 | 67 | 80 | 92 | 65 |
| Ausgaben | 0 | 10 | 0 | 8 | 20 | 12 | 8 | 52 | 10 | 12 | 30 | 40 | 12 |
| Einnahmen (ohne Pflegegeld) | 1 | 6 | 2 | 17 | 16 | 23 | 15 | 23 | 28 | 21 | 38 | 9 | 10 |
| Abends | 21 | 21 | 27 | 40 | 40 | 55 | 66 | 41 | 63 | 76 | 88 | 61 | 63 |
- Morgens nie unter **20** (B1). Pflicht ist nur die Weihe (10). Ohne die zwei Stufen 3 endet der Bogen bei ≈ 138, mit ihnen bei ≈ 63.

**Nachmessung G7 Runde 2 (angepasst, B7-2):** Die Bots lagen mit den W0-Werten bei **91** (`neighbor7`) und **107** (`anatomist7`) – mehr Auftragslöhne und Dorfverkäufe als gerechnet, dazu billige Weihe und keine Spende, weil der Ruf-Bonus +10 Fenner und Lenz sofort „Vertraut" machte. Geändert (alle Werte in `data/`): Ruf-Startbonus [0, +2, +4, +6, +8] (§2.1); Auftragslöhne (§2.5) `o_rosine_tincture` 8→6, `o_esch_stone` 10→8, `o_mangold_stone` 12→10, `o_lenz_service` 6→4, `o_quast_tincture` 10→7, `o_quast_antidote` 12→9, `o_fenner_dropsy` 10→8, `o_quast_cabinet` 14→11, `o_liesel_gowns` 8→6, `o_hagedorn_place` 10→6, Tafel `ob_wood` 5→4, `ob_stone` 5→3, `ob_herbs` 8→6, `ob_yarn` 5→3, `ob_gown` 4→3, `ob_tend` 5→4; dafür `o_fenner_linden` 0→**6** (Rodungslohn: der erste Dorftag kostet jetzt Weihe 10 und eine Spende für die Abschrift, sonst fällt der Morgen B2 unter 5); Quast zahlt für Herz/Augen/Hand **9/11/12** statt 7/9/10 (§2.6, der anatomische Weg kauft Glas, Branntwein und Leinen). Gemessen (13 Tage, `tests/integration/test_phase7_playthrough.gd`):

| Bot | Kapitel | Einnahmen | Ausgaben | Ende | Ziel | morgens min. | Aufträge |
|---|---|---|---|---|---|---|---|
| `neighbor7` | Tag 50 (B11) | 318 | 278 | **60** | ≈ 63 (−5 %) | 12 | 11 (7 Geber) |
| `anatomist7` | Tag 50 (B11) | 381 | 330 | **71** | ≈ 77 (−8 %) | 13 | 13 (7 Geber) |
| `save_load7` | = `neighbor7` | | | 60 | | 12 | |

Abstand anatomisch − würdevoll **+11** (Ziel ≈ +14; der Bot `anatomist7` bezahlt dabei die Brücken-Spende, 20). Morgens nie unter 5 (G7 Runde 2; vorher Ziel 20).
- *Warum die Pflicht so klein ist:* Das Dorf verkauft keine Gebäude. Seine Senke sind Dinge mit sozialem Lohn (Runde, Spende, Geschenk: Beziehung und Ruf, nie Münzen) und die Ware, die das Handwerk braucht. Ein knapper Spieler kann das alles lassen und kommt trotzdem ans Kapitel; ein voller Beutel hat jetzt Orte, an denen er sinnvoll leer wird. Eine echte Preisdynamik bleibt Phase 10 (G5-Befund E5, GP-03).

**Andere Wege (Erwartung für W3)**
| Weg | Start | Einnahmen | Ausgaben | Ende (≈ 13 Tage) | Bemerkung |
|---|---|---|---|---|---|
| anatomisch (`anatomist7`, v5 reverent) | ≈ 20 | ≈ 337 (Rechnung unten) | ≈ 280 | ≈ 77 | +≈ 14 gegenüber A (≈ 5 % des Umsatzes), dafür Pietät Hartherzig, Ruf eine Stufe tiefer, Pfarrer und Liesel „Fremd", alle Lindenacker-Geister unruhig außer Hagedorn |
| forschend (`scholar7`, v5 mender) | ≈ 41 | wie A + 4 Vorlesungen (≈ 34) + Arznei-Aufträge (22) | wie A + Ware ≈ 60 | ≈ 70–100 | Herzen, Lebern und Mägen im Glas, alles begutachtet und gedeutet, zwei Präparate zurückgelegt; `i_burn_it` und `c_v_arsenic`/`c_v_dry_lungs` je nach Seed |
| reuig (`penitent7`, v5 harvester) | ≈ 63 | wie A, Ruf niedriger | Spenden 10/Tag, Runden, Geschenke | ≈ 20–60 | Ruf steigt über die Armenkasse; keine Präparate |
| neues Spiel (`founder7`, v5 founder) | ≈ 40 | wie A | wie A | ≈ 40–90 | Kapitel ≤ Tag 50 |

**Anatomischer Weg nachgerechnet (`anatomist7`, Neuberechnung nach §14.3)** – 8 Lieferungen, davon 7 mit je **3 Präparaten** (Herz, Augen, Hand; D1 Hagedorn bleibt unverwertet), 21 Stück: 10 an Quast verkauft, 7 in der Sammlung (Sätze „Brustraum" und „Sinne und Hand", Ansehen 2), 4 in Vorlesungen.
| Posten | würdevoll (A) | anatomisch | Unterschied |
|---|---|---|---|
| Pflegegeld (Ruf sinkt von Gerühmt auf Geachtet/Geschätzt) | 48 | ≈ 30 | −18 |
| Bestattungen (Qualität −8 je Leiche → −4, Ruf-Bonus 3 → 1) | 104 | ≈ 62 | −42 |
| Aussegnungsgebühren | 20 | 20 | 0 |
| Aufträge (Pfarrer- und Liesel-Aufträge seltener, dafür Quast-Aufträge) | 65 | ≈ 70 | +5 |
| Präparate verkauft (10 × ≈ 10, Ansehen +2) | – | ≈ 100 | +100 |
| Vorlesungen (4 × (4 + Organzuschlag + Ansehen 2) ≈ 4 × 9) | – | ≈ 36 | +36 |
| Sammlungs-Sätze (5 + 8) | – | 13 | +13 |
| Verkäufe im Dorf, Geistergaben | 20 | ≈ 6 | −14 |
| **Einnahmen** | **257** | **≈ 337** | +80 |
| Ware fürs Nehmen (7 × Augenglas 6 + 7 × Glas 5 + 7 × Hand-Bündel und Knochen 8) | – | ≈ 133 | −133 |
| übrige Ausgaben (wie A, ohne Spenden-Aufträge und ohne Gruft 3) | 214 | ≈ 147 | +67 |
| **Ende** | **≈ 63** | **≈ 77** | **+≈ 14** |
- **Je Leiche** bringt der würdevolle Weg ≈ 19 Münzen (Bestattung 13, Gebühr 5, Gabe 1), der anatomische ≈ 22 (Bestattung 7, Gebühr 5, Präparate netto ≈ 10). Über den Bogen frisst der Ruf-Verlust (Pflegegeld, Bezahlung) den größten Teil des Präparat-Erlöses wieder auf. *Das Ziel ist erfüllt:* Die Anatomie ist kein dominanter Verdienst (≈ +5 % über den Bogen). Bündel statt Gläser würden mehr abwerfen, verderben aber in 10 h, und die Grenze von 3 Präparaten je Leiche deckelt alles. Würdevoll bleibt gleichwertig bezahlt und kostet keine Pietät.
- **Arzneien** sind die beste Verwertung eines Präparats (ein Leberglas → 2 Bittertropfen ≈ 12 Münzen oder ein Auftrag), kosten aber Kräuter und 30 Min. W3 prüft, dass `scholar7` damit nicht über `neighbor7` + 40 kommt; sonst senkt P7 die Quast-Preise der Arzneien um 1.

### 2.11 Qualität, Ruf, Pietät, Geister, Statistik
- `EconomyConfig.harvest_malus` + `heart −2`, `lung −2`, `stomach −2`, `liver −2`, `kidneys −2`, `eyes −3`, `hand −3`. `quality_max` bleibt **20**. Zurücklegen ändert die Qualität nicht.
- `ReputationConfig.event_points` + `organ_taken −3`, `organ_taken_grave −5` (Augen, Hand), `lecture_rumor −4`, `donation 1`, `order_failed −1`. Erledigte Aufträge geben `OrderData.reward_rep` mit dem Grund „Auftrag: <Titel>".
- `PietyConfig.events` + `lecture_attended −3`, `specimen_returned +3`, `specimen_returned_grave +5`; die Pietät je Organ steht in `AnatomyConfig.organs[*].piety` (Herz −8, innere Organe −6, Augen/Hand −12) und läuft über `Piety.event(&"organ_taken", …, amount)`. Die tägliche Erholung (Phase 4) bleibt; Nehmen und Vorlesung setzen `piety_used_day`.
- `GhostMood`: Der Beraubt-Abzug ist jetzt die Summe über die genommenen, nicht zurückgelegten Arten (✦ `GhostMood.robbed_penalty(record)`): Haar/Zähne je −5 (`robbed_mood`, unverändert), Organe nach `AnatomyConfig.organs[*].mood` (−5, Augen/Hand −8). Stücke in der Sammlung zählen als genommen. Neuer Grund-Text-Pool `GhostLines.by_organ` (Vorrang vor `robbed`, wenn ein Organ fehlt): „In mir ist eine Stelle, die nicht mehr warm wird." · „Mein Name steht auf einem Etikett. Wer liest ihn?" · „Sie haben mich in der Stadt in ein Regal gestellt. Ich kann die Linde nicht sehen." · Augen: „Ich sehe die Linde nicht mehr. Ich weiß nur, dass sie da ist." · Hand: „Ich greife nach etwas und weiß nicht, womit." `GhostLines.by_returned` (erste Nacht danach): „Es ist wieder da. Ich spüre es nicht, aber ich weiß es." · „Du hast zurückgebracht, was du genommen hast. Das tun nicht viele."
- `GameState.DEFAULT_STATS` + `village_trips`, `orders_done`, `orders_failed`, `gifts_given`, `rounds_bought`, `donations`, `specimens_taken`, `specimens_sold`, `specimens_researched`, `specimens_returned`, `specimens_collected`, `medicines_made`, `lectures_attended`, `deductions`, `university_standing`, `coins_spent_village`, `coins_spent_donation`, `coins_spent_round`, `coins_spent_consecration`.
- `coins_spent`-Zwecke + `&"village"` (Läden), `&"donation"` (Armenkasse, Spenden-Aufträge), `&"round"`, `&"consecration"`. Das Pult läuft unter `&"build"` (Phase-5-Station).

### 2.12 Osric, Ilse und die Freischaltung der Anatomie
- **Osric** (`carter.tres` + neuer Dialog `carter_village`, P6): Friedhof: `p7_intro` (§1.2), danach Menüpunkt „Wie ist es unten im Dorf?" (wechselnd nach Beziehungen). Dorf (Remise, Gaststube): stellt am ersten Treffen vor („Das ist Rosine, der gehört der Holderkrug und das halbe Dorf, wenn man sie reden lässt."), spendiert das versprochene Bier (Notiz, keine Wirkung), erzählt vom Trauerflor, kommentiert Präparate einmal je Stufe („Der Quast fährt jetzt öfter mit mir in die Stadt. Seine Kisten klirren."). Keine Beziehung in Phase 7.
- **Quast und das Besteck:** Beim ersten Gespräch in der Wundarztstube (Knoten `v_surgeon_intro`): „Sie haben, was mir fehlt, Totengräber: Zeit mit den Toten, bevor die Erde sie nimmt. Die Stadt zahlt für Präparate. Ich zahle Ihnen davon, was recht ist." Wahl: **„Zeigen Sie mir, wie." → `anatomy_case` geschenkt, Flag `anatomy_known`** · „Nein. Die bleiben, wie sie sind." → Flag `anatomy_declined` (er fragt nach 3 Tagen noch einmal, danach nie wieder von sich aus; der Menüpunkt „Ich habe es mir überlegt." bleibt). Ohne Besteck gibt es keine Präparate-Karte. Mit dem Besteck kommen **Quasts Rezeptbuch** (die drei Arzneien, §2.7) und die Lehrsätze `l_lung` und `l_liver` (§2.6.5). Nach dem ersten verkauften oder begutachteten Präparat lädt er zur **Vorlesung** ein (§2.6.4). *Begründung:* Wie Ilses Werkzeug (Phase 4) ist die dunkle Möglichkeit ein Angebot, kein Zwang.
- **Ilse** (`trader.tres`, P6), neue Fragen ab `village_open`: „Wer besucht im Dorf die Kranken?" (nach dem ersten Gespräch mit Quast) → Antwort §1.6 → `c_v_three_visitors` · „Was hältst du vom Wundarzt?" → „Quast kauft, was ich nicht nehme, und schreibt alles in ein Buch. Lorenz hat ihn einmal gefragt, wohin die Gläser gehen. Danach hat Quast ihm nichts mehr verkauft." · nach dem ersten verkauften Präparat (Begrüßung, einmal): „Du warst beim Wundarzt. Man riecht den Branntwein durch das Leinen."

---

## 3. Architektur

### 3.1 Neue Knoten
**Systemknoten** (unter `WorldRoot/Systems`, vom Welt-Builder angelegt):
| Knoten | Klasse | Gruppen | save_id / save_order |
|---|---|---|---|
| `Village` | `Village` | `village`, `saveable` | `village` / **50** |
| `Relationships` | `Relationships` | `relationships`, `saveable` | `relationships` / **51** |
| `VillageShops` | `VillageShops` | `village_shops`, `saveable` | `village_shops` / **52** |
| `Orders` | `Orders` | `orders`, `saveable` | `orders` / **53** |
| `Specimens` | `Specimens` | `specimens`, `saveable` | `specimens` / **54** |
| `Lectures` | `Lectures` | `lectures`, `saveable` | `lectures` / **55** |
| `Deductions` | `Deductions` | `deductions`, `saveable` | `deductions` / **56** |
| `NpcLod` | `NpcLod` | `npc_lod` | – (nicht gespeichert) |

**Regionen** (§3.4, §4.1): `WorldRoot/Regions/Graveyard` (`RegionRoot`, region_id `graveyard`, verwaltet die bestehenden Außenknoten über `managed_paths`, verschiebt nichts) und `WorldRoot/Regions/Village` (Instanz von `src/world/village/village.tscn`, `RegionRoot`, region_id `village`, Ursprung **(0, 0, 400)**). In der Dorf-Szene: `Ground`, `Decor`, `Buildings`, `Entities` (8 `Npc` der Dorfbewohner + `npc_carter_v`, `HouseDoor` × 3, `ShopCounter` × 2, `VillageBoard`, `RegionPortal` `road_out`, `MourningRibbon` × 6), `Waypoints`, `Colliders`, `Lights`. **Friedhof:** `Entities/road_exit` (`RegionPortal`), `Entities/npc_priest` (`Npc`, Weihetag), Abschnitt `linden` mit Plots und Hindernissen, `Interiors/InnInterior|SurgeryInterior|OfficeInterior` (`InteriorRoom`, `region_id village`; in der Wundarztstube `LectureSet` mit drei Studenten und Lesepult), im Gruft-Raum `pult` (`Workbench`, Station `pult`) + `PultStore` (saveable `pult_store` / **62**) + `CollectionShelf` (saveable `collection_shelf` / **63**). Keine neuen Autoloads.

### 3.2 Module & Besitz (Phase 7)
| Modul | Besitzt (Pfade) |
|---|---|
| **Lead** (W0 + laufend) | `project.godot`, `src/core/*` (EventBus, Database), alle **Datenklassen ✦**, alle **Stubs** (bis zur Übergabe), `tests/run_tests.gd`, `tests/framework/*`, `tests/fixtures/*` (inkl. **`saves_v5/*`**, `phase7/*`), `tests/integration/test_saves_v5_load.gd`, `tests/unit/test_phase7_scaffold.gd`, `docs/*`, `CLAUDE.md` |
| **P1 Regionen, Portale & NPC-Last** | `src/world/regions/{region_root,region_portal,region_travel}.gd` (neu), `src/entities/house_door/*` (neu), `src/entities/region_portal/*` (neu, Szene), `src/world/interiors/{interior_room,room_exit}.gd` (nur `region_id` / `door_id`), `src/world/hut_interior/hut_portal.gd` (nur Durchreichen), `src/world/camera/camera_rig.gd` (`set_base_profile`), `src/entities/player/player.gd` (nur `region_id`, `set_region`, Speichern), `src/entities/npc/{npc,npc_pose}.gd` (`region_id`, `hide_flag`, LOD), `src/systems/npc/{schedule_resolver,npc_lod}.gd`, `data/config/npc_config.tres`, `data/config/regions/*`, `tests/unit/{test_regions,test_npc_lod,test_schedule_resolver,test_house_door}.gd`, `tests/integration/test_region_travel.gd` |
| **P2 Läden & Beziehungen** | `src/systems/village/{village_shops,shop_rules,relationships,relationship_rules}.gd`, `src/entities/shop_counter/*`, `data/shops/*`, `data/village/villagers/*`, `data/config/relationship_config.tres`, `tests/unit/{test_village_shops,test_relationships}.gd` |
| **P3 Aufträge & Dorf-Fortschritt** | `src/systems/village/{orders,order_rules,village}.gd`, `src/entities/{village_board,mourning_ribbon,poor_box,register_copy}/*`, `data/orders/*`, `data/config/{orders_config,village_config}.tres`, `data/sections/linden.tres`, `data/clearables/*` (nur neue Einträge), `src/systems/expansion/expansion_manager.gd` (nur `unlock_flag`, `try_unlock`), `src/systems/graveyard/graveyard.gd` (nur `replace_old_marker` und die Aufrufe `Orders.note_grave_completed`/`note_stone_set`), `src/systems/stone/stonemasonry.gd` (nur Steine für Ruhezeit-Gräber mit Auftrag: `ready_for` gilt auch für sie), `tests/unit/{test_orders,test_village,test_expansion}.gd` |
| **P4 Anatomie-Kern & Präparate** | `src/systems/anatomy/{specimens,specimen_rules,specimen_record}.gd` (neu), `src/systems/corpse/{corpse_care,corpse_generator,corpse_record}.gd` (Präparate-Karte mit sieben Organen, Grenze 3, Behältnis-Regeln, `hidden_cause`, `returned`), `src/entities/morgue_table/morgue_table.gd` (`request_organ`, Tuch, Schleier, Ton-Haken), `src/entities/corpse/corpse.gd` (nur `set_covered`), `src/entities/grave/grave_plot.gd` (beide neuen Prompts: „Präparat beisetzen" und „Neuen Stein setzen" auf Ruhezeit-Gräbern gegen die P3-API), `src/systems/inventory/inventory.gd` + `src/ui/panels/chest_transfer.gd` (nur Einzelstücke), `src/systems/ghosts/{ghost_mood,ghost_manager}.gd` (`robbed_penalty`), `data/config/{anatomy_config,economy_config,reputation_config,piety_config}.tres`, `data/anatomy/findings/*`, `data/ghosts/ghost_lines.tres`, `data/corpses/corpse_tables.tres` (nur `hidden_causes`), `tests/unit/{test_specimens,test_inventory_unique,test_anatomy_harvest,test_ghosts,test_corpse_generator}.gd` |
| **P5 Assets** | `tools/blender/{asset_village_buildings,asset_village_props,asset_village_interiors,asset_villagers,asset_anatomy}.py` (neu), `tools/blender/asset_items.py`, `tools/blender/build_all.py`, `assets/models/**` (nur neue Phase-7-Dateien), `art_source/blender/**` (Phase 7), `tests/unit/test_assets_phase7.gd`, `docs/reviews/phase7_assets/*` |
| **P6 Dialog, Geschichte & Speichern** | `data/dialogue/{carter,trader}.tres`, `data/dialogue/v_*.tres` + `carter_village.tres` + `priest_linden.tres` (neu), `data/npc/*_schedule.tres` (neue + Osrics Dorf-Einträge), `src/systems/dialogue/{dialogue_conditions,dialogue_actions}.gd`, `src/systems/story/{story_director,story_corpse_data}.gd` (nur `after_flag`/`after_days`/`section`-Logik), `data/story/d1_hagedorn.tres`, `data/finds/f_d1_*.tres`, `data/journal/{clues,insights}/*` (Phase 7), `src/systems/save/{save_migration,save_file_io,save_manager}.gd`, `src/systems/game_state/game_state.gd` (Stats), `tests/unit/{test_dialogue,test_save,test_save_migration,test_story,test_journal,test_game_state}.gd`, `tests/integration/test_phase6_save_upgrade.gd` |
| **P7 Präparierpult: Arzneien, Sammlung, Kühlfach** | `data/stations/pult.tres`, `data/recipes/{fever_tincture,wound_salve,corpse_balm}.tres`, `data/items/*` (Phase-7-Items), `src/systems/anatomy/{pult_rules,collection_rules}.gd` (neu: Arzneien, Einlegen, Schau-/Knochenpräparat, Begutachten, Sätze), `src/entities/{pult_store,collection_shelf}/*` (neu, `extends Chest`), `data/anatomy/{medicines,sets}/*`, `src/systems/workshop/workshop.gd` (nur Station im Innenraum, falls nötig), `data/config/{prep_config,shed_config}.tres` (`corpse_balm`, Ausschlüsse), `tests/unit/{test_pult,test_recipes_phase7,test_medicines,test_collection}.gd` |
| **P8 Vorlesung & Deutung** | `src/systems/anatomy/{lectures,lecture_rules,deductions,deduction_rules}.gd` (neu), `src/entities/lecture_set/*` (neu, Studenten wie `MournerSet`), `data/anatomy/{teachings,deductions}/*`, Block `lecture` in `data/config/anatomy_config.tres` (Werte; Datei P4, Abstimmung über den Lead), `tests/unit/{test_lectures,test_deductions}.gd`, `tests/integration/test_lecture_night.gd` |
| **W-Welt** (W2) | `data/world/village_layout.json`, `data/world/interiors/{inn,surgery,office}_layout.json`, `data/world/interiors/crypt_layout.json` (nur Pult-Platz), `src/world/village/*` (neu: `village_build.gd`, `village_builder.gd`, `village.tscn`, `village_shots.gd`), `src/world/interiors/*` + `{inn,surgery,office}_interior.tscn`, `data/world/graveyard_layout.json` (Lindenacker, Wegstein, Bäume, Regionen §4.6), `src/world/graveyard/*` (neu `graveyard_build_phase7.gd`, `graveyard_shots_phase7.gd`, Gras/Maske neu gebacken), `tools/blender/asset_ground_village.py` (neu), `tests/integration/{test_village_world,test_graveyard_world,test_phase7_loop,test_interiors}.gd`, `docs/reviews/phase7_round1/*` |
| **W-UI** (W2) | `src/ui/**` (neu `panels/{shop_panel,anatomist_panel,orders_panel,gift_panel,pult_panel,collection_panel,deduction_panel,lecture_panel}.gd`, `hud/{region_label,veil,remark_bubbles}.gd`, `phase7_texts.gd`; Präparate-Karte in `corpse_exam_tabs.gd`/`corpse_exam_sections.gd`; Merkbuch-Seiten „Aufträge" und „Hollerbrück", „Ursache deuten" am Totenzettel), `assets/ui/**`, `tools/ui/*`, `src/debug/*` (neu `debug_commands_phase7.gd`; außer `asset_preview.gd`, `screenshot_capture.gd`), `tests/unit/{test_ui,test_objective,test_ui_phase7}.gd`, `tests/integration/test_ui_flow.gd` |
| **W3 QA** | `tests/integration/{phase3_bot,…,phase6_bot,phase7_bot,test_phase7_playthrough,test_phase7_qa,test_save_fuzzer}.gd`, `docs/reviews/phase7_wip/*` |
| **Eingefroren** | `src/world/art_prototype/*`, `src/entities/player/player_proto.*`, `data/art_prototype/*`, **Maler-Shader**, `data/atmosphere/*`, Hütte, Werkbank, Stationen, Pförtchen, Ostpforte, Kirchpforte, alle Phase-6-Gebäude und ihre Räume (außer dem Pult-Platz in der Gruft), Abschnitte I–IV, Werkhof, Kirchhof im Layout (außer §4.6) |

✦ **Datenklassen (W0, Lead):** `RegionConfig`, `NpcConfig`, `VillagerData`, `ShopData`, `RelationshipConfig`, `VillageConfig`, `OrderData`, `OrdersConfig`, `AnatomyConfig`, `SpecimenFindingData`, `SpecimenRecord`, `MedicineData`, `CollectionSetData`, `TeachingData`, `DeductionData`. Erweiterungen: `ScheduleEntry` (+ `region`, `today_flag`), `ItemData` (+ `unique`), `SectionData` (+ `unlock_flag`), `StoryCorpseData` (+ `after_flag`, `after_days`, `section`, `requires_flag`, `due_flag`), `CorpseRecord` (+ `hidden_cause`, `returned`, `revealed_cause`; `HARVEST_KINDS` + `heart`, `lung`, `stomach`, `liver`, `kidneys`, `eyes`, `hand` angehängt), `CorpseTables` (+ `hidden_causes`), `EconomyConfig.harvest_malus` (+ 7), `ReputationConfig.event_points` (+ `organ_taken`, `organ_taken_grave`, `lecture_rumor`, `donation`, `order_failed`), `PietyConfig.events` (+ `organ_taken`, `lecture_attended`, `specimen_returned`, `specimen_returned_grave`), `GhostLines` (+ `by_organ`, `by_returned`), `PrepConfig.balm_items` (+ `corpse_balm`), `InteriorConfig` unverändert.
Bei nur fünf Agents übernimmt P2 zusätzlich P7, P3 zusätzlich P6 und P4 zusätzlich P8.

### 3.2.1 Klassen → Dateien
| Klasse | Datei | Art |
|---|---|---|
| `RegionConfig` | `src/world/regions/region_config.gd` | ✦ |
| `RegionRoot`, `RegionPortal`, `RegionTravel` | `src/world/regions/{region_root,region_portal,region_travel}.gd` (+ `src/entities/region_portal/region_portal.tscn`) | Stub (P1) |
| `HouseDoor` | `src/entities/house_door/house_door.gd` (+ `.tscn`) | Stub (P1) |
| `NpcConfig` | `src/systems/npc/npc_config.gd` | ✦ |
| `NpcLod` | `src/systems/npc/npc_lod.gd` | Stub (P1) |
| `VillagerData`, `ShopData`, `RelationshipConfig`, `VillageConfig` | `src/systems/village/{villager_data,shop_data,relationship_config,village_config}.gd` | ✦ |
| `ShopRules`, `VillageShops`, `RelationshipRules`, `Relationships` | `src/systems/village/{shop_rules,village_shops,relationship_rules,relationships}.gd` | Stub (P2) |
| `ShopCounter` | `src/entities/shop_counter/shop_counter.gd` (+ `.tscn`) | Stub (P2) |
| `OrderData`, `OrdersConfig` | `src/systems/village/{order_data,orders_config}.gd` | ✦ |
| `OrderRules`, `Orders`, `Village` | `src/systems/village/{order_rules,orders,village}.gd` | Stub (P3) |
| `VillageBoard`, `MourningRibbon`, `PoorBox`, `RegisterCopy` | `src/entities/{village_board,mourning_ribbon,poor_box,register_copy}/*.gd` (+ `.tscn`) | Stub (P3) |
| `AnatomyConfig`, `SpecimenFindingData` | `src/systems/anatomy/{anatomy_config,specimen_finding_data}.gd` | ✦ |
| `SpecimenRecord` | `src/systems/anatomy/specimen_record.gd` | ✦ (reine Daten + `to_dict`/`from_dict`) |
| `SpecimenRules`, `Specimens` | `src/systems/anatomy/{specimen_rules,specimens}.gd` | Stub (P4) |
| `PultStore` | `src/entities/pult_store/pult_store.gd` (+ `.tscn`, `extends Chest`) | Stub (P7) |
| `MedicineData`, `CollectionSetData` | `src/systems/anatomy/{medicine_data,collection_set_data}.gd` | ✦ |
| `PultRules`, `CollectionRules` | `src/systems/anatomy/{pult_rules,collection_rules}.gd` | Stub (P7) |
| `CollectionShelf` | `src/entities/collection_shelf/collection_shelf.gd` (+ `.tscn`, `extends Chest`) | Stub (P7) |
| `TeachingData`, `DeductionData` | `src/systems/anatomy/{teaching_data,deduction_data}.gd` | ✦ |
| `LectureRules`, `Lectures`, `DeductionRules`, `Deductions` | `src/systems/anatomy/{lecture_rules,lectures,deduction_rules,deductions}.gd` | Stub (P8) |
| `LectureSet` | `src/entities/lecture_set/lecture_set.gd` (+ `.tscn`) | Stub (P8) |
| `ShopPanel`, `AnatomistPanel`, `OrdersPanel`, `GiftPanel`, `PultPanel`, `CollectionPanel`, `DeductionPanel`, `LecturePanel` | `src/ui/panels/*.gd` | W-UI |

### 3.3 EventBus – neue Signale (Ergänzung `src/core/event_bus.gd`)
```gdscript
# Regionen (Player.set_region) – nach interior_changed / interior_room_changed, wenn beide wechseln
signal region_changed(region_id: StringName)
# Läden (VillageShops): coins positiv = Einnahme des Spielers
signal shop_trade(shop_id: StringName, coins: int, sold: Dictionary, bought: Dictionary)
# Beziehungen (Relationships)
signal relationship_changed(npc_id: StringName, value: int, tier: StringName, delta: int, reason: String)
signal villager_remarked(npc_id: StringName, text: String)
# Aufträge (Orders); state: &"offered" | &"accepted" | &"completed" | &"failed"
signal order_changed(order_id: StringName, state: StringName)
# Präparate (Specimens); state: &"taken" | &"sold" | &"researched" | &"lectured" | &"used" | &"returned" | &"sealed" | &"displayed" | &"boned" | &"spoiled"
signal specimen_changed(uid: String, state: StringName)
# Darstellung: dunkler Schleier während eines Präparats (MorgueTable)
signal screen_veil_changed(active: bool)
# Weihe (Village)
signal ground_consecrated(section_id: StringName)
# Präparatesammlung (CollectionShelf über CollectionRules), Vorlesung (Lectures), Deutung (Deductions)
signal collection_set_completed(set_id: StringName, standing: int)
signal lecture_held(day: int, organ: StringName, fee: int, rumor: bool)
signal cause_deduced(corpse_id: String, cause_id: StringName)
```
Regel wie Phase 3–6: **Listener ändern keinen Spielzustand.** Wer ändert, ruft direkt auf: `ShopCounter`/Dialog → `VillageShops.buy/sell` (ändert keine Beziehung); `DialogueActions` → `Relationships.add/give_gift`, `Orders.accept/turn_in`, `Village.buy_round/donate/pay_consecration`; `Orders.complete` → `Relationships.add`, `Reputation.event`, `Village.check_goal`; `Graveyard.place_marker/set_designed_stone` → `Orders.note_grave_completed/note_stone_set` (P3); `ExpansionManager` → `Orders.note_section_progress`, `Village.check_goal`; `MorgueTable` → `CorpseCare.harvest_organ` → `Specimens.harvest`, `Piety.event`, `Reputation.event`; `AnatomistPanel` → `Specimens.sell/expertise` → `Relationships.add`, `Deductions.add_card`, `Lectures.learn`; `PultPanel` → `PultRules` + `Specimens.seal/make_display/make_bone/inspect/consume`; `CollectionShelf.place` → `CollectionRules` → `payment_received`, `stats.university_standing`; `LecturePanel` → `Lectures.hold` → `Specimens.consume`, `Piety.event`, `Relationships.add`; `Lectures.apply_morning` → `Reputation.event(lecture_rumor)`; `DeductionPanel` → `Deductions.deduce` → `JournalManager.add_clue`, `CorpseManager.notify_changed`; `GravePlot` → `Specimens.return_to_grave` → `CorpseManager.notify_changed`, `Piety.event`; `Npc`-Zeitplan des Pfarrers endet → `Village.apply_minute` (Uhr) → `Village.consecrate` → `ExpansionManager.try_unlock`. `coins_spent` erhöht `stats.coins_spent` im Sender über `GameState.note_coins_spent`.

### 3.4 Logik-Klassen (Signaturen = Vertrag)

**Regionen, Portale & NPC-Last (P1)**
```gdscript
class_name RegionConfig extends Resource              # ✦ data/config/regions/<region_id>.tres
@export var region_id: StringName; @export var display_name: String = ""; @export var arrive_text: String = ""
@export var origin: Vector3 = Vector3.ZERO
@export var camera_distance: float = 22.0; @export var camera_zoom_min: float = 12.0; @export var camera_zoom_max: float = 24.0
@export var bounds_min: Vector2; @export var bounds_max: Vector2       # Fokusgrenzen, region-lokal
@export var travel_minutes: int = 30; @export var fade_seconds: float = 0.8
@export var managed_paths: PackedStringArray = []    # relativ zum Eltern-Knoten der Region (Graveyard: WorldRoot → ["Decor", "Lights", "Grass"]); Village: ["."] (die eigene Szene)
class_name RegionRoot extends Node3D                  # src/world/regions/region_root.gd
const GROUP := &"region_root"; const GRAVEYARD := &"graveyard"; const VILLAGE := &"village"
@export var region_id: StringName = &"graveyard"; @export var config: RegionConfig
@export var camera_rig_path: NodePath; @export var hide_when_inactive: bool = true
var active: bool = false
func get_waypoint(id: StringName) -> Vector3; func get_waypoint_facing(id: StringName) -> float   # wie WorldRoot (Graveyard: delegiert an WorldRoot)
func ground_height(pos: Vector2) -> float
func spawn_transform(spawn_id: StringName) -> Transform3D        # Marker Spawns/<id>
func camera_profile() -> CameraProfile                             # bounds = origin + config.bounds_*
func apply_region(current: StringName) -> void   # EventBus.region_changed: aktiv/inaktiv; inaktiv → managed_paths unsichtbar + PROCESS_MODE_DISABLED;
                                                  # aktiv → sichtbar, INHERIT, alle Npc.refresh(), rig.set_base_profile(camera_profile()), rig.snap()
static func find(tree: SceneTree, id: StringName) -> RegionRoot
static func current(tree: SceneTree) -> StringName                # Player.region_id (Graveyard ohne Spieler)
class_name RegionTravel extends RefCounted
static func block_reason(player: Player, target: StringName) -> String   # "" | „Eine Leiche nimmst du nicht mit ins Dorf." | „Erst fertig machen." | Flag fehlt
static func travel(player: Player, target: StringName, spawn: Transform3D, minutes: int, fade: float) -> bool
#   screen_fade_requested(fade); in der Mitte: TimeManager.advance(minutes) (wie Schlafen, ohne Tageswechsel-Sonderfall),
#   Teleport, Player.set_region(target), stats.village_trips +1 beim Weg ins Dorf; HutPortal.is_travelling gilt mit
class_name RegionPortal extends Node3D                # Entities/road_exit (Friedhof) · Village/Entities/road_out
@export var target_region: StringName; @export var target_spawn: StringName
@export var requires_flag: StringName = &"village_open"; @export var prompt: String = "[E] Nach Hollerbrück (30 Min)"
func can_interact(player: Player) -> bool; func get_interaction_prompt(player: Player) -> String; func interact(player: Player) -> void
# Player (P1): var region_id: StringName = &"graveyard"; func set_region(id: StringName) -> void   # emit region_changed
#   save_state + "region_id"; load_state tolerant (fehlt → graveyard; unbekannt → graveyard + Warnung); nach interior_* gemeldet
# CameraRig (P1): func set_base_profile(p: CameraProfile) -> void   # clear_profile() kehrt zum Basisprofil zurück (statt zum Layout-Start)
#   Ohne set_base_profile bitgleich wie bisher (Basis = der Zustand aus _capture beim Start)
# InteriorRoom (P1): @export var region_id: StringName = &"graveyard"   # nur Doku/Tests; apply_room bleibt, clear_profile → Region
# RoomExit (P1): @export var door_id: StringName = &""   # gesetzt → HouseDoor.find(tree, door_id).exit_transform() statt BuildingDoor
class_name HouseDoor extends Node3D                   # Village/Entities/door_<id>; Tür eines begehbaren Hauses
@export var door_id: StringName; @export var room_id: StringName; @export var display_name: String = ""
@export var open_windows: PackedInt32Array = []      # [von, bis, von, bis] Tagesminuten; leer = immer offen
func is_open_now() -> bool; func next_opening() -> int   # Minute oder -1
#   Wundarztstube: zusätzlich offen, wenn Lectures.door_open(door_id) (Vorlesungsabend, nur für den eingeladenen Totengräber)
func exit_transform() -> Transform3D                  # Marker door_outside des Hausmodells
func can_interact(player: Player) -> bool             # nie mit Leiche (Dorf); geschlossen → Prompt „Geschlossen. Öffnet um 14:00."
func interact(player: Player) -> void                 # HutPortal.travel(..., room_id) – Player.region_id bleibt village
static func find(tree: SceneTree, door_id: StringName) -> HouseDoor
# ScheduleEntry ✦ + @export var region: StringName = &""        # "" = Friedhof
#                 + @export var today_flag: StringName = &""    # Eintrag gilt nur, wenn GameState-Flag == TimeManager.day
# ScheduleResolver (P1): static func entry_at(schedule, minute_of_day, day: int = -1) -> ScheduleEntry
#   day ≥ 0: Einträge mit today_flag zählen nur, wenn flag == day; bei gleichem start_minute gewinnt ein gültiger today_flag-Eintrag.
#   day -1 (alle bisherigen Aufrufe): today_flag-Einträge werden übersprungen → bitgleich für Osric und Ilse
# Npc (P1): @export var region_id: StringName = &"graveyard"; @export var hide_flag: StringName = &""
#   shown = entry.visible ∧ flag_allows() ∧ (entry.region if != "" else graveyard) == region_id ∧ ¬hide_flag
#   Npc in inaktiver Region: Auswertung einmal je Spielminute (wie verborgen), Animation pausiert
#   func set_lod(level: int) -> void   # 0 voll · 1 gedrosselt (Auswertung nach NpcConfig.reduced_interval, Animation läuft) · 2 ruhend (Animation pausiert)
#   Bestehende Lookups nach npc_id (NightTrade._npc, Debug) filtern auf region_id == graveyard (W0-Lead prüft alle Stellen)
class_name NpcConfig extends Resource                 # ✦ data/config/npc_config.tres
@export var lod_full_distance: float = 26.0; @export var lod_rest_distance: float = 40.0
@export var reduced_interval: float = 0.2; @export var max_full: int = 6; @export var governor_hz: float = 2.0
@export var remark_distance: float = 4.0
class_name NpcLod extends Node                        # Systems/NpcLod: 2 Hz; ordnet die Npc der aktiven Region nach Abstand zum Kamera-Fokus,
func update_now() -> void                             # die nächsten max_full → 0, bis lod_rest_distance → 1, dahinter → 2; meldet Nähe < remark_distance
func lod_of(npc: Npc) -> int                          #   an Relationships.remark (einmal je Person und Tag)
```

**Läden & Beziehungen (P2)**
```gdscript
class_name VillagerData extends Resource              # ✦ data/village/villagers/<npc_id>.tres (§2.1)
@export var npc_id: StringName; @export var display_name: String; @export var role: String = ""
@export var dialogue_id: StringName; @export var shop_id: StringName = &""; @export var home_door: StringName = &""
@export var gifts_liked: Array[StringName] = []; @export var start_value: int = 20
@export var specimen_delta: int = 0; @export var returned_delta: int = 0; @export var piety_sensitive: bool = false
@export var remarks: Dictionary[StringName, PackedStringArray] = {}   # Schlüssel: rep_<tier>, piety_<tier>, friend, specimens
class_name ShopData extends Resource                  # ✦ data/shops/<id>.tres (§2.3)
@export var id: StringName; @export var npc_id: StringName; @export var title: String = ""
@export var sells: Dictionary[StringName, Dictionary] = {}   # {item: {price, per_day, requires_tier?}}
@export var buys: Dictionary[StringName, Dictionary] = {}    # {item: {price, per_day}}
@export var coin_reason: StringName = &"village"
class_name RelationshipConfig extends Resource        # ✦ §2.4
@export var tier_thresholds: PackedInt32Array = [15, 40, 70]
@export var gains: Dictionary[StringName, int] = {&"talk": 1, &"gift": 4, &"round": 2, &"donation": 1, &"order_failed": -4}
@export var rep_start_bonus: PackedInt32Array = [-10, -5, 0, 5, 10]; @export var piety_start_bonus: PackedInt32Array = [-5, 0, 0, 3, 5]
@export var discount_tier: StringName = &"trusted"; @export var discount: int = 1; @export var discount_min_price: int = 4
@export var surcharge_rep_tier: StringName = &"disreputable"; @export var surcharge: int = 1
@export var friend_buy_bonus: int = 1; @export var friend_buy_min_price: int = 3
class_name RelationshipRules extends RefCounted
const TIERS: Array[StringName] = [&"stranger", &"acquainted", &"trusted", &"friend"]
static func tier(value: int, cfg: RelationshipConfig) -> StringName
static func start_value(data: VillagerData, rep_tier: StringName, piety_tier: StringName, cfg: RelationshipConfig) -> int
static func word(tier: StringName) -> String          # „Fremd" | „Bekannt" | „Vertraut" | „Befreundet"
class_name Relationships extends Node                 # Systems/Relationships
func value(npc_id: StringName) -> int; func tier(npc_id: StringName) -> StringName; func met(npc_id: StringName) -> bool
func meet(npc_id: StringName) -> void                 # erster Kontakt: Startwert (§2.1), relationship_changed
func add(npc_id: StringName, delta: int, reason: String) -> int   # 0…100 geklemmt; relationship_changed; Rückgabe = neuer Wert
func note_talk(npc_id: StringName) -> void            # +talk einmal je Tag
func gift_block_reason(npc_id: StringName, item_id: StringName, inv: Inventory) -> String
func give_gift(npc_id: StringName, item_id: StringName, inv: Inventory) -> bool   # 1 Item fort, +gift, stats.gifts_given
func count_at_least(tier: StringName) -> int          # Kapitel
func remark(npc_id: StringName) -> String             # einmal je Tag; villager_remarked; "" = schon gesagt
func on_specimen_sold() -> void; func on_specimen_returned() -> void   # alle Bewohner mit specimen_delta / returned_delta
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
class_name ShopRules extends RefCounted
static func price(base: int, rep_tier: StringName, rel_tier: StringName, cfg: RelationshipConfig) -> int
static func buy_price(base: int, rel_tier: StringName, cfg: RelationshipConfig) -> int
static func buy_block_reason(shop: ShopData, item: StringName, n: int, stock_left: int, inv: Inventory, price: int, rel_tier: StringName) -> String
static func sell_block_reason(shop: ShopData, item: StringName, n: int, bought_left: int, inv: Inventory) -> String
class_name VillageShops extends Node                  # Systems/VillageShops
func shop(shop_id: StringName) -> ShopData; func is_open(shop_id: StringName) -> bool   # Npc steht am Laden-Ort (gesprächsbereit, nicht gehend)
func offers(shop_id: StringName) -> Array[Dictionary]  # {item, price, stock_left, block_reason}
func wants(shop_id: StringName) -> Array[Dictionary]   # {item, price, bought_left, held, block_reason}
func buy(shop_id: StringName, item: StringName, n: int, inv: Inventory) -> bool          # atomar; note_coins_spent(cost, coin_reason); shop_trade
func sell(shop_id: StringName, item: StringName, n: int, inv: Inventory) -> int          # atomar; payment_received(…, „Verkauf im Dorf"); shop_trade; Münzen | 0
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void              # {stock_day, stock_left, bought_left}; neuer Tag → voll (abgeleitet)
class_name ShopCounter extends Node3D                 # Ladenfenster der Krämerin, Amboss des Schmieds: „[E] Kaufen und verkaufen" (wenn is_open) → Panel &"shop"
@export var shop_id: StringName
```

**Aufträge & Dorf-Fortschritt (P3)**
```gdscript
class_name OrderData extends Resource                 # ✦ data/orders/<id>.tres (§2.5)
const KINDS: Array[StringName] = [&"deliver", &"bury", &"stone", &"tend", &"donate", &"section"]
@export var id: StringName; @export var giver: StringName; @export var recipient: StringName = &""; @export var kind: StringName
@export var title: String; @export_multiline var request_text: String; @export_multiline var thanks_text: String
@export var items: Dictionary[StringName, int] = {}; @export var coins: int = 0
@export var target: String = ""                      # grave_id | story_id | section_id | "next_delivery"
@export var conditions: Dictionary = {}              # dress, service, prepared, unharvested, section, stone_shape, ornament, gilded, inscription, mornings, min_clarity, organ
@export var days_limit: int = 0; @export var requires_flag: StringName = &""; @export var requires_orders: Array[StringName] = []
@export var requires_tier: StringName = &""          # Beziehung zum Auftraggeber
@export var reward_coins: int = 0; @export var reward_rel: int = 0; @export var reward_rep: int = 0
@export var extra_rel: Dictionary[StringName, int] = {}; @export var fail_rel: Dictionary[StringName, int] = {}
@export var board: bool = false; @export var cooldown_days: int = 3; @export var order: int = 0
@export var accept_flag: StringName = &""            # o_fenner_linden: linden_granted
class_name OrdersConfig extends Resource              # ✦
@export var max_active: int = 4; @export var board_offers: int = 2; @export var board_giver: StringName = &"council"
@export var refresh_minute: int = 360
class_name OrderRules extends RefCounted
static func offer_block_reason(order: OrderData, state: Dictionary, rel_tier: StringName, active: int, cfg: OrdersConfig) -> String
static func bury_result(order: OrderData, record: CorpseRecord, grave: GraveRecord) -> StringName   # &"done" | &"wait" | &"broken"
static func stone_matches(order: OrderData, grave: GraveRecord) -> bool
static func deliver_ready(order: OrderData, inv: Inventory) -> bool
static func board_pick(pool: Array[OrderData], day: int, history: Dictionary, n: int) -> Array[StringName]   # deterministisch
class_name Orders extends Node                        # Systems/Orders
func offers(giver: StringName = &"") -> Array[StringName]; func active() -> Array[StringName]
func state(order_id: StringName) -> StringName       # &"" | offered | accepted | completed | failed
func accept(order_id: StringName) -> bool             # max_active; accept_flag; order_changed
func turn_in(order_id: StringName, inv: Inventory) -> bool   # deliver/donate atomar → complete
func complete(order_id: StringName) -> void           # Lohn: payment_received, Relationships.add, Reputation.event; stats.orders_done; Village.check_goal
func note_grave_completed(grave_id: String, corpse_id: String) -> void; func note_stone_set(grave_id: String) -> void
func note_section_progress(section_id: StringName, done: int, total: int) -> void
func note_harvest(corpse_id: String) -> void          # bury-Aufträge mit unharvested → broken → fail
func apply_morning(day: int) -> void                  # Fristen, tend-Prüfung, Tafel-Angebote (idempotent je Tag)
func done_count() -> int; func done_givers() -> PackedStringArray
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
class_name VillageConfig extends Resource             # ✦ data/config/village_config.tres
@export var unlock_flag: StringName = &"roof_and_earth_complete"; @export var open_flag: StringName = &"village_open"
@export var intro_minute: int = 360; @export var round_price: int = 5; @export var round_minutes: int = 15
@export var donation_step: int = 5; @export var donation_steps_per_day: int = 2
@export var consecration_price_by_tier: Dictionary[StringName, int] = {&"stranger": 10, &"acquainted": 10, &"trusted": 5, &"friend": 0}
@export var consecration_section: StringName = &"linden"; @export var consecration_end_minute: int = 630
@export var mourning_houses: PackedStringArray = ["house_kehr", "house_brandt", "house_ott", "house_sieber", "cottage_hagedorn", "cottage_dorn"]
@export var goal_orders: int = 6; @export var goal_givers: int = 4; @export var goal_trusted: int = 3
@export var goal_insight: StringName = &"i_deathbook"; @export var chapter_id: StringName = &"name_in_village"
@export var goal_flag: StringName = &"name_in_village_complete"
class_name Village extends Node                       # Systems/Village
func is_open() -> bool; func apply_morning(day: int) -> void; func post_load() -> void   # v5 → sofort offen
func apply_minute(day: int, minute: int) -> void     # time_tick: Weihe-Ende, Trauerflor
func consecration_price() -> int; func pay_consecration(inv: Inventory) -> bool          # linden_consecration_day = morgen
func consecrate() -> void                             # linden_consecrated, ground_consecrated, ExpansionManager.try_unlock
func buy_round(inv: Inventory) -> bool                # Wirtin anwesend, einmal je Tag; Relationships.add(round) für alle in der Gaststube
func donate(inv: Inventory) -> bool                   # ein Schritt; Ruf +1, Fenner +1
func mourning_house(day: int) -> StringName          # "" = keiner
func goal_progress() -> Dictionary; func check_goal() -> void
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
class_name VillageBoard extends Node3D                # Gemeindetafel an der Linde: „[E] Gemeindetafel lesen" → Panel &"orders" {board: true}
class_name PoorBox extends Node3D                     # Amtsstube: „[E] In die Armenkasse geben (5 Münzen)" → Village.donate (höchstens 2 Schritte je Tag)
class_name RegisterCopy extends Node3D                # Amtsstube: „[E] Die Abschrift lesen" (Fenner anwesend ∧ (Vertraut ∨ Spende heute)) → JournalManager.add_clue(c_v_deathbook)
class_name MourningRibbon extends Node3D              # Trauerflor an Marker ribbon eines Hauses; sichtbar nach Village.mourning_house
@export var house_id: StringName
# SectionData ✦ + @export var unlock_flag: StringName = &""   # Abschnitt öffnet erst mit allen Hindernissen UND diesem Flag
# ExpansionManager (P3): func try_unlock(section_id: StringName) -> bool   # nach dem letzten Hindernis und nach dem Flag; sonst „Geräumt. Es fehlt die Weihe."
# Stonemasonry (P3) / GravePlot (P4-Prompt): Ruhezeit-Grab (OLD, nicht hebbar) mit aktivem stone-Auftrag: Steinmetzbank darf einen Stein
#   dafür fertigen; „[E] Neuen Stein setzen (20 Min)" → Graveyard.replace_old_marker(grave_id, design) (Zustand bleibt OLD)
```

**Anatomie (P4)**
```gdscript
class_name AnatomyConfig extends Resource             # ✦ data/config/anatomy_config.tres (§2.6; Werte dort)
@export var organs: Dictionary[StringName, Dictionary] = {}   # heart, lung, stomach, liver, kidneys, eyes, hand: {label, containers, minutes, base_price, quality, reputation_event, piety, mood, return_piety, sell_rel, lecture_bonus, medicine, res_tag, res_weight}
@export var max_per_corpse: int = 3; @export var small_jar_inputs: Dictionary[StringName, int] = {&"prep_jar_small": 1, &"spirits": 1}
@export var hand_inputs: Dictionary[StringName, int] = {&"linen": 1, &"beeswax": 1}; @export var sound_cue: StringName = &"anatomy_tool"
@export var inspect_minutes: int = 20; @export var expertise_minutes: int = 30; @export var inspect_min_clarity: float = 0.5; @export var bone_minutes: int = 60
@export var lecture: Dictionary = {}                  # §2.6.4: every_days, start, minutes, fee, standing_bonus, piety, rumor_chance(_esteemed), rumor_rep, rumor_rel, veil_alpha
@export var tool_item: StringName = &"anatomy_case"; @export var room_id: StringName = &"crypt"; @export var min_freshness: float = 0.3
@export var jar_inputs: Dictionary[StringName, int] = {&"prep_jar": 1, &"spirits": 1}; @export var bundle_inputs: Dictionary[StringName, int] = {&"linen": 1}
@export var bundle_minutes: int = 600; @export var pult_cold_factor: float = 0.25; @export var clarity_words: PackedFloat32Array = [0.8, 0.6, 0.45]
@export var basic_teachings: Array[StringName] = [&"l_lung", &"l_liver"]   # kommen mit dem Besteck
@export var bundle_price_factor: float = 0.5; @export var display_price_factor: float = 1.5; @export var display_price_bonus: int = 2
@export var friend_price_bonus: int = 1; @export var return_minutes: int = 10; @export var seal_minutes: int = 5; @export var display_minutes: int = 40
@export var veil_seconds: float = 0.6; @export var veil_alpha: float = 0.85; @export var known_flag: StringName = &"anatomy_known"
class_name SpecimenFindingData extends Resource       # ✦ data/anatomy/findings/<id>.tres
@export var id: StringName; @export var organ: StringName; @export var priority: int = 0
@export var story_id: StringName = &""; @export var hidden_cause: StringName = &""; @export var cause_id: StringName = &""
@export var requires_trait: StringName = &""; @export_multiline var text: String; @export var clue_id: StringName = &""
@export var reveals_cause: StringName = &""          # Totenzettel „laut Quast: Arsenik"
class_name SpecimenRecord extends RefCounted         # ✦ reine Daten
const CONTAINER_JAR := &"jar"; const CONTAINER_BUNDLE := &"bundle"; const CONTAINER_DISPLAY := &"display"; const CONTAINER_BONE := &"bone"
const STATES: Array[StringName] = [&"held", &"sold", &"researched", &"lectured", &"used", &"returned"]   # researched = Gutachten bei Quast, used = Arznei
var uid: String; var corpse_id: String; var corpse_name: String; var organ: StringName; var container: StringName
var clarity_at_harvest: float; var harvest_total: int; var sealed_total: int = -1; var sealed_clarity: float = -1.0
var cold_windows: PackedInt32Array = []; var state: StringName = &"held"; var finding_id: StringName = &""; var day: int
func to_dict() -> Dictionary; static func from_dict(d: Dictionary) -> SpecimenRecord   # tolerant
class_name SpecimenRules extends RefCounted
static func harvest_block_reason(record: CorpseRecord, organ: StringName, container: StringName, inv: Inventory, room: StringName, known: bool, cfg: AnatomyConfig) -> String   # "-" = keine Karte
static func clarity(spec: SpecimenRecord, now_total: int, cfg: AnatomyConfig) -> float   # Glas konstant; Bündel linear über wirksame Minuten (cold_windows × pult_cold_factor)
static func is_spoiled(spec: SpecimenRecord, now_total: int, cfg: AnatomyConfig) -> bool
static func clarity_word(c: float, cfg: AnatomyConfig) -> String
static func price(spec: SpecimenRecord, now_total: int, friend: bool, cfg: AnatomyConfig) -> int
static func finding_for(spec: SpecimenRecord, record: CorpseRecord, findings: Array[SpecimenFindingData]) -> SpecimenFindingData   # Vorrang priority, dann Reihenfolge §2.6
class_name Specimens extends Node                     # Systems/Specimens
func get_record(uid: String) -> SpecimenRecord; func held() -> PackedStringArray; func of_corpse(corpse_id: String) -> PackedStringArray
func label(uid: String) -> String                     # „Herz – Hedwig Lamprecht, 58 – Klarheit gut"
func harvest(corpse_id: String, organ: StringName, container: StringName, inv: Inventory) -> String   # uid | ""; nimmt Zutaten, add_unique; specimen_changed(taken)
func sell(uid: String, inv: Inventory) -> int         # Quast anwesend; remove_uid; Münzen; Relationships.on_specimen_sold; stats.specimens_sold
func expertise(uid: String, inv: Inventory) -> Dictionary  # Gutachten nach der TimedAction: Befund-Karte (Deductions.add_card) + Lehrsatz des Organs (Lectures.learn); state researched; Quast +3
func inspect(uid: String) -> StringName              # Begutachten am Pult: Befund-Id (finding_for), das Stück bleibt; Deductions.add_card
func consume(uid: String, inv: Inventory, state: StringName) -> bool   # für Vorlesung (lectured) und Arznei (used): remove_uid, state, specimen_changed
func make_bone(uid: String, inv: Inventory) -> bool  # Hand-Bündel → bone_specimen (neue Item-Id, gleiche uid)
func seal(uid: String, inv: Inventory) -> bool        # Bündel → Glas (neue uid nicht nötig: container jar, sealed_*)
func make_display(uid: String, inv: Inventory) -> bool
func return_block_reason(uid: String, grave_id: String) -> String; func return_to_grave(uid: String, grave_id: String, inv: Inventory) -> bool
func note_cold(uid: String, entering: bool) -> void   # PultStore beim Hinein/Hinaus: Fenster öffnen/schließen
func check_spoiled(now_total: int) -> void            # hour_changed: Notiz einmal je Bündel, specimen_changed(spoiled)
func kept(organ: StringName) -> int                   # Haken Phase 13 (nur gezählt)
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void; func post_load() -> void   # uid ohne Inventar-Platz → Warnung, state bleibt (Fuzzer)
# Inventory (P4) – Einzelstücke (ItemData.unique): ein Platz je Stück, slot {"id", "amount": 1, "uid"}
func add_unique(id: StringName, uid: String) -> bool; func remove_uid(uid: String) -> bool
func uids(id: StringName = &"") -> PackedStringArray; func has_uid(uid: String) -> bool
#   add_item für unique-Ids legt Stücke mit uid "" an (nur Debug/Tests, Warnung); remove_item(id, n) nimmt die neuesten (Kompatibilität)
#   save/load: "uid" im Platz, fehlend = "" (tolerant); ChestTransfer.move_slot bewegt den Platz samt uid; move(id, n) wählt die neuesten
# CorpseRecord ✦ + var hidden_cause: StringName = &""; var returned: Array[StringName] = []
#   HARVEST_KINDS + &"heart", &"lung", &"stomach", &"liver", &"kidneys", &"eyes", &"hand" (angehängt); is_harvested / harvested unverändert
#   CorpseCare.organ_block_reason prüft zusätzlich max_per_corpse (Organe zählen, Haar/Zähne nicht) und die erlaubten Behältnisse je Organ
# CorpseTables ✦ + @export var hidden_causes: Dictionary[StringName, Array] = {}   # cause → [{id, chance}]; CorpseGenerator würfelt aus dem Seed
# CorpseCare (P4): func organ_block_reason(id: String, organ: StringName, container: StringName, inv: Inventory) -> String
#                  func harvest_organ(id: String, organ: StringName, container: StringName, inv: Inventory) -> String   # uid | ""
#   Piety.event(organ_taken), Reputation.event(organ_taken), stats.specimens_taken, piety_used_day, Orders.note_harvest, corpse_harvested(id, organ, item)
# MorgueTable (P4): func request_organ(organ: StringName, container: StringName) -> void
#   TimedAction minutes (nicht abbrechbar); Start: Corpse.set_covered(true), screen_veil_changed(true); Ende/Abbruch: beides zurück
# Corpse (P4): func set_covered(on: bool) -> void       # Tuch-Modell (ph_prop_corpse_shrouded) ein/aus, reine Darstellung
# GravePlot (P4): FILLED/MARKED + Präparat des Toten im Inventar → Prompt „[E] Präparat beisetzen: <Organ> von <Name> (10 Min)" (Vorrang nach dem Stein)
# GhostMood (P4): static func robbed_count(record: CorpseRecord) -> int   # harvested.size() − returned.size()
#   score(..., robbed := robbed_count(record)); main_reason → &"robbed_organ", wenn ein Organ fehlt; GhostLines ✦ + by_organ, by_returned (PackedStringArray)
```

**Dialog, Geschichte & Speichern (P6)**
```gdscript
# DialogueConditions (P6): rel_gte:<npc>:<n> · rel_tier:<npc>:<tier> · met:<npc> · rep_tier:<tier> · order:<id>:<state>
#   · order_offerable:<id> · shop_open:<shop> · region:<id> · specimens_held_gte:<n> · specimen_sold_any · alive:<npc> (¬hide_flag)
# DialogueActions (P6): meet:<npc> · talked:<npc> (Relationships.note_talk) · open_shop:<shop> · open_gifts:<npc>
#   · order_offer:<id> (Panel-Karte im Dialog) · order_accept:<id> · order_turn_in:<id> · buy_round · donate
#   · consecrate_pay · anatomy_case (Quast: Besteck, Rezeptbuch, Grund-Lehrsätze, Flag anatomy_known) · open_anatomist · open_lecture (nur am Vorlesungsabend) · lecture_invite · rel_add:<npc>:<n>
#   take_item:coin:<n>:<reason> bleibt; Grund-Standard: Sprecher-npc_id → &"village" für Dorfbewohner
# StoryCorpseData ✦ + @export var after_flag: StringName = &""; @export var after_days: int = 0; @export var section: StringName = &""
#   + @export var requires_flag: StringName = &""; @export var due_flag: StringName = &""   # D1: linden_consecrated / hagedorn_dead
# StoryDirector (P6): due_story beachtet after_flag (Flagwert = Tag) + after_days und requires_flag; reserviert eine Stelle in `section`;
#   daily_checks setzt due_flag (hagedorn_dead) am Liefertag um 00:00, wenn die Leiche an diesem Tag fällig ist
# SaveMigration (P6): CURRENT := 6; + static func migrate_5_to_6(state: Dictionary, meta: Dictionary) -> Dictionary
#   V6_EMPTY_NODES := ["village", "relationships", "village_shops", "orders", "specimens", "pult_store"]
# SaveFileIO.FORMAT_VERSION = 6; read_doc akzeptiert 1…6
# GameState.DEFAULT_STATS + die 14 Stats aus §2.11; COIN_REASONS + &"village", &"donation", &"round", &"consecration"
```

**Präparierpult (P7)**
```gdscript
class_name PultStore extends Chest                    # Innen Gruft am Pult; save_id "pult_store", save_order 62; PANEL &"chest"; slot_count 8
func store() -> Inventory                             # = storage; Inventory.changed → Specimens.note_cold für Bündel (hinein/hinaus)
# Station pult (data/stations/pult.tres): requires_built, Bau §2.7; Workbench im Gruft-Raum (room crypt), Panel &"crafting"
#   zweite Karte → Panel &"pult" (W-UI): Einlegen, Schau-/Knochenpräparat, Begutachten, Arzneien – jeweils TimedAction, danach PultRules/Specimens
class_name MedicineData extends Resource              # ✦ data/anatomy/medicines/<id>.tres (§2.7)
@export var id: StringName; @export var organs: Array[StringName] = []   # eines davon als Präparat im Glas
@export var min_clarity: float = 0.45; @export var inputs: Dictionary[StringName, int] = {}; @export var minutes: int = 30
@export var output: StringName; @export var amount: int = 1
class_name PultRules extends RefCounted
static func medicine_block_reason(med: MedicineData, spec: SpecimenRecord, inv: Inventory, now_total: int, cfg: AnatomyConfig) -> String
static func seal_block_reason(spec: SpecimenRecord, inv: Inventory, now_total: int, cfg: AnatomyConfig) -> String
static func display_block_reason(spec: SpecimenRecord, inv: Inventory, cfg: AnatomyConfig) -> String
static func bone_block_reason(spec: SpecimenRecord, inv: Inventory, now_total: int, cfg: AnatomyConfig) -> String
static func inspect_block_reason(spec: SpecimenRecord, now_total: int, cfg: AnatomyConfig) -> String
#   Arznei am Ende der TimedAction: Specimens.consume(uid, inv, &"used"), Zutaten fort, Ausgabe ins Inventar, stats.medicines_made
class_name CollectionSetData extends Resource         # ✦ data/anatomy/sets/<id>.tres (§2.7)
@export var id: StringName; @export var title: String; @export var organs: Array[StringName] = []
@export var needs_display: bool = false; @export var reward_coins: int = 0; @export var standing: int = 1; @export var sets_flag: StringName = &""
class_name CollectionRules extends RefCounted
static func slot_for(organ: StringName) -> int; static func accepts(item_id: StringName, spec: SpecimenRecord) -> bool   # kein Bündel
static func completed_sets(shelf_organs: Dictionary, sets: Array[CollectionSetData], done: PackedStringArray) -> Array[StringName]
static func price_bonus(standing: int) -> int          # min(standing, 2)
class_name CollectionShelf extends Chest              # Innen Gruft neben dem Pult; save_id "collection_shelf", save_order 63; 7 Plätze (ein Organ je Platz); PANEL &"collection"
func standing() -> int; func sets_done() -> PackedStringArray
func place(uid: String, inv: Inventory) -> bool; func take(uid: String, inv: Inventory) -> bool   # nach dem Aufstellen: CollectionRules.completed_sets → einmal Lohn (payment_received), stats.university_standing, collection_set_completed
# PrepConfig ✦ balm_items + &"corpse_balm" (dritter Eintrag; juniper bleibt erstes Element)
# ShedConfig.excluded_items + specimen_jar, specimen_bundle, display_specimen, bone_specimen (nur „Überschuss einlagern")
```

**Vorlesung & Deutung (P8)**
```gdscript
class_name TeachingData extends Resource              # ✦ data/anatomy/teachings/<id>.tres (§2.6.5)
@export var id: StringName; @export var organ: StringName; @export var title: String; @export_multiline var text: String
class_name DeductionData extends Resource             # ✦ data/anatomy/deductions/<id>.tres (§2.6.5)
@export var id: StringName; @export var cause_id: StringName
@export var needs_any: Array[StringName] = []         # mindestens eine dieser Karten (z. B. b_white_stomach | b_pale_liver)
@export var needs_all: Array[StringName] = []         # alle (Befunde, Funde, Lehrsätze)
@export var clue_id: StringName = &""; @export_multiline var text: String; @export var reveals_cause: bool = true
class_name LectureRules extends RefCounted
static func is_lecture_night(day: int, minute: int, cfg: AnatomyConfig) -> bool   # day % every_days == 0 und start ≤ minute < start + Fenster (bis 00:30)
static func block_reason(spec: SpecimenRecord, now_total: int, invited: bool, held_today: bool, cfg: AnatomyConfig) -> String
static func fee(organ: StringName, standing: int, cfg: AnatomyConfig) -> int
static func rumor(day: int, seed: int, rep_tier: StringName, cfg: AnatomyConfig) -> bool   # deterministisch
class_name Lectures extends Node                      # Systems/Lectures
func invited() -> bool; func tonight() -> bool; func door_open(door_id: StringName) -> bool   # HouseDoor (P1) fragt die Gruppe lectures
func hold(uid: String, inv: Inventory) -> Dictionary  # nach der TimedAction: Specimens.consume(lectured), Honorar (payment_received), Lehrsatz, Pietät, Quast +3, lecture_held
func learn(teaching_id: StringName) -> bool; func known_teachings() -> PackedStringArray
func apply_morning(day: int) -> void                  # Gerede der Nacht: Ruf, Pfarrer, Liesel (einmal)
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
class_name DeductionRules extends RefCounted
static func matches(d: DeductionData, cards: PackedStringArray, cause: StringName) -> bool
static func find(deductions: Array[DeductionData], cards: PackedStringArray, cause: StringName) -> DeductionData   # null = „Das passt nicht zusammen."
class_name Deductions extends Node                    # Systems/Deductions
func add_card(corpse_id: String, card_id: StringName) -> void; func cards(corpse_id: String) -> PackedStringArray   # Befunde + aufgedeckte Funde + Lehrsätze
func can_deduce(corpse_id: String) -> bool
func deduce(corpse_id: String, cards: PackedStringArray, cause: StringName) -> Dictionary   # {ok, cause, clue, text}; richtig: CorpseRecord.revealed_cause, JournalManager.add_clue, stats.deductions, cause_deduced
func deduced(corpse_id: String) -> PackedStringArray
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
class_name LectureSet extends Node3D                  # Wundarztstube: drei sitzende Studenten + Glas auf dem Lesepult; show_lecture(organ) / hide_lecture() mit Überblendung 0,6 s
# CorpseRecord ✦ + var revealed_cause: StringName = &""   # gedeutete wahre Ursache (Totenzettel)
```

### 3.5 Database (Lead)
Neue Ordner → Schlüssel: `data/shops` (`id`), `data/orders` (`id`, nach `order`), `data/village/villagers` (`npc_id`), `data/anatomy/findings` (`id`, nach `priority`), `data/anatomy/{medicines,sets,teachings,deductions}` (`id`), `data/config/regions` (`region_id`). Funktionen: `shop(id)`, `shops()`, `order_data(id)`, `orders()`, `villager(npc_id)`, `villagers()`, `finding(id)`, `findings()`, `medicine(id)`, `medicines()`, `collection_set(id)`, `collection_sets()`, `teaching(id)`, `teachings()`, `deduction(id)`, `deductions()`, `region_config(id)`. Configs `village_config`, `relationship_config`, `orders_config`, `anatomy_config`, `npc_config` über `config()`. Raum-Configs `data/config/interiors/{inn,surgery,office}.tres` über `interior_config(room_id)` (bestehend). Leere/fehlende Ordner = leere Listen.

### 3.6 Eingaben
Keine neuen Tasten. Panels über [E], Esc schließt. Laden-Panel: Mausklick, Umschalt+Klick = 5 Stück. Auftrags-Panel: `[`/`]` blättert (bestehende Aktionen `journal_page_prev/next`).

---

## 4. Welt, Dorf & Innenräume (W-Welt)

### 4.1 Anbindung – Entscheidung: eigene Außen-Region mit Abblende am Wegstein (Bestätigung §14.1)
**Das Dorf ist eine eigene Außen-Szene** (`src/world/village/village.tscn`, gebaut aus `data/world/village_layout.json`), die der Welt-Builder **fern der Friedhofswelt** unter `WorldRoot/Regions/Village` bei **(0, 0, 400)** instanziert – das erprobte Innenraum-Muster aus Phase 2/6, nur für draußen. Am Ende des Kutschwegs steht ein **Wegstein** („[E] Nach Hollerbrück (30 Min)"); an der Holderbrücke im Dorf der Rückweg („[E] Zum Friedhof (30 Min)"). Der Wechsel ist eine Abblende (0,8 s), in deren Mitte die Uhr um 30 Minuten springt und der Spieler teleportiert wird. Die Region bringt ihr eigenes Kameraprofil (Distanz 22, Zoom 12–24 wie draußen, eigene Fokusgrenzen) und nutzt **dieselbe** Sonne, Umgebung und Atmosphäre.

*Begründung gegen die Alternativen:*
- **Weiterlaufen auf derselben Szene** (ein neuer Abschnitt am Kutschweg): Osric sagt seit Phase 2 „drei Meilen" – ein angebautes Dorf 30 m hinter dem Tor widerspräche dem und wäre von der Friedhofskamera aus sichtbar (es läge südlich, also im Vordergrund jeder Friedhofsansicht). Boden (64 × 80 m), Gras, Bau-Maske und alle Sichtprüfungen der Phasen 3–6 müssten neu gebacken werden, und die CPU zahlte für Dorf und Friedhof gleichzeitig.
- **Szenenwechsel** (`change_scene`): Der ganze Spielzustand lebt in einer Welt (`saveable`-Knoten unter `WorldRoot`, uhrgetriebene Systeme: Verfall, Lieferung, Geister, Osric). Ein Szenenwechsel würde den Friedhof entladen, während seine Uhr weiterlaufen muss, und den Speicher-Vertrag aufbrechen.
- **Die Region** hält alles in einer Szene, kostet in der Ferne fast nichts (die Kamera sieht 84 m weit, `camera.far = distance + 60`; die inaktive Region ist unsichtbar und `PROCESS_MODE_DISABLED`), und sie skaliert: Phase 11 („Welt erweitern": Wald, Sumpf, Mine) hängt weitere `RegionRoot`s an dieselben Portale. Die Innenräume des Dorfes sind normale `InteriorRoom`s in der bekannten Reihe bei z −200.
- **Die 30 Minuten** sind der Preis der Entfernung (§1.3). Laufen müsste man drei Meilen nicht; man entscheidet nur, ob es sich heute lohnt.

**Regeln am Portal:** keine Leiche („Eine Leiche nimmst du nicht mit ins Dorf. Osric holt und bringt."), keine laufende Handlung, nicht während einer Abblende, nur ab `village_open`. Mit vollem Inventar, Werkzeug und Präparaten geht es. Speichern im Dorf ist erlaubt (`region_id` im Spielstand). Nachts ist das Dorf begehbar; Läden und Häuser haben ihre Zeiten (§2.2).

### 4.2 Hollerbrück – Plan (region-lokal; x = Osten, z = Süden zur Kamera; Ursprung = Mitte des Angers)
```
 z −24  ── Kulisse: Kirchhofmauer, Obstbäume, Hügel; Kirchturm am Nordende der Kirche ──
 z −18  [Wohnhaus Kehr]  AMTSHAUS (−15|−14)   KIRCHE ST. GALLUS (0|−18)   HOLDERKRUG (15|−14)  [Wohnhaus Brandt]
 z −10,4       Tür → Amtsstube        Tür (0|−11,9), Kirchplatz       Tür → Gaststube · Laterne
 z  −6  SCHMIEDE (−20|−2)          ····· ANGER (Pflaster, Gras) ·····          WUNDARZTHAUS (19|−2)
         offen nach Osten, Amboss       BRUNNEN (0|−3) · Bank                   Tür nach Westen → Wundarztstube
 z   3   │ Hollerbach            LINDE (−7|3) · GEMEINDETAFEL (−7|4,6) · Bank
 z   1,5 ═HOLDERBRÜCKE (−26|1,5)═ Ortstafel · Bildstock      Weg ← vom Wegstein (Portal road_out −28,4|1,5)
 z   7   │ Waschplatz (−24,5|8,5)   KRÄMERLADEN (−18|7), Ladenfenster nach Osten     REMISE Osric (19,5|8), Tor nach Westen
 z  11      HAGEDORN-KATE (−6|13,5), Tür (−6|11)       DORN-KATE (6|13,5), Tür (6|11)
 z  16  ── Kulisse: Gärten, Zäune, Wiesen, Bachlauf nach Süden ──
          x −29 (Bachufer)                                                    x 24
```
**Kamera-Regel wie Phase 6 §4:** Was südlich steht, verdeckt; was nördlich steht, wird verdeckt. Deshalb stehen die drei hohen Häuser (Amtshaus, Kirche, Holderkrug) als Nordreihe mit den Türen nach Süden, dahinter nur Kulisse. Schmiede, Krämerladen, Wundarzthaus und Remise stehen seitlich und öffnen sich zum Anger. Im Süden stehen nur die zwei niedrigen Katen (Traufe ≤ 2,6 m, First ≤ 4,5 m), Gärten und der Bach.

| Element | Lage (Mitte) | Drehung / Öffnung | Maße (Footprint · Höhe) | Funktion |
|---|---|---|---|---|
| Kirche St. Gallus `v_church` | (0 \| −18) | Tür Süd (0 \| −11,9) | 8 × 12 m · First ≤ 9 m, Turm (Nordende) ≤ 17 m | Kulisse mit Tür; Pfarrer an der Tür; **nicht begehbar** in Phase 7 („Drinnen beten Leute. Du störst nicht." – Innenraum Phase 8/11) |
| Amtshaus `v_office` | (−15 \| −14) | Tür Süd (−15 \| −10,4) | 9 × 7 · ≤ 8,5 m | **begehbar** → Amtsstube |
| Holderkrug `v_inn` | (15 \| −14) | Tür Süd (15 \| −10,4) | 10 × 7 · ≤ 8,5 m | **begehbar** → Gaststube; Wirtshausschild, Bank, Laterne |
| Schmiede `v_smithy` | (−20 \| −2) | offen nach Osten | 6 × 6 · ≤ 5,5 m (Kamin 6,5) | `ShopCounter smith` am Amboss (−16,8 \| −2); Esse-Glut |
| Krämerladen `v_shop` | (−18 \| 7) | Ladenfenster Ost | 6 × 5 · ≤ 6 m | `ShopCounter grocer` (−14,3 \| 7) |
| Wundarzthaus `v_surgery` | (19 \| −2) | Tür West (15,4 \| −2) | 7 × 8 · ≤ 8 m | **begehbar** → Wundarztstube; Messingschild |
| Remise `v_remise` | (19,5 \| 8) | Tor West | 7 × 5 · ≤ 5 m | Osrics Karren als Requisite |
| Hagedorn-Kate `cottage_hagedorn` | (−6 \| 13,5) | Tür Nord (−6 \| 11) | 6 × 5 · First ≤ 4,5 m | Kulisse, Gartenpforte (−6 \| 10,2), Marker `ribbon` |
| Dorn-Kate `cottage_dorn` | (6 \| 13,5) | Tür Nord (6 \| 11) | 6 × 5 · ≤ 4,5 m | Kulisse, Liesels Spinnplatz (6 \| 10,0), Marker `ribbon` |
| Wohnhäuser `house_kehr`, `house_brandt`, `house_ott`, `house_sieber` | Rand: (−25,5 \| −12), (25,5 \| −12), (26,5 \| 3), (−27,5 \| 13) (W-Welt ±1,5 m, außerhalb der Laufgrenze) | zur Kamera | je ≤ 7 m | Kulisse, Marker `ribbon`, Fensterlicht |
| „Zum Stumpf" (zweites Wirtshaus) | hinter dem Amtshaus (−24 \| −20) | – | ≤ 7 m | nur Kulisse, Schild sichtbar |
| Brunnen `v_well` | (0 \| −3) | – | Ziehbrunnen ≤ 3 m | Bank (2,2 \| −3) |
| Linde + Gemeindetafel | Stamm (−7 \| 3), Tafel (−7 \| 4,6) Süd | – | Krone r 4,5 m, ≤ 9 m | `VillageBoard`; Bank (−5,2 \| 3,4) |
| Holderbrücke | (−26 \| 1,5), 6 m lang (O–W) | – | Steinbogen | Portal `road_out` am Westende (−28,4 \| 1,5), Spawn `from_graveyard` (−24,6 \| 1,5, Blick nach Osten) |
| Waschplatz | (−24,5 \| 8,5) | – | flache Steine am Ostufer | Liesel morgens |
| Ortstafel „Hollerbrück", Bildstock, Holunderbüsche | (−23,5 \| −0,5), (−22,5 \| 4,5), an der Brücke | – | – | Dorfeingang |
- **Grenzen:** `walkable_bounds` x −29…24, z −10,6…12,0; Kollision an allen Häusern (Footprint-Boxen), Brückengeländer, Bach (unsichtbare Wand am Ufer außer an Brücke und Waschplatz). `camera_bounds` (Fokus) x −22…20, z −8…8. Boden 70 × 50 m (`ph_env_ground_village`, eigenes Asset aus `tools/blender/asset_ground_village.py`), Gras auf Anger-Rändern und Gärten, Dichte × 0,5 gegenüber dem Friedhof (§9), keines auf Pflaster, Wegen und unter Footprints. Keine Bau-Maske, keine Zier im Dorf.

### 4.3 Begehbare Häuser – drei Innenräume (Muster Phase 6 §4.7/§4.8)
| Raum | Szene (W-Welt, generiert) | Layout | Ursprung (Welt) | Grundfläche | Kamera (Distanz / Zoom) | Tür außen → innen |
|---|---|---|---|---|---|---|
| **Gaststube** `inn` | `src/world/interiors/inn_interior.tscn` | `data/world/interiors/inn_layout.json` | **(240, 0, −200)** | 8 × 6 m | 10 / 8–12 | `door_inn` → hinter der Tür |
| **Wundarztstube** `surgery` | `…/surgery_interior.tscn` | `…/surgery_layout.json` | **(300, 0, −200)** | 6 × 5 m | 9 / 7–11 | `door_surgery` |
| **Amtsstube** `office` | `…/office_interior.tscn` | `…/office_layout.json` | **(360, 0, −200)** | 6 × 5 m | 9 / 7–11 | `door_office` |
- Gleicher generischer Builder (`interior_build.gd`, Layoutformat Phase 6) mit `region_id village`, `hide_when_inactive true`. `RoomExit` mit `door_id` führt zur `HouseDoor` im Dorf zurück (die Region bleibt `village`). Die Dorfbewohner, die drinnen sind, sind normale `Npc` der Dorf-Region mit Wegpunkten im Raum (`v_in_inn_bar`, …); Gehen zwischen Tür und Raum ist ein Zeitplan-Sprung (Eintrag mit `travel_minutes 0` am Innen-Wegpunkt), kein Laufen durch die Tür.
- **Gaststube:** Schanktisch mit Fässern (Rosine, Marker `bar`), Kachelofen (Feuerlicht `warm_lights`), 4 Tische, Osrics Ecktisch (`v_in_inn_corner`), Treppe nach oben (Kulisse), 2–3 sitzende Gäste ohne Rig (`ph_chr_guest_a/b`, §8), Fenster (Rolle `window`), Hängelaterne mit Schatten (`lantern`, nachts). „[E] Eine Runde für alle (5 Münzen)" am Schanktisch (über Rosines Dialog).
- **Wundarztstube:** Behandlungstisch mit weißem Tuch (leer), Glasschrank mit **trüben, verschlossenen Gläsern** mit Papieretiketten (keine erkennbaren Inhalte), Schreibpult mit Büchern und dem Kabinettsbuch, Waschschüssel, Arzttasche, Kräuterbündel, Fenster mit kühlem Tageslicht, Öllampe (Schatten nachts). Quasts Platz `v_in_surgery_desk`; das Panel `&"anatomist"` öffnet aus seinem Dialog. Kein Skelett, keine Abbildungen von Innereien.
- **Amtsstube:** Schreibpult mit Siegel, Aktenregal, **Armenkasse** (eisenbeschlagene Truhe, Entität `PoorBox`: „[E] In die Armenkasse geben (5 Münzen)" → `Village.donate`), **Lesepult mit der Abschrift des Sterbebuchs** (Entität `RegisterCopy`: „[E] Die Abschrift lesen" – mit Fenner „Vertraut" oder nach einer Spende an diesem Tag, und nur wenn Fenner anwesend ist → `c_v_deathbook`; sonst „Das ist Gemeindesache, Totengräber."). `PoorBox`/`RegisterCopy` besitzt P3 (`src/entities/{poor_box,register_copy}/*`).

### 4.4 Wegpunkte (Region Dorf, region-lokal; `Waypoints/<id>`)
`v_road_in` (−29,5 | 1,5) · `v_bridge` (−25,0 | 1,5) · `v_anger_w` (−12 | 0) · `v_well` (0,6 | −1,6) · `v_well_bench` (2,2 | −2,2) · `v_linden` (−5,2 | 4,2) · `v_board` (−7 | 5,6) · `v_church_door` (0 | −10,6) · `v_office_door` (−15 | −9,6) · `v_inn_door` (15 | −9,6) · `v_anvil` (−16,2 | −2) · `v_shop_window` (−13,6 | 7) · `v_surgery_door` (14,6 | −2) · `v_remise` (15,2 | 8) · `v_hagedorn_gate` (−6 | 9,6) · `v_dorn_door` (6 | 9,6) · `v_wash` (−23,6 | 8,5) · `v_house_n` (−20 | −9,8) (Hausbesuche) · Innen: `v_in_inn_bar`, `v_in_inn_table`, `v_in_inn_corner`, `v_in_surgery_desk`, `v_in_office_desk`. `waypoint_facing` für alle Steh-Orte (Blick zum Anger bzw. zur Kamera). Teleports (Debug): `tp_village` (−20 | 1,5), `tp_anger` (0 | 2).

### 4.5 Sichtprüfung und Wege im Dorf (Kamerastrahl-Test, Pflicht)
Test in `test_village_world.gd` (W-Welt) auf der echten Dorf-Region, Verfahren wie Phase 6 §4.5 (AABB aller `VisualInstance3D` außer Boden, Gras, Partikel, Spieler und Zielobjekt; Kronen als AABB):
1. **Nahsicht:** Spieler an jeder `HouseDoor`, jedem `ShopCounter`, der Gemeindetafel, dem Portal und an **jedem gesprächsbereiten Steh-Ort** der acht Zeitpläne (§2.2). Zoom 12, 22, 24: Strahlen zu Spielerkopf (1,7 m), Kopf der Person (1,6 m) und Tür-/Fenstermitte. **Bestanden:** alle frei bei allen drei Zoomstufen.
2. **Im Bild:** Jedes Haus der Nordreihe ist vom Anger aus (Spieler am Brunnen, Zoom 22) zu ≥ 70 % im Bild und deckt ≥ 3 % der Fläche; der Kirchturm ragt sichtbar über das Schiff.
3. **Trauerflor:** Marker `ribbon` jedes der sechs Häuser ist vom nächsten Anger-Punkt aus frei.
4. **Wege** (Flood-Fill, Kapselbreite 1,5 m): Brücke ↔ alle Türen, Läden, Tafel, Waschplatz, Brunnen, Katen; kein Steh-Ort eines Zeitplans liegt in einer Kollision; jeder Zeitplan-Weg (Polylinie) läuft frei (Strahl in Hüfthöhe, Toleranz 0,3 m).
5. Scheitert eine Prüfung, verschiebt W-Welt nur Kulisse, Linde (±1 m) oder Steh-Orte (±0,8 m) und meldet es im G7-Bericht. Bilder `p7_vis_*` (§11).

### 4.6 Eingriffe am Friedhof (vollständig; Layout-Diff-Test gegen `tests/fixtures/phase7/layout_p6.json`)
```
 z  9,6 ════ Ostwiese-Südzaun ════[LINDENACKER-PFORTE x 15,0…16,6]═══════  │ Am Bruch (z ≤ 9,6)
        │ Nordstreifen (Weg) z 9,6…11,8                                    │
 z 12,8 │  l_01 (13,6)   l_02 (15,9)   l_03 (18,2)   l_04 (20,5)          │   LINDE (23,4|14,8) Kulisse
        │ Mittelgang z 13,8…15,9 (≥ 2,0 m)                                  │
 z 16,9 │  l_05          l_06          l_07          l_08                 │
 z 19,6 └══ Zaun ═══════════════════════════════════════════════════════════┘
   x 11,5 (Zaun; unsichtbare Wand x 11,2 zum Kutschweg bleibt)            x 21,5
   Kutschweg … Wegstein (8,4|24,4) „Hollerbrück · 3 Meilen"
```
| # | Element | vorher | nachher | Grund |
|---|---|---|---|---|
| R1 | Wegstein `road_exit` (`RegionPortal`, Modell `ph_prop_milestone`) | – | **(8,4 \| 24,4)**, Blick Nordwest; Spawn `from_village` (8,0 \| 23,4) | Ende des sichtbaren Kutschwegs an der Laufgrenze (z 25,2) |
| L1 | Abschnitt `linden` | Wald hinter der Wand x 11,2 | Rechteck x 11,5…21,5 · z 9,6…19,6, `order 8`, Plots `l_01…l_08` (Raster oben, W-Welt ±0,4 m) | §2.9 |
| L2 | Ostwiese-Südzaun | [[11,5, 9,6], [21,5, 9,6]] | [[11,5, 9,6], [15,0, 9,6]] + Pforte `obs_l_gate` + [[16,6, 9,6], [21,5, 9,6]] | Zugang aus der Ostwiese |
| L3 | Zaun Lindenacker | – | West [[11,5, 9,6], [11,5, 19,6]], Süd [[11,5, 19,6], [21,5, 19,6]], Ost [[21,5, 9,6], [21,5, 19,6]] (`ph_prop_fence_iron`), mit `extra_walls` auf denselben Linien | Abgrenzung; die Wand x 11,2 zum Kutschweg bleibt |
| L4 | Waldbaum `forest.trees[6]` | (12,6 \| 17,2) | **(25,0 \| 23,5)** | stand im Abschnitt |
| L5 | Waldbaum `forest.trees[8]` | (18,0 \| 12,0) | **(27,5 \| 15,5)** | stand im Abschnitt |
| L6 (bedingt) | Waldbaum `forest.trees[7]` | (16,5 \| 22,0) | bis 3 m nach Süden | **nur**, wenn die Krone die Köpfe in Reihe 2 verdeckt (§4.5 Punkt 1 am Lindenacker) |
| L7 | Linde `ph_env_linden_old` | – | (23,4 \| 14,8), außerhalb der Laufgrenze | Namensgeberin, Kulisse; darf keine Bruch-Sammelstelle verdecken (Prüfung) |
| L8 | Bau-Maske | x −11,5…21,5 · z −20…9,6 | + Rechteck Lindenacker (x 11,5…21,5 · z 9,6…19,6), neu gebacken | Zier im Lindenacker (`decor_cap 6`) |
| L9 | Gras / Boden | Waldboden | Gras wie Ostwiese im Abschnitt, Boden unter den Plots geglättet (`plot_flat_rect`), `ph_env_ground_graveyard` neu exportiert (Größe unverändert) | – |
| P1 | Gruft-Raum `crypt_layout.json` | – | Platz `pult` an der Westwand zwischen Treppe und `niche_3` (W-Welt wählt, `min_level 1`, Kollision nur gebaut), `PultStore` im Pult | §2.7 |
| N1 | Wegpunkte | – | + `w_east_pass` (11,5 \| −2,2), `w_linden_n` (15,8 \| 8,6), `linden_spot` (15,8 \| 10,8), `tp_linden` (16 \| 14,8), `from_village` | Weg des Pfarrers am Weihetag (road_end → gate_outside → dropoff → Hofweg → Durchgang Ostwiese → Pforte) und Debug |
| N2 | Entitäten | – | `npc_priest` (`Npc`, Region graveyard, Modell `ph_chr_v_priest`), `Regions/Graveyard` (`RegionRoot`, `managed_paths` ["Decor", "Lights", "Grass"]) | – |
- Nicht bewegt: alles andere, insbesondere Tor, Bahre, Kutschweg-Polylinie, Schlag (Erlen), Ostpforte, Am Bruch, alle Gräber, Pflegestellen und Gebäude. `walkable_bounds` und `camera_bounds` bleiben (max z 25,2 / 23 reichen).
- **Sichtprüfung Lindenacker** (Phase-6-Verfahren): Kopf des Spielers an jedem Plot und an der Pforte frei bei Zoom 12/22/24; **keine neue Verdeckung** an Ostwiesen-Plots, Pflegestellen, Ostpforte und den Sammelstellen Am Bruch; Wegstein am Ende des Kutschwegs bei Zoom 22 im Bild.
- **Wege** (Flood-Fill 1,5 m): Tor ↔ Lindenacker-Pforte ↔ jede Grabstelle `l_*` (Nordstreifen, Weststreifen x 11,5…13,1, Mittelgang, Südstreifen); Bahre ↔ Wegstein; Gruft ↔ Lindenacker (Tragweg ≈ 32 m, ≈ 16 s ≈ 30 Spielminuten wie der Leichenzug zur Kapelle).

### 4.7 Licht im Dorf
- **Tag:** dieselbe Sonne und Atmosphäre wie auf dem Friedhof. Esse-Glut der Schmiede (wie die Werkhof-Esse: `#E07A3A`, 0,5, 3,5 m, ohne Schatten).
- **Nacht:** Laterne am Holderkrug (**mit Schatten**, 2,6 / 8 m wie die Hüttenlaterne), Laterne an der Kirchentür (**mit Schatten**), Brückenlaterne und Laterne an der Linde (ohne Schatten), warme Fenster (ohne Schatten) an Holderkrug (2), Amtshaus (1), Katen (je 1, bis 22:00), Wohnhäuser (je 1, bis 21:00). Höchstens **2 Schattenlichter** im Dorf (§9). Keine Lichter an Figuren.
- Innenräume: `InteriorConfig` je Raum wie Hütte/Gruft, ≤ 2 Schattenlichter (Gaststube: Hängelaterne nachts + Ofen ohne Schatten; Wundarztstube: Lampe; Amtsstube: Fenster + Kerze ohne Schatten).

---

## 5. Speichern & Migration (P6)

### 5.1 Format v6 (Ergänzungen)
```
format_version: 6
data.autoloads.GameState.stats   + village_trips, orders_done, orders_failed, gifts_given, rounds_bought, donations,
                                   specimens_taken, specimens_sold, specimens_researched, specimens_returned, specimens_collected,
                                   medicines_made, lectures_attended, deductions, university_standing,
                                   coins_spent_village, coins_spent_donation, coins_spent_round, coins_spent_consecration
data.autoloads.GameState.flags   + village_open, village_open_day: 40, p7_intro, linden_granted, linden_consecration_day: 42,
                                   linden_consecrated, anatomy_known | anatomy_declined, hagedorn_dead, name_in_village_complete,
                                   insight_deathbook, insight_burn_it, clue_c_v_* (bestehendes Muster)
data.nodes.player                + "region_id": "graveyard" | "village"   (interior_id + "inn" | "surgery" | "office")
data.nodes.player.inventory.slots[] + "uid": "sp_0007"    (nur Einzelstücke; ebenso hut_chest, shed_store, pult_store)
data.nodes.corpse_manager.records[] + hidden_cause: "arsenic", returned: ["heart"]; harvested + "heart" | "lung" | "stomach"
data.nodes.village               {"open_day": 40, "consecration_paid_day": 41, "round_day": 45, "donation_day": 46, "donation_steps": 1,
                                  "goal_done": false, "ribbon_seen": {}}
data.nodes.relationships         {"values": {"innkeeper": 34, …}, "met": ["innkeeper", …], "talk_day": {…}, "gift_day": {…}, "remark_day": {…}}
data.nodes.village_shops         {"stock_day": 45, "stock_left": {"grocer": {"linen": 4}}, "bought_left": {"inn": {"elderberries": 6}}}
data.nodes.orders                {"states": {"o_fenner_well": "completed", …}, "accepted_day": {…}, "board_day": 45,
                                  "board": ["ob_wood", "ob_herbs"], "history": {"ob_wood": 43}, "progress": {"ob_tend": 1}}
data.nodes.specimens             {"next": 8, "records": [{uid, corpse_id, corpse_name, organ, container, clarity_at_harvest,
                                  harvest_total, sealed_total, sealed_clarity, cold_windows, state, finding_id, day}]}
data.nodes.pult_store            {"storage": Inventory.save_state()}
data.nodes.collection_shelf      {"storage": Inventory.save_state(), "sets_done": ["set_chest"], "standing": 1}
data.nodes.lectures              {"invited": true, "last_day": 45, "attended": 2, "teachings": ["l_lung", "l_liver", "l_heart"], "rumor_day": 46}
data.nodes.deductions            {"cards": {"c_0012": ["b_white_stomach", "l_stomach"]}, "done": {"c_0012": ["d_arsenic"]}}
data.nodes.specimens.records[].state  + "lectured" | "used"; container + "bone"
data.nodes.corpse_manager.records[]   + revealed_cause: "arsenic"
data.nodes.graveyard.graves[]    + l_01…l_08 (aus dem Layout, Zustand LOCKED bis zur Öffnung); old_01/old_08 + design (Ersatzstein)
data.nodes.expansion             bestehend (linden: Hindernisse, Fortschritt)
```
Nicht gespeichert: NPC-Positionen (aus der Uhr), LOD-Stufen, Trauerflor (aus Tag + Records), Schleier, Gerede-Blasen. Laden mitten in einem Präparat oder einer Untersuchung bei Quast ist gesperrt (`can_save` false während der TimedAction, wie Phase 5/6).

### 5.2 Migration v5 → v6 (Phase-6-Spielstände müssen laden)
`SaveMigration.migrate_5_to_6` läuft in `read_doc` nach `decode_state` (Kette 1→…→6), rein, auf einer tiefen Kopie.
1. **Spieler:** `region_id = "graveyard"`; `interior_id` unverändert (Hütte, Gruft, Kapelle, Schuppen liegen alle in der Friedhofs-Region).
2. **Inventare:** Plätze unverändert (`uid` fehlt = ""; es gibt in v5 keine Einzelstücke).
3. **Leichen:** alle Records + `hidden_cause ""`, `returned []`. Eine Leiche auf dem Gruft-Tisch bleibt bearbeitbar; die Präparate-Karte erscheint erst mit `anatomy_known`.
4. **Gräber:** unverändert. Die Plots `l_01…l_08` fehlen im v5-Stand und entstehen beim Laden aus dem Layout als `LOCKED` (bestehende tolerante Graveyard-Regel aus Phase 4 für neue Abschnitte).
5. `nodes.village = {}`, `nodes.relationships = {}`, `nodes.village_shops = {}`, `nodes.orders = {}`, `nodes.specimens = {}`, `nodes.pult_store = {}`, `nodes.collection_shelf = {}`, `nodes.lectures = {}`, `nodes.deductions = {}`. `SaveMigration.V6_EMPTY_NODES` fügt sie erst ein, wenn W-Welt die Knoten anlegt (wie Phase 4–6). Records + `revealed_cause ""`.
6. Stats (§2.11) = 0. Flags: keine. `village_open` setzt `Village.post_load` zur Laufzeit, wenn `roof_and_earth_complete` gilt.
7. Die Bau-Maske wächst um den Lindenacker; im v5-Stand liegt dort keine Zier (vorher Wald), es muss nichts geräumt werden.

**Fixtures (W0, Lead, vor jeder Code-Änderung mit Build `705bd5a` erzeugt, über `Phase6Bot` + echte Systeme):** `tests/fixtures/saves_v5/`
- `slot_p6_day40_reverent.json`: `reverent6`-Endstand, 07:00 nach dem letzten Bot-Tag, `roof_and_earth_complete`, alle drei Gebäude auf Stufe 2, 5 Umbettungen (`old_03` hebbar), Münzen gemessen (≈ 20). Start für `neighbor7`, `anatomist7`, `save_load7`.
- `slot_p6_day45_harvester.json`: `harvester6`-Endstand (≈ 63 Münzen, Gruft 3, viele beraubte Seelen). Start für `penitent7`.
- `slot_p6_day41_mender.json`: `mender6`-Endstand (≈ 41 Münzen, Kapelle zuerst). Start für `scholar7`.
- `slot_p6_day37_founder.json`: `founder`-Endstand nach `roof_and_earth` (neues Spiel). Start für `founder7`.
- `slot_p6_day37_eve.json`: `reverent6` am Abend des Kapiteltags (Freischaltung am nächsten Morgen, neues Spiel).
- `slot_p6_crypt_table.json`: Leiche auf dem Gruft-Tisch mit 2 von 4 Schritten, Zopf genommen, offenes Kältefenster, Spieler in der Gruft (Präparate nach der Migration möglich, Ruf/Pietät-Folgen korrekt).
- `slot_p6_chapel_carry.json`: Spieler trägt eine Leiche in der Kapelle (Region graveyard, `interior_id chapel`).
Dazu `make_v5_saves.gd` + `_driver.gd` (historisches Werkzeug, wie Phase 6) und `tests/fixtures/phase7/layout_p6.json` (= `graveyard_layout.json` von `705bd5a`, bytegleich). Lade-Wächter: `tests/integration/test_saves_v5_load.gd` (Lead). v4-, v3-, v2- und v1-Fixtures laden weiter (Kette bis 6).

---

## 6. Debug-Konsole (W-UI) – neue Befehle
`village open` · `region <graveyard|village>` (Teleport mit Profil, ohne Zeitsprung) · `room <inn|surgery|office>` · `tp <village|anger|linden>` · `rel <npc> <wert>` · `rel all <wert>` · `orders` (Zustände, Fristen) · `order <id> <offer|accept|done|fail>` · `board` (Tafel neu würfeln) · `linden <grant|clear|consecrate|open>` · `anatomy` (Besteck + `anatomy_known`) · `specimen <heart|lung|stomach> [jar|bundle]` (Präparat von der Tisch-Leiche sofort) · `specimens` (Liste mit Klarheit, Zustand) · `spoil <uid>` · `shelf <organ…>` (Sammlung füllen) · `standing <0-4>` · `lecture` (heute Vorlesungsabend, Einladung) · `rumor <on|off>` · `cards <corpse>` (Karten anzeigen) · `deduce <corpse> <cause>` · `teach <l_id|all>` · `medicine <id>` · `hidden <cause>` (verborgene Ursache der Tisch-Leiche setzen) · `hagedorn` (D1 morgen fällig) · `npclod` (LOD-Stufen als Farbe über den Köpfen) · `remark <npc>` · `vis7` (Sichtprüfung §4.5 im laufenden Spiel) · `goal7`.

## 7. UI (W-UI)
- **Laden-Panel** `&"shop"` (Kontext `{shop_id, speaker, inventory, player}`): Pergament wie Ilses Panel, zwei Spalten „Kaufen" / „Verkaufen", je Zeile Icon, Name, Preis (durchgestrichener Grundpreis bei Rabatt, „+1 (Ruf)" bei Aufschlag), Vorrat „noch 4 heute", gehalten „du hast 6"; Knöpfe 1 / 5; gedimmt mit Grund. Kopf: Name der Person, Beziehung als Wort und fünf Punkte.
- **Wundarzt-Panel** `&"anatomist"` (Kontext `{speaker, inventory}`): Liste der gehaltenen Präparate mit Etikett (Organ, Name, Alter, Klarheit als Wort und Balken, Glas/Bündel/Schau-/Knochenpräparat, „verdorben in ≈ 4 h"), Preis (mit „+2 Ansehen"), Knöpfe **„Verkaufen (8)"** und **„Gutachten (30 Min)"**, am Vorlesungsabend zusätzlich **„Für die Vorlesung"**; Hinweiszeile beim Verkauf: „Im Dorf wird man davon hören." Verkaufte und begutachtete erscheinen nicht mehr. Ohne Präparate: Quasts Zeile „Bringen Sie mir, was die Erde nicht vermisst." (nur bei `anatomy_known`).
- **Vorlesung** `&"lecture"`: Auswahl des Präparats mit Honorar-Vorschau und der Zeile zur Nacht („Der Nachtwächter ist heute bei seiner Schwester."), danach die Szene: Wundarztstube bei geschlossenen Läden, eine Lampe, Quast am Lesepult, drei Studenten von hinten, das Glas im Lampenlicht, der Behandlungstisch unter dem Tuch; Schleier 60 %, Aktionsbalken 60 Min, drei Zeilen aus Quasts Vortrag (je Organ, sachlich, ohne Beschreibung des Inneren). Ergebnis-Karte: Honorar, neuer Lehrsatz.
- **Deutungs-Panel** `&"deduction"` (aus dem Totenzettel „Ursache deuten"): links die Karten des Toten (Befunde, Funde, Lehrsätze; Farbe je Art wie die Hinweiskarten), rechts die Ursachen-Liste; 2–3 Karten und eine Ursache wählen → **„Deuten"**. Richtig: Karte „Gedeutet: Arsenik" + Hinweis; falsch: „Das passt nicht zusammen." (kein Zähler, kein Abzug). Gedeutete Tote tragen im Register ein kleines Siegel.
- **Sammlungs-Panel** `&"collection"`: sieben Fächer mit Etiketten (leer: Organname in Grau), Sätze als Leiste mit Häkchen und Lohn, „Ansehen bei der Universität: 2", Knöpfe „Aufstellen" / „Herausnehmen". Hinweis: „Was im Regal steht, fehlt im Grab."
- **Präparate-Karte am Gruft-Tisch** (4. Registerkarte „Präparate" in `corpse_exam_tabs.gd`, nur ab `anatomy_known` und `room crypt`): sieben Zeilen Herz / Lunge / Magen / Leber / Nieren / Augen / Hand, Kopfzeile „Genommen: 1 von höchstens 3"; je Zeile Umschalter **Glas** / **Bündel**, soweit erlaubt (Augen nur Glas, Hand nur Bündel), Zutaten vorhanden/fehlt, Dauer, Folgenzeile („Qualität −2 · Ruf −3 · der Geist wird es merken"; Augen/Hand „Qualität −3 · Ruf −5 · das wird ihr fehlen" – ohne Pietät-Zahl, wie Phase 4), Klarheit-Vorschau, **zweistufige Bestätigung** (3 s; Augen/Hand mit der längeren Zeile §2.6); genommene Zeilen zeigen „Genommen – im Glas, in der Sammlung" usw. Während der Handlung: **Schleier** (`hud/veil.gd`, 85 % Tintenblau `#1F2A3A`, 0,6 s Ein-/Ausblendung) mit Aktionsbalken und der Zeile. Untersuchungs-Karte: Ursache „laut Osric: Fieber · gedeutet: Arsenik", sobald gedeutet.
- **Pult-Panel** `&"pult"`: Präparate im Inventar und im Kühlfach; Karten „Einlegen (5 Min)", „Schaupräparat (40 Min)", „Knochenpräparat (60 Min)", „Begutachten (20 Min)" und **„Arzneien"** (Rezeptkarten aus Quasts Rezeptbuch mit gewähltem Präparat, Zutaten, Ergebnis, Quasts Preis), Zutatenzeilen wie das Werkstatt-Panel (mit Schuppen-Holen ab Schuppen 2).
- **Aufträge** `&"orders"` (Gemeindetafel und Dialog): Karten mit Titel, Auftraggeber, Text, Bedingungen als Häkchenliste („Totenhemd ✓ · Aussegnung – · Lindenacker ✓"), Frist („noch 2 Tage"), Lohn (Münzen, Beziehung als Pfeil, Ruf), Knopf „Annehmen" / gedimmt „Vier Aufträge laufen schon." · Kopfzeile der Tafel mit Ruf. **Merkbuch-Seite „Aufträge":** aktive (mit Fortschritt), erledigte (mit Datum nach dem Kalender aus Phase 5), gescheiterte (grau).
- **Merkbuch-Seite „Hollerbrück":** acht Karten (Icon-Porträt aus dem Icon-Renderer, Name, Rolle, Beziehung als Wort + fünf Punkte, „Zuletzt gesprochen: heute", Laden-Zeiten, mag: „?" bis zum ersten angenommenen Geschenk), dazu die Ruf-Stufe des Dorfes. Die Pietät bleibt verborgen.
- **Geschenk-Panel** `&"gift"`: Inventarzeilen, die die Person mag (ab dem ersten Treffer bekannt), „Schenken"; einmal je Tag.
- **HUD:** Beim Betreten einer Region für 3 s unten links der Ortsname („Hollerbrück · Anger", `RegionConfig.arrive_text`). **Gerede-Blasen** über Dorfbewohnern wie die Geisterblasen (`remark_bubbles.gd`, 4 s, eine zugleich). Zielzeile (`ObjectiveResolver`, nach den Ketten aus Phase 4–6): „Sprich mit Osric" · „Geh nach Hollerbrück" (Wegstein) · „Der Schultheiß erwartet dich in der Amtsstube" · „Lindenacker: 4/10" · „Bitte den Pfarrer um die Weihe" · „Der Pfarrer kommt am Vormittag" · „Bring die Leiche in die Gruft" · „Der Wundarzt will dich sprechen" (einmal) · „Auftrag: <Titel> (noch n Tage)" (dringendster) · „Wiebke Hagedorns letzter Wunsch" · „Merkbuch: Hinweise passen zusammen" · „Ein Name im Dorf: 3/4" · danach „Die Gemeindetafel hat neue Bitten".
- **Prompts:** Wegstein „[E] Nach Hollerbrück (30 Min)" / mit Leiche gedimmt · Brücke „[E] Zum Friedhof (30 Min)" · Türen „[E] Holderkrug betreten" · „Geschlossen. Öffnet um 14:00." · Laden „[E] Kaufen und verkaufen" · Tafel „[E] Gemeindetafel lesen" · Armenkasse · Abschrift · Grab „[E] Präparat beisetzen: Herz von Hedwig Lamprecht (10 Min)" · Ruhezeit-Grab „[E] Neuen Stein setzen (20 Min)".
- **Grabregister** (Hütte): Spalte „Präparate" (Anzahl, zurückgelegt als ✓); Lindenacker als Abschnitt; Ersatzsteine auf `old_01`/`old_08` vermerkt. **Totenzettel:** Präparate mit Verbleib, Befund, „laut Quast". **Tageszusammenfassung:** + „Im Dorf" (Einnahmen, Ausgaben nach Zweck), „Aufträge erledigt", „Beziehungen" (Pfeile), „Präparate".
- **Abschluss-Panel** Variante `&"name_in_village"` (§1.5).

## 8. Assets (P5, Stil gesperrt, alle `ph_`, `lib_painted.py` / geteilte Materialien)
| Asset | Zweck | Dreiecke | Hinweise |
|---|---|---|---|
| `ph_bld_v_church` | Kirche St. Gallus (Schiff + Turm, Tür, Kirchplatz-Stufen) | ≤ 9 000 | Marker `door_outside`, `light_door`, `light_window_*`; Turm Nordende ≤ 17 m; Kalkputz warmgrau, Schiefer `#5B6168` |
| `ph_bld_v_office`, `ph_bld_v_inn` | Amtshaus, Holderkrug (Fachwerk, zwei Geschosse) | ≤ 6 500 / 7 000 | `door_outside`, `light_window_*`, Holderkrug + `light_lantern`, Wirtshausschild mit gemaltem Holunderzweig (kein Text außer „Holderkrug") |
| `ph_bld_v_smithy`, `ph_bld_v_shop`, `ph_bld_v_surgery`, `ph_bld_v_remise` | Schmiede (offen, Esse, Amboss), Krämerladen (Ladenfenster mit Klappladen), Wundarzthaus (Messingschild), Remise | ≤ 4 500 / 4 500 / 6 000 / 3 000 | `counter`, `anvil`, `light_ember`, `smoke`, `door_outside` |
| `ph_bld_v_cottage_a/_b`, `ph_bld_v_house_a/_b/_c`, `ph_bld_v_inn2` | Katen (Hagedorn, Dorn), Wohnhäuser, „Zum Stumpf" | ≤ 3 000 / 4 500 / 4 500 | Marker `ribbon`, `light_window`; Katen First ≤ 4,5 m |
| `ph_prop_v_well`, `ph_prop_v_bridge`, `ph_prop_v_board`, `ph_prop_v_shrine`, `ph_prop_v_sign`, `ph_prop_v_ribbon`, `ph_prop_v_bench`, `ph_prop_v_wash_stones`, `ph_prop_v_cart_rest` | Brunnen, Holderbrücke, Gemeindetafel, Bildstock, Ortstafel, Trauerflor, Bank, Waschplatz, abgestellter Karren | ≤ 1 500 / 3 000 / 800 / 600 / 400 / 150 / 400 / 500 / (bestehender Handkarren) | Trauerflor: schwarzes Band mit Schleife, kein Text |
| `ph_env_linden_old`, `ph_env_brook`, `ph_env_ground_village`, `ph_env_garden_fence` | alte Linde (Dorf + Lindenacker), Bachlauf (flaches gemaltes Wasser, **ohne** neuen Shader, Vertex-Farbe + bestehendes Material), Dorfboden, Gartenzaun | ≤ 6 000 / 2 000 / (Boden) / 300 | Linde mit `painted_foliage` wie die Eiche |
| `ph_prop_milestone` | Wegstein „Hollerbrück · 3 Meilen" am Kutschweg | ≤ 500 | Label3D wie die Friedhofstafel |
| `ph_int_inn_*` (`room`, `bar`, `table`, `stove`, `barrels`, `stairs`), `ph_chr_guest_a/_b` | Gaststube, sitzende Gäste ohne Rig | ≤ 9 000 / 1 500 / 600 / 1 200 / 800 / 600 · ≤ 2 500 | `door_inside`, `spawn_inside`, `light_*` |
| `ph_int_surgery_*` (`room`, `table`, `cabinet`, `desk`, `bag`) | Wundarztstube: Gläser **trüb und verschlossen**, Etiketten ohne lesbaren Text, kein Skelett | ≤ 7 000 / 900 / 1 800 / 1 200 / 400 | – |
| `ph_int_office_*` (`room`, `desk`, `shelf`, `poor_box`, `lectern`) | Amtsstube, Armenkasse, Lesepult mit Buch | ≤ 7 000 / 1 000 / 1 200 / 600 / 700 | – |
| `ph_int_pult` | Präparierpult in der Gruft: Pult mit Schieferlade (Kühlfach), Glasreihe **unter einem Tuch**, Wachsstange, Etiketten, Mörser, Rezeptbuch, kleine Fläschchenreihe | ≤ 2 400 | Marker `use`, `cold` |
| `ph_int_collection_shelf` | Sammlungsregal: sieben Fächer hinter **Tuchvorhängen**, Etikettenleiste; belegte Fächer zeigen nur den Glasrand bzw. den Holzkasten unter dem halb gezogenen Tuch | ≤ 2 000 | Marker `slot_1…7`, `use` |
| `ph_int_surgery_lectern`, `ph_int_surgery_bench`, `ph_int_surgery_shutters`, `ph_chr_student_a/_b/_c` | Vorlesung: Lesepult, zwei Bänke, geschlossene Fensterläden (nachts), drei sitzende Studenten ohne Rig (Mantel, Mütze, Notizbuch, von hinten bzw. im Halbprofil) | ≤ 800 / 600 / 400 / je ≤ 2 500 | Marker `jar_spot`, `seat_1…3` |
| `ph_chr_v_innkeeper`, `_smith`, `_grocer`, `_priest`, `_mayor`, `_surgeon`, `_washer`, `_oldwoman` | die acht Dorfbewohner auf dem **gemeinsamen 8-Knochen-Rig** (wie Ilse), Animationen `idle`, `walk`, `talk`, dazu `work` (Schmied, Liesel, Krämerin) und `sit` (Hagedorn) | je ≤ 9 000 | 4–5 Kopfhöhen, eigene Silhouette je Figur (Hut/Haube/Barett/Kahlkopf/Stock), Palette der Figuren; Gesichter einfach |
| `ph_prop_corpse_poppy` (Kindmesh `poppy` für Look 1) | D1: Mohnsträußchen am Mieder | ≤ 300 | – |
| `ph_item_prep_jar`, `_prep_jar_small`, `_spirits`, `_beeswax`, `_anatomy_case`, `_specimen_jar`, `_specimen_bundle`, `_display_specimen`, `_bone_specimen`, `_fever_tincture`, `_wound_salve`, `_corpse_balm`, `_antidote`, `_bitter_drops`, `_dropsy_powder`, `_honey_cake`, `_elder_wine` | Item-Icons | ≤ 800 | **Präparat im Glas:** trübes Glas mit Wachsdeckel, Papieretikett, Inhalt nur als dunkler, unbestimmter Schatten; **Augen:** dasselbe als kleines, fast schwarzes Glas mit zwei Siegeln, nichts erkennbar; **Bündel:** Leinen mit Schnur; **Knochenpräparat:** geschlossener Holzkasten mit Leinenpaket und Etikett; **Schaupräparat:** Glasglocke auf Holzsockel mit Siegel; **Arzneien:** beschriftete Fläschchen und Pulverbriefchen „nach Quast". Kein Rot, keine Organformen |
- Wiederverwenden: Friedhofs-Zaun, Holunderbüsche, Bäume, Laternenpfahl, Handkarren, Phase-6-Trauergäste (Gaststube), `ph_prop_corpse_shrouded` (Tuch beim Präparat), Bänke.
- **Kein Gore:** keine offenen Leiber, keine Organe außerhalb trüber Gläser, keine Augen und keine Hand sichtbar (nur das dunkle Glas und der Holzkasten), kein Blut, keine Instrumente im Detail (das Besteck ist eine geschlossene Ledertasche), keine Darstellung der Arznei-Herstellung. Kein Gehirn, kein Schädel.

## 9. Performance-Budget (Phase 7, Messung mit `village_shots.gd` und `graveyard_shots_phase7.gd`)
| Größe | Budget | Begründung |
|---|---|---|
| FPS | 60 @ 1080p Mittelklasse-GPU | unverändert |
| Draw Calls Dorf | < 1 000 (erwartet ≤ 500) | 12 Häuser à ≈ 6–10, Figuren 9 × 3, Requisiten, Gras-Chunks |
| Draw Calls Friedhof | wie G6 (≤ 600) | der Lindenacker bringt ≈ +20 (8 Gräber, Zaun, Linde) |
| Kamera-Dreiecke inkl. Gras (Spiel-Zoom) | < 500 k Dorf und Friedhof | Dorf-Gras × 0,5; Figuren je ≤ 9 k |
| Sichtbare Figuren mit Skelett | ≤ 9 im Dorf, davon **≤ 6 voll animiert** (`NpcConfig.max_full`) | `NpcLod`: Stufe 1 (gedrosselte Auswertung 5 Hz) ab 26 m, Stufe 2 (Animation ruht) ab 40 m oder in einem nicht aktiven Raum |
| Lichter Dorf | ≤ 2 Omni mit Schatten (Holderkrug, Kirchentür), ≤ 22 sichtbar | Fenster, Brücke, Linde, Esse ohne Schatten |
| Lichter innen | ≤ 2 mit Schatten, ≤ 8 sichtbar je Raum | wie Phase 6 |
| Partikel | ≤ 60 je Region | Dorf: Esse-Funken 4, Kaminrauch 4 × 3 |
| Regionswechsel | Abblende 0,8 s, Hänger ≤ 60 ms in der Mitte | Dorf vorgebaut; nur Sichtbarkeit, `process_mode`, `refresh()` der 9 Npc, Kameraprofil |
| Skripte CPU/Frame (headless, Uhr läuft) | **Dorf aktiv:** ≤ Friedhofs-Referenz derselben Messung + 0,3 ms · **Friedhof aktiv:** Phase-7-Anteil ≤ +0,1 ms gegenüber 705bd5a | inaktive Region ist `PROCESS_MODE_DISABLED`; Npc der inaktiven Region werten einmal je Spielminute aus; Läden, Aufträge, Beziehungen, Präparate ohne `_process` (ereignis- bzw. stundengetrieben); `NpcLod` 2 Hz; Gerede über `NpcLod`, keine Areas |
| Neues Spiel / Laden | ≤ 600 ms / < 1 s | Dorf-Szene + 3 Räume zusätzlich im Baum |
| Spielstand | < 350 kB | + ≈ 6 kB Dorf (Beziehungen, Aufträge, Läden, Präparate) |
*Hinweis CPU (Lehre G4–G6):* Der geteilte Container misst ±0,7 ms Rauschen. Deshalb vergleicht W3 **relativ in derselben Messung** (Dorf aktiv vs. Friedhof aktiv vs. Phase-7-Teile aus) und protokolliert Median und Mittel über ≥ 3 Läufe. Liegt der Dorf-Anteil über +0,3 ms, senkt P1 zuerst `max_full` auf 4 und die Stufe-1-Rate auf 3 Hz, bevor Inhalte gekürzt werden.

## 10. Tests
Regeln wie Phase 3–6 (Fixtures statt fremder Moduldaten, Fehler-Logger, Watchdog). **Alle 2 017 bestehenden Tests bleiben grün**; Anpassungen nur durch den Besitzer (z. B. `HARVEST_KINDS`-Länge, Item-Zählungen, Exam-Tabs 3 → 4, Laufgrenzen/Layout-Diff im Welt-Test).

**Unit**
| Datei | Besitzer | Prüft |
|---|---|---|
| `test_regions.gd` / `test_house_door.gd` / `test_schedule_resolver.gd` (+) | P1 | `RegionRoot.apply_region` (aktiv/inaktiv, `managed_paths` unsichtbar + DISABLED, Npc-`refresh` bei Aktivierung, Basisprofil der Kamera, `clear_profile` → Region); Portal-Sperrgründe (Leiche, Handlung, Flag); Reise: +30 Min genau einmal, `region_changed` nach `interior_*`; Türen: Öffnungsfenster, „Öffnet um …", Ausgang zurück zur Haustür; `today_flag`-Alternativen, `region`-Filter, alte Zeitpläne bitgleich (`day -1`) |
| `test_npc_lod.gd` | P1 | Rangfolge nach Abstand, `max_full`, Stufen 0/1/2, Npc in inaktiver Region einmal je Minute, Animation ruht, `hide_flag`, Gerede-Nähe einmal je Tag |
| `test_village_shops.gd` | P2 | Preise (Grund, Verrufen +1, Vertraut −1 ab 4, nie < 1), Vorrat/Tag und Ankauf/Tag (Reset 06:00, nicht durch Laden), atomar (Münzen/Platz), `is_open` nur am Laden-Ort, `shop_trade`, Münzbuch `village`, `requires_tier` |
| `test_relationships.gd` | P2 | Startwert (Ruf- und Pietät-Bonus), Stufen 15/40/70, Klemme 0…100, Gespräch +1 je Tag, Geschenk nur gemocht und einmal je Tag, Runde für alle in der Gaststube, Spende, Präparat-Verkauf/-Rückgabe-Deltas, `count_at_least`, Gerede-Vorrang, Save/Load |
| `test_orders.gd` | P3 | alle sechs Arten; Freigaben (Flag, Vorgänger, Stufe), `max_active 4`, Fristen 06:00, Scheitern (Beziehung −4, `fail_rel`), Bestatt-Bedingungen (`wait`/`broken`/`done`), `unharvested` scheitert beim Nehmen, Stein-Abgleich, Tafel deterministisch mit Abkühlzeit, Lohn einmal, Save/Load |
| `test_village.gd` / `test_expansion.gd` (+) | P3 | Freischaltung (Morgen/Laden v5/v6, idempotent), Weihe-Preis je Stufe, Weihetag (Pfarrer-Eintrag gilt nur heute), `consecrate` + `try_unlock` in beiden Reihenfolgen, `unlock_flag`, Runde/Spende je Tag, Trauerflor deterministisch, Kapitel genau einmal (alle vier Bedingungen, jede Reihenfolge), Ersatzstein auf `old_01`/`old_08` nur mit Auftrag (Zustand bleibt OLD) |
| `test_specimens.gd` / `test_anatomy_harvest.gd` | P4 | Sperrgründe (Karte unsichtbar ohne `anatomy_known`/außerhalb der Gruft, eingekleidet, Frische < 0,3, Werkzeug, Behältnis je Organ: Augen nur Glas, Hand nur Bündel, Zutaten, Platz, **höchstens 3 je Leiche**), Wirkung je Organ (Tabelle §2.6: Ruf, Pietät, Qualität beim Zeichen, Geist), kein `full_prep`, Klarheit = Frische am Ende, Bündel-Verfall 600 Min und × 0,25 im Kühlfach (Fenster, Mehrtagessprung, Laden mitten im Fenster), Preise (§2.6.1 mit Ansehen), Verkauf/Gutachten/Vorlesung/Arznei/Rückgabe schließen sich aus, Befund-Vorrang, verborgene Ursachen deterministisch, `kept`, Save/Load |
| `test_inventory_unique.gd` | P4 | Einzelstücke: ein Platz je Stück, `uid` bleibt bei Truhe/Schuppen/Kühlfach-Transfer, `remove_uid`, Save/Load mit und ohne `uid`, alte Stände unverändert, `ChestTransfer` |
| `test_ghosts.gd` (+) / `test_corpse_generator.gd` (+) | P4 | `robbed_count` mit Rückgabe, Grund `robbed_organ`, Pools `by_organ`/`by_returned` einmal je Grab; `hidden_cause` aus dem Seed, Story-Leichen ohne |
| `test_pult.gd` / `test_recipes_phase7.gd` / `test_medicines.gd` / `test_collection.gd` | P7 | Bau (Material + 12 Münzen, nur Gruft ≥ 1), Kräuter-Rezepte, Totensalbe als Räucher-Ersatz (× 0,25, 18 h), Kühlfach meldet Fenster, Schau- und Knochenpräparat, Begutachten (Stück bleibt, Karte einmal), Arzneien (nur erlaubte Organe, Klarheit ≥ 0,45, Präparat verbraucht, Ausgabe 2/2/1), Sammlung (ein Organ je Fach, kein Bündel, Sätze einmal belohnt auch nach Herausnehmen und Wiederaufstellen, Ansehen nie sinkend, Preisbonus ≤ 2), Schuppen-Ausschlüsse |
| `test_lectures.gd` / `test_deductions.gd` | P8 | Vorlesungsabend (`Tag % 3`, 23:00–00:30, Tür nur dann), Einladung, ein Abend einmal, Bündel abgelehnt, Honorar (Organ, Ansehen), Lehrsatz einmal, Pietät −3, Gerede deterministisch (25 %/10 %) mit Ruf/Pfarrer/Liesel am Morgen einmal; Deutung: Karten-Sammlung je Toter (Befund, Funde, Lehrsätze), `needs_any`/`needs_all`, falsche Deutung ohne Folgen und ohne Zähler, richtige einmal (Hinweis, `revealed_cause`, Stat), `d_still_heart` → `c_v_still_heart`, Save/Load |
| `test_dialogue.gd` (+) / `test_story.gd` / `test_journal.gd` (+) / `test_save_migration.gd` (+) / `test_save.gd` (+) / `test_game_state.gd` (+) | P6 | neue Bedingungen/Aktionen; Osric `p7_intro` einmal; Quast-Angebot (annehmen/ablehnen/später); Ilses neue Fragen und Hinweis; D1 fällig nach `after_flag + 8` nur mit Weihe, Reservierung im Lindenacker, `hagedorn_dead` um 00:00; Erkenntnisse `i_deathbook`/`i_burn_it`; **7 v5-, 7 v4-, 6 v3-, 4 v2-, 3 v1-Fixtures laden ohne Fehler/Warnungen**; v6-Roundtrip identisch; Version 7 → abgelehnt |
| `test_assets_phase7.gd` | P5 | Modelle vorhanden, Budgets §8, Marker (`door_outside`, `door_inside`, `spawn_inside`, `counter`, `anvil`, `ribbon`, `light_*`, `use`, `cold`), Rig/Animationen der acht Figuren (gemeinsames Skelett, `idle`/`walk`/`talk`), Höhen (Katen ≤ 4,5 m, Kirchturm ≤ 17 m), Icons; **Stilregel:** Präparat-Icons ohne gesättigtes Rot (Pixelprüfung) |
| `test_ui_phase7.gd` | W-UI | Laden-, Wundarzt-, Auftrags-, Geschenk-, Pult-, Sammlungs-, Vorlesungs- und Deutungs-Panel (Werte = Systeme, Gründe), Präparate-Karte (sieben Zeilen, Grenze 3, zweistufig, Schleier an/aus, Folgenzeile), Merkbuch „Aufträge"/„Hollerbrück"/„Ursache deuten", Zielzeilen, HUD-Ortsname, Gerede-Blase, Register/Totenzettel/Tageszusammenfassung, Debug-Befehle |
- `test_lecture_night.gd` (P8): eingeladener Totengräber reist um 22:30 ins Dorf, Tür der Wundarztstube öffnet nur am Vorlesungsabend, Vorlesung mit echtem Präparat, Rückweg, Gerede am Morgen nach dem deterministischen Seed; Roundtrip mitten in der Nacht vor der Vorlesung.

**Integration**
- `test_region_travel.gd` (P1): Wegstein → Dorf → Gaststube → Dorf → Friedhof mit echter `HutPortal`/`RegionTravel`-Kette; Uhr +60 Min gesamt; Kamera-Profil je Ort; Speichern/Laden in jedem der fünf Zustände (Friedhof, Dorf, Gaststube, Gruft, Kapelle) → identische Ansicht.
- `test_phase7_loop.gd` (W-Welt): v5-Fixture `slot_p6_day40_reverent` laden → `village_open` → Osric `p7_intro` (echter `DialogueRunner`) → Wegstein → Fenner (Lindenacker, Brunnen) → Lindenacker räumen (echte Hindernisse) → Weihe bezahlen → nächster Tag 10:30 geweiht, Abschnitt offen → Lieferung → Gruft-Tisch → **Präparat im Glas** (zweistufig) → Grab im Lindenacker → Wundarzt: verkaufen / Gutachten → Pult: begutachten, Arznei, Sammlung → **Deutung** im Merkbuch (richtig und falsch) → Vorlesungsabend (Debug-Tag) mit echter Reise → zweite Leiche: **Präparat beisetzen** (Geisterstimmung zurück) → Aufträge liefern, Stein für `old_08` → D1 per Debug fällig → Bestatt-Auftrag → Hinweise → `i_deathbook` → drei Vertraute (Debug-Hilfe nur für Zeit) → **Kapitel**. **Roundtrip** `collect_state()` identisch nach `save_game`/`load_game` an 6 Momenten: im Dorf mit Präparat im Inventar; in der Gaststube um 23:00; Bündel im Kühlfach mit offenem Fenster; am Weihetag 10:00 (Pfarrer auf dem Friedhof); Auftrag angenommen mit Frist; nach dem Kapitel.
- `test_phase6_save_upgrade.gd` (P6): `slot_p6_crypt_table` laden → Präparate erst nach `anatomy` → Zopf bleibt genommen, Herz dazu → Qualität −1 −2; `slot_p6_chapel_carry` laden → Kapelle, `region graveyard`, Aussegnung weiter möglich.
- `test_village_world.gd` (W-Welt): Häuser, Türen, Läden, Wegpunkte an den Positionen §4.2/§4.4; Sichtprüfung und Wege §4.5 vollständig; Frustum-Test: von keinem Dorf-Kamerastandpunkt ist der Friedhof oder ein Innenraum im Bild und umgekehrt.
- `test_graveyard_world.gd` (+): Layout-Diff gegen `layout_p6.json`: nur R1, L1–L9, P1, N1, N2 und neue Einträge; Lindenacker-Sicht und -Wege §4.6; keine neue Verdeckung.
- `test_interiors.gd` (+): drei neue Räume an ihren Ursprüngen, Frustum, ≤ 2 Schattenlichter, `door_id`-Ausgang.
- **Playthrough-Bot (W3):** `phase7_bot.gd` erweitert `Phase6Bot` um Reisen (echte Portale, Wegminuten über die Uhr), Dialoge über den echten `DialogueRunner`, Laden-, Auftrags-, Geschenk-, Wundarzt- und Pult-Panel, Lindenacker räumen, Weihe, Präparate über die echte Präparate-Karte (zweistufig), Rückgabe am Grab. **Münzbuch je Strategie** (+ Zwecke `village`, `donation`, `round`, `consecration`; Einnahmen „Auftrag", „Verkauf im Dorf", „Präparat", „Vorlesung", „Sammlung", „Arznei").
  | Strategie | Start | Tage | Verhalten | Erwartung |
  |---|---|---|---|---|
  | `neighbor7` | v5 `day40_reverent` | 13 | Bogen A §1.4, keine Präparate | Kapitel B11–B13 (G7 Runde 2 angepasst); Ende 30–110; Morgenstand nie < 5 (G7 Runde 2 angepasst, vorher 15); ≥ 8 Aufträge; Pietät nicht gesunken |
  | `anatomist7` | v5 `day40_reverent` | 13 | Besteck angenommen; jede Leiche außer D1 Herz + Augen + Hand; 10 an Quast, 7 in die Sammlung, 4 in Vorlesungen | Kapitel erreicht (Sterbebuch über die Amtsstube); Pfarrer und Liesel höchstens „Bekannt"; Ende ≤ `neighbor7` + 40 (Anatomie nicht dominant, §2.10); Ansehen ≥ 2; Geister der Lindenacker-Gräber unruhig |
  | `scholar7` | v5 `day41_mender` | 13 | Herz, Leber, Magen im Glas; alles begutachten und deuten, Arzneien für die Arznei-Aufträge, zwei Bündel ins Kühlfach und einlegen, zwei Gläser zurücklegen | jede mögliche Deutung richtig gefunden; falsche Versuche ohne Folgen; `i_burn_it` (wenn eine gezeichnete Leiche kam); Rückgabe hebt die Stimmung; Ende ≤ `neighbor7` + 40; Kapitel erreicht |
  | `penitent7` | v5 `day45_harvester` | 13 | keine Präparate, Spenden 2/Tag, Runden, Geschenke | Ruf steigt ≥ eine Stufe; Kapitel erreicht |
  | `founder7` | v5 `day37_founder` | 15 | `crafter` + Phase 7 | Kapitel ≤ Tag 55; alte Kapitel unverändert |
  | `save_load7` | wie `neighbor7` | 13 | lädt jeden Morgen, einmal in der Gaststube und einmal mit Bündel im Kühlfach | bitgleich zu `neighbor7` |
  - Phase-3/4/5/6-Bots unverändert grün: Sie sehen nach ihrem Kapitel `village_open`, reisen aber nicht. Ohne Dorf bleibt der Lindenacker zu.
- **Save-Fuzzer (W3):** + echter v6-Stand mitten in Phase 7 (Spieler in der Gaststube, Präparate im Inventar und Kühlfach, Bündel mit offenem Fenster, 3 aktive Aufträge, Weihetag) mit gezielten Mutationen (`region_id`, `uid` doppelt/fehlend, `specimens.records`, Auftragszustände, Beziehungswerte außerhalb 0…100, `returned` ⊄ `harvested`) + alle v5…v1-Fixtures. Neu in der Konsistenzprüfung: jede `uid` höchstens in einem Platz; gehaltene Records ohne Platz → Warnung erlaubt, Zustand bleibt; `returned ⊆ harvested`; unbekannte Region → Friedhof.
- Art-Prototyp-Regression: `test_art_prototype.gd` unverändert grün.

## 11. Screenshot-Liste Gate G7 (`village_shots.gd -- --out=/abs/dir`, `graveyard_shots_phase7.gd -- --out=/abs/dir` + `ui_screenshots.gd --phase7`, 1280×720 → `docs/reviews/phase7_round1/`)
| # | Motiv |
|---|---|
| p7_00 | Wegstein am Ende des Kutschwegs, Spieler davor, Tag (Prompt sichtbar) |
| p7_01 | Ankunft an der Holderbrücke, Ortstafel, Bildstock, Holunder, Morgen |
| p7_02 | Anger Übersicht Tag (Zoom 24): Kirche, Amtshaus, Holderkrug, Brunnen, Linde, Schmiede, Leute an ihren Orten |
| p7_03 | Anger am Nachmittag (14:30): Brunnen mit Theres und Liesel, Hagedorn an ihrer Pforte, Fenner an der Tafel |
| p7_04 | Anger in der Abenddämmerung: Holderkrug-Laterne, Fenster warm, Esch unter der Linde |
| p7_05 | Dorf nachts: Kirchentür-Laterne, Brücke, dunkle Katen, Osric auf dem Weg in den Holderkrug |
| p7_06 | Kontaktbogen der acht Dorfbewohner (idle, gleiche Kamera, Namen darunter) |
| p7_07 | Schmiede mit Esse-Glut, Esch am Amboss, Laden-Prompt |
| p7_08 | Krämerladen mit offenem Fensterladen, Theres |
| p7_09 | Kirche St. Gallus mit Pfarrer Lenz an der Tür |
| p7_10 | Gaststube Tag / Nacht: Rosine am Schanktisch, Gäste, Osric im Eck, „Eine Runde für alle" |
| p7_11 | Wundarztstube: Quast am Pult, Glasschrank mit trüben Gläsern |
| p7_12 | Amtsstube: Fenner, Armenkasse, Lesepult mit der Abschrift |
| p7_13 | Lindenacker vorher (Wald, Stümpfe, Brombeeren) / geräumt / belegt mit Steinen, Linde am Rand |
| p7_14 | Weihetag: Pfarrer Lenz an der Lindenacker-Pforte, Spieler daneben |
| p7_15 | Trauerflor an der Hagedorn-Kate, Liesel davor |
| p7_16 | Gruft mit Präparierpult (Glasreihe unter dem Tuch, Kühlfach) |
| p7_17 | Präparate-Karte am Gruft-Tisch, Zeile geschärft („Wirklich? Noch einmal drücken.") |
| p7_18 | Während des Präparats: Tuch über der Leiche, Schleier, Aktionsbalken, Zeile |
| p7_19 | Laden-Panel (Theres, Rabatt bei „Vertraut") |
| p7_20 | Wundarzt-Panel mit drei Präparaten (Glas, Bündel mit Verfallsanzeige, Schaupräparat) |
| p7_21 | Gemeindetafel-Panel mit zwei Angeboten und Kopfzeile Ruf |
| p7_22 | Merkbuch „Hollerbrück" (acht Karten) und „Aufträge" |
| p7_23 | Gerede-Blase über Rosine („Wackernagel hat für dich einen Stuhl am Ofen frei …") |
| p7_24 | Präparat beisetzen am Grab (Prompt + Aktionsbalken) und Geist mit `by_returned`-Blase in der Nacht |
| p7_25 | Geist mit `by_organ`-Blase über einem Lindenacker-Grab |
| p7_26 | Neuer Stein auf `old_08` (Dorothee Mahn) neben dem alten an der Gruft-Treppe |
| p7_27 | Merkbuch: Erkenntnis „Vorher eingetragen" |
| p7_28 | Abschluss-Panel „Ein Name im Dorf" |
| p7_29 | Sammlungsregal in der Gruft mit zwei vollständigen Sätzen (Tuchvorhänge halb gezogen) und das Sammlungs-Panel |
| p7_30 | Anatomie-Vorlesung nachts: geschlossene Läden, Lampe, Quast am Lesepult, drei Studenten von hinten, Schleier 60 % |
| p7_31 | Deutungs-Panel: Befund „weißlicher Belag", Lehrsatz „Arsenik …", Ursache gewählt, „Deuten" / Ergebnis „Gedeutet: Arsenik" |
| p7_32 | Pult-Panel „Arzneien" mit Leberglas und zwei Bittertropfen als Ergebnis |
| p7_33 | Präparate-Karte mit sieben Zeilen, „Genommen: 2 von höchstens 3", Augen-Zeile geschärft mit der längeren Zeile |
| p7_vis_village / _linden | Sichtprüfung §4.5/§4.6 mit eingezeichneten Strahlen (frei grün, verdeckt rot), Zoom 12/22/24 |
Dazu Asset-Tafeln `docs/reviews/phase7_assets/` (Gebäude, Figuren mit Rig-Posen, Items) und eine Performance-Tabelle (`perf_p7_01…05`: Anger Tag Zoom 24 mit 9 Figuren · Dorf nachts · Gaststube abends voll · Friedhof mit Lindenacker belegt · Gruft mit Pult und vollen Nischen).

## 12. Wellenplan
| Welle | Agents (parallel) | Inhalt | Ende |
|---|---|---|---|
| **W0** | Lead | **Zuerst v5-Fixtures mit Build `705bd5a`** (7 Stände §5.2, eigener Commit vor jedem Gerüst) und `tests/fixtures/phase7/layout_p6.json`. Dann: Datenklassen ✦ (inkl. Erweiterungen), Stubs mit exakten Signaturen, 11 EventBus-Signale, Database-Ordner, `SaveMigration.CURRENT = 6` mit `migrate_5_to_6` als Identität (fail-safe), Config-Fixtures `tests/fixtures/phase7/` (+ `Phase7Fixtures`, u. a. `region_at(id, tree)`, `villager(npc, value)`, `order_in(id, state)`, `specimen(organ, container, clarity, corpse)`, `shelf_with(organs)`, `lecture_night(day)`, `cards_for(corpse, ids)`, `shop_with(stock)`, `linden_open(tree)`), Prüfung aller `npc_id`-Lookups auf Region (§3.4), `test_phase7_scaffold.gd`, `test_saves_v5_load.gd` | Import + alle Tests grün → Commit |
| **W1** | **8 Pakete:** P1, P2, P3, P4, P5, P6, P7, P8 (bei 5 Agents: P1 · P2 + P7 · P3 + P6 · P4 + P8 · P5) | Systeme mit Unit-Tests gegen Fixtures (ohne Welt): Regionen/Portale/Türen/NPC-LOD/Zeitplan-Region (P1) · Läden/Beziehungen/Gerede (P2) · Aufträge/Dorf/Weihe/Kapitel/Ersatzstein (P3) · Anatomie-Kern: Präparate-Karte mit sieben Organen, Einzelstücke, Verderben, Verkauf, Gutachten, Befunde, Rückgabe, Geister (P4) · Assets + Asset-Tests, **Figuren zuerst** (P5) · Dialoge der acht + Osric/Ilse, D1, Merkbuch, Migration v6 (P6) · Präparierpult: Arzneien, Sammlung, Kühlfach, Schau-/Knochenpräparat, Kräuter-Rezepte (P7) · Vorlesung und Todesursachen-Deutung (P8) | je Modul: Tests grün → Merge durch Lead, danach `--import` |
| **W2** | W-Welt, W-UI (2 parallel) | Dorf-Region (Layout, Builder, Boden, Gras, Licht, Wegpunkte, 9 Npc), drei Innenräume, Wegstein, Lindenacker (L1–L9), Pult-Platz, Pfarrer am Weihetag, **Sichtprüfungen §4.5/§4.6** und Wege, `test_phase7_loop`, `test_village_world`; alle Panels, Präparate-Karte mit Schleier, Merkbuch-Seiten, HUD, Zielzeilen, Register, Debug, Icons | Integration + Roundtrips grün, Screenshots erstellt |
| **W3** | QA (19), Art (04), Lead | `phase7_bot.gd` (6 Strategien, Münzbuch), Save-Fuzzer v6, Performance relativ (§9), Stil-/Ton-Prüfung (Dorf-Licht, Figuren, Gläser ohne Gore, Schleier, Trauerflor, Texte der acht Stimmen), Befunde beheben (Besitzer), Gate-Protokoll in `QUALITY_GATE_STATUS.md` | **STOPP – Benutzerprüfung G7** |
Abhängigkeiten:
- **P1 liefert zuerst** (Tag 1 der Welle): `RegionRoot`, `Player.region_id`, `ScheduleEntry.region` im Resolver und `Npc.region_id`. P2/P3 (Läden, Weihetag) und P6 (Zeitpläne) hängen daran. Bis dahin arbeiten Läden mit `is_open` aus dem Zeitplan allein (wie `NightTrade`).
- **P4 liefert zuerst** die Einzelstücke im `Inventory` und `Specimens.harvest/consume/inspect` (Tag 1–2): P7 (Kühlfach, Sammlung, Arzneien), P8 (Vorlesung verbraucht, Begutachten liefert Karten) und W-UI (Wundarzt-Panel) hängen daran. Bis dahin arbeiten P7/P8 mit `Phase7Fixtures.specimen(...)`.
- **P8** braucht von P6 nur die Hinweis-Daten (`c_v_*`) und `JournalManager.add_clue` (bestehend); die Deutung legt keine eigene Merkbuch-Logik an, das Panel ist W-UI.
- **Lastverteilung W1** (Richtwert Arbeitstage): P1 4 · P2 3 · P3 4 · P4 4 · P5 6 (größtes Paket, Figuren und Dorf) · P6 4 · P7 3 · P8 3.
- **P5 liefert zuerst** die acht Figuren (Rig, `idle/walk/talk`) und die Nordreihe des Dorfes (Höhen) – **Blocker** für die Sichtprüfung im Dorf. Bis dahin: graue Platzhalter-Quader in Modellmaß und die Ilse-Figur als Stellvertreter (nur Tests, nie in Screenshots).
- `graveyard.gd`: nur P3 (Ersatzstein, Aufträge). `grave_plot.gd`: nur P4 (beide Prompts). `corpse_care.gd`/`morgue_table.gd`: nur P4. `expansion_manager.gd`: nur P3. `dialogue_*`: nur P6. `npc.gd`/`schedule_resolver.gd`: nur P1.
- Texte: P6 besitzt alle Dialoge und Zeitpläne (auch Quasts Vortragszeilen in seinem Dialog), P3 die Aufträge (`data/orders/*`), P4 die Befunde und Geisterzeilen, P7 die Arznei- und Sammlungstexte, P8 die Lehrsätze und Deutungen, P2 Gerede und Bewohnerdaten. Die Leittexte stehen in §1–§2; wer sie ändert, meldet es dem Lead.

## 13. Nicht in Phase 7
- Ein durchgehend begehbarer Kutschweg, weitere Dörfer, Stadtbesuche, Reisen mit Karren oder Kutsche (Welt: Phase 11)
- Der Innenraum der Kirche, Messen, Predigten, Beichte, eigene Riten des Pfarrers am Friedhof außer der Weihe (Phase 8/11)
- Beziehungen zu Osric und Ilse, Romanzen, Hochzeiten, Kinder als Figuren, Feste, Markttage, Wochentage
- Freie Gespräche, Gerüchte-Netz, Tagesabläufe, die auf den Spieler reagieren (NPCs: Phase 8); Quest-Ketten mit Verzweigung und Belohnungsbaum (Phase 9)
- Preisdynamik, Angebot und Nachfrage, Steuern, Pacht, Kredit (Phase 10)
- Leichen ins Dorf tragen, Leichen aus dem Dorf abholen, mehr als eine Lieferung am Tag, Exhumieren
- Fleisch, Blut, Fett, Haut, Gehirn oder Schädel als Ware; Knochen außer dem Knochenpräparat der Hand; Organe als Speise oder Zaubertrank; Arzneien aus Herz, Augen oder Hand; Darstellung der Arznei-Herstellung; sichtbare Organe, offene Leiber, Sektionsszenen (auch in der Vorlesung bleibt der Tisch leer); Organe für die Auferstehung (Phase 13 – heute nur Daten); mehr als 3 Präparate je Leiche; eine Universität als Ort, Briefwechsel mit ihr (nur das Empfehlungsschreiben als Flag)
- Präparate an Ilse; Präparate aus Gräbern holen; Präparate von Geschichts-Leichen S1–S5 (bestattet)
- Wer zeichnet, und warum; Lorenz' Aufenthalt; das Gitter in der Gruft (Phase 12)
- Gegner, Diebstahl, Strafen, Verhaftung, Kirchenbann
- Neue Gebäude auf dem Friedhof, Zier im Dorf, Zier auf Ruhezeit-Gräbern; Wetter, Jahreszeiten
- Änderungen am Maler-Shader, an den Atmosphären-Presets, an den freigegebenen Abschnitten I–IV, Werkhof, Kirchhof, an Hütte, Werkbank, Stationen, Pforten und den Phase-6-Gebäuden (außer §4.6)

## 14. Benutzerentscheidungen (03.10.2026, bindend)
1. **Anbindung des Dorfes:** eigene Außen-Region mit Abblende am Wegstein und an der Holderbrücke, **30 Spielminuten** Weg je Richtung (§4.1).
2. **Lindenacker:** 8 Grabstellen südlich der Ostwiese, vom Schultheiß gegeben, vom Pfarrer geweiht; zwei (bedingt drei) Waldbäume werden versetzt (§2.9, §4.6).
3. **Organ-System – erweitert:** sieben Präparate (**Herz, Lunge, Magen, Leber, Nieren, Augen, Hand/Knochen**; die Hand als Lehrpräparat und späterer Auferstehungs-Haken) und alle vier zusätzlichen Zwecke: **Präparatesammlung** mit Sätzen und Ansehen bei der Universität (§2.7), **Arzneien aus Präparaten** für kranke Dorfbewohner (§2.7), Quasts heimliche **Anatomie-Vorlesung** bei Nacht (§2.6.4) und die **Todesursachen-Deutung** über das Verknüpfen im Merkbuch (§2.6.5). Darstellung bleibt **angedeutet** (Tuch, Werkzeuggeräusch als Haken, Abblende; nur verschlossene Gläser und Leinenbündel; kein Blut, keine offenen Wunden, kein Gehirn, keine Schädelpunkte; Augen nur im dunklen versiegelten Glas, die Hand nur in Leinen). Eigene Mechaniken bleiben: „Präparat beisetzen", Einzelstücke mit Id, Glas gegen Leinen-Verderben, Kühlfach. Neu abgewogen: Kosten je Organ (Augen und Hand am schwersten), Preise, Sätze, Arzneien, Vorlesung; die Anatomie ist kein dominanter Verdienst, der würdevolle Weg bleibt gleichwertig bezahlt (§2.10). Paketschnitt: P4 Anatomie-Kern, P7 Präparierpult mit Arzneien und Sammlung, P8 Vorlesung und Deutung (§12).
4. **Wiebke Hagedorn stirbt** als Geschichts-Leiche D1, gezeichnet, nachdem man sie im Dorf kennengelernt hat (§2.9, §1.6).

---

## W0-Notizen (Lead, Welle 0 – verbindlich für W1)
1. **v5-Fixtures** `tests/fixtures/saves_v5/*.json` wurden **vor** jeder Code-Änderung mit Stand f7d5cc5 erzeugt (Code identisch zu 705bd5a, nur Doku neu) – über `Phase6Bot` + echte Systeme (`make_v5_saves.gd` + `_driver.gd`, historisches Werkzeug; `-- --out=/abs/dir [--only=day40r,day45h,day41m,day37f,day37eve,crypt,chapel]`; auf einem Phase-7-Stand schriebe es v6). Die Endstände setzen die v4-Fixtures mit denselben Bot-Tagen fort wie `test_phase6_playthrough.gd` (reverent6/harvester6 10 Tage, mender6 11 Tage, founder 36 Tage ab neuem Spiel). Eigener Commit a0456ff vor dem Gerüst, zusammen mit `tests/fixtures/phase7/layout_p6.json` (= `data/world/graveyard_layout.json` von 705bd5a, bytegleich). Gemessene Stände:
   - *day40_reverent* (`reverent6`, 07:00 Tag 40): `roof_and_earth_complete`, Gruft 2 · Kapelle 2 · Schuppen 2, **23** Gräber `MARKED` (§1.4 nennt ≈ 24), 3 Altgräber `OLD` (`old_01`, `old_08`, **`old_03` hebbar**), 5 umgebettet, Ruf 100, Pietät 98, **20 Münzen** (= §2.10). Keine freie Stelle.
   - *day45_harvester* (`harvester6`, 07:00 Tag 45): Gruft **3** · Kapelle 2 · Schuppen 2, **63 Münzen** (= §2.10), Ruf 96, Pietät −86, 23 Gräber, 2 `OLD`, **1 freie Stelle**, 6 umgebettet, viele beraubte Seelen.
   - *day41_mender* (`mender6`, 07:00 Tag 41): 2 · 2 · 2, **41 Münzen** (= §2.10), Ruf 100, Pietät 44, 23 Gräber, 3 `OLD`, 5 umgebettet.
   - *day37_founder* (`founder`, neues Spiel, 36 Bot-Tage, 07:00 Tag 37): alle drei Kapitel, 2 · 2 · 2, **40 Münzen** (= §2.10), Ruf 100, Pietät 98.
   - *day37_eve* (`reverent6`): `roof_and_earth` fiel an **Tag 37**; gespeichert vor dem Zubettgehen um **23:05** (der Bot arbeitet bis in die Nacht; geprüft wird „Abend des Kapiteltags"), 12 Münzen.
   - *crypt_table* (`harvester6` ab `slot_p5_day35_harvester`, Tag **36**, 08:30): Gruft 1, die Tagesleiche `corpse_0019` auf dem Gruft-Tisch (`room crypt`), **„2 von 4" = `clothing` + `hands`**, Zopf genommen, offenes Kältefenster `[50880, −1, 800]`, Spieler in der Gruft. (Der würdevolle Bot hat keine Schere – deshalb harvester6.)
   - *chapel_carry* (`reverent6`, Tag **33**, 10:56): Kapelle 1, der Spieler trägt `corpse_0021` in der Kapelle (Leichenzug zur Aussegnung), Region graveyard.
   - Ungeprüft gelassen (Fixture, kein Gate): Die drei Bot-Läufe ohne `watch()` zählen kein Kapitel im Bot (`chapter6 -1` im Protokoll) – das Flag `roof_and_earth_complete` ist gesetzt und wird geprüft.
2. **Speicherformat v6 schon in W0:** `SaveMigration.CURRENT = 6` (`SaveFileIO`/`SaveManager.FORMAT_VERSION` folgen), Kette 1→…→6. `migrate_5_to_6(state, meta)` ist **Identität auf einer tiefen Kopie** (`## STUB (P6)`). **P6** implementiert §5.2 1–7. `SaveMigration.V6_EMPTY_NODES` enthält **alle neun** Knoten aus §5.2 Schritt 5 (`village, relationships, village_shops, orders, specimens, pult_store, collection_shelf, lectures, deductions`; §3.4 nennt nur die ersten sechs – Lücke, Lead-Entscheidung), wird in W0 aber **nicht** eingefügt; `SaveManager.without_absent_defaults` kennt V6 noch nicht (P6 ergänzt es wie V5, bevor die Migration die Knoten einfügt). `CorpseRecord` speichert `hidden_cause`, `returned`, `revealed_cause` **schon ab W0** (38 Felder; `returned` wird beim Laden auf ⊆ `harvested` und eindeutig gefiltert). Lade-Wächter `tests/integration/test_saves_v5_load.gd`: 7 v5-Fixtures laden **ohne jede Warnung**, Zustand erhalten, Neuspeichern v6, Roundtrip identisch. v4/v3/v2/v1-Fixtures laden weiter. Lead-Anpassungen an fremden Tests (nur Versionsnummer/Feldzahl/Listenlänge, mechanisch): siehe Punkt 12.
3. **Datenklassen ✦ vollständig** (§3.2.1): `RegionConfig`, `NpcConfig`, `VillagerData`, `ShopData`, `RelationshipConfig`, `VillageConfig`, `OrderData`, `OrdersConfig`, `AnatomyConfig`, `SpecimenFindingData`, `SpecimenRecord` (+ `to_dict`/`from_dict`, tolerant), `MedicineData`, `CollectionSetData`, `TeachingData`, `DeductionData`. Zusätze, die der Vertrag nicht nennt (rein additiv): `AnatomyConfig.ORGANS` (Reihenfolge = Sammlungsfächer) und `organ(id)`, `SpecimenRecord.CONTAINERS`/`STATE_HELD`, `CorpseRecord.ORGAN_KINDS` + `HARVEST_HEART…HAND`.
   - **`AnatomyConfig`-Defaults tragen die Vertragswerte** (Tabelle §2.6, Block `lecture` §2.6.4), nicht `{}` wie in der Kurzschreibweise §3.4 – damit gilt „data == Fixture == Klassen-Default" bis zur Übergabe. `lecture.window 90` (23:00–00:30) ist neu benannt; `organs[*].medicine` ist für Lunge, Magen, Leber, Nieren **true** (§2.7 nimmt nur Herz, Augen, Hand aus; die Lunge hat kein Rezept). `sell_rel` enthält nur priest/washer/oldwoman (§3.4); Quasts +2 steht in `VillagerData.specimen_delta`.
4. **Erweiterungen bestehender Datenklassen (Klassen-Defaults = Vertrag, die `.tres` bleiben bei ihren Besitzern unverändert):** `ScheduleEntry.region`/`today_flag`, `ItemData.unique`, `SectionData.unlock_flag`, `StoryCorpseData.after_flag/after_days/section/requires_flag/due_flag`, `CorpseRecord` (oben), `CorpseTables.hidden_causes`, `ReputationConfig.event_points` + 5, `PietyConfig.events` + `organ_taken −6` (Vertrag ohne Zahl: −6 = inneres Organ, die Menge je Organ kommt aus `AnatomyConfig`), `lecture_attended`, `specimen_returned`, `specimen_returned_grave`, `GhostLines.by_organ`/`by_returned` (`PackedStringArray`). **Abweichung:** `EconomyConfig.harvest_malus` (+ 7 Organe) und `PrepConfig.balm_items` (+ `corpse_balm`) bleiben als **Klassen-Default unverändert** – die Phase-4/5-Fixtures ohne eigene Liste und die Tests „data == Klassen-Default" (`test_grave_quality`, `test_phase4_scaffold`, `test_phase5_scaffold`) folgen dem Default. Die Werte stehen in `tests/fixtures/phase7/{economy,prep}_config_fixture.tres`; **P4** (Economy) bzw. **P7** (Prep) setzt Default und `.tres` gemeinsam und passt diese Tests an. `data/config/{economy,reputation,piety,prep,shed}_config.tres`, `ghost_lines.tres`, `corpse_tables.tres` setzen ihre Listen ausdrücklich und bleiben bis P4/P7 unverändert. **Nicht** in W0: `GameState.DEFAULT_STATS`/`COIN_REASONS` (+ Phase-7-Stats/Zwecke → P6, sonst ändern sich alle Stand-Vergleiche; wie Phase 5/6), `ShedConfig.excluded_items` (P7, Fixture hat die vier Ids).
5. **Neue Config-Dateien** mit Vertragswerten (= Klassen-Default, ausdrücklich geschrieben): `data/config/{village_config (→ P3), relationship_config (→ P2), orders_config (→ P3), anatomy_config (→ P4, Block `lecture` P8), npc_config (→ P1)}.tres`. Identische Kopien in `tests/fixtures/phase7/*_fixture.tres` (Scaffold-Test: data == Fixture == Klassen-Default bis zur Übergabe; danach dürfen die Daten abweichen, die Fixture bleibt). `data/config/regions/*` legt **P1** an (Fixture: `tests/fixtures/phase7/regions/{graveyard,village}.tres`).
6. **Nicht** in W0 angelegt (Besitzer, W1): `data/shops/*`, `data/village/villagers/*` (P2), `data/orders/*`, `data/sections/linden.tres`, neue `data/clearables/*` (P3), `data/anatomy/findings/*`, `ghost_lines.tres`-Erweiterung (P4), `data/items/*` (Phase 7), `data/recipes/*`, `data/stations/pult.tres`, `data/anatomy/{medicines,sets}/*` (P7), `data/anatomy/{teachings,deductions}/*` (P8), `data/npc/*_schedule.tres`, `data/dialogue/*`, `data/story/d1_hagedorn.tres`, `data/finds/f_d1_*`, `data/journal/*` (P6), `data/config/interiors/{inn,surgery,office}.tres` (W-Welt). Die Fixtures sind vollständige Vorlagen mit den Leittexten aus §1–§2 (kopieren erlaubt). Neue Items in `data/items` ändern ggf. Item-Zählungen in fremden Tests – der Besitzer passt sie an (Lead-genehmigt).
7. **Stubs** (Körper leer/trivial, `## STUB (P<n>)`, Signaturen exakt §3.4; Test `test_phase7_scaffold.gd` mit Liste `IMPLEMENTED`, die Besitzer füllen):
   - **P1:** `RegionRoot` (Gruppe `region_root`, `find()`/`current()` fertig), `RegionPortal` (+ `src/entities/region_portal/region_portal.tscn` mit `Interactable`; das Skript liegt laut §3.2.1 in `src/world/regions/`), `RegionTravel` (+ `TEXT_CORPSE`, `TEXT_BUSY`), `HouseDoor` (+ `.tscn`, Gruppe `house_door`, `find()` fertig), `NpcLod` (Gruppe `npc_lod`, nicht gespeichert). An bestehenden Klassen: `Player.region_id` (`&"graveyard"`) + `set_region(id)` (setzt nur den Wert; P1: Signal, Speichern, tolerantes Laden), `CameraRig.set_base_profile(p)` (leer), `InteriorRoom.region_id`, `RoomExit.door_id` (ungelesen), `Npc.region_id`/`hide_flag` (ungelesen) + `set_lod(level)` (leer), `ScheduleResolver.entry_at(schedule, minute, _day := -1)` (ungelesen – P1 benennt in `day` um).
   - **P2:** `RelationshipRules` (+ `TIERS`, `WORDS`), `Relationships` (Gruppen `relationships`, `saveable`; `"relationships"`, 51), `ShopRules`, `VillageShops` (`"village_shops"`, 52), `ShopCounter` (+ `.tscn`). **`Relationships.value()/met()` antworten schon aus `load_state({"values": {…}, "met": […]})`** (Format §5.1) – `tier()` ruft den Stub `RelationshipRules.tier` (liefert bis P2 `stranger`).
   - **P3:** `OrderRules` (+ `RESULT_*`), `Orders` (`"orders"`, 53; **`state()` antwortet aus `load_state({"states": {…}})`**), `Village` (`"village"`, 50; + `FLAG_*`), `VillageBoard`, `MourningRibbon` (ohne `Interactable`, + `refresh()`), `PoorBox`, `RegisterCopy` (je `.tscn`). An bestehenden Klassen: `ExpansionManager.try_unlock(section_id)` (false), `Graveyard.replace_old_marker(grave_id, design: StoneDesign) -> bool` (false; Typen wie `set_designed_stone`).
   - **P4:** `SpecimenRules` (`harvest_block_reason` liefert bis P4 `"-"` = keine Karte), `Specimens` (`"specimens"`, 54; **`get_record/held/of_corpse` antworten aus `load_state({"next", "records"})`**; + `ITEMS`, `UID_FORMAT "sp_%04d"`). An bestehenden Klassen: `Inventory.add_unique/remove_uid/uids/has_uid` (inert), `CorpseCare.organ_block_reason` (`"-"`) / `harvest_organ` (`""`), `MorgueTable.request_organ` (leer), `Corpse.set_covered` (leer), `GhostMood.robbed_penalty(record, cfg := null)` (W0 = Phase-6-Wert `robbed_count × robbed_mood`; `robbed_count` bleibt bis P4 Haar/Zähne; §2.11 nennt `robbed_penalty`, §3.4 `robbed_count` – beide existieren).
   - **P6:** `SaveMigration.migrate_5_to_6` (Identität), `V6_EMPTY_NODES`.
   - **P7:** `PultStore` (`extends Chest`, `_init` setzt `"pult_store"`/62; `.tscn` mit `Interactable` + `Storage`; `store()` fertig; `SLOT_COUNT 8` – Slots setzt P7), `PultRules`, `CollectionRules` (`slot_for` = Index in `AnatomyConfig.ORGANS`), `CollectionShelf` (`extends Chest`, `"collection_shelf"`/63, `SLOT_COUNT 7`; **Panel-Konstante `COLLECTION_PANEL = &"collection"`** – `Chest.PANEL` kann in der Unterklasse nicht neu definiert werden; **`standing()/sets_done()` antworten aus `load_state`**).
   - **P8:** `LectureRules` (+ `TEXT_BUNDLE`), `Lectures` (`"lectures"`, 55; **`invited()/known_teachings()` aus `load_state`**), `DeductionRules` (+ `TEXT_NO_MATCH`, `TEXT_MATCH`), `Deductions` (`"deductions"`, 56; **`cards()/deduced()` aus `load_state({"cards", "done"})`**; der Parameter `cards` von `deduce` heißt im Stub `_cards_chosen`, weil er die Methode `cards()` verschatten würde – Stelligkeit gleich), `LectureSet` (+ `.tscn` ohne `Interactable`).
   - P5: keine Stubs. W-UI/W-Welt: Panels, Builder, Szenen nicht als Stub (W2).
8. **EventBus:** die 11 Signale aus §3.3. **Eingaben:** keine neuen (§3.6). **Angehängte „Enums":** `CorpseRecord.HARVEST_KINDS` + 7 Organe (angehängt; `GhostMood.ROBBED_KINDS` bleibt Haar/Zähne bis P4); `ItemData.Category`, `GraveRecord.State`, `CorpseRecord.LOCATIONS` unverändert.
9. **Database** (§3.5): `shop/shops` (`data/shops`, nach id), `order_data/orders` (`data/orders`, nach `order`, Gleichstand id), `villager/villagers` (`data/village/villagers`, Schlüssel `npc_id`), `finding/findings` (`data/anatomy/findings`, nach `priority` aufsteigend, Gleichstand id – `SpecimenRules.finding_for` ordnet selbst „höchste zuerst"), `medicine(s)`, `collection_set(s)`, `teaching(s)`, `deduction(s)` (nach id), `region_config(id)` (`data/config/regions`, Schlüssel `region_id`; `config()` liest den Unterordner nicht). Leere/fehlende Ordner = leere Listen.
10. **`npc_id`-Lookups (§3.4):** `NightTrade._npc` nimmt nur das Npc mit `region_id == graveyard`; `DebugWorldLookup.npc_node` (W-UI-Datei, Lead-Eingriff) bevorzugt das Friedhofs-Npc. Alle anderen Stellen suchen über `get_node_by_layout_id` (Friedhof) oder Gruppen-Schleifen in eingefrorenen Aufnahme-Skripten (`graveyard_shots*.gd`, nur Darstellung) – unverändert; W-Welt prüft sie, wenn das Dorf-Npc `npc_carter_v` in der Welt ist.
11. **Fixtures für W1:** `tests/fixtures/phase7/` – erzeugt von `make_phase7_fixtures.gd` (+ `_driver.gd`, historisch; schreibt jede Eigenschaft ausdrücklich, damit Fixtures nicht späteren Klassen-Defaults folgen): `{village,relationship,orders,anatomy,npc}_config_fixture.tres` (= W0-Daten), Phase-7-Werte bestehender Configs (`economy`, `reputation`, `piety`, `prep`, `shed`, `corpse_tables` + `hidden_causes` §2.6.3, `ghost_lines` + `by_organ`/`by_returned` mit den Leittexten §2.11); `regions/{graveyard,village}.tres`; `villagers/*` (8, §2.1; `remarks` nur mit den Leitzeilen §2.4 – P2 schreibt 6–8 je Person); `schedules/*_schedule.tres` (8 Bewohner nach §2.2 mit `region village` und den Wegpunkten §4.4; der Pfarrer hat die vier Weihetag-Einträge `today_flag linden_consecration_day`, `region ""`, Weg `road_end → … → w_east_pass → w_linden_n → linden_spot`; `carter_schedule.tres` = Daten + 7 Dorf-Einträge, Friedhofs-Einträge bitgleich); `shops/*` (6, §2.3; Quast kauft zusätzlich die drei Arzneien zu §2.7-Preisen, Vorrat 2/Tag – §2.3 nennt sie nicht; Quasts `prep_jar_small 3` aus §2.8); `orders/*` (23, §2.5); `findings/*` (15), `teachings/*` (7), `deductions/*` (5), `medicines/*` (3), `sets/*` (4), `recipes/*` (3, Station `pult`), `stations/pult.tres`, `sections/linden.tres`, `story/d1_hagedorn.tres`, `finds/f_d1_*` (3), `clues/c_v_*` (7), `insights/{i_deathbook,i_burn_it}.tres`, `interiors/{inn,surgery,office}.tres` (`InteriorConfig` §4.3/§4.7 auf Basis der Kapelle), `village_layout.json` (Plan §4.2, Türen mit Öffnungszeiten, Läden, Tafel, Portal, Spawns, Wegpunkte §4.4, Innenräume §4.3), `linden_layout.json` (Eingriffe §4.6), `layout_p6.json`; `tests/fixtures/items/` + 17 Phase-7-Items (§2.8). Zugriff: `Phase7Fixtures` (`tests/fixtures/phase7/phase7_fixtures.gd`), u. a. `region_at(id, tree)`, `villager(npc, value, tree, more)`, `order_in(id, state, tree, more, accepted_day)`, `specimen(organ, container, clarity, corpse, harvest_total)`, `shelf_with(organs, display)`, `lecture_night(day, tree, teachings)` + `lecture_minute(day)`, `cards_for(corpse, ids, tree)`, `shop_with(stock, day, bought, tree)`, `linden_open(tree, open_day)`, `inv_with`, `install_save_v5`, `save_v5_path`, `layout_p6()`, `village_layout()`, `linden_layout()`, ID-Listen, `ROOMS`, `OPEN_WINDOWS`, `SAVEABLES`.
12. **Lücken, pragmatisch entschieden:**
    - **Befund-Bedingungen „A oder B"** (§2.6.3: `arsenic` oder `poisoned`, `moor_cold` oder `drowned_millpond`): `SpecimenFindingData.hidden_cause` und `cause_id` sind **Alternativen** – ein Befund mit Ursachen-Bedingung passt, wenn die *wirksame* Ursache der Leiche (`hidden_cause`, sonst `cause_id`) einem seiner beiden nicht leeren Felder gleicht (`b_moor_eyes`: `hidden_cause drowned_millpond`, `cause_id moor_cold`). `b_stones` („Seed 1 von 4") hat kein Datenfeld: P4 würfelt es aus dem Leichen-Seed. Vorrang: höhere `priority` zuerst (Fixture-Werte 30/20/10/0), `b_plain` (Organ "") ist der Rückfall.
    - `CollectionRules.completed_sets(shelf_organs, …)`: `shelf_organs = {organ: SpecimenRecord}` der belegten Fächer (Behältnis für `needs_display`); `Phase7Fixtures.shelf_with` liefert genau das.
    - Auftrags-Bedingungen ohne Vertragsschlüssel (in `conditions`, P3 liest sie): `o_rosine_tincture` `substitutes {fever_tincture: bitter_drops}` (Bittertropfen statt Tinktur, §2.7), `o_lenz_service` `chapel_level 2` (≥ Stufe 2, mit Trauergästen), `o_quast_antidote` `teaching l_stomach` (Freigabe), `o_quast_cabinet` `standing 2` (Freigabe), `o_quast_specimen` `organ [heart, lung, stomach, liver, kidneys]` + `min_clarity 0.6`. `o_hagedorn_place`: Auftraggeber `oldwoman`, `recipient washer` (nach ihrem Tod), Lohn-Beziehung als `extra_rel {washer: 8}` (`reward_rel 0`), `days_limit 3` zählt **ab Ankunft** (P3). Tafel-Aufträge: Beziehung an Fenner/Quast/Liesel als `extra_rel` (die Gemeinde hat keine Beziehung). `thanks_text` sind Platzhalter („Danke, Totengräber.") – P3 schreibt sie.
    - `d_moor` hat `cause_id moor_cold` (§2.6.5 „gezeigte Ursache" – bei `drowned_millpond` darf P8 die gezeigte Ursache gelten lassen) und `reveals_cause false` (nur bestätigt).
    - Zeitpläne: Wo §2.2 keine Minuten nennt, sind Wege 4–10 Min lang, Innenraum-Wechsel Zeitplan-Sprünge (`travel 0`); unsichtbare Phasen („im Haus", Totenwache, Krankenbesuch) sind `visible false`. Der Weg des Pfarrers am Weihetag nutzt Friedhofs-Wegpunkte, die W-Welt anlegt (§4.6 N1).
    - Regionen: Friedhofs-`bounds` im Fixture sind Näherungen (x −22…22, z −20…23); W-Welt übernimmt die `camera_bounds` des Layouts.
    - Prompts/Texte der Stubs (`[E] Kühlfach öffnen`, `[E] Sammlung ansehen`, `[E] %s betreten`, `Kein Bündel. Quast will ein Glas.`) sind W0-Entwürfe – die Besitzer formulieren.
    - Item-Beschreibungen, Rezept-Namen und Ortsnamen der Fixtures sind W0-Entwürfe (P7/P6/W-Welt formulieren).
13. **Lead-Anpassungen an fremden Tests (mechanisch, nur Versionsnummer / Feldzahl / Listenlänge):** `test_save_migration.gd` (v6, „neuer" = `CURRENT + 1`, Neuspeichern = `FORMAT_VERSION`), `test_phase3/4/5/6_scaffold.gd` (v6; Phase 6: `migrate(state, 6)` = aktuell, „neuer" = `CURRENT + 1`), `test_saves_v4_load.gd` und `test_save_fuzzer.gd` (`FORMAT_VERSION 6`), `test_phase5_save_upgrade.gd` (Neuspeichern = `FORMAT_VERSION`), `test_corpse.gd` (38 Record-Felder).
14. **Testzahl:** vor W0 2 017, nach W0 **2 051** (+ `test_phase7_scaffold.gd` 25, `test_saves_v5_load.gd` 9).
