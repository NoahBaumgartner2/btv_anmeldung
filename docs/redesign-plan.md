# Redesign-Plan BTV Anmeldung (Branch `design`)

Vorlage: Video „Admin Dashboard V2“ – Glas-Look auf weichem Farbverlauf, Sidebar mit
gruppierter Navigation, helle Milchglas-Karten mit dunklem Text, dunkle Pill-Buttons,
Stat-Karten mit Icon, Segment-Tabs, sanfter Blur-Übergang beim Seitenwechsel.

## Entscheide (mit Noah geklärt, 05.11.2026)

| Thema | Entscheid |
|---|---|
| Kursfoto | Eigenes Foto pro Kurs. Fallback: Kategorie-Bild → Farbverlauf |
| Kursseite | Foto-Karten-Grid pro Kategorie, ganze Karte klickbar → Kursseite/Anmeldung |
| Farben | Verlauf und Akzente aus den ClubSetting-Farben (Admin-Einstellung bleibt wirksam) |
| Navigation | Desktop: Glas-Sidebar für alle Rollen. Handy: Glas-Tab-Leiste unten + „Mehr“-Drawer |
| Rollout | Phase für Phase auf `design` pushen → design.btvbern-anmeldung.ch |

## Leitplanken

- **Funktion bleibt identisch.** Keine Änderung an Routen, Controllern (ausser Foto-Upload),
  Services, Jobs, Berechtigungen. Nur Markup/CSS + Foto-Feature.
- **Nicht angefasst:** E-Mails (Mail-Clients können kein Glas), PDF-/QR-Ausgabe.
- **QR-Codes bleiben auf weissem Grund** (Scan-Kontrast).
- **Lesbarkeit vor Effekt:** Karten sind helles Milchglas (≈ weiss 70 %) mit dunklem Text,
  der Verlauf liegt nur im Hintergrund → Kontrast AA unabhängig von den Vereinsfarben.
  Fallback ohne `backdrop-filter` und bei `prefers-reduced-transparency`: deckend weiss.
- **Performance Handy:** Blur nur auf Shell (Sidebar/Tab-Leiste/Topbar) und Karten erster
  Ebene, nie verschachtelt. Hintergrund-Verlauf statisch (kein Video/Canvas).
- **Keine neuen Gems/JS-Libs.** Tailwind 4 + Stimulus + CSS. Animationen nach
  `animation-easing` (ease-out rein, ease-in raus, kleine Feder bei Feedback),
  `prefers-reduced-motion` respektiert.
- Neue Texte in de/en/fr.

## Phasen

### Phase 0 – Design-Grundlage
`app/assets/tailwind/application.css`
- Tokens: Verlauf aus `--color-primary`/`--color-secondary` (color-mix), Glas-Flächen
  (2 Stufen), Radien, Schatten, Motion-Tokens.
- Komponenten-Klassen: `.glass`, `.glass-strong`, `.btn` / `.btn-primary` (dunkle Pill) /
  `.btn-secondary` / `.btn-danger`, `.input`, `.segmented`, `.stat-card`, `.badge`,
  `.table-glass`, `.modal-glass`.
- Seitenwechsel: Turbo View Transitions (`<meta name="view-transition">`) mit Blur-Fade
  wie im Video.

### Phase 1 – App-Shell
`app/views/layouts/application.html.erb` (+ Partials `shared/_sidebar`, `shared/_tabbar`)
- Desktop (≥ lg): Sidebar links mit Gruppen
  *Allgemein* (Kurse, Profil/Kinder) · *Training* (Meine Kurse, Mails) ·
  *Verwaltung* (Admin-Dashboard + bestehende Admin-Links), Logo/Vereinsname oben,
  Benutzer + Sprache + Logout unten. Exakt dieselben Sichtbarkeitsregeln wie heute.
- Topbar: Seitentitel, Benutzer-Avatar (Initialen).
- Handy: Tab-Leiste unten (Kurse · Profil · Meine Kurse [Trainer] · Mehr), Safe-Area.
- Ausgeloggt: schlanke Topbar (Login/Registrieren) statt Sidebar.
- Flash-Toasts und Cookie-Banner im Glas-Stil.

### Phase 2 – Kursfoto (Funktion)
- `Course has_one_attached :photo`; Validierung JPG/PNG/WebP, max. 10 MB.
- Variante `:card` (z. B. 800×500, WebP) über vorhandenes `image_processing`/vips.
- `Course#card_image` → eigenes Foto, sonst Kategorie-Bild (`CourseCategory`), sonst `nil`
  (View zeigt Verlauf).
- Kursformular: Upload-Feld mit Vorschau + „Foto entfernen“; `:photo, :remove_photo`
  in `course_params`.
- **Rollover** (`CourseRolloverService`): Foto auf den Folgekurs übernehmen. Test, dass
  Löschen des alten Kurses das Foto des neuen nicht mitlöscht (geteilter Blob).
- Tests: Fallback-Kette, Upload/Entfernen im Controller, Rollover, ungültiger Dateityp.

### Phase 3 – Kursübersicht `courses/index`
- Pro Kategorie: Überschrift + Chips (Wochentage, Orte) wie heute, darunter Karten-Grid
  (1 Spalte Handy, 2 Tablet, 3 Desktop).
- Karte: Foto oben, Titel, Tag/Zeit, Ort, Preis, Badge freie Plätze / Warteliste / voll /
  eingeschränkt. Ganze Karte = Link auf `course_path` (gleiche Ziele wie die heutigen
  Buttons „Anmelden“ / „Termine ansehen“ / „Warteliste“).
- Admin-Link „Verwalten“ bleibt als eigener Button auf der Karte.
- Eingeschränkte Kurse: gleicher Aufbau, eigener Abschnitt wie heute.
- Hover: leichtes Anheben (Feder), Fokus-Ring für Tastatur.

### Phase 4 – Kursseite + Anmeldung
`courses/show`, `course_registrations/*`: Foto-Header, Infos als Glas-Panels,
Anmeldeformular und Zahlungs-Schritte im neuen Stil, Ticket/QR auf weiss.

### Phase 5 – Dashboards
`dashboards/admin|trainer|stats|talents|open_attendances|show`: Stat-Karten wie im
Video, Segment-Tabs, Tabellen im Glas-Stil.

### Phase 6 – Restliche Ansichten (mechanisch, ohne Umbau der Logik)
Grösste zuerst: `courses/manage` (690 Z.), `courses/_form` (658 Z.), dann
`training_sessions` (inkl. Scanner, Anwesenheit), `participants`, `trainers`,
`admin/*`, `holidays`, `newsletters`, `mail_logs`, `payments`, `terms`, `onboarding`,
`devise/*` (Login/Registrierung als zentrierte Glas-Karte), `pages/*`.
Modals (`_delete_modal`, `_move_registration_modal`, …) als Glas-Modal.

### Phase 7 – Abnahme
- `bin/rails test` + `bin/rails test:system` grün, `bin/rubocop`, `bin/brakeman`.
- Playwright-Screenshots aller Seiten (Handy 390 px + Desktop 1440 px) auf
  design.btvbern-anmeldung.ch, je Rolle Admin/Trainer/Eltern.
- Klick-Durchlauf der Kernabläufe auf der Design-Umgebung: Anmeldung, Zahlung,
  Warteliste, Abmeldung, QR-Scan, Anwesenheit, Kurs anlegen + Trainings generieren.
- Kontrast-Check mit 2–3 verschiedenen Vereinsfarben.
- Danach: Merge `design` → `staging` → `main` nur nach deiner Freigabe.

## Risiken

| Risiko | Gegenmassnahme |
|---|---|
| Grosse Views (manage/_form) brechen beim Umstylen | Nur Klassen tauschen, Struktur/Stimulus-Targets unverändert; System-Tests |
| Glas ruckelt auf alten Handys | Blur-Ebenen begrenzen, Fallback deckend |
| Vereinsfarben ergeben schlechten Kontrast | Text nie direkt auf Verlauf, nur auf hellem Glas |
| iPhone-Fotos (HEIC) | `accept="image/jpeg,image/png,image/webp"` → Safari konvertiert beim Upload zu JPEG |
| Merge-Konflikte mit laufender Arbeit auf `staging` | `staging` regelmässig in `design` mergen |
