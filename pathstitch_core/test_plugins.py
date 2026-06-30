"""Tests for the user plugin loader (Phase 4 — scripting API).

    PYTHONPATH=. python pathstitch_core/test_plugins.py
"""
import os
import tempfile

from pathstitch_core import plugins
from pathstitch_core import worker


def _plugin_dir_with(files: dict) -> str:
    d = tempfile.mkdtemp(prefix="pstitch_plugins_")
    for name, body in files.items():
        with open(os.path.join(d, name), "w") as f:
            f.write(body)
    return d


_GOOD = '''
def op_double(args):
    return {"status": "ok", "data": {"value": args.get("n", 0) * 2}}

OPERATIONS = {"double": op_double}
'''

_BROKEN = "this is not valid python ::::\n"

_PRIVATE = '''
OPERATIONS = {"secret": lambda a: {"status": "ok"}}
'''  # in a `_helper.py` → must be ignored


def test_loads_valid_plugin():
    d = _plugin_dir_with({"mathy.py": _GOOD})
    ops = plugins.load_operations(d)
    assert "double" in ops, ops.keys()
    res = ops["double"]({"n": 21})
    assert res["status"] == "ok" and res["data"]["value"] == 42, res
    print("plugin loader: custom op 'double' loaded and runs ✓")


def test_broken_plugin_is_skipped():
    d = _plugin_dir_with({"good.py": _GOOD, "bad.py": _BROKEN})
    ops = plugins.load_operations(d)
    assert "double" in ops, "a broken sibling must not block a valid plugin"
    print("plugin loader: broken plugin skipped, valid one still loads ✓")


def test_private_underscore_ignored():
    d = _plugin_dir_with({"_helper.py": _PRIVATE})
    ops = plugins.load_operations(d)
    assert "secret" not in ops, "_-prefixed files are helpers, not plugins"
    print("plugin loader: _-prefixed file ignored ✓")


def test_missing_dir_is_empty():
    assert plugins.load_operations("/no/such/dir/anywhere") == {}
    print("plugin loader: missing dir → no ops ✓")


def test_worker_dispatches_plugin_op():
    d = _plugin_dir_with({"mathy.py": _GOOD})
    os.environ["PATHSTITCH_PLUGINS_DIR"] = d
    try:
        ops = worker._get_operations("plugins")
        assert "list" in ops, "built-in plugins.list missing"
        assert "double" in ops, "user op not merged into the plugins module"
        # the discovery op reports the user op too
        listing = ops["list"]({})
        assert "double" in listing["data"]["ops"], listing
        assert ops["double"]({"n": 5})["data"]["value"] == 10
    finally:
        del os.environ["PATHSTITCH_PLUGINS_DIR"]
    print("worker: 'plugins' module merges built-in + user ops ✓")


if __name__ == "__main__":
    test_loads_valid_plugin()
    test_broken_plugin_is_skipped()
    test_private_underscore_ignored()
    test_missing_dir_is_empty()
    test_worker_dispatches_plugin_op()
    print("\nALL PLUGIN TESTS PASSED")
