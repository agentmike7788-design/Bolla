# Bolla

I am new Vibecoder and try my Best

## Bolla Fabrik

Ein kleines Fabrik-Spiel à la Factorio/Satisfactory in Three.js. Aktueller Stand: eine zufällige Kachel-Karte mit Erzvorkommen (Eisen, Kupfer, Kohle, Kalkstein), eine Strategie-Kamera, Bohrer, Förderbänder, Lager, Schmelzofen, Presse, Verteiler, Zusammenführer und Konstruktor, dazu ein Forschungsbaum, der Gebäude und Verbesserungen freischaltet.

```bash
npm install
npm run dev     # startet den Entwicklungsserver
npm run build   # baut das Spiel nach dist/
```

Steuerung: linke Maus verschieben, rechte Maus oder Q/E drehen, Mausrad zoomen, WASD bewegen.

Bauen: `1` Bohrer, `2` Förderband, `3` Lager, `4` Schmelzofen, `5` Presse, `6` Verteiler, `7` Zusammenführer, `8` Konstruktor, `X` Abriss, `T` Forschungsbaum, `R` dreht das nächste Gebäude (ohne Werkzeug: das Gebäude unter der Maus), `Esc` beendet den Bau-Modus. Bänder verlegt man durch Ziehen mit der linken Maus; sie folgen der Maus und biegen automatisch ab. Ein Bohrer legt sein Erz auf das Band vor seinem Ausgang. Am Ende eines Bands staut sich das Erz, und der Bohrer wartet.

Maschinen nehmen Teile von Bändern an jeder Seite außer ihrem Ausgang an und geben ihr Produkt nach vorn ab (Pfeil beim Bauen):
- Schmelzofen: Eisenerz → Eisenbarren, Kupfererz → Kupferbarren.
- Presse: Eisenbarren → Eisenplatte, Kupferbarren → Kupferdraht, Kalkstein → Beton.
- Lager: nimmt alles von allen Seiten an und zählt es.
- Verteiler: nimmt Teile von hinten und gibt sie abwechselnd nach vorn, links und rechts weiter; ein voller Ausgang wird übersprungen.
- Zusammenführer: nimmt Teile von hinten, links und rechts und gibt sie abwechselnd nach vorn ab.
- Konstruktor: baut aus mehreren Teilen eins. Ohne Werkzeug auf ihn klicken, um das Rezept zu wählen: 2 Eisenplatten → Zahnrad, 1 Eisenplatte + 2 Kupferdraht → Schaltkreis, 2 Eisenbarren + 1 Kohle → Stahlträger.

Forschung: Oben links steht die nächste Forschung, `T` öffnet den ganzen Baum. Bezahlt wird mit Teilen aus dem Lager. Schmelzen schaltet den Schmelzofen frei, Pressen die Presse; dazu gibt es schnellere Bänder, Bohrer und Öfen. „Erste Fabrik“ (25 Platten, 25 Draht, 15 Beton) ist das erste Spielziel. Danach geht es weiter: Logistik (Verteiler, Zusammenführer), Konstruktor, Hydraulik, Tiefbohrer und Magnetbänder; „Meisterfabrik“ (50 Schaltkreise, 40 Stahlträger, 40 Zahnräder) ist das große Ziel. Bänder und Bohrer wechseln mit jeder Tempo-Forschung die Farbe. Neue Einträge kommen in `src/research.js`; der Baum ordnet sie selbst nach ihren Voraussetzungen an.

Karten und Missionen: Beim Start (und mit `M` oder dem Knopf „Karten“) wählt man eine Karte. Im freien Spiel gibt es eine Zufallsinsel mit allen Erzen und den Forschungsbaum. Dazu kommen vier Missionskarten mit eigener Landschaft und nur bestimmten Erzen:
- Eisenberge (Eisen, Kalkstein): der Einstieg vom ersten Bohrer bis zum Zahnradwerk.
- Kupferwüste (Kupfer, Kalkstein): Wüste mit Kakteen, am Ende 60 Draht pro Minute.
- Kohleinsel (Kohle, Eisen): kleine Insel, wenig Platz, ein Stahlwerk.
- Großes Festland (alle Erze): die Meisterprüfung mit Schaltkreisen und Stahl.

Auf Missionskarten ersetzen Missionen den Forschungsbaum: Jede Mission hat Ziele (Teile ins Lager liefern, Gebäude bauen oder eine Menge pro Minute schaffen) und schaltet als Belohnung Gebäude und Tempo frei. Wer alle Missionen schafft, bekommt je nach Zeit ein bis drei Sterne; die Bestzeit merkt sich der Browser. Neue Karten kommen in `src/scenarios.js`.

Ton und Licht: Alle Geräusche entstehen im Browser per Web Audio, ohne Audiodateien: Bauen, Abreißen, Drehen, Missionserfolg und eine ruhige Hintergrundmusik. Maschinen brummen, rattern und fauchen umso lauter, je näher die Kamera ist, und kommen von links oder rechts. Über „Ton & Licht“ oben stellt man Lautstärke und Musik ein, `U` schaltet den Ton stumm. Ein Tag dauert acht Minuten: Die Sonne wandert, abends wird es orange, nachts gibt es Sterne, und die Maschinen leuchten den Boden an. `N` springt zur nächsten Tageszeit; im Menü lässt sich auch „Immer Tag“ oder „Immer Nacht“ wählen. Öfen sprühen Funken und Glut, Bohrer werfen Erzbrocken auf, Pressen funken beim Stanzen, beim Bauen staubt es, und eine geschaffte Karte gibt ein Feuerwerk.

Code:
- `src/world.js` erzeugt die Karte (Gelände per Rauschen, Erzfelder als Flecken); Landschaft und Erze lassen sich pro Karte einstellen.
- `src/scenarios.js` sind die Karten mit ihren Missionen, `src/missionView.js` zeigt die aktuelle Mission an.
- `src/scenery.js` baut daraus die 3D-Szene: Kacheln, Bäume, Büsche, Blumen, Felsen, Erze und das Meer.
- `src/camera.js` ist die Kamera-Steuerung.
- `src/factory.js` ist die Spiel-Logik: welches Gebäude wo steht, Abbau, Transport, Rezepte der Maschinen, Lager und Ziele.
- `src/research.js` ist der Forschungsbaum, `src/researchView.js` zeigt ihn an.
- `src/buildings.js` zeichnet die Gebäude, Bänder, die Teile darauf und die Bau-Vorschau.
- `src/audio.js` erzeugt alle Geräusche und die Musik, `src/effects.js` die Partikel, `src/daynight.js` den Tag-Nacht-Wechsel mit Himmel, Sternen und Maschinenlichtern.
- `src/main.js` verbindet Szene, Licht, Maus- und Tastatur-Steuerung und HUD.
