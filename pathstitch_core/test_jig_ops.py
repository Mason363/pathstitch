"""Tests for jig_ops: extrude flat panels to a binary STL with through-holes.

Run from repo root with the pathstitch env:
    PYTHONPATH=. python pathstitch_core/test_jig_ops.py
"""
import os
import struct
import tempfile

from pathstitch_core.jig_ops import op_extrude_to_stl, op_jig_from_panels


def _tmp_stl():
    f = tempfile.NamedTemporaryFile(suffix=".stl", delete=False); f.close()
    return f.name


def _binary_stl_tri_count(path):
    """Read the triangle count from a binary STL header and verify file size."""
    with open(path, "rb") as fh:
        head = fh.read(84)
        assert len(head) == 84, "STL too short for a binary header"
        count = struct.unpack("<I", head[80:84])[0]
        fh.seek(0, os.SEEK_END)
        size = fh.tell()
    expected = 84 + 50 * count
    assert size == expected, f"binary STL size {size} != {expected} (count {count})"
    return count


def test_extrude_square():
    out = _tmp_stl()
    panel = {"outer": [[0, 0], [50, 0], [50, 30], [0, 30]]}
    res = op_extrude_to_stl({"panels": [panel], "output": out, "thickness": 2.0})
    assert res["status"] == "ok", res
    count = _binary_stl_tri_count(out)
    assert count == res["data"]["triangle_count"], "header count != reported"
    # a box has 12 triangles (2 per face × 6 faces)
    assert count == 12, f"box should be 12 triangles, got {count}"
    assert res["data"]["vertices"] and res["data"]["triangles"], "no preview mesh"
    print(f"Extrude square OK: {count} triangles, valid binary STL")


def test_extrude_with_hole():
    out = _tmp_stl()
    panel = {
        "outer": [[0, 0], [40, 0], [40, 40], [0, 40]],
        "holes": [[[15, 15], [25, 15], [25, 25], [15, 25]]],
    }
    res = op_extrude_to_stl({"panels": [panel], "output": out, "thickness": 3.0})
    assert res["status"] == "ok", res
    count = _binary_stl_tri_count(out)
    # outer box + inner square hole through it → more than a plain box
    assert count > 12, f"hole did not add geometry (count {count})"
    print(f"Extrude with through-hole OK: {count} triangles")


def test_stitch_template_mode():
    out = _tmp_stl()
    panel = {
        "outer": [[0, 0], [60, 0], [60, 20], [0, 20]],
        "holes": [[[c, 10], [c + 1, 10], [c + 1, 11], [c, 11]] for c in range(5, 55, 6)],
    }
    res = op_jig_from_panels({"mode": "stitch_template", "panels": [panel],
                              "output": out, "plate_thickness": 3.0})
    assert res["status"] == "ok", res
    assert res["data"]["mode"] == "stitch_template"
    _binary_stl_tri_count(out)
    print(f"Stitch-template jig OK: {res['data']['triangle_count']} triangles")


def test_multi_panel_compound():
    out = _tmp_stl()
    panels = [
        {"outer": [[0, 0], [20, 0], [20, 20], [0, 20]]},
        {"outer": [[30, 0], [50, 0], [50, 20], [30, 20]]},
    ]
    res = op_extrude_to_stl({"panels": panels, "output": out, "thickness": 2.0})
    assert res["status"] == "ok", res
    assert res["data"]["panels"] == 2, "expected 2 panels in compound"
    print(f"Multi-panel compound OK: {res['data']['triangle_count']} triangles")


def test_errors():
    assert op_extrude_to_stl({"panels": [], "output": _tmp_stl()})["status"] == "error"
    assert op_extrude_to_stl({"panels": [{"outer": [[0, 0], [1, 0]]}],
                              "output": _tmp_stl()})["status"] == "error", \
        "degenerate panel (2 pts) should error"
    print("Error handling OK")


def run():
    test_extrude_square()
    test_extrude_with_hole()
    test_stitch_template_mode()
    test_multi_panel_compound()
    test_errors()
    print("\nALL JIG OPS TESTS PASSED")


if __name__ == "__main__":
    run()
