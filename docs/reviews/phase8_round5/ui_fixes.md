# G8 Runde 5 – die bekannten UI-Probleme

Benutzerauftrag: „bitte die bekannten probleme mal fixen". Gemeint sind die drei offenen Punkte aus Runde 4 (`docs/reviews/phase8_round4/panels.md`, Abschnitt „Offen"):

1. Die Steinmetzbank stand beim Entwerfen breit in der Mitte (drei Seiten, ~1700 px, Abdunklung) und verdeckte die Welt.
2. Angedockte Fenster lagen über dem rechten Teil der HUD-Leiste (Münzen, Vorräte, Friedhofsqualität, Ruf).
3. Quasts Gutachten (und gleichartig die Vorlesung) ließ das Fenster die ganze Arbeit über offen.

Alle Bilder stammen aus dem echten Spiel:

- Bilder ohne Endung: Forward+.
- Bilder mit `_web`: Compatibility-Renderer (`--rendering-method gl_compatibility --rendering-driver opengl3`), so sieht es im Browser aus.
- Fenstergröße 1280 × 720, sofern der Name nichts anderes sagt (`_1366` = 1366 × 768, `_1024` = 1024 × 768, `_1920` = 1920 × 1080).

Die Vorher-Bilder entstanden mit dem Stand `3a75fb3` in einer Kopie des Projekts, ergänzt nur um die neuen Aufnahme-Skripte.

**Aufnahme:**

- Friedhof: `tools/godot_run.sh --resolution 1280x720 -s res://src/world/graveyard/graveyard_shots.gd -- --out=<dir> --round5=ui --tag=vorher|nachher [--shots=steinmetz,hud] [--suffix=_web]`
  - Modul `graveyard_shots_round5.gd`, aufgebaut wie die Panel-Aufnahmen aus Runde 4.
  - Neues Spiel, Tag 1. Stationen gebaut, ein gefülltes Grab für den Stein, die Zutaten in der Tasche.
  - Das Panel öffnet sich über `interact` der Station. „Stein hauen" startet über das `pressed`-Signal des Knopfs, dann laufen Figur und Clip in 60-Hz-Schritten bis 70 % der Arbeit.
- Quast: `tools/godot_run.sh --resolution 1280x720 -s res://src/world/village/village_shots_quast.gd -- --out=<dir> --tag=vorher|nachher [--suffix=_web]`
  - Ausgangsstand ist das Phase-7-Ende (`saves_v6/slot_p7_day53_neighbor`). Die Uhr läuft bis Tag 54, 10:00, Quast steht nach seinem Zeitplan in der Wundarztstube.
  - Ein Herz im Glas wird über `Specimens.harvest` angelegt, die Zutaten liegen in der Tasche.
  - Das Panel öffnet sich wie aus Quasts Dialog (`&"anatomist"` mit Sprecher). „Gutachten" wird gedrückt, dann wird bis 70 % der Arbeit geschritten, danach bis zum Ende.

## 1. Steinmetzbank als angedockte Spalte mit Reitern

**Vorher:** drei Pergamentseiten nebeneinander:

- Gräber: 470 px
- Gestaltung: 660 px
- Vorschau: 540 px

Zusammen ~1700 px, mittig und abgedunkelt. Beim Hauen war das Panel seit Runde 4 schon ausgeblendet.

**Nachher:** rechts angedockt wie die anderen Arbeits-Panels, eine Pergamentspalte von 660 px, ohne Abdunklung, unter der HUD-Leiste. Von oben nach unten:

- **Kopf:** „Steinmetzbank", „Ablage: 0/3 fertig", ✕.
- **Vorschau** (bleibt immer sichtbar): der 3D-Stein verkleinert auf 230 × 210, daneben „Grab 6 → 11", „Stein: 5 von 9 Punkten" und die Aufschlüsselung („Schlichte Stele +3", „Inschrift +1" …).
- **Reiter** `[Q]` **Grab · Form · Inschrift · Zierde** `[E]`:
  - **Grab:** Gräberliste mit Filter „ohne Namen zuerst" und Seitenzahl, darunter „Fertige Steine" mit „Verwerfen".
  - **Form:** die drei Formkarten.
  - **Inschrift:** „Inschrift für …", der Text des gewählten Spruchs, der Schalter „vergoldet · Blattgold: n" und die Spruchkarten in zwei Spalten.
  - **Zierde:** „ohne" und die vier Zierden.
  - Die Reiterseite rollt. Sie ist so hoch wie die höchste der vier Seiten, so springt das Panel beim Reiterwechsel nicht in der Höhe.
- **Fuß:** „Material: Stein 4/4 · Holundertinte 1/1", Minuten mit „Stein hauen (70 Min)" daneben, der Sperrgrund, die Schuppen-Zeile (der Grund bricht um) und darunter die weitere Arbeit der Bank (Namenstafel nach Rosine 2).
- **Hinweiszeile:** „Pfeile + Enter wählen · [ / ] Gräber blättern · [Esc] schließen".
- Jedes Öffnen beginnt auf dem Reiter „Grab". Beim Hauen bleibt das Panel wie in Runde 4 ausgeblendet, der HUD-Balken zeigt die Arbeit.

**Bedienung:**

- **Maus:** Klick auf Reiter und Karten wie bisher.
- **Q / E:** voriger und nächster Reiter, mit Umlauf. Dafür werden die vorhandenen Aktionen `drop` (Q) und `interact` (E) genutzt. Es gibt keine neue Eingabe-Aktion (PHASE5 §3.6). Das E erreicht dabei nicht die Welt.
- **Pfeiltasten:** wechseln zwischen den Karten. Alle Karten, Reiter, „vergoldet", „ohne Namen zuerst", „Verwerfen" und „Stein hauen" nehmen jetzt den Fokus, vorher hatten die Karten keinen Fokus.
- **Enter:** wählt die fokussierte Karte. Der Fokus bleibt nach dem Neuaufbau auf derselben Karte und wird in Sicht gerollt.
- **[ / ]:** blättern die Gräber und holen dabei den Reiter „Grab" zurück.
- **Esc:** schließt das Panel, auch während der Arbeit.
- **Fokusrahmen:** ein Bernstein-Rahmen auf dem Pergament. Neue Theme-Varianten `LedgerCardButton`/`LedgerCardSelected`, `LedgerTabButton`/`LedgerTabSelected` und `LedgerInkButton` erben von den Merkbuch-Varianten und setzen nur `focus`. Dazu kommt `LedgerColumnPanel`, ein Pergamentblatt mit schmalen Rändern. Das Merkbuch selbst ist unverändert.

| Bild | Inhalt |
|---|---|
| `steinmetz_vorher(_web).jpg` | vorher: drei Seiten über die ganze Bildbreite, Welt abgedunkelt |
| `steinmetz_vorher_arbeit(_web).jpg` | vorher: beim Hauen ausgeblendet (seit Runde 4) |
| `steinmetz_nachher(_web).jpg` | nachher: angedockt, Reiter „Grab", Bank, Figur und Gräber frei |
| `steinmetz_nachher_form / _inschrift / _zierde(_web).jpg` | nachher: die anderen drei Reiter, gleiche Panelhöhe |
| `steinmetz_nachher_arbeit(_web).jpg` | nachher: beim Hauen ausgeblendet, nur der HUD-Balken |

## 2. Angedockte Fenster unter der HUD-Leiste

**Gewählte Lösung:** Die Fenster beginnen unter der Ressourcen-Leiste. Die Leiste rückt nicht zur Seite.

Begründung:

- Die Leiste bleibt dort, wo der Spieler sie sucht.
- Ein Verschieben nach links hätte sie über die Bildmitte gelegt, also über die Figur bei der Arbeit. Neben dem Zeitblock links (588 px) und einem 650-px-Fenster bleiben bei 1920 px nur ~660 px, und die Leiste wird mit hergestellten Dingen breiter.
- Mit `stretch_aspect = expand` ist die Leinwand immer mindestens 1920 × 1080: bei 4:3 höher (1920 × 1440), bei 1366 × 768 gleich groß. Unter der Leiste bleiben bei 1080 px Höhe noch 854 px für das Fenster.

**Umsetzung:**

- `GameHud.resource_panel` und `GameHud.dock_bottom()` geben die Unterkante der Leiste an.
- `UIRoot.dock_top()` = Unterkante + `DOCK_GAP` (16 px), mindestens `DOCK_MARGIN`.
- `UIKit.docked_right(child, margin, top)` setzt den oberen Rand. Das Fenster hängt von dort nach unten (`SIZE_SHRINK_BEGIN`, vorher senkrecht mittig).
- `UIPanel.dock_top` / `set_dock_top()`: Die Rollfläche bekommt die Höhe von dort bis `DOCK_MARGIN` über dem unteren Rand (`dock_scroll_room`, `fit_dock_scroll`). Wächst die Leiste, etwa weil ein Leichentuch mit Beschriftung dazukommt, oder ändert sich das Fenster (`resized`, `size_changed`), folgen alle angedockten Panels (`UIRoot._update_docks`, virtuell `UIPanel._fit_dock`).
- Die Meldungsspalte (oben rechts, unter der Leiste) steht, solange ein angedocktes Panel sichtbar ist, links daneben. So verdeckt keine Meldung den Kopf des Panels. Ohne Panel steht sie wieder am Rand.
- Gilt für alle angedockten Fenster: Leichentisch, Werkbank/Esse/Webstuhl (ein Panel), Präparierpult, Steinmetzbank, Wundarzt, Vorlesung.

| Bild | Inhalt |
|---|---|
| `hud_vorher(_web).jpg` | vorher: das Werkbank-Panel liegt über Münzen, Holz, Stein, Leinen, Qualität und Ruf |
| `hud_nachher(_web).jpg` | nachher 1280 × 720: Leiste frei, das Panel beginnt darunter, die Liste rollt |
| `hud_nachher_steinmetz(_web).jpg` | nachher 1280 × 720: die Steinmetzbank unter der Leiste |
| `hud_nachher_1366(_web).jpg`, `hud_nachher_steinmetz_1366(_web).jpg` | nachher 1366 × 768 (Browserfenster) |
| `hud_nachher_1024(_web).jpg`, `hud_nachher_steinmetz_1024(_web).jpg` | nachher 1024 × 768 (4:3, die Leinwand ist höher, die Panels sind länger) |
| `hud_nachher_1920_web.jpg`, `hud_nachher_steinmetz_1920_web.jpg` | nachher 1920 × 1080 im Browser-Look |

Bei den HUD-Bildern mit Steinmetzbank fehlt das Material in der Tasche („Es fehlt: 4 Stein, 1 Holundertinte"), denn dieser Satz gibt nur der Werkbank ihre Zutaten. Die Zeile zeigt zugleich den Sperrgrund im Fuß.

## 3. Quasts Gutachten und die Vorlesung

**Vorher:**

- Wundarzt-Panel `anatomist`: 1300 px mittig mit Abdunklung. Während der 30 Minuten blieb es offen, mit eigenem Balken „Quast sieht es sich an …".
- Vorlesung `lecture`: 1180 px mittig, blieb unter dem Schleier offen.

**Nachher:**

- **Wundarzt:** rechts angedockt, einspaltig 650 px, ohne Abdunklung, unter der HUD-Leiste.
  - Jede Zeile hat zwei Zeilen: Glas-Icon, „Herz – Name, Alter", Klarheit und Preis, darunter rechtsbündig die Knöpfe „Verkaufen", „Gutachten" und am Vorlesungsabend „Für die Vorlesung" (umbrechend).
  - Liste, Ergebnis-Karte und Quasts Antwort rollen.
  - Während des Gutachtens ist das Panel ausgeblendet (`hide_while_working`). Der Totengräber steht frei sichtbar am Tresen, der HUD-Balken zeigt die Arbeit, das Panel bleibt modal.
  - Danach kommt es mit der Ergebnis-Karte zurück. Der Fokus liegt auf dem ersten „Gutachten", sonst auf „Schließen", nie auf „Verkaufen".
- **Vorlesung:** ebenso angedockt (650 px), jede Präparatzeile zweizeilig, gewähltes Stück und Grund über den Knöpfen.
  - Während der Vorlesung ausgeblendet: Der Schleier mit Quasts Vortrag und der HUD-Balken sind die Ansicht.
  - Danach kommt sie mit der Ergebnis-Karte zurück.

**Prüfung aller Fenster mit zeitgesteuerter Arbeit bei offenem Fenster:** Gesucht wurde nach `start_timed_action` in `src/ui` und nach Stations-Aufrufen, die eine Arbeit starten.

- **Leichentisch, Werkbank/Esse/Webstuhl, Präparierpult, Steinmetzbank:** angedockt und ausgeblendet (Runde 4 bzw. jetzt).
- **Bauplatz, Gebäude:** ausgeblendet bei „Fehlendes holen" („Bauen" schließt vorher), mittig.
- **Wundarzt, Vorlesung:** jetzt angedockt und ausgeblendet.
- **Kapelle (Totenmesse, Andacht), Grabzeichen-Wahl:** schließen vor der Arbeit.
- **Alle übrigen** (Laden, Geschenk, Aufträge, Truhe, Sammlung, Deuten, Register …): starten keine zeitgesteuerte Arbeit.

Damit verhält sich jedes Fenster gleich, das während einer zeitgesteuerten Arbeit offen wäre.

| Bild | Inhalt |
|---|---|
| `quast_vorher(_web).jpg` | vorher: Wundarztstube, Panel 1300 px mittig, abgedunkelt |
| `quast_vorher_arbeit(_web).jpg` | vorher: das Panel bleibt während des Gutachtens offen, mit eigenem Balken |
| `quast_vorher_danach(_web).jpg` | vorher: Ergebnis |
| `quast_nachher(_web).jpg` | nachher: rechts angedockt unter der HUD-Leiste, Quast und der Totengräber frei |
| `quast_nachher_arbeit(_web).jpg` | nachher: während des Gutachtens ausgeblendet, nur der HUD-Balken |
| `quast_nachher_danach(_web).jpg` | nachher: zurück mit der Ergebnis-Karte |
| `ui_fixes_uebersicht(_web).jpg` | Kontaktbogen (16 Bilder, je Renderer einer). Zeilen: Steinmetz vorher/nachher mit Arbeit · die drei anderen Reiter und Steinmetz unter dem HUD · HUD vorher/nachher bei 1280, 1366, 1024 · Quast vorher/nachher mit Gutachten |

Hinweis zum Wundarzt-Bild: Die Raumkamera folgt dem Totengräber. Am Tresen steht er rechts im Bild, deshalb liegt das angedockte Panel beim Auswählen über ihm. Während des Gutachtens ist das Panel weg, er ist frei zu sehen.

## Tests

- **`test_ui.gd`:**
  - `DOCKED_PANELS` umfasst jetzt auch `stone_design`, `anatomist` und `lecture`, `WORK_PANELS` zusätzlich `anatomist` und `lecture`. `test_every_panel_opens_and_closes` prüft Andocken, Abdunklung und Ausblenden je Panel.
  - `test_other_work_panels_hidden_while_working` prüft nur noch Bauplatz und Gebäude (mittig).
  - `_check_docked` prüft zusätzlich den Abstand zum HUD.
  - **Neu `test_docked_panels_below_the_hud_at_every_size`:** Bei 1280 × 720, 1920 × 1080, 1366 × 768 und 1024 × 768 öffnet jedes angedockte Panel. Geprüft wird:
    - es beginnt `DOCK_GAP` unter der Leiste und überdeckt sie nicht
    - es endet über `DOCK_MARGIN`
    - es steht am rechten Rand, die Mitte bleibt frei
    - die Meldungsspalte steht daneben und ohne Panel wieder am Rand
    - wächst die Leiste (Leichentuch), rückt das Panel nach
- **`test_ui_phase5.gd`, neu `test_stone_panel_docked_with_tabs_and_keyboard`:**
  - Andocken: unter 700 px, unter dem HUD, ohne Abdunklung
  - Vorschau oben in der Spalte, ≥ 200 × 180
  - Start auf „Grab" mit Fokus auf dem gewählten Grab
  - E/Q mit Umlauf, das E erreicht nicht die Welt
  - Pfeil rechts und Enter auf einer Form: der Fokus bleibt
  - Pfeil runter und Enter bei den Inschriften: die Karte bleibt in Sicht
  - gleiche Höhe über alle Reiter
  - Mausklick auf Reiter und Karte, die Vorschau folgt
  - alle Knöpfe jedes Reiters in der Spalte
  - `]` holt den Reiter „Grab" zurück
  - ausgeblendet während „Stein hauen" (Q/E wirken dann nicht), danach Fokus zurück
  - Esc schließt
- **`test_ui_phase7.gd`:**
  - **Neu `test_anatomist_and_lecture_docked_and_hidden_while_working`:**
    - beide angedockt unter dem HUD, Knöpfe in der Spalte
    - Enter auf „Gutachten" blendet das Panel aus (HUD-Balken, modal)
    - zurück mit Ergebnis-Karte und Fokus
    - Esc während eines zweiten Gutachtens schließt
    - Vorlesung per Mausklick gehalten, ausgeblendet unter dem Schleier, zurück mit Ergebnis
  - `test_pult_docked_and_hidden_while_working` prüft zusätzlich den Abstand zum HUD.
- **Volle Suite:** 2982/2982 grün.

## Vertrag

„(G8 Runde 5 angepasst)" steht in:

- `docs/PHASE5_DESIGN.md`: §3.6 Eingaben (Q/E über `drop`/`interact`) und §7 Stein-Panel
- `docs/VERTICAL_SLICE_DESIGN.md`: Zeile `&"crafting"` (Andocken unter der HUD-Leiste für alle angedockten Panels)
- `docs/PHASE7_DESIGN.md`: Wundarzt-Panel und Vorlesung

## Offen

- Die Benutzerprüfung steht aus, insbesondere für Q/E als Reitertasten. Q ist sonst „Ablegen", E „Interagieren"; im offenen Panel greifen beide nicht in die Welt.
- Der Fokusrahmen ist nur zu sehen, wenn mit der Tastatur bedient wird. Auf den Bildern ist die Maus-Bedienung zu sehen. Dass er auf Karten, Reitern und „Stein hauen" gesetzt ist, prüft der Test.
- In Quasts Stube steht der Totengräber am Tresen rechts im Bild. Das angedockte Panel liegt deshalb beim Auswählen über ihm, nicht aber während des Gutachtens. Ob die Raumkamera dort anders rahmen soll, entscheidet der Benutzer.
