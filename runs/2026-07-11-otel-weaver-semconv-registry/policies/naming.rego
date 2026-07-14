package after_resolution

import rego.v1

# Enforce snake_case attribute names.
#
# The built-in registry check validates schema + resolution (types, required
# brief, references) but does NOT enforce naming style — so `commerce.order.totalAmount`
# passes the built-in check silently. Layering this policy makes naming a
# contract the check enforces.
deny contains attr_registry_violation("attr_name_not_snake_case", group.id, attr.name) if {
	group := input.groups[_]
	attr := group.attributes[_]
	regex.match(`[A-Z]`, attr.name)
}

# Build an attribute registry violation (weaver's expected finding shape).
attr_registry_violation(violation_id, group_id, attr_id) := violation if {
	violation := {
		"id": violation_id,
		"type": "semconv_attribute",
		"category": "attribute_registry",
		"group": group_id,
		"attr": attr_id,
	}
}
