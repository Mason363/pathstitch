"""Tests for explode-compound (MAS-145). Run from repo root with the
pathstitch conda env:  python pathstitch_core/test_explode.py"""
import tempfile
import ezdxf
from shapely.geometry import Polygon

from pathstitch_core.dxf_ops import op_explode_compound, op_boolean


def _save(doc):
    f = tempfile.NamedTemporaryFile(suffix=".dxf", delete=False); f.close()
    doc.saveas(f.name)
    return f.name


def _closed_loops(path):
    doc = ezdxf.readfile(path)
    loops = []
    for e in doc.modelspace():
        if e.dxftype() == "LWPOLYLINE" and (e.closed or getattr(e, "is_closed", False)):
            loops.append([(p[0], p[1]) for p in e.get_points()])
    return loops


def run():
    out = tempfile.NamedTemporaryFile(suffix=".dxf", delete=False); out.close()

    # --- Figure-eight / bowtie: one closed self-intersecting polyline -> 2 loops ---
    doc = ezdxf.new(dxfversion="R2010"); m = doc.modelspace()
    bow = m.add_lwpolyline([(0, 0), (2, 2), (2, 0), (0, 2)], dxfattribs={"closed": True})
    path = _save(doc)
    res = op_explode_compound({"input": path, "output": out.name, "handles": [bow.dxf.handle]})
    assert res["status"] == "ok", res
    loops = _closed_loops(out.name)
    assert len(loops) == 2, f"bowtie should explode into 2 loops, got {len(loops)}"
    print("Bowtie explode OK: %d loops" % len(loops))

    # --- Shape with hole, as a self-touching single ring (keyhole) -> 2 loops ---
    # Outer square CCW, pinch to an inner square traced CW (a hole).
    ring = [
        (0, 0), (10, 0), (10, 10), (0, 10), (0, 0),
        (3, 3), (3, 7), (7, 7), (7, 3), (3, 3),
    ]
    doc = ezdxf.new(dxfversion="R2010"); m = doc.modelspace()
    key = m.add_lwpolyline(ring, dxfattribs={"closed": True})
    path = _save(doc)
    res = op_explode_compound({"input": path, "output": out.name, "handles": [key.dxf.handle]})
    assert res["status"] == "ok", res
    loops = _closed_loops(out.name)
    assert len(loops) >= 2, f"keyhole should explode into >=2 loops, got {len(loops)}"
    areas = sorted(Polygon(l).area for l in loops)
    # Largest loop ~100 (outer), a smaller loop ~16 (the hole boundary).
    assert abs(areas[-1] - 100.0) < 1.0, f"outer loop area ~100 expected, got {areas[-1]}"
    print("Keyhole explode OK: %d loops, areas=%s" % (len(loops), [round(a, 1) for a in areas]))

    # --- Simple square: nothing to explode ---
    doc = ezdxf.new(dxfversion="R2010"); m = doc.modelspace()
    sq = m.add_lwpolyline([(0, 0), (5, 0), (5, 5), (0, 5)], dxfattribs={"closed": True})
    path = _save(doc)
    res = op_explode_compound({"input": path, "output": out.name, "handles": [sq.dxf.handle]})
    assert res["status"] == "error" and "nothing to explode" in res["message"].lower(), res
    print("Simple-square no-op OK")

    # --- Open polyline: kept, nothing exploded -> error ---
    doc = ezdxf.new(dxfversion="R2010"); m = doc.modelspace()
    op = m.add_lwpolyline([(0, 0), (5, 0), (5, 5)], dxfattribs={"closed": False})
    path = _save(doc)
    res = op_explode_compound({"input": path, "output": out.name, "handles": [op.dxf.handle]})
    assert res["status"] == "error", res
    print("Open-polyline no-op OK")

    # --- Round-trip with a real compound produced via... not possible (union emits
    #     separate loops), so the bowtie above is the canonical compound case. ---

    print("\nALL EXPLODE TESTS PASSED")


if __name__ == "__main__":
    run()
