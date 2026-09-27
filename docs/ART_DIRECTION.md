# Art Direction Document

Status: **FREIGEGEBEN (27.09.2026) – ART STYLE LOCK = ACTIVE**
Referenz-Szene: `src/world/art_prototype/art_prototype.tscn` · Referenz-Screenshots: `docs/reviews/phase1_round1/`
Verantwortlich: Agent 04 (Art Director) · Finale Entscheidung: Benutzer

## 1. Ziel

Eine eigene, sofort wiedererkennbare Optik für einen melancholisch-gemütlichen Fantasy-Friedhof:
*„Tod ist Handwerk, nicht Horror."* – düster, aber warm; unheimlich, aber einladend; mit trockenem Humor.

Arbeitsmotto der Identität: **„Moos & Kerzenwachs"** – kalte, feuchte Welt (Moos, Nebel, Stein) gegen warmes, menschliches Licht (Laternen, Kerzen, Fenster).

## 2. Stil-Richtungen

**Benutzerentscheidung 27.09.2026: A – „Gemaltes Diorama".** B und C sind verworfen.

| | A – „Gemaltes Diorama" (Empfehlung) | B – „Holzschnitt / Scherenschnitt" | C – „Clean Low-Poly" |
|---|---|---|---|
| Formen | Leicht übertriebene, schiefe, handgemachte Formen; dicke Silhouetten | Scharfe, kantige Formen, starke Kontraste | Einfache Facetten, glatte Flächen |
| Oberflächen | Handgemalte Texturen + dezentes PBR | Flache Farben, Schraffur-Shader, Outline | Vertex-Farben, fast keine Texturen |
| Licht | Weiches Licht, volumetrischer Nebel, warme Lichtinseln | Harte Schatten, fast grafisch | Klares Licht, wenig Nebel |
| Wirkung | Märchenbuch, gemütlich-düster | Folklore, grafisch, ungewöhnlich | Freundlich, gut lesbar, günstig in Produktion |
| Produktionsaufwand | mittel | mittel–hoch (Shader) | niedrig |

## 3. Farbpalette (Richtung A)

| Rolle | Farbe | Hex |
|---|---|---|
| Boden / Gras (tagsüber) | Gedämpftes Moosgrün | `#5E7148` |
| Erde / Wege | Warmes Graubraun | `#6B5A48` |
| Stein / Grabsteine | Kühles Blaugrau | `#8A8F94` |
| Schatten / Nacht | Tiefes Tintenblau | `#1F2A3A` |
| Nebel | Blasses Graugrün | `#B7C2B0` |
| Akzent Licht | Kerzen-Bernstein | `#F2A93B` |
| Akzent Übernatürlich | Geister-Türkis | `#6FE3D2` (sparsam!) |
| Akzent Gefahr / Blut | Getrocknetes Rot | `#8C2F2B` (sparsam!) |

Regel: Übernatürliches ist die **einzige** Quelle gesättigter kalter Farbe → sofort lesbar.

## 4. Kamera (Vorschlag)

- 3D-Welt, **Perspektivkamera mit kleinem FOV (~30°)**, ca. 50° Neigung, fester Blickwinkel (keine Rotation im Vertical Slice).
  → wirkt wie 2.5D-Diorama, behält aber Tiefe & Parallaxe.
- Alternative: **orthografisch** (flacher, „brettspielartiger").
- **Benutzerentscheidung 27.09.2026:** beide verglichen, Art Direction freigegeben → Standard = **Perspektive, FOV 30°, Neigung 45°**; Orthografisch bleibt als Debug-Option.
- Kamera folgt dem Spieler weich (Lerp), leichter Zoom-Bereich.

## 5. Charakter-Proportionen (Vorschlag)

- Stilisiert, ca. **4–5 Kopfhöhen** (nicht Chibi, nicht realistisch).
- Große Hände & Füße, schmale Beine, markante Silhouette (Hut/Kapuze, Schaufel).
- Gravekeeper: hager, gebeugt, langer Mantel, Laterne am Gürtel – Silhouette muss auch nachts lesbar sein.

## 6. Licht & Atmosphäre

- Tag: tiefstehende Sonne, lange Schatten, leichter Bodennebel.
- Nacht: Mondlicht (kühl, gedimmt) + warme Punktlichter; Nacht darf nie „schwarz" sein – Lesbarkeit geht vor.
- Godot-Features: `WorldEnvironment` (Tonemap ACES/AgX, Glow dezent), volumetrischer Nebel, SSAO, weiche Schatten.

## 7. Lesbarkeit

- Interagierbare Objekte: dezenter Rim-/Outline-Highlight bei Nähe.
- Spieler hebt sich durch Wert-Kontrast (hell/dunkel) vom Boden ab.
- UI später: Pergament/Holz-Anmutung, aber eigene Formensprache.

## 8. PHASE 1 – ART-DIRECTION-PROTOTYP (Plan)

**Ziel:** Eine einzige kleine Szene (~20 × 20 m), die den Stil beweist. Keine Gameplay-Systeme.

| # | Inhalt | Umsetzung |
|---|---|---|
| 1 | Spieler (Gravekeeper) | Stilisiertes Modell (Blender-Script), einfache Idle-Pose, WASD-Bewegung nur zum Kamera-Test |
| 2 | Friedhof mit 6–8 Gräbern | Erdhügel + Einfassungen |
| 3 | 4 verschiedene Grabsteine | Kreuz, Rundstein, Obelisk, schiefer alter Stein |
| 4 | Baum | knorrige alte Eiche/Weide |
| 5 | Gras | MultiMesh-Grasbüschel + Boden-Shader |
| 6 | Weg | Erdpfad mit Steinen |
| 7 | Kleines Gebäude | Leichenhalle/Totengräberhütte |
| 8 | Lichtquelle | Laterne am Gebäude + Mond/Sonne |
| 9 | Schatten | Directional + Omni-Schatten |
| 10 | Kamera | Perspektiv/Ortho umschaltbar |
| 11 | Atmosphäre | Nebel, Tonemapping, Tag/Nacht-Vergleich per Taste |

**Aktive Agents:** 01 Lead, 04 Art Director, 05 Blender, 06 Character Art, 08 Godot Core, 19 QA.
**Nicht aktiv:** alle übrigen.

**Ablauf:**
1. Benutzer wählt Stil-Richtung (A/B/C) + ggf. Referenzbilder/Wünsche.
2. Blender-Generator-Scripts in `tools/blender/` erzeugen die Assets reproduzierbar → `.glb`.
3. Szene `src/world/art_prototype/art_prototype.tscn` aufbauen, Licht & Umgebung einstellen.
4. QA: Performance-Messung, Lesbarkeit Tag/Nacht, Checkliste Abschnitt 13 der Projektregeln.
5. **Screenshots** (Tag, Nacht, Nah, Fern, Ortho vs. Perspektive) + Build/Projekt zum Selbststarten → Benutzer.
6. STOPP – Benutzerprüfung. Bei Kritik: Änderungsschleife. Bei Freigabe: ART STYLE LOCK = ACTIVE.

**Hinweis:** Alle Assets in Phase 1 sind Prototypen (`ph_`-Präfix), bis der Benutzer sie ausdrücklich akzeptiert.

## 9. Technische Umsetzung des Stils (Prototyp)

| Baustein | Umsetzung |
|---|---|
| „Gemalte" Farbe | Vertex-Paint aus Blender-Scripts (Grundfarbe + Rauschen + Fake-AO + Oberlicht) statt vieler Texturen |
| Pinselstruktur | Welt-Raum-Rauschen im Shader `assets/shaders/painted.gdshader` (triplanar) |
| Licht | weicher, „gewickelter" Terminator + dezenter Randlicht-Saum (lesbare Silhouetten nachts) |
| Gras | MultiMesh-Büschel mit Wind, nutzen Boden-Normale → verschmelzen mit dem Boden |
| Atmosphäre | AgX-Tonemapping, SSAO, Glow, Höhen- + Volumennebel; Tag/Nacht als Presets in `data/atmosphere/` |
| Warme Lichter | an Blender-Markern (`light_*`) automatisch gesetzt, Werte in `data/art_prototype/layout.json` |
