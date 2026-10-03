# Bolla

I am new Vibecoder and try my Best

Ein kleines **3D-Third-Person-Spiel in Unity**: Du steuerst eine Figur durch ein Level,
sammelst alle goldenen Münzen ein und weichst den roten Gegnern aus.

| Taste | Aktion |
|---|---|
| W A S D | Laufen |
| Shift | Rennen |
| Leertaste | Springen |
| Maus | Kamera drehen |
| R | Neustart |
| Esc | Maus freigeben (Linksklick fängt sie wieder ein) |

---

## Anleitung für Anfänger

### 1. Unity installieren

1. Lade den **Unity Hub** herunter: <https://unity.com/download>
2. Öffne den Hub und melde dich an (ein kostenloses Konto reicht, „Personal“-Lizenz).
3. Gehe links auf **Installs → Install Editor** und installiere die empfohlene
   **Unity 6** Version (LTS).
4. Wenn du gefragt wirst, kannst du **Visual Studio** (Windows) oder
   **Visual Studio Code** mitinstallieren – damit bearbeitest du später die Skripte.

### 2. Neues Projekt anlegen

1. Im Unity Hub: **Projects → New project**.
2. Vorlage **„Universal 3D“** (oder „3D (URP)“) auswählen.
3. Einen Namen eingeben, z. B. `Bolla`, und auf **Create project** klicken.
   Das dauert beim ersten Mal ein paar Minuten.

### 3. Die Skripte aus diesem Repository ins Projekt kopieren

1. Lade dieses Repository herunter (auf GitHub: grüner Button **Code → Download ZIP**)
   und entpacke es.
2. Kopiere den Ordner **`Assets/Scripts`** aus dem ZIP in den Ordner **`Assets`**
   deines Unity-Projekts.
   (Du findest ihn, wenn du in Unity unten im **Project**-Fenster mit Rechtsklick
   auf `Assets` → **Show in Explorer** / **Reveal in Finder** gehst.)
3. Wechsle zurück zu Unity. Es lädt die Skripte automatisch (unten rechts dreht sich kurz ein Kreis).

### 4. Das Level mit einem Klick erstellen

1. Oben in der Menüleiste gibt es jetzt einen neuen Punkt **Spiel**.
2. Klicke auf **Spiel → Demo-Level erstellen**.
3. Unity baut jetzt automatisch Boden, Plattformen, Spielfigur, Kamera, Münzen
   und Gegner und speichert alles als Szene `Assets/Scenes/DemoLevel.unity`.

### 5. Spielen!

Drück oben in der Mitte auf den **▶ Play**-Button. Klick einmal ins Spielfenster,
damit die Maus eingefangen wird. Zum Beenden nochmal auf **▶** drücken.

---

## Was macht welches Skript?

Alle Skripte liegen in `Assets/Scripts` und sind auf Deutsch kommentiert.

| Datei | Aufgabe |
|---|---|
| `PlayerController.cs` | Bewegt die Figur (Laufen, Rennen, Springen, Schwerkraft) und setzt sie zurück, wenn sie herunterfällt. |
| `ThirdPersonCamera.cs` | Kamera folgt der Figur, dreht sich mit der Maus und rutscht nicht durch Wände. |
| `Collectible.cs` | Eine Münze: dreht sich, schwebt, verschwindet beim Einsammeln. |
| `Hazard.cs` | Ein Gegner, der hin- und herfährt. Berührung = zurück zum Start. |
| `GameManager.cs` | Zählt Münzen und Zeit, zeigt alles auf dem Bildschirm, erkennt den Sieg. |
| `Editor/DemoLevelBuilder.cs` | Der Menüpunkt **Spiel → Demo-Level erstellen**. Läuft nur im Editor, nicht im fertigen Spiel. |

## Erste eigene Änderungen (zum Ausprobieren)

Du musst dafür keinen Code ändern:

1. Klick im **Hierarchy**-Fenster (links) auf **Spieler**.
2. Rechts im **Inspector** siehst du beim Skript *Player Controller* Werte wie
   `Walk Speed`, `Jump Height` oder `Gravity`. Ändere sie und drück Play.
3. Genauso kannst du bei **Main Camera** den Abstand (`Distance`) oder die
   Mausempfindlichkeit einstellen.
4. Neue Münzen: Eine **Muenze** in der Hierarchy auswählen, **Strg+D** (Mac: Cmd+D)
   zum Duplizieren, dann mit dem Verschiebe-Werkzeug (Taste **W**) woanders hinziehen.
5. **Strg+S** speichert die Szene.

> Tipp: Änderungen, die du **während** Play machst, werden beim Beenden zurückgesetzt!

## Hilfe bei Problemen

**Fehler: „InvalidOperationException: You are trying to read Input using the
UnityEngine.Input class, but you have switched active Input handling to Input System package“**

Die Skripte benutzen das klassische Eingabesystem. So schaltest du es ein:
**Edit → Project Settings → Player → Other Settings → Active Input Handling** auf
**„Both“** stellen. Unity startet danach neu.

**Der Menüpunkt „Spiel“ erscheint nicht**

Dann gibt es einen Fehler in den Skripten. Öffne **Window → General → Console** und
schau dir die roten Meldungen an. Prüfe auch, ob der Ordner `Editor` wirklich
innerhalb von `Assets/Scripts` liegt.

**Alles ist pink**

Das Projekt nutzt eine andere Render-Pipeline als erwartet. Lösche den Ordner
`Assets/Materials` und führe **Spiel → Demo-Level erstellen** noch einmal aus.

**Beim Drücken von R passiert nichts**

Die Szene muss in den Build-Einstellungen stehen. Das macht der Menüpunkt automatisch;
falls du eine eigene Szene gebaut hast: **File → Build Profiles** (bzw. Build Settings)
→ **Add Open Scenes**.

## Ideen für danach

- Einen Zielpunkt bauen, der erst nach allen Münzen erscheint
- Soundeffekte beim Einsammeln (`AudioSource.PlayClipAtPoint`)
- Ein echtes Charaktermodell mit Animationen aus dem
  [Unity Asset Store](https://assetstore.unity.com) (z. B. die kostenlosen „Starter Assets“)
- Mehrere Level und ein Hauptmenü
