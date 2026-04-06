import { Application } from "@hotwired/stimulus"
import ColorSyncController from "controllers/color_sync_controller"
import FieldSorterController from "controllers/field_sorter_controller"

const application = Application.start()
application.register("color-sync", ColorSyncController)
application.register("field-sorter", FieldSorterController)
