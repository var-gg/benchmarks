# 01 — three obvious mismatches every checker should catch.
x: int = "not an int"        # (1) str assigned to int


def f() -> int:
    return "nope"            # (2) str returned where int declared


y: str = 42                  # (3) int assigned to str
