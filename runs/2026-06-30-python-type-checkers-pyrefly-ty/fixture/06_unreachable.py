# 06 — dead code + a missing return path.
# pyrefly flags the missing return (1); mypy/pyright/ty are silent at default.
def after_return(x: int) -> int:
    return x
    print("dead")               # unreachable


def missing_return(x: int) -> int:
    if x > 0:
        return 1
    # no return on the else path
