"""
test_mesh_imports.py

Unit test for checking STL and OBJ mesh import support in step_ops.py.
"""

import os
import tempfile
import unittest
from pathstitch_core.step_ops import load_step_shape, get_solid_bodies, op_list_bodies

class TestMeshImports(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_stl_import(self):
        # 1. Write a simple ASCII STL file representing a single triangle
        stl_path = os.path.join(self.temp_dir.name, "test.stl")
        stl_content = """solid mock
facet normal 0.0 0.0 1.0
  outer loop
    vertex 0.0 0.0 0.0
    vertex 10.0 0.0 0.0
    vertex 0.0 10.0 0.0
  endloop
endfacet
endsolid mock
"""
        with open(stl_path, "w", encoding="utf-8") as f:
            f.write(stl_content)

        # 2. Load shape
        shape = load_step_shape(stl_path)
        self.assertIsNotNone(shape)
        self.assertFalse(shape.IsNull())

        # 3. Extract bodies
        bodies = get_solid_bodies(shape)
        self.assertEqual(len(bodies), 1)

        # 4. List bodies op
        result = op_list_bodies({"input": stl_path})
        self.assertEqual(result.get("status"), "ok")
        data = result.get("data", {})
        bodies_list = data.get("bodies", [])
        self.assertEqual(len(bodies_list), 1)
        body0 = bodies_list[0]
        self.assertEqual(len(body0.get("faces", [])), 1)
        self.assertGreater(len(body0.get("faces")[0].get("vertices", [])), 0)

    def test_obj_import(self):
        # 1. Write a simple OBJ file representing a pyramid (5 vertices, 5 faces)
        obj_path = os.path.join(self.temp_dir.name, "test.obj")
        obj_content = """# Mock OBJ Pyramid
v 0.0 0.0 0.0
v 10.0 0.0 0.0
v 10.0 10.0 0.0
v 0.0 10.0 0.0
v 5.0 5.0 10.0

# Base face (quad)
f 1 2 3 4
# Triangular sides
f 1 2 5
f 2 3 5
f 3 4 5
f 4 1 5
"""
        with open(obj_path, "w", encoding="utf-8") as f:
            f.write(obj_content)

        # 2. Load shape
        shape = load_step_shape(obj_path)
        self.assertIsNotNone(shape)
        self.assertFalse(shape.IsNull())

        # 3. Extract bodies
        bodies = get_solid_bodies(shape)
        self.assertEqual(len(bodies), 1)

        # 4. List bodies op
        result = op_list_bodies({"input": obj_path})
        self.assertEqual(result.get("status"), "ok")
        data = result.get("data", {})
        bodies_list = data.get("bodies", [])
        self.assertEqual(len(bodies_list), 1)
        body0 = bodies_list[0]
        # Should have 5 faces
        self.assertEqual(len(body0.get("faces", [])), 5)
        self.assertGreater(len(body0.get("faces")[0].get("vertices", [])), 0)

if __name__ == "__main__":
    unittest.main()
