require "net/http"

# Füllt fehlende Koordinaten laufender Kurse über den Adressdienst des Bundes
# (geo.admin.ch). Es gehen nur die öffentlichen Hallenadressen hinaus. Läuft
# stündlich und deckt damit bestehende, neue und verlängerte Kurse ab; was nicht
# gefunden wird, versucht der nächste Lauf wieder.
class GeocodeCoursesJob < ApplicationJob
  queue_as :default

  SEARCH_URI = URI("https://api3.geo.admin.ch/rest/services/api/SearchServer").freeze

  def perform
    courses = Course.not_archived.where(latitude: nil).where.not(location_address: [ nil, "" ])

    courses.distinct.pluck(:location_address).each do |address|
      latitude, longitude = self.class.locate(address)
      courses.where(location_address: address).update_all(latitude: latitude, longitude: longitude) if latitude
    end
  end

  # Mehrere Hallen („A / B“): die erste zählt. Lange Adressen mit Hallenname findet
  # der Dienst nicht, deshalb als Rückfall nur „Strasse, PLZ Ort“.
  def self.locate(address)
    first = address.split(" / ").first.to_s
    [ first, first.split(",").last(2).join(",").strip ].uniq.lazy.filter_map { |text| search(text) }.first
  end

  def self.search(text)
    uri = SEARCH_URI.dup
    uri.query = URI.encode_www_form(searchText: text, type: "locations", origins: "address", limit: 1, sr: 4326)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) { |http| http.get(uri.request_uri) }
    attrs = JSON.parse(response.body).dig("results", 0, "attrs")
    [ attrs["lat"], attrs["lon"] ] if attrs
  rescue StandardError => e
    # Der nächste Lauf versucht es wieder; eine Adresse darf die anderen nicht stoppen.
    Rails.logger.warn "[GeocodeCoursesJob] #{e.class}: #{e.message}"
    nil
  end
end
