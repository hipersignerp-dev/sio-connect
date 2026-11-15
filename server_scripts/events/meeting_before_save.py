# SIO Meeting, Before Save: attendance counts.
doc.total_count = len(doc.attendance)
doc.present_count = len([r for r in doc.attendance if r.status == "Present"])
