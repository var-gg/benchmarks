# 04 — inference precision + the "reveal_type not imported" pedantry.
# mypy 2.1 widens to tuple[int, str]; pyright + Rust tools keep
# tuple[Literal[1], Literal['two']].
# reveal_type is used WITHOUT importing it: pyrefly/ty emit a runtime-failure
# diagnostic; mypy/pyright treat it as a special form and stay silent.
reveal_type((1, "two"))
