# Admin-Bereich: Architektur-Plan (Kommandozentrale)

Stand 05.11.2026, Branch `design`. Erstellt mit `wi-architect` (Abläufe/Risiken) und
`admin-architect` (Code-Struktur). **Noch kein Produktivcode geändert.**

Leitsatz: Jede bestehende Funktion bleibt erhalten und funktioniert gleich. Sie wird
nur logisch eingeordnet und von der Übersicht aus schneller erreichbar.
Es geht um die **Abläufe in der Oberfläche**, nicht um Geschwindigkeit. Gemessen:
Die Admin-Seiten haben keine N+1-Abfragen (7 Queries auf der Kommandozentrale, egal
ob 2 oder 22 Kurse).

---

## 1. Ist-Analyse

### 1.1 Was die Kommandozentrale heute ist

`app/views/dashboards/admin.html.erb`, **537 Zeilen in einer Datei**, vier Blöcke:

| Block | Zeilen | Inhalt |
|---|---|---|
| Schnellzugriff | 17–270 | 15 von Hand kopierte Link-Zeilen in 3 Gruppen |
| Teilnehmer-Suche | 272–408 | Suche + CSV-Export über Export-Profile |
| Kurs-Übersicht | 410–492 | Aktive Kurse mit Filter und „Mehr anzeigen“ |
| Archiv | 494–537 | Vergangene Kurse nach Zeitraum |

Es fehlt eine **Zusammenfassung**: Man sieht nicht, ob etwas zu tun ist. Ob z.B.
Präsenzkontrollen offen sind, erfährt man erst nach dem Klick auf den Link.

### 1.2 Falsch eingeordnete Funktionen (Hauptproblem)

Der Einstellungs-Hub (`/admin/einstellungen`) enthält tägliche Arbeit, keine Einstellungen:

| Funktion | Liegt heute unter | Gehört zu |
|---|---|---|
| Newsletter schreiben/senden | Einstellungen › Kommunikation (`admin/settings/communication.html.erb:42`) | Kommunikation |
| Newsletter-Abonnenten | Einstellungen › Kommunikation (`:48`) | Kommunikation |
| Berichte (BTV, Sportfonds, Krabbel-Gym) | Einstellungen › Daten (`admin/settings/data.html.erb:21`) | Auswertung |
| NDS / J+S-Export, AWK | Einstellungen › Daten (`:25`) | Auswertung |
| Export-Profile | Einstellungen › Daten (`:16`) | Auswertung |
| Mail-Protokoll | nur Hauptnavigation, nicht im Admin-Bereich | Kommunikation |

Umgekehrt ist die einzige echte Funktions-Einstellung (`FeatureSetting`, 1 Schalter)
der einzige Inhalt ihres Tabs, und viele Geschäftsregeln sind fest im Code (1.4).

### 1.3 Klickwege heute → Ziel

Gezählt ab der Kommandozentrale (Links laut Views).

| Aufgabe | Heute | Problem | Ziel |
|---|---|---|---|
| Newsletter schreiben | Einstellungen › Kommunikation → Newsletter → Neu (3) | versteckt unter „Einstellungen“ | Kommunikation → Neu (2), Entwürfe als Zahl sichtbar |
| Sportfonds-Bericht | Einstellungen › Daten → Berichte (2) | unter „Einstellungen“ erwartet niemand Berichte | Auswertung → Berichte (2) |
| NDS-Export | Einstellungen › Daten → NDS (2) | dito | Auswertung → NDS (2) |
| Offene Präsenzkontrollen prüfen | Link (1), Anzahl erst danach sichtbar | Klick nötig, um zu wissen, ob etwas offen ist | Kachel zeigt Anzahl direkt (0 Klicks zum Wissen) |
| Offene Nachforderungen | Verwaltung → Nachforderungen (1), Status erst danach | dito | Kachel mit Anzahl |
| Mail-Protokoll | ausserhalb des Admin-Bereichs | nicht in der Admin-Struktur | Kommunikation → Mail-Protokoll |
| Regel ändern (z.B. Schnupperfrist) | nicht möglich, Code-Änderung | Medienbruch: Entwickler nötig | Einstellungen › Funktionen & Regeln |

### 1.4 Fest verdrahtete Geschäftsregeln (Kandidaten für globale Einstellungen)

| Regel | Wert | Beleg |
|---|---|---|
| Schnuppertraining verfällt nach | 5 Tage | `course_registration.rb:112,273`, `expire_trial_registrations_job.rb:10`, `participant.rb:79` |
| Zahlungsfrist nach Nachrücken (Warteliste) | 5 Tage | `waitlist_promotion_service.rb:83` |
| Mindest-Restfrist beim Verschieben Schnuppern | 48 h | `course_registration.rb:263-265` |
| Präsenzkontrolle öffnet vor Trainingsbeginn | 1 h | `training_session.rb:24` |
| Trainer-Erinnerung offene Präsenz nach | 24 h | `training_session.rb:47` |
| Admin-Meldung offene Präsenz nach | 7 Tage | `training_session.rb:51` |
| Erinnerung manuelle Anmeldung nach | 7 Tage | `manual_enrollment_reminder_job.rb:14` |
| Mail-Protokoll wird gelöscht nach | 12 Monate | `mail_log.rb:4` (Datenschutz) |

### 1.5 Code-Struktur

| Befund | Beleg |
|---|---|
| Admin-Seiten an 3 Orten: `DashboardsController` (6 Actions), `Admin::*` (12 Controller), Top-Level (`Trainers`, `Terms`, `HolidayTypes`, `CourseCategories`, `Newsletters`, `NewsletterSubscribers`, `MailSettings`) | `config/routes.rb:6-58` |
| Kein `Admin::BaseController`: jeder Admin-Controller wiederholt `authenticate_user!` + `authorize_admin!` | z.B. `admin/feature_settings_controller.rb:5-6` |
| `TermsController` lädt den Datensatz vor der Admin-Prüfung | `terms_controller.rb:2-3` |
| Linklisten doppelt: Dashboard-Schnellzugriff und Settings-Tabs pflegen eigene Listen | `dashboards/admin.html.erb:17-270`, `admin/settings/_tabs.html.erb:2-8` |
| Teilnehmer-Suchabfrage doppelt (Dashboard + Export) | `dashboards_controller.rb:39-46`, `:59-63` |
| Gutes Vorbild vorhanden: `NotificationCatalog` (Registry) + JSONB-Schalter | `models/notification_catalog.rb`, `models/mail_setting.rb:52-74` |

### 1.6 Prozess-Risiken (wi-architect)

| Befund | Beleg | Status |
|---|---|---|
| Eltern konnten über `CourseRegistrations#update` den Zahlungsstatus setzen (offener Punkt der Arbeitsliste) | `course_registrations_controller.rb:6,1256` | **bereits behoben** in `d91c12d` |
| Einstellbare Fristen könnten Jobs/Mails falsch steuern, wenn ein unsinniger Wert gesetzt wird | – | Gegenmassnahme: Min/Max je Eintrag in der Registry |

Zahlung, Rückerstattung, Warteliste und Mailversand werden vom Umbau nicht angefasst.

### 1.7 Testabdeckung heute

| Bereich | Abgedeckt |
|---|---|
| Kommandozentrale | `dashboards_controller_test.rb`: Kursliste, Filter, Archiv, Nachforderungs-Link |
| Einstellungs-Hub | `admin/settings_controller_test.rb`: Tabs, Zugriffsschutz, Weiterleitungen |
| Statistik, Talente, NDS, Berichte, Export-Profile | **kein Zugriffstest** |

---

## 2. Zielbild

### 2.1 Informationsarchitektur

```
Übersicht                     „Was ist heute zu tun?“
├── Handlungsbedarf           Kacheln mit Anzahl + Link (nur sichtbar, wenn > 0)
├── Suche                     Teilnehmende (wie heute, inkl. Export)
└── Bereiche                  6 Karten mit ihren Seiten (Schnellzugriff)

Kurse          aktive Kurse · Archiv · Kategorien · Zeiträume · Ferientage
Personen       Trainer:innen · Altersausnahmen  (Teilnehmende über die Suche)
Finanzen       Nachforderungen · Zahlungsabgleich (SumUp)
Kommunikation  Newsletter · Abonnenten · Mail-Protokoll · System-Mails
Auswertung     Statistiken · Talentliste · Berichte · NDS/J+S · Export-Profile
Einstellungen  nur Konfiguration:
               Verein · E-Mail-Versand · Zahlungsanbieter · Newsletter-API
               · Funktionen & Regeln (neu) · Meine Benachrichtigungen
```

Jede Bereichsseite hat denselben Aufbau: Kopf mit „← Übersicht“, Titel, Liste der
Seiten als Link-Karten. Jede Unterseite führt zurück zu ihrem Bereich, nicht immer
zur Übersicht. Alte URLs leiten weiter.

### 2.2 Code-Struktur

**Bewusst nicht** in den Admin-Namespace verschoben: die CRUD-Controller (`Trainers`,
`Terms`, …). Das würde viele Path-Helper in Views, Mails und Tests umbenennen, ohne dass
der Admin etwas davon merkt.

```
app/controllers/admin/base_controller.rb         Zugriffsschutz einmal
app/controllers/admin/sections_controller.rb     eine Action für alle 6 Bereichsseiten
app/models/admin_navigation.rb                   Registry: Bereich → Seiten (Label, Pfad, Icon, Badge)
app/models/settings_catalog.rb                   Registry: globale Regeln (Muster NotificationCatalog)
app/models/admin/dashboard_overview.rb           Zähler für „Handlungsbedarf“
app/views/admin/shared/_page_header.html.erb     locals: title, subtitle, back_url
app/views/admin/shared/_section_card.html.erb    locals: section
app/views/admin/shared/_link_row.html.erb        locals: item
app/views/admin/dashboard/_kpi_tile.html.erb     locals: label, count, url, tone
app/views/admin/settings/_setting_field.html.erb locals: entry, form
```

**`AdminNavigation`** ist die einzige Quelle für Übersicht, Bereichsseiten und
Einstellungs-Tabs. Neue Admin-Seite = 1 Eintrag + 1 Locale-Text.

**`SettingsCatalog`**:

```ruby
entry key: :trainer_self_enroll_enabled, type: :boolean, default: true, group: :trainers   # bestehender Schalter
entry key: :trial_expiry_days,           type: :integer, default: 5,    min: 1, max: 30, group: :registration
entry key: :waitlist_payment_days,       type: :integer, default: 5,    min: 1, max: 30, group: :registration
```

Gespeichert in einer neuen JSONB-Spalte `values` auf der bestehenden Tabelle
`feature_settings`. Abfrage: `FeatureSetting.value(:trial_expiry_days)`. Ohne
gespeicherten Wert gilt der Default, also das heutige Verhalten. Die Seite „Funktionen &
Regeln“ wird komplett aus dem Katalog gerendert: **neuer globaler Schalter = 1 Eintrag +
1 Locale-Text**, ohne neue View und ohne neue Action.

### 2.3 Routen (Ergänzungen)

```ruby
namespace :admin do
  get "bereich/:id", to: "sections#show", as: :section,
      constraints: { id: /kurse|personen|finanzen|kommunikation|auswertung/ }
  get "einstellungen/regeln", to: "settings#rules", as: :settings_rules
  # alle bestehenden admin-Routen bleiben
end
# /dashboards/admin bleibt die Übersicht (URL unverändert, Bookmarks funktionieren).
# Einstellungs-Tab „Daten“ → redirect auf admin_section_path("auswertung").
```

---

## 3. Umsetzung in einzelnen Schritten

Jeder Schritt ist ein eigener Commit auf `design`. Die volle Testsuite ist danach grün,
und keine Funktion verschwindet.

| # | Schritt | Sichtbar für Admin | Test |
|---|---|---|---|
| 0 | Charakterisierungstest: jede Admin-Seite → 200 für Admin, Umleitung für Eltern/Trainer; jede heutige Seite ist von der Übersicht aus erreichbar | nein | neu: `test/integration/admin_access_test.rb` |
| 1 | `Admin::BaseController`, Admin-Controller erben davon; Filterreihenfolge `TermsController` | nein | Schritt 0 |
| 2 | `AdminNavigation` + Partials; Schnellzugriff und Tabs daraus rendern; Dashboard-View von 537 auf ~150 Zeilen | nein (gleiches Bild) | bestehende Dashboard-Tests |
| 3 | Neue Bereiche: Bereichsseiten, Newsletter/Mail-Protokoll → Kommunikation, Berichte/NDS/Export → Auswertung; Einstellungen nur noch Konfiguration; Weiterleitungen | **ja** | Weiterleitungstests |
| 4 | Übersicht mit Handlungsbedarf-Kacheln | **ja** | 1 Test je Kachel |
| 5 | `SettingsCatalog` + Seite „Funktionen & Regeln“, bestehender Schalter übernommen | **ja** | Default = heutiger Wert |
| 6 | Freigegebene Fristen aus 1.4 einzeln auf den Katalog umstellen, **je Regel ein Commit** | **ja** | bestehende Job-/Model-Tests grün + 1 Test mit geändertem Wert |

**Migration/Rollback:** Einzige DB-Änderung ist Schritt 5 (`add_column :feature_settings,
:values, :jsonb, default: {}, null: false`), additiv. Fehlt ein Wert, gilt der Default.
Ein Rollback ändert also kein Verhalten.

**Bewusst nicht geändert:** CRUD-Controller ausserhalb des Namespaces, Geschäftslogik
(Zahlung, Rückerstattung, Warteliste, Mails), Design (neue Partials nutzen die Glass-Klassen),
Trainer-Dashboard.

---

## 4. Entscheide (05.11.2026)

A. **Kursliste bleibt auf der Übersicht**, unter Handlungsbedarf und Suche. Der Bereich
   „Kurse“ enthält Kategorien, Zeiträume und Ferientage und verweist auf die Liste.
B. **Alle Fristen aus 1.4 werden einstellbar:** Schnupper-Ablauf, Nachrück-Zahlungsfrist,
   Präsenz-Erinnerungen (1 h / 24 h / 7 Tage), Mail-Protokoll-Aufbewahrung. Jede mit
   Min/Max-Grenze, Default = heutiger Wert, je Regel ein Commit (Schritt 6).
C. **Kacheln „Handlungsbedarf“:** offene Präsenzkontrollen, offene Nachforderungen,
   Zahlung ausstehend, Newsletter-Entwürfe. Jede Kachel nur sichtbar, wenn > 0.

---

## 5. Umsetzungsstand (05.11.2026, Branch `design`)

| Schritt | Commit | Ergebnis |
|---|---|---|
| 0 Absicherungstest | `61333fb` | `test/integration/admin_access_test.rb` |
| 1 Admin::BaseController | `6f20f48` | + Terms/Trainers prüfen Admin vor dem Laden |
| – fehlende EN/FR-Texte | `fd3656c` | „translation missing“ im Admin-Bereich behoben |
| 2 AdminNavigation | `49496d8` | `admin.html.erb` 537 → 30 Zeilen, HTML identisch |
| 3 Neue Bereiche | `4034b98` | Einstellungen nur noch Konfiguration |
| 4 Handlungsbedarf | `235652e` | 4 Kacheln + Liste „Offene Zahlungen“ |
| 5 SettingsCatalog | `e9c3ec2` | Seite „Funktionen & Regeln“, JSONB `feature_settings.rules` |
| 6.1 Mail-Protokoll | `374f4b8` | 1–60 Monate |
| 6.2 Präsenzkontrolle | `6bfb58e` | 0–24 h / 1–168 h / 1–60 Tage |
| 6.3 Warteliste | `478d274` | 1–30 Tage, Mail nennt den Wert |
| 6.4 Schnupperfrist | `6edacc7` | 1–30 Tage, Mail/Formular/Hinweis nennen den Wert |

Bewusst weggelassen: eigene Bereichsseiten (`/admin/bereich/:id`). Die Karten auf der
Kommandozentrale zeigen bereits alle Seiten eines Bereichs, eine Zwischenseite wäre
ein zusätzlicher Klick. `Admin::DashboardOverview` als eigene Klasse: Die Kennzahlen
haben nur einen Nutzer und stehen im Controller.

## 6. Entscheide zu den Schlussfragen (05.11.2026)

1. Nachrücken in einen Bezahlkurs: Zahlungsfrist **7 Tage** (wie in der Mail
   versprochen) statt 48 h. Normale Online-Zahlungen behalten 48 h. Die Mail
   „Zahlung abgelaufen“ sagt jetzt „nicht rechtzeitig“ statt fest „48 Stunden“.
2. Abgrenzung „Zahlung ausstehend“: passt so.
3. Bereichsname „Personen & Finanzen“: passt so.
4. Merge nach `staging`: noch offen.
