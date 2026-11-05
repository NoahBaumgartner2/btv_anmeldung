require "test_helper"

class GeocodeCoursesJobTest < ActiveJob::TestCase
  def course(address, **attrs)
    Course.new(title: "Kurs", category: "Turnen", registration_type: "semester", registration_mode: "semester",
               has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
               end_date: 3.months.from_now, location_address: address, **attrs).tap { |c| c.save!(validate: false) }
  end

  def with_search(implementation)
    original = GeocodeCoursesJob.method(:search)
    GeocodeCoursesJob.define_singleton_method(:search, implementation)
    yield
  ensure
    GeocodeCoursesJob.define_singleton_method(:search, original)
  end

  test "füllt Kurse mit derselben Adresse mit einer Anfrage" do
    first = course("Hallenweg 1, Bern")
    second = course("Hallenweg 1, Bern")
    searches = []

    with_search(->(text) { searches << text; [ 46.9, 7.4 ] }) { GeocodeCoursesJob.perform_now }

    assert_equal [ "Hallenweg 1, Bern" ], searches
    assert_equal [ 46.9, 7.4 ], [ first.reload.latitude, first.longitude ]
    assert_equal 46.9, second.reload.latitude
  end

  test "lässt bereits verortete und nicht gefundene Kurse aus" do
    located = course("Hallenweg 1, Bern", latitude: 1.0, longitude: 2.0)
    missing = course("Unbekannt, Nirgendwo")

    with_search(->(_text) { nil }) { GeocodeCoursesJob.perform_now }

    assert_equal 1.0, located.reload.latitude
    assert_nil missing.reload.latitude
  end

  test "versucht bei langen Adressen Strasse und Ort und nimmt von mehreren Hallen die erste" do
    searches = []
    search = ->(text) { searches << text; text.start_with?("Nationales") ? nil : [ 46.9, 7.4 ] }

    with_search(search) do
      assert_equal [ 46.9, 7.4 ], GeocodeCoursesJob.locate("Nationales Zentrum, Halle 31, Mingerstrasse 3, 3014 Bern / Hallenweg 1, Bern")
    end
    assert_equal [ "Nationales Zentrum, Halle 31, Mingerstrasse 3, 3014 Bern", "Mingerstrasse 3, 3014 Bern" ], searches
  end

  test "neue Adresse löscht die alten Koordinaten" do
    located = course("Hallenweg 1, Bern", latitude: 1.0, longitude: 2.0)

    located.location_address = "Neue Strasse 2, Bern"
    located.save!(validate: false)

    assert_nil located.reload.latitude
    assert_nil located.longitude
  end

  test "SwissGeo kennt Postleitzahlen und rechnet die Luftlinie" do
    bern = SwissGeo.coordinates(" 3008 ")
    biel = SwissGeo.coordinates("2504")

    assert_nil SwissGeo.coordinates("0000")
    assert_in_delta 25, SwissGeo.distance_km(bern, biel), 5
    assert_in_delta 0, SwissGeo.distance_km(bern, bern), 0.001
  end
end
