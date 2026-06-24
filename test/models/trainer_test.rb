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
end
