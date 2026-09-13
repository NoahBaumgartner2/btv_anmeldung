# Rabatt-Audit Q4 2026 — Zweitkurs-/Geschwisterrabatt-Bug

> Rekonstruiert aus dem Session-Log vom 11.09.2026, 15:33–15:43 Uhr. Ursprünglich
> per SendUserFile als Anhang verschickt, dabei aber nur im temporären
> Scratchpad der damaligen Session erzeugt (und damit nach Sessionende von der
> Platte verschwunden) — dieses Dokument ist die inhaltsgleiche Rekonstruktion,
> jetzt dauerhaft im Projekt abgelegt.
>
> **Hinweis:** Der Stand unten ist der Stand vom 11.09.2026. Ob die betroffenen
> Anmeldungen inzwischen korrigiert/nachbelastet wurden, ist hier nicht
> nachgeführt — bei Bedarf mit dem aktuellen DB-Stand abgleichen.

## Hintergrund

`DiscountCalculator.existing_registrations` zählte alle Anmeldungen derselben
Kategorie, unabhängig davon aus welchem Term/Quartal sie stammten — auch die
alte Anmeldung im vorigen Kurs einer Rollover-Kette. Dadurch wurde z. B. eine
verlängerte FS2027-Anmeldung fälschlich als "zweiter Kurs" gegenüber der alten
HS2026-Anmeldung gewertet und erhielt unberechtigt den Zweitkurs-/
Geschwisterrabatt.

**Fix:** Bei Kursen mit gesetztem `term` zählen seither nur noch Anmeldungen im
selben Term für Zweitkurs- **und** Geschwisterrabatt. Kurse ohne Term (eigener
Zeitraum) verhalten sich unverändert. Der Fix ging am 9.9. um **20:31 Uhr**
live (Commit `aa49540` auf `staging`).

## Befund

Alle 36 Q4-Anmeldungen mit angewendetem Rabatt wurden mit der korrigierten
Logik neu durchgerechnet:

**28 Anmeldungen wurden fälschlich mit dem Zweitkurs-/Geschwisterrabatt
belastet** — alle 28 hätten eigentlich den vollen Preis zahlen sollen.

Betroffen sind ausschliesslich Checkouts, die zwischen **18:09 Uhr und
20:46 Uhr am 9.9.** begonnen wurden — also im Fenster um den Fix herum. Der
Preis wird beim Checkout-**Start** berechnet und fest eingefroren, nicht erst
bei Zahlungsabschluss — darum ist auch der letzte Fall (Checkout um 20:45,
kurz nach dem Fix-Deploy) noch betroffen: Die Seite war schon vorher geöffnet.

**Jede der 28 Personen zahlte CHF 120.00 statt CHF 150.00 — macht CHF 30.00 zu
wenig pro Person, total CHF 840.00.**

## Betroffene (chronologisch)

| # | Teilnehmer | Kurs |
|---|---|---|
| 1622 | Kaya Joshi | Sonntag RLZ l |
| 1620 | Neva Juliette Schneider | Samstag Tscharnergut l.l |
| 1621 | Keller Siara | Donnerstag Brunnmatt |
| 1623 | Laura Zurkinden | Donnerstag EWB |
| 1626 | Lena Niklaus | Montag Brunnmatt ll |
| 1631 | Nilay Sümbül | Freitag Laubegg |
| 1630 | Mio Laube | Junior Samstag Tscharnergut l.ll |
| 1633 | Daria Dudnikova | Samstag Tscharnergut l.ll |
| 1629 | Amelie Neuenschwander | Sonntag RLZ ll |
| 1637 | Valentina Fernández | Sonntag RLZ l |
| 1639 | Marlene Erhart | Samstag Tscharnergut l.l |
| 1641 | Paulina Otterbach | Montag Brunnmatt l |
| 1642 | Noelani Habisreutinger | Junior Sonntag EWB l |
| 1643 | Luzius Thalmann | Mittwoch Brunnmatt l |
| 1644 | Tamara Hersche | 1418 Donnerstag EWB |
| 1645 | Nikà Banzhaf | Sonntag RLZ l |
| 1646 | Elina Nunes dos Santos | Samstag Tscharnergut l.ll |
| 1648 | Lionel Hoigné | Dienstag EWB |
| 1650 | Amélie Lauper | Freitag Breitenrain ll |
| 1651 | Matilda Johanna Ritschard | Samstag Tscharnergut l.ll |
| 1649 | Marit Jordi | Mittwoch Brunnmatt l |
| 1655 | Leonie Marti | Samstag Tscharnergut l.l |
| 1657 | Paul Stöppler | Montag Brunnmatt ll |
| 1628 | Solène Sonderegger | Samstag Tscharnergut l.l |
| 1658 | Sofie Mauerhofer | Montag Brunnmatt ll |
| 1663 | Tilla Lötscher | Freitag Breitenrain l |
| 1665 | Amélie Lehmann | Junior Samstag Tscharnergut l.ll |
| 1656 | Ella Mess | Sonntag RLZ ll |

## Verifikation (13.09.2026)

Alle 28 Fälle wurden gegen die **aktuelle Produktionsdatenbank** mit dem
reparierten `DiscountCalculator` (term-scoped Zweitkurs-/Geschwisterrabatt)
neu durchgerechnet — nicht nur die alte Liste übernommen:

- Für **alle 28** ergibt die korrigierte Logik den vollen Kurspreis (CHF 150.-,
  `discount: nil`), während `applied_price_cents` weiterhin bei CHF 120.-
  (`applied_discount: second_course` bzw. bei #1651 `sibling`) steht — der
  fälschliche Rabatt ist bei allen 28 tatsächlich noch unkorrigiert in der DB.
- **Keine** der 28 Personen hat bereits eine `SupplementaryCharge` (Nachforderung)
  erhalten — keine Gefahr einer Doppelbelastung.
- Alle 28 sind weiterhin `status: bestätigt`, `payment_cleared: true` — keine
  Stornierung, keine offene Zahlung dazwischengekommen.

**Ergebnis: Die Liste ist unverändert korrekt. CHF 30.- Nachforderung pro
Person ist für alle 28 gerechtfertigt.**

## Zur Eingabe: sortiert nach Kurskategorie und Kursname

| Kategorie | Kurs | Teilnehmer |
|---|---|---|
| Kunstturnen Plus | Dienstag EWB | Lionel Hoigné |
| Kunstturnen Plus | Donnerstag Brunnmatt | Keller Siara |
| Kunstturnen Plus | Donnerstag EWB | Laura Zurkinden |
| Kunstturnen Plus | Freitag Breitenrain l | Tilla Lötscher |
| Kunstturnen Plus | Freitag Breitenrain ll | Amélie Lauper |
| Kunstturnen Plus | Freitag Laubegg | Nilay Sümbül |
| Kunstturnen Plus | Mittwoch Brunnmatt l | Luzius Thalmann |
| Kunstturnen Plus | Mittwoch Brunnmatt l | Marit Jordi |
| Kunstturnen Plus | Montag Brunnmatt l | Paulina Otterbach |
| Kunstturnen Plus | Montag Brunnmatt ll | Lena Niklaus |
| Kunstturnen Plus | Montag Brunnmatt ll | Paul Stöppler |
| Kunstturnen Plus | Montag Brunnmatt ll | Sofie Mauerhofer |
| Kunstturnen Plus | Samstag Tscharnergut l.l | Neva Juliette Schneider |
| Kunstturnen Plus | Samstag Tscharnergut l.l | Marlene Erhart |
| Kunstturnen Plus | Samstag Tscharnergut l.l | Leonie Marti |
| Kunstturnen Plus | Samstag Tscharnergut l.l | Solène Sonderegger |
| Kunstturnen Plus | Samstag Tscharnergut l.ll | Daria Dudnikova |
| Kunstturnen Plus | Samstag Tscharnergut l.ll | Elina Nunes dos Santos |
| Kunstturnen Plus | Samstag Tscharnergut l.ll | Matilda Johanna Ritschard |
| Kunstturnen Plus | Sonntag RLZ l | Kaya Joshi |
| Kunstturnen Plus | Sonntag RLZ l | Valentina Fernández |
| Kunstturnen Plus | Sonntag RLZ l | Nikà Banzhaf |
| Kunstturnen Plus | Sonntag RLZ ll | Amelie Neuenschwander |
| Kunstturnen Plus | Sonntag RLZ ll | Ella Mess |
| Kunstturnen Plus 1418 | 1418 Donnerstag EWB | Tamara Hersche |
| Kunstturnen Plus Junior | Junior Samstag Tscharnergut l.ll | Mio Laube |
| Kunstturnen Plus Junior | Junior Samstag Tscharnergut l.ll | Amélie Lehmann |
| Kunstturnen Plus Junior | Junior Sonntag EWB l | Noelani Habisreutinger |

Jede Zeile: **CHF 30.00**, Beschreibung z. B. "Korrektur Rabatt Q4 2026".

## Offener Entscheid (Stand 11.09.2026, Verifikation 13.09.2026 bestätigt weiterhin offen)

Es wurde bisher **nichts automatisch geändert** — keine Nachbelastung, keine
Korrektur der Anmeldungen. Die neue **Nachforderungen**-Funktion (Admin →
Verwaltung → Nachforderungen) kann jetzt genutzt werden, um die CHF 30.- pro
Person einzufordern: Teilnehmerliste des jeweiligen Kurses öffnen, die
betroffene Person anhaken, Betrag/Beschreibung/Erklärtext eintragen — die
Person erhält automatisch eine E-Mail mit Zahlungslink, nach Zahlung eine
offizielle Quittung.
