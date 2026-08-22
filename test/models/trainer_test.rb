require "test_helper"

class TrainerTest < ActiveSupport::TestCase
  test "Eltern-Account mit angemeldeten Kindern kann nicht als Trainer erfasst werden" do
    # parent_only besitzt ein Kind (parent_only_child) und ist kein Trainer
    trainer = Trainer.new(user: users(:parent_only))

    assert_not trainer.save
    assert trainer.errors[:base].any? { |m| m.include?("Eltern-Account") },
           "Erwartete Eltern-Account-Fehlermeldung, erhielt: #{trainer.errors.full_messages.to_sentence}"
  end

  test "Account ohne Kinder kann als Trainer erfasst werden" do
    trainer = Trainer.new(user: users(:admin))

    assert trainer.save, trainer.errors.full_messages.to_sentence
  end

  test "bestehender Trainer bleibt editierbar (Validierung nur on: :create)" do
    # trainers(:one) hängt am User one, der zugleich Kinder hat (Altbestand) –
    # Updates müssen trotzdem funktionieren.
    trainer = trainers(:one)
    trainer.phone = "+41791234567"

    assert trainer.save, trainer.errors.full_messages.to_sentence
  end

  # ── sync_self_participant! ───────────────────────────────────────────────────

  def build_fresh_trainer(attrs = {})
    user = User.create!(
      email: attrs.delete(:email) || "trainer-#{SecureRandom.hex(4)}@example.com",
      password: "password123", confirmed_at: Time.current, privacy_accepted: true
    )
    Trainer.create!(
      user: user, first_name: "Test", last_name: "Trainer",
      phone: "+41 79 111 22 33", date_of_birth: Date.new(1990, 1, 1), gender: "weiblich",
      ahv_number: "756.9999.8888.77", street: "Weg", house_number: "1",
      zip_code: "3000", city: "Bern", country: "CH", nationality: "CH", mother_tongue: "DE",
      **attrs
    )
  end

  test "sync_self_participant! legt einen Teilnehmer-Datensatz mit den Trainer-Daten an" do
    trainer = build_fresh_trainer

    participant = trainer.sync_self_participant!

    assert participant.persisted?
    assert participant.is_trainer_self?
    assert_equal trainer.user_id, participant.user_id
    assert_equal trainer.first_name, participant.first_name
    assert_equal trainer.date_of_birth, participant.date_of_birth
    assert_equal participant.id, trainer.reload.self_participant_id
  end

  test "sync_self_participant! aktualisiert denselben Datensatz statt einen neuen anzulegen" do
    trainer = build_fresh_trainer
    first = trainer.sync_self_participant!

    trainer.update!(first_name: "Geändert")
    second = trainer.sync_self_participant!

    assert_equal first.id, second.id
    assert_equal "Geändert", second.reload.first_name
  end
end
