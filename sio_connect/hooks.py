app_name = "sio_connect"
app_title = "SIO Connect"
app_publisher = "Hipersign"
app_description = "SIO Connect: student organisation app (members, programmes, photos, daily ayah) for Hipersign ERP"
app_email = "hipersignerp@gmail.com"
app_license = "mit"
app_logo_url = "/assets/sio_connect/images/sio-logo.png"

# The SIO DocTypes live on the site (custom DocTypes); this app carries the code. Everything the site ran as
# Server Scripts is in sio_connect/scripts and runs from here once SIO Settings > use_app_code is ticked
# (see runtime.py). Generated hooks come from tools/make_app.py.
from sio_connect.hooks_generated import doc_events as _generated_doc_events
from sio_connect.hooks_generated import permission_query_conditions
from sio_connect.hooks_generated import scheduler_events

doc_events = {k: dict(v) for k, v in _generated_doc_events.items()}

# Push notifications: every SIO Notice is pushed to the phones it reaches (always on: Server Scripts cannot push)
doc_events.setdefault("SIO Notice", {}).setdefault("after_insert", [])
doc_events["SIO Notice"]["after_insert"] = list(doc_events["SIO Notice"]["after_insert"]) + [
	"sio_connect.push.on_notice"
]

del _generated_doc_events
