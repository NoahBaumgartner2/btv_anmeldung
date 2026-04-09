# Readme

## Backend architecture

```
erDiagram
    USER ||--o{ PARTICIPANT : "ist Elternteil von (1:n)"
    USER ||--o| TRAINER : "hat Trainer-Profil (1:1)"

    PARTICIPANT ||--o{ COURSE_REGISTRATION : "meldet sich an für (1:n)"
    COURSE ||--o{ COURSE_REGISTRATION : "hat Anmeldungen (1:n)"

    TRAINER ||--o{ COURSE_TRAINER : "leitet (1:n)"
    COURSE ||--o{ COURSE_TRAINER : "wird geleitet von (1:n)"

    COURSE ||--o{ TRAINING_SESSION : "findet statt an (1:n)"
    TRAINING_SESSION ||--o{ ATTENDANCE : "hat Anwesenheitsliste (1:n)"
    COURSE_REGISTRATION ||--o{ ATTENDANCE : "gehört zu (1:n)"

    USER {
        int id PK
        string email
        string role "z.B. 'admin', 'parent', 'trainer'"
    }

    PARTICIPANT {
        int id PK
        int user_id FK "Verknüpfung zum Eltern-Account"
        string first_name
        string last_name
        date date_of_birth
        string ahv_number
    }

    COURSE {
        int id PK
        string title
        datetime start_date
        datetime end_date
        string registration_type "z.B. 'einmalig', 'pro_training'"
        boolean has_ticketing
        boolean has_payment
    }

    COURSE_REGISTRATION {
        int id PK
        int participant_id FK
        int course_id FK
        string status "z.B. 'bestätigt', 'warteliste'"
    }

    TRAINER {
        int id PK
        int user_id FK "Verknüpfung zum Login-Account"
        string phone
    }

    COURSE_TRAINER {
        int id PK
        int course_id FK
        int trainer_id FK
    }

    TRAINING_SESSION {
        int id PK
        int course_id FK
        datetime start_time
        datetime end_time
        boolean is_canceled "z.B. wenn der Trainer krank ist"
    }

    ATTENDANCE {
        int id PK
        int training_session_id FK
        int course_registration_id FK
        string status "z.B. 'anwesend', 'entschuldigt'"
    }

    HOLIDAY {
        int id PK
        string title "z.B. 'Herbstferien'"
        date start_date
        date end_date
    }
```

![ER-Diagramm](/Documentation/Bildschirmfoto%202026-03-29%20um%2017.46.59.png)


TODO

- 1. Rechtliches & Compliance (höchste Priorität)
Für die Schweiz und DSGVO/DSG brauchst du unbedingt eine Datenschutzerklärung und AGB, die direkt in der App verlinkt sind. Ein Cookie-Consent-Banner fehlt komplett. Bei der Registrierung sollte eine Checkbox für die Zustimmung zu den AGB/Datenschutz vorhanden sein. Dein Devise erlaubt zwar subscribe_to_newsletter, aber ein Newsletter-Opt-in ohne rechtliche Grundlage ist problematisch. Ausserdem solltest du eine Impressum-Seite einbauen — in der Schweiz (UWG) und besonders bei der DSGVO für EU-Kunden ist das Pflicht.

- automatisches anmelden newsletter
- https://www.kids-sport.ch/
- trainer separat (von hand)
- wenn training mehr als 1.5h, dann max 1.5h
- course form.html.erb alter begränzen
- möglichkeit für rückerstattung wobei admin benachrichtigt wird

### Workflow NDS
- 1. Teilnehmende exportieren meine datenbank
- 2. Teilnehmende importieren NDS 
- 3. Teilnehemnde exportieren NDS 
- 4. Teilnehemnde importieren meine datenbank (AHV Überprüfung (unique))
- 5. Anwesenheitkontrolle exportieren meine datenbank
- 6. Anwesenheitkontrolle importieren NDS