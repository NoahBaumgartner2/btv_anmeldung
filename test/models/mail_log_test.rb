require "test_helper"

class MailLogTest < ActiveSupport::TestCase
  setup do
    @course = courses(:one)
    @participant = participants(:parent_only_child)
    @session = TrainingSession.new(course: @course, start_time: 1.week.from_now, end_time: 1.week.from_now + 1.hour)
    @session.save!(validate: false)
  end

  test "versendete Mail wird mit Kurs, Training, Kind und eingeteilten Trainern festgehalten" do
    assert_difference "MailLog.count", 1 do
      send_cancellation
    end

    log = MailLog.order(:id).last
    assert_equal "training_session.cancellation_notice", log.kind
    assert_equal @course.id, log.course_id
    assert_equal @course.title, log.course_title
    assert_equal @session.id, log.training_session_id
    assert_equal "#{@participant.first_name} #{@participant.last_name}", log.participant_name
    assert_equal [ @participant.user.email ], log.recipients
    assert_equal "parent", log.audience
    assert_equal @course.trainer_ids.sort, log.trainer_ids.sort
  end

  test "sichtbar ist, wer beim Versand eingeteilt war, spätere Wechsel ändern das nicht" do
    assigned = trainers(:one)
    later = trainers(:two)
    assert_includes @course.trainers, assigned
    assert_not_includes @course.trainers, later
    send_cancellation
    log = MailLog.order(:id).last

    @course.course_trainers.where(trainer: assigned).destroy_all
    CourseTrainer.create!(course: @course, trainer: later)

    assert_includes MailLog.visible_to(assigned.user), log
    assert_not_includes MailLog.visible_to(later.user), log
  end

  test "Ersatztrainer:in sieht die Mail des Trainings" do
    @session.update_columns(substitute_trainer_id: trainers(:two).id)
    send_cancellation

    assert_includes MailLog.visible_to(trainers(:two).user), MailLog.order(:id).last
  end

  test "Trainer:innen sehen keine Zahlungs-, internen oder unbekannten Mailarten, Admins alle" do
    trainer = trainers(:one)
    %w[payment_reminder.reminder course_registration.payment_receipt
       course_registration.admin_refund_done_notice training_session.training_cancelled_admin_notice
       newsletter.campaign something_new.action].each do |kind|
      log = MailLog.create!(kind: kind, trainer_ids: [ trainer.id ])
      assert_not_includes MailLog.visible_to(trainer.user), log, kind
      assert_includes MailLog.visible_to(users(:admin)), log
    end
  end

  test "Eltern sehen nichts" do
    log = MailLog.create!(kind: "training_session.cancellation_notice", trainer_ids: [ trainers(:one).id ])
    assert_not_includes MailLog.visible_to(users(:parent_only)), log
  end

  test "abgeschaltete Mail wird nicht festgehalten" do
    replacing(MailSetting, :mail_enabled?, ->(*) { false }) do
      assert_no_difference "MailLog.count" do
        CourseTrainerMailer.assigned_to_course(trainers(:one), @course).deliver_now
      end
    end
  end

  test "Fehler beim Festhalten verhindert den Versand nicht und wirft nichts" do
    replacing(MailLog, :record, ->(**) { raise "kaputt" }) do
      assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
        send_cancellation
      end
    end
  end

  test "Mail an mehrere Admins und ohne Kurs wird festgehalten" do
    TestMailer.test_email("jemand@example.com").deliver_now

    log = MailLog.order(:id).last
    assert_equal "test.test_email", log.kind
    assert_nil log.course_id
    assert_equal "other", log.audience
    assert_empty log.trainer_ids
  end

  test "Einträge verschwinden, wenn Kind oder Konto gelöscht werden" do
    by_child = MailLog.create!(kind: "x.y", participant_id: @participant.id)
    @participant.course_registrations.destroy_all
    @participant.destroy!
    assert_not MailLog.exists?(by_child.id)

    user = users(:parent_only)
    by_address = MailLog.create!(kind: "x.y", recipients: [ user.email ])
    user.participants.destroy_all
    user.destroy!
    assert_not MailLog.exists?(by_address.id)
  end

  test "jede Mailart hat in jeder Sprache eine Bezeichnung, und die Trainerliste ist gültig" do
    Rails.application.eager_load!
    kinds = ApplicationMailer.descendants.flat_map do |mailer|
      mailer.action_methods.map { |action| "#{mailer.mailer_name.delete_suffix('_mailer')}.#{action}" }
    end
    assert_operator kinds.size, :>, 30
    assert_empty MailLog::TRAINER_VISIBLE_KINDS - kinds

    %i[de en fr].each do |locale|
      missing = kinds.reject { |kind| I18n.exists?("mail_logs.kinds.#{kind}", locale) }
      assert_empty missing, locale
    end
  end

  private

  def replacing(klass, name, implementation)
    original = klass.method(name)
    klass.define_singleton_method(name, implementation)
    yield
  ensure
    klass.define_singleton_method(name, original)
  end

  def send_cancellation
    TrainingSessionMailer.cancellation_notice(@session, @participant.user, participant: @participant).deliver_now
  end
end
