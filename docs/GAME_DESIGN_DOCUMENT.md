# Game Design Document

Status: **ENTWURF – Grundidee vom Benutzer vorgegeben, Details offen**
Verantwortlich: Agent 02 (Game Design) · Finale Entscheidung: Benutzer

## 1. Eckdaten

| | |
|---|---|
| Arbeitstitel | THE LAST GRAVEKEEPER |
| Genre | 2.5D Fantasy Graveyard Management / Adventure / RPG |
| Perspektive | Fixe, gewinkelte 3D-Kamera (siehe Art Direction) |
| Plattform | PC (vorläufig) |
| Ton | Melancholisch, warm, trockener Humor, übernatürliche Geheimnisse |

## 2. Prämisse

Der Spieler übernimmt einen alten, heruntergekommenen Friedhof am Rand eines Dorfes. Der letzte Totengräber ist verschwunden. Zwischen Leben und Tod regt sich etwas – und jede Leiche bringt ein Stück der Wahrheit mit.
*(Story-Details: offen, Phase 18 / Agent 13)*

## 3. Kern-Loop

```
Leiche kommt an → untersuchen → entscheiden
  → bestatten / verarbeiten / untersuchen / anderen Systemen zuführen
  → Ressourcen → Friedhof verbessern → neue Gebäude & Systeme
  → neue NPCs & Quests → neue Leichen → neue Geheimnisse → größere Welt
```

## 4. Kernsysteme (Überblick, Umsetzung phasenweise)

| System | Kurzbeschreibung | Phase |
|---|---|---|
| Spieler | Bewegung, Interaktion, Tragen, Werkzeuge | 2 |
| Leichen | Ankunft, Zustand (Frische, Todesursache, Besonderheit), Untersuchung | 2 / 4 |
| Gräber | Grab ausheben, Bestattung, Grabstein, Qualität | 2 / 3 |
| Friedhofsqualität | Summe aus Gräbern, Deko, Sauberkeit → beeinflusst Ruf/Einkommen | 3 |
| Inventar & Ressourcen | Slots, Stapel, Grundressourcen (Holz, Stein, Erde, Münzen …) | 2 |
| Crafting | Werkbank, einfache Rezepte | 2 (einfach) / 5 |
| Tag/Nacht | Uhrzeit, Beleuchtung, NPC-Routinen | 2 |
| NPCs | Tagesroutine, Dialog, Beziehung | 2 (1 NPC) / 8 |
| Save/Load | Früh; alles speicherbar | 2 |
| Später | Dorf, Quests, Wirtschaft, Krypten, Auferstehung, untote Arbeiter, Kampf, Dungeons, Bosse | 7–17 |

## 5. Eigene Identität (Abgrenzung)

Ideen zur Diskussion (nichts davon ist beschlossen):
- **Leichen erzählen Geschichten:** Jede Untersuchung liefert Hinweise (Gegenstände, Wunden, Briefe), die zu Geheimnissen/Quests führen.
- **Moralische Entscheidungen:** Würdevolle Bestattung vs. Verwertung beeinflusst Dorf-Ruf *und* übernatürliche Kräfte.
- **Der Friedhof lebt:** Geister der Bestatteten reagieren auf die Qualität ihres Grabes.

## 6. Offene Design-Entscheidungen

- Name & Hintergrund der Spielfigur
- Ton-Gewichtung: eher gemütlich oder eher düster?
- Kampf: Echtzeit-Action oder einfacher?
- Moral-System ja/nein
