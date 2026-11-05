# Entfernungen über Schweizer Postleitzahlen. Die Tabelle liegt in der App, damit
# keine Adressen von Familien an einen externen Dienst gehen.
module SwissGeo
  POSTCODES_FILE = Rails.root.join("config/swiss_postcodes.csv")
  EARTH_RADIUS_KM = 6371.0

  def self.coordinates(zip_code)
    postcodes[zip_code.to_s.strip]
  end

  # Luftlinie (Haversine). ponytail: kein ÖV-Weg, reicht für eine geringe Gewichtung.
  def self.distance_km(from, to)
    lat1, lon1, lat2, lon2 = [ *from, *to ].map { |degrees| degrees * Math::PI / 180 }
    a = Math.sin((lat2 - lat1) / 2)**2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin((lon2 - lon1) / 2)**2
    2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt(a))
  end

  def self.postcodes
    @postcodes ||= File.foreach(POSTCODES_FILE, encoding: "UTF-8").each_with_object({}) do |line, map|
      next if line.start_with?("#")

      zip_code, latitude, longitude = line.strip.split(",")
      map[zip_code] = [ latitude.to_f, longitude.to_f ].freeze
    end.freeze
  end
  private_class_method :postcodes
end
