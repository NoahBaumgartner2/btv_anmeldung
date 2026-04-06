module ApplicationHelper
  require 'rqrcode'

  def club_setting
    @club_setting_cache ||= ClubSetting.current
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