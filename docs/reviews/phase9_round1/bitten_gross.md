# Phase 9 – Größere Bitten: Bot-Messung (P2, §2.3.6)

Gemessen mit `tests/integration/test_hill_requests_bot.gd` (`HillBot`, neue Strategien `duty_large` und `reverent_large`): echte Welt, neues Spiel, Tag 1–14, `Player.instant_actions`, 3 Min je Gang. „Leerlauf“ = Minuten von der letzten Tagesarbeit bis 18:00 (wie G8 Runde 6). Die alten Strategien (`duty`, `duty_requests`, `reverent`, `reverent_requests`) laufen **bitgleich** zur Runde 6 (Tabellen und Summen identisch).

Was der Bot mit großen Bitten tut: Er liest den großen Bogen morgens am Tor (während die Lieferung da ist), nimmt an, was er darf, und arbeitet die Teile ab – Werkbank (Eisen/Samen bei Osric), die genannten Pflegestellen, Zier im Alten Hof / am Tor, Roden für Holz, die Kette Untersuchen → Bestatten → Grabstein (macht die Leichenarbeit ohnehin), nachts nur die nötigen Geister, abends das Warten am Tor (`visit`) und die Abgabe bei Osric.

## Ergebnis

| Spieler | Leerlauf Tag 2–12 | Ziel §2.3.6 | Tage > 240 min | große Bitten (Tag 1–14) | Tag 14 Münzen |
|---|---|---|---|---|---|
| Pflicht ohne Bitten | 2820 min | – | – | – | 51 |
| Pflicht, kleine Bitten (R6) | 2483 min | – | – | – | 105 |
| **Pflicht, kleine + große Bitten** | **1887 min** (−24 % gegen R6, −33 % gegen 2820) | ≤ 1700 (Band 1450–1800) | **3 von 11** ✓ | 8 angenommen, 7 erfüllt, 0 halb, 0 versäumt (1 versäumt am Morgen von Tag 15) ✓ | **129** ✓ (≤ 130) |
| Andächtig, kleine Bitten (R6) | 1581 min | – | – | – | 91 |
| **Andächtig, kleine + große Bitten** | **1413 min** ✓ (1350–1750) | 1350–1750 | 1 | 6 angenommen, 3 erfüllt, 1 halb, 1 versäumt (Tag 1–14) ✓ | **99** ✓ (≤ 110) |

**Offen:** Das Leerlauf-Ziel ≤ 1700 min wird mit den Vertragswerten nicht erreicht. Der Test sichert den gemessenen Stand (`IDLE_GUARD` 1900).

## Warum nicht ≤ 1700 – und was es kosten würde

- Der Pflicht-Bot erledigt eine große Bitte meist am Tag der Annahme (die Teile „Untersuchen, Bestatten, Holz vom Stapel“ tut er ohnehin, Geister und das Warten am Tor fallen in die Nacht). Danach hängt bis zum nächsten Morgen nichts Neues (1 Platz, Neubelegung am nächsten Morgen), und mit 8–10 Tagen Abklingzeit ist der Pool von 8 Tor-Bitten um Tag 10 erschöpft (Tage 10, 12–14).
- Mehr Durchsatz drückt den Leerlauf, hebt aber die Münzen über 130 (Lohn + höherer Ruf → höhere Bestattungslöhne):

| Variante (nur `data/`) | Leerlauf | Tag 14 Münzen | große Bitten erfüllt |
|---|---|---|---|
| Vertrag: 1 Platz, Abklingzeit 8–10, Ruf +2 (**gewählt**) | 1887 | 129 | 7 |
| 2 Plätze am Tor, Abklingzeit 8 | 1879 | 134 | 7 |
| 2 Plätze, Abklingzeit 6, Ruf +2 | 1795 | 142 | 10 |
| 2 Plätze, Abklingzeit 5, Ruf +1 | 1744 | 139 | 10 |

Entscheidung beim Gate G9 (Benutzer): Leerlauf-Ziel oder Münzgrenze. Vorschlag P2: Vertragswerte behalten; wenn der Leerlauf wichtiger ist, `large_slots_gate 2` und Abklingzeit 6 (dann Tag-14-Münzen ≈ 140).

## Datenanpassungen (P2, begründet)

- **Münzen der Tor-Bitten auf Schnitt 3** (§2.3.5 Schritt 1): ferry/crosses/bench/widow/lantern/old_names 3, proper_grave 4, restless 2 – sonst 141 Münzen an Tag 14.
- **`hrl_ferry_graves`**: alle 8 Unkrautstellen des Alten Hofs (statt 4) – die 4 waren nach einer Stunde sauber.
- **`hrl_proper_grave`**: „Die Gräber ringsum säubern“ (4 Nachbargräber statt 2).
- **`hrl_bench_path`**: Roden auch auf der Ostwiese; Laub unter der Eiche (`dirt_y09`, `dirt_y10`) statt `dirt_n01/n02` (die liegen bis zur Freigabe des Birkenhangs sauber); kein Rechen als Angebotsbedingung (der Rechen ist ein Werkbank-Rezept, der Bot baut ihn).
- **`hrl_old_names`**: zwei Grabsteine an der Werkbank (`gravestone_simple` ist ein Werkbank-Rezept → **keine Holzkreuz-Ausweichregel**), Jäten zwischen den Altgräbern (`dirt_y05`, `dirt_y06`; Altgräber haben keine eigene Pflegestelle), ein Geist im Alten Hof (Altgräber haben keine Geister).
- **`hrl_widow_wood`**: 10 Holz in 2 Tagen; das Angebot verlangt, dass Stapel (4 je Morgen) + Roden die Menge hergeben – sonst hängt die Bitte nicht.

## Tabellen

### Pflicht (`duty_large`)

| Tag | Arbeit bis | Leerlauf bis 18:00 | kleine Bitten (Σ) | große Bitten erfüllt (Σ) | Münzen aus großen Bitten (Σ) | läuft am Abend | Münzen | Ruf |
|---|---|---|---|---|---|---|---|---|
| 1 | 17:54 | 6 min | 0 | 0 | 0 |  | 10 | 26 |
| 2 | 14:13 | 227 min | 1 | 0 | 0 | hrl_crosses 0/2 | 11 | 29 |
| 3 | 13:07 | 293 min | 2 | 1 | 3 |  | 11 | 36 |
| 4 | 17:47 | 13 min | 4 | 2 | 6 |  | 25 | 43 |
| 5 | 21:18 | 0 min | 5 | 2 | 6 | hrl_restless 1/2 | 15 | 51 |
| 6 | 15:42 | 138 min | 6 | 3 | 8 |  | 19 | 59 |
| 7 | 14:58 | 182 min | 7 | 4 | 11 |  | 27 | 69 |
| 8 | 14:44 | 196 min | 9 | 5 | 14 |  | 40 | 78 |
| 9 | 18:49 | 0 min | 11 | 6 | 17 |  | 52 | 88 |
| 10 | 13:21 | 279 min | 13 | 6 | 17 |  | 62 | 92 |
| 11 | 14:13 | 227 min | 13 | 7 | 20 |  | 74 | 96 |
| 12 | 12:28 | 332 min | 15 | 7 | 20 |  | 88 | 98 |
| 13 | 13:32 | 268 min | 17 | 7 | 20 | hrl_widow_wood 0/2 | 118 | 99 |
| 14 | 12:34 | 326 min | 18 | 7 | 20 |  | 129 | 97 |

Verlauf: Tag 2 hrl_crosses accepted; Tag 3 hrl_crosses completed; Tag 4 hrl_ferry_graves accepted; Tag 4 hrl_ferry_graves completed; Tag 5 hrl_restless accepted; Tag 6 hrl_restless completed; Tag 7 hrl_proper_grave accepted; Tag 7 hrl_proper_grave completed; Tag 8 hrl_old_names accepted; Tag 8 hrl_old_names completed; Tag 9 hrl_lantern_path accepted; Tag 9 hrl_lantern_path completed; Tag 11 hrl_crosses accepted; Tag 11 hrl_crosses completed; Tag 13 hrl_widow_wood accepted; Tag 15 hrl_widow_wood failed

### Andächtig (`reverent_large`)

| Tag | Arbeit bis | Leerlauf bis 18:00 | kleine Bitten (Σ) | große Bitten erfüllt (Σ) | Münzen aus großen Bitten (Σ) | läuft am Abend | Münzen | Ruf |
|---|---|---|---|---|---|---|---|---|
| 1 | 19:36 | 0 min | 0 | 0 | 0 |  | 12 | 26 |
| 2 | 15:25 | 155 min | 0 | 0 | 0 | hrl_crosses 0/2 | 8 | 31 |
| 3 | 14:39 | 201 min | 1 | 0 | 0 | hrl_crosses 0/2 | 10 | 39 |
| 4 | 14:33 | 207 min | 3 | 0 | 0 |  | 10 | 44 |
| 5 | 21:40 | 0 min | 3 | 1 | 2 |  | 8 | 51 |
| 6 | 17:40 | 20 min | 3 | 1 | 2 | hrl_proper_grave 2/4 | 13 | 61 |
| 7 | 16:27 | 93 min | 4 | 1 | 2 | hrl_proper_grave 2/4 | 14 | 70 |
| 8 | 12:59 | 301 min | 4 | 1 | 3 |  | 25 | 76 |
| 9 | 21:46 | 0 min | 5 | 1 | 3 | hrl_old_names 2/3 | 34 | 87 |
| 10 | 18:15 | 0 min | 6 | 2 | 6 |  | 50 | 95 |
| 11 | 14:44 | 196 min | 6 | 3 | 9 |  | 59 | 98 |
| 12 | 14:00 | 240 min | 6 | 3 | 9 |  | 72 | 100 |
| 13 | 18:05 | 0 min | 7 | 3 | 9 | hrl_widow_wood 0/2 | 86 | 100 |
| 14 | 15:25 | 155 min | 7 | 3 | 9 |  | 99 | 97 |

Verlauf: Tag 2 hrl_crosses accepted; Tag 5 hrl_crosses failed; Tag 5 hrl_restless accepted; Tag 5 hrl_restless completed; Tag 6 hrl_proper_grave accepted; Tag 9 hrl_proper_grave half; Tag 9 hrl_old_names accepted; Tag 10 hrl_old_names completed; Tag 11 hrl_lantern_path accepted; Tag 11 hrl_lantern_path completed; Tag 13 hrl_widow_wood accepted; Tag 15 hrl_widow_wood failed
