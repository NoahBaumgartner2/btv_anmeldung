import { Application } from "@hotwired/stimulus"
import ColorSyncController from "controllers/color_sync_controller"
import FieldSorterController from "controllers/field_sorter_controller"
import ConfirmUnsubscribeController from "controllers/confirm_unsubscribe_controller"
import ExportTypeController from "controllers/export_type_controller"
import CancelTrainingController from "controllers/cancel_training_controller"
import DeleteAccountController from "controllers/delete_account_controller"
import ModalController from "controllers/modal_controller"
import MobileMenuController from "controllers/mobile_menu_controller"
import DatepickerController from "controllers/datepicker_controller"
import CookieConsentController from "controllers/cookie_consent_controller"
import RegistrationModeController from "controllers/registration_mode_controller"

const application = Application.start()
application.register("color-sync", ColorSyncController)
application.register("field-sorter", FieldSorterController)
application.register("confirm-unsubscribe", ConfirmUnsubscribeController)
application.register("export-type", ExportTypeController)
application.register("cancel-training", CancelTrainingController)
application.register("delete-account", DeleteAccountController)
application.register("modal", ModalController)
application.register("mobile-menu", MobileMenuController)
application.register("datepicker", DatepickerController)
application.register("cookie-consent", CookieConsentController)
application.register("registration-mode", RegistrationModeController)
