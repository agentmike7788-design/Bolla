# Bolla

I am new Vibecoder and try my Best

## Bolla Fabrik

Ein kleines Fabrik-Spiel à la Factorio/Satisfactory in Three.js. Aktueller Stand: eine zufällige Kachel-Karte mit Erzvorkommen (Eisen, Kupfer, Kohle, Kalkstein) und eine Strategie-Kamera.

```bash
npm install
npm run dev     # startet den Entwicklungsserver
npm run build   # baut das Spiel nach dist/
```

Steuerung: linke Maus verschieben, rechte Maus oder Q/E drehen, Mausrad zoomen, WASD bewegen.

Code:
- `src/world.js` erzeugt die Karte (Gelände per Rauschen, Erzfelder als Flecken) und baut die 3D-Meshes.
- `src/camera.js` ist die Kamera-Steuerung.
- `src/main.js` verbindet Szene, Licht, Hover-Anzeige und HUD.
