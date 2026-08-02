require "test_helper"

class TermTest < ActiveSupport::TestCase
  test "valide mit Name, Start- und Enddatum" do
    term = Term.new(name: "WS2030", start_date: Date.new(2030, 8, 1), end_date: Date.new(2030, 12, 1))
    assert term.valid?
  end

  test "Name muss eindeutig sein" do
    term = Term.new(name: terms(:one).name, start_date: Date.new(2030, 1, 1), end_date: Date.new(2030, 6, 1))
    assert_not term.valid?
    assert_includes term.errors[:name], "ist bereits vergeben"
  end

  test "Enddatum muss nach Startdatum liegen" do
    term = Term.new(name: "WS2031", start_date: Date.new(2031, 6, 1), end_date: Date.new(2031, 1, 1))
    assert_not term.valid?
    assert_includes term.errors[:end_date], "muss nach dem Startdatum liegen"
  end

  test "Kurse verlieren nur die Zuordnung, wenn der Term gelöscht wird" do
    term = terms(:one)
    course = courses(:one)
    course.update!(term: term)

    assert_difference("Course.count", 0) do
      term.destroy!
    end
    assert_nil course.reload.term_id
  end
end
