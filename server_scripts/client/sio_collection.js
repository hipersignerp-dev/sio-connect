// SIO Collection form: split the area target among units, and keep the unit targets total in view.
function sio_targets_total(frm) {
	let total = 0;
	(frm.doc.unit_targets || []).forEach((r) => (total += flt(r.target)));
	frm.set_value("unit_targets_total", total);
}

frappe.ui.form.on("SIO Collection", {
	refresh(frm) {
		frm.add_custom_button(__("Split target among units"), () => {
			const target = flt(frm.doc.target_amount);
			if (!target) {
				frappe.msgprint(__("Enter the Target first, then split it among the units."));
				return;
			}
			const filters = { active: 1 };
			if (frm.doc.unit) filters.name = frm.doc.unit;
			frappe.db.get_list("SIO Unit", { filters, fields: ["name"], limit: 500, order_by: "name asc" }).then((units) => {
				if (!units.length) return frappe.msgprint(__("Add the units first."));
				const share = Math.floor(target / units.length / 100) * 100;
				frm.clear_table("unit_targets");
				units.forEach((u, i) => {
					const row = frm.add_child("unit_targets");
					row.unit = u.name;
					row.target = i === units.length - 1 ? target - share * (units.length - 1) : share;
				});
				frm.refresh_field("unit_targets");
				sio_targets_total(frm);
				frappe.show_alert({ message: __("Split equally. Change any unit's target if needed."), indicator: "green" });
			});
		});
	},
});

frappe.ui.form.on("SIO Collection Unit Target", {
	target: sio_targets_total,
	unit_targets_remove: sio_targets_total,
});
