"""
test_unfold_full.py

End-to-end coverage for the full 3D→2D unfolding roadmap (unfold.md):

  Phase 2 — curved flattening:  LSCM + equal-area/equidistant/balanced modes,
            distortion heatmap (op_face_distortion), hemisphere split, and
            LSCM patches integrated into the connected-net rollout.
  Phase 3 — seam control:       forced seams (manual cuts), forbidden seams
            (hybrid forced folds), curvature-weighted spanning placement.
  Phase 4 — globe UX / overrides: anchor selection, per-seam decoration
            overrides, OBJ/STL mesh import flowing into the flattener.

Generates its own STEP geometry with OCC primitives, so it needs no fixtures.
Run:  python -m pathstitch_core.test_unfold_full
"""

import math
import os
import tempfile
import unittest

import ezdxf

from OCC.Core.BRepPrimAPI import (
    BRepPrimAPI_MakeBox, BRepPrimAPI_MakeCylinder,
    BRepPrimAPI_MakeCone, BRepPrimAPI_MakeSphere,
)
from OCC.Core.BRepAlgoAPI import BRepAlgoAPI_Fuse
from OCC.Core.STEPControl import STEPControl_Writer, STEPControl_AsIs
from OCC.Core.gp import gp_Pnt, gp_Ax2, gp_Dir

from pathstitch_core.step_ops import (
    load_step_shape, get_solid_bodies, op_unfold_face, op_unfold_connected,
    op_face_distortion,
)
from pathstitch_core import net_unfold
from pathstitch_core.surface_unfold import (
    triangulate_face, parameterize_mesh, split_closed_mesh, boundary_loops,
    lscm_flatten,
)


def _write_step(shapes, path):
    writer = STEPControl_Writer()
    for s in shapes:
        writer.Transfer(s, STEPControl_AsIs)
    writer.Write(path)


def _finite_polylines(wires):
    """True when every point in every polyline is finite and the result is
    non-degenerate (has area-bearing extent)."""
    if not wires:
        return False
    xs, ys = [], []
    for w in wires:
        if len(w) < 2:
            return False
        for (x, y) in w:
            if not (math.isfinite(x) and math.isfinite(y)):
                return False
            xs.append(x)
            ys.append(y)
    return (max(xs) - min(xs)) > 1e-6 and (max(ys) - min(ys)) > 1e-6


def _dxf_layer_counts(path):
    doc = ezdxf.readfile(path)
    msp = doc.modelspace()
    counts = {}
    for e in msp:
        layer = e.dxf.layer
        counts[layer] = counts.get(layer, 0) + 1
    return counts


class TestPhase2Curved(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = self.tmp.name
        self.sphere = os.path.join(self.d, "sphere.step")
        _write_step([BRepPrimAPI_MakeSphere(20.0).Shape()], self.sphere)

    def tearDown(self):
        self.tmp.cleanup()

    def _sphere_face_index(self):
        bodies = get_solid_bodies(load_step_shape(self.sphere))
        from OCC.Core.TopExp import TopExp_Explorer
        from OCC.Core.TopAbs import TopAbs_FACE
        exp = TopExp_Explorer(bodies[0], TopAbs_FACE)
        # First "Other"-typed face is the spherical surface.
        idx = 0
        while exp.More():
            return 0  # sphere body's single face
        return idx

    def test_sphere_lscm_unfolds_finite(self):
        """A non-developable sphere face flattens conformally to a finite,
        non-degenerate boundary loop and writes a DXF."""
        out = os.path.join(self.d, "sphere_conf.dxf")
        res = op_unfold_face({
            "input": self.sphere, "output": out,
            "body_index": 0, "face_index": 0,
            "distortion_mode": "conformal",
        })
        self.assertEqual(res.get("status"), "ok", msg=res)
        self.assertTrue(os.path.exists(out))
        doc = ezdxf.readfile(out)
        self.assertGreater(len(list(doc.modelspace())), 0)

    def test_all_distortion_modes_finite(self):
        """Every distortion mode flattens the sphere face to finite geometry
        without raising or producing NaNs."""
        bodies = get_solid_bodies(load_step_shape(self.sphere))
        from pathstitch_core.surface_unfold import unfold_freeform_face
        from OCC.Core.TopExp import TopExp_Explorer
        from OCC.Core.TopAbs import TopAbs_FACE
        from OCC.Core.TopoDS import topods
        exp = TopExp_Explorer(bodies[0], TopAbs_FACE)
        face = topods.Face(exp.Current())
        for mode in ("conformal", "equal-area", "equidistant", "balanced"):
            wires = unfold_freeform_face(face, mode=mode)
            self.assertTrue(_finite_polylines(wires),
                            msg=f"mode={mode} produced degenerate/NaN output")

    def test_distortion_heatmap_per_vertex(self):
        """op_face_distortion returns one finite, non-negative distortion value
        per mesh vertex for each mode (drives the 3D heatmap overlay)."""
        for mode in ("conformal", "equal-area", "equidistant", "balanced"):
            res = op_face_distortion({
                "input": self.sphere, "body_index": 0, "face_index": 0,
                "distortion_mode": mode,
            })
            self.assertEqual(res.get("status"), "ok", msg=res)
            dist = res.get("distortion")
            self.assertIsInstance(dist, list)
            self.assertGreater(len(dist), 0)
            for v in dist:
                self.assertTrue(math.isfinite(v) and v >= -1e-9,
                                msg=f"mode={mode} bad distortion value {v}")
        # A conformal map preserves angles but NOT area, so a sphere must show
        # some nonzero area distortion somewhere.
        res = op_face_distortion({
            "input": self.sphere, "body_index": 0, "face_index": 0,
            "distortion_mode": "conformal"})
        self.assertGreater(max(res["distortion"]), 1e-3)

    def test_hemisphere_split_closed_mesh(self):
        """A closed shell (no boundary) splits into two open sub-meshes that
        each carry a boundary loop and flatten — 'two hemispheres as one'."""
        # Build a closed octahedron-ish mesh: unit sphere sampling -> convex hull
        # is overkill; use a simple closed double-pyramid (octahedron).
        verts = [
            (1, 0, 0), (-1, 0, 0), (0, 1, 0),
            (0, -1, 0), (0, 0, 1), (0, 0, -1),
        ]
        tris = [
            (0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4),
            (0, 4, 2), (2, 4, 1), (1, 4, 3), (3, 4, 0),  # dummy dup removed below
        ]
        # Proper octahedron faces (closed, no boundary):
        tris = [
            (4, 0, 2), (4, 2, 1), (4, 1, 3), (4, 3, 0),
            (5, 2, 0), (5, 1, 2), (5, 3, 1), (5, 0, 3),
        ]
        self.assertEqual(boundary_loops(tris), [],
                         msg="octahedron should be closed (no boundary)")
        (va, ta), (vb, tb) = split_closed_mesh(verts, tris)
        self.assertGreater(len(ta), 0)
        self.assertGreater(len(tb), 0)
        self.assertTrue(boundary_loops(ta), "hemisphere A must have a boundary")
        self.assertTrue(boundary_loops(tb), "hemisphere B must have a boundary")
        uva = parameterize_mesh(va, ta, "conformal")
        uvb = parameterize_mesh(vb, tb, "conformal")
        self.assertEqual(len(uva), len(va))
        self.assertEqual(len(uvb), len(vb))

    def test_lscm_developable_is_near_isometric(self):
        """LSCM is exact for developables: a flat triangulated grid flattens
        back to itself up to rigid motion / uniform scale (angles preserved)."""
        # Planar 2x2 grid embedded in 3D (z=0), known geometry.
        verts = [(x, y, 0.0) for y in (0, 1, 2) for x in (0, 1, 2)]
        def vid(ix, iy):
            return iy * 3 + ix
        tris = []
        for iy in range(2):
            for ix in range(2):
                a, b = vid(ix, iy), vid(ix + 1, iy)
                c, d = vid(ix, iy + 1), vid(ix + 1, iy + 1)
                tris.append((a, b, d))
                tris.append((a, d, c))
        uv = lscm_flatten(verts, tris)
        # Check one triangle's angles are preserved vs. 3D.
        import numpy as np
        def angle(p, q, r):
            u = np.array(q) - np.array(p)
            w = np.array(r) - np.array(p)
            cu = np.dot(u, w) / (np.linalg.norm(u) * np.linalg.norm(w))
            return math.degrees(math.acos(max(-1, min(1, cu))))
        (i, j, k) = tris[0]
        a3 = angle(verts[i], verts[j], verts[k])
        a2 = angle(tuple(uv[i]), tuple(uv[j]), tuple(uv[k]))
        self.assertLess(abs(a3 - a2), 1.0,
                        msg=f"angle drift {abs(a3-a2):.3f}° too high for developable")


class TestConnectedNet(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = self.tmp.name
        self.box = os.path.join(self.d, "box.step")
        _write_step([BRepPrimAPI_MakeBox(40.0, 30.0, 20.0).Shape()], self.box)
        self.cyl = os.path.join(self.d, "cyl.step")
        ax2 = gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1))
        _write_step([BRepPrimAPI_MakeCylinder(ax2, 15.0, 40.0).Shape()], self.cyl)

    def tearDown(self):
        self.tmp.cleanup()

    def test_box_cross_net(self):
        """A box unfolds to a single connected patch with 5 fold edges."""
        out = os.path.join(self.d, "box.dxf")
        res = op_unfold_connected({
            "input": self.box, "output": out, "whole_body": True,
            "mode": "spanning", "decoration": "none",
        })
        self.assertEqual(res.get("status"), "ok", msg=res)
        data = res["data"]
        self.assertEqual(data["faces_unfolded"], 6)
        self.assertEqual(data["fold_edges"], 5)
        self.assertEqual(data["patches"], 1)

    def test_box_modes_all_valid(self):
        for mode in ("radial", "strip", "spanning"):
            out = os.path.join(self.d, f"box_{mode}.dxf")
            res = op_unfold_connected({
                "input": self.box, "output": out, "whole_body": True,
                "mode": mode, "decoration": "none"})
            self.assertEqual(res.get("status"), "ok", msg=res)
            self.assertEqual(res["data"]["faces_unfolded"], 6)

    def test_decorations_tabs_and_holes(self):
        for deco, layer in (("tabs", "GLUE_TABS"), ("holes", "SEW_HOLES")):
            out = os.path.join(self.d, f"box_{deco}.dxf")
            res = op_unfold_connected({
                "input": self.box, "output": out, "whole_body": True,
                "mode": "spanning", "decoration": deco,
                "tab_height": 6.0, "hole_diameter": 2.0,
                "hole_spacing": 8.0, "hole_margin": 3.0})
            self.assertEqual(res.get("status"), "ok", msg=res)
            counts = _dxf_layer_counts(out)
            self.assertIn(layer, counts, msg=f"{deco}: no {layer} entities; {counts}")
            self.assertGreater(counts[layer], 0)

    def test_cylinder_closure_seam_tab(self):
        """Cylinder → rectangle + 2 caps; the rolled wall mates with itself so a
        closure-seam glue tab appears even with no face-to-face seam pair."""
        out = os.path.join(self.d, "cyl.dxf")
        res = op_unfold_connected({
            "input": self.cyl, "output": out, "whole_body": True,
            "mode": "spanning", "decoration": "tabs", "tab_height": 5.0})
        self.assertEqual(res.get("status"), "ok", msg=res)
        counts = _dxf_layer_counts(out)
        self.assertIn("GLUE_TABS", counts)

    def test_anchor_changes_layout_but_stays_valid(self):
        """Setting an explicit anchor face still yields a valid net."""
        out = os.path.join(self.d, "box_anchor.dxf")
        res = op_unfold_connected({
            "input": self.box, "output": out, "whole_body": True,
            "mode": "radial", "decoration": "none",
            "anchor": {"body_index": 0, "face_index": 3}})
        self.assertEqual(res.get("status"), "ok", msg=res)
        self.assertEqual(res["data"]["faces_unfolded"], 6)

    def _a_fold_edge_id(self):
        """Find one fold-eligible shared edge id of the box via engine internals."""
        body = get_solid_bodies(load_step_shape(self.box))[0]
        records, edge_to_faces, _ = net_unfold._build_records(body, None)
        adj = net_unfold._fold_candidates(records, edge_to_faces)
        for f, nbrs in adj.items():
            for (_n, eid, _w) in nbrs:
                return eid
        return None

    def test_manual_forced_seam_excludes_that_edge(self):
        """Phase 3 manual mode: a forced seam is dropped from the fold-candidate
        graph, so that exact edge can never become a crease (even though the
        spanning tree may reroute around it to keep the net connected)."""
        body = get_solid_bodies(load_step_shape(self.box))[0]
        records, edge_to_faces, _ = net_unfold._build_records(body, None)
        eid = self._a_fold_edge_id()
        self.assertIsNotNone(eid)

        # With the edge forced as a seam, it must not appear in any fold pair.
        adj = net_unfold._fold_candidates(
            records, edge_to_faces, forced_seams={eid})
        anchor = max(records, key=lambda f: records[f]["area"])
        order = net_unfold._spanning_order(records, adj, anchor, "spanning")
        _placements, fold_pairs, _patch = net_unfold._rollout(records, order)
        fold_eids = {e for (_a, _b, e) in fold_pairs}
        self.assertNotIn(eid, fold_eids)

    def test_manual_force_all_seams_zero_folds(self):
        """Forcing every fold-eligible edge to be a seam yields a fully cut net:
        no folds, every face its own patch."""
        body = get_solid_bodies(load_step_shape(self.box))[0]
        records, edge_to_faces, _ = net_unfold._build_records(body, None)
        adj = net_unfold._fold_candidates(records, edge_to_faces)
        all_eids = {eid for nbrs in adj.values() for (_n, eid, _w) in nbrs}
        forced = [{"body_index": 0, "edge_index": e} for e in all_eids]
        res = op_unfold_connected({
            "input": self.box, "output": os.path.join(self.d, "ball.dxf"),
            "whole_body": True, "mode": "spanning", "decoration": "none",
            "forced_seams": forced})
        self.assertEqual(res.get("status"), "ok", msg=res)
        self.assertEqual(res["data"]["fold_edges"], 0)
        self.assertEqual(res["data"]["patches"], 6)

    def test_hybrid_forbidden_seam_valid(self):
        """Phase 3 hybrid mode: pinning a fold-eligible edge as a forced fold
        keeps the net valid and that edge stays a fold."""
        eid = self._a_fold_edge_id()
        res = op_unfold_connected({
            "input": self.box, "output": os.path.join(self.d, "b2.dxf"),
            "whole_body": True, "mode": "spanning", "decoration": "none",
            "forbidden_seams": [{"body_index": 0, "edge_index": eid}]})
        self.assertEqual(res.get("status"), "ok", msg=res)
        self.assertEqual(res["data"]["fold_edges"], 5)

    def test_per_seam_decoration_override(self):
        """Phase 4 per-seam override: globally plain, but one edge forced to
        'holes' must add a SEW_HOLES entity."""
        # Pick a seam edge (a closed cap boundary or any non-fold edge). Use a
        # box edge id and force holes on it; even if it's a fold, the override
        # only applies to drawn seams, so force it to a seam too.
        eid = self._a_fold_edge_id()
        res = op_unfold_connected({
            "input": self.box, "output": os.path.join(self.d, "b3.dxf"),
            "whole_body": True, "mode": "spanning", "decoration": "none",
            "forced_seams": [{"body_index": 0, "edge_index": eid}],
            "seam_decorations": [
                {"body_index": 0, "edge_index": eid, "decoration": "holes"}],
        })
        self.assertEqual(res.get("status"), "ok", msg=res)
        counts = _dxf_layer_counts(os.path.join(self.d, "b3.dxf"))
        self.assertIn("SEW_HOLES", counts,
                      msg=f"override didn't add holes; layers={counts}")


class TestCurvedInNet(unittest.TestCase):
    """Phase 2 integration: an 'Other' (curved) face flattens via LSCM and
    participates in the connected-net rollout instead of being skipped."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = self.tmp.name
        self.sphere = os.path.join(self.d, "sphere.step")
        _write_step([BRepPrimAPI_MakeSphere(18.0).Shape()], self.sphere)
        self.cone = os.path.join(self.d, "cone.step")
        ax2 = gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1))
        _write_step([BRepPrimAPI_MakeCone(ax2, 20.0, 0.0, 30.0).Shape()], self.cone)

    def tearDown(self):
        self.tmp.cleanup()

    def test_sphere_body_connected_unfolds_no_skips(self):
        out = os.path.join(self.d, "sphere_net.dxf")
        base_args = {
            "input": self.sphere, "output": out, "whole_body": True,
            "mode": "spanning", "decoration": "none",
            "distortion_mode": "conformal"}
        res = op_unfold_connected(base_args)
        self.assertEqual(res.get("status"), "ok", msg=res)
        self.assertGreaterEqual(res["data"]["faces_unfolded"], 1)
        self.assertEqual(res["data"].get("skipped_faces"), [])
        # By default the distortion-heatmap facelets are NOT written, so the DXF
        # stays a clean set of cut/crease lines for a DXF reader (MAS-157).
        counts = _dxf_layer_counts(out)
        self.assertNotIn("DISTORTION", counts)
        # Opt-in restores the heatmap facelets.
        res2 = op_unfold_connected({**base_args, "include_distortion": True})
        self.assertEqual(res2.get("status"), "ok", msg=res2)
        self.assertIn("DISTORTION", _dxf_layer_counts(out))

    def test_cone_apex_unfolds(self):
        out = os.path.join(self.d, "cone_net.dxf")
        res = op_unfold_connected({
            "input": self.cone, "output": out, "whole_body": True,
            "mode": "spanning", "decoration": "tabs", "tab_height": 4.0})
        self.assertEqual(res.get("status"), "ok", msg=res)
        self.assertGreaterEqual(res["data"]["faces_unfolded"], 2)


class TestMeshImportToFlatten(unittest.TestCase):
    """Phase 4: OBJ/STL mesh-only models route into the flattener — every face
    is 'Other' and must unfold via LSCM end-to-end."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def test_obj_pyramid_connected_unfold(self):
        obj = os.path.join(self.d, "pyr.obj")
        with open(obj, "w") as f:
            f.write(
                "v 0 0 0\nv 20 0 0\nv 20 20 0\nv 0 20 0\nv 10 10 18\n"
                "f 1 2 3 4\nf 1 2 5\nf 2 3 5\nf 3 4 5\nf 4 1 5\n")
        out = os.path.join(self.d, "pyr.dxf")
        res = op_unfold_connected({
            "input": obj, "output": out, "whole_body": True,
            "mode": "spanning", "decoration": "none",
            "distortion_mode": "conformal"})
        self.assertEqual(res.get("status"), "ok", msg=res)
        self.assertEqual(res["data"]["faces_unfolded"], 5)

    def test_stl_triangle_unfold_face(self):
        stl = os.path.join(self.d, "tri.stl")
        with open(stl, "w") as f:
            f.write(
                "solid m\nfacet normal 0 0 1\nouter loop\n"
                "vertex 0 0 0\nvertex 10 0 0\nvertex 0 10 0\n"
                "endloop\nendfacet\nendsolid m\n")
        out = os.path.join(self.d, "tri.dxf")
        res = op_unfold_face({
            "input": stl, "output": out, "body_index": 0, "face_index": 0,
            "distortion_mode": "conformal"})
        self.assertEqual(res.get("status"), "ok", msg=res)


if __name__ == "__main__":
    unittest.main(verbosity=2)
