# Phase 4 – Leichensystem erweitern – Vertrag v1

Status: **v1 – Entwurf zur Benutzerfreigabe, danach verbindlich für die Umsetzung** · Verantwortlich: Agent 01 (Lead), Agent 02 (Game Design), Agent 08 (Godot Core), Agent 11 (Corpse System), Agent 13 (Quest/Story)
Baut auf `docs/PHASE3_DESIGN.md` (Vertrag v1, freigegeben 27.09.2026) und `docs/VERTICAL_SLICE_DESIGN.md` (Vertrag v2) auf. Was dieses Dokument nicht ändert, gilt dort unverändert weiter.
Gameplay-Werte sind **Vorschläge**; der Benutzer prüft sie beim Gate G4. ART STYLE LOCK „Gemaltes Diorama" ist aktiv: Phase 4 ändert den Stil nicht. Verfall, Fliegen und Geruch werden gemalt und angedeutet dargestellt, **ohne Gore**. Der freigegebene Maler-Shader (`painted.gdshader`, `painted_common.gdshaderinc`) bleibt unverändert.

**Benutzerentscheidungen (verbindlich, 27.09.2026)**
- Inhalt, alle vier Teile:
  1. **Gründliche Untersuchung:** mehrere Schritte (Kleidung, Hände, Wunden, Taschen); die Funde erzählen mehr über die Toten.
  2. **Hinweise & Geheimnis:** Ein Merkbuch sammelt Hinweise aus Briefen, Tätowierungen und Wunden. Erster Erzählfaden: Was geschah mit dem letzten Totengräber?
  3. **Leichen herrichten:** waschen, einkleiden, aufbahren. Das bringt bessere Grabqualität und zufriedenere Geister.
  4. **Verwertung (Moral):** Wertsachen, Haar oder Zähne verkaufen statt würdevoll bestatten. Das bringt Münzen, kostet aber Ruf und macht Geister unruhig. Geschmackvoll und angedeutet, kein Gore.
- **Moral-System: ja, sanft.** Entscheidungen haben spürbare Folgen, es gibt aber kein „böses Ende", und beide Wege bleiben spielbar.
- **Verfall deutlicher:** sichtbare Stufen, Geruch als Effekt, Verfall zerstört Hinweise, eine einfache Konservierung.
- **Balancing-Übertrag aus Phase 3:** „Ehrwürdig" verlangt Zier **und** Pflege. Beim Playthrough-Bot erreichen „neglectful" und „hoarder" die Stufe nicht mehr, „diligent" weiterhin.

**Regeln für alle Agents** (wie Phase 3)
- Klassen, Signaturen, Dateipfade, Signale und Datenformate hier sind **fest**. Änderungen nur über den Lead.
- Der Lead legt in **Welle 0** alle Datenklassen (✦) vollständig und alle Logikklassen als **Stubs mit exakten Signaturen** an. Die Besitzer füllen die Körper und benennen nichts um.
- Nach jedem neuen Worktree und nach jedem Merge: `godot --headless --path . --import`.
- Jede Datei hat genau einen Besitzer (§3.2). Fremde Dateien nicht ändern; Bedarf an den Lead melden.
- Alle neuen Assets tragen `ph_` und kommen in die Placeholder-Liste (`docs/QUALITY_GATE_STATUS.md`).
- Keine Mechaniken, Namen oder Texte anderer Spiele übernehmen. Ausdrücklich **nicht**: Organe entnehmen, Fleisch verkaufen, Chemie-Einbalsamierung, Schädel-Wertungen, Leichen-„Qualitätssterne".
- Eigene Identität dieser Phase: **„Was sie mitbrachten"**. Jede Leiche bringt etwas mit: eine Spur, eine Bitte, eine Versuchung. Was man nicht ansieht, nimmt sie mit ins Grab.
- Sprache: alle Spieltexte eigenständig auf Deutsch, trocken-melancholisch, nachts leise unheimlich. Kein Spott über die Toten.

---

## 1. Spielablauf & Progression

### 1.1 Erweiterter Kern-Loop
```
Ankunft (07:40, Bahre) → zum Tisch tragen
  → UNTERSUCHEN in bis zu 4 Schritten: Kleidung · Hände & Arme · Wunden & Haut · Taschen & Säume
       └ Funde → Totenzettel im Merkbuch; Hinweise → Merkbuch (verknüpfen → Erkenntnis)
       └ Verfall: Funde mit Mindestfrische gehen verloren, wenn man zu lange wartet
  → ENTSCHEIDEN: Wertsachen (wie Phase 2) · optional VERWERTEN: Haar / Zähne → Hohlstein → Münzen am Morgen
  → HERRICHTEN: waschen · einkleiden (Leichentuch / Totenhemd) · aufbahren · optional mit Wacholder räuchern
  → Grab ausheben → bestatten → Grabzeichen → Qualität + Bezahlung (neue Zeilen)
  → Pietät (still, innen) · Ruf (öffentlich) · Geister (nachts: zufrieden / beraubt / ungerichtet)
```
Einkleiden ist der Schnitt: Danach sind Kleidung und Taschen nicht mehr zugänglich, und es wird nichts mehr verwertet. Die Reihenfolge ist also eine echte Entscheidung, ohne Zwang.

### 1.2 Zeitkosten (Spielminuten, alles TimedAction am Tisch, nicht abbrechbar – wie Phase 2 im Panel)
| Handlung | Minuten | Braucht | Wirkung (Kurz) |
|---|---|---|---|
| Kleidung durchsehen | 10 | – | Todesursache-Beschreibung, Kleidungsfunde; setzt `examined` |
| Hände & Arme | 10 | – | Tätowierung, Handfunde |
| Wunden & Haut | 15 | – | Zeichen, Ursachen-Detail |
| Taschen & Säume | 10 | – | Wertsachen, Brief, Gegenstände |
| **Gründlich untersuchen** (alle offenen Schritte) | Summe (max. 45) | – | ein Balken, gleiche Regeln |
| Waschen | 15 | `scrub_brush` (Werkzeug) | Qualität +1 |
| Einkleiden: Leichentuch / Totenhemd | 10 / 15 | 1 `shroud` / 1 `burial_gown` | Qualität +2 / +3 |
| Aufbahren | 10 | `comb` (Werkzeug) | Qualität +1 |
| Mit Wacholder räuchern | 10 | 1 `juniper` | Verfall × 0,25 für 18 h, kein Geruch |
| Haar abschneiden | 10 | `shears` | Item `hair_braid` |
| Zähne nehmen | 15 | `pliers` | Item `teeth_pouch` |
| Hohlstein befüllen / leeren | 0 (Panel) | – | Münzen am nächsten Morgen |
*Begründung:* Phase 2 brauchte für Untersuchen + Tuch 30 Min. Gründlich untersuchen und voll herrichten dauert 85 Min (+55 Min). Ein Phase-3-Tag hat genug Luft dafür (Bot-Tag endete bei 12 Gräbern mit Freizeit). Ein Mensch muss aber zwischen Pflege, Zier und Sorgfalt wählen. Die gewohnte Kurzform (Kleidung + Taschen + Leichentuch, 30 Min) bleibt voll spielbar.

### 1.3 Tagesbogen (neues Spiel, 1 Leiche/Tag, Richtwert Mensch)
Die Mechaniken (Schritte, Herrichten, Verfall, Merkbuch) gelten **ab Tag 1**. Der Erzählfaden läuft über feste **Geschichts-Leichen** (S1–S5, §2.11) und die bestehenden Merkmals-Tage 3–5 (die „Vorboten"). Phase 3 endet wie bisher um Tag 12–15 (12 Gräber). **Phase 4 fügt die Tage ≈ 15–21 hinzu** (Holunderwinkel, 6 weitere Grabstellen, S4/S5, Kapitelende).

| Tag | Geschehen | Leiche | Zielzeile (Beispiel) |
|---|---|---|---|
| 1 | Tutorial wie Phase 2. Das Panel zeigt 4 Schritte. Erste Notiz „[J] Merkbuch". | zufällig, keine Merkmale | „Untersuche die Leiche (Kleidung, Taschen …)" |
| 2 | Osric (`p4_intro`): „Kleider, Hände, Wunden, Taschen", verkauft **Wacholder**. Rezepte Wurzelbürste, Kamm, Totenhemd. | Wertsachen (Phase 2) | „Herrichten: waschen, einkleiden, aufbahren" |
| 3 | **Vorbote 1** | `strange_wound` → Hinweis *Das Zeichen* | – |
| 4 | Morgens steckt ein **Zettel an der Hüttentür** (Abnehmer) → Hohlstein bekannt, Werkzeug liegt darin. **Vorbote 2** | Wertsachen + `letter` → *Ein Warnbrief* | „Etwas steckt an deiner Tür" |
| 5 | **Vorbote 3** | Wertsachen + `tattoo` → *Anker und Schlange* | – |
| 6 | **S1 Marthe Quendel** | Geschichte | „Merkbuch: zwei Hinweise passen vielleicht zusammen" |
| 7–8 | Phase 3 (Ostwiese, Birkenhang) | zufällig | – |
| 9 | **S2 Jost Hemmerling** (ertrunken, verwest 1,5× schneller). In der Tasche: der Schlüssel zum **Holunderwinkel** | Geschichte | „Holunderwinkel aufschließen" |
| 10–12 | Holunderwinkel freilegen (300 Min). Ab Tag 12 bringt Osric den Schlüssel, falls er fehlt (§2.11). | zufällig | „Holunderwinkel: 4/10" |
| 13 | **S3 Ida Wernstein** | Geschichte | – |
| 13–15 | 12. Grab in Alter Hof/Ostwiese/Birkenhang → Phase-3-Abschluss „Der Friedhof ist vollendet" (unverändert) | zufällig | – |
| 16 | **S4 Bartel Uhlig** | Geschichte | – |
| 17–18 | Holunderwinkel füllt sich. **1 Grabstelle bleibt für S5 reserviert.** An Tagen ohne freie Stelle für Zufallsleichen bringt Osric nichts (still). | zufällig / keine | „Eine Grube wartet noch" |
| 19 | **S5 „Der Tote aus dem Moor"**: Osric bringt „den alten Aschau". | Geschichte, Finale | „Sieh ihn dir genau an" |
| ≈ 19–21 | S5 bestattet und alle 6 Grabstellen im Holunderwinkel `MARKED` → **Kapitelende „Sechs Gruben"** | – | – |

**Phasenende (Kapitel `six_pits`):** Alle 6 Grabstellen des Holunderwinkels sind `MARKED` **und** S5 ist bestattet. Dann: Flag `six_pits_complete`, Signal `chapter_completed(&"six_pits")`, Abschluss-Panel Variante „Sechs Gruben" (Tage, Bestattungen, hergerichtet/verwertet, Pietät-Stufe als Wort, Erkenntnisse n/5, Geister zufrieden/unruhig, Schlusszeile je nach Erkenntnis *Nicht Lorenz*). Danach läuft das Spiel frei weiter. Wenn alles belegt ist, enden die Lieferungen still (bestehende Regel). **Gate-Ziel:** Beide Wege (würdevoll / verwertend) erreichen das Kapitelende; der verwertende Weg ist langsamer, aber nicht gesperrt.

### 1.4 Das Geheimnis

**Gesamtbogen (Autorenwissen, Phase 18 entscheidet endgültig, hier nur Leitplanke):**
Lorenz Aschau war 31 Jahre Totengräber von Hollerbrück. Vor gut einem Jahr verschwand er. Die Hütte stand offen, die Schaufel lehnte am Tor (Osric, Phase 2). Er hatte entdeckt, dass im Dorf Sterbende mit einem Zeichen „gezeichnet" werden: einem Kreis, von drei Linien durchbrochen, dem **Dreistrich**. Diese Toten finden keine Ruhe, der Hügel „behält" sie („Der Hügel erinnert sich", Phase 3). Lorenz warnte die Gezeichneten mit namenlosen Briefen. Mit den alten Moorfährleuten (Tätowierung Anker + Schlange) ließ er sie nachts über das Moor fortbringen. Nicht alle kamen an. Im Holunderwinkel hinter der Hütte hob er sechs Gruben aus: Holunder hält im Volksglauben Böses fern. Dann ließ er sich für tot erklären. Einem toten Fährmann zog er seinen Mantel an, er selbst stieg unter den Birkenhang hinab (Krypten, Phase 12). Wer zeichnet und wozu, bleibt Phase 13–18 vorbehalten. Wer am Hohlstein kauft, kannte Lorenz. Ob der Käufer Freund oder Feind ist, bleibt offen.

**Phase-4-Ausschnitt (was der Spieler herausfinden kann):**
1. Die Warnbriefe schrieb Lorenz selbst (*Wer die Warnbriefe schrieb*).
2. Das Zeichen wird Wochen vor dem Tod geritzt. Jemand wählt aus (*Gezeichnet*).
3. Die Fährleute mit Anker und Schlange brachten Gezeichnete nachts fort, Lorenz bezahlte (*Die Nachtfähre*).
4. Nach Lorenz' Verschwinden schreibt dieselbe Hand weiter (*Die Hand schreibt weiter*).
5. Der Tote aus dem Moor ist nicht Lorenz, sondern Kaspar Dorn. Lorenz lebt (*Nicht Lorenz*). Letzte Zeile: „Unter dem Birkenhang ist es nicht still." (Haken Phase 12).
Optional für verwertende Spieler: *Holunderblüten* (Der Abnehmer kannte Lorenz). Die Toten tragen das Geheimnis. Beide Wege erzählen es, nur aus verschiedenen Blickwinkeln.

---

## 2. Spielwerte (Vorschläge, alle in `data/`)

### 2.1 Untersuchung (`data/config/exam_config.tres` – `ExamConfig`)
| Schritt `id` | Name | Min | Deckt auf | Nach dem Einkleiden |
|---|---|---|---|---|
| `clothing` | Kleidung | 10 | Todesursache-Beschreibung (bestehend `causes[].description`), Kleidungsfunde | gesperrt |
| `hands` | Hände & Arme | 10 | `tattoo`, Handfunde | möglich |
| `wounds` | Wunden & Haut | 15 | `strange_wound`, Ursachen-Detail | möglich |
| `pockets` | Taschen & Säume | 10 | `valuables`, `letter`, Gegenstände | gesperrt |
- `examined` (Phase-2-Feld) wird **true nach dem ersten erledigten Schritt**. Die Qualitätszeile „Untersucht +1" bleibt. Gründlichkeit wird mit Funden belohnt, nicht mit Punkten. So bleibt die Qualität berechenbar.
- `revealed_traits()` gilt neu: Ein Merkmal ist aufgedeckt, wenn sein Fund aufgedeckt ist (Zuordnung Merkmal → Schritt oben). `needs_valuables_decision()` = `pockets` erledigt ∧ Wertsachen ∧ unentschieden.
- Schritt ohne Funde: Karte „Nichts Auffälliges." (`ExamConfig.nothing_text`).
- **Gründlich untersuchen**: Alle offenen, erlaubten Schritte laufen als **eine** TimedAction mit der Summe der Minuten. Aufgelöst wird jeder Schritt am Ende mit der Frische bei Abschluss (einfach und deterministisch).

### 2.2 Funde (`data/finds/<id>.tres` – `FindData`)
Ein Fund wird bei Abschluss seines Schritts **aufgedeckt**, wenn `freshness ≥ min_freshness`, sonst **verloren** (Karte gedimmt mit `lost_text`). Aufgedeckte Funde bleiben für immer.
Frische-Klassen: **Papier/Gegenstände 0,0** (nie verloren) · **Hautzeichen 0,3** (bis „Welk") · **feine Spuren 0,6** (nur „Frisch").

**Generische Funde** (jede Zufallsleiche, abhängig von Merkmal oder Ursache):
| id | Schritt | min | Quelle | Hinweis → Merkbuch | Text / Verlusttext |
|---|---|---|---|---|---|
| `f_valuables` | pockets | 0,0 | Merkmal `valuables` | – | `reveal_text` aus CorpseTables |
| `f_letter` | pockets | 0,0 | `letter` | `c_warning_letter` | `reveal_text` |
| `f_tattoo` | hands | 0,3 | `tattoo` | `c_anchor_snake` | `reveal_text` · verloren: „Die Haut am Unterarm ist fleckig geworden. Was dort war, lässt sich nicht mehr erkennen." |
| `f_mark` | wounds | 0,3 | `strange_wound` | `c_mark` | `reveal_text` · verloren: „Über dem Herzen ist die Haut dunkel verfärbt. Vielleicht war da etwas. Jetzt nicht mehr." |
| `f_cause_<cause>` (7×) | wounds | 0,6 | Ursache | – | Ursachen-Detail (unten) · verloren: „Was die ersten Stunden noch gezeigt hätten, ist vergangen." |

Ursachen-Details (eigene Texte, P2 darf glätten):
- `fever`: „Kleine rote Flecken unter den Achseln. Das Sumpffieber zeigt sie nur in den ersten Stunden."
- `drowned_millpond`: „In der Faust ein Büschel Wasserlinsen. Wer ertrinkt, greift nach allem."
- `fall_hayloft`: „Die Handflächen sind aufgeschürft – ein Griff ins Leere."
- `old_age`: „Die Lippen stehen einen Spalt offen, als fehlte noch ein letztes Wort."
- `poisoned`: „Ein Hauch von Bittermandel, der schon jetzt verfliegt."
- `coach_accident`: „Die blauen Flecken ordnen sich zu einem Bogen. Ein Rad, kein Huf."
- `moor_cold`: „Die Haut ist ledrig und dunkel vom Moorwasser. Das Moor hält fest, was es hat."

Hinweis-Regel: Ein generischer Fund legt seinen Hinweis nur beim **ersten** Mal an. Weitere Fälle erscheinen im Totenzettel und erhöhen am Hinweis den Zähler „(3 Tote)".

**Geschichts-Funde** (nur an S1–S5; ein Geschichts-Fund mit `trait_id` **ersetzt** den generischen Fund dieses Merkmals):
| Leiche | id | Schritt | min | Hinweis | Text |
|---|---|---|---|---|---|
| S1 | `f_s1_sprig` | clothing | 0,0 | – | „Ein Holunderzweig steckt im Mieder, die Blüten noch weiß – als hätte ihn jemand heute Morgen hineingesteckt." |
| S1 | `f_s1_soil` | hands | 0,6 | – | „Frische Gartenerde unter den Nägeln. Sie hat bis zuletzt gegraben." |
| S1 | (generisch `f_mark`) | wounds | 0,3 | `c_mark` | – |
| S1 | `f_s1_page` | pockets | 0,0 | `c_page_1` | „Ein herausgerissenes Blatt, eng beschrieben: ‚M. Quendel – gezeichnet seit Lichtmess. Hab ihr zweimal geschrieben. Sie will nicht fort. Sie sagt, einer muss die Gräber der anderen gießen. – L. A.'" |
| S2 | `f_s2_jacket` | clothing | 0,0 | `c_ferry_jacket` | „Eine Joppe mit Messingknöpfen, auf jedem ein kleines Ruder. So kleideten sich die Moorfährleute, bevor die Fähre stillgelegt wurde." |
| S2 | (generisch `f_tattoo`) | hands | 0,3 | `c_anchor_snake` | – |
| S2 | `f_s2_wrists` | wounds | 0,6 | – | „Keine Wunde. Nur Striemen an den Handgelenken, als hätte er sich an etwas festgeklammert." |
| S2 | `f_s2_key` | pockets | 0,0 | `c_elder_key` · Flag `has_elder_key` | „Ein rostiger Schlüssel an einer Lederschnur. In den Bart ist ein Holunderblatt gefeilt." |
| S3 | `f_s3_coat` | clothing | 0,6 | – | „Der Reisemantel ist zugeknöpft, als wäre sie gerade aufgebrochen." |
| S3 | `f_s3_ink` | hands | 0,3 | – | „Tinte an Daumen und Zeigefinger. Sie hat viel geschrieben, zuletzt." |
| S3 | `f_s3_mark` (ersetzt `f_mark`) | wounds | 0,3 | `c_mark_healed` | „Das Zeichen über ihrem Herzen ist längst verheilt – eine blasse, alte Narbe. Sie trug es seit Wochen." |
| S3 | `f_s3_letter` (ersetzt `f_letter`) | pockets | 0,0 | `c_letter_late` | „Ein Warnbrief in derselben schrägen Hand: ‚Geh vor Martini, Ida. Nimm nicht die Nachtfähre, sie ist verraten.' Datiert drei Wochen, nachdem der alte Totengräber verschwand." |
| S4 | `f_s4_collar` | clothing | 0,6 | – | „Heu im Kragen – und darunter schwarzer Torf, der nicht vom Heuboden stammt." |
| S4 | (generisch `f_tattoo`) | hands | 0,3 | `c_anchor_snake` | – |
| S4 | `f_s4_scar` | hands | 0,3 | `c_oath_scar` | „Quer über die linke Handfläche läuft eine alte Schnittnarbe. So besiegelten die Fährleute einen Schwur." |
| S4 | `f_s4_token` | pockets | 0,0 | `c_ferry_token` | „Eine Blechmarke, darauf eine Schlange um einen Anker: ‚Moorfähre – Nachtfahrt – frei.' Auf der Rückseite eingeritzt: ‚L. A. zahlt.'" |
| S5 | `f_s5_coat` | clothing | 0,0 | `c_coat` | „Ein langer, geflickter Totengräbermantel. Innen am Kragen gestickt: ‚L. Aschau'." |
| S5 | `f_s5_buckle` | clothing | 0,0 | `c_buckle` | „Die Gürtelschnalle passt nicht zum Mantel. Eingeritzt: K. D." |
| S5 | `f_s5_hands` | hands | 0,3 | `c_soft_hands` | „Junge Hände, keine Schwielen vom Spaten. Lorenz hat dreißig Jahre gegraben." |
| S5 | (generisch `f_mark`) | wounds | 0,3 | `c_mark` | – |
| S5 | `f_s5_list` | pockets | 0,0 | `c_page_list` | „Ins Mantelfutter eingenäht: die letzte Seite aus Lorenz' Kladde. Sechs Namen: Quendel. Hemmerling. Wernstein. Uhlig. Dorn. Der sechste ist vom Moorwasser verwischt. Darunter: ‚Unter dem Birkenhang ist es nicht still.'" |
*Begründung Frische:* Papier überlebt immer. Wer zu spät kommt, verliert Stimmung und Hautzeichen, aber nie den roten Faden. S2 (ertrunken, 1,5×) setzt als einzige Leiche echten Zeitdruck: Die Tätowierung ist ab ≈ 17:00 verloren.

### 2.3 Herrichten (`data/config/prep_config.tres` – `PrepConfig`)
| Aktion | Minuten | Braucht | Regeln | Qualität |
|---|---|---|---|---|
| Waschen | 15 | Werkzeug `scrub_brush` | nur **vor** dem Einkleiden, einmal | „Gewaschen" +1 |
| Einkleiden: Leichentuch | 10 | 1 `shroud` | einmal; gesperrt, solange die Wertsachen-Entscheidung offen ist (wie Phase 2) | „Leichentuch" +2 (bestehend) |
| Einkleiden: Totenhemd | 15 | 1 `burial_gown` | wie oben | „Totenhemd" +3 |
| Aufbahren | 10 | Werkzeug `comb` | einmal, vor oder nach dem Einkleiden: Augen schließen, Hände falten, Haar kämmen, Zweig auflegen | „Aufgebahrt" +1 |
| Räuchern | 10 | 1 `juniper` | nicht, solange ein Räucherfenster läuft | – (§2.5) |
- **Voll hergerichtet** = gewaschen ∧ eingekleidet ∧ aufgebahrt → Pietät +3 (einmal je Leiche), Zähler `stats.prepared`.
- Einkleiden sperrt `clothing`, `pockets` und jede Verwertung. Der Knopf warnt vorher: „Nach dem Einkleiden sind Kleidung und Taschen nicht mehr zugänglich."
- `CorpseRecord.shrouded` bleibt als Kompatibilitätsfeld: `shrouded == (dress != &"")`. Phase-2/3-Code, der `shrouded` liest (Geister „cold", Register, Tests), gilt für beide Kleidungen.
- Der Tisch bleibt die **einzige** Station. Waschschüssel und Räucherschale stehen als Requisiten daneben (W-Welt). Es gibt keine zweite Tischstelle.
*Begründung:* Volles Herrichten kostet 40 Min und bringt +3 Qualität gegenüber dem Phase-3-Standard (Leichentuch). Das sind +1,5 Münzen je Grab, 3 Friedhofspunkte und oft ein zufriedener statt gleichmütiger Geist. Das Totenhemd ist die Luxusstufe (+1 für 3 Münzen mehr Leinen) und eine bewusste Münzsenke (GP-03).

### 2.4 Grabqualität neu (`EconomyConfig`, `GraveQuality`)
| Zeile (Reihenfolge) | Punkte | neu? |
|---|---|---|
| Bestattet | +2 | – |
| Gewaschen | +1 | neu `quality_washed` |
| Leichentuch / Totenhemd | +2 / +3 | neu `dress_quality {shroud: 2, gown: 3}` (`quality_shroud` bleibt = 2) |
| Aufgebahrt | +1 | neu `quality_laid_out` |
| Holzkreuz / Grabstein | +1 / +3 | – |
| Frisch (≥ 0,6) / Verwesend (< 0,3) / **Verfallen (< 0,1)** | +1 / −1 / **−2** | neu `rot_threshold 0.1`, `rot_malus −2` |
| Untersucht (≥ 1 Schritt) | +1 | – |
| Wertsachen liegen gelassen / genommen | +1 / −2 | – |
| **Haar genommen / Zähne genommen** | **−1 / −2** | neu `harvest_malus {hair: −1, teeth: −2}` |
**`quality_max` 10 → 13** (theoretisches Maximum ohne Klemmen: 2+1+3+1+3+1+1+1 = 13). `quality_min` 0. Vollendete Gräber aus Phase 2/3 behalten ihre gespeicherte Qualität (keine Neuberechnung). Bezahlung unverändert `base + floor(Q × 0,5) + Ruf-Bonus`.
*Begründung:* Die Klemme bei 10 würde Herrichten wertlos machen (der Phase-3-Bot erreicht schon 9–10). 13 macht jeden Handgriff sichtbar. Die Friedhofsstufen 15/32/50/100 bleiben (Phase-3-Freigabe). Sie werden früher erreicht, dafür bekommt „Ehrwürdig" die Zusatzbedingung aus §2.14.

### 2.5 Verfall & Räuchern (`CorpseTables`, `EconomyConfig`, `PrepConfig`, `DecayVisualConfig`)
Formel unverändert, nur mit Räucherfenstern: `frische = 1 − rate × wirksame_minuten / 60`. Dabei ist `wirksame_minuten = minuten_seit_ankunft − (1 − balm_factor) × Σ Überlappung(Räucherfenster, [ankunft, jetzt])`. `rate = 0,05 × decay_mult`. Weiter rein aus der Minutendifferenz (keine Ticks), Raster 1e-6.

| Stufe `id` | ab Frische | bei Rate 1,0 (Ankunft 07:40) | Sichtbar (gemalt) | Folgen |
|---|---|---|---|---|
| Frisch `fresh` | ≥ 0,6 | bis 15:40 | nichts | feine Spuren lesbar, Qualität +1 |
| Welk `wilted` | ≥ 0,3 | 15:40–21:40 | fahler Hautton (Überlagerung 0,35), 4 Fliegen | feine Spuren verloren |
| Verwesend `decaying` | ≥ 0,1 | 21:40–01:40 | fleckig graugrün (0,7), 8 Fliegen, 3 Geruchsschwaden | Hautzeichen verloren, Qualität −1, Haar nicht verwertbar, Gestank am Tor |
| **Verfallen `rotten`** (neu) | < 0,1 | ab 01:40 | stark entsättigt (1,0), 10 Fliegen, 5 Schwaden | Qualität −2, Pietät −2 bei Bestattung |
Ursachen-Raten bleiben (0,75–1,5). Neu `moor_cold` 0,5 (nur S5, `weight 0`). *Begründung:* Die Geschwindigkeit bleibt. Neu ist, dass Warten sichtbar ist und Folgen hat: Spuren, Geruch, Ruf. Wer am Ankunftstag bestattet, spürt nur das Fenster „Frisch bis Nachmittag".

- **Räuchern** (Wacholder): 10 Min, `balm_factor 0,25`, Fenster 1 080 Min (18 h), höchstens 4 Fenster je Leiche. Während des Fensters gibt es keine Geruchsschwaden, sondern einen dünnen, warmgrauen Wacholderrauch (3 Partikel, Tischnähe). Gewählt statt Kühlkeller oder Eishaus: kein neuer Raum, keine neue Lagerlogik, ein Verbrauchsgut, eine Aktion am bestehenden Tisch. Wacholder: Osric, **2 Münzen**, Stapel 10.
- **Gestank am Tor:** Liegt bei Osrics Morgenlieferung (07:40) eine nicht bestattete Leiche mit Stufe ≥ `decaying` und ohne Räucherfenster, dann Ruf −2 („Gestank am Tor", einmal je Tag) und ein Osric-Satz. Aus `CorpseManager._deliver` (P1).
- **Geruch am Spieler:** Wer eine verwesende Leiche trägt, bekommt einmal je Leiche die Notiz „Es riecht streng." Keine weitere Wirkung.
- Bestattete Leichen verfallen nicht weiter (unverändert). Gräber zeigen keinen Verfall.

### 2.6 Verwertung & Hohlstein (`data/config/utilization_config.tres` – `UtilizationConfig`)
| Art `kind` | Handlung | Min | Werkzeug | Item | Mindestfrische | Qualität | Ruf | Pietät | Geist (Stimmungswert) |
|---|---|---|---|---|---|---|---|---|---|
| `hair` | „Zopf abschneiden" | 10 | `shears` | `hair_braid` | 0,3 („Das Haar ist zu brüchig.") | −1 | −3 | −4 | −5 |
| `teeth` | „Zähne nehmen" | 15 | `pliers` | `teeth_pouch` | – | −2 | −5 | −6 | −5 |
| Wertsachen (Phase 2) | „Nehmen" | – | – | Münzen sofort | – | −2 (bestehend) | −8 (bestehend) | −6 | über Qualität |
- Nur vor dem Einkleiden, je Art einmal je Leiche, nur wenn der Hohlstein bekannt ist (Flag `hollow_known`). Ohne Werkzeug erscheint der Knopf gedimmt: „Werkzeug fehlt (liegt im Hohlstein)". Vor dem Bekanntwerden gibt es keinen Knopf.
- **Darstellung:** keine Animation am Körper. Die Figur beugt sich über den Tisch (`interact`), der Balken läuft, dann eine Zeile. Ton: „Du schneidest den Zopf ab. Er ist schwerer, als du dachtest." / „Du nimmst, was der Zahnbrecher in der Stadt bezahlt. Du siehst dabei nicht hin."
- **Hohlstein** (Entity an der Westmauer, §4): „[E] Hohlstein öffnen" → Panel. Einlegen: `hair_braid` **4**, `teeth_pouch` **5** Münzen (`sell_prices`). Bei Pietät „Abgebrüht" oder tiefer +1 je Stück („Er kennt dich jetzt."). Die Auszahlung kommt am **nächsten Morgen 06:00** (`day_started`, idempotent über `last_payout_day`): Die Münzen liegen im Stein, „[E] Münzen nehmen (9)". Benachrichtigung „Im Hohlstein klimpert es." Keine anderen Waren, kein Rückkauf.
- **Werkzeug:** Beim ersten Öffnen liegen `shears` und `pliers` im Stein (einmalig, `tools_given`). Sie lassen sich nicht herstellen.
- **Abnehmer-Zettel** (Hinweise, §2.12): Zettel 1 am Tag 4 an der Hüttentür (macht den Stein bekannt). Zettel 2 nach der 4. eingelegten Ware, Zettel 3 nach der 8. (`note_thresholds [0, 4, 8]`).
- **Wertsachen** bleiben wie in Phase 2: Münzen sofort, ohne Hohlstein. Sie zählen neu auch für die Pietät.
*Begründung Folgen:* Eine voll verwertete Leiche (Haar + Zähne, dazu im Mittel 35 % Wertsachen) bringt ≈ 9–11 Münzen am Hohlstein plus ≈ 2,3 aus Wertsachen. Sie kostet ≈ 3–4 Qualität (≈ −2 Münzen Bezahlung), −8 Ruf (Wertsachen im Mittel −2,8 zusätzlich), −10 Pietät und einen unruhigen Geist. Rechnung §2.15.

### 2.7 Pietät – der Moralwert (`data/config/piety_config.tres` – `PietyConfig`)
**Name (Vorschlag, Frage §14.1): „Pietät"** – die Achtung vor den Toten. Sie ist **innen** (nur der Spieler und die Toten wissen es), der Ruf ist **außen** (das Dorf).
- Wert **−100…+100**, Start **0**, gespeichert in `GameState.stats.piety` (Dialog-Bedingungen `stat_gte/stat_lt` nutzbar).
| Stufe | id | Bereich | Selbstbild im Merkbuch (Beispiel) |
|---|---|---|---|
| Hartherzig | `hardhearted` | ≤ −60 | „Die Toten sind Ware. Du schläfst trotzdem." |
| Abgebrüht | `callous` | −59…−20 | „Man gewöhnt sich. Das ist ja das Schlimme." |
| Sachlich | `matter_of_fact` | −19…+19 | „Ein Handwerk wie jedes andere. Meistens." |
| Rücksichtsvoll | `considerate` | +20…+59 | „Du sprichst mit ihnen, wenn keiner zuhört." |
| Andächtig | `devout` | ≥ +60 | „Du gehst leise zwischen ihnen. Sie merken es." |
`tier_thresholds = [−59, −19, 20, 60]` (Stufe i+1 ab Wert ≥ Schwelle i).

**Änderungen** (`events`, direkt vom auslösenden System über `Piety.event`):
| Ereignis | Punkte | Auslöser |
|---|---|---|
| `valuables_left` | +3 | CorpseManager.decide_valuables |
| `valuables_taken` | −6 | CorpseManager.decide_valuables |
| `hair_taken` / `teeth_taken` | −4 / −6 | CorpseCare.harvest |
| `full_prep` | +3 | CorpseCare (3. Bestandteil fertig) |
| `bare_burial` (ohne Kleidung bestattet) | −2 | Graveyard.bury |
| `rotten_burial` (Stufe `rotten` bei Bestattung) | −2 | Graveyard.bury |
| Tägliche Erholung | +1 Richtung 0, nur wenn Wert < 0 und am Vortag nichts verwertet (Flag `piety_used_day`) | Piety.apply_daily bei `day_started`, idempotent (`piety_last_day`) |
*Nachrechnung:* Der würdevolle Weg bringt je Leiche +3, dazu im Mittel +1,05 aus Wertsachen, zusammen ≈ +4. „Rücksichtsvoll" kommt um Tag 5, „Andächtig" um Tag 15. Voll verwerten kostet je Leiche ≈ −10 bis −12 (mit Herrichten −7 bis −9). „Abgebrüht" kommt nach 2 Leichen, „Hartherzig" nach ≈ 6. Wer einmal verwertet und dann aufhört, erholt sich um 1 je Tag und 4 je hergerichtete Leiche: Nach ≈ 3 Tagen ist er wieder „Sachlich" (sanft, keine Sackgasse).

**Wirkung in Phase 4** (spürbar, nie sperrend):
| Stufe | Geistergabe (§2.9) | Abnehmer | Osric | Geister-Zeilen |
|---|---|---|---|---|
| Hartherzig | keine („Die Geister deuten nicht mehr ins Moos.") | +1 je Stück | kühl, knapp | 1 von 4 gehörten Zeilen aus `by_piety.hardhearted` |
| Abgebrüht | 2 | +1 je Stück | spitze Bemerkung (einmal je Stufe) | – |
| Sachlich | 2 | ±0 | wie bisher | – |
| Rücksichtsvoll | 2 | ±0 | warme Bemerkung | – |
| Andächtig | **3** | ±0 | Dank, erzählt von Lorenz' Art (einmal) | 1 von 4 aus `by_piety.devout` |
- **Keine** HUD-Anzeige (Begründung §7). Stufenwechsel → leise Benachrichtigung ohne Zahl („Du merkst, dass dir das nicht mehr schwerfällt." / „Du merkst, dass du leiser gehst.").
- **Haken für Phase 13+ (nur API, heute ohne Wirkung):** `PietyRules.affinity(value)` → `&"soul"` (≥ 20) · `&"bone"` (≤ −20) · `&""`. Dazu die Statistiken `stats.prepared` / `stats.utilized` und die Zettel des Abnehmers. Später können Seelenkräfte (Geister als Helfer) an hohe, Knochenkräfte (Auferstehung/untote Arbeiter) an niedrige Pietät gebunden werden. Keine Phase-4-Logik liest `affinity`.
- **Kein böses Ende:** Das Kapitelende ist in jeder Stufe gleich erreichbar, nur die Schlusszeile im Panel wechselt (5 Varianten).

### 2.8 Ruf – neue Ereignisse (`ReputationConfig.event_points`)
`hair_taken −3` · `teeth_taken −5` · `stench −2` (§2.5). Bestehend bleiben u. a. Wertsachen −8 (`EconomyConfig.valuables_reputation`), Grab gut +2 / schlecht −3. Der tägliche Drift ist unverändert und folgt der Friedhofsqualität.

### 2.9 Geister (Änderungen, `GhostConfig`, `GhostLines`, `GhostMood`)
- **Stimmungswert** = Grabqualität + Pflegestelle + Zierbonus + **Beraubt-Abzug** (`robbed_mood −5` je genommener Art Haar/Zähne). Schwellen unverändert `[5, 9]`.
  Beispiele: voll hergerichtet + Grabstein + frisch + untersucht = 12, gepflegt +1 → 13 zufrieden. Nur Holzkreuz + Tuch 7 +1 = 8 gleichmütig; mit Waschen + Aufbahren 10 → **zufrieden**. Zopf genommen: 12 − 1 − 5 + 1 = 7 gleichmütig, Grund „beraubt". Haar + Zähne: 12 − 3 − 10 + 1 = 0 → **unruhig**.
- **Gründe** (neue Priorität): `robbed` (Haar/Zähne) → `weeds` → `valuables` → `cold` (ohne Kleidung) → **`unkempt`** (nicht gewaschen oder nicht aufgebahrt) → `cross` → `waited` (verwesend/verfallen bestattet) → `bare`.
- **Geschichts-Geister** (S1–S5) bekommen als zufriedene und gleichmütige Geister eigene Zeilen (`GhostLines.by_story`, je 2). Das Merkbuch vermerkt beim Zuhören „Gehört: …" am Totenzettel.
- **Gabe** je Pietät-Stufe (`PietyConfig.gift_by_tier = [0, 2, 2, 2, 3]`), weiter einmal je Grab.
- Neue Zeilen (je 3, ≤ 90 Zeichen, P4): `robbed`: „Mir fehlt etwas. Ich weiß genau, was." · „Mein Zopf. Wo ist mein Zopf?" · „Du hast mir genommen, was mir gehörte. Nicht das Geld – mich." `unkempt`: „Ungewaschen in die Erde. Der Staub juckt noch." · „Meine Hände liegen irgendwie. Hat sie keiner gefaltet?" · „Mein Haar war mein Stolz. Nun liegt es wirr." `by_piety.devout` (2), `by_piety.hardhearted` (2, z. B. „Du riechst nach Hohlstein, Totengräber."). Geschichte (Beispiele): S1 „Die Briefe waren gut gemeint. Aber wer gießt dann die Gräber?" · S2 „Ich hab sie übers Moor gerudert, Nacht für Nacht. Die Letzte nicht." · S3 „Ich hatte gepackt. Ich war so nah am Fortgehen." · S4 „Wir haben geschworen, Lorenz und wir. Ich hab mich dran gehalten." · S5 „Ich trage einen fremden Mantel. Er war mir immer zu weit." / „Der Sechste ist noch nicht tot."

### 2.10 Holunderwinkel (neuer Abschnitt, `data/sections/elder.tres`, `data/clearables/*`)
| # | id | Name | Grabstellen | Freilegen | Voraussetzung |
|---|---|---|---|---|---|
| IV | `elder` | **Holunderwinkel** | `h_01…h_06` | 1× Pförtchen, 2× Holunderdickicht, 6× eingesunkene Grube, 1× Zaunlücke | Flag `has_elder_key` (`SectionData.requires_flag`) |
| kind | Name / Verb | Minuten | Kosten | Ertrag |
|---|---|---|---|---|
| `gate_small` | Rostiges Pförtchen / „aufschließen" | 10 | – (Flag) | – |
| `elder_thicket` | Holunderdickicht / „zurückschneiden" | 40 | – | 2 wood |
| `sunken_pit` | Eingesunkene Grube / „zuschütten und abstecken" | 30 | – | – |
| `fence_gap` | Zaunlücke (bestehend) | 30 | 2 wood, 1 iron_fittings | – |
Summe 300 Min (≈ 5 h), Kosten 2 Holz + 1 Eisen, Ertrag 4 Holz. `decor_cap 6` (Zier gesamt max. 36). **`counts_for_cemetery = false`**: Der Holunderwinkel zählt nicht zur Phase-3-Vollendung (`cemetery_complete` bleibt „12 Gräber in Abschnitt I–III"), wohl aber zur Friedhofsqualität, zu Pflege und Geistern. `chapter = &"six_pits"`. Ohne Schlüssel zeigen die Hindernisse gedimmt „Das Pförtchen ist verschlossen." Bei der Freigabe: Ruf +4 (bestehend), Hinweis `c_six_pits`, Text „Sechs Gruben, sauber ausgehoben, längst eingesunken. Wer gräbt Gräber für Tote, die noch leben?"
*Begründung:* Ohne neue Grabstellen enden die Lieferungen mit dem 12. Grab (Phase-3-Regel „Friedhof voll → still"), und Phase 4 hätte keine neuen Tage. 6 Stellen tragen ≈ 7 Tage. Der Winkel ist zugleich Schauplatz des Geheimnisses: Lorenz' sechs Gruben.

### 2.11 Geschichts-Leichen & Lieferregel (`data/story/<id>.tres` – `StoryCorpseData`, `data/config/story_config.tres` – `StoryConfig`)
| # | id | Name, Alter | Ursache | Merkmale | Look | `earliest_day` | Osric bei Ankunft (Benachrichtigung) |
|---|---|---|---|---|---|---|---|
| S1 | `s1_quendel` | Marthe Quendel, 63 | `old_age` | `strange_wound` | alte Frau (1) | 6 | „Marthe Quendel. Hat mir mal die Hand verbunden, als das Rad brach. Sei gut zu ihr." |
| S2 | `s2_hemmerling` | Jost Hemmerling, 41 | `drowned_millpond` | `tattoo` | Knecht (0) | 9 | „Aus dem Mühlteich. Jost war früher Fährmann, bevor sie die Moorfähre zugemacht haben." |
| S3 | `s3_wernstein` | Ida Wernstein, 27 | `poisoned` | `strange_wound`, `letter` | junge Frau (**5, neu**) | 13 | „Ida Wernstein. Die wollte weg aus Hollerbrück, hieß es. Hat's nicht geschafft." |
| S4 | `s4_uhlig` | Bartel Uhlig, 72 | `fall_hayloft` | `tattoo` | alter Mann (2) | 16 | „Der alte Uhlig. Vom Heuboden, sagen sie. Mit zweiundsiebzig steigt man da nicht mehr hinauf." |
| S5 | `s5_moor` | „Lorenz Aschau?", ≈ 50 | `moor_cold` (neu) | `strange_wound` | Mann im langen Mantel (**4, neu**) | 19 | „Das ist er, Totengräber. Der alte Aschau. Das Moor hat ihn ausgespuckt." |
Geschichts-Leichen haben keine Wertsachen (`valuables_coins 0`, kein Merkmal). Verwertung ist möglich. Geister und Merkbuch reagieren darauf, die Geschichte bleibt lösbar.

**Lieferregel (Ergänzung Phase-3 §2.7, CorpseManager + `StoryDirector`):**
1. An einem Liefertag wird zuerst geprüft, ob eine Geschichts-Leiche fällig ist: die nächste nicht gelieferte nach `order` mit `tag ≥ earliest_day` **und** `tag ≥ story_last_day + min_gap_days (2)`. Dann kommt sie **statt** der Zufallsleiche (weiter höchstens 1 Leiche/Tag, freie Bahre nötig, Verrufen nur an ungeraden Tagen).
2. **Reservierung:** Eine Zufallsleiche kommt nur, wenn `freie Grabstellen > nicht bestattete Leichen + ausstehende Geschichts-Leichen`. Eine Geschichts-Leiche braucht `freie > nicht bestattete`. Keine Zufallsleiche wegen Reservierung → still (kein Versäumnis). Osric: „Heute nichts. Aber halt eine Grube frei."
3. Migrierte Stände holen auf: Die Geschichte beginnt am ersten Liefertag nach dem Laden, danach folgt alle 2 Tage die nächste Leiche.
4. **Schlüssel-Rückfall:** Ab `key_fallback_day 12` bei `day_started` ohne `has_elder_key` setzt `StoryDirector` das Flag. Der Hinweis `c_elder_key` kommt ohne Zeile, dazu die Benachrichtigung „An der Bahre hängt ein rostiger Schlüssel an einer Schnur. Osric: ‚Lag an der alten Fährstelle.'" (Kein Softlock, auch nicht in migrierten Ständen, die schon voll sind.)
5. **Zettel an der Tür** (`HollowStoneMarket.apply_morning`, P3): Ab `StoryConfig.hollow_note_day 4` wird bei `day_started` einmalig Flag `hollow_known` gesetzt, dazu Hinweis `c_buyer_note_1` und die Benachrichtigung „An deiner Hüttentür steckt ein Zettel."
6. S5 heißt im Register „Lorenz Aschau (?)". Mit der Erkenntnis *Nicht Lorenz* benennt das Merkbuch den Datensatz in **„Kaspar Dorn"** um (`InsightData.rename_story`).

### 2.12 Merkbuch (`data/journal/clues/<id>.tres` – `ClueData`, `data/journal/insights/<id>.tres` – `InsightData`)
**Eintragsarten:** *Totenzettel* (aus den CorpseRecords abgeleitet, nicht gespeichert: Name, Alter, Ursache, Tag, Grab, Funde, verlorene Funde, Herrichtung, Verwertung, gehörte Geisterzeile) · *Hinweise* (gespeichert) · *Erkenntnisse* (gespeichert) · *Ich* (Pietät-Stufe als Satz, hergerichtet/verwertet als Zahl).

**Hinweise (18):**
| id | Titel | Art | Quelle |
|---|---|---|---|
| `c_mark` | Das Dreistrich-Zeichen | Zeichen | erste `strange_wound` (Vorbote Tag 3) |
| `c_warning_letter` | Ein Warnbrief | Brief | erster `letter` (Tag 4) |
| `c_anchor_snake` | Anker und Schlange | Zeichen | erste `tattoo` (Tag 5) |
| `c_page_1` | Eine Seite aus einer Kladde | Seite | S1 |
| `c_ferry_jacket` | Die Fährmannsjoppe | Gegenstand | S2 |
| `c_elder_key` | Der Schlüssel mit dem Holunderblatt | Gegenstand | S2 oder Rückfall |
| `c_six_pits` | Sechs Gruben | Ort | Holunderwinkel freigelegt |
| `c_mark_healed` | Ein verheiltes Zeichen | Zeichen | S3 |
| `c_letter_late` | Ein Brief nach der Zeit | Brief | S3 |
| `c_oath_scar` | Die Schwurnarbe | Zeichen | S4 |
| `c_ferry_token` | Die Fährmarke | Gegenstand | S4 |
| `c_coat` | Lorenz' Mantel | Gegenstand | S5 |
| `c_buckle` | Die Schnalle „K. D." | Gegenstand | S5 |
| `c_soft_hands` | Hände ohne Schwielen | Zeichen | S5 |
| `c_page_list` | Die Liste der Sechs | Seite | S5 |
| `c_buyer_note_1…3` | Zettel des Abnehmers I–III | Zettel | Tür (Tag 4), 4. / 8. Ware |
Abnehmer-Zettel: I „Für Haar und Zähne der Toten zahlt einer gut, der keine Fragen stellt. Leg sie in den hohlen Stein an der Westmauer. Das Werkzeug liegt schon drin. – Ein Freund des Hauses" · II „Du arbeitest sauber. Der vor dir hat nie verkauft. Er hat alles behalten, bis zuletzt." (mit gepresster Holunderblüte) · III „Die mit dem Zeichen lass in Ruhe. Die gehören schon jemandem."

**Erkenntnisse (5 + 1 optional)** – Verknüpfen = genau die geforderte Menge (2–3 Hinweise, Reihenfolge egal):
| id | Titel (offene Frage vorher) | benötigt | Text | Flag |
|---|---|---|---|---|
| `i_warnings` | Wer die Warnbriefe schrieb („Wer warnt die Toten?") | `c_warning_letter`, `c_page_1` | „Dieselbe schräge Hand, dieselbe braune Tinte. Die Warnbriefe hat Lorenz Aschau geschrieben. Er wusste vorher, wen es trifft." | `insight_warnings` |
| `i_marked` | Gezeichnet („Wann wird das Zeichen geritzt?") | `c_mark`, `c_mark_healed`, `c_page_1` | „Das Zeichen wird Wochen vor dem Tod geritzt. Wer es trägt, ist ausgewählt – und jemand in Hollerbrück wählt aus." | `insight_marked` |
| `i_ferry` | Die Nachtfähre („Was verbindet die Tätowierten?") | `c_anchor_snake`, `c_ferry_jacket`, `c_ferry_token` | „Anker und Schlange: das Zeichen der alten Moorfährleute. Lorenz bezahlte Nachtfahrten über das Moor. Er wollte die Gezeichneten fortbringen. Nicht alle kamen an." | `insight_ferry` |
| `i_still_writing` | Die Hand schreibt weiter („Wer schreibt jetzt?") | `c_letter_late`, `c_page_1` | „Ein Warnbrief, drei Wochen nach Lorenz' Verschwinden geschrieben – in seiner Hand. Entweder schreibt ein Toter, oder Lorenz ist nicht tot." | `insight_still_writing` |
| `i_not_lorenz` | Nicht Lorenz („Wer liegt im Mantel?") | `c_soft_hands`, `c_buckle`, `c_page_list` | „Der Tote aus dem Moor trägt Lorenz' Mantel, aber Kaspar Dorns Hände. Dorn stand als Fünfter auf der Liste. Lorenz hat ihm den Mantel gegeben und sich für tot erklären lassen. Er lebt – irgendwo unter dem Hügel." | `insight_not_lorenz`, benennt S5 um |
| `i_elder_buyer` *(optional)* | Holunderblüten („Wer kauft am Hohlstein?") | `c_buyer_note_2`, `c_elder_key` | „Der Abnehmer siegelt mit gepresster Holunderblüte – dasselbe Blatt wie auf Lorenz' Schlüssel. Wer am Hohlstein kauft, kannte den alten Totengräber gut." | `insight_elder_buyer` |
- Die offene Frage einer Erkenntnis erscheint, sobald **ein** geforderter Hinweis gefunden ist (Seite „Hinweise", Spalte „Offene Fragen"). Ein Fehlversuch ist kostenlos: „Diese Hinweise erzählen noch keine gemeinsame Geschichte." Er wird nicht gezählt.
- Belohnung: Text, Flag (Osric-Dialoge), Zeile im Abschluss-Panel, Benachrichtigung „Erkenntnis: …". **Keine** Münzen und kein Ruf: Das Geheimnis ist Erzählung, kein Farmziel.
- Zielzeile „Merkbuch: Hinweise passen zusammen", sobald alle Hinweise einer Erkenntnis da sind, diese aber noch nicht verknüpft ist (einmal je Erkenntnis bis zum Verknüpfen).

### 2.13 Neue Items & Rezepte
`ItemData.Category` erhält **`GOODS` (5) am Ende** (Ware: nur im Inventar sichtbar, nicht in der HUD-Ressourcenleiste).
| id | Name | Kategorie | Stapel | Herkunft |
|---|---|---|---|---|
| `scrub_brush` | Wurzelbürste | TOOL | 1 | Werkbank: 2 wood, 15 Min (`category tool`) |
| `comb` | Holzkamm | TOOL | 1 | Werkbank: 1 wood, 10 Min (`tool`) |
| `burial_gown` | Totenhemd | CRAFTED | 5 | Werkbank: 3 linen, 30 Min (`grave`) |
| `juniper` | Wacholderzweige | RESOURCE | 10 | Osric, 2 Münzen |
| `shears` | Schere | TOOL | 1 | Hohlstein (einmalig) |
| `pliers` | Zange | TOOL | 1 | Hohlstein (einmalig) |
| `hair_braid` | Zopf | GOODS | 10 | Verwertung |
| `teeth_pouch` | Zahnsäckchen | GOODS | 10 | Verwertung |
Neues Spiel: Startinventar unverändert (die Werkzeuge baut man an Tag 1–2 aus 3 Holz).

### 2.14 Balancing-Übertrag aus Phase 3 (Entscheidung)
Gewählt wird **beides**: (a) Vernachlässigung kostet mehr, (b) „Ehrwürdig" bekommt eine ausdrückliche Bedingung.
- (a) `CleanlinessConfig.penalty_by_level` **[0, 0, 1, 2] → [0, 0, 1, 3]**. Eine verwilderte Stelle kostet 3 statt 2.
- (b) `CemeteryRating` Stufe `venerable` gilt nur, wenn **Friedhofsqualität ≥ 100 ∧ Zier ≥ 12 (`EconomyConfig.venerable_min_decor`) ∧ Pflegeabzug ≤ 6 (`venerable_max_dirt`)**. Sonst höchstens „Würdevoll". Das HUD und der Tooltip nennen, was fehlt: „Ehrwürdig: noch Zier 8/12" / „… Pflegeabzug 9 (höchstens 6)".
*Begründung:* Eine reine Schwellenanhebung hält nicht, weil Phase 4 mehr Gräber (18) und mehr Punkte je Grab (13) bringt. Ein „hoarder" käme dann über jede Zahl. Die Bedingung macht die Vorgabe des Benutzers wörtlich wahr und für den Spieler lesbar. (a) sorgt dafür, dass Vernachlässigung auch unterhalb von Ehrwürdig spürbar bleibt. Die Werte passen zu den Phase-3-Bot-Zahlen: diligent hat ab Tag 8 Zier 20 und Abzug 0 (✓ Ehrwürdig ab Tag ≤ 9). Hoarder hat Zier 0 (✗). Neglectful hat ab Tag 5 einen Abzug ≥ 13 (✗).
- **Bot-Erwartungen (W3, Pflicht):** `diligent` erreicht `rating() == &"venerable"` bis Tag 12. `neglectful` und `hoarder` erreichen an **keinem** der 14 Tage `&"venerable"` (Prüfung auf `CemeteryScore.rating()`, nicht auf die Zahl). `neglectful` erreicht weiterhin an mindestens einem Tag „Würdevoll" (Phase-3-Gate-Ziel). Hält das nicht, wird der Befund gemeldet. Die Werte ändert W3 nicht eigenmächtig. Die Qualitätsgrenze im Bot-Test wird von 0…150 auf 0…260 angehoben (18 Gräber × 13 + Zier 36).

### 2.15 Nachrechnung Münzen & Moral (je Leiche, Tag 10–20)
| | würdevoll („reverent") | verwertend („harvester") |
|---|---|---|
| Bezahlung | 3 + floor(12 × 0,5) = 6 + Ruf-Bonus 2 (Geschätzt) = **11** | Q = 9 (Tuch, Stein, frisch, untersucht) − 3 = 6 → 3 + 3 + 0 (Unauffällig) = **6** |
| Verwertung | – | Zopf 4 + Zähne 5 (+2 ab „Abgebrüht") + Wertsachen ≈ 2,3 = **≈ 13** |
| Ausgaben | Totenhemd 9 oder Tuch 6, Wacholder gelegentlich 2 | Tuch 6 |
| Netto je Leiche | ≈ +3 bis +5 | ≈ +13 |
| Täglich dazu | Pflegegeld 3–4, Geistergabe 2–3 je neuem Grab | Pflegegeld 0–1, keine Gaben ab „Hartherzig" |
| Ruf | steigt (Drift) | je Leiche −8 (−10,8 mit Wertsachen), Drift ≤ +6/Tag → pendelt um „Verrufen/Unauffällig" (15) |
| Lieferungen | täglich | bei „Verrufen" nur an ungeraden Tagen → Kapitelende ≈ 4–6 Tage später |
| Geister | meist zufrieden | unruhig, Grund „beraubt" |
Ergebnis: Verwerten bringt kurzfristig etwa das Doppelte, kostet aber Tempo, Pflegegeld, Gaben und Stimmung. Das ist spürbar, beide Wege bleiben spielbar. Der Münzüberschuss aus Phase 3 (58 am Ende, GP-03) sinkt beim würdevollen Weg durch Totenhemd und Wacholder.

---

## 3. Architektur

### 3.1 Neue Systemknoten (unter `WorldRoot/Systems`, alle vom Welt-Builder angelegt)
| Knoten | Klasse | Gruppen | save_id / save_order |
|---|---|---|---|
| `CorpseCare` | `CorpseCare` | `corpse_care` | – (Zustand steht im CorpseRecord) |
| `Piety` | `Piety` | `piety` | – (Wert in `GameState.stats.piety`) |
| `Journal` | `JournalManager` | `journal`, `saveable` | `journal` / **40** |
| `HollowStoneMarket` | `HollowStoneMarket` | `hollow_stone_market`, `saveable` | `hollow_stone` / **45** |
Bestehende bleiben, auch `CorpseManager` (0), `Expansion` (5), `Graveyard` (10). `StoryDirector` ist eine reine Regelklasse ohne Knoten; ihren Zustand speichert der CorpseManager. Keine neuen Autoloads.

### 3.2 Module & Besitz (Phase 4)
| Modul | Besitzt (Pfade) |
|---|---|
| **Lead** (W0 + laufend) | `project.godot` (Input `journal`), `src/core/*` (EventBus, Database), alle **Datenklassen ✦**, alle **Stubs** (nur bis zur Übergabe), `tests/run_tests.gd`, `tests/framework/*`, `tests/fixtures/*` (inkl. **`saves_v2/*`**, `phase4/*`), `docs/*`, `CLAUDE.md` |
| **P1 Leichen-Kern, Verfall & Geschichte** | `src/systems/corpse/{corpse_record,corpse_decay,corpse_manager,corpse_delivery_rules,corpse_save_codec,corpse_generator}.gd`, `src/systems/story/story_director.gd`, `src/systems/graveyard/{graveyard,grave_record}.gd`, `src/systems/expansion/expansion_manager.gd`, `data/corpses/corpse_tables.tres`, `data/story/*`, `data/config/story_config.tres`, `data/sections/elder.tres`, `data/clearables/{gate_small,elder_thicket,sunken_pit}.tres`, `tests/unit/{test_corpse,test_corpse_manager,test_story,test_expansion,test_graveyard}.gd` |
| **P2 Untersuchung & Herrichten** | `src/systems/corpse/{corpse_exam,corpse_prep,corpse_care}.gd`, `src/entities/morgue_table/*`, `src/systems/graveyard/grave_quality.gd`, `data/config/{exam_config,prep_config,economy_config,action_config}.tres`, `data/finds/*`, **alle neuen** `data/items/*` und `data/recipes/*` (§2.13), `tests/unit/{test_corpse_exam,test_corpse_prep,test_grave_quality}.gd`, Zähl-Anpassungen in `test_inventory.gd`/`test_crafting.gd` (Lead-genehmigt) |
| **P3 Pietät, Verwertung & Friedhofsstufe** | `src/systems/piety/{piety,piety_rules}.gd`, `src/systems/utilization/{utilization_rules,hollow_stone_market}.gd`, `src/entities/hollow_stone/*`, `src/systems/graveyard/{cemetery_rating,cemetery_score}.gd`, `src/systems/game_state/game_state.gd`, `data/config/{piety_config,utilization_config,reputation_config,cleanliness_config}.tres`, `tests/unit/{test_piety,test_utilization,test_cemetery_rating,test_cemetery_score,test_cleanliness,test_reputation,test_game_state}.gd` |
| **P4 Verfall-Darstellung & Geister** | `src/entities/corpse/*` (inkl. neu `corpse_decay_visual.gd`), `assets/shaders/decay_overlay.gdshader`, `assets/materials/{mat_decay_overlay,mat_vfx_fly,mat_vfx_wisp,mat_vfx_smoke}.tres`, `src/systems/ghosts/{ghost_mood,ghost_manager}.gd`, `src/entities/ghost/*` (nur falls nötig), `data/config/{ghost_config,decay_visual_config}.tres`, `data/ghosts/ghost_lines.tres`, `tests/unit/{test_ghosts,test_decay_visual}.gd` |
| **P5 Assets** | `tools/blender/{asset_props_phase4,asset_env_phase4,asset_corpses_phase4}.py`, `tools/blender/asset_items.py`, `tools/blender/build_all.py`, `tools/textures/paint_vfx.py` (neu, Pillow), `assets/models/**` (nur neue Phase-4-Dateien), `assets/vfx/*.png`, `art_source/blender/**` (Phase 4), `tests/unit/test_assets_phase4.gd`, `docs/reviews/phase4_assets/*` |
| **P6 Merkbuch, Dialog & Speichern** | `src/systems/journal/{journal_manager,journal_rules}.gd`, `data/journal/**`, `src/systems/save/{save_migration,save_file_io,save_manager}.gd`, `src/systems/dialogue/dialogue_conditions.gd`, `data/dialogue/carter.tres`, `tests/unit/{test_journal,test_save,test_save_migration,test_dialogue}.gd`, `tests/integration/test_phase3_save_upgrade.gd` (neu) |
| **W-Welt** (W2) | `data/world/graveyard_layout.json`, `src/world/graveyard/*` (Builder, neu `graveyard_build_phase4.gd`, `world_root.gd`, `graveyard_shots_phase4.gd`), `src/world/camera/camera_rig.gd` (nur Grenzen), `tools/blender/asset_ground_graveyard.py` (nur falls nötig), `tests/integration/{test_graveyard_world,test_phase4_loop}.gd`, `docs/reviews/phase4_round1/*` |
| **W-UI** (W2) | `src/ui/**`, `assets/ui/**`, `tools/ui/*` (neu: Merkbuch-Papier), `src/debug/*` (außer `asset_preview.gd`, `screenshot_capture.gd`), `tests/unit/{test_ui,test_objective,test_ui_phase3,test_ui_phase4}.gd`, `tests/integration/test_ui_flow.gd` |
| **W3 QA** | `tests/integration/{phase3_bot.gd,phase4_bot.gd,test_phase3_playthrough.gd,test_phase4_playthrough.gd,test_phase4_qa.gd,test_save_fuzzer.gd}`, `docs/reviews/phase4_wip/*` |
| **Eingefroren** | `src/world/art_prototype/*`, `src/entities/player/player_proto.*`, `data/art_prototype/*`, **`assets/shaders/painted.gdshader`, `painted_common.gdshaderinc`, `painted_foliage.gdshader`**, Presets `data/atmosphere/*`, `src/world/hut_interior/*` |

✦ **Datenklassen (W0, Lead, nur Felder + kleine reine Helfer):** `ExamConfig`, `FindData`, `PrepConfig`, `UtilizationConfig`, `PietyConfig`, `StoryCorpseData`, `StoryConfig`, `ClueData`, `InsightData`, `DecayVisualConfig`. Dazu Erweiterungen: `ItemData.Category.GOODS`, `SectionData` (+ `requires_flag`, `requires_flag_text`, `counts_for_cemetery`, `chapter`), `EconomyConfig` (+ §2.4/§2.14-Felder), `GhostConfig` (+ `robbed_mood`), `GhostLines` (+ `by_story`, `by_piety`), `ReputationConfig.event_points` (Defaults), `CleanlinessConfig.penalty_by_level`-Default.
Bei nur fünf Agents übernimmt P1 zusätzlich P6.

### 3.2.1 Klassen → Dateien
| Klasse | Datei | Art |
|---|---|---|
| `ExamConfig`, `FindData`, `PrepConfig` | `src/systems/corpse/{exam_config,find_data,prep_config}.gd` | ✦ |
| `CorpseExam`, `CorpsePrep`, `CorpseCare` | `src/systems/corpse/{corpse_exam,corpse_prep,corpse_care}.gd` | Stub (P2) |
| `StoryCorpseData`, `StoryConfig` | `src/systems/story/{story_corpse_data,story_config}.gd` | ✦ |
| `StoryDirector` | `src/systems/story/story_director.gd` | Stub (P1) |
| `PietyConfig` | `src/systems/piety/piety_config.gd` | ✦ |
| `PietyRules`, `Piety` | `src/systems/piety/{piety_rules,piety}.gd` | Stub (P3) |
| `UtilizationConfig` | `src/systems/utilization/utilization_config.gd` | ✦ |
| `UtilizationRules`, `HollowStoneMarket` | `src/systems/utilization/{utilization_rules,hollow_stone_market}.gd` | Stub (P3) |
| `HollowStone` | `src/entities/hollow_stone/hollow_stone.gd` + `.tscn` | Stub (P3) |
| `ClueData`, `InsightData` | `src/systems/journal/{clue_data,insight_data}.gd` | ✦ |
| `JournalRules`, `JournalManager` | `src/systems/journal/{journal_rules,journal_manager}.gd` | Stub (P6) |
| `DecayVisualConfig` | `src/entities/corpse/decay_visual_config.gd` | ✦ |
| `CorpseDecayVisual` | `src/entities/corpse/corpse_decay_visual.gd` | Stub (P4) |
| `JournalPanel`, `HollowStonePanel` | `src/ui/panels/{journal_panel,hollow_stone_panel}.gd` | W-UI |

### 3.3 EventBus – neue Signale (Ergänzung `src/core/event_bus.gd`)
```gdscript
# Untersuchung, Herrichten, Verwertung (CorpseCare)
signal exam_step_done(corpse_id: String, step: StringName, revealed: Array[StringName], lost: Array[StringName])
signal corpse_prepared(corpse_id: String, action: StringName)     # &"wash", &"dress", &"lay_out", &"balm"
signal corpse_harvested(corpse_id: String, kind: StringName, item_id: StringName)
# Geschichte (CorpseManager / StoryDirector)
signal story_corpse_arrived(story_id: StringName, corpse_id: String)
signal chapter_completed(chapter_id: StringName)                  # &"six_pits" (Graveyard)
# Pietät (Piety)
signal piety_changed(value: int, tier: StringName, delta: int, reason: String)
# Merkbuch (JournalManager)
signal clue_found(clue_id: StringName, corpse_id: String)
signal insight_unlocked(insight_id: StringName)
# Hohlstein (HollowStoneMarket)
signal hollow_stone_paid(coins: int, day: int)
```
- `corpse_updated` bleibt das Sammelsignal für jede Änderung am Record. Die neuen Signale kommen **zusätzlich** (für Benachrichtigungen, Merkbuch-Hinweis, Belohnungskarte).
- Regel wie Phase 3: **Listener ändern keinen Spielzustand.** Wer den Zustand ändert, ruft direkt auf (Gruppen-API): `CorpseCare` → `JournalManager.add_clue`, `Piety.event`, `Reputation.event`. `Graveyard.bury` → `Piety.event`. `ExpansionManager.unlock` → `JournalManager.add_clue(&"c_six_pits")`. `StoryDirector`-Rückfälle laufen bei `day_started` im CorpseManager (zeitgetrieben wie Lieferung und Verfall).

### 3.4 Logik-Klassen (Signaturen = Vertrag)

**Leichen-Kern, Verfall, Geschichte (P1)**
```gdscript
# CorpseRecord – Ergänzungen (alle in to_dict/from_dict; fehlende Felder = Default)
const STEP_CLOTHING := &"clothing"; const STEP_HANDS := &"hands"; const STEP_WOUNDS := &"wounds"; const STEP_POCKETS := &"pockets"
const STEPS: Array[StringName] = [STEP_CLOTHING, STEP_HANDS, STEP_WOUNDS, STEP_POCKETS]
const STAGE_ROTTEN := &"rotten"
const DRESS_NONE := &""; const DRESS_SHROUD := &"shroud"; const DRESS_GOWN := &"gown"
const HARVEST_HAIR := &"hair"; const HARVEST_TEETH := &"teeth"
var story_id: StringName = &""
var exam_done: Array[StringName] = []          # erledigte Schritte
var finds_revealed: Array[StringName] = []     # FindData-ids, Reihenfolge des Aufdeckens
var finds_lost: Array[StringName] = []
var traits_revealed: Array[StringName] = []    # Merkmale, deren Fund aufgedeckt wurde (CorpseCare setzt es)
var washed: bool = false
var dress: StringName = &""                    # setzt shrouded = (dress != &"") mit (Kompatibilität)
var laid_out: bool = false
var harvested: Array[StringName] = []
var balm_windows: PackedInt32Array = []        # [start, ende, start, ende …] in total_minutes
var stench_noted: bool = false                 # „Es riecht streng." schon gezeigt
func is_step_done(step: StringName) -> bool
func is_fully_examined() -> bool               # alle 4 Schritte
func is_dressed() -> bool
func is_fully_prepared() -> bool               # washed ∧ dress ≠ "" ∧ laid_out
func is_harvested(kind: StringName) -> bool
func revealed_traits() -> Array[StringName]    # NEU: traits_revealed (Phase-2-Pfad CorpseManager.examine ohne CorpseCare setzt traits_revealed = traits)
func needs_valuables_decision() -> bool        # NEU: STEP_POCKETS erledigt ∧ valuables ∧ unentschieden
static func stage_for(value: float, config: EconomyConfig) -> StringName   # + &"rotten" (< rot_threshold)

class_name CorpseDecay  # Ergänzung
static func effective_minutes(record: CorpseRecord, now_total: int, balm_factor: float) -> float
static func freshness_at(record: CorpseRecord, now_total: int, decay_per_hour: float, balm_factor: float = 0.25) -> float   # Räucherfenster eingerechnet
static func minutes_until(record: CorpseRecord, now_total: int, decay_per_hour: float, balm_factor: float, threshold: float) -> int   # −1 = schon darunter; für UI „noch ≈ 3 h"

# CorpseManager – Ergänzungen
func notify_changed(id: String) -> void        # corpse_updated für Änderungen durch CorpseCare
func story_delivered() -> PackedStringArray; func story_last_day() -> int
func deliver_story_now(story_id: StringName) -> CorpseRecord   # Debug; gleiche Regeln außer Tag
# _deliver: 1) StoryDirector.due_story → Record aus StoryDirector.make_record, story_corpse_arrived + Benachrichtigung arrival_note
#           2) sonst Zufallsleiche nur bei free_plots > unburied + StoryDirector.pending_count(...)
#           3) Gestank am Tor (§2.5) vor der Lieferung prüfen, einmal je Tag (stench_day)
# day_started: StoryDirector.daily_checks(day, has_elder_key, cfg) → Schlüssel-Rückfall (§2.11 Pkt. 4); den Tür-Zettel (Pkt. 5) macht HollowStoneMarket
# decide_valuables: + Piety.event(valuables_left/taken)
# examine(id) (Phase-2-API, Debug/Tests): delegiert an CorpseCare.exam_all_instant(id), falls vorhanden; sonst Phase-2-Verhalten
# apply_shroud(id, inv) (Phase-2-API): delegiert an CorpseCare.dress(id, &"shroud", inv), falls vorhanden
# Speichern: + "story_delivered": Array[String], "story_last_day": int, "stench_day": int

class_name CorpseDeliveryRules  # + static func is_cemetery_full(graveyard: Node, unburied: int, reserved: int = 0) -> bool
class_name StoryCorpseData extends Resource       # ✦ data/story/<id>.tres (§2.11)
@export var id: StringName; @export var order: int; @export var earliest_day: int
@export var display_name: String; @export var age: int; @export var cause_id: StringName
@export var traits: Array[StringName] = []; @export var valuables_coins: int = 0
@export var look: int = -1                          # Corpse-Look-Index (−1 = aus Name/Alter wie bisher)
@export var finds: Array[StringName] = []           # FindData-ids (story_only)
@export_multiline var arrival_note: String; @export var is_finale: bool = false
class_name StoryConfig extends Resource             # ✦ data/config/story_config.tres
@export var min_gap_days: int = 2; @export var key_fallback_day: int = 12; @export var hollow_note_day: int = 4
@export var key_flag: StringName = &"has_elder_key"; @export var key_clue: StringName = &"c_elder_key"
@export var chapter_section: StringName = &"elder"; @export var finale_story: StringName = &"s5_moor"
@export_multiline var key_fallback_text: String; @export var reserve_note: String = "Heute nichts. Aber halt eine Grube frei."
class_name StoryDirector extends RefCounted
static func due_story(day: int, delivered: PackedStringArray, last_story_day: int, stories: Array[StoryCorpseData], cfg: StoryConfig) -> StoryCorpseData   # null = keine
static func pending_count(delivered: PackedStringArray, stories: Array[StoryCorpseData]) -> int
static func make_record(story: StoryCorpseData, seed: int) -> CorpseRecord   # Name/Alter/Ursache/Merkmale/story_id aus Daten, freshness 1
static func daily_checks(day: int, has_key: bool, cfg: StoryConfig) -> Array[StringName]    # heute fällige Rückfälle: &"elder_key" (ab key_fallback_day ohne Schlüssel)

# SectionData ✦ + @export var requires_flag: StringName = &""; @export var requires_flag_text: String = ""
#                + @export var counts_for_cemetery: bool = true; @export var chapter: StringName = &""   (elder: false / &"six_pits")
# EconomyConfig ✦ + quality_washed 1, quality_laid_out 1, dress_quality {shroud: 2, gown: 3}, rot_threshold 0.1, rot_malus −2,
#                  harvest_malus {hair: −1, teeth: −2}, venerable_min_decor 12, venerable_max_dirt 6; quality_max 13 (Default + .tres)
# ItemData ✦ enum Category { RESOURCE, CRAFTED, CURRENCY, DECOR, TOOL, GOODS }
# Graveyard – Änderungen
# bury: + Piety.event(&"bare_burial") ohne Kleidung, + &"rotten_burial" bei Stufe rotten
# _check_cemetery_complete: nur Abschnitte mit counts_for_cemetery (LOCKED-Plots anderer Abschnitte zählen nicht)
# + _check_chapter(): Abschnitte mit chapter ≠ "": alle Plots MARKED ∧ (Kapitel six_pits) Finale-Leiche (StoryConfig.finale_story) bestattet
#   → Flag six_pits_complete, chapter_completed, ui_panel_requested(&"slice_summary", {variant: &"six_pits", …})
func plots_counting_for_cemetery() -> PackedStringArray
# GraveRecord unverändert. ExpansionManager: block_reason prüft zusätzlich SectionData.requires_flag (Text requires_flag_text); unlock ruft JournalManager.add_clue, wenn SectionData.chapter == &"six_pits"
```

**Untersuchung & Herrichten (P2)**
```gdscript
class_name ExamConfig extends Resource              # ✦ data/config/exam_config.tres
@export var steps: Array[Dictionary] = []           # [{id: &"clothing", label: "Kleidung", verb: "Kleidung durchsehen", minutes: 10}, …] (§2.1)
@export var locked_by_dress: Array[StringName] = [&"clothing", &"pockets"]
@export var nothing_text: String = "Nichts Auffälliges."
@export var trait_steps: Dictionary[StringName, StringName] = {&"valuables": &"pockets", &"letter": &"pockets", &"tattoo": &"hands", &"strange_wound": &"wounds"}
class_name FindData extends Resource                # ✦ data/finds/<id>.tres
@export var id: StringName; @export var step: StringName; @export var label: String
@export_multiline var text: String                  # "" = reveal_text des Merkmals aus CorpseTables
@export_multiline var lost_text: String
@export var min_freshness: float = 0.0
@export var trait_id: StringName = &""              # generischer Fund des Merkmals / Geschichts-Fund ersetzt ihn
@export var cause_id: StringName = &""              # generisches Ursachen-Detail
@export var story_only: bool = false
@export var clue_id: StringName = &""
@export var sets_flag: StringName = &""
class_name PrepConfig extends Resource              # ✦ §2.3
@export var wash_minutes: int = 15; @export var wash_tool: StringName = &"scrub_brush"
@export var dress: Dictionary[StringName, Dictionary] = {&"shroud": {"item": &"shroud", "minutes": 10}, &"gown": {"item": &"burial_gown", "minutes": 15}}
@export var lay_out_minutes: int = 10; @export var lay_out_tool: StringName = &"comb"
@export var balm_item: StringName = &"juniper"; @export var balm_minutes: int = 10
@export var balm_factor: float = 0.25; @export var balm_window_minutes: int = 1080; @export var balm_max_windows: int = 4

class_name CorpseExam extends RefCounted           # rein, ohne Szenenbaum testbar
static func candidates(record: CorpseRecord, step: StringName, finds: Array[FindData], story: StoryCorpseData, cfg: ExamConfig) -> Array[FindData]
#   generisch nach trait_id (Merkmal vorhanden, Schritt = trait_steps) und cause_id; Geschichts-Funde aus story.finds; Geschichts-Fund mit trait_id ersetzt generischen
static func resolve(record: CorpseRecord, candidates: Array[FindData]) -> Dictionary     # {revealed: Array[StringName], lost: Array[StringName]} nach record.freshness
static func block_reason(record: CorpseRecord, step: StringName, cfg: ExamConfig) -> String   # "" | „Schon untersucht." | „Nach dem Einkleiden nicht mehr zugänglich."
static func open_steps(record: CorpseRecord, cfg: ExamConfig) -> Array[StringName]
static func minutes_for(steps: Array[StringName], cfg: ExamConfig) -> int
static func next_loss(record: CorpseRecord, pending: Array[FindData], now_total: int, decay_per_hour: float, balm_factor: float) -> Dictionary   # {minutes, stage_label} | {}
class_name CorpsePrep extends RefCounted
static func block_reason(record: CorpseRecord, action: StringName, inv: Inventory, cfg: PrepConfig, kind: StringName = &"") -> String
#   action: &"wash" (Werkzeug, nicht eingekleidet, nicht gewaschen) · &"dress" (kind shroud/gown, Item, Wertsachen entschieden, nicht eingekleidet)
#   · &"lay_out" (Werkzeug, nicht aufgebahrt) · &"balm" (Item, kein laufendes Fenster, < max_windows)
static func minutes(action: StringName, cfg: PrepConfig, kind: StringName = &"") -> int
static func is_balm_active(record: CorpseRecord, now_total: int) -> bool
class_name CorpseCare extends Node                  # Systems/CorpseCare, Gruppe &"corpse_care"
func step_block_reason(id: String, step: StringName) -> String
func exam_step(id: String, step: StringName) -> Dictionary        # löst auf, setzt examined, Flags (sets_flag), Hinweise (JournalManager.add_clue), exam_step_done, notify_changed
func exam_all(id: String) -> Dictionary                           # alle offenen Schritte (Aufruf nach der Sammel-TimedAction)
func exam_all_instant(id: String) -> Dictionary                   # Debug/Phase-2-API: wie exam_all, ohne Zeit
func prep_block_reason(id: String, action: StringName, inv: Inventory, kind: StringName = &"") -> String
func wash(id: String, inv: Inventory) -> bool
func dress(id: String, kind: StringName, inv: Inventory) -> bool  # entnimmt 1 Item; setzt shrouded
func lay_out(id: String, inv: Inventory) -> bool
func apply_balm(id: String, inv: Inventory) -> bool               # Fenster [jetzt, jetzt + balm_window_minutes]
func harvest_block_reason(id: String, kind: StringName, inv: Inventory) -> String   # über UtilizationRules.block_reason
func harvest(id: String, kind: StringName, inv: Inventory) -> bool   # Item ins Inventar (voll → abgelehnt), Piety.event, Reputation.event, stats.utilized, Flag piety_used_day, corpse_harvested
func next_loss(id: String) -> Dictionary                          # für UI-Hinweis
# jede erfolgreiche Herrichtung: corpse_prepared; der 3. Bestandteil → Piety.event(&"full_prep"), stats.prepared +1
# GraveQuality.breakdown – neue Zeilen §2.4 (Labels "Gewaschen", "Totenhemd", "Aufgebahrt", "Verfallen", "Haar genommen", "Zähne genommen")
# MorgueTable – Panel-Aufrufe: request_exam_step(step), request_exam_all(), request_wash(), request_dress(kind), request_lay_out(),
#   request_balm(), request_harvest(kind); request_examine() = request_exam_step(&"clothing") (Kompatibilität), request_shroud() = request_dress(&"shroud")
#   Prompt: „[E] Leiche untersuchen" (0 Schritte) / „[E] Leiche ansehen" (sonst) – unverändert
```

**Pietät, Verwertung, Friedhofsstufe (P3)**
```gdscript
class_name PietyConfig extends Resource             # ✦ §2.7
@export var min_value: int = -100; @export var max_value: int = 100; @export var start_value: int = 0
@export var tier_thresholds: PackedInt32Array = [-59, -19, 20, 60]
@export var events: Dictionary[StringName, int] = {&"valuables_left": 3, &"valuables_taken": -6, &"hair_taken": -4, &"teeth_taken": -6, &"full_prep": 3, &"bare_burial": -2, &"rotten_burial": -2}
@export var daily_recovery: int = 1
@export var gift_by_tier: PackedInt32Array = [0, 2, 2, 2, 3]
@export var buyer_bonus_by_tier: PackedInt32Array = [1, 1, 0, 0, 0]
@export var affinity_threshold: int = 20
class_name PietyRules extends RefCounted
const TIERS: Array[StringName] = [&"hardhearted", &"callous", &"matter_of_fact", &"considerate", &"devout"]
const LABELS := {"hardhearted": "Hartherzig", "callous": "Abgebrüht", "matter_of_fact": "Sachlich", "considerate": "Rücksichtsvoll", "devout": "Andächtig"}
static func tier(value: int, cfg: PietyConfig) -> StringName; static func tier_index(t: StringName) -> int; static func label(t: StringName) -> String
static func self_image(t: StringName) -> String      # Satz fürs Merkbuch (§2.7)
static func recovery(value: int, used_yesterday: bool, cfg: PietyConfig) -> int
static func affinity(value: int, cfg: PietyConfig) -> StringName   # Haken Phase 13+
class_name Piety extends Node                        # Systems/Piety, Gruppe &"piety"
func value() -> int; func tier() -> StringName
func change(delta: int, reason: String) -> void      # klemmt, GameState.stats.piety, piety_changed; Stufenwechsel → leise Benachrichtigung
func event(kind: StringName, reason: String) -> void
func apply_daily(day: int) -> int                    # idempotent (Flag piety_last_day)
func gift_coins() -> int; func buyer_bonus() -> int
class_name UtilizationConfig extends Resource        # ✦ §2.6
@export var kinds: Dictionary[StringName, Dictionary] = {}   # {hair: {label, verb, minutes, tool, item, min_freshness, reputation_event, piety_event, done_text}, teeth: {…}}
@export var sell_prices: Dictionary[StringName, int] = {&"hair_braid": 4, &"teeth_pouch": 5}
@export var payout_minute: int = 360
@export var note_thresholds: PackedInt32Array = [0, 4, 8]
@export var tool_items: Array[StringName] = [&"shears", &"pliers"]
class_name UtilizationRules extends RefCounted
static func block_reason(record: CorpseRecord, kind: StringName, inv: Inventory, cfg: UtilizationConfig, known: bool) -> String   # "" = möglich; "-" = Knopf unsichtbar (nicht bekannt)
static func sale_value(items: Dictionary, bonus_per_item: int, cfg: UtilizationConfig) -> int
class_name HollowStoneMarket extends Node            # Systems/HollowStoneMarket
func is_known() -> bool
func deposit(item_id: StringName, amount: int, inv: Inventory) -> int     # eingelegt; nur sell_prices-Items
func deposited() -> Dictionary; func pending_coins() -> int
func collect(inv: Inventory) -> int                  # Münzen + beim ersten Mal Werkzeug (tools_given)
func apply_morning(day: int) -> int                  # idempotent (last_payout_day): Tür-Zettel ab hollow_note_day (hollow_known, c_buyer_note_1), Wert berechnen, Ablage leeren, Zettel 2/3 nach sales (JournalManager.add_clue), hollow_stone_paid
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void
class_name HollowStone extends Node3D               # Interactable Priorität 7; „[E] Hohlstein öffnen" → Panel &"hollow_stone"; unbekannt: kein Prompt
# CemeteryRating: + static func rating_gated(total: int, decor: int, dirt_penalty: int, config: EconomyConfig) -> StringName
#                 + static func venerable_missing(decor: int, dirt_penalty: int, config: EconomyConfig) -> PackedStringArray
# CemeteryScore.rating() nutzt rating_gated; breakdown() + {venerable_missing: PackedStringArray}
# GameState.DEFAULT_STATS + &"piety", &"utilized", &"prepared"
```

**Verfall-Darstellung & Geister (P4)**
```gdscript
class_name DecayVisualConfig extends Resource       # ✦ data/config/decay_visual_config.tres
@export var overlay_by_stage: Dictionary[StringName, float] = {&"fresh": 0.0, &"wilted": 0.35, &"decaying": 0.7, &"rotten": 1.0}   # stetig über die Frische interpoliert
@export var washed_reduction: float = 0.15
@export var flies_by_stage: Dictionary[StringName, int] = {&"fresh": 0, &"wilted": 4, &"decaying": 8, &"rotten": 10}
@export var wisps_by_stage: Dictionary[StringName, int] = {&"fresh": 0, &"wilted": 0, &"decaying": 3, &"rotten": 5}
@export var smoke_particles: int = 3
@export var stain_color: Color = Color("8E9A7E"); @export var wisp_color: Color = Color(0.66, 0.65, 0.48, 0.3); @export var smoke_color: Color = Color(0.72, 0.70, 0.66, 0.3)
@export var visibility_range: float = 22.0; @export var max_emitting: int = 3
class_name CorpseDecayVisual extends Node3D        # Kind "DecayVisual" in corpse.tscn: Overlay-Material je MeshInstance, CPUParticles3D Flies/Wisps/Smoke
func apply(freshness: float, stage: StringName, balm_active: bool, washed: bool) -> void
func overlay_amount() -> float; func flies() -> int; func wisps() -> int; func smoke_on() -> bool
# Corpse (P4): refresh() liest dress (none/shroud/gown-Modell), laid_out (Zweig + Kerzenstumpf ohne Licht), Look aus StoryCorpseData.look (≥ 0);
#   aktualisiert DecayVisual bei corpse_updated und hour_changed (reine Darstellung)
# GhostMood: static func score(quality, dirt_level, decor_bonus, clean, cfg, robbed: int = 0) -> int
#            static func main_reason(grave, corpse, dirt_level, decor_bonus, economy) -> StringName   # + &"robbed", &"unkempt" (§2.9)
#            static func pick_line(lines, mood, reason, traits, seed, story_id: StringName = &"", piety_tier: StringName = &"") -> String
# GhostManager: Gabe = Piety.gift_coins() (0 = keine Gabe, Zeile „Die Geister deuten nicht mehr ins Moos." einmal je Nacht)
# GhostConfig: + @export var robbed_mood: int = -5
# GhostLines: + @export var by_story: Dictionary[StringName, PackedStringArray]; + @export var by_piety: Dictionary[StringName, PackedStringArray]
```

**Merkbuch, Dialog, Speichern (P6)**
```gdscript
class_name ClueData extends Resource                # ✦ data/journal/clues/<id>.tres
@export var id: StringName; @export var title: String; @export_multiline var text: String
@export var kind: StringName                         # &"mark", &"letter", &"page", &"object", &"place", &"note"
@export var order: int
class_name InsightData extends Resource             # ✦ data/journal/insights/<id>.tres
@export var id: StringName; @export var order: int; @export var title: String; @export var question: String
@export_multiline var text: String; @export var requires: Array[StringName] = []   # 2–3
@export var sets_flag: StringName; @export var optional: bool = false
@export var rename_story: StringName = &""; @export var rename_to: String = ""
class_name JournalRules extends RefCounted
static func match_insight(selected: Array[StringName], insights: Array[InsightData], unlocked: Dictionary) -> StringName   # exakte Menge; &"" = passt nicht
static func open_questions(found: Dictionary, insights: Array[InsightData], unlocked: Dictionary) -> Array[InsightData]
static func ready_insights(found: Dictionary, insights: Array[InsightData], unlocked: Dictionary) -> Array[InsightData]   # alles da, nicht verknüpft (Zielzeile)
class_name JournalManager extends Node              # Systems/Journal
func has_clue(id: StringName) -> bool
func add_clue(id: StringName, corpse_id: String = "", silent: bool = false) -> bool   # false = schon da (dann nur Zähler); clue_found; Benachrichtigung „Ins Merkbuch: <Titel>"
func clue_count(id: StringName) -> int              # wie viele Tote den generischen Hinweis tragen
func clues() -> Array[StringName]
func try_link(ids: Array[StringName]) -> StringName # insight_unlocked, Flag, ggf. Umbenennung über CorpseManager; &"" ohne Folgen
func insights() -> Array[StringName]; func has_insight(id: StringName) -> bool
func people() -> Array[Dictionary]                  # abgeleitet: {corpse_id, name, age, cause, day, grave_id, story_id, finds, lost, washed, dress, laid_out, harvested, heard}
func unread() -> Array[StringName]; func mark_read(ids: Array[StringName]) -> void
func sync_from_records() -> int                     # still: Hinweise aus finds_revealed aller Records (Migration, Laden)
func save_state() -> Dictionary; func load_state(data: Dictionary) -> void; func post_load() -> void   # post_load → sync_from_records
class_name SaveMigration  # CURRENT := 3; migrate: Kette 1→2→3; + static func migrate_2_to_3(state: Dictionary, meta: Dictionary) -> Dictionary
# SaveFileIO.FORMAT_VERSION = 3; read_doc akzeptiert 1…3
# DialogueConditions: stat_gte/stat_lt mit negativen Zahlen (Pietät) – Test; keine neue Syntax nötig
```

### 3.5 Database (Lead)
Neue Ordner → Schlüssel: `data/finds` (`id`), `data/story` (`id`), `data/journal/clues` (`id`), `data/journal/insights` (`id`). Neue Funktionen: `find(id)`, `finds()`, `story_corpse(id)`, `story_corpses()` (nach `order`), `clue(id)`, `clues()` (nach `order`), `insight(id)`, `insights()` (nach `order`). Configs über `config(&"exam_config")` usw. wie bisher.

### 3.6 Eingaben (Lead, `project.godot`)
| Aktion | Taste | Wirkung |
|---|---|---|
| `journal` | J | Merkbuch auf/zu (draußen und in der Hütte; nicht im Baumodus, nicht im Dialog) |
Im Merkbuch: Seiten über Reiter oder `[`/`]`, Hinweise per Mausklick wählen (höchstens 3), „Verknüpfen" per Knopf. Esc schließt.

---

## 4. Welt (W-Welt)

### 4.1 Holunderwinkel
- Rechteck `elder`: x −11,5…−2,0 · z −20,0…−12,5 (hinter der Hütte, bisher `extra_walls`-Sperre). Der Boden reicht bereits (56 × 64 m). Kein Neubau des Bodens, außer die Kante ist sichtbar.
- Grabstellen (rot_y 0): `h_01` (−9,4, −18,0) · `h_02` (−6,9, −18,0) · `h_03` (−4,4, −18,0) · `h_04` (−9,4, −14,6) · `h_05` (−6,9, −14,6) · `h_06` (−4,4, −14,6). Kommt der Reihenabstand (3,4 m) mit den Grab-Footprints in Konflikt, darf W-Welt um ±0,4 m schieben und meldet das.
- Zugang: **Pförtchen** `obs_h_gate` in der bisherigen Sperrlinie z = −12,5 bei x ≈ −10,0. Es ist vom Alten Hof aus westlich an der Hütte vorbei erreichbar (Korridor x −11,5…−8,1). Das `extra_walls`-Segment [[−11,2, −12,5], [−2,0, −12,5]] wird durch Zaun + Pförtchen ersetzt. Solange das Tor zu ist, bleibt es Kollision.
- Hindernisse: `obs_h_thicket_1/2` (Holunderdickicht, im Zugangsweg und an der Westmauer), `obs_h_pit_1…6` (je über `h_01…06`, Footprint = Grabplatz), Zaunlücke `obs_h_gap_1` (−7,0, −20,0) im neuen Nordzaun z = −20 (x −11,5…−2,0). Die Ostseite ist der bestehende Westzaun des Birkenhangs.
- Pflegestellen: `dirt_h01…03` (Fläche; `dirt_h02`, `dirt_h03` = Laub unter den Holundern) + Grabstellen `dirt_h_01…06` (vom Builder). Gesamt 43.
- 3 große Holundersträucher (`ph_env_elder_bush`) als Identität, einer über dem Pförtchen.
- `camera_bounds.min` → [−10,0, −17,5]. `walkable_bounds` unverändert. `waypoints` + `tp_elder`.
### 4.2 Weitere Platzierungen
- **Hohlstein** `hollow_stone` an der Westmauer (−11,0, −2,6), rot_y 90, Interactable-Punkt nach innen, nicht auf dem Weg. Er ist ab Tag 1 sichtbar, aber bis `hollow_known` ohne Prompt.
- **Waschschüssel** (`ph_prop_wash_basin` auf Holzbock) 1,1 m links vom Leichentisch, **Räucherschale** (`ph_prop_smoke_bowl`) auf der Tischkante: nur Requisiten. Die Rauchpartikel gehören zur Leiche (P4).
- Die Bau-Maske wird mit dem Abschnitt `elder` (Index 4) neu gebacken. Hohlstein + 0,6 m gesperrt, Pförtchen = `ROUTE`.
### 4.3 Layout-Schema-Ergänzungen
`sections[]` + `elder` · `plots[]` + `h_01…06` (`section: "elder"`) · `clearables[]` + Pförtchen, Dickicht, Gruben, Lücke · `entities[]` + `hollow_stone`, Requisiten `wash_basin`, `smoke_bowl` · `elder_bushes[]` · `extra_walls` (Segment ersetzt). Neue Systemknoten §3.1 legt `graveyard_build_phase4.gd` an.

---

## 5. Speichern & Migration (P6)

### 5.1 Format v3 (Ergänzungen)
```
format_version: 3
data.autoloads.GameState.stats   + piety:int (−100…100), utilized:int, prepared:int
data.autoloads.GameState.flags   + p4_intro, hollow_known, has_elder_key, piety_last_day:int, piety_used_day:int,
                                   six_pits_complete, insight_<id>, remark_piety_<tier>
data.nodes.corpse_manager.corpses[] + story_id, exam_done[], finds_revealed[], finds_lost[], traits_revealed[], washed, dress, laid_out,
                                   harvested[], balm_windows[], stench_noted
data.nodes.corpse_manager        + story_delivered: ["s1_quendel", …], story_last_day:int, stench_day:int
data.nodes.journal               {"clues": {"c_mark": {"day": 3, "corpse": "corpse_0003", "count": 2}}, "insights": {"i_warnings": 7}, "unread": ["c_page_1"]}
data.nodes.hollow_stone          {"deposit": {"hair_braid": 1}, "pending": 9, "tools_given": true, "sales": 3, "notes": 1, "last_payout_day": 8}
data.nodes.graveyard             Plots h_01…06 (v2: fehlen → Graveyard legt sie LOCKED an)
```
Nicht gespeichert: CorpseCare, Pietät-Stufe (abgeleitet), Totenzettel (abgeleitet), offene Fragen, Verfall-Effekte, Merkbuch-Auswahl.

### 5.2 Migration v2 → v3 (Phase-3-Spielstände müssen laden)
`SaveMigration.migrate_2_to_3` läuft in `read_doc` nach `decode_state` (Kette 1→2→3). Rein, auf einer tiefen Kopie.
1. `stats.piety = clampi(−6 × stats.valuables_taken + 3 × (#Records mit valuables_decision == left), −100, 100)`, `utilized = 0`, `prepared = 0`.
2. Jeder Record: `dress = "shroud"` wenn `shrouded`, sonst `""`. War er `examined`, dann `exam_done = alle 4`, `traits_revealed = traits` und `finds_revealed =` generische Funde seiner Merkmale **+ Ursachen-Detail** (Phase 2/3 hat alles auf einmal gezeigt; kein nachträglicher Verlust). Sonst leer. Übrige neue Felder Default. `story_id = ""`.
3. `corpse_manager`: `story_delivered = []`, `story_last_day = 0`, `stench_day = meta.day` (kein Gestank-Abzug am Ladetag).
4. `nodes.journal = {}` → `JournalManager.post_load` legt die Hinweise still aus den Records an (`sync_from_records`): Wer in Phase 3 ein Zeichen oder einen Brief gesehen hat, hat sie im Merkbuch.
5. `nodes.hollow_stone = {}`. Flags: `piety_last_day = meta.day`. `hollow_known` bleibt unset: Liegt `meta.day ≥ 4`, kommt der Zettel beim nächsten `day_started`.
6. Gräber unverändert: gespeicherte Qualität (≤ 10) bleibt, keine Neuberechnung. `h_01…06` fehlen → `LOCKED`.
7. Spieler, Zeit, Inventar, Truhe, Zier, Pflege, Geister: unverändert. **Hinweis:** Die neue Abzugstabelle (§2.14) gilt beim Laden sofort. Ein vernachlässigter Phase-3-Stand kann dadurch einige Punkte verlieren. Die Tageszusammenfassung erklärt es einmalig („Die Gemeinde sieht verwilderte Gräber jetzt strenger.").
**Fixtures (W0, Lead, vor jeder Code-Änderung mit Build `febd2c7` erzeugt, über `Phase3Bot` + echte Systeme):** `tests/fixtures/saves_v2/`
- `slot_p3_day5_table.json`: Tag 5, 09:00, Ostwiese frei, Leiche untersucht auf dem Tisch, Wertsachen-Entscheidung **offen**, Merkmal `tattoo`, Zier aufgestellt.
- `slot_p3_day9_night.json`: Tag 9, 23:30, Geister aktiv, unberührte Leiche auf der Bahre (verfällt über Nacht), 1 Grab mit genommenen Wertsachen.
- `slot_p3_day14_complete.json`: `cemetery_complete`, 12 Gräber, Wertsachen 2× genommen, `strange_wound`/`letter`/`tattoo` bestattet, Geister gehört, Gaben gegeben.
- `slot_p3_interior.json`: Tag 3, 19:30, Spieler in der Hütte, Truhe gefüllt, getragene Leiche **nicht** möglich → Leiche am Boden vor dem Tisch.
Dazu `make_v2_saves.gd` + `_driver.gd` (historisches Werkzeug, wie Phase 3). Lade-Wächter: `tests/integration/test_saves_v2_load.gd` (Lead). v1-Fixtures laden weiterhin (Kette 1→3).

---

## 6. Debug-Konsole (W-UI) – neue Befehle
`corpse fresh <0-1>` (Frische der Tisch-Leiche) · `corpse stage <fresh|wilted|decaying|rotten>` · `exam all` (ohne Zeit) · `prep all` · `harvest <hair|teeth>` · `piety <-100..100>` · `clue <id|all>` · `insight <id>` · `story <id|next>` (sofort liefern, gleiche Platzregeln) · `story list` · `hollow known` · `hollow pay` · `unlock elder` · `tp <elder|hollow>` · `decay row` (4 Leichen in den 4 Stufen am Tisch/Boden – Screenshot p4_02) · `quality` zeigt zusätzlich die Ehrwürdig-Bedingung.

## 7. UI (W-UI)
- **Untersuchungs-Panel (erweitert, bestehendes `corpse_exam`):** Kopf und rechte Fundspalte bleiben. Die linke Spalte bekommt drei **Reiter**: *Untersuchen* · *Herrichten* · *Verwerten*. Der dritte Reiter erscheint erst mit `hollow_known`, als gedämpfter Reiter ohne Signalfarbe.
  - *Untersuchen:* 4 Schritt-Knöpfe in einer Reihe („Kleidung · 10 Min", „✓", gesperrt mit Grund), darunter „Gründlich untersuchen (35 Min)". Zustand mit Frische-Balken und 4 Stufenstrichen. Darunter die Verlust-Vorhersage: „Hautzeichen noch ≈ 3 Std. lesbar" (`CorpseCare.next_loss`). Wertsachen-Entscheidung wie bisher, sobald `pockets` erledigt ist.
  - *Herrichten:* 3 Zeilen mit Folgen: „Waschen · 15 Min · Grabqualität +1" (ohne Bürste: „Wurzelbürste nötig – Werkbank"), Einkleiden mit Auswahl Leichentuch/Totenhemd und der Warnzeile zum Einkleiden, Aufbahren. Dazu „Mit Wacholder räuchern · 10 Min" (zeigt das laufende Fenster „geräuchert bis 04:10").
  - *Verwerten:* Haar/Zähne als `DangerButton`, Folgenzeile („+1 Zopf (4 Münzen am Hohlstein) · Grabqualität −1 · Ruf −3 · Der Geist wird es wissen."). **Zweistufig:** Der erste Klick macht daraus „Wirklich? Noch einmal klicken". Nach 3 s fällt der Knopf zurück. Kein Fokus per Standard (wie die Wertsachen-Knöpfe).
  - *Fundkarten* (rechte Spalte): nach Schritt gruppiert. Karten mit Hinweis tragen einen Tintenstempel „→ Merkbuch". Verlorene Karten sind gedimmt mit `lost_text` und kleinem Welkblatt-Symbol. „Nichts Auffälliges." als schmale Zeile.
- **Merkbuch-Panel** `&"journal"` (J), Pergament-Doppelseite (`ph_ui_journal_*`), 4 Reiter:
  - *Die Toten:* Liste (neueste oben), rechts der Totenzettel. S5 zeigt vor der Erkenntnis „Lorenz Aschau (?)".
  - *Hinweise:* Kartenraster, Klick wählt aus (höchstens 3, gezeichneter roter Faden zwischen den gewählten), Knopf „Verknüpfen". Rechts die Spalte „Offene Fragen".
  - *Erkenntnisse:* Tagebuchseiten in Reihenfolge.
  - *Ich:* Pietät-Satz (ohne Zahl), „Hergerichtet: 9 · Verwertet: 2".
  Kontext `{page: StringName}`. Ungelesenes trägt einen Punkt.
- **HUD:** kleines Buch-Symbol neben dem Tagessymbol mit Zähler ungelesener Einträge („[J] Merkbuch · 2 neu"). **Keine Pietät-Anzeige.** *Begründung:* Der Ruf ist öffentlich und steht deshalb im HUD. Die Pietät ist ein innerer Wert. Die Welt soll sie spiegeln (Geister, Osric, Hohlstein), statt dass ein Balken zum Optimieren einlädt. Sichtbar ist sie im Merkbuch als Satz und bei Stufenwechseln als leise Notiz. Das passt zu „sanft".
- **Hohlstein-Panel** `&"hollow_stone"`: Waren im Inventar mit Preis, „Hineinlegen" (einzeln/alle), Liste der eingelegten Waren, „Morgen früh liegt hier Geld." Bei `pending > 0` der Knopf „Münzen nehmen (9)". Beim ersten Öffnen: „Im Stein liegen eine Schere und eine Zange, in Sackleinen gewickelt."
- **Belohnungskarte:** neue Qualitätszeilen (§2.4). Keine Pietät-Zahl.
- **Tageszusammenfassung:** + Hohlstein-Auszahlung, neue Hinweise/Erkenntnisse, Leichen mit verlorenen Funden („Bei Jost Hemmerling kamst du zu spät für die Tätowierung.").
- **Zielzeile** (`ObjectiveResolver`, nach der Leichen-Kette, vor Phase-3-Zielen): Leiche auf dem Tisch und `next_loss ≤ 120 Min` → „Spuren verblassen – untersuchen oder räuchern" · Holunderwinkel aufschließen (Schlüssel da, ≤ 1 freie Stelle) · „Merkbuch: Hinweise passen zusammen" · „Eine Grube wartet noch" (Reservierung aktiv).
- **Friedhofsübersicht / Qualitäts-Tooltip:** Ehrwürdig-Bedingung mit fehlenden Teilen. Holunderwinkel als 4. Abschnitt.
- **Abschluss-Panel** Variante `&"six_pits"` (§1.3), Schlusszeile nach Pietät-Stufe und Erkenntnis *Nicht Lorenz*.

## 8. Assets (P5, Stil gesperrt, alle `ph_`, `lib_painted.py` / geteilte Materialien)
| Asset | Zweck | Dreiecke | Hinweise |
|---|---|---|---|
| `ph_prop_corpse_05` | Mann im langen, geflickten Mantel (S5) | ≤ 4 000 | gleiche Grundfläche wie `ph_prop_corpse` |
| `ph_prop_corpse_06` | junge Frau (S3), Reisemantel | ≤ 4 000 | – |
| `ph_prop_corpse_gown` | Leiche im Totenhemd, Hände gefaltet | ≤ 3 000 | Leinen heller und wärmer als das Leichentuch |
| `ph_prop_layout_sprig` | Rosmarin-/Holunderzweig + Kerzenstumpf (ohne Licht) | ≤ 300 | Marker `sprig`, auf dem Brustkorb |
| `ph_prop_wash_basin` | Zinnschüssel auf Holzbock, Tuch | ≤ 900 | – |
| `ph_prop_smoke_bowl` | Tonschale mit Wacholder | ≤ 300 | Marker `smoke` |
| `ph_prop_hollow_stone` | bemooster Grenzstein mit Loch und Deckelstein | ≤ 1 200 | Marker `coins` |
| `ph_prop_gate_small`, `_gate_small_open` | rostiges Pförtchen zu / offen | ≤ 800 | gleiche Breite 1,2 m |
| `ph_prop_pit_sunken` | eingesunkene, bewachsene Grube mit morschen Brettern | ≤ 900 | Footprint = Grabplatz |
| `ph_env_elder_thicket` | Holunderdickicht (Hindernis) ~2 × 2 × 1,6 m | ≤ 2 500 | Laub-Shader |
| `ph_env_elder_bush` | großer Holunderstrauch, weiße Dolden, dunkle Beeren | ≤ 4 000 | Laub-Shader; Beeren tintenviolett, **kein** kaltes Sättigungsblau |
| `ph_item_scrub_brush`, `_comb`, `_burial_gown`, `_juniper`, `_shears`, `_pliers`, `_hair_braid`, `_teeth_pouch` | Item-Modelle (Icons) | ≤ 800 | Zahnsäckchen = zugebundenes Leinensäckchen (nichts Sichtbares); Zopf = gebundener Zopf mit Band |
| `ph_vfx_fly_atlas.png` | 4 Flugbilder einer gemalten Fliege, 4 × 64 × 64 | – | Tintenblau `#1F2A3A` mit Bernstein-Glanzpunkt |
| `ph_vfx_stench_wisp.png` | gemalte, gekräuselte Schwade 128 × 128 | – | fahles Oliv, weiche Pinselkante, **nie** Grün-Türkis (reserviert für Übernatürliches) |
| `ph_vfx_smoke_wisp.png` | Wacholderrauch 128 × 128 | – | warmes Grau |
| `ph_ui_journal_spread`, `_journal_card`, `_ink_stamp`, `_wilted_leaf` (W-UI, `tools/ui/`) | Merkbuch-Papier, Karte, Stempel, Verlust-Symbol | – | Pergament wie das bestehende Theme, eigene Formensprache |
Shader (P4): `assets/shaders/decay_overlay.gdshader` als `material_overlay` (blend_mul, Pinselrauschen aus `painted_common.gdshaderinc` **nur gelesen**). Uniforms `amount`, `stain_color`. Er malt fleckige, entsättigte Graugrün-Flächen und nichts Offenes, keine Wunden. Partikel: `CPUParticles3D`, Billboard, unshaded, `cast_shadow off`, im Nebel sichtbar. **Kein Abnehmer-NPC** (Frage §14.2).

## 9. Performance-Budget (Phase 4, Messung mit `graveyard_shots_phase4.gd`)
| Größe | Budget | Begründung |
|---|---|---|
| FPS | 60 @ 1080p Mittelklasse-GPU | unverändert |
| Draw Calls | < 1 000 (erwartet ≤ 500) | Holunderwinkel ≈ +35, Effekte ≤ 3 Leichen × (Overlay 1 + 3 Emitter) |
| Partikel gesamt | ≤ 60 (≤ 3 Leichen × [10 Fliegen + 5 Schwaden + 3 Rauch]) | `CPUParticles3D` (deterministisch, auch im Software-Renderer), `visibility_range_end 22 m`, außerhalb kein Prozess |
| Transparente Überzeichnung | Schwade ≤ 0,6 × 0,6 m, Alpha ≤ 0,35 | Nebel + Geister sind schon transparent |
| Kamera-Dreiecke inkl. Gras | < 500 k | Holunderwinkel ≈ +25 k |
| Lichter | unverändert (≤ 4 Omni mit Schatten, ≤ 24 sichtbar) | keine neuen Lichter (Kerzenstumpf ohne Licht, Hohlstein ohne Licht) |
| Geister | ≤ 18 berechtigt, ≤ 6 sichtbar | unverändert |
| Skripte CPU/Frame (headless) | < 1,5 ms | Merkbuch/Journal ereignisgetrieben; Verfall-Tönung stündlich + bei Stufenwechsel; Partikel < 0,1 ms |
| Spielstand | < 250 kB, Laden < 1 s | + Merkbuch ≈ 5 kB, + ≈ 0,5 kB je Leiche |
| Merkbuch öffnen | < 100 ms bei 25 Toten / 18 Hinweisen | Karten werden nur beim Öffnen gebaut |

## 10. Tests
Regeln wie Phase 3 §10 (Fixtures statt fremder Moduldaten, Fehler-Logger, Watchdog). **Alle 1 120 bestehenden Tests bleiben grün.** Anpassungen nimmt nur der jeweilige Besitzer vor, z. B. `revealed_traits` nach Schritten, `quality_max 13`, `penalty_by_level`.

**Unit**
| Datei | Besitzer | Prüft |
|---|---|---|
| `test_corpse.gd` (+) / `test_corpse_manager.gd` (+) | P1 | neue Record-Felder Roundtrip + tolerantes `from_dict`; `stage_for` mit `rotten`; Räucherfenster (Überlappung, Mehrfachfenster, 3×1 h == 1×3 h); `minutes_until`; Geschichts-Lieferung statt Zufall, Reservierung, Aufholen mit Abstand 2, Verrufen-Tage; Gestank-Abzug einmal je Tag; `examine`/`apply_shroud`-Delegation |
| `test_story.gd` | P1 | `due_story`/`pending_count`/`make_record`/`daily_checks` (Schlüssel ab Tag 12, idempotent) |
| `test_expansion.gd` (+) / `test_graveyard.gd` (+) | P1 | `requires_flag`, Holunderwinkel-Freigabe → 6 Plots + `c_six_pits`; `cemetery_complete` nur I–III; Kapitel `six_pits` (alle MARKED ∧ S5); Pietät-Ereignisse bei `bury` |
| `test_corpse_exam.gd` | P2 | Kandidaten (generisch/Ursache/Geschichte, Ersetzung), Aufdecken vs. Verlieren an genau `min_freshness`, Sperre nach Einkleiden, Gründlich = Einzelschritte, `examined` nach 1. Schritt, `revealed_traits`, Wertsachen erst nach `pockets`, `next_loss` |
| `test_corpse_prep.gd` | P2 | Reihenfolge-Regeln, Werkzeug/Item, Tuch vs. Hemd, `full_prep` genau einmal (+3 Pietät), Räuchern verlangsamt, Verwertung über CorpseCare (Item, Ruf, Pietät, Sperren, volles Inventar) |
| `test_grave_quality.gd` (+) | P2 | alle neuen Zeilen, Maximum 13, Verfallen −2, Altgräber unverändert |
| `test_piety.gd` | P3 | Stufen/Schwellen, Klemmen, Ereignisse, Erholung idempotent + nur ohne Verwertung, Gabe/Abnehmer je Stufe, `affinity` |
| `test_utilization.gd` | P3 | Sperrgründe (unbekannt = unsichtbar), Tür-Zettel ab Tag 4 genau einmal, Hohlstein: Einlegen, Auszahlung am Morgen genau einmal (auch mit Laden), Bonus, Werkzeug einmalig, Zettel 2/3 nach Verkäufen, Save/Load |
| `test_cemetery_rating.gd` (+) / `test_cemetery_score.gd` (+) / `test_cleanliness.gd` (+) | P3 | Ehrwürdig-Bedingung (Zier/Abzug), `venerable_missing`, neue Abzugstabelle |
| `test_decay_visual.gd` / `test_ghosts.gd` (+) | P4 | Überlagerung stetig je Frische, Partikelzahlen je Stufe, Räuchern ersetzt Schwaden durch Rauch, max. 3 emittierende; Kleidungs-/Aufbahr-Modelle; Gründe `robbed`/`unkempt` in Priorität, Beraubt-Abzug, Geschichts- und Pietät-Zeilen, Gabe 0/2/3 |
| `test_journal.gd` | P6 | `add_clue` (erstmals/Zähler), `try_link` exakte Menge (auch falsche Reihenfolge ✓, Obermenge ✗), offene Fragen, `ready_insights`, Umbenennung S5, `sync_from_records` still + idempotent, Save/Load |
| `test_save_migration.gd` (+) / `test_save.gd` (+) / `test_dialogue.gd` (+) | P6 | **alle vier v2-Fixtures und drei v1-Fixtures laden ohne Fehler/Warnungen**; Pietät aus Historie; `dress`/`exam_done`/Funde aus v2; Merkbuch rückwirkend; v3-Roundtrip identisch; Version 4 → abgelehnt; Osric: `p4_intro`, Wacholder-Handel, Pietät-Bemerkungen (negative Zahlen), Geschichts-Reaktionen |
| `test_assets_phase4.gd` | P5 | Modelle vorhanden, Budgets §8, Marker (`sprig`, `smoke`, `coins`), geteilte Materialien, VFX-PNGs (Größe, Alpha) |
| `test_ui_phase4.gd` | W-UI | Reiter und Sichtbarkeit von *Verwerten*, Schritt-Knöpfe + Gründe, Verlust-Hinweis, zweistufiger Verwerten-Knopf, Merkbuch (Seiten, Auswahl ≤ 3, Verknüpfen, Fehlversuch), Hohlstein-Panel, HUD-Zähler, Zielzeilen, Debug-Befehle |

**Integration**
- `test_phase4_loop.gd` (W-Welt): Neues Spiel → Tag 1: Leiche → Kleidung + Taschen → Tuch → bestatten. Tag 3 bis 16:00 warten → Zeichen verloren → kein `c_mark`. Tag 4: Zettel → Hohlstein → Werkzeug → Zopf → einlegen → Tag 5 06:00 Auszahlung. S1 (Tag 6) voll untersuchen → `c_page_1` → `i_warnings` verknüpfen. Holunderwinkel per Schlüssel (S2) freilegen. S5 per Debug → `i_not_lorenz` → Umbenennung → Kapitelende. **Roundtrip** `collect_state()` identisch nach `save_game`/`load_game` an 4 Momenten: mitten in der Untersuchung (2 von 4 Schritten), während eines Räucherfensters, mit Ware im Hohlstein vor der Auszahlung, nach dem Kapitelende.
- `test_phase3_save_upgrade.gd` (P6): `slot_p3_day14_complete.json` laden → Lieferungen ruhen → nächster `day_started`: Zettel + (Tag ≥ 12) Schlüssel-Rückfall → Holunderwinkel per Debug räumen → nächste Lieferung ist **S1** (Aufholen) → 2 Tage später S2.
- `test_graveyard_world.gd` (+, W-Welt): 18 Plots, Abschnitt `elder`, Pförtchen/Gruben/Dickicht, Hohlstein, Requisiten, Bau-Maske Index 4, Pförtchen begehbar nach Öffnen, Kamera-Grenzen.
- **Playthrough-Bot (W3):** `phase4_bot.gd` erweitert `Phase3Bot` um Untersuchungsschritte, Herrichten, Räuchern, Verwerten, Hohlstein und Verknüpfen.
  - Phase-3-Strategien mit neuen Erwartungen (§2.14), 14 Tage.
  - Neue Strategien, 24 Tage (harvester 28):
    - `reverent`: gründlich, voll herrichten, verknüpft, verwertet nie. Erwartet: Kapitelende ≤ Tag 22, alle 5 Haupt-Erkenntnisse, Pietät „Andächtig".
    - `harvester`: verwertet alles, Tuch, verkauft. Erwartet: Kapitelende erreicht (≤ Tag 28), Pietät ≤ −60, keine Softlocks.
    - `procrastinator`: bearbeitet Leichen erst am Folgetag, räuchert nie. Erwartet: ≥ 3 verlorene Funde, Gestank-Abzug, Schlüssel-Rückfall greift, Kapitelende erreicht.
    - `mixed`: nur Zopf an ungeraden Tagen, sonst würdevoll. Erwartet: Pietät pendelt, „Sachlich" oder „Abgebrüht".
    - `save_load4`: lädt jeden Morgen. Erwartet: bitgleich zu `reverent`.
  - Je Strategie protokolliert: Pietät, Ruf, Münzen, Erkenntnisse, verlorene Funde, Kapitel-Tag.
- Save-Fuzzer (W3): v3-Stand eines Phase-4-Spiels + 4 v2- + 3 v1-Fixtures. Gleiche zwei erlaubte Ausgänge wie Phase 3.
- Art-Prototyp-Regression: `test_art_prototype.gd` unverändert grün (Maler-Shader unberührt).

## 11. Screenshot-Liste Gate G4 (`graveyard_shots_phase4.gd -- --out=/abs/dir` + `ui_screenshots.gd --phase4`, 1280×720 → `docs/reviews/phase4_round1/`)
| # | Motiv |
|---|---|
| p4_01 | Morgens: frische Leiche auf dem Tisch, Waschschüssel und Räucherschale daneben |
| p4_02 | Verfall-Reihe: frisch · welk · verwesend · verfallen nebeneinander (Debug `decay row`), Fliegen und Schwaden lesbar, kein Gore |
| p4_03 | Nacht 22:30: verwesende Leiche auf der Bahre im Laternenlicht, Schwaden im Nebel |
| p4_04 | Geräucherte Leiche: Wacholderrauch statt Schwaden (Vergleich zu p4_03) |
| p4_05 | Panel *Untersuchen*: 2 Schritte erledigt, Fundkarten mit Stempel, eine verlorene Karte, Verlust-Hinweis |
| p4_06 | Panel *Herrichten*: gewaschen, Totenhemd gewählt, Warnzeile Einkleiden |
| p4_07 | Panel *Verwerten*: Folgenzeile + „Wirklich?"-Zustand |
| p4_08 | Leiche im Totenhemd, aufgebahrt (Zweig, Kerzenstumpf) vs. Leichentuch |
| p4_09 | Merkbuch *Die Toten* mit Totenzettel (verlorener Fund sichtbar) |
| p4_10 | Merkbuch *Hinweise*: 3 Karten gewählt, roter Faden, offene Fragen |
| p4_11 | Erkenntnis „Wer die Warnbriefe schrieb" freigeschaltet |
| p4_12 | Merkbuch *Ich* (Pietät-Satz ohne Zahl) |
| p4_13 | Hohlstein an der Westmauer (Tag) + Hohlstein-Panel |
| p4_14 | Morgens: Münzen im Hohlstein + Tageszusammenfassung mit Auszahlung |
| p4_15 | Holunderwinkel vorher: Pförtchen, Dickicht, sechs eingesunkene Gruben |
| p4_16 | Holunderwinkel belegt, Nacht, Geister, Holunder im Mondlicht |
| p4_17 | Geister nebeneinander: beraubt (unruhig) vs. hergerichtet (zufrieden), Sprechblase „Mein Zopf …" |
| p4_18 | S5 im Mantel auf der Bahre, Osric daneben, Ankunftszeile |
| p4_19 | Osric-Dialog bei Pietät „Abgebrüht" und bei „Andächtig" |
| p4_20 | Belohnungskarte mit neuen Zeilen (Gewaschen, Totenhemd, Aufgebahrt) |
| p4_21 | Friedhofsübersicht / Tooltip mit Ehrwürdig-Bedingung |
| p4_22 | Abschluss-Panel „Sechs Gruben" |
Dazu Asset-Tafeln `docs/reviews/phase4_assets/` und eine Performance-Tabelle je Motiv.

## 12. Wellenplan
| Welle | Agents (parallel) | Inhalt | Ende |
|---|---|---|---|
| **W0** | Lead | **Zuerst v2-Fixtures mit Build `febd2c7`** (vor jeder Code-Änderung). Dann: Datenklassen ✦, Stubs mit exakten Signaturen, EventBus-Signale, Database-Ordner, Input `journal`, `Category.GOODS`, `SaveMigration.CURRENT = 3` mit `migrate_2_to_3` als Identität (fail-safe), Config-/Daten-Fixtures `tests/fixtures/phase4/` (+ `Phase4Fixtures`), `test_phase4_scaffold.gd`, `test_saves_v2_load.gd` | Import + alle Tests grün → Commit |
| **W1** | P1, P2, P3, P4, P5, P6 (bei 5 Agents: P1 + P6) | Systeme mit Unit-Tests gegen Fixtures (ohne Welt), Assets + Asset-Tests, Migration, Texte (Funde, Hinweise, Erkenntnisse, Geister, Osric) | je Modul: Tests grün → Merge durch Lead, danach `--import` |
| **W2** | W-Welt, W-UI (2 parallel) | Holunderwinkel, Hohlstein, Requisiten, Builder, Bau-Maske, Szene neu bauen, `test_phase4_loop`; Panel-Reiter, Merkbuch, Hohlstein-Panel, HUD, Zielzeilen, Debug, Icons | Integration + Roundtrips grün, Screenshots erstellt |
| **W3** | QA (19), Art (04), Lead | Playthrough-Bot mit Phase-3-Erwartungen (§2.14) und Moral-Strategien (§10), Save-Fuzzer mit v2/v1, Performance, Stil-/Ton-Prüfung Verfall (kein Gore, Palette) und Verwertungstexte, Befunde beheben (Besitzer), Gate-Protokoll in `QUALITY_GATE_STATUS.md` | **STOPP – Benutzerprüfung G4** |
Abhängigkeiten:
- W1-Agents nutzen nur Stubs und Datenklassen anderer Module.
- P2 ruft `UtilizationRules`, `Piety`, `JournalManager` und `CorpseManager.notify_changed` nur über die Gruppen-API/Stubs.
- P4 liest den Record nur lesend.
- P5 liefert zuerst `ph_prop_corpse_05/06`, `_gown`, VFX-PNGs, `ph_prop_hollow_stone`, `_pit_sunken` (Blocker für W2-Screenshots).
- Texte: P2 besitzt `data/finds/*`, P6 `data/journal/*` und `carter.tres`, P4 `ghost_lines.tres`, P1 `data/story/*`. Die Leittexte stehen in §2.2/§2.11/§2.12. Wer sie ändert, meldet es dem Lead.

## 13. Nicht in Phase 4
- Ganze Leichen verkaufen (Anatomie), Körperteile oder Organe entnehmen, sichtbare Eingriffe, Blut, Gore
- Exhumieren, Umbetten, Gräber wiederverwenden
- Kühlkeller, Eishaus, zweiter Leichentisch, Leichenhalle (Gebäude: Phase 6)
- Sichtbarer Abnehmer-NPC, Handel mit anderen Waren, Preisdynamik (Wirtschaft: Phase 10)
- Angehörige, Trauerfeiern, Pfarrer, Totenwache (NPCs: Phase 8)
- Quests, Aufträge (Phase 9)
- Krypta unter dem Birkenhang (nur als Satz, Phase 12)
- Übernatürliche Kräfte, Auferstehung, untote Arbeiter (nur Haken `affinity`, Phasen 13–14)
- Auflösung des Geheimnisses: Wer zeichnet, wo Lorenz ist, der sechste Name (Phase 18)
- Mehr als eine Leiche pro Tag
- Verfall bestatteter Leichen oder der Gräber
- Wetter, Jahreszeiten
- Musik, Sound (Agent 17 inaktiv)
- Controller, Lokalisierung
- Änderungen am Maler-Shader, an den Atmosphären-Presets und am Hütten-Innenraum

## 14. Offene Fragen an den Benutzer (bitte entscheiden)
1. **Name des Moralwerts:** „Pietät" (Vorschlag) oder „Gewissen" oder „Ehrfurcht"? Dazu die Stufen „Hartherzig · Abgebrüht · Sachlich · Rücksichtsvoll · Andächtig". Bestätigen oder umbenennen?
2. **Abnehmer:** (a) unsichtbarer Käufer am **Hohlstein**, nur Zettel und Münzen (Vorschlag: eerie, keine neue Figur). (b) Eine sichtbare Nachthändlerin am Zaun (neue Figur mit Rig, Tagesplan und Dialog, deutlich mehr Aufwand). (c) Osric als Zwischenhändler (keine neuen Assets, aber er wird mitschuldig).
3. **Holunderwinkel mit 6 neuen Grabstellen:** Ja (Vorschlag, trägt ≈ 7 neue Tage und das Kapitelende)? Oder keine neuen Gräber? Dann endet die Geschichte mit dem 12. Grab um Tag 14, S4/S5 rücken auf Tag 10/12, und Phase 4 bringt keine eigenen Tage.
4. **Richtung des Finales:** „Der Tote aus dem Moor ist nicht Lorenz – er lebt" (Vorschlag, offener Haken für Krypta und Story)? Oder „Es ist wirklich Lorenz" (stiller, abgeschlossener, melancholischer)? Und passt der Name **Lorenz Aschau**?

## W0-Notizen (Lead, Welle 0 – verbindlich für W1)
*(folgt nach Welle 0)*
