# Bolla

I am new Vibecoder and try my Best

## Bolla Fabrik

Ein kleines Fabrik-Spiel à la Factorio/Satisfactory in Three.js. Aktueller Stand: eine zufällige Kachel-Karte mit Erzvorkommen (Eisen, Kupfer, Kohle, Kalkstein), eine Strategie-Kamera, Bohrer auf Erzfeldern und Förderbänder, über die das Erz sichtbar läuft.

```bash
npm install
npm run dev     # startet den Entwicklungsserver
npm run build   # baut das Spiel nach dist/
```

Steuerung: linke Maus verschieben, rechte Maus oder Q/E drehen, Mausrad zoomen, WASD bewegen.

Bauen: `1` Bohrer, `2` Förderband, `X` Abriss, `R` dreht das nächste Gebäude (ohne Werkzeug: das Gebäude unter der Maus), `Esc` beendet den Bau-Modus. Bänder verlegt man durch Ziehen mit der linken Maus; sie folgen der Maus und biegen automatisch ab. Ein Bohrer legt sein Erz auf das Band vor seinem Ausgang. Am Ende eines Bands staut sich das Erz, und der Bohrer wartet.

Code:
- `src/world.js` erzeugt die Karte (Gelände per Rauschen, Erzfelder als Flecken).
- `src/scenery.js` baut daraus die 3D-Szene: Kacheln, Bäume, Büsche, Blumen, Felsen, Erze und das Meer.
- `src/camera.js` ist die Kamera-Steuerung.
- `src/factory.js` ist die Spiel-Logik: welches Gebäude wo steht, Abbau und Transport auf den Bändern.
- `src/buildings.js` zeichnet Bohrer, Bänder, das Erz darauf und die Bau-Vorschau.
- `src/main.js` verbindet Szene, Licht, Maus- und Tastatur-Steuerung und HUD.
