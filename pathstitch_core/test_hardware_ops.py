"""Tests for op_place_hardware (Phase 2 — hardware footprints).

Run from repo root with the pathstitch env:
    PYTHONPATH=. python pathstitch_core/test_hardware_ops.py
"""
import math
import tempfile
import ezdxf

from pathstitch_core.dxf_ops import op_place_hardware


def _tmp():
    f = tempfile.NamedTemporaryFile(suffix=".dxf", delete=False); f.close()
    return f.name


def _blank():
    p = _tmp(); ezdxf.new(dxfversion="R2010").saveas(p); return p


def _circles(path, layer="HARDWARE"):
    d = ezdxf.readfile(path)
    return [e for e in d.modelspace()
            if e.dxftype() == "CIRCLE" and e.dxf.layer == layer]


def test_two_hole_snap_offsets():
    """A 2-hole footprint lands its holes at center ± the local offsets."""
    out = _tmp()
    res = op_place_hardware({
        "input": _blank(), "output": out,
        "footprint": [{"kind": "hole", "dx": -6.5, "dy": 0, "dia": 4.0},
                      {"kind": "hole", "dx": 6.5, "dy": 0, "dia": 4.0}],
        "center": [10.0, 20.0], "rotation": 0.0,
    })
    assert res["status"] == "ok", res
    assert res["data"]["count"] == 2
    cs = sorted(_circles(out), key=lambda e: e.dxf.center.x)
    assert len(cs) == 2, cs
    assert all(abs(e.dxf.radius - 2.0) < 1e-9 for e in cs), "hole dia 4 → radius 2"
    assert abs(cs[0].dxf.center.x - 3.5) < 1e-9 and abs(cs[0].dxf.center.y - 20.0) < 1e-9
    assert abs(cs[1].dxf.center.x - 16.5) < 1e-9 and abs(cs[1].dxf.center.y - 20.0) < 1e-9
    print("two-hole snap: holes at (3.5,20) and (16.5,20), r=2 ✓")


def test_rotation_applies_to_offsets():
    """Rotating the part rotates the whole footprint about the center."""
    out = _tmp()
    op_place_hardware({
        "input": _blank(), "output": out,
        "footprint": [{"kind": "hole", "dx": -6.5, "dy": 0, "dia": 4.0},
                      {"kind": "hole", "dx": 6.5, "dy": 0, "dia": 4.0}],
        "center": [10.0, 20.0], "rotation": 90.0,
    })
    # (±6.5, 0) rotated 90° → (0, ±6.5) → center + offset = (10, 13.5) and (10, 26.5)
    cs = sorted(_circles(out), key=lambda e: e.dxf.center.y)
    assert abs(cs[0].dxf.center.x - 10.0) < 1e-6 and abs(cs[0].dxf.center.y - 13.5) < 1e-6, cs[0].dxf.center
    assert abs(cs[1].dxf.center.x - 10.0) < 1e-6 and abs(cs[1].dxf.center.y - 26.5) < 1e-6, cs[1].dxf.center
    print("rotation 90°: holes swing to (10,13.5) and (10,26.5) ✓")


def test_slot_footprint_bbox():
    """A slot stamps a closed stadium polyline of the right span; angle rotates it."""
    out = _tmp()
    res = op_place_hardware({
        "input": _blank(), "output": out,
        "footprint": [{"kind": "slot", "dx": 0, "dy": 0,
                       "length": 5.0, "width": 1.2, "angle": 90.0}],
        "center": [0.0, 0.0], "rotation": 0.0,
    })
    assert res["status"] == "ok", res
    d = ezdxf.readfile(out)
    polys = [e for e in d.modelspace()
             if e.dxftype() == "LWPOLYLINE" and e.dxf.layer == "HARDWARE"]
    assert len(polys) == 1, f"expected one slot polyline, got {len(polys)}"
    assert polys[0].closed, "slot should be a closed loop"
    pts = [(p[0], p[1]) for p in polys[0]]
    w = max(x for x, _ in pts) - min(x for x, _ in pts)
    h = max(y for _, y in pts) - min(y for _, y in pts)
    # angle 90° → long axis (5.0) runs along Y, short (1.2) along X
    assert abs(h - 5.0) < 1e-6 and abs(w - 1.2) < 1e-6, f"slot bbox {w:.3f} x {h:.3f}"
    print(f"slot: closed stadium, bbox {w:.2f} x {h:.2f} (rotated 90°) ✓")


def test_unknown_primitive_errors():
    res = op_place_hardware({
        "input": _blank(), "output": _tmp(),
        "footprint": [{"kind": "triangle", "dx": 0, "dy": 0}],
    })
    assert res["status"] == "error" and "triangle" in res["message"], res
    print("unknown primitive rejected ✓")


if __name__ == "__main__":
    test_two_hole_snap_offsets()
    test_rotation_applies_to_offsets()
    test_slot_footprint_bbox()
    test_unknown_primitive_errors()
    print("\nALL HARDWARE OPS TESTS PASSED")
