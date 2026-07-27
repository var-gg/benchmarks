# 05 — non-exhaustive match. Triangle is missing, so the assert_never branch
# is reachable -> all four flag 1 error.
# The PEP 695 `type Shape = ...` alias also makes pyright (no pinned version)
# warn "requires 3.12+".
from dataclasses import dataclass
from typing import assert_never


@dataclass
class Circle:
    r: float


@dataclass
class Square:
    s: float


@dataclass
class Triangle:
    b: float
    h: float


type Shape = Circle | Square | Triangle


def area(shape: Shape) -> float:
    match shape:
        case Circle(r):
            return 3.14159 * r * r
        case Square(s):
            return s * s
        case _ as unreachable:      # Triangle falls through here
            assert_never(unreachable)
