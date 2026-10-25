# Phase 10 W0 – Ist-Kurve des alten Tarifs (Lead, 24.10.2026)

Zahlenbasis für P1 (docs/PHASE10_DESIGN.md §2.3, §12.1 W0). Gemessen auf dem W0-Stand: Der Tarif ist noch der von G9, die alten Bots laufen bitgleich. Geprüft: `kindly9` (12 Tage) und `crafter` (29 Tage) erzeugen dieselben Zustände wie die v8-Fixtures; neu sind nur die 23 Stats (= 0) und Format 9.

**Werkzeug:** `tests/integration/economy_curve_bot.gd` (`EconomyCurveBot`, Gerüst von P1s `curve10`) + `tools/economy/ist_kurve.gd`:
`godot --headless --path . -s res://tools/economy/ist_kurve.gd -- --out=/abs/ist_kurve.md [--days=91]` (≈ 4 min).

**Kette (W0 festgelegt):**
- neues Spiel → `Phase6Bot founder` (Phase 3–6, der Bot von `slot_p6_day37_founder`) bis `roof_and_earth_complete`
- → `founder7` bis `name_in_village_complete`
- → `founder8` bis `who_comes_up_complete`
- → `founder9` bis Tag 91 (`founder10` kommt in W3)

Übergabe wie bei den Fixtures: am Morgen nach dem Kapitel aus der Hütte, 07:00, speichern, laden, dann der nächste Bot.

**Gemessen:**
- morgens das Polster (`Reputation.holdings`: Beutel + Truhen + Lohndose) und `stats.coins_spent`; Einnahmen = ΔPolster + ΔAusgaben
- Quellen über `EventBus.payment_received` mit der W0-Präfixtabelle (`cash_book_config_fixture.tres`) und `trader_trade` (Ilse)
- „ohne Buchung“ = Einnahmen − gebuchte Quellen (Wertsachen usw.)
- Zwecke aus `GameState.coin_ledger()`
- „parish“ ist hier noch das alte Pflegegeld.

## Befund (wichtig für P1/W3)
1. **Die Gründer-Linie ist auf dem G9-Code schneller als die Fixture-Linie:** `roof_and_earth` an Tag 27 (Dorf ab Tag 28 statt 37), `name_in_village` an Tag 38 (statt 47).
2. **`founder8` erreicht „Wer heraufkommt“ in dieser Kette nicht.** Von Tag 39 bis 84 läuft der Bot, dann bricht die Stufe nach 45 Tagen ab.
   - erfüllt: Lehrling 2/2, Wünsche 28/5, Haushalte 6/3
   - fehlt: **Freundschaftsschritte 0/6** und die Einsicht – obwohl jeder Schritt laut `Friendship.step_block_reason` nehmbar ist (Beziehung 90–100)
   - mit und ohne Speichern/Laden an der Übergabe gleich; auf der Fixture-Linie (`slot_p8_founder`, `test_phase8_playthrough`) klappt es
   - Ursache offen (Bot-Weg zu „[Geschichte]“ im Dorfmenü oder Inhalt) → **P1 klärt das vor der `curve10`-Messung**
   - Folge: P8–P10 unten laufen ohne Phase-8/9-Kapitel und ohne Phase-9-Inhalte; dafür gelten weiter die Fixture-Bot-Messungen aus §2.1.
3. Ab etwa Tag 45 ist der Hügel voll, es gibt keine Bestattung mehr. Dann trägt das Pflegegeld (≈ 4/Tag; unter 80 Münzen greift die Kappe nicht) das Spiel fast allein, und die Spenden an Fenners Armenkasse fressen den Rest. Morgens min. 1 (Tag 87).

## Messung
Ist-Kurve (alter Tarif) – neues Spiel bis Tag 91, Kette { &"founder": 1, &"founder7": 28, &"founder8": 39, &"founder9": 84 }

| Abschnitt | Tage | Polster morgens Start → Ende (Δ) | Einnahmen | Ausgaben | Ausgabequote | morgens min. | Einnahmen nach Quelle | Ausgaben nach Zweck | ohne Buchung |
|---|---|---|---|---|---|---|---|---|---|
| P2–3 Ankunft & Friedhof | 1–14 | 5 → 38 (+33) | 217 | 184 | 85 % | 5 | burial 148 · parish 37 · gift 28 | osric 101 · ilse 53 · license 20 · build 10 | 4 |
| P4 Leichen | 15–24 | 38 → 55 (+17) | 172 | 155 | 90 % | 15 | burial 91 · parish 40 · gift 20 · reinter 12 · service 9 | osric 40 · ilse 40 · build 40 · building 35 | 0 |
| P5 Werkhof | 20–30 | 21 → 15 (-6) | 193 | 199 | 103 % | 11 | burial 70 · parish 44 · order 29 · reinter 20 · service 15 · gift 15 | building 115 · osric 24 · ilse 16 · round 15 · village 14 · consecration 10 · donation 5 | 0 |
| P6 Gebäude | 30–40 | 20 → 50 (+30) | 271 | 241 | 89 % | 15 | burial 113 · parish 44 · service 44 · gift 27 · shop_sale 22 · order 17 · reinter 4 | building 75 · village 60 · ilse 41 · donation 30 · osric 29 · round 5 · alms 1 | 0 |
| P7 Dorf | 40–53 | 79 → 26 (-53) | 212 | 265 | 125 % | 19 | parish 56 · burial 53 · shop_sale 30 · tip 26 · service 21 · gift 12 · order 10 | village 135 · donation 62 · apprentice 33 · ilse 16 · alms 13 · osric 6 | 4 |
| P8 Leute | 53–63 | 20 → 8 (-12) | 100 | 112 | 112 % | 14 | parish 44 · order 25 · tip 16 · shop_sale 15 | donation 50 · village 30 · apprentice 27 · alms 5 | 0 |
| P9 Fragen | 63–75 | 14 → 9 (-5) | 97 | 102 | 105 % | 7 | parish 52 · shop_sale 21 · order 14 · tip 10 | donation 85 · apprentice 15 · alms 2 | 0 |
| P10 Wirtschaft | 75–91 | 12 → 13 (+1) | 104 | 103 | 99 % | 6 | parish 68 · order 23 · shop_sale 15 · tip 2 | donation 90 · apprentice 9 · osric 4 | -4 |

| Prüfpunkt (morgens) | Polster | Kapitel bis dahin | Bot |
|---|---|---|---|
| Tag 14 | 35 | 1 | founder |
| Tag 30 | 20 | 3 | founder7 |
| Tag 45 | 78 | 4 | founder8 |
| Tag 60 | 21 | 4 | founder8 |
| Tag 75 | 12 | 4 | founder8 |
| Tag 91 | 9 | 4 | founder9 |

Übergaben: founder ab Tag 1 · founder7 ab Tag 28 · founder8 ab Tag 39 · founder9 ab Tag 84.

Polster je Morgen: 1:5, 2:12, 3:8, 4:11, 5:9, 6:10, 7:10, 8:11, 9:15, 10:23, 11:33, 12:42, 13:55, 14:35, 15:38, 16:31, 17:22, 18:17, 19:15, 20:21, 21:19, 22:33, 23:23, 24:33, 25:55, 26:28, 27:32, 28:24, 29:11, 30:20, 31:15, 32:26, 33:46, 34:41, 35:28, 36:54, 37:60, 38:41, 39:54, 40:79, 41:50, 42:47, 43:76, 44:70, 45:78, 46:58, 47:71, 48:60, 49:46, 50:31, 51:19, 52:27, 53:20, 54:26, 55:26, 56:15, 57:20, 58:18, 59:26, 60:21, 61:19, 62:23, 63:14, 64:8, 65:9, 66:8, 67:20, 68:9, 69:8, 70:7, 71:9, 72:13, 73:10, 74:9, 75:12, 76:9, 77:16, 78:10, 79:11, 80:17, 81:14, 82:20, 83:8, 84:7, 85:9, 86:6, 87:14, 88:8, 89:11, 90:10, 91:9, 92:13

Bot-Probleme: keine

