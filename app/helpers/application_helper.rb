module ApplicationHelper
  require "rqrcode"

  def club_setting
    @club_setting_cache ||= ClubSetting.current
  end

  def favicon_tags
    cs   = club_setting
    url  = cs&.logo_url || "/icon.png"
    v    = cs&.updated_at&.to_i || 0
    mime = cs&.logo&.attached? ? cs.logo.blob.content_type : "image/png"
    href = "#{url}?v=#{v}"

    tag.link(rel: "shortcut icon", href: href, type: mime) +
      tag.link(rel: "icon", href: href, type: mime) +
      tag.link(rel: "apple-touch-icon", href: href)
  end

  # Heroicons (outline, 24px) für Sidebar und Tab-Leiste.
  NAV_ICONS = {
    courses: "M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5",
    my_profile: "M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z",
    my_courses: "M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z",
    mails: "M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75",
    admin_dashboard: "M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z",
    login: "M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15M12 9l3 3m0 0l-3 3m3-3H2.25",
    register: "M19 7.5v3m0 0v3m0-3h3m-3 0h-3m-2.25-4.125a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zM4 19.235v-.11a6.375 6.375 0 0112.75 0v.109A12.318 12.318 0 0110.374 21c-2.331 0-4.512-.645-6.374-1.766z",
    logout: "M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9",
    account_settings: "M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.325.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.241-.438.613-.43.992a7.723 7.723 0 010 .255c-.008.378.137.75.43.991l1.004.827c.424.35.534.955.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.47 6.47 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.281c-.09.543-.56.94-1.11.94h-2.594c-.55 0-1.019-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.991a6.932 6.932 0 010-.255c.007-.38-.138-.751-.43-.992l-1.004-.827a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.086.22-.128.332-.183.582-.495.644-.869l.214-1.28zM15 12a3 3 0 11-6 0 3 3 0 016 0z",
    more: "M6.75 12a.75.75 0 11-1.5 0 .75.75 0 011.5 0zM12.75 12a.75.75 0 11-1.5 0 .75.75 0 011.5 0zM18.75 12a.75.75 0 11-1.5 0 .75.75 0 011.5 0z"
  }.freeze

  # Inhalts-Icons (Heroicons 24px) statt Emojis. :star_solid ist gefüllt, alle
  # anderen sind Umriss-Icons. Farbe über text-*-Klassen in css.
  UI_ICONS = {
    star: "M11.48 3.499a.562.562 0 011.04 0l2.125 5.111a.563.563 0 00.475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 00-.182.557l1.285 5.385a.562.562 0 01-.84.61l-4.725-2.885a.563.563 0 00-.586 0L6.982 20.54a.562.562 0 01-.84-.61l1.285-5.386a.562.562 0 00-.182-.557l-4.204-3.602a.563.563 0 01.321-.988l5.518-.442a.563.563 0 00.475-.345L11.48 3.5z",
    check_circle: "M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z",
    warning: "M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z",
    x_circle: "M9.75 9.75l4.5 4.5m0-4.5l-4.5 4.5M21 12a9 9 0 11-18 0 9 9 0 0118 0z",
    calendar: "M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5"
  }.freeze

  def ui_icon(name, css = "w-4 h-4")
    solid = name == :star_solid
    d = UI_ICONS.fetch(solid ? :star : name)
    tag.svg(tag.path(stroke_linecap: "round", stroke_linejoin: "round", d: d),
            class: "inline-block shrink-0 #{css}", xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24",
            fill: solid ? "currentColor" : "none", stroke: "currentColor", stroke_width: "1.75", aria_hidden: "true")
  end

  def nav_icon(key, css = "w-5 h-5 shrink-0")
    tag.svg(tag.path(stroke_linecap: "round", stroke_linejoin: "round", d: NAV_ICONS.fetch(key)),
            class: css, xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24",
            stroke: "currentColor", stroke_width: "1.75", aria_hidden: "true")
  end

  # Navigation für Sidebar (Desktop) und Tab-Leiste (Handy). Gleiche Sichtbarkeits-
  # regeln wie die frühere Top-Navigation. → [[gruppe, [{ key:, path: }, …]], …]
  def nav_sections
    return [ [ :general, [ { key: :courses, path: courses_path } ] ],
             [ :account, [ { key: :login, path: new_user_session_path },
                           { key: :register, path: new_user_registration_path } ] ] ] unless user_signed_in?

    trainer = Trainer.exists?(user: current_user)
    staff = current_user.admin? || trainer
    training = []
    training << { key: :my_courses, path: dashboards_trainer_path } if trainer
    training << { key: :mails, path: mail_logs_path } if staff

    sections = [ [ :general, [ { key: :courses, path: courses_path },
                               { key: :my_profile, path: staff ? my_profile_path : participants_path } ] ] ]
    sections << [ :training, training ] if training.any?
    sections << [ :admin, [ { key: :admin_dashboard, path: dashboards_admin_path } ] ] if current_user.admin?
    sections
  end

  # Bereich und Seite der Kommandozentrale zur aktuellen Seite (für den
  # Bereichskopf mit Tabs). active: Item-Key erzwingen, sonst per Pfad.
  def admin_section_for_current_page(active = nil)
    AdminNavigation::SECTIONS.each do |section, items|
      item = items.find { |i| active ? i.key == active : request.path == send(i.path) }
      return [ section, item ] if item
    end
    nil
  end

  def nav_current?(path)
    request.path == path || request.path.start_with?("#{path}/")
  end

  def generate_qr_code(text)
    qrcode = RQRCode::QRCode.new(text)

    svg = qrcode.as_svg(
      color: "000000",
      shape_rendering: "crispEdges",
      module_size: 5,
      standalone: true,
      use_path: true,
      viewbox: true  # <--- HIER IST DER MAGISCHE TRICK!
    )
    svg.html_safe
  end
end
