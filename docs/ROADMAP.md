# Development Roadmap

Regel: **BAUE → TESTE → ZEIGE → WARTE AUF FREIGABE.** Keine Phase startet ohne ausdrückliche Benutzerfreigabe.

| Phase | Inhalt | Status |
|---|---|---|
| 0 | Projektsetup | ✅ freigegeben (27.09.2026) |
| 1 | Art-Direction-Prototyp | ✅ freigegeben (27.09.2026) – ART STYLE LOCK aktiv |
| 2 | Vertical Slice | ✅ freigegeben (27.09.2026) |
| 3 | Friedhof vollständig ausbauen | ✅ freigegeben (27.09.2026) |
| 4 | Leichensystem erweitern | ✅ freigegeben (28.09.2026) |
| 5 | Crafting und Ressourcen | 🔵 Planung – Umfang wird mit dem Benutzer abgestimmt |
| 6 | Gebäude | – |
| 7 | Dorf | – |
| 8 | NPCs | – |
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
