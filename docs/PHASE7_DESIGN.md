# Phase 7 – Dorf – Vertrag v1

Status: **v1 – Entwurf zur Benutzerfreigabe (Vertragsfragen §14 offen), danach verbindlich für die Umsetzung** · Verantwortlich: Agent 01 (Lead), Agent 02 (Game Design), Agent 03 (World Design), Agent 05 (Blender/Gebäude), Agent 06 (Character Art), Agent 08 (Godot Core), Agent 11 (Corpse System), Agent 12 (NPC/AI), Agent 13 (Quest/Story), Agent 14 (Crafting/Economy)
Baut auf `docs/PHASE6_DESIGN.md` (Vertrag v1, freigegeben 03.10.2026), `docs/PHASE5_DESIGN.md`, `docs/PHASE4_DESIGN.md`, `docs/PHASE3_DESIGN.md` und `docs/VERTICAL_SLICE_DESIGN.md` auf. Was dieses Dokument nicht ändert, gilt dort unverändert weiter. Referenz-Build: **705bd5a** (Gate G6 freigegeben, 2 017 Tests).
Gameplay-Werte sind **Vorschläge**; der Benutzer prüft sie beim Gate G7. ART STYLE LOCK „Gemaltes Diorama" ist aktiv: Phase 7 ändert den Stil nicht. Maler-Shader (`painted.gdshader`, `painted_common.gdshaderinc`, `painted_foliage.gdshader`) und die Atmosphären-Presets bleiben unverändert; das Dorf benutzt **dieselbe** Sonne, dieselbe `WorldEnvironment` und dieselben Presets wie der Friedhof. Die freigegebenen Abschnitte I–IV, Werkhof, Kirchhof und alle Phase-6-Gebäude bleiben bitgleich, **außer** den in §4.6 vollständig aufgezählten Eingriffen am Friedhof (Wegstein am Kutschweg, Lindenacker südlich der Ostwiese mit Pforte im Ostwiesen-Südzaun, zwei bzw. drei versetzte Waldbäume, Präparierpult-Platz in der Gruft).

**Benutzerentscheidungen (verbindlich, 03.10.2026)**
- **Inhalt, alle vier Teile:**
  1. **Begehbares Dorf Hollerbrück** am Kutschweg, erreichbar über den Weg vom Friedhofstor: Anger mit Brunnen, Häuser, Dorfeingang. Die Anbindung legt dieser Vertrag fest und begründet sie (§3.4, §4.1).
  2. **Dorfbewohner und Händler** (Wirtin, Schmied, Krämerin, Pfarrer, Schultheiß, Wundarzt/Anatom und weitere), jeder mit Tagesablauf, Laden (Kaufen/Verkaufen) und Dialog, auf dem bestehenden `Npc`-System. Der Pfarrer zeigt sich jetzt im Dorf; Tiefe und eigene Riten bekommt er in Phase 8.
  3. **Wundarzt/Anatom mit Organ-System** (Benutzerwunsch vom 03.10.2026, `docs/ROADMAP.md`): **angedeutet** (Tuch über der Leiche, Abblende, Organe nur als verschlossene Gläser oder Bündel im Inventar, **kein Blut, keine offenen Wunden**), am **Gruft-Tisch** als neue Kategorie mit derselben zweistufigen Bestätigung wie die Verwertung aus Phase 4. Zwecke: (a) Präparate an den Anatomen verkaufen (Münzen; kostet Pietät und Ruf; Geister „beraubt"), (b) Forschung (die wahre Todesursache → Merkbuch), (c) Handwerk an einer neuen Station, (d) Haken für die Auferstehung (Phase 13, nur Daten).
  4. **Aufträge und Beziehungen:** kleine Aufträge der Dorfbewohner (liefern, würdig bestatten, einen Stein setzen) und **ein Beziehungswert je Person**. Vorstufe für Phase 8 (NPCs) und Phase 9 (Quests): erweiterbar, aber klein.
- **Umfang: groß.** 12–14 Spieltage auf dem Phase-6-Endstand, mit Kapitelziel (§1.5), in erreichbaren Wellen (W1 mit 7 Paketen, §12).
- **Einbindung:** Das Dorf wird Quelle für neue Tote (über neuen Grund, §2.9) und für Einnahmen und Ausgaben. Die Dorfbewohner reagieren auf Ruf-Stufe und Pietät. Osric wohnt im Dorf, Ilse bleibt die Nachtgestalt an der Westmauer und spricht über das Dorf. Das Geheimnis geht ein Stück weiter: Hinweise darauf, **wer die Sterbenden zeichnet**, ohne Auflösung. Der nächste Erzählschritt wird benannt (§1.6).

**Regeln für alle Agents** (wie Phase 3–6)
- Klassen, Signaturen, Dateipfade, Signale und Datenformate hier sind **fest**. Änderungen nur über den Lead.
- Der Lead legt in **Welle 0** alle Datenklassen (✦) vollständig und alle Logikklassen als **Stubs mit exakten Signaturen** an. Die Besitzer füllen die Körper und benennen nichts um.
- Nach jedem neuen Worktree und nach jedem Merge: `godot --headless --path . --import`.
- Jede Datei hat genau einen Besitzer (§3.2). Fremde Dateien nicht ändern; Bedarf an den Lead melden.
- Alle neuen Assets tragen `ph_` und kommen in die Placeholder-Liste (`docs/QUALITY_GATE_STATUS.md`).
- Keine Mechaniken, Namen oder Texte anderer Spiele übernehmen. Ausdrücklich **nicht**: Fleisch, Blut, Fett, Haut oder Gehirn als Ressource; Schädel- oder Knochenpunkte (rot/weiß oder sonst farbig); Körperteil-Wertungen mit Sternen; Organe als Zutat für Salben, Speisen oder Tränke; Leichen-Qualitätspunkte, die man „verbessern" kann; Freundschafts-Herzchen; Geschenk-Kalender; Hochzeiten; Tagesquest-Ketten mit Sofortbelohnung; Händler-Reputation als eigene Währung.
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
  → Leiche → Gruft-Tisch: Untersuchen · Herrichten · Verwerten (Phase 4) · NEU „Präparate" (Herz, Lunge, Magen)
       └ Tuch, Abblende, 20 Min → Glas (Glas + Branntwein) oder Bündel (Leinen, verdirbt) mit Namen auf dem Etikett
       └ Wundarzt Quast: VERKAUFEN (Münzen) · UNTERSUCHEN LASSEN (Befund, Merkbuch) · PRÄPARIERPULT: Schaupräparat
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
| Präparat nehmen (Herz / Lunge / Magen) am Gruft-Tisch | **20** je Präparat | `anatomy_case`, Glas (1 `prep_jar` + 1 `spirits`) oder Bündel (1 `linen`) | nein |
| Bündel einlegen (Präparierpult) | 5 | Bündel, 1 `prep_jar`, 1 `spirits` | nein |
| Schaupräparat herrichten (Präparierpult) | 40 | Präparat im Glas, 1 `beeswax`, 1 `ink` | nein |
| Salbe / Tinktur (Präparierpult) | 20 / 30 | Rezept §2.7 | nein |
| Präparat untersuchen lassen (Wundarztstube) | 30 | Präparat, Quast anwesend | nein |
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
| 42 (B3) | Rest roden, Pforte. **10:00 Pfarrer Lenz weiht den Lindenacker** (er kommt den Hügel herauf). Wundarzt Quast (Wundarztstube): Vorstellung, Präparierbesteck angeboten (annehmen oder ablehnen). | 25 → 27 | „Der Pfarrer kommt um zehn" → „Der Wundarzt will dich sprechen" |
| 43 (B4) | Erste Leiche seit Tagen → Gruft → Lindenacker `l_01`. Aufträge Rosine (Holunderbeeren) und Esch (Holzkohle) abgeben. | 31 → 40 | „Bring die Leiche in die Gruft" |
| 44 (B5) | Leiche 2. **Präparierpult** aufstellen (12). Fiebertinktur für Rosines Sohn. | 44 → 40 | „Gruft: Präparierpult aufstellen" |
| 45 (B6) | Leiche 3 mit Aussegnung (`o_lenz_service`). Stein für Dorothee Mahn (`o_mangold_stone`) an der Steinmetzbank. | 44 → 55 | „Ein Stein für Dorothee Mahn" |
| 46 (B7) | Leiche 4. Ilse (nachts): „Wer besucht im Dorf die Kranken?" → Hinweis *Drei Besucher*. | 59 → 66 | „Merkbuch: Wer besucht die Sterbenden?" |
| 47 (B8) | Leiche 5. Pfarrer **Vertraut** → Sterbebuch → Hinweis *Das Zeichen im Sterbebuch*. Freiwillig: Kapelle 3 (40). | 70 → 41 | – |
| 48 (B9) | **Trauerflor an Wiebke Hagedorns Kate.** Osric bringt sie (Geschichts-Leiche D1, gezeichnet). Totenhemd, Aussegnung, Lindenacker, Stein mit Mohn → `o_hagedorn_place`. | 45 → 63 | „Wiebke Hagedorns letzter Wunsch" |
| 49 (B10) | Leiche 7. Liesel **Vertraut** → Hinweis *Was die Seelfrau sah*. | 67 → 76 | „Merkbuch: Hinweise passen zusammen" |
| 50 (B11) | Leiche 8 (Lindenacker voll). Erkenntnis **„Vorher eingetragen"**. Stein für Wendel Gratz (`o_esch_stone`). | 80 → 88 | „Drei Bewohner vertraut: 2/3" |
| 51 (B12) | Dritter Bewohner **Vertraut**, sechster Auftrag → **Kapitel „Ein Name im Dorf"**. Freiwillig: Gruft 3 (35). | 92 → 61 | „Ein Name im Dorf: 4/4" |
| 52 (B13) | Freies Spiel. Keine freie Stelle → keine Lieferung. Gemeindetafel, Tinkturen, Runden. | 65 → 63 | „Die Gemeindetafel hat neue Bitten" |

**B) Neues Spiel:** `roof_and_earth` fällt je nach Spielweise an Tag 29–42 (G6), der Bogen läuft danach wie A. Richtwert Kapitelende „Ein Name im Dorf" ≈ Tag 41–55. Die Kapitel sind voneinander unabhängig: Phase 7 sperrt nichts aus Phase 4–6.

### 1.5 Phasenziel – Kapitel „Ein Name im Dorf" (`name_in_village`)
Erfüllt, sobald **alle** gelten (geprüft von `Village.check_goal` bei `order_completed`, `relationship_changed`, `insight_unlocked` und nach der Weihe):
1. Der **Lindenacker ist geweiht** (`linden_consecrated`).
2. Mindestens **6 Aufträge erledigt**, von mindestens **4 verschiedenen** Auftraggebern (Gemeindetafel zählt als Auftraggeber „Gemeinde").
3. Mindestens **3 Dorfbewohner** stehen auf **„Vertraut"** oder höher (Beziehung ≥ 40, §2.4).
4. Die Erkenntnis **„Vorher eingetragen"** (`i_deathbook`) ist verknüpft.

Dann: Flag `name_in_village_complete`, `chapter_completed(&"name_in_village")`, Abschluss-Panel Variante `name_in_village`. Es zeigt: Tage seit `village_open`, Wege ins Dorf, Aufträge n (nach Auftraggeber), Beziehungen aller acht als Wort, Ruf-Stufe, Bestattungen im Lindenacker, Präparate genommen / verkauft / untersucht / zurückgelegt, Münzen im Dorf eingenommen und ausgegeben (nach Zweck), Erkenntnisse der Phase. Schlusszeile je nach Pietät-Stufe (5 Varianten, P6), Standard: „Unten im Dorf kennen sie jetzt deinen Namen. Oben auf dem Hügel kennen sie ihn schon länger." Danach läuft das Spiel frei weiter. **Gate-Ziel:** Alle Bot-Strategien erreichen das Kapitel, auch der verwertende Weg und ein Spieler mit niedrigem Ruf; keine Bedingung verlangt Präparate, keine verbietet sie.

### 1.6 Das Geheimnis – Phase-7-Ausschnitt „Wer besucht die Sterbenden?"
**Leitplanke (Autorenwissen, Phase 18 entscheidet endgültig):** Der Gesamtbogen aus Phase 4 §1.4 bleibt. Lorenz lebt unter dem Birkenhang. Er hatte Ilse gefragt, „wer im Dorf die Kranken besucht" (Phase 4 §2.6). In Phase 7 nimmt der Spieler diese Frage auf. Wer zeichnet, wird **nicht** aufgelöst. Drei Menschen haben Zugang zu den Sterbenden, und alle drei sind hier: der **Pfarrer** (Versehgang), der **Wundarzt** (Krankenbesuch) und die **Seelfrau** (Totenwache). Ausgerechnet die Seelfrau, Liesel Dorn, war Lorenz' Augen im Dorf.

**Was der Spieler herausfinden kann:**
1. *Drei Besucher* (`c_v_three_visitors`, Ilse, nachts): „Ich hab ihm drei genannt: den Pfarrer, den Wundarzt und die Seelfrau. Er hat einen Namen unterstrichen. Welchen, hat er mir nicht gezeigt."
2. *Das Zeichen im Sterbebuch* (`c_v_deathbook`, Pfarrer bei „Vertraut" **oder** die Abschrift in der Amtsstube bei Fenner „Vertraut" oder nach einer Spende): Am Rand des Sterbebuchs steht neben fünf Namen ein kleiner Dreistrich. Die Tinte ist älter als der Eintrag des Todestags. Jemand hat die Namen vorher eingetragen.
3. *Was die Seelfrau sah* (`c_v_washing`, Liesel bei „Vertraut" **oder** wenn man ihr von Kaspar erzählt, nur mit Erkenntnis *Nicht Lorenz*): Sie hat das Zeichen seit dem Winter, als die Fähre kenterte, an den Toten gesehen und es Lorenz gemeldet, jedes Mal. Seit er fort ist, meldet sie es niemandem mehr. Sie schreibt die Namen in ihr Gesangbuch.
4. *Drei Wochen alt* (`c_v_hagedorn`, Fund an D1 Wiebke Hagedorn, Schritt Wunden, Mindestfrische 0,3): Ihr Zeichen ist frisch verheilt, etwa drei Wochen alt. In ihrer Schürze steckt ein Zettel: „Für den Totengräber. Linde, Mohn, Totenhemd. Und schau nach, wer mich besucht hat. – W. H."

**Erkenntnis (Pflicht fürs Kapitel):** `i_deathbook` „Vorher eingetragen" (Frage: „Wer schreibt die Namen auf?") = `c_v_deathbook` + `c_v_washing` + `c_v_three_visitors`. Text: „Im Sterbebuch steht das Zeichen neben Namen, deren Tod erst Wochen später eingetragen wurde. Liesel hat es an ihren Leibern gesehen, Lorenz hat nach denen gefragt, die die Kranken besuchen. Wer zeichnet, kommt ins Haus, solange sie noch leben, und schreibt sie vorher auf. Drei kommen in Frage. Eine davon hat Lorenz geholfen." Flag `insight_deathbook`.
**Optionale Erkenntnis (nur über die Anatomie):** `i_burn_it` „Verbrennt es" (Frage: „Was wollte der Zettel bei Quast?") = `c_v_still_heart` (Quast untersucht ein **Herz** eines gezeichneten Toten, §2.6) + `c_warning_letter` (Phase 4). Text: „Zweimal hat Quast ein gesundes, stilles Herz eines Gezeichneten eingelegt. Beide Male lag am nächsten Morgen ein Zettel vor seiner Tür, in derselben schrägen Hand wie die Warnbriefe: ‚Verbrennt es.' Lorenz will nicht, dass sie aufbewahrt werden." Flag `insight_burn_it`. Wer nie ein Organ nimmt, verpasst nur diese eine Zeile; die Geschichte bleibt lösbar.
- `c_v_hagedorn` ist Hinweis und Stimmung, kein Teil einer Pflicht-Erkenntnis (sie wäre sonst an eine Liefertagsfolge gebunden).
- **Belohnung wie Phase 4:** Text, Flag, Zeile im Abschluss-Panel, keine Münzen.

**Nächster Erzählschritt (Phase 8, benannt): „Der unterstrichene Name".** Phase 8 gibt den drei Besuchern nächtliche Wege (Versehgang, Krankenbesuch, Totenwache) mit eigenen Zeitplänen. Der Spieler kann ihnen folgen und findet in Lorenz' zweiter Kladde (im Pfarrarchiv) die Seite mit den drei Namen, einer davon unterstrichen. Phase 8 zeigt, **wen** Lorenz verdächtigte, nicht, ob er recht hatte. Die Auflösung bleibt Phase 13–18.

---
