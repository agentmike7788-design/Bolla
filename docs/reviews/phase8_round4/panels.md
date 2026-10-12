# G8 Runde 4 – Arbeits-Panels wie der Leichentisch

Benutzerentscheidung: „Ja" auf die Frage, ob Präparierpult und Werkbank dasselbe Verhalten wie das Tisch-Panel bekommen sollen (`runde4_tisch_lieferung.md` §1). Dazu sollten alle anderen Panels geprüft werden, in denen der Totengräber eine zeitgesteuerte Arbeit startet, während das Panel offen ist.

Alle Bilder stammen aus dem echten Spiel in 1280 × 720: neues Spiel, Tag 1, echte Systeme. Bilder ohne Endung sind mit Forward+ aufgenommen, Bilder mit `_web` im Compatibility-Renderer (`--rendering-method gl_compatibility --rendering-driver opengl3`, so sieht es im Browser aus).

**Ablauf der Aufnahmen:**
- Die Station wird so hergerichtet, wie das Spiel sie hinterlässt:
  - Esse, Steinmetzbank und Pult gebaut (Workshop-Stand + `refresh_built`)
  - die Zutaten eines Rezepts in der Tasche
  - für den Stein ein gefülltes Grab (`plot_02`)
  - für das Pult eine Leber aus Osrics erster Leiche (als Bündel)
- Das Panel öffnet sich wie beim Spieler: `interact` der Station, beim Pult über den Knopf „Präparate und Arzneien".
- Die Arbeit startet über das `pressed`-Signal ihres Knopfs. Figur und Clip laufen in 60-Hz-Schritten bis 70 % der Arbeit, also nach dem Ziehen des Werkzeugs.

Erzeugt mit `tools/godot_run.sh --resolution 1280x720 -s res://src/world/graveyard/graveyard_shots.gd -- --out=<dir> --round4=panels --tag=vorher|nachher [--suffix=_web] [--shots=werkbank,schmiede,steinmetz,pult]` (Modul `graveyard_shots_panels.gd`). Die Vorher-Bilder entstanden mit den Panel-Skripten von `630929a` in einer Kopie des Projekts.

## 1. Prüfung aller Panels

Spalte „Arbeit bei offenem Panel": Läuft eine zeitgesteuerte Arbeit des Totengräbers, während das Panel offen ist?

| Panel | Arbeit bei offenem Panel | vorher | nachher |
|---|---|---|---|
| **Leichentisch** `corpse_exam` | ja: Untersuchen, Herrichten, Verwerten, Präparate | (Runde 4) rechts angedockt, ~650 px, ohne Abdunklung, während der Arbeit ausgeblendet | unverändert. Die Hilfsfunktionen zum Andocken liegen jetzt in `UIPanel` und werden geteilt. |
| **Werkbank** `crafting` (Station `workbench`) | ja: Herstellen (Säge), „Fehlendes holen" | mittig, 900 px, Abdunklung; das Panel bleibt mit eigenem Balken offen und verdeckt die Figur an der Bank | **rechts angedockt, einspaltig 650 px, ohne Abdunklung, Liste rollt; während der Arbeit ausgeblendet**, danach Fokus auf dem zuletzt benutzten Rezept |
| **Esse / Schmiede** `crafting` (Station `forge`) | ja: Schmieden (Hammer), Meiler stapeln, „Fehlendes holen" | wie Werkbank | wie Werkbank (dasselbe Panel) |
| **Webstuhl** `crafting` (Station `loom`) | ja: Weben | wie Werkbank | wie Werkbank (dasselbe Panel, ohne eigenes Bild) |
| **Präparierpult** `crafting` (Station `pult`) → `pult` | ja: Einlegen, Schau-/Knochenpräparat, Begutachten, Arzneien, „Fehlendes holen" | erste Karte wie Werkbank; zweite Karte mittig, zweispaltig, 1500 px, Abdunklung; bleibt mit Balken offen | beide Karten **rechts angedockt, einspaltig 650 px** (Präparate → Handgriffe → Arzneien, Inhalt rollt), ohne Abdunklung; **während der Arbeit ausgeblendet**, danach Fokus auf dem ersten freien Knopf |
| **Steinmetzbank** `stone_design` | ja: „Stein hauen" (50–205 Min, 2,5–4 s real), „Fehlendes holen", Namenstafel | mittig, drei Pergamentseiten (~1700 px), Abdunklung; bleibt beim Hauen offen und verdeckt Bank und Figur | **während der Arbeit ausgeblendet**, der Totengräber meißelt sichtbar, danach zurück mit Fokus. **Die Aufteilung bleibt mittig**, siehe unten. |
| **Bauplatz** `build_site` (Werkhof) | „Bauen" schließt das Panel schon vor der Arbeit. Nur „Fehlendes holen" (10 Min, ab Schuppen 2) lief bei offenem Panel. | mittig, 860 px | mittig. **Während „Fehlendes holen" ausgeblendet** |
| **Gebäude** `building` (Ausbau Hütte/Gruft/Kapelle/Schuppen) | „Stufe … bauen" schließt das Panel vorher. Nur „Fehlendes holen" lief bei offenem Panel. | mittig, 1560 px | mittig. **Während „Fehlendes holen" ausgeblendet** |
| Kapelle: Totenmesse `chapel`, Andacht `devotion` | nein, das Panel schließt vor der Arbeit | mittig | unverändert |
| Grabzeichen-Wahl `marker_choice` | nein, schließt vor dem Setzen | mittig | unverändert |
| Gruft-Nischen | kein Panel (Ablegen/Herausnehmen direkt mit E) | – | unverändert |
| Beinhaus (Umbetten) | kein Panel (Arbeit direkt mit E) | – | unverändert |
| Truhe / Lehrlingskiste `chest` | nein, Umlagern geht sofort | mittig | unverändert |
| Regale / Sammlung `collection` | nein, Einstellen/Herausnehmen geht sofort | mittig | unverändert |
| Archiv (Schrank) | kein Panel (Arbeit direkt mit E) | – | unverändert |
| Grabregister am Schreibpult `grave_register` | nein, reines Lesefenster. Die Abschrift startet direkt mit E, ohne Panel. | mittig | unverändert |
| Quast `anatomist` (Gutachten 30 Min) | ja, aber es ist ein Handelsfenster. Der Totengräber wartet am Tresen (Clip `idle`), es ist keine Arbeit zu sehen. | mittig | unverändert (siehe Offen) |
| Vorlesung `lecture` (60 Min) | ja, aber der Schleier mit dem Vorlesungstext ist selbst der Inhalt (Clip `idle`) | mittig | unverändert |
| Inventar, Laden, Geschenk, Aufträge, Händlerin, Merkbuch, Karte, Kreidetafel, Wunschkarte, Gefallen, Fest, Deuten, Tages-/Kapitelabschluss, Friedhofsübersicht, Pause | nein (Lese-, Handels- oder Dialogfenster) | mittig | unverändert |

**Warum die Steinmetzbank mittig bleibt:**
- Der Entwurf ist eine Gestaltungsarbeit auf drei Seiten nebeneinander: Gräber, Gestaltung mit 3 + 9 + 5 Karten und eine Vorschau mit eigenem 3D-Bild (500 × 300). Die Mittelseite allein ist schon 660 px breit.
- Für eine schmale Spalte müssten die Seiten zu Reitern umgebaut werden. Das wäre ein eigener Umbau des Layouts mit seinen Tests in `test_ui_phase5.gd`.
- Während des Entwerfens arbeitet die Figur nicht. Beim Hauen, wo man sie sehen will, ist das Panel jetzt weg. Ein Umbau zu Reitern bleibt Benutzerentscheidung.

## 2. Umsetzung

- **`UIPanel`:**
  - `fit_dock_scroll(scroll, content, cap)` und `make_dock_scroll(parent, sep)` sind die Rollfläche eines angedockten Panels. Die Höhe richtet sich nach dem Inhalt, höchstens nach dem, was der Bildschirm neben Kopf, Balken und Knöpfen übrig lässt. Die Fläche folgt dem Tastaturfokus.
  - `reveal(control)`: Nach einem Neuaufbau der Zeilen kann der Fokus auf einem Knopf außerhalb der sichtbaren Fläche liegen, weil `follow_focus` nur bei einem Fokuswechsel greift. Dann rollt das Panel so, dass die ganze Zeile dieses Knopfs zu sehen ist.
  - `CorpseExamPanel` nutzt jetzt dieselben Funktionen, sein Verhalten ist unverändert.
- **`CraftingPanel`:**
  - `dock_right` und `hide_while_working`, `panel_width` 900 → 650.
  - Jede Rezeptzeile ist jetzt einspaltig: Bild, dann Name, Zutaten als fließende Reihe (`HFlowContainer`), Details mit Umbruch, Grund und die Knöpfe „Fehlendes holen" und „Herstellen" rechtsbündig darunter.
  - „Überschuss einlagern" hat eine eigene Zeile.
  - Ein Panel dient allen Stationen. Beim Öffnen steht die Liste deshalb wieder oben, vorher blieb die Rollposition der letzten Station stehen.
- **`PultPanel`:**
  - `dock_right` und `hide_while_working`, `panel_width` 1500 → 650.
  - Eine Spalte in einer Rollfläche: Präparate, dann Trennlinie, gewähltes Stück, Handgriffe (Knöpfe gleich breit, 320 px, daneben der Grund) und Arzneien. In den Rezeptkarten steht der Grund über den Knöpfen, Zutaten und Bedarf brechen um.
- **`StoneDesignPanel`, `BuildSitePanel`, `BuildingPanel`:** nur `hide_while_working`.
- **Unverändert:** `UIRoot` (`_update_dim`, Andocken über `dock_right`) und `GameHud.set_work_view` aus Runde 4 tragen alles. Steht das Pult über der ersten Karte, bleibt diese während und nach der Arbeit verdeckt.

**Bedienung:**
- Das Panel bleibt während der Arbeit modal, es ist also keine andere Interaktion möglich.
- Esc schließt es auch während der Arbeit.
- Danach liegt der Fokus wieder im Panel: bei der Werkbank auf dem zuletzt benutzten Rezept, sonst auf dem ersten freien Knopf. Maus und Enter funktionieren wie vorher.

## 3. Bilder

| Bild | Inhalt |
|---|---|
| `panel_werkbank_vorher(_web).jpg` / `panel_werkbank_vorher_arbeit(_web).jpg` | vorher: Werkbank-Panel mittig (900 px) über der Figur. Während „Räucherkräuter binden" bleibt es mit Balken offen. |
| `panel_werkbank_nachher(_web).jpg` / `panel_werkbank_nachher_arbeit(_web).jpg` | nachher: rechts, die Figur an der Bank frei. Während der Arbeit nur der HUD-Balken, der Totengräber arbeitet frei sichtbar an der Bank (Clip `saw`). |
| `panel_schmiede_vorher(_web).jpg` / `…_arbeit` | vorher: Esse-Panel mittig, auch während „Beschläge schmieden" |
| `panel_schmiede_nachher(_web).jpg` / `…_arbeit` | nachher: rechts, Liste oben, Fokus auf „Herstellen". Während des Schmiedens steht er frei sichtbar an der Esse (Clip `hammer`). |
| `panel_steinmetz_vorher(_web).jpg` / `…_arbeit` | vorher: drei Seiten über der ganzen Bildbreite, auch während „Stein hauen" |
| `panel_steinmetz_nachher(_web).jpg` / `…_arbeit` | nachher: Entwurf unverändert mittig. Während „Stein hauen" ist das Panel weg, er arbeitet frei sichtbar an der Bank (Clip `chisel`). |
| `panel_pult_vorher(_web).jpg` / `…_arbeit` | vorher: Pult-Karte zweispaltig über 1500 px, verdeckt Pult und Figur, auch während „Einlegen" |
| `panel_pult_nachher(_web).jpg` / `…_arbeit` | nachher: rechts, einspaltig, Pult und Figur frei. Während „Einlegen" nur der HUD-Balken. |
| `panels_uebersicht(_web).jpg` | Kontaktbogen aller 16 Bilder: je Zeile ein Panel, Spalten vorher offen · vorher Arbeit · nachher offen · nachher Arbeit |

## Tests

- **`test_ui.gd::test_every_panel_opens_and_closes`:** Angedockt sind genau `corpse_exam`, `crafting` und `pult`, sie haben keine Abdunklung, alle anderen sind abgedunkelt. `hide_while_working` haben genau die sechs Arbeits-Panels.
- **`test_ui.gd::test_crafting_docked_and_hidden_while_working` (neu):**
  - rechts angedockt, Mitte frei, unter 700 px, auf dem Bildschirm, alle Knöpfe innerhalb der Spalte
  - Enter auf dem fokussierten Rezept, ausgeblendet während der Arbeit mit HUD-Balken, weiter modal
  - danach Fokus auf demselben Rezept, Mausklick auf ein anderes Rezept (vorher in Sicht gerollt)
  - Esc während der Arbeit
  - erneutes Öffnen: Liste oben, fokussierter Knopf sichtbar
- **`test_ui.gd::test_other_work_panels_hidden_while_working` (neu):** Steinmetzbank, Bauplatz und Gebäude bleiben mittig und abgedunkelt, sind während der Arbeit ausgeblendet und haben danach Abdunklung und Fokus zurück.
- **`test_ui_phase7.gd::test_pult_docked_and_hidden_while_working` (neu):**
  - echtes `Specimens` mit einer Leber
  - angedockt, Rollfläche, die erste Karte darunter nicht gezeichnet
  - Enter auf „Einlegen" (der Spieler-Double hält die Arbeit an), ausgeblendet mit HUD-Balken
  - nach dem Ende versiegelt, Fokus im Panel, Mausklick auf das Stück
  - Esc zurück zur ebenfalls angedockten ersten Karte
- **`test_ui_phase3.gd::test_workbench_groups_and_decor_hint`:** Die Zeile des Rezepts wird jetzt über den nächsten `PanelContainer` gesucht, weil der Knopf in der neuen Zeile tiefer liegt.
- **Volle Suite:** siehe QA-Protokoll in `docs/QUALITY_GATE_STATUS.md`.

## Offen

- **Steinmetzbank:** Bleibt beim Entwerfen mittig mit Abdunklung (siehe §1). Ob sie als schmale Spalte mit Reitern Gräber · Gestaltung · Vorschau neu aufgebaut werden soll, entscheidet der Benutzer.
- **Quasts Gutachten** (`anatomist`): Es bleibt offen, während der Totengräber 30 Minuten am Tresen wartet. Dort ist keine Arbeitsbewegung zu sehen. Ausblenden wäre eine Zeile (`hide_while_working = true`), falls gewünscht.
- **Angedockte Panels und HUD:** Sie liegen wie das Tisch-Panel über dem rechten Rand der HUD-Leiste oben rechts (Münzen, Holz …). Das war in Runde 4 schon so.
- **Vertrag:** `docs/VERTICAL_SLICE_DESIGN.md` (Zeile `&"crafting"`) und `docs/PHASE7_DESIGN.md` (Pult-Panel) sind „(G8 Runde 4 angepasst)". Die Benutzerbestätigung steht aus.
