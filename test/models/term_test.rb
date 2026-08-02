require "test_helper"

class TermTest < ActiveSupport::TestCase
  test "valide mit Name, Art, Start- und Enddatum" do
    term = Term.new(name: "WS2030", kind: "semester", start_date: Date.new(2030, 8, 1), end_date: Date.new(2030, 12, 1))
    assert term.valid?, term.errors.full_messages.inspect
  end

  test "kind muss semester oder quartal sein" do
    term = Term.new(name: "WS2033", kind: "jahr", start_date: Date.new(2033, 8, 1), end_date: Date.new(2033, 12, 1))
    assert_not term.valid?
  end

  test "Name muss eindeutig sein" do
    term = Term.new(name: terms(:one).name, kind: "semester", start_date: Date.new(2030, 1, 1), end_date: Date.new(2030, 6, 1))
    assert_not term.valid?
    assert_includes term.errors[:name], "ist bereits vergeben"
  end

  test "Enddatum muss nach Startdatum liegen" do
    term = Term.new(name: "WS2031", kind: "semester", start_date: Date.new(2031, 6, 1), end_date: Date.new(2031, 1, 1))
    assert_not term.valid?
    assert_includes term.errors[:end_date], "muss nach dem Startdatum liegen"
  end

  test "next_term findet den chronologisch nächsten Term derselben Art" do
    assert_equal terms(:two), terms(:one).next_term
  end

  test "next_term ignoriert andere Art" do
    quartal = Term.create!(name: "Q1-2027", kind: "quartal", start_date: Date.new(2027, 1, 1), end_date: Date.new(2027, 3, 1))
    assert_not_equal quartal, terms(:one).next_term
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
