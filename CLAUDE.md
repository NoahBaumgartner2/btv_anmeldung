# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Start development server (Rails + Tailwind CSS watcher)
bin/dev

# Initial setup
bin/setup

# Run all tests
bin/rails test

# Run system tests (Capybara + Selenium)
bin/rails test:system

# Run a single test file
bin/rails test test/models/course_test.rb

# Run a single test by line number
bin/rails test test/models/course_test.rb:42

# Run full CI pipeline locally
bin/ci

# Linting
bin/rubocop

# Security scanning
bin/brakeman --quiet --no-pager
bin/bundler-audit

# Database
bin/rails db:prepare
bin/rails db:seed
bin/rails db:reset
```

## Architecture

**BTV Anmeldung** is a Ruby on Rails 8.1 course registration system for managing training courses, participants, trainers, and attendance. The UI uses Hotwire (Turbo + Stimulus) with TailwindCSS 4.

### Domain Model

```
Users (Devise auth, roles: admin/trainer/parent)
├── Participants (children/students, belong to users)
└── Trainers (staff, belong to users)

Courses (training programs with schedule, capacity, payment/ticketing flags)
├── CourseTrainers (many-to-many: Courses ↔ Trainers)
├── CourseRegistrations (many-to-many: Courses ↔ Participants, with QR ticket)
├── TrainingSessions (auto-generated individual class occurrences)
└── Attendances (per-session attendance records)

Holidays (blackout dates — skipped when generating TrainingSessions)
```

### Key Workflows

**Training Session Auto-Generation**: `Courses#generate_trainings` creates `TrainingSessions` for the course's date range, skipping holidays. Triggered manually from the admin UI after creating a course.

**QR Code Ticketing**: `CourseRegistrations` generate a QR code ticket (via `rqrcode`). `CourseRegistrations#scan` handles ticket scanning; `TrainingSessions#scanner` provides camera-based attendance scanning.

**Attendance Tracking**: Trainers use `TrainingSessions#toggle_attendance` to mark participants present/absent per session.

**Role-Based Access**: `ApplicationController` includes authorization helpers ("Türsteher" pattern) — role checks are enforced per action. Roles: `admin`, `trainer`, `parent`.

### Routes of Note

- `POST /courses/:id/generate_trainings` — triggers session auto-generation
- `GET /course_registrations/:id/scan` — QR code scanner view
- `POST /training_sessions/:id/toggle_attendance` — attendance toggle
- `GET /dashboards/admin` and `/dashboards/trainer` — role-specific dashboards

### Tech Stack

- **Ruby** 3.4.8, **Rails** 8.1.2
- **PostgreSQL** 16
- **Hotwire** (Turbo + Stimulus), **TailwindCSS** 4.4
- **Authentication**: Devise 5.0
- **Background Jobs**: Solid Queue
- **Deployment**: Kamal (`config/deploy.yml`)
- **i18n**: German locale throughout (`config/locales/`)

### Testing

- Unit and controller tests in `test/` with fixtures in `test/fixtures/`
- System tests use Capybara + Selenium
- Tests run in parallel (all CPU cores) — configured in `test/test_helper.rb`
- CI runs: rubocop → brakeman → bundler-audit → yarn audit → tests → system tests
