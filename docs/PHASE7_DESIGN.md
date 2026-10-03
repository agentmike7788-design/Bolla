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

- **Startwert** beim ersten Gespräch: Spalte „Start" + `RelationshipConfig.rep_start_bonus` nach Ruf-Stufe [−10, −5, 0, +5, +10] (Verrufen … Gerühmt). Liesel und Pfarrer zusätzlich + `piety_start_bonus` [−5, 0, 0, +3, +5] (Hartherzig … Andächtig). *Begründung:* Das Dorf kennt den Totengräber vorher nur vom Hörensagen. Der Ruf ist genau dieses Hörensagen; die Pietät spüren nur die, die selbst mit Toten umgehen.
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
- *Nachrechnung:* Von Start 20 bis „Vertraut" (40) braucht es 20 Punkte: zwei erledigte Aufträge (≈ 16) und vier Gesprächstage, oder ein Auftrag, zwei Geschenke und vier Tage. Bei einem Besuch am Tag erreicht man drei Personen auf „Vertraut" um B9–B11 (Bogen A). Liesel (Start 10) ist am schwersten, Fenner (30) am leichtesten.

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

**Aufträge (Leitdaten, Texte P6/P3 dürfen glätten)**
| id | Auftraggeber | Art | Freigabe | Inhalt | Frist | Lohn: Münzen · Beziehung · Ruf |
|---|---|---|---|---|---|---|
| `o_fenner_linden` | Fenner | section | erstes Gespräch | „Der Lindenacker": Pforte, Stümpfe, Brombeeren und Steine räumen (§2.9); setzt `linden_granted` bei Annahme | – | 0 · +8 · +2 |
| `o_fenner_well` | Fenner | deliver → Esch | erstes Gespräch | 4 `workstone` für die neue Brunnenfassung, beim Schmied abgeben | 4 | 6 · +6 (+4 Esch) · +1 |
| `o_fenner_bridge` | Fenner | donate | `o_fenner_well` erledigt | „Die Holderbrücke": 20 Münzen und 6 `wood` für neue Bohlen | 6 | 0 · +10 · +3 |
| `o_rosine_berries` | Rosine | deliver | erstes Gespräch | 8 `elderberries` für den Holunderwein | 5 | 6 · +8 · 0 |
| `o_rosine_tincture` | Rosine | deliver | `o_rosine_berries` erledigt | 2 `fever_tincture` – „Jakob fiebert, und der Quast nimmt zu viel." | 4 | 8 · +10 · 0 |
| `o_esch_charcoal` | Esch | deliver | erstes Gespräch | 6 `charcoal` | 5 | 7 · +8 · 0 |
| `o_esch_stone` | Esch | stone | Esch „Bekannt", `o_esch_charcoal` erledigt | „Ein Stein für den Meister": Wendel Gratz (`old_01`), sein Lehrmeister; Bogenstein mit Fackel | 6 | 10 · +10 · +1 |
| `o_mangold_stone` | Theres | stone | Theres „Bekannt" | „Ein Stein für die Mutter": Dorothee Mahn (`old_08`); Stele mit Mohn und Inschrift | 6 | 12 · +10 · +1 |
| `o_lenz_service` | Lenz | bury | erstes Gespräch nach der Weihe | die nächste Lieferung nach Annahme: eingekleidet und **ausgesegnet** in der Kapelle (≥ Stufe 2, mit Trauergästen) | 3 | 6 · +8 · +1 |
| `o_lenz_poor` | Lenz | donate | Lenz „Vertraut" | „Armenspeisung": 12 Münzen und 4 `honey_cake` | 5 | 0 · +8 · +2 |
| `o_quast_tincture` | Quast | deliver | erstes Gespräch | 2 `fever_tincture` | 5 | 10 · +8 · 0 |
| `o_quast_specimen` | Quast | deliver | `anatomy_known` | „Für das Kabinett": 1 Herzpräparat im Glas, Klarheit ≥ 0,6 (§2.6); die Folgen trug schon das Nehmen | 6 | 12 · +10 · 0 |
| `o_liesel_gowns` | Liesel | deliver | Liesel „Bekannt" | 2 `burial_gown` – „für die, die nicht zu dir hinaufkommen" | 6 | 8 · +8 · 0 |
| `o_hagedorn_place` | Hagedorn (nach ihrem Tod: Liesel) | bury | erstes Gespräch mit ihr, sonst bei ihrer Ankunft | D1 Wiebke Hagedorn (§2.9): Lindenacker, Totenhemd, Stein mit Mohn, **unverwertet** | 3 Tage ab Ankunft | 10 · +8 Liesel · +2; gescheitert: Liesel −10, Lenz −5 |
| `ob_wood` | Gemeinde (Tafel) | deliver → Fenner | `village_open` | 10 `wood` „für den Gemeindezaun" | 1 | 5 · +3 Fenner · 0 |
| `ob_stone` | Gemeinde | deliver → Fenner | `village_open` | 8 `stone` „für den Weg zur Kirche" | 1 | 5 · +3 Fenner · 0 |
| `ob_herbs` | Gemeinde | deliver → Quast | `village_open` | 4 `herb_bundle` „für die Armen im Winter" | 1 | 8 · +3 Quast · 0 |
| `ob_yarn` | Gemeinde | deliver → Liesel | `village_open` | 6 `yarn` | 1 | 5 · +3 Liesel · 0 |
| `ob_gown` | Gemeinde | bury | `linden_consecrated` | die nächste Lieferung im Totenhemd | 2 | 4 · 0 · +1 |
| `ob_tend` | Gemeinde | tend | `linden_consecrated` | alle belegten Gräber im Lindenacker an 2 Morgen in Folge ohne Pflegeabzug | 4 | 5 · 0 · +1 |
- Tafel-Aufträge: Frist 1 = „bis morgen früh" (angenommen am Tag der Ausschreibung, abzugeben bis 06:00 des Folgetags) – außer `ob_gown`/`ob_tend` mit eigener Frist.
- **Kapitel** zählt jeden erledigten Auftrag (§1.5). Auftraggeber für „4 verschiedene": Fenner, Rosine, Esch, Theres, Lenz, Quast, Liesel, Hagedorn, Gemeinde.
- *Begründung Lohn:* Ein Liefer-Auftrag ersetzt einen Laden-Verkauf mit Aufschlag (8 Holunderbeeren: bei Rosine 8–16 Münzen Ankauf, als Auftrag 6 + Beziehung +8). Aufträge lohnen also vor allem über die Beziehung. Steine und Bestattungen bringen mehr, weil sie Stunden kosten. Die zwei Spenden-Aufträge (`donate`) sind die Münzsenke des Dorfes: sie kosten 32 Münzen und bringen Ruf und Beziehung, nie Münzen (§2.10).

### 2.6 Anatomie – Präparate am Gruft-Tisch (`data/config/anatomy_config.tres` – `AnatomyConfig`, `data/anatomy/findings/<id>.tres` – `SpecimenFindingData`)
**Eigene Identität: das Etikett.** Jedes Präparat trägt den Namen des Toten. Es ist kein Rohstoff und hat keine Punkte, sondern ein Einzelstück mit Herkunft: „Herz – Hedwig Lamprecht, 58 – Klarheit gut". Man kann es verkaufen, untersuchen lassen, als Schaupräparat herrichten **oder dem Toten zurückgeben**. Darin liegt der Unterschied zu jedem Organhandel: Was hier genommen wird, bleibt jemandes, und der Weg zurück ins Grab steht immer offen, solange das Glas nicht verkauft ist.

**Drei Präparate** (`AnatomyConfig.organs`; nur diese drei, je Leiche je eines):
| organ | Etikett | Min | Grundpreis bei Quast | Qualität | Ruf | Pietät | Geist | zeigt in der Untersuchung (§ Befunde) | Auferstehungs-Haken (`res_tag`, nur Daten) |
|---|---|---|---|---|---|---|---|---|---|
| `heart` | Herz | 20 | 8 | −2 | −3 | −8 | −5 (beraubt) | ein „stilles Herz" bei Gezeichneten | `&"will"` |
| `lung` | Lunge | 20 | 5 | −2 | −3 | −8 | −5 | Wasser oder kein Wasser (Ertrunkene) | `&"breath"` |
| `stomach` | Magen | 20 | 6 | −2 | −3 | −8 | −5 | Gift (Arsenik) | `&"hunger"` |

**Nehmen (Registerkarte „Präparate" am Gruft-Tisch, §7)**
- Sichtbar erst ab Flag `anatomy_known` (Quast gibt das **Präparierbesteck** `anatomy_case`, §2.12), nur am Tisch mit `room &"crypt"`. Vorher gibt es keine Karte.
- Voraussetzungen: Leiche nicht eingekleidet (wie Haar/Zähne: „Nach dem Einkleiden nicht mehr zugänglich."), dieses Präparat noch nicht genommen, Frische ≥ **0,3** („Zu spät. Daran lässt sich nichts mehr zeigen."), Werkzeug `anatomy_case` („Werkzeug fehlt – Quast hat es."), Behältnis: **Glas** (1 `prep_jar` + 1 `spirits`) oder **Bündel** (1 `linen`) nach Wahl in der Zeile, Platz für ein Einzelstück.
- **Zweistufige Bestätigung** wie die Verwertung aus Phase 4 (`CorpseExamTabs.press_harvest`, `confirm_seconds 3`): Der erste Druck schärft die Zeile („Wirklich? Noch einmal drücken."), der zweite innerhalb von 3 s startet.
- **Darstellung (angedeutet):** Beim Start legt sich das **Tuch** über die Leiche (Modellwechsel auf `ph_prop_corpse_shrouded`, die bestehende Tuch-Variante), die Figur beugt sich über den Tisch (`interact`), der Bildschirm wird über 0,6 s zu einem **dunklen Schleier** (85 %, `screen_veil_changed(true)`), nur der Aktionsbalken und eine Zeile bleiben lesbar: „Du ziehst das Tuch über sie und arbeitest, ohne hinzusehen." Am Ende hebt sich der Schleier, das Tuch bleibt **nicht** liegen (vorheriges Modell), und die Zeile: „Ein Glas mehr. Auf dem Etikett steht ihr Name." bzw. „Ein Bündel in Leinen. Es hält nicht lange." Kein Ton (Agent 17 inaktiv), kein Blut, keine Wunde, keine sichtbare Veränderung am Körper danach.
- **Wirkung sofort:** Item ins Inventar (Einzelstück, §3.4), `record.harvested` + Organ (gleiche Liste wie Haar/Zähne, `CorpseRecord.HARVEST_KINDS` angehängt), Ruf `organ_taken` −3, Pietät `organ_taken` −8, `stats.specimens_taken` +1, Flag `piety_used_day`. Qualität −2 je Präparat erscheint beim Grabzeichen (`EconomyConfig.harvest_malus`). Kein „Voll hergerichtet"-Bonus mehr für diese Leiche (Phase-5-Regel `full_prep_requires_unharvested` greift von selbst).
- **Klarheit** = Frische der Leiche am Ende der 20 Minuten (0,3…1,0), wird im Etikett als Wort gezeigt: ≥ 0,8 „sehr gut" · ≥ 0,6 „gut" · ≥ 0,45 „trüb" · darunter „kaum lesbar".

**Glas oder Bündel – Verderben (die Frage „verderben Organe ohne Glas oder Kälte?" – Entscheidung: ja, nur das Bündel)**
- **Glas** (`specimen_jar`): verschlossen, in Branntwein. Die Klarheit bleibt für immer.
- **Bündel** (`specimen_bundle`, in Leinen): Klarheit sinkt linear auf 0 in **600 Min** (10 h); liegt es im **Kühlfach des Präparierpults** (§2.7), läuft die Zeit × **0,25** (≈ 40 h). Bei 0 ist es **verdorben**: nicht verkäuflich, nicht untersuchbar, nicht mehr einlegbar – es bleibt nur das Zurücklegen ins Grab. Einmal je Bündel die Notiz „Das Bündel von <Name> ist verdorben."
- **Einlegen** am Präparierpult (5 Min, 1 `prep_jar` + 1 `spirits`): Bündel → Glas mit der Klarheit dieses Augenblicks.
- Die Rechnung nutzt Fenster wie die Kühle der Gruft (`SpecimenRecord.cold_windows`, Faktor‰), rein aus der Minutendifferenz, Raster 1e-6.
- *Begründung:* Das Glas kostet 5 Münzen Ware (Glas 2 + Branntwein 3) und macht das Nehmen teuer und bewusst. Das Bündel ist der billige, eilige Weg, und es bestraft Eile mit Verfall, genau wie die Leichen selbst. Die Kälte der Gruft hilft auch hier, aber nur am Pult.

**Verkaufen an Quast** (Wundarztstube, Panel `&"anatomist"`, Münzen sofort)
- Preis je Stück: `round(Grundpreis × (0,5 + 0,5 × Klarheit))`; Bündel × 0,5; Schaupräparat × 1,5 + 2; Quast „Befreundet" +1. Beispiele: Herz im Glas bei 0,9 → 8 · Lunge bei 0,6 → 4 · Herz-Bündel nach 3 h (0,63) → 3 · Herz-Schaupräparat → 14.
- Folgen des Verkaufs (nur Beziehung, §2.4): Pfarrer −4, Liesel −3, Hagedorn −2, Quast +2. Ruf und Pietät trugen schon das Nehmen. `stats.specimens_sold` +1. Das Präparat ist danach für immer fort (`state sold`); der Totenzettel vermerkt „an Quast verkauft".
- **Ilse nimmt keine Präparate** („Gläser nehme ich nicht. Was in Branntwein liegt, gehört schon dem Wundarzt."). Haar und Zähne bleiben bei ihr.

**Untersuchen lassen (Forschung)**
- In der Wundarztstube: „Präparat untersuchen lassen (30 Min)": Quast sieht es sich an, die Uhr läuft 30 Min (der Spieler wartet in der Stube). Braucht Klarheit ≥ **0,5** („Zu trüb. Da sehe ich nur Branntwein."). Kein Schaupräparat („Unter Wachs sehe ich nichts mehr.").
- Ergebnis: der **Befund** (`SpecimenFindingData`, Vorrang: Geschichte → verborgene Ursache → gezeichnet → Ursache → Standard) als Zeile im Totenzettel und als Benachrichtigung; wenn der Befund einen Hinweis trägt, kommt er ins Merkbuch (einmal). Das Präparat bleibt bei Quast („für die Sammlung", `state researched`), kein Geld, Quast +3.
- **Verborgene Ursachen** (✦ `CorpseTables.hidden_causes`, nur Zufallsleichen, deterministisch aus dem Seed): `fever` → `arsenic` mit 12 % · `drowned_millpond` → `dead_before_water` mit 15 %. Ohne Untersuchung bleibt die angezeigte Ursache die von Osric.

| Befund | Präparat · Bedingung | Text (P4 darf glätten) | Hinweis |
|---|---|---|---|
| `b_still_heart` | Herz · Leiche gezeichnet (`strange_wound`) | „Gesund. Keine Narbe, kein Fett, keine Schwäche. Es hat einfach aufgehört. Ich habe so ein Herz schon zweimal eingelegt." | `c_v_still_heart` |
| `b_arsenic` | Magen · verborgene Ursache `arsenic` oder Ursache `poisoned` | „Ein weißlicher Belag und ein Geruch nach Knoblauch. Arsenik. Das war kein Fieber." | `c_v_arsenic` (erstes Mal) |
| `b_dry_lungs` | Lunge · verborgene Ursache `dead_before_water` | „Trocken. Wer ertrinkt, atmet Wasser. Dieser hat nicht mehr geatmet, als er ins Wasser kam." | `c_v_dry_lungs` (erstes Mal) |
| `b_wet_lungs` | Lunge · Ursache `drowned_millpond` | „Schwer von Wasser. Er hat noch geatmet, als er unterging." | – |
| `b_fever_lungs` | Lunge · Ursache `fever` | „Fleckig wie bei allen, die das Sumpffieber holt." | – |
| `b_old_heart` | Herz · Ursache `old_age` | „Groß und müde. Es hat lange gearbeitet." | – |
| `b_empty_stomach` | Magen · sonst | „Leer. Die letzten Tage hat sie kaum gegessen." | – |
| `b_plain` | jedes · sonst | „Nichts, was an der Todesursache etwas ändert." | – |
- `c_v_arsenic` („Arsenik im Fieber") und `c_v_dry_lungs` („Trockene Lungen") bilden in Phase 7 **keine** Erkenntnis; sie stehen unter „Offen" mit der Randnotiz „Im Dorf stirbt man nicht immer an dem, was Osric sagt." (Haken für Phase 9).

**Zurücklegen ins Grab („Präparat beisetzen")**
- Am Grab des Toten (Zustand `FILLED` oder `MARKED`): „[E] Präparat beisetzen: Herz von Hedwig Lamprecht (10 Min)". Geht für Glas, Bündel (auch verdorben) und Schaupräparat, nicht nach Verkauf oder Untersuchung.
- Wirkung: `record.returned` + Organ → der Geist zählt dieses Organ nicht mehr als „beraubt" (Stimmung +5 zurück), Pietät `specimen_returned` **+3**, Pfarrer +1, Liesel +2, `stats.specimens_returned` +1. Die **Qualität bleibt** (der Stein steht schon, die Bezahlung ist geflossen) und der Ruf auch. Geisterzeile aus `by_returned` in der nächsten Nacht. Glas, Branntwein und Leinen sind verbraucht.
- *Begründung:* Phase 5 sagte: „Ein Stein gibt nicht zurück, was genommen wurde." Ein Präparat kann es. Das gibt dem Spieler, der aus Neugier oder Not genommen hat, einen würdigen Ausweg, der etwas kostet (Ware, Zeit, die entgangenen Münzen) und nicht alles heilt.

**Haken für Phase 13 (nur Daten, keine Logik):** `AnatomyConfig.organs[*].res_tag` und `res_weight` (Herz 3, Lunge 2, Magen 1); `Specimens.kept(organ) -> int` zählt gehaltene, nicht verdorbene Präparate. Keine Phase-7-Logik liest sie.

`AnatomyConfig` (Kurzform): `organs {heart, lung, stomach: {label, minutes 20, base_price 8/5/6, quality_event, reputation_event &"organ_taken", piety_event &"organ_taken", res_tag, res_weight}}`, `tool_item &"anatomy_case"`, `room_id &"crypt"`, `min_freshness 0.3`, `jar_inputs {prep_jar: 1, spirits: 1}`, `bundle_inputs {linen: 1}`, `bundle_minutes 600`, `pult_cold_factor 0.25`, `clarity_words [0.8, 0.6, 0.45]`, `research_minutes 30`, `research_min_clarity 0.5`, `bundle_price_factor 0.5`, `display_price_factor 1.5`, `display_price_bonus 2`, `friend_price_bonus 1`, `return_minutes 10`, `seal_minutes 5`, `veil_seconds 0.6`, `veil_alpha 0.85`, `known_flag &"anatomy_known"`.

### 2.7 Das Präparierpult in der Gruft (`data/stations/pult.tres` – `StationData`, Rezepte `data/recipes/*`)
**Entscheidung: eine Station im Gruft-Raum statt eines neuen Gebäudes.** *Begründung:* Die Gruft ist kalt, still und hat schon Tisch, Waschbecken und Räucherschale. Das Pult gehört dorthin, wo die Präparate entstehen. Es braucht keinen neuen Bauplatz in der vollen Außenwelt. Die Phase-5-Station (`StationData` + `Workbench`, `requires_built`) trägt es ohne neue Mechanik.
- **Aufstellen:** „[E] Präparierpult aufstellen" am Platz `pult` in der Gruft (§4.6 P1), sichtbar ab `village_open` und Gruft ≥ 1: **6 wood, 2 iron_fittings, 2 stone + 12 Münzen** („Glaswaren und Wachstuch von Quast", Zweck `&"build"`), 90 Min. Danach steht das Pult mit Kühlfach (Schieferlade).
- **Rezepte** am Pult (normales Werkstatt-Panel `&"crafting"`, Station `pult`):
  | Rezept | Zutaten | Min | Ergebnis | Wofür |
  |---|---|---|---|---|
  | `fever_tincture` Fiebertinktur | 2 `herbs`, 1 `elderberries`, 1 `spirits` | 30 | 1 | Quast kauft 6, Rosine und Quast wollen sie (Aufträge) |
  | `wound_salve` Wundsalbe | 1 `herb_bundle`, 1 `beeswax` | 20 | 2 | Theres kauft 4, Quast 5 |
  | `corpse_balm` Totensalbe | 2 `herbs`, 1 `beeswax` | 20 | 1 | wie Wacholder beim Räuchern (× 0,25, 18 h; `PrepConfig.balm_items` + `corpse_balm`), ohne Rauch – ein Glanz auf der Haut |
- **Pult-Panel** `&"pult"` (zweite Karte am Pult, nur mit Präparaten): „Bündel einlegen (5 Min)" · „Schaupräparat herrichten (40 Min)": Glas + 1 `beeswax` + 1 `ink` → `display_specimen` (Glas unter einer Glasglocke, Wachssiegel, beschriftet; verkaufbar × 1,5 + 2; zurücklegbar).
- **Kühlfach** `PultStore` (`extends Chest`, 8 Plätze, Panel `&"chest"`): nimmt alles auf, was die Truhe nimmt; Bündel darin verderben × 0,25 (§2.6).
- *Keine* Rezepte mit Präparaten als Zutat außer dem Schaupräparat. Salben und Tinkturen entstehen aus Kräutern, Wachs und Branntwein. *Begründung:* Organe als Arznei wären der grausige Volksglaube, den dieser Vertrag ausschließt (§ Regeln).

### 2.8 Neue Items
`ItemData` erhält **`unique: bool`** (✦, Standard false): Einzelstücke liegen je in einem eigenen Platz und tragen eine `uid` (§3.4).
| id | Name | Kategorie | Stapel | Herkunft | Zweck |
|---|---|---|---|---|---|
| `prep_jar` | Präparatglas | MATERIAL | 10 | Theres 2, Quast 2 | Präparat im Glas, Einlegen |
| `spirits` | Branntwein | MATERIAL | 10 | Rosine 3, Quast 3 | Glas, Fiebertinktur, Geschenk (Quast) |
| `beeswax` | Bienenwachs | MATERIAL | 10 | Theres 1 | Salben, Schaupräparat |
| `anatomy_case` | Präparierbesteck | TOOL | 1 | Quast, einmalig (§2.12) | Präparate nehmen |
| `specimen_jar` | Präparat im Glas | GOODS, **unique** | 1 | Gruft-Tisch | §2.6 |
| `specimen_bundle` | Präparat im Bündel | GOODS, **unique** | 1 | Gruft-Tisch | §2.6, verdirbt |
| `display_specimen` | Schaupräparat | GOODS, **unique** | 1 | Präparierpult | §2.6 |
| `fever_tincture` | Fiebertinktur | CRAFTED | 5 | Pult | Verkauf, Aufträge |
| `wound_salve` | Wundsalbe | CRAFTED | 10 | Pult | Verkauf |
| `corpse_balm` | Totensalbe | MATERIAL | 10 | Pult | Konservieren (wie Wacholder) |
| `honey_cake` | Honigkuchen | GOODS | 10 | Theres 1 | Geschenk, `o_lenz_poor` |
| `elder_wine` | Holunderwein | GOODS | 5 | Rosine 2 | Geschenk (Esch, Lenz) |
- Einzelstücke dürfen in Truhe, Schuppen (nicht über „Überschuss einlagern": `ShedConfig.excluded_items` + die drei) und Kühlfach liegen. Das Etikett (Name, Organ, Klarheit) zeigt der Tooltip aus `Specimens`.

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
| Aufträge (`neighbor7`: 10 Aufträge, davon 2 Spenden) | 6 + 6 + 8 + 7 + 12 + 6 + 10 + 10 + 0 + 0 | 65 |
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
- *Warum die Pflicht so klein ist:* Das Dorf verkauft keine Gebäude. Seine Senke sind Dinge mit sozialem Lohn (Runde, Spende, Geschenk: Beziehung und Ruf, nie Münzen) und die Ware, die das Handwerk braucht. Ein knapper Spieler kann das alles lassen und kommt trotzdem ans Kapitel; ein voller Beutel hat jetzt Orte, an denen er sinnvoll leer wird. Eine echte Preisdynamik bleibt Phase 10 (G5-Befund E5, GP-03).

**Andere Wege (Erwartung für W3)**
| Weg | Start | Einnahmen | Ausgaben | Ende (≈ 13 Tage) | Bemerkung |
|---|---|---|---|---|---|
| anatomisch (`anatomist7`, v5 reverent) | ≈ 20 | wie A, Bestattungen ≈ 8 × 10 (Qualität −6, Ruf fällt), dazu Präparate ≈ 8 × 3 × 6 = 144 | Gläser und Branntwein 8 × 3 × 5 = 120, Pult, Weihe | ≈ 60–100 | Das Glas macht das Nehmen teuer; der Gewinn je Leiche liegt bei ≈ 3–6 Münzen netto, Bündel bringen mehr und verderben. Pfarrer und Liesel bleiben „Fremd", Sterbebuch über die Amtsstube. Pietät → Hartherzig, Geister unruhig |
| forschend (`scholar7`, v5 mender) | ≈ 41 | wie A ohne Präparat-Verkauf | Herzen im Glas, alle untersucht | ≈ 60–90 | `i_burn_it`, `c_v_arsenic`/`c_v_dry_lungs` je nach Seed; 2 Präparate zurückgelegt |
| reuig (`penitent7`, v5 harvester) | ≈ 63 | wie A, Ruf niedriger | Spenden 10/Tag, Runden, Geschenke | ≈ 20–60 | Ruf steigt über die Armenkasse; keine Präparate |
| neues Spiel (`founder7`, v5 founder) | ≈ 40 | wie A | wie A | ≈ 40–90 | Kapitel ≤ Tag 50 |

### 2.11 Qualität, Ruf, Pietät, Geister, Statistik
- `EconomyConfig.harvest_malus` + `heart −2`, `lung −2`, `stomach −2`. `quality_max` bleibt **20**. Zurücklegen ändert die Qualität nicht.
- `ReputationConfig.event_points` + `organ_taken −3`, `donation 1`, `order_failed −1`. Erledigte Aufträge geben `OrderData.reward_rep` mit dem Grund „Auftrag: <Titel>".
- `PietyConfig.events` + `organ_taken −8`, `specimen_returned +3`. Die tägliche Erholung (Phase 4) bleibt; das Nehmen setzt `piety_used_day`.
- `GhostMood`: Der Beraubt-Zähler ist jetzt `harvested.size() − returned.size()` (✦ `GhostMood.robbed_count(record)`); `robbed_mood −5` je Art bleibt. Neuer Grund-Text-Pool `GhostLines.by_organ` (Vorrang vor `robbed`, wenn ein Organ fehlt): „In mir ist eine Stelle, die nicht mehr warm wird." · „Mein Name steht auf einem Etikett. Wer liest ihn?" · „Sie haben mich in der Stadt in ein Regal gestellt. Ich kann die Linde nicht sehen." `GhostLines.by_returned` (erste Nacht danach): „Es ist wieder da. Ich spüre es nicht, aber ich weiß es." · „Du hast zurückgebracht, was du genommen hast. Das tun nicht viele."
- `GameState.DEFAULT_STATS` + `village_trips`, `orders_done`, `orders_failed`, `gifts_given`, `rounds_bought`, `donations`, `specimens_taken`, `specimens_sold`, `specimens_researched`, `specimens_returned`, `coins_spent_village`, `coins_spent_donation`, `coins_spent_round`, `coins_spent_consecration`.
- `coins_spent`-Zwecke + `&"village"` (Läden), `&"donation"` (Armenkasse, Spenden-Aufträge), `&"round"`, `&"consecration"`. Das Pult läuft unter `&"build"` (Phase-5-Station).

### 2.12 Osric, Ilse und die Freischaltung der Anatomie
- **Osric** (`carter.tres` + neuer Dialog `carter_village`, P6): Friedhof: `p7_intro` (§1.2), danach Menüpunkt „Wie ist es unten im Dorf?" (wechselnd nach Beziehungen). Dorf (Remise, Gaststube): stellt am ersten Treffen vor („Das ist Rosine, der gehört der Holderkrug und das halbe Dorf, wenn man sie reden lässt."), spendiert das versprochene Bier (Notiz, keine Wirkung), erzählt vom Trauerflor, kommentiert Präparate einmal je Stufe („Der Quast fährt jetzt öfter mit mir in die Stadt. Seine Kisten klirren."). Keine Beziehung in Phase 7.
- **Quast und das Besteck:** Beim ersten Gespräch in der Wundarztstube (Knoten `v_surgeon_intro`): „Sie haben, was mir fehlt, Totengräber: Zeit mit den Toten, bevor die Erde sie nimmt. Die Stadt zahlt für Präparate. Ich zahle Ihnen davon, was recht ist." Wahl: **„Zeigen Sie mir, wie." → `anatomy_case` geschenkt, Flag `anatomy_known`** · „Nein. Die bleiben, wie sie sind." → Flag `anatomy_declined` (er fragt nach 3 Tagen noch einmal, danach nie wieder von sich aus; der Menüpunkt „Ich habe es mir überlegt." bleibt). Ohne Besteck gibt es keine Präparate-Karte. *Begründung:* Wie Ilses Werkzeug (Phase 4) ist die dunkle Möglichkeit ein Angebot, kein Zwang.
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
| `NpcLod` | `NpcLod` | `npc_lod` | – (nicht gespeichert) |

**Regionen** (§3.4, §4.1): `WorldRoot/Regions/Graveyard` (`RegionRoot`, region_id `graveyard`, verwaltet die bestehenden Außenknoten über `managed_paths`, verschiebt nichts) und `WorldRoot/Regions/Village` (Instanz von `src/world/village/village.tscn`, `RegionRoot`, region_id `village`, Ursprung **(0, 0, 400)**). In der Dorf-Szene: `Ground`, `Decor`, `Buildings`, `Entities` (8 `Npc` der Dorfbewohner + `npc_carter_v`, `HouseDoor` × 3, `ShopCounter` × 2, `VillageBoard`, `RegionPortal` `road_out`, `MourningRibbon` × 6), `Waypoints`, `Colliders`, `Lights`. **Friedhof:** `Entities/road_exit` (`RegionPortal`), `Entities/npc_priest` (`Npc`, Weihetag), Abschnitt `linden` mit Plots und Hindernissen, `Interiors/InnInterior|SurgeryInterior|OfficeInterior` (`InteriorRoom`, `region_id village`), im Gruft-Raum `pult` (`Workbench`, Station `pult`) + `PultStore` (saveable `pult_store` / **62**). Keine neuen Autoloads.

### 3.2 Module & Besitz (Phase 7)
| Modul | Besitzt (Pfade) |
|---|---|
| **Lead** (W0 + laufend) | `project.godot`, `src/core/*` (EventBus, Database), alle **Datenklassen ✦**, alle **Stubs** (bis zur Übergabe), `tests/run_tests.gd`, `tests/framework/*`, `tests/fixtures/*` (inkl. **`saves_v5/*`**, `phase7/*`), `tests/integration/test_saves_v5_load.gd`, `tests/unit/test_phase7_scaffold.gd`, `docs/*`, `CLAUDE.md` |
| **P1 Regionen, Portale & NPC-Last** | `src/world/regions/{region_root,region_portal,region_travel}.gd` (neu), `src/entities/house_door/*` (neu), `src/entities/region_portal/*` (neu, Szene), `src/world/interiors/{interior_room,room_exit}.gd` (nur `region_id` / `door_id`), `src/world/hut_interior/hut_portal.gd` (nur Durchreichen), `src/world/camera/camera_rig.gd` (`set_base_profile`), `src/entities/player/player.gd` (nur `region_id`, `set_region`, Speichern), `src/entities/npc/{npc,npc_pose}.gd` (`region_id`, `hide_flag`, LOD), `src/systems/npc/{schedule_resolver,npc_lod}.gd`, `data/config/npc_config.tres`, `data/config/regions/*`, `tests/unit/{test_regions,test_npc_lod,test_schedule_resolver,test_house_door}.gd`, `tests/integration/test_region_travel.gd` |
| **P2 Läden & Beziehungen** | `src/systems/village/{village_shops,shop_rules,relationships,relationship_rules}.gd`, `src/entities/shop_counter/*`, `data/shops/*`, `data/village/villagers/*`, `data/config/relationship_config.tres`, `tests/unit/{test_village_shops,test_relationships}.gd` |
| **P3 Aufträge & Dorf-Fortschritt** | `src/systems/village/{orders,order_rules,village}.gd`, `src/entities/village_board/*`, `src/entities/mourning_ribbon/*`, `data/orders/*`, `data/config/{orders_config,village_config}.tres`, `data/sections/linden.tres`, `data/clearables/*` (nur neue Einträge), `src/systems/expansion/expansion_manager.gd` (nur `unlock_flag`, `try_unlock`), `src/systems/graveyard/graveyard.gd` (nur `replace_old_marker` und die Aufrufe `Orders.note_grave_completed`/`note_stone_set`), `src/systems/stone/stonemasonry.gd` + `src/entities/grave/grave_plot.gd` (nur „Neuen Stein setzen" auf Ruhezeit-Gräbern mit Auftrag), `tests/unit/{test_orders,test_village,test_expansion}.gd` |
| **P4 Anatomie** | `src/systems/anatomy/{specimens,specimen_rules,specimen_record}.gd` (neu), `src/systems/corpse/{corpse_care,corpse_generator,corpse_record}.gd` (Organ-Karte, `hidden_cause`, `returned`), `src/entities/morgue_table/morgue_table.gd` (`request_organ`, Tuch, Schleier), `src/entities/corpse/corpse.gd` (nur `set_covered`), `src/entities/grave/grave_plot.gd` (nur „Präparat beisetzen"), `src/systems/inventory/inventory.gd` + `src/ui/panels/chest_transfer.gd` (nur Einzelstücke), `src/systems/ghosts/{ghost_mood,ghost_manager}.gd`, `data/config/{anatomy_config,economy_config,reputation_config,piety_config}.tres`, `data/anatomy/**`, `data/ghosts/ghost_lines.tres`, `data/corpses/corpse_tables.tres` (nur `hidden_causes`), `tests/unit/{test_specimens,test_inventory_unique,test_anatomy_harvest,test_ghosts,test_corpse_generator}.gd` |
| **P5 Assets** | `tools/blender/{asset_village_buildings,asset_village_props,asset_village_interiors,asset_villagers,asset_anatomy}.py` (neu), `tools/blender/asset_items.py`, `tools/blender/build_all.py`, `assets/models/**` (nur neue Phase-7-Dateien), `art_source/blender/**` (Phase 7), `tests/unit/test_assets_phase7.gd`, `docs/reviews/phase7_assets/*` |
| **P6 Dialog, Geschichte & Speichern** | `data/dialogue/{carter,trader}.tres`, `data/dialogue/v_*.tres` + `carter_village.tres` + `priest_linden.tres` (neu), `data/npc/*_schedule.tres` (neue + Osrics Dorf-Einträge), `src/systems/dialogue/{dialogue_conditions,dialogue_actions}.gd`, `src/systems/story/{story_director,story_corpse_data}.gd` (nur `after_flag`/`after_days`/`section`-Logik), `data/story/d1_hagedorn.tres`, `data/finds/f_d1_*.tres`, `data/journal/{clues,insights}/*` (Phase 7), `src/systems/save/{save_migration,save_file_io,save_manager}.gd`, `src/systems/game_state/game_state.gd` (Stats), `tests/unit/{test_dialogue,test_save,test_save_migration,test_story,test_journal,test_game_state}.gd`, `tests/integration/test_phase6_save_upgrade.gd` |
| **P7 Präparierpult & Handwerk** | `data/stations/pult.tres`, `data/recipes/{fever_tincture,wound_salve,corpse_balm}.tres`, `data/items/*` (Phase-7-Items), `src/entities/pult_store/*` (neu, `extends Chest`), `src/systems/workshop/workshop.gd` (nur Station im Innenraum, falls nötig), `data/config/{prep_config,shed_config}.tres` (`corpse_balm`, Ausschlüsse), `tests/unit/{test_pult,test_recipes_phase7}.gd` |
| **W-Welt** (W2) | `data/world/village_layout.json`, `data/world/interiors/{inn,surgery,office}_layout.json`, `data/world/interiors/crypt_layout.json` (nur Pult-Platz), `src/world/village/*` (neu: `village_build.gd`, `village_builder.gd`, `village.tscn`, `village_shots.gd`), `src/world/interiors/*` + `{inn,surgery,office}_interior.tscn`, `data/world/graveyard_layout.json` (Lindenacker, Wegstein, Bäume, Regionen §4.6), `src/world/graveyard/*` (neu `graveyard_build_phase7.gd`, `graveyard_shots_phase7.gd`, Gras/Maske neu gebacken), `tools/blender/asset_ground_village.py` (neu), `tests/integration/{test_village_world,test_graveyard_world,test_phase7_loop,test_interiors}.gd`, `docs/reviews/phase7_round1/*` |
| **W-UI** (W2) | `src/ui/**` (neu `panels/{shop_panel,anatomist_panel,orders_panel,gift_panel,pult_panel}.gd`, `hud/{region_label,veil,remark_bubbles}.gd`, `phase7_texts.gd`; Präparate-Karte in `corpse_exam_tabs.gd`/`corpse_exam_sections.gd`; Merkbuch-Seiten „Aufträge" und „Hollerbrück"), `assets/ui/**`, `tools/ui/*`, `src/debug/*` (neu `debug_commands_phase7.gd`; außer `asset_preview.gd`, `screenshot_capture.gd`), `tests/unit/{test_ui,test_objective,test_ui_phase7}.gd`, `tests/integration/test_ui_flow.gd` |
| **W3 QA** | `tests/integration/{phase3_bot,…,phase6_bot,phase7_bot,test_phase7_playthrough,test_phase7_qa,test_save_fuzzer}.gd`, `docs/reviews/phase7_wip/*` |
| **Eingefroren** | `src/world/art_prototype/*`, `src/entities/player/player_proto.*`, `data/art_prototype/*`, **Maler-Shader**, `data/atmosphere/*`, Hütte, Werkbank, Stationen, Pförtchen, Ostpforte, Kirchpforte, alle Phase-6-Gebäude und ihre Räume (außer dem Pult-Platz in der Gruft), Abschnitte I–IV, Werkhof, Kirchhof im Layout (außer §4.6) |

✦ **Datenklassen (W0, Lead):** `RegionConfig`, `NpcConfig`, `VillagerData`, `ShopData`, `RelationshipConfig`, `VillageConfig`, `OrderData`, `OrdersConfig`, `AnatomyConfig`, `SpecimenFindingData`. Erweiterungen: `ScheduleEntry` (+ `region`, `today_flag`), `ItemData` (+ `unique`), `SectionData` (+ `unlock_flag`), `StoryCorpseData` (+ `after_flag`, `after_days`, `section`, `requires_flag`, `due_flag`), `CorpseRecord` (+ `hidden_cause`, `returned`; `HARVEST_KINDS` + `heart`, `lung`, `stomach` angehängt), `CorpseTables` (+ `hidden_causes`), `EconomyConfig.harvest_malus` (+ 3), `ReputationConfig.event_points` (+ `organ_taken`, `donation`, `order_failed`), `PietyConfig.events` (+ `organ_taken`, `specimen_returned`), `GhostLines` (+ `by_organ`, `by_returned`), `PrepConfig.balm_items` (+ `corpse_balm`), `InteriorConfig` unverändert.
Bei nur fünf Agents übernimmt P2 zusätzlich P7 und P3 zusätzlich P6.

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
| `VillageBoard`, `MourningRibbon` | `src/entities/{village_board,mourning_ribbon}/*.gd` (+ `.tscn`) | Stub (P3) |
| `AnatomyConfig`, `SpecimenFindingData` | `src/systems/anatomy/{anatomy_config,specimen_finding_data}.gd` | ✦ |
| `SpecimenRecord` | `src/systems/anatomy/specimen_record.gd` | ✦ (reine Daten + `to_dict`/`from_dict`) |
| `SpecimenRules`, `Specimens` | `src/systems/anatomy/{specimen_rules,specimens}.gd` | Stub (P4) |
| `PultStore` | `src/entities/pult_store/pult_store.gd` (+ `.tscn`, `extends Chest`) | Stub (P7) |
| `ShopPanel`, `AnatomistPanel`, `OrdersPanel`, `GiftPanel`, `PultPanel` | `src/ui/panels/*.gd` | W-UI |

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
# Präparate (Specimens); state: &"taken" | &"sold" | &"researched" | &"returned" | &"sealed" | &"displayed" | &"spoiled"
signal specimen_changed(uid: String, state: StringName)
# Darstellung: dunkler Schleier während eines Präparats (MorgueTable)
signal screen_veil_changed(active: bool)
# Weihe (Village)
signal ground_consecrated(section_id: StringName)
```
Regel wie Phase 3–6: **Listener ändern keinen Spielzustand.** Wer ändert, ruft direkt auf: `ShopCounter`/Dialog → `VillageShops.buy/sell` → `Relationships.add` (nur Ankauf-Ereignisse, keine); `DialogueActions` → `Relationships.add/give_gift`, `Orders.accept/turn_in`, `Village.buy_round/donate/pay_consecration`; `Orders.complete` → `Relationships.add`, `Reputation.event`, `Village.check_goal`; `Graveyard.place_marker/set_designed_stone` → `Orders.note_grave_completed/note_stone_set` (P3); `ExpansionManager` → `Orders.note_section_progress`, `Village.check_goal`; `MorgueTable` → `CorpseCare.harvest_organ` → `Specimens.harvest`, `Piety.event`, `Reputation.event`; `AnatomistPanel` → `Specimens.sell/research` → `Relationships.add`, `JournalManager.add_clue`; `GravePlot` → `Specimens.return_to_grave` → `CorpseManager.notify_changed`, `Piety.event`; `Npc`-Zeitplan des Pfarrers endet → `Village.apply_minute` (Uhr) → `Village.consecrate` → `ExpansionManager.try_unlock`. `coins_spent` erhöht `stats.coins_spent` im Sender über `GameState.note_coins_spent`.

### 3.4 Logik-Klassen (Signaturen = Vertrag)

**Regionen, Portale & NPC-Last (P1)**
```gdscript
class_name RegionConfig extends Resource              # ✦ data/config/regions/<region_id>.tres
@export var region_id: StringName; @export var display_name: String = ""; @export var arrive_text: String = ""
@export var origin: Vector3 = Vector3.ZERO
@export var camera_distance: float = 22.0; @export var camera_zoom_min: float = 12.0; @export var camera_zoom_max: float = 24.0
@export var bounds_min: Vector2; @export var bounds_max: Vector2       # Fokusgrenzen, region-lokal
@export var travel_minutes: int = 30; @export var fade_seconds: float = 0.8
@export var managed_paths: PackedStringArray = []    # Graveyard: ["Decor", "Lights", "Grass"]; Village: ["."] (alles)
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
class_name MourningRibbon extends Node3D              # Trauerflor an Marker ribbon eines Hauses; sichtbar nach Village.mourning_house
@export var house_id: StringName
# SectionData ✦ + @export var unlock_flag: StringName = &""   # Abschnitt öffnet erst mit allen Hindernissen UND diesem Flag
# ExpansionManager (P3): func try_unlock(section_id: StringName) -> bool   # nach dem letzten Hindernis und nach dem Flag; sonst „Geräumt. Es fehlt die Weihe."
# Stonemasonry/GravePlot (P3): Ruhezeit-Grab (OLD, nicht hebbar) mit aktivem stone-Auftrag: Steinmetzbank darf einen Stein
#   dafür fertigen; „[E] Neuen Stein setzen (20 Min)" → Graveyard.replace_old_marker(grave_id, design) (Zustand bleibt OLD)
```

**Anatomie (P4)**
```gdscript
class_name AnatomyConfig extends Resource             # ✦ data/config/anatomy_config.tres (§2.6; Werte dort)
@export var organs: Dictionary[StringName, Dictionary] = {}   # heart, lung, stomach: {label, minutes, base_price, reputation_event, piety_event, res_tag, res_weight}
@export var tool_item: StringName = &"anatomy_case"; @export var room_id: StringName = &"crypt"; @export var min_freshness: float = 0.3
@export var jar_inputs: Dictionary[StringName, int] = {&"prep_jar": 1, &"spirits": 1}; @export var bundle_inputs: Dictionary[StringName, int] = {&"linen": 1}
@export var bundle_minutes: int = 600; @export var pult_cold_factor: float = 0.25; @export var clarity_words: PackedFloat32Array = [0.8, 0.6, 0.45]
@export var research_minutes: int = 30; @export var research_min_clarity: float = 0.5
@export var bundle_price_factor: float = 0.5; @export var display_price_factor: float = 1.5; @export var display_price_bonus: int = 2
@export var friend_price_bonus: int = 1; @export var return_minutes: int = 10; @export var seal_minutes: int = 5; @export var display_minutes: int = 40
@export var veil_seconds: float = 0.6; @export var veil_alpha: float = 0.85; @export var known_flag: StringName = &"anatomy_known"
class_name SpecimenFindingData extends Resource       # ✦ data/anatomy/findings/<id>.tres
@export var id: StringName; @export var organ: StringName; @export var priority: int = 0
@export var story_id: StringName = &""; @export var hidden_cause: StringName = &""; @export var cause_id: StringName = &""
@export var requires_trait: StringName = &""; @export_multiline var text: String; @export var clue_id: StringName = &""
@export var reveals_cause: StringName = &""          # Totenzettel „laut Quast: Arsenik"
class_name SpecimenRecord extends RefCounted         # ✦ reine Daten
const CONTAINER_JAR := &"jar"; const CONTAINER_BUNDLE := &"bundle"; const CONTAINER_DISPLAY := &"display"
const STATES: Array[StringName] = [&"held", &"sold", &"researched", &"returned"]
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
func research(uid: String, inv: Inventory) -> Dictionary   # nach der TimedAction; {finding, text, clue}; JournalManager.add_clue; Quast +3
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
#   HARVEST_KINDS + &"heart", &"lung", &"stomach" (angehängt); is_harvested / harvested unverändert
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
#   · consecrate_pay · anatomy_case (Quast: Besteck, Flag anatomy_known) · open_anatomist · rel_add:<npc>:<n>
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
#   zweite Karte → Panel &"pult" (W-UI) mit Specimens.seal / make_display als TimedAction (seal_minutes / display_minutes)
# PrepConfig ✦ balm_items + &"corpse_balm" (dritter Eintrag; juniper bleibt erstes Element)
# ShedConfig.excluded_items + specimen_jar, specimen_bundle, display_specimen (nur „Überschuss einlagern")
```

### 3.5 Database (Lead)
Neue Ordner → Schlüssel: `data/shops` (`id`), `data/orders` (`id`, nach `order`), `data/village/villagers` (`npc_id`), `data/anatomy/findings` (`id`, nach `priority`), `data/config/regions` (`region_id`). Funktionen: `shop(id)`, `shops()`, `order_data(id)`, `orders()`, `villager(npc_id)`, `villagers()`, `finding(id)`, `findings()`, `region_config(id)`. Configs `village_config`, `relationship_config`, `orders_config`, `anatomy_config`, `npc_config` über `config()`. Raum-Configs `data/config/interiors/{inn,surgery,office}.tres` über `interior_config(room_id)` (bestehend). Leere/fehlende Ordner = leere Listen.

### 3.6 Eingaben
Keine neuen Tasten. Panels über [E], Esc schließt. Laden-Panel: Mausklick, Umschalt+Klick = 5 Stück. Auftrags-Panel: `[`/`]` blättert (bestehende Aktionen `journal_page_prev/next`).
