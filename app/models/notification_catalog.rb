# Zentrales Verzeichnis aller automatischen E-Mail-Benachrichtigungen des Systems.
# Treibt die Benachrichtigungszentrale (Admin::NotificationsController) an: Liste,
# Ein-/Ausschalten (via MailSetting#notification_enabled?) und Vorschau.
#
# toggleable: false → wird nur zur Info angezeigt, kann nicht deaktiviert werden
# (Konto-Sicherheitsmails von Devise, sowie individuell verfasste Trainer-Nachrichten,
# deren Ausbleiben ohne Wissen des Trainers überraschend/unerwünscht wäre).
#
# scope: :global (Standard) → EIN Schalter für alle, betrifft ausnahmslos jeden
#   Empfänger. scope: :global_and_personal → zusätzlich zum globalen Schalter kann
#   jede Person (Trainer:in) die Mail für sich selbst abschalten (User#admin_notification_
#   preferences, "Meine Benachrichtigungen"). WICHTIG: der globale Schalter gewinnt immer
#   zuerst – ist er aus, bekommt NIEMAND die Mail mehr, unabhängig von der persönlichen
#   Einstellung. Die persönliche Einstellung wirkt nur als zusätzlicher Filter, wenn der
#   globale Schalter an ist.
#
# preview_method: Methode auf NotificationPreviewBuilder, die mit erfundenen
# Beispieldaten (kein Zugriff auf echte Datensätze) das jeweilige Mail::Message-Objekt
# baut, ohne es zu versenden.
class NotificationCatalog
  Entry = Struct.new(:key, :category, :toggleable, :preview_method, :scope, keyword_init: true) do
    def name        = I18n.t("mail_settings.catalog.#{key}.name")
    def description = I18n.t("mail_settings.catalog.#{key}.description")
    def recipient    = I18n.t("mail_settings.catalog.#{key}.recipient")
    def global_and_personal? = scope == :global_and_personal
  end

  def self.entry(key:, category:, toggleable:, preview_method:, scope: :global)
    Entry.new(key: key, category: category, toggleable: toggleable, preview_method: preview_method, scope: scope)
  end

  CATALOG = [
    # ── Anmeldung & Kursplatz ──────────────────────────────────────────────
    entry(key: "registration_confirmation", category: "registration", toggleable: true, preview_method: :registration_confirmation),
    entry(key: "waitlist_promoted",         category: "registration", toggleable: true, preview_method: :waitlist_promoted),
    entry(key: "course_access_invited",     category: "registration", toggleable: true, preview_method: :course_access_invited),
    entry(key: "abo_imported",              category: "registration", toggleable: true, preview_method: :abo_imported),
    entry(key: "abo_exhausted",             category: "registration", toggleable: true, preview_method: :abo_exhausted),
    entry(key: "renewal_available",         category: "registration", toggleable: true, preview_method: :renewal_available),

    # ── Abmeldung & Stornierung ────────────────────────────────────────────
    # Hinweis: admin_cancel_notice existiert im Mailer, wird aber aktuell von
    # keinem Code-Pfad ausgelöst (toter Code) – deshalb bewusst NICHT hier gelistet,
    # ein nicht-funktionierender Schalter wäre irreführend.
    entry(key: "self_cancelled",         category: "cancellation", toggleable: true, preview_method: :self_cancelled),
    entry(key: "cancelled_by_trainer",   category: "cancellation", toggleable: true, preview_method: :cancelled_by_trainer),
    entry(key: "trainer_cancel_notice",  category: "cancellation", toggleable: true, preview_method: :trainer_cancel_notice, scope: :global_and_personal),
    entry(key: "session_unsubscription", category: "cancellation", toggleable: true, preview_method: :session_unsubscription, scope: :global_and_personal),
    entry(key: "unsubscribe_reminder",   category: "cancellation", toggleable: true, preview_method: :unsubscribe_reminder),
    entry(key: "training_cancelled",     category: "cancellation", toggleable: true, preview_method: :training_cancelled),
    entry(key: "training_cancelled_admin", category: "cancellation", toggleable: true, preview_method: :training_cancelled_admin, scope: :global_and_personal),

    # ── Zahlung ────────────────────────────────────────────────────────────
    entry(key: "payment_expired",          category: "payment", toggleable: true, preview_method: :payment_expired),
    entry(key: "trial_expired",            category: "payment", toggleable: true, preview_method: :trial_expired),
    entry(key: "payment_receipt",          category: "payment", toggleable: true, preview_method: :payment_receipt),
    entry(key: "payment_reminder",         category: "payment", toggleable: true, preview_method: :payment_reminder),
    entry(key: "refund_failed_notice",     category: "payment", toggleable: true, preview_method: :refund_failed_notice),
    entry(key: "admin_refund_done_notice", category: "payment", toggleable: true, preview_method: :admin_refund_done_notice),

    # ── Trainer & Anwesenheit ──────────────────────────────────────────────
    entry(key: "trainer_assigned",            category: "trainer", toggleable: true,  preview_method: :trainer_assigned),
    entry(key: "trainer_invitation",          category: "trainer", toggleable: true,  preview_method: :trainer_invitation),
    entry(key: "attendance_reminder_trainer", category: "trainer", toggleable: true,  preview_method: :attendance_reminder_trainer),
    entry(key: "attendance_reminder_admin",   category: "trainer", toggleable: true,  preview_method: :attendance_reminder_admin),
    entry(key: "custom_trainer_message",      category: "trainer", toggleable: false, preview_method: :custom_trainer_message),

    # ── Sonstiges ──────────────────────────────────────────────────────────
    entry(key: "participant_complete_profile", category: "other", toggleable: true, preview_method: :participant_complete_profile),
    entry(key: "course_rollover_ready",        category: "other", toggleable: true, preview_method: :course_rollover_ready),

    # ── Konto (immer aktiv, Devise) ────────────────────────────────────────
    entry(key: "devise_confirmation",     category: "account", toggleable: false, preview_method: nil),
    entry(key: "devise_password_reset",   category: "account", toggleable: false, preview_method: nil)
  ].freeze

  CATEGORIES = %w[registration cancellation payment trainer other account].freeze

  def self.all = CATALOG
  def self.find(key) = CATALOG.find { |e| e.key == key.to_s }
  def self.by_category = CATEGORIES.filter_map { |cat| entries = CATALOG.select { |e| e.category == cat }; [ cat, entries ] if entries.any? }
end
