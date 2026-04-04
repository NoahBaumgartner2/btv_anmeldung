import { Application } from "@hotwired/stimulus"
import ColorSyncController from "controllers/color_sync_controller"

const application = Application.start()
application.register("color-sync", ColorSyncController)
