import { Application } from "@hotwired/stimulus"
import ColorSyncController from "controllers/color_sync_controller"
import FieldSorterController from "controllers/field_sorter_controller"
import ConfirmUnsubscribeController from "controllers/confirm_unsubscribe_controller"
import ExportTypeController from "controllers/export_type_controller"
import CancelTrainingController from "controllers/cancel_training_controller"
import DeleteAccountController from "controllers/delete_account_controller"

const application = Application.start()
application.register("color-sync", ColorSyncController)
application.register("field-sorter", FieldSorterController)
application.register("confirm-unsubscribe", ConfirmUnsubscribeController)
application.register("export-type", ExportTypeController)
application.register("cancel-training", CancelTrainingController)
application.register("delete-account", DeleteAccountController)
