# Zentrales Verzeichnis aller Admin-Seiten, gruppiert nach Bereichen der
# Kommandozentrale. Einzige Quelle für den Schnellzugriff (dashboards/admin)
# und die Tabs des Einstellungs-Hubs (admin/settings/_tabs).
#
# Neue Admin-Seite = 1 Item hier + Texte unter dashboards.admin.links.<key>(_desc).
#
# path:  Name des Route-Helpers (wird in der View aufgelöst)
# tone:  Farbschema aus TONES (Klassen ausgeschrieben, damit Tailwind sie findet)
# icon:  SVG-Pfad (Heroicons outline) – oder emoji: für ein Zeichen statt Icon
# tab:   Schlüssel des Einstellungs-Tabs (nur Bereich :settings)
class AdminNavigation
  Item = Data.define(:key, :path, :tone, :icon, :emoji, :tab) do
    def initialize(key:, path:, tone:, icon: nil, emoji: nil, tab: nil) = super
  end

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
    management: [
      Item.new(key: :trainers, path: :trainers_path, tone: :primary,
               icon: "M17 20h5v-2a4 4 0 00-5-3.87M9 20H4v-2a4 4 0 015-3.87m6-4.13a4 4 0 10-8 0 4 4 0 008 0z"),
      Item.new(key: :holidays, path: :holiday_types_path, tone: :yellow,
               icon: "M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"),
      Item.new(key: :terms, path: :terms_path, tone: :indigo,
               icon: "M8 7V3m8 4V3M3 11h18M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"),
      Item.new(key: :open_attendances, path: :open_attendances_dashboard_path, tone: :red,
               icon: "M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"),
      Item.new(key: :course_categories, path: :course_categories_path, tone: :cyan,
               icon: "M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"),
      Item.new(key: :supplementary_charges, path: :admin_supplementary_charges_path, tone: :amber,
               icon: "M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"),
      Item.new(key: :age_exemptions, path: :admin_age_exemptions_path, tone: :purple,
               icon: "M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z")
    ],
    analysis: [
      Item.new(key: :stats, path: :dashboards_stats_path, tone: :green,
               icon: "M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"),
      Item.new(key: :talents, path: :talents_dashboard_path, tone: :amber, emoji: "⭐")
    ],
    settings: [
      Item.new(key: :settings_communication, path: :admin_settings_communication_path, tone: :gray, tab: :communication,
               icon: "M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"),
      Item.new(key: :settings_club, path: :admin_settings_club_path, tone: :orange, tab: :club,
               icon: "M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"),
      Item.new(key: :settings_payments, path: :admin_settings_payments_path, tone: :indigo, tab: :payments,
               icon: "M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"),
      Item.new(key: :settings_data, path: :admin_settings_data_path, tone: :teal, tab: :data,
               icon: "M12 10v6m0 0l-3-3m3 3l3-3M3 17V7a2 2 0 012-2h6l2 2h6a2 2 0 012 2v8a2 2 0 01-2 2H5a2 2 0 01-2-2z"),
      Item.new(key: :settings_features, path: :admin_settings_features_path, tone: :purple, tab: :features,
               icon: "M13 10V3L4 14h7v7l9-11h-7z")
    ]
  }.freeze

  def self.items(section) = SECTIONS.fetch(section)
  def self.tone(item) = TONES.fetch(item.tone)
end
