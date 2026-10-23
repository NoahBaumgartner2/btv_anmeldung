require "test_helper"

class ExportProfileBaspoTest < ActiveSupport::TestCase
  DATES = Date.new(2026, 3, 1)..Date.new(2026, 3, 31)

  test "AWK-CSV entspricht der BASPO-Vorlage" do
    participants(:one).update_columns(js_person_number: "123456789")
    lines = ExportProfile.generate_baspo_awk_csv(courses(:one), DATES).delete_prefix("\xEF\xBB\xBF").split("\r\n")

    assert_equal "PERSONENNUMMER;FUNKTION;DATUM;AKTIVITÄTSTYP;ZEIT;DAUER;ORT", lines.first
    assert_match(/\A123456789;Teilnehmer\/in;29\.03\.2026;Training;\d\d:\d\d;60;/, lines.second)
    assert_equal 2, lines.size
  end

  test "AWK-CSV lässt Zeilen ohne Personennummer weg" do
    participants(:one).update_columns(js_person_number: nil)
    lines = ExportProfile.generate_baspo_awk_csv(courses(:one), DATES).split("\r\n")

    assert_equal 1, lines.size
  end

  test "Personenimport-CSV hat die Spalten der BASPO-Vorlage" do
    header = ExportProfile.generate_baspo_person_csv([]).delete_prefix("\xEF\xBB\xBF").chomp
    assert_equal "PERSONENNUMMER;NAME;VORNAME;GEBURTSDATUM;GESCHLECHT;AHV_NR;PEID;NATIONALITAET;MUTTERSPRACHE;STRASSE;HAUSNUMMER;PLZ;ORT;LAND", header
  end
end
