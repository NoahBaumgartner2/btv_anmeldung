# Zentrales Verzeichnis aller Admin-Seiten, gruppiert nach Bereichen der
# Kommandozentrale (Kurse, Personen & Finanzen, Kommunikation, Auswertung,
# Einstellungen). Einstellungen enthalten nur Konfiguration.
# Einzige Quelle für den Schnellzugriff (dashboards/admin) und die Bereichs-Tabs
# oben auf jeder Admin-Seite (admin/shared/_section_header).
#
# Neue Admin-Seite = 1 Item hier + Texte unter dashboards.admin.links.<key>(_desc).
#
# path:  Name des Route-Helpers (wird in der View aufgelöst)
# icon:  SVG-Pfad (Heroicons outline); Farbe kommt vom Bereich (SECTION_TONES)
class AdminNavigation
  Item = Data.define(:key, :path, :icon)

  # Eine Farbe pro Bereich: alle Seiten eines Bereichs teilen sie.
  SECTION_TONES = {
    courses: :indigo,
    people: :amber,
    communication: :cyan,
    analysis: :green,
    settings: :gray
  }.freeze

  TONES = {
    primary: { row: "hover:bg-primary-50 active:bg-primary-100", box: "bg-primary-100 group-hover:bg-primary-200", icon: "text-primary-600", title: "group-hover:text-primary-700", chevron: "group-hover:text-primary-400", badge: "text-primary-600 bg-primary-100" },
    gray:    { row: "hover:bg-gray-100 active:bg-gray-200",       box: "bg-gray-100 group-hover:bg-gray-200",       icon: "text-gray-600",    title: "group-hover:text-gray-900",    chevron: "group-hover:text-gray-500",    badge: "text-gray-600 bg-gray-100" },
    yellow:  { row: "hover:bg-yellow-50 active:bg-yellow-100",   box: "bg-yellow-100 group-hover:bg-yellow-200",   icon: "text-yellow-600",  title: "group-hover:text-yellow-700",  chevron: "group-hover:text-yellow-400",  badge: "text-yellow-600 bg-yellow-100" },
    indigo:  { row: "hover:bg-indigo-50 active:bg-indigo-100",   box: "bg-indigo-100 group-hover:bg-indigo-200",   icon: "text-indigo-600",  title: "group-hover:text-indigo-700",  chevron: "group-hover:text-indigo-400",  badge: "text-indigo-600 bg-indigo-100" },
    red:     { row: "hover:bg-red-50 active:bg-red-100",         box: "bg-red-100 group-hover:bg-red-200",         icon: "text-red-600",     title: "group-hover:text-red-700",     chevron: "group-hover:text-red-400",     badge: "text-red-600 bg-red-100" },
    cyan:    { row: "hover:bg-cyan-50 active:bg-cyan-100",       box: "bg-cyan-100 group-hover:bg-cyan-200",       icon: "text-cyan-600",    title: "group-hover:text-cyan-700",    chevron: "group-hover:text-cyan-400",    badge: "text-cyan-600 bg-cyan-100" },
    amber:   { row: "hover:bg-amber-50 active:bg-amber-100",     box: "bg-amber-100 group-hover:bg-amber-200",     icon: "text-amber-600",   title: "group-hover:text-amber-700",   chevron: "group-hover:text-amber-400",   badge: "text-amber-600 bg-amber-100" },
    purple:  { row: "hover:bg-purple-50 active:bg-purple-100",   box: "bg-purple-100 group-hover:bg-purple-200",   icon: "text-purple-600",  title: "group-hover:text-purple-700",  chevron: "group-hover:text-purple-400",  badge: "text-purple-600 bg-purple-100" },
    green:   { row: "hover:bg-green-50 active:bg-green-100",     box: "bg-green-100 group-hover:bg-green-200",     icon: "text-green-600",   title: "group-hover:text-green-700",   chevron: "group-hover:text-green-400",   badge: "text-green-600 bg-green-100" },
    orange:  { row: "hover:bg-orange-50 active:bg-orange-100",   box: "bg-orange-100 group-hover:bg-orange-200",   icon: "text-orange-600",  title: "group-hover:text-orange-700",  chevron: "group-hover:text-orange-400",  badge: "text-orange-600 bg-orange-100" },
    teal:    { row: "hover:bg-teal-50 active:bg-teal-100",       box: "bg-teal-100 group-hover:bg-teal-200",       icon: "text-teal-600",    title: "group-hover:text-teal-700",    chevron: "group-hover:text-teal-400",    badge: "text-teal-600 bg-teal-100" }
  }.freeze

  SECTIONS = {
    courses: [
      Item.new(key: :course_categories, path: :course_categories_path,
               icon: "M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"),
      Item.new(key: :terms, path: :terms_path,
               icon: "M8 7V3m8 4V3M3 11h18M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"),
      Item.new(key: :holidays, path: :holiday_types_path,
               icon: "M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"),
      Item.new(key: :open_attendances, path: :open_attendances_dashboard_path,
               icon: "M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"),
      Item.new(key: :archive, path: :archive_dashboard_path,
               icon: "M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z")
    ],
    people: [
      Item.new(key: :trainers, path: :trainers_path,
               icon: "M17 20h5v-2a4 4 0 00-5-3.87M9 20H4v-2a4 4 0 015-3.87m6-4.13a4 4 0 10-8 0 4 4 0 008 0z"),
      Item.new(key: :age_exemptions, path: :admin_age_exemptions_path,
               icon: "M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"),
      Item.new(key: :supplementary_charges, path: :admin_supplementary_charges_path,
               icon: "M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"),
      Item.new(key: :open_payments, path: :open_payments_dashboard_path,
               icon: "M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z")
    ],
    communication: [
      Item.new(key: :newsletters, path: :newsletters_path,
               icon: "M11 5.882V19.24a1.76 1.76 0 01-3.417.592l-2.147-6.15M18 13a3 3 0 100-6M5.436 13.683A4.001 4.001 0 017 6h1.832c4.1 0 7.625-1.234 9.168-3v14c-1.543-1.766-5.067-3-9.168-3H7a3.988 3.988 0 01-1.564-.317z"),
      Item.new(key: :newsletter_subscribers, path: :newsletter_subscribers_path,
               icon: "M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"),
      Item.new(key: :mail_logs, path: :mail_logs_path,
               icon: "M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z")
    ],
    analysis: [
      Item.new(key: :stats, path: :dashboards_stats_path,
               icon: "M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"),
      Item.new(key: :talents, path: :talents_dashboard_path,
               icon: "M11.48 3.499a.562.562 0 011.04 0l2.125 5.111a.563.563 0 00.475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 00-.182.557l1.285 5.385a.562.562 0 01-.84.61l-4.725-2.885a.563.563 0 00-.586 0L6.982 20.54a.562.562 0 01-.84-.61l1.285-5.386a.562.562 0 00-.182-.557l-4.204-3.602a.563.563 0 01.321-.988l5.518-.442a.563.563 0 00.475-.345L11.48 3.5z"),
      Item.new(key: :reports, path: :admin_reports_path,
               icon: "M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"),
      Item.new(key: :nds, path: :admin_nds_path,
               icon: "M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4"),
      Item.new(key: :export_profiles, path: :admin_export_profiles_path,
               icon: "M12 10v6m0 0l-3-3m3 3l3-3M3 17V7a2 2 0 012-2h6l2 2h6a2 2 0 012 2v8a2 2 0 01-2 2H5a2 2 0 01-2-2z")
    ],
    settings: [
      Item.new(key: :settings_communication, path: :admin_settings_communication_path,
               icon: "M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"),
      Item.new(key: :notifications, path: :admin_notifications_path,
               icon: "M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75v-.7V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0"),
      Item.new(key: :settings_club, path: :admin_settings_club_path,
               icon: "M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"),
      Item.new(key: :settings_payments, path: :admin_settings_payments_path,
               icon: "M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"),
      Item.new(key: :settings_features, path: :admin_settings_features_path,
               icon: "M13 10V3L4 14h7v7l9-11h-7z")
    ]
  }.freeze

  def self.items(section) = SECTIONS.fetch(section)
  def self.tone(section) = TONES.fetch(SECTION_TONES.fetch(section))
end
