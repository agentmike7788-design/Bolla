# Development Roadmap

Regel: **BAUE → TESTE → ZEIGE → WARTE AUF FREIGABE.** Keine Phase startet ohne ausdrückliche Benutzerfreigabe.

| Phase | Inhalt | Status |
|---|---|---|
| 0 | Projektsetup | ✅ freigegeben (27.09.2026) |
| 1 | Art-Direction-Prototyp | ✅ freigegeben (27.09.2026) – ART STYLE LOCK aktiv |
| 2 | Vertical Slice | ✅ freigegeben (27.09.2026) |
| 3 | Friedhof vollständig ausbauen | ✅ freigegeben (27.09.2026) |
| 4 | Leichensystem erweitern | ✅ freigegeben (28.09.2026) |
| 5 | Crafting und Ressourcen | ✅ freigegeben (28.09.2026) |
| 6 | Gebäude | ✅ freigegeben (03.10.2026) |
| 7 | Dorf | ✅ freigegeben (04.10.2026) |
| 8 | NPCs | 🟡 Gate G8 PENDING – gebaut (W0–W3), wartet auf Benutzerprüfung |
| 9 | Quests | – |
| 10 | Wirtschaft | – |
| 11 | Welt erweitern | – |
| 12 | Krypten | – |
| 13 | Auferstehung | – |
| 14 | Untote Arbeiter | – |
| 15 | Combat | – |
| 16 | Dungeons | – |
| 17 | Bosse | – |
| 18 | Story | – |
| 19 | Polishing | – |
| 20 | Final QA | – |
| 21 | Release Build | – |

## PHASE 2 – VERTICAL SLICE (Plan)

Start erst nach: **Art Direction freigegeben (ART STYLE LOCK = ACTIVE)**.
Ende: **STOPP** – Benutzer muss „Vertical Slice freigegeben." sagen.

Gebaut in kleinen, einzeln getesteten Meilensteinen (je ein Git-Commit):

| M | Meilenstein | Agents | Tests |
|---|---|---|---|
| 2.1 | Spieler-Controller, Kamera-Follow, Interaktions-Komponente | 08, 09, 19 | Bewegung, Kollision, Interaktion |
| 2.2 | **SaveManager** + Saveable-Vertrag (Spielerposition) + Debug-Overlay (F1) | 08, 19 | Save/Load-Roundtrip |
| 2.3 | Tag/Nacht-Zyklus (TimeManager + Beleuchtung) | 08, 04, 19 | Zeit speichern/laden, Debug „Zeit setzen" |
| 2.4 | Inventar + Ressourcen (Resource-Definitionen in `data/`) | 09, 14, 18, 19 | Hinzufügen/Entfernen, Save/Load |
| 2.5 | Leiche: Ankunft, aufnehmen/tragen, untersuchen, Zustand-UI | 11, 18, 19 | Zustandsanzeige, Debug „Leiche spawnen" |
| 2.6 | Grab: ausheben, Leiche hineinlegen, Bestattung, Grabstein, Friedhofsqualität (einfach) | 10, 11, 19 | Kompletter Loop, Save/Load |
| 2.7 | Einfaches Crafting (Werkbank, 2–3 Rezepte, z. B. Grabstein, Holzkreuz) | 14, 18, 19 | Rezept-Tests |
| 2.8 | 1 NPC: Position, Tagesroutine, Dialog, Interaktion (z. B. Leichenkutscher) | 12, 13, 19 | Routine über Tageszeit, Dialog, Save/Load |
| 2.9 | Angrenzender Bereich + Übergang | 03, 05, 19 | Performance, Übergang |
| 2.10 | Integration, Regressionstest, Performance-Messung, Präsentation | 01, 19, 20 | Voller Durchlauf |

Debug-Funktionen im Vertical Slice: Zeit ändern, Teleport, Ressourcen hinzufügen, Leiche spawnen, NPC spawnen. (Gegner/Quests/Gebäude-Platzieren erst mit den jeweiligen Systemen.)

## PHASE 3 – FRIEDHOF AUSBAU (Plan)

Verbindlicher Vertrag (Entwurf zur Benutzerfreigabe): **`docs/PHASE3_DESIGN.md`** – Abschnitte Ostwiese/Birkenhang (12 Grabstellen), Zier & Baumodus, Pflege, Ruf, Geister, Migration der Phase-2-Stände, Wellenplan W0–W3.

## PHASE 4 – LEICHENSYSTEM (Plan)

Verbindlicher Vertrag (Entwurf zur Benutzerfreigabe): **`docs/PHASE4_DESIGN.md`**. Inhalt:
- Untersuchung in 4 Schritten, deren Funde durch Verfall verloren gehen können
- Merkbuch (J) mit Hinweisen und Erkenntnissen und erster Erzählfaden „Was geschah mit Lorenz Aschau?" mit 5 Geschichts-Leichen
- Herrichten (waschen, einkleiden, aufbahren, räuchern)
- Verwertung (Haar, Zähne, Wertsachen) und Verkauf an die sichtbare Nachthändlerin Ilse Kranich
- Moralwert „Pietät" (sanft, ohne HUD-Anzeige)
- deutlicherer Verfall mit gemalten Fliegen und Schwaden
- Holunderwinkel mit 6 neuen Grabstellen und Kapitelende „Sechs Gruben"
- Balancing-Übertrag: „Ehrwürdig" verlangt Zier und Pflege
- Save-Format v3 mit Migration der Phase-3-Stände
- Wellenplan W0–W3 und Benutzerentscheidungen (§14)

## PHASE 5 – CRAFTING & RESSOURCEN (Plan)

Verbindlicher Vertrag (Entwurf zur Benutzerfreigabe): **`docs/PHASE5_DESIGN.md`**. Inhalt:
- Werkhof an der Hütte: Steinmetzbank, Webstuhl und Esse auf festen Bauplätzen (Material + Münzen), Meiler als einziger Hintergrund-Auftrag; Holzhaufen versetzt (sonst bleibt der Alte Hof unverändert)
- „Am Bruch" östlich der Ostwiese als Rohstoffgebiet (Steinbruch, Findlinge, Erz, Lehm, Flachs), eingeführt als Lorenz' alter Werkplatz
- Rohstoffe mit nachwachsenden Sammelstellen: Lehm, Flachs, Kräuter, Erz, Bruchstein, Werkstein (Steinbruch hinter Findlingen), Schlag-Erlen am Kutschweg, Holunderbeeren
- Werkzeugstufen (Schaufel, Axt, Spitzhacke, je 0–2) am passiven Werkzeuggürtel, Faktoren 1,0 / 0,8 / 0,6, neue Aufgaben (Fällen, Findlinge, Werkstein); Inventar 20 Slots
- Grabstein-Gestaltung je Grab an der Steinmetzbank: 3 Formen × 7 Inschrift-Vorlagen (Name/Daten automatisch) × 4 Zierden, vergoldet; Qualität bis 19, Geister-Grund „ohne Namen"
- Münzsenke: 108 Münzen Pflicht + freiwillige Posten gegen den Überschuss aus Phase 4 (Rechnung §2.8)
- Übertrag: kein „Voll hergerichtet"-Bonus für verwertete Leichen (Pietät-Fix, Bot `mixed`)
- Kapitel „Namen in Stein", Save-Format v4 mit Migration der Phase-4-Stände, Wellenplan W0–W3, Benutzerentscheidungen §14 (keine neuen Gräber, Werkhof an der Hütte, Jahr 1834, Lorenz-Bezug)

## PHASE 6 – GEBÄUDE (Plan)

Verbindlicher Vertrag (Entwurf zur Benutzerfreigabe, Vertragsfragen §14 offen): **`docs/PHASE6_DESIGN.md`**. Inhalt:
- Drei Gebäude auf festen Bauplätzen mit Stufen 1–3 (Material + Münzen), jedes begehbar mit eigener Innenraum-Szene nach dem Hüttenmuster (Portal, Kameraprofil, Innenlicht nach Tag/Nacht)
- **Die Gruft** unter der alten Eiche (Südwestecke Alter Hof): Leichenhalle + Beinhaus in einem Gebäude unter der Erde; der Leichentisch vor der Hütte zieht mit Gruft 1 hinab (Benutzerwunsch), Kühlnischen 2/4/6 bremsen den Verfall (× 0,5/0,4/0,3), vermauerter Gang und Gitter als Haken für Phase 12
- **Beinhaus:** 6 verwitterte Altgräber heben und umbetten (Ruhezeit 30 Jahre) → die Stellen werden frei, Osric liefert wieder
- **Die Kapelle** am Birkenkamm (neuer Kirchhof nördlich des Birkenhangs, Kirchpforte): Aussegnung als Laienritus (Kerze, Gebühr, Ruf, Trauergäste, „Ausgesegnet +1"), Andacht für Gräber (beraubte Seelen höchstens gleichmütig)
- **Der Lagerschuppen** westlich der Hütte: 24/32/40 Plätze, ab Stufe 2 „Fehlendes aus dem Schuppen holen" an allen Stationen
- Kamerastrahl-Sichtprüfung für jedes Gebäude und jede Stufe, Vorher/Nachher vor der Hütte
- Münzrechnung: 130 Münzen Pflicht (Stufe 1+2), 225 für alles, finanziert über Umbettgeld, neue Bestattungen und Gebühren
- Kapitel „Unter Dach und Erde", Save-Format v5 mit Migration der Phase-5-Stände (Leiche am alten Tisch bleibt bearbeitbar), Wellenplan W0–W3, Vertragsfragen §14

## PHASE 7 – DORF (Plan)

Verbindlicher Vertrag (Entwurf zur Benutzerfreigabe, Vertragsfragen §14 offen): **`docs/PHASE7_DESIGN.md`**. Inhalt:
- **Hollerbrück** als eigene Außen-Region (Szene fern der Friedhofswelt, Abblende am Wegstein, 30 Spielminuten Weg), Anger mit Brunnen, Linde und Gemeindetafel, Kirche St. Gallus (außen), drei begehbare Häuser (Holderkrug, Wundarztstube, Amtsstube)
- Acht Dorfbewohner auf dem gemeinsamen Rig (Wirtin, Schmied, Krämerin, Pfarrer, Schultheiß, Wundarzt Quast, Seelfrau Liesel Dorn, die alte Hagedorn) mit Tagesabläufen, Läden und Dialogen; Osric wohnt im Dorf, Ilse spricht nachts über das Dorf; NPC-Last über LOD und Regionen begrenzt
- **Organ-System (Benutzerwunsch 03.10.2026):** Präparate Herz, Lunge, Magen am Gruft-Tisch (angedeutet: Tuch, Schleier, nur verschlossene Gläser/Bündel), verkaufen, untersuchen lassen (wahre Todesursache → Merkbuch), Schaupräparat am neuen Präparierpult, ins Grab zurücklegen; Daten-Haken für Phase 13
- Aufträge (liefern, bestatten, Stein setzen, pflegen, spenden) und ein Beziehungswert je Person; Ruf und Pietät färben Begrüßung, Gerede und Preise
- Der **Lindenacker** (8 neue Grabstellen südlich der Ostwiese, vom Pfarrer geweiht) macht das Dorf zur Quelle neuer Toter; Geschichts-Leiche D1 Wiebke Hagedorn
- Geheimnis-Ausschnitt „Wer besucht die Sterbenden?" (Erkenntnis „Vorher eingetragen"), nächster Schritt „Der unterstrichene Name" (Phase 8)
- Kapitel „Ein Name im Dorf", Münzrechnung, Save-Format v6 mit Migration der Phase-6-Stände, Wellenplan W0–W3 (W1 mit 7 Paketen), Vertragsfragen §14

## PHASE 8 – NPCs (Plan)

Verbindlicher Vertrag (Entwurf zur Benutzerfreigabe, Vertragsfragen §14 offen): **`docs/PHASE8_DESIGN.md`**. Umfang „mittel" (10 Spieltage, Kapitel „Wer heraufkommt"). Inhalt:
- **Dorfleben:** Launen je Tag (heiter, bedrückt, gereizt, „Zuhören"), 16 Begegnungen zwischen Bewohnern als Sprechblasen, Reaktionen auf das Tun des Spielers; Esch, Theres und Liesel besuchen ihre Toten auf dem Hügel
- **Besucher & Trauernde:** vier Angehörige der Dorfhäuser (Kehr, Brandt, Ott, Sieber) kommen sichtbar zu ihren Gräbern (Blumen ablegen, knien, stehen), sehen das Grab an (Ruf ±), äußern Wünsche (pflegen, Blumen, Kerze, Inschrift-Zeile, Vase) und geben kleines Trinkgeld (Kappe 4/Tag); Grabpflege neu: Grabblumen mit Gießen, Grabkerzen, Grabgitter
- **Lehrling Jakob Wackernagel** (Rosines Sohn): Arbeitsliste an der Kreidetafel, Harken, Jäten, Gießen, Kerzen; Anlernen durch Vormachen und Übung, Fehler, Lohn 3/Tag; klare Grenze zu Phase 14
- **Neue Figuren:** Bettler Veit Ammer (Zeuge der Nacht), Wanderhändlerin Hanne Vogelsang, Nachtgräber Lambert Grell (ohne Kampf, die Leiche bleibt im Grab)
- **Freundschaft:** drei Schritte je Bewohner, Gefallen und Gegengefallen; **Feste:** Kathreintanz (25. Nebelung) und der Hollerbrücker **Lichtgang** (Vorabend des Advents)
- Geheimnis-Ausschnitt „Der unterstrichene Name" (Krankenlicht, Nachtbesuche, D2 Gerhard Ott, Lorenz' zweite Kladde), dritte Reihe im Lindenacker (4 Stellen), Save-Format v7 mit Migration der Phase-7-Stände, Wellenplan W0–W3 (W1 mit 7 Paketen), Vertragsfragen §14

## Benutzerwunsch 03.10.2026 – Organe & Anatomie (eigene spätere Phase/Erweiterung)
- **Wann:** als eigene Erweiterung **nach Phase 6** (nicht in Phase 6). Einordnung wird vor dem Start mit dem Benutzer abgestimmt (Vorschlag: zusammen mit Phase 7 „Dorf", wo der Wundarzt/Anatom der Stadt eingeführt wird).
- **Darstellung:** **angedeutet** wie die bisherige Verwertung – Tuch über der Leiche, Werkzeug-Geräusch, Abblende; Organe nur als verschlossene Gläser/Bündel im Inventar. Kein Blut, keine offenen Wunden (ART STYLE LOCK).
- **Zweck (alle vier):** Verkauf an einen Anatomen („Präparate", 1834, kostet Pietät/Ruf, Geister unruhig) · Forschung/Hinweise (wahre Todesursache, z. B. Gift → Merkbuch) · Handwerk (Salben, Tinkturen, Präparate an neuer Station) · später Zutat für die Auferstehung (Phase 13).
- Eigene Mechanik, keine Übernahme aus anderen Spielen.

## Benutzerwunsch 04.10.2026 – Angeln (für Phase 11 „Welt erweitern")
- Neuer Ort **Mühlteich** bei der alten Mühle (bisher nur in Jost Hemmerlings Totengeschichte erwähnt), mit Steg.
- **Angel**, **Köder** (Würmer vom Friedhof, Brot, Maden …), mehrere **Fischarten** nach Tages- und Jahreszeit, Fische verkaufen und kochen.
- Sichtbare Abläufe wie gewohnt: Angel in der Hand (Rig-Knochen `tool`), Ton, Karten-Eintrag.
- Entscheidung: kommt mit Phase 11, Phase 8 bleibt unverändert.
