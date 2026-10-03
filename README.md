# Bolla

I am new Vibecoder and try my Best

## Bolla Fabrik

Ein kleines Fabrik-Spiel à la Factorio/Satisfactory in Three.js. Aktueller Stand: eine zufällige Kachel-Karte mit Erzvorkommen (Eisen, Kupfer, Kohle, Kalkstein), eine Strategie-Kamera, Bohrer, Förderbänder, Lager, Schmelzofen und Presse, dazu ein Forschungsbaum, der Gebäude und Verbesserungen freischaltet.

```bash
npm install
npm run dev     # startet den Entwicklungsserver
npm run build   # baut das Spiel nach dist/
```

Steuerung: linke Maus verschieben, rechte Maus oder Q/E drehen, Mausrad zoomen, WASD bewegen.

Bauen: `1` Bohrer, `2` Förderband, `3` Lager, `4` Schmelzofen, `5` Presse, `X` Abriss, `T` Forschungsbaum, `R` dreht das nächste Gebäude (ohne Werkzeug: das Gebäude unter der Maus), `Esc` beendet den Bau-Modus. Bänder verlegt man durch Ziehen mit der linken Maus; sie folgen der Maus und biegen automatisch ab. Ein Bohrer legt sein Erz auf das Band vor seinem Ausgang. Am Ende eines Bands staut sich das Erz, und der Bohrer wartet.

Maschinen nehmen Teile von Bändern an jeder Seite außer ihrem Ausgang an und geben ihr Produkt nach vorn ab (Pfeil beim Bauen):
- Schmelzofen: Eisenerz → Eisenbarren, Kupfererz → Kupferbarren.
- Presse: Eisenbarren → Eisenplatte, Kupferbarren → Kupferdraht, Kalkstein → Beton.
- Lager: nimmt alles von allen Seiten an und zählt es.

Forschung: Oben links steht die nächste Forschung, `T` öffnet den ganzen Baum. Bezahlt wird mit Teilen aus dem Lager. Schmelzen schaltet den Schmelzofen frei, Pressen die Presse; dazu gibt es schnellere Bänder, Bohrer und Öfen. „Erste Fabrik“ (25 Platten, 25 Draht, 15 Beton) ist das erste Spielziel. Neue Einträge kommen in `src/research.js`; der Baum ordnet sie selbst nach ihren Voraussetzungen an.

Code:
- `src/world.js` erzeugt die Karte (Gelände per Rauschen, Erzfelder als Flecken).
- `src/scenery.js` baut daraus die 3D-Szene: Kacheln, Bäume, Büsche, Blumen, Felsen, Erze und das Meer.
- `src/camera.js` ist die Kamera-Steuerung.
- `src/factory.js` ist die Spiel-Logik: welches Gebäude wo steht, Abbau, Transport, Rezepte der Maschinen, Lager und Ziele.
- `src/research.js` ist der Forschungsbaum, `src/researchView.js` zeigt ihn an.
- `src/buildings.js` zeichnet die Gebäude, Bänder, die Teile darauf und die Bau-Vorschau.
- `src/main.js` verbindet Szene, Licht, Maus- und Tastatur-Steuerung und HUD.
