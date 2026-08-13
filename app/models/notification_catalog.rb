# Zentrales Verzeichnis aller automatischen E-Mail-Benachrichtigungen des Systems.
# Treibt die Benachrichtigungszentrale (Admin::NotificationsController) an: Liste,
# Ein-/Ausschalten (via MailSetting#notification_enabled?) und Vorschau.
#
# toggleable: false → wird nur zur Info angezeigt, kann nicht deaktiviert werden
# (Konto-Sicherheitsmails von Devise, sowie individuell verfasste Trainer-Nachrichten,
# deren Ausbleiben ohne Wissen des Trainers überraschend/unerwünscht wäre).
#
# preview_method: Methode auf NotificationPreviewBuilder, die mit erfundenen
# Beispieldaten (kein Zugriff auf echte Datensätze) das jeweilige Mail::Message-Objekt
# baut, ohne es zu versenden.
class NotificationCatalog
  Entry = Struct.new(:key, :category, :toggleable, :preview_method, keyword_init: true) do
    def name        = I18n.t("mail_settings.catalog.#{key}.name")
    def description = I18n.t("mail_settings.catalog.#{key}.description")
    def recipient    = I18n.t("mail_settings.catalog.#{key}.recipient")
  end

  CATALOG = [
    # ── Anmeldung & Kursplatz ──────────────────────────────────────────────
    Entry.new(key: "registration_confirmation", category: "registration", toggleable: true,  preview_method: :registration_confirmation),
    Entry.new(key: "waitlist_promoted",          category: "registration", toggleable: true,  preview_method: :waitlist_promoted),
    Entry.new(key: "course_access_invited",      category: "registration", toggleable: true,  preview_method: :course_access_invited),
    Entry.new(key: "abo_imported",               category: "registration", toggleable: true,  preview_method: :abo_imported),
    Entry.new(key: "abo_exhausted",               category: "registration", toggleable: true,  preview_method: :abo_exhausted),
    Entry.new(key: "renewal_available",          category: "registration", toggleable: true,  preview_method: :renewal_available),

    # ── Abmeldung & Stornierung ────────────────────────────────────────────
    Entry.new(key: "self_cancelled",             category: "cancellation", toggleable: true,  preview_method: :self_cancelled),
    Entry.new(key: "cancelled_by_trainer",       category: "cancellation", toggleable: true,  preview_method: :cancelled_by_trainer),
    Entry.new(key: "admin_cancel_notice",        category: "cancellation", toggleable: true,  preview_method: :admin_cancel_notice),
    Entry.new(key: "trainer_cancel_notice",      category: "cancellation", toggleable: true,  preview_method: :trainer_cancel_notice),
    Entry.new(key: "session_unsubscription",     category: "cancellation", toggleable: true,  preview_method: :session_unsubscription),
    Entry.new(key: "unsubscribe_reminder",       category: "cancellation", toggleable: true,  preview_method: :unsubscribe_reminder),
    Entry.new(key: "training_cancelled",         category: "cancellation", toggleable: true,  preview_method: :training_cancelled),
    Entry.new(key: "training_cancelled_admin",   category: "cancellation", toggleable: true,  preview_method: :training_cancelled_admin),

    # ── Zahlung ────────────────────────────────────────────────────────────
    Entry.new(key: "payment_expired",            category: "payment", toggleable: true,  preview_method: :payment_expired),
    Entry.new(key: "trial_expired",              category: "payment", toggleable: true,  preview_method: :trial_expired),
    Entry.new(key: "payment_receipt",            category: "payment", toggleable: true,  preview_method: :payment_receipt),
    Entry.new(key: "payment_reminder",           category: "payment", toggleable: true,  preview_method: :payment_reminder),
    Entry.new(key: "refund_failed_notice",       category: "payment", toggleable: true,  preview_method: :refund_failed_notice),
    Entry.new(key: "admin_refund_done_notice",   category: "payment", toggleable: true,  preview_method: :admin_refund_done_notice),

    # ── Trainer & Anwesenheit ──────────────────────────────────────────────
    Entry.new(key: "trainer_assigned",           category: "trainer", toggleable: true,  preview_method: :trainer_assigned),
    Entry.new(key: "trainer_invitation",         category: "trainer", toggleable: true,  preview_method: :trainer_invitation),
    Entry.new(key: "attendance_reminder_trainer", category: "trainer", toggleable: true,  preview_method: :attendance_reminder_trainer),
    Entry.new(key: "attendance_reminder_admin",  category: "trainer", toggleable: true,  preview_method: :attendance_reminder_admin),
    Entry.new(key: "custom_trainer_message",     category: "trainer", toggleable: false, preview_method: :custom_trainer_message),

    # ── Sonstiges ──────────────────────────────────────────────────────────
    Entry.new(key: "participant_complete_profile", category: "other", toggleable: true,  preview_method: :participant_complete_profile),
    Entry.new(key: "course_rollover_ready",      category: "other", toggleable: true,  preview_method: :course_rollover_ready),

    # ── Konto (immer aktiv, Devise) ────────────────────────────────────────
    Entry.new(key: "devise_confirmation",        category: "account", toggleable: false, preview_method: nil),
    Entry.new(key: "devise_password_reset",      category: "account", toggleable: false, preview_method: nil)
  ].freeze

  CATEGORIES = %w[registration cancellation payment trainer other account].freeze

  def self.all = CATALOG
  def self.find(key) = CATALOG.find { |e| e.key == key.to_s }
  def self.by_category = CATEGORIES.filter_map { |cat| entries = CATALOG.select { |e| e.category == cat }; [ cat, entries ] if entries.any? }
end
