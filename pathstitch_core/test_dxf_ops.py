import subprocess
import json
import os

PYTHON_BIN = "/opt/homebrew/Caskroom/miniconda/base/envs/pathstitch/bin/python"

def run_cli(op, args):
    payload = json.dumps({"op": op, "args": args})
    # Run python -m pathstitch_core.dxf_ops
    cmd = [PYTHON_BIN, "-m", "pathstitch_core.dxf_ops", "--json", payload]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"CLI process crashed: {res.stderr}")
    try:
        return json.loads(res.stdout)
    except json.JSONDecodeError:
        raise RuntimeError(f"Failed to decode CLI stdout: {res.stdout}")

def test_dxf_ops():
    input_dxf = "TestFiles/test.dxf"
    
    # 1. Test list_entities
    print("Testing list_entities...")
    res = run_cli("list_entities", {"input": input_dxf})
    assert res["status"] == "ok", f"list_entities failed: {res}"
    entities = res["data"]["entities"]
    print(f"Found {len(entities)} entities in test.dxf")
    assert len(entities) == 3, f"Expected 3 entities, got {len(entities)}"
    
    # 2. Test offset_lines
    print("Testing offset_lines...")
    offset_dxf = "TestFiles/test_offset.dxf"
    res = run_cli("offset_lines", {
        "input": input_dxf,
        "output": offset_dxf,
        "distance": 3.0,
        "side": "left",
        "layer": "OFFSET"
    })
    assert res["status"] == "ok", f"offset_lines failed: {res}"
    assert os.path.exists(offset_dxf), "Offset DXF file not created"
    
    # Verify offset file has entities
    res = run_cli("list_entities", {"input": offset_dxf})
    entities = res["data"]["entities"]
    offset_count = sum(1 for e in entities if e["layer"] == "OFFSET")
    print(f"Found {offset_count} entities on OFFSET layer")
    assert offset_count > 0, "No offset entities generated"
    
    # 3. Test add_holes
    print("Testing add_holes (single row)...")
    holes_dxf = "TestFiles/test_holes.dxf"
    res = run_cli("add_holes", {
        "input": input_dxf,
        "output": holes_dxf,
        "offset_distance": 5.0,
        "hole_diameter": 1.5,
        "hole_spacing": 6.0,
        "pattern": "single",
        "corner_behavior": "skip",
        "side": "left"
    })
    assert res["status"] == "ok", f"add_holes failed: {res}"
    assert os.path.exists(holes_dxf), "Holes DXF file not created"
    
    res = run_cli("list_entities", {"input": holes_dxf})
    entities = res["data"]["entities"]
    hole_count = sum(1 for e in entities if e["layer"] == "SEWING_HOLES")
    print(f"Generated {hole_count} sewing holes (single row)")
    assert hole_count > 0, "No sewing holes generated"

    # Test add_holes (saddle stitching)
    print("Testing add_holes (saddle staggered pattern)...")
    saddle_dxf = "TestFiles/test_saddle.dxf"
    res = run_cli("add_holes", {
        "input": input_dxf,
        "output": saddle_dxf,
        "offset_distance": 5.0,
        "hole_diameter": 1.5,
        "hole_spacing": 6.0,
        "pattern": "saddle",
        "corner_behavior": "skip",
        "side": "left",
        "row_spacing": 3.0
    })
    assert res["status"] == "ok", f"add_holes (saddle) failed: {res}"
    
    res = run_cli("list_entities", {"input": saddle_dxf})
    entities = res["data"]["entities"]
    saddle_hole_count = sum(1 for e in entities if e["layer"] == "SEWING_HOLES")
    print(f"Generated {saddle_hole_count} sewing holes (saddle stitching)")
    assert saddle_hole_count > hole_count, "Saddle stitch should produce more holes than single stitch"

    # 4. Test export_svg
    print("Testing export_svg...")
    output_svg = "TestFiles/test.svg"
    res = run_cli("export_svg", {
        "input": input_dxf,
        "output": output_svg
    })
    assert res["status"] == "ok", f"export_svg failed: {res}"
    assert os.path.exists(output_svg), "SVG file not created"
    print(f"SVG successfully exported to: {output_svg}")
    
    # 5. Test cleanup
    print("Testing cleanup...")
    cleanup_dxf = "TestFiles/test_cleanup.dxf"
    res = run_cli("cleanup", {
        "input": input_dxf,
        "output": cleanup_dxf,
        "tolerance": 0.5
    })
    assert res["status"] == "ok", f"cleanup failed: {res}"
    assert os.path.exists(cleanup_dxf), "Cleanup DXF file not created"
    print(f"Cleanup stats: {res['data']}")

    # 6. Test new_dxf creates a valid blank document
    print("Testing new_dxf (blank document)...")
    blank_dxf = "TestFiles/test_blank.dxf"
    if os.path.exists(blank_dxf):
        os.remove(blank_dxf)
    res = run_cli("new_dxf", {"output": blank_dxf})
    assert res["status"] == "ok", f"new_dxf failed: {res}"
    assert os.path.exists(blank_dxf), "Blank DXF file not created"
    res = run_cli("list_entities", {"input": blank_dxf})
    assert res["status"] == "ok", f"list_entities on blank failed: {res}"
    assert len(res["data"]["entities"]) == 0, "Blank DXF should have no entities"
    print("Blank document created and lists 0 entities")

    # 7. Test export_svg on an empty document returns a valid empty SVG (no error)
    print("Testing export_svg on empty document...")
    empty_svg = "TestFiles/test_empty.svg"
    if os.path.exists(empty_svg):
        os.remove(empty_svg)
    res = run_cli("export_svg", {"input": blank_dxf, "output": empty_svg})
    assert res["status"] == "ok", f"export_svg on empty should succeed: {res}"
    assert res["data"].get("empty") is True, f"export_svg should flag empty: {res}"
    assert os.path.exists(empty_svg), "Empty SVG file not created"
    print("Empty document exported a valid empty SVG without erroring")

    # 8. Test append_dxf merges into a blank document (MAS-13 regression).
    print("Testing append_dxf into a blank document...")
    merged_dxf = "TestFiles/test_merged.dxf"
    if os.path.exists(merged_dxf):
        os.remove(merged_dxf)
    res = run_cli("append_dxf", {
        "primary": blank_dxf,
        "secondary": input_dxf,
        "output": merged_dxf
    })
    assert res["status"] == "ok", f"append_dxf into blank failed: {res}"
    res = run_cli("list_entities", {"input": merged_dxf})
    merged_count = len(res["data"]["entities"])
    print(f"Merged document has {merged_count} entities")
    assert merged_count == 3, f"Expected 3 merged entities, got {merged_count}"
 
    # 9. Test point ignoring and import_distribute layout aspect ratio
    print("Testing point ignoring and import_distribute layout...")
    import ezdxf
    
    # Create a secondary DXF with:
    # - a line from (10, 10) to (20, 20)
    # - a touching POINT at (10, 10)
    # - an isolated POINT at (100, 100) (should be ignored for layout calculation)
    test_pts_dxf = "TestFiles/test_pts.dxf"
    doc_pts = ezdxf.new(dxfversion="R2010")
    msp_pts = doc_pts.modelspace()
    msp_pts.add_line((10.0, 10.0), (20.0, 20.0))
    msp_pts.add_point((10.0, 10.0))
    msp_pts.add_point((100.0, 100.0))
    doc_pts.saveas(test_pts_dxf)
    
    pts_out_dxf = "TestFiles/test_pts_out.dxf"
    if os.path.exists(pts_out_dxf):
        os.remove(pts_out_dxf)
        
    res = run_cli("import_distribute", {
        "primary": blank_dxf,
        "secondaries": [test_pts_dxf],
        "output": pts_out_dxf
    })
    assert res["status"] == "ok", f"import_distribute failed: {res}"
    
    # Read output and verify the line is centered around (0,0),
    # meaning the bounds center used was (15,15) and NOT (55,55).
    doc_out = ezdxf.readfile(pts_out_dxf)
    msp_out = doc_out.modelspace()
    lines = [e for e in msp_out if e.dxftype() == "LINE"]
    assert len(lines) == 1, "Expected 1 line in output"
    line = lines[0]
    l_cx = (line.dxf.start.x + line.dxf.end.x) / 2.0
    l_cy = (line.dxf.start.y + line.dxf.end.y) / 2.0
    assert abs(l_cx) < 0.1 and abs(l_cy) < 0.1, f"Expected line center near (0,0), got ({l_cx}, {l_cy})"
    print("Isolated points successfully ignored in bounds calculation!")

    # Test 2D compact grid distribution of multiple files (e.g. 3 files)
    print("Testing 2D compact grid layout distribution...")
    grid_out_dxf = "TestFiles/test_grid_out.dxf"
    if os.path.exists(grid_out_dxf):
        os.remove(grid_out_dxf)
    
    res = run_cli("import_distribute", {
        "primary": blank_dxf,
        "secondaries": [test_pts_dxf, test_pts_dxf, test_pts_dxf],
        "output": grid_out_dxf
    })
    assert res["status"] == "ok", f"import_distribute for grid failed: {res}"
    
    doc_grid = ezdxf.readfile(grid_out_dxf)
    msp_grid = doc_grid.modelspace()
    lines_grid = [e for e in msp_grid if e.dxftype() == "LINE"]
    assert len(lines_grid) == 3, f"Expected 3 lines, got {len(lines_grid)}"
    
    centers = [((l.dxf.start.x + l.dxf.end.x)/2.0, (l.dxf.start.y + l.dxf.end.y)/2.0) for l in lines_grid]
    y_coords = [c[1] for c in centers]
    min_y, max_y = min(y_coords), max(y_coords)
    assert abs(max_y - min_y) > 10.0, f"Expected items to stack vertically (diff in Y > 10), got Y coords: {y_coords}"
    # 10. Test chain_select with intermediate vertices (rect + line)
    print("Testing chain_select with polyline vertices...")
    chain_test_dxf = "TestFiles/test_chain.dxf"
    if os.path.exists(chain_test_dxf):
        os.remove(chain_test_dxf)
    doc_chain = ezdxf.new(dxfversion="R2010")
    msp_chain = doc_chain.modelspace()
    # Add a rectangle (closed polyline) with corners at (0,0), (10,0), (10,10), (0,10)
    rect = msp_chain.add_lwpolyline([(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)], dxfattribs={"closed": True})
    # Add a line connecting to the corner (10, 10) of the rectangle, ending at (20, 10)
    line = msp_chain.add_line((10.0, 10.0), (20.0, 10.0))
    doc_chain.saveas(chain_test_dxf)
    
    # Run chain_select with seed rect.dxf.handle
    res = run_cli("chain_select", {
        "input": chain_test_dxf,
        "seed_handle": rect.dxf.handle,
        "tolerance": 0.1
    })
    assert res["status"] == "ok", f"chain_select failed: {res}"
    handles = res["data"]["handles"]
    print(f"Chain select returned handles: {handles}")
    assert rect.dxf.handle in handles, "Rectangle should be in chain"
    assert line.dxf.handle in handles, "Touching line should be in chain"
    print("Chain selection with intermediate vertices verified successfully!")

    # 11. Test PSD import (MAS-141)
    test_parse_psd()

    print("ALL TESTS PASSED SUCCESSFULLY!")


def test_parse_psd():
    """Validates op_parse_psd (MAS-141). Always exercises the synthetic
    fully-flattened path; additionally validates real multi-layer/vector PSDs
    when the local test-asset folder is present."""
    print("Testing parse_psd...")
    try:
        from psd_tools import PSDImage
        from PIL import Image
    except Exception as e:
        print(f"  psd-tools/PIL unavailable, skipping PSD tests: {e}")
        return

    import tempfile, shutil
    out_dir = tempfile.mkdtemp(prefix="psdtest_")
    try:
        # A flattened PSD (no explicit layer records) must still import as one
        # raster layer thanks to the composite fallback.
        flat = os.path.join(out_dir, "flat.psd")
        PSDImage.frompil(Image.new("RGBA", (64, 48), (120, 30, 30, 255))).save(flat)
        res = run_cli("parse_psd", {"input": flat, "out_dir": out_dir})
        assert res["status"] == "ok", f"parse_psd(flat) failed: {res}"
        d = res["data"]
        assert d["canvas_width"] == 64 and d["canvas_height"] == 48
        assert len(d["layers"]) >= 1, "Flattened PSD should import as >=1 layer"
        assert os.path.exists(d["composite_png_path"]), "composite PNG missing"
        assert d["layers"][0]["kind"] == "raster"
        print("  Flattened PSD imported as a single reference image.")

        # Real-asset validation (developer machine only).
        asset_dir = "/Users/chen/Documents/Assets/Other Pathstitch Files/Pathstitch .PSD tests"
        if os.path.isdir(asset_dir):
            raster_file = os.path.join(asset_dir, "Raster No Backtround 4 layers.psd")
            if os.path.exists(raster_file):
                r = run_cli("parse_psd", {"input": raster_file, "out_dir": out_dir})
                assert r["status"] == "ok", f"parse_psd(raster) failed: {r}"
                rl = [l for l in r["data"]["layers"] if l["kind"] == "raster"]
                assert len(rl) == 4, f"Expected 4 raster layers, got {len(rl)}"
                for l in rl:
                    assert os.path.exists(l["png_path"]), "raster PNG missing"
                    assert l["width_px"] > 0 and l["height_px"] > 0
                print(f"  Multi-layer raster PSD: {len(rl)} layers extracted.")

            vector_file = os.path.join(asset_dir, "Vector No Background 1 layers.psd")
            if os.path.exists(vector_file):
                v = run_cli("parse_psd", {"input": vector_file, "out_dir": out_dir})
                assert v["status"] == "ok", f"parse_psd(vector) failed: {v}"
                vl = [l for l in v["data"]["layers"] if l["kind"] == "vector"]
                assert len(vl) >= 1, "Expected a vector layer from a vector PSD"
                total_verts = sum(len(e["vertices"]) for l in vl for e in l["entities"])
                assert total_verts > 50, f"Vector layer too sparse: {total_verts} verts"
                print(f"  Vector PSD: {len(vl)} vector layer(s), {total_verts} verts extracted.")
        else:
            print("  (Skipping real-asset PSD checks: asset folder not present.)")

        print("PSD import verified successfully!")
    finally:
        shutil.rmtree(out_dir, ignore_errors=True)


if __name__ == "__main__":
    test_dxf_ops()
