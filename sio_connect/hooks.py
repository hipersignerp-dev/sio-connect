app_name = "sio_connect"
app_title = "SIO Connect"
app_publisher = "Hipersign"
app_description = "Student organisation management for Hipersign ERP, with the SIO phone app"
app_email = "hipersignerp@gmail.com"
app_license = "mit"
app_logo_url = "/assets/sio_connect/images/sio-logo.png"

add_to_apps_screen = [
	{
		"name": "sio_connect",
		"logo": "/assets/sio_connect/images/sio-logo.png",
		"title": "SIO Connect",
		"route": "/app/sio-connect",
	}
]

# Creates the SIO roles and the workspace
after_install = "sio_connect.install.after_install"
after_migrate = "sio_connect.install.after_migrate"

# Keep event totals in step with registrations and expense approvals
doc_events = {
	"SIO Event Registration": {
		"on_update": "sio_connect.utils.refresh_event_totals",
		"on_trash": "sio_connect.utils.refresh_event_totals",
	},
	"SIO Expense Claim": {
		"on_update": "sio_connect.utils.refresh_event_totals",
		"on_trash": "sio_connect.utils.refresh_event_totals",
	},
}
