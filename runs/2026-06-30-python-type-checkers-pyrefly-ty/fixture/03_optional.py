# 03 — two None-member accesses. Flow narrowing should catch both.
from typing import Optional


def maybe_name() -> Optional[str]:
    return None


s = maybe_name()
print(s.upper())             # (1) s may be None


class Box:
    val: Optional[int] = None


b = Box()
print(b.val + 1)             # (2) val may be None
