# Redesign BTV Anmeldung – Dokumentation

Stand: 5. November 2026 · Branch `design` · Vorschau: https://design.btvbern-anmeldung.ch
Plan und ursprüngliche Entscheide: [`docs/redesign-plan.md`](redesign-plan.md)

Das Redesign ändert das Aussehen der ganzen App nach dem Vorbild des Videos
„Admin Dashboard V2“ (Glas-Look, Sidebar, Kacheln). Die Funktionen bleiben gleich.
Ausnahmen sind die neue Kursübersicht mit Kategorie-Overlay und ein paar falsche
Zurück-/Abbrechen-Ziele, die dabei aufgefallen und korrigiert worden sind.

`staging` und `main` sind unverändert. Der Merge `design` → `staging` → `main`
passiert nur nach ausdrücklicher Freigabe.

---

## 1. Entscheide

| Thema | Entscheid |
|---|---|
| Look | Heller Milchglas-Inhalt auf einem dunklen Verlauf aus den Vereinsfarben. Text steht immer auf hellem Grund, nie direkt auf dem Verlauf. |
| Farben | Verlauf **nur** aus Primär- und Sekundärfarbe (Admin → Verein). Primärfarbe = aktiver Menüpunkt, Sekundärfarbe = Akzent (gewählte Filter, aktiver Handy-Tab, Schrittnummern, Scanner-Rahmen). |
| Schrift auf Vereinsfarben | Der Server berechnet sie aus der Helligkeit der Farbe: dunkel auf Gelb, weiss auf Rot. |
| Buttons | Hauptaktion = dunkle Pille, Nebenaktion = weisse Pille mit Rand, Löschen/Abmelden = rot. Vereinsrot wird nicht mehr für normale Buttons verwendet. |
| Navigation | Computer: Glas-Sidebar mit Gruppen. Handy: Kopfzeile, Tab-Leiste unten und „Mehr“-Menü. |
| Bilder | **Ein Bild pro Kurskategorie** (Admin → Kurskategorien). Das Foto pro Kurs wurde wieder entfernt. |
| Kursübersicht | Kacheln pro Kategorie; ein Klick öffnet ein Overlay mit allen Kursen der Kategorie (ohne Bilder). |
| Ortsnamen | Bleiben, wie sie in den Kursen erfasst sind (nicht zusammengeführt). |
| E-Mails, PDF, QR-Code | Unverändert. QR-Codes bleiben auf weissem Grund. |

## 2. Design-System

Alles steht in `app/assets/tailwind/application.css`, ohne neue Libraries.

| Klasse / Token | Zweck |
|---|---|
| `.app-bg`, `.brand-bg` | Verlauf aus den Vereinsfarben, gemischt in `oklab` (bei `oklch` ergab Gelb→Blau einen Grünstich) |
| `.glass`, `.glass-strong` | Milchglas mit Unschärfe, nur für Sidebar, Kopfzeile, Tab-Leiste und Mehr-Menü |
| `.panel` | Inhaltsfläche ohne Unschärfe (siehe Stolperfalle unten) |
| `.btn`, `.btn-primary`, `.btn-secondary` | Pillen-Buttons mit Feder-Animation beim Drücken |
| `.chip` | Filter-Buttons mit `aria-pressed` |
| `.field` | Eingabefelder |
| `.stat-card` | Kennzahl-Kacheln (Statistiken) |
| `.nav-item`, `.nav-group` | Einträge in der Sidebar |
| `.course-dialog` | Kategorie-Overlay (natives `<dialog>`, am Handy als Sheet von unten) |
| `--ease-entrance/-exit/-spring` | Animationskurven (rein = ease-out, raus = ease-in, Feedback = Feder) |
| `--color-on-primary/-secondary` | Schriftfarbe auf den Vereinsfarben, kommt aus `ClubSetting#text_color_on` |

Weitere Punkte:
- Ohne Blur-Unterstützung oder bei „weniger Transparenz“ werden die Flächen deckend weiss. Bei „weniger Bewegung“ sind die Animationen aus.
- Beim Seitenwechsel verschwimmt die alte Seite und die neue wird scharf (Turbo View Transitions). Sidebar, Kopfzeile und Tab-Leiste bleiben dabei stehen.
- **Button-Gruppen:** am Handy `grid grid-cols-2 gap-2`, ab Tablet `sm:flex`. Die Buttons haben `w-full sm:w-auto min-h-11`. Bei `button_to` wird `form_class: "contents"` gesetzt, damit der Button selbst im Raster sitzt.

### Stolperfallen (für spätere Änderungen)

- Kein `backdrop-filter`, `transform` oder `view-transition-name` auf Elementen, die Modals mit `position: fixed` enthalten. Sonst werden die Modals eingesperrt bzw. liegen unter Sidebar und Tab-Leiste. Darum gibt es `.panel` statt `.glass` für den Inhalt.
- Einige Farben schaltet JavaScript um: `manual_enroll`, `training_actions` und `abo_weekday_filter` wechseln zwischen `bg-slate-900` und `bg-gray-100`. Diese Klassen dürfen nur zusammen mit dem JS geändert werden.
- Tailwind-Utilities schlagen Komponenten-Klassen. Wer `.chip` mit `bg-transparent` kombiniert, braucht für den gewählten Zustand `aria-pressed:bg-…`.

## 3. Was neu bzw. anders ist

### Navigation (`app/views/layouts/_navigation.html.erb`)
- Die Sidebar hat drei Gruppen: Allgemein (Kurse, Profil), Training (Meine Kurse, Mails) und Verwaltung (Admin-Dashboard). Wer was sieht, ist gleich wie vorher (`nav_sections` im `ApplicationHelper`).
- Unten in der Sidebar stehen **Kontoeinstellungen**, Sprache und der Benutzer mit Initialen und Logout.
- Am Handy zeigt die Tab-Leiste 3 Einträge plus „Mehr“. „Mehr“ ist ein natives Popover mit den restlichen Links, Kontoeinstellungen, Sprache, Logout, Datenschutz und Impressum.
- Der alte `mobile_menu_controller` ist entfernt.

### Kursübersicht (`courses/index`)
- Eine Kachel pro Kategorie mit Bild, Anzahl Kurse, Wochentagen und Orten (`courses/_category_tile_body`, auch auf der Startseite verwendet).
- Ein Klick öffnet ein Overlay mit allen Kursen als Zeilen (`courses/_course_row`): Tag und Zeit, Name, Ort mit Adresse (Link zu Google Maps), Zeitraum, freie Plätze, Preis, „Jetzt anmelden“ bzw. „Warteliste“. Schliessen geht mit Esc, dem X oder einem Klick daneben.
- **Filter oben:** Wochentage als Segment-Leiste, Ort als Auswahl („Alle Orte“). Dazu „x von y Kursen“ und „Zurücksetzen“. Am Computer läuft die Leiste beim Scrollen mit.
- **Tag-Filter im Overlay:** Er wirkt nur auf das Overlay und kombiniert sich mit dem Filter oben.
- Links wie `/courses#kids-gym` (z. B. von der Startseite) öffnen das passende Overlay direkt.
- Die Logik steckt im `course_filter_controller.js`.

### Bilder pro Kategorie
- Upload unter Admin → Kurskategorien (Bild-Kacheln, Erklärtext, Mail-Versand separat).
- Das Bild erscheint auf der Kachel, auf der Kursseite oben und im Kursformular (als Vorschau mit Link „Kategorie-Bilder verwalten“).
- Im Code: `Course#card_image` und `Course#category_name`, Variante 800×500 WebP.

### Vereinsfarben
- Kein Grünstich mehr: Gemischt wird nur aus den zwei Vereinsfarben, in `oklab`.
- `ClubSetting#text_color_on(hex)` liefert die lesbare Schriftfarbe (WCAG-Luminanz). Getestet in `test/models/club_setting_test.rb`.

### Seiten
- **Kursseite:** Foto-Header mit Titel, Tag, Zeit und Ort. „Wann & Wo“ zeigt jetzt auch die Trainingszeit (fehlte vorher). Der Trainer & Admin Bereich ist ein gleichmässiges Button-Raster.
- **Anmeldung:** einheitliche Felder und Buttons, Fehlermeldungen im neuen Stil.
- **Dashboards:** Kennzahl-Kacheln, dunkler „Heute“-Banner beim Trainer. Im Admin-Dashboard steht die Teilnehmer-Suche über der Kursliste.
- **Startseite (nur Gäste):** Hero auf dem Verlauf, die 4 Schritte als Karten mit Schrittnummer, Kategorien als Kacheln. **Kurse auf Einladung werden nicht mehr angezeigt** (Test in `pages_controller_test.rb`).
- **QR-Scanner:** Start- und Fehlerbildschirm auf dem Marken-Verlauf, Rahmen und Zähler in der Akzentfarbe, ruhige grüne bzw. rote Rückmeldung. Die Scan-Logik ist unverändert.
- **Alle übrigen Seiten** (Kursverwaltung, Kursformular, Trainings, Teilnehmende, Trainer, Admin-Einstellungen, Ferientage, Newsletter, Login und Registrierung, Rechtsseiten): Pillen-Buttons, gerundete Karten und Tabellen, einheitliche Felder.

### Korrigierte Fehler, die schon vor dem Redesign bestanden

| Stelle | Vorher | Jetzt |
|---|---|---|
| Training bearbeiten → „Zurück zur Übersicht“ | führte zur rohen Liste *aller* Trainings | „Zurück zum Training“ |
| Training bearbeiten/neu → „Abbrechen“ | `javascript:history.back()`, von der CSP blockiert | festes Ziel (Training bzw. Kursverwaltung) |
| Ferientermin → „Abbrechen“ | 404 | Ferientage-Übersicht |
| Teilnehmer-Profil (Admin) → „Zurück“ | führte zur *eigenen* Familie des Admins | Admin-Dashboard (Trainer: Trainer-Dashboard) |
| Präsenzkontrolle → Link zum Bearbeiten | hiess „Änderungen speichern“ | „Training bearbeiten“ |
| Semester/Quartal, Datenschutz (Handy) | Tabellen abgeschnitten, „Löschen“ nicht erreichbar | waagrecht scrollbar |
| Ferientage-Kopf (Handy) | „Löschen“ abgeschnitten | Zeile bricht um |

## 4. Qualitätssicherung

- **Tests:** 779 grün (`bin/rails test`). Rubocop und Brakeman sind sauber, CI inklusive System-Tests grün.
- **Automatische Button-Inventur** auf 57 Admin-Seiten, je am Computer und am Handy (Playwright). Pro Button: Form, Farbe, Umbruch, Herausragen, Link-Ziel. Dazu wurden alle 58 Formular-Ziele gegen die Rails-Routen geprüft.

  | | vorher | nachher |
  |---|---|---|
  | Buttons im alten Stil | 4'992 | 0 |
  | Links auf Fehlerseiten | 1 | 0 |
  | Abgeschnitten am Handy | 3 Stellen | 0 |
  | Ungleich grosse Buttons in einer Gruppe | mehrere | 0 |

- **Rundgänge** als Elternteil (11 Seiten), Trainer (15) und Admin (57) auf der Design-Umgebung, mit Kontaktbögen der Screenshots.
- **Anmelde-Ablauf als Elternteil** auf der Design-Umgebung: Kachel → Overlay → Kursseite → Formular → Absenden. Die Pflichtangaben-Prüfung (AHV, Alter) greift korrekt. Lokal ist eine vollständige Anmeldung bis „Zahlung ausstehend“ durchgelaufen.
- **QR-Scanner:** auf einem echten Handy geprüft (funktioniert).
- **Regel-Skripte** für die Umstellung: `~/vault/BTV/redesign-restyle.rb` und `redesign-restyle2.rb`. Sie ändern nur Klassen und lassen per JS umgeschaltete Klassen aus.

## 5. Offen / bewusst nicht gemacht

- Die Teilnehmer-Suche in der Kursverwaltung filtert nicht. Ihr Inline-Script hat keine CSP-Nonce. Das Problem gab es schon vorher, auch live, und es wartet auf ein OK.
- `/training_sessions` ist eine rohe Scaffold-Liste. Sie ist nicht mehr verlinkt und liesse sich entfernen.
- Der Newsletter-Editor-Tab „Designer“ ist noch in Vereinsrot (seine Farbe schaltet ein Script um).
- Die Startseite hat ihren eigenen Footer zusätzlich zum allgemeinen (doppelt).
- Die 404-Seite (`public/404.html`) ist statisch und noch im alten Stil.
- Auf der Design-Umgebung fehlen Kategorie-Bilder. Ohne sie zeigen die Kacheln den Farbverlauf.
- **CI:** Am 5.11. hing der Job „test“ einmal nach den Tests (Neustart war grün). Ein `timeout-minutes` für die Jobs ist vorgeschlagen, aber nicht eingebaut.

## 6. Lokal testen

```bash
# Postgres läuft im Docker-Container btv_anmeldung-postgres-1
export DB_HOST=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' btv_anmeldung-postgres-1)
export DB_USERNAME=postgres
export POSTGRES_PASSWORD=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' btv_anmeldung-postgres-1 | sed -n 's/^POSTGRES_PASSWORD=//p')
bin/rails tailwindcss:build && bin/rails test
```

System-Tests laufen lokal nicht, weil Chrome nicht startet („DevToolsActivePort“). In CI laufen sie.

Zugänge auf der Design-Umgebung: siehe `~/vault/Sessions/2026-11-05_btv-design-umgebung-und-skills.md`.

## 7. Commits auf `design`

```
1001a38 Redesign Phase 0+1: Glas-Grundlage und neue Navigation
892a263 Redesign Phase 2: Kursfoto pro Kurs, aufgeräumte Kategorie-Bilder
a244fc6 Redesign Phase 3: Kursübersicht als Foto-Karten mit Tag/Ort-Filter
9ef54e6 Redesign Phase 4: Kursseite und Anmeldung
18e0fe8 Redesign Phase 5: Dashboards
22ab94d Redesign Phase 6: restliche Ansichten
9fd9e2c Redesign: Vereinsfarben ohne Grünstich, Kursübersicht als Kategorie-Kacheln
2347cdb Kursübersicht: Tag-Filter im Kategorie-Overlay
e97acf2 Abnahme: Handy-Überläufe und Kollisionen mit der Tab-Leiste behoben
0164acc Abnahme Admin: Suchfelder am Handy, Speichern-Buttons der Ferientage
1fbaf67 Scanner, Admin-Dashboard und Startseite an den neuen Stil angepasst
9bfdf64 Kursübersicht: Filterleiste neu – Tage als Segment-Leiste, Ort als Auswahl
8274448 Präsenzkontrolle: QR-Scanner-Button als dunkle Pill statt violett
5285c98 Button-Audit Admin: einheitliche Form, richtige Ziele, kein Abschneiden am Handy
eb9eb10 Button-Audit Nachtrag: Handy-Umbrüche und Newsletter-Speichern
425d9c7 Kursseite: Trainer & Admin Bereich als gleichmässiges Button-Raster
30be793 Button-Gruppen: gleich grosse Buttons im Raster (Handy 2 Spalten)
64c0723 Ferientage-Kopf bricht um statt Löschen abzuschneiden; Newsletter-Buttons am Handy mit Textumbruch
9dfc741 Navigation: Kontoeinstellungen unten in der Sidebar und im Mehr-Menü
```

## 8. Nächste Schritte

1. Kategorie-Bilder auf der Design-Umgebung hochladen und alles nochmals durchklicken.
2. Entscheiden, welche offenen Punkte aus Abschnitt 5 noch vor dem Livegang erledigt werden.
3. Freigabe → `design` nach `staging` mergen (test.btvbern-anmeldung.ch), dort prüfen.
4. Freigabe → `staging` nach `main` (Produktion).
