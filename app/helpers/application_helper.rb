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

    tag.link(rel: "icon", href: href, type: mime) +
      tag.link(rel: "apple-touch-icon", href: href)
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
