# 02 — a plain bug inside an UNANNOTATED function.
# raw has no annotation -> Unknown/Any -> the body is not checked by default.
# All four checkers report 0. Only mypy prints a note that it skipped.
# Confirm: annotate `raw: str -> int` and all four immediately flag n = raw.upper().
def parse(raw):
    n: int = raw.upper()     # .upper() is a str; assigning to int is wrong
    return n
