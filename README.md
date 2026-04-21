# Readme
![ER-Diagramm](/Documentation/Bildschirmfoto%202026-03-29%20um%2017.46.59.png)


TODO

- 1. Rechtliches & Compliance (höchste Priorität)
Für die Schweiz und DSGVO/DSG brauchst du unbedingt eine Datenschutzerklärung und AGB, die direkt in der App verlinkt sind. Ein Cookie-Consent-Banner fehlt komplett. Bei der Registrierung sollte eine Checkbox für die Zustimmung zu den AGB/Datenschutz vorhanden sein. Dein Devise erlaubt zwar subscribe_to_newsletter, aber ein Newsletter-Opt-in ohne rechtliche Grundlage ist problematisch. Ausserdem solltest du eine Impressum-Seite einbauen — in der Schweiz (UWG) und besonders bei der DSGVO für EU-Kunden ist das Pflicht.

- https://www.kids-sport.ch/
- gewisse sachen wie zum beispiel "kostenlos" bleibt deutsch obwohl die sprache gewechselt wird
- überprüfen, ob das automatische mailing bei nicht gemachter anwesenheitskontrolle funktioniert
- gewisse fehlercode sind noch standartisiert
- course form sind die placeholder noch durcheinannder



### Workflow NDS
- 1. Teilnehmende exportieren meine datenbank (Beides möglich: alle Kurse oder ecpliziter Kurs)
- 2. Teilnehmende importieren NDS (Beides möglich: alle Kurse oder ecpliziter Kurs)
- 3. Teilnehemnde exportieren NDS (Beides möglich: alle Kurse oder ecpliziter Kurs)
- 4. Teilnehemnde importieren meine datenbank (AHV Überprüfung (unique)) (Beides möglich: alle Kurse oder ecpliziter Kurs)
- 5. Anwesenheitkontrolle exportieren meine datenbank
- 6. Anwesenheitkontrolle importieren NDS

Wichtige Bemerkungen:
- trainer separat (von hand)
- wenn training mehr als 1.5h, dann max 1.5h