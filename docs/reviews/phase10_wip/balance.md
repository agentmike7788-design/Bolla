# Phase 10 W1 – P1 Tarif & Zielkurve (Agent 14 + 02)

## Tarifblatt (erzeugt)

<!-- tarifblatt:begin (tools/economy/tariff_report.py) -->
| # | Posten | Ort (`data/…`) | G9 | Phase 10 (Vertrag) | Daten | Stand |
|---|---|---|---|---|---|---|
| E1 | Pflegegeld je Tag nach Ruf | config/reputation_config `stipend` | 0/1/2/3/4 | 0/0/0/0/0 | 0/1/2/3/4 | mit P2 |
| E1b | Pflegegeld-Kappe | config/reputation_config `stipend_purse_cap` | 80 | 0 | 80 | mit P2 |
| E2 | Friedhofsgeld je Stufe/Woche | config/treasury_config `tier_pay` | – | 0/4/7/10/12 | 0/4/7/10/12 | ✓ |
| E2b | Pflegezuschlag ab Anteil · Kappe | config/treasury_config `care_steps`, `quality_cap` | – | 0,5/0,75/0,95/15 | 0,5/0,75/0,95/15 | ✓ |
| E2c | Bedarfszulage Schwelle/Teiler/Kappe | config/treasury_config `need_*` | – | 60/4/15 | 60/4/15 | ✓ |
| E2d | Notgroschen bis/Kappe | config/treasury_config `hardship_*` | – | 10/8 | 10/8 | ✓ |
| E3 | Bestattungslohn Grund | corpses/corpse_tables `base_payment` | 2–4 | 2–4 | 2–4 | ✓ |
| E4 | Lohn je Qualitätspunkt | config/economy_config `payment_per_quality` | 0,5 | 0,5 | 0,5 | ✓ |
| E5 | Ruf-Zuschlag auf den Lohn | config/reputation_config `pay_bonus` | -2/0/1/2/3 | -2/0/1/2/2 | -2/0/1/2/2 | ✓ |
| E6 | Aussegnung Kapelle 1/2/3 | config/chapel_config `service_fee_by_level` | 3/5/7 | 3/5/6 | 3/5/6 | ✓ |
| E7 | Umbettgeld · Geistergabe | config/crypt_config `reinter_fee`, ghost_config `gift_coins` | 4/2 | 4/2 | 4/2 | ✓ |
| E7b | Weihe fremd/bekannt/vertraut/befreundet | config/village_config `consecration_price_by_tier` | 10/10/5/0 | 10/10/5/0 | 10/10/5/0 | ✓ |
| E8 | Kleine Bitten | hill_requests/hr_* `reward_coins` | 1–3 (Ø 1,78) | 1–2: 1 bis 40 Min Arbeit, 2 länger | 1–2 (Ø 1,39) | ✓ |
| E9 | Große Bitten Tor | hill_requests/large/hrl_* `reward_coins` | 2–3 | 2 | 2 | ✓ |
| E9b | Große Bitten Dorf | hill_requests/large/hrv_* `reward_coins` | 3–5 | 3–4 | 3–4 | ✓ |
| E10 | Aufträge im Dorf | orders/o_*, ob_* `reward_coins` | 3–11 | 3–11 | 3–11 | ✓ |
| E11 | Trinkgeld-Kappe je Tag | config/visitor_config `tip_cap_day` | 4 | 3 | 3 | ✓ |
| E11b | Opferstock je Besuch · Kappe/Tag | config/visitor_config `poor_box_*` | – | 1/2 | 1/2 | ✓ |
| E12 | Ilse: Zopf · Zähne | config/utilization_config `sell_prices` | 4/5 | 3/4 | 3/4 | ✓ |
| E12b | Ilse: Aufschlag je Stück nach Pietät | config/piety_config `buyer_bonus_by_tier` | 1/1/0/0/0 | 1/1/0/0/0 | 1/1/0/0/0 | ✓ |
| E13 | Wertsachen im Saum | corpses/corpse_tables `valuables_coins_*` | 5–8 | 4–7 | 4–7 | ✓ |
| E14 | Quast: Augen · Hand · Herz | config/anatomy_config `organs.*.base_price` | 11/12/9 | 10/11/8 | 10/11/8 | ✓ |
| E14b | Vorlesungshonorar | config/anatomy_config `lecture.fee` | 4 | 4 | 4 | ✓ |
| E15 | Brenneisen: Kladde · Schweigen | config/stranger_config `kladde_price`, `bribe_coins` | 40/15 | 40/15 | 40/15 | ✓ |
| E17 | Läden kaufen an | shops/* `buys.price` | 1–8 | 1–8 | 1–8 | ✓ |
| E18 | Eigener Stand: Grundwerte | market/wares/* | – | wooden_cross 4 · herbs 1 · herb_bundle 3 · grave_candle 1 · wax_wreath 6 | – | P4 |
| A1 | Steinbruchbrief → Pachtbrief | dialogue/carter `p5_license` | 20 | 0 | 20 | P5 |
| A2 | Stationen Esse/Webstuhl/Steinmetz/Pult | stations/* `build_coins` | 25/10/15/12 | 25/10/15/12 | 25/10/15/12 | ✓ |
| A2b | Gebäude je Stufe | buildings/* `levels.coins` | shed 10/15/20 · chapel 25/30/40 · crypt 0/35/35 | shed 10/15/20 · chapel 25/30/40 · crypt 0/35/35 | shed 10/15/20 · chapel 25/30/40 · crypt 0/35/35 | ✓ |
| A3 | Honigkuchen (Theres) | shops/grocer `honey_cake` | 1 | 2 | 2 | ✓ |
| A3b | Grabgitter (Esch) | shops/smith `mortsafe` | 12 | 12 | 12 | ✓ |
| A4 | Lehrling je Tag | config/apprentice_config `wage` | 3 | 3 | 3 | ✓ |
| A5 | Runde · Spendenschritt · Postgeld | config/village_config `round_price`, `donation_step`, letters_config `postage` | 5/5/1 | 5/5/1 | 5/5/1 | ✓ |
| A6 | Ilses Nachtware Leinen/Wacholder/Gold | config/trader_config `shop` | 2/1/6 | 2/1/6 | 2/1/6 | ✓ |
| A7 | Pacht je Monat | config/treasury_config `rent` | – | 8 | 8 | ✓ |
| A8 | Zehnt % · Kappe | config/treasury_config `tithe_*` | – | 10/25 | 10/25 | ✓ |
| A9 | Schätzung % · ab · Kappe | config/treasury_config `estimate_*` | – | 10/20/15 | 10/20/15 | ✓ |
| A10 | Standgeld je Markttag | config/market_config `stall_fee` | – | 1 | 1 | ✓ |
| A11 | Rosenstock · Messinglaterne (Agathe) | market/stalls/ms_agathe | – | 12/10 | – | P4 |
<!-- tarifblatt:end -->
