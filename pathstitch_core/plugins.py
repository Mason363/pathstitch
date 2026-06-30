"""User plugin / scripting API (assembly_workflow.md Phase 4).

Pathstitch's whole geometry engine is a Python worker whose modules each expose an
`OPERATIONS` dict ({op_name: fn(args) -> dict}). That same convention is the
extension point: drop a `*.py` file exposing an `OPERATIONS` dict into the user
plugins directory and its ops become callable through the worker as module
`plugins`, op `<name>` — no rebuild, no fork.

A plugin op is just a function taking the args dict and returning a result dict
(`{"status": "ok", "data": {...}}` by convention), exactly like the built-ins, so
plugins can read/write DXFs with ezdxf/shapely or generate patterns procedurally.

Loading is deliberately defensive: a plugin that raises on import is skipped, never
taking the worker down. Discovery is re-run on every `plugins` dispatch, so a newly
dropped file is picked up without restarting the app.
"""
import os
import glob
import importlib.util
from typing import Any, Callable, Dict, Optional


def plugins_dir() -> str:
    """The user plugins directory (overridable via PATHSTITCH_PLUGINS_DIR for tests),
    mirroring the Swift side's Application Support/Pathstitch/plugins."""
    override = os.environ.get("PATHSTITCH_PLUGINS_DIR")
    if override:
        return override
    return os.path.join(os.path.expanduser("~"), "Library", "Application Support",
                        "Pathstitch", "plugins")


def load_operations(directory: Optional[str] = None) -> Dict[str, Callable[[Dict[str, Any]], Any]]:
    """Discovers every `*.py` in `directory`, imports it, and merges the callables
    from its `OPERATIONS` dict. Later files override earlier ones on a name clash.
    A broken plugin is skipped (it can't break the others or the worker)."""
    directory = directory or plugins_dir()
    ops: Dict[str, Callable[[Dict[str, Any]], Any]] = {}
    if not directory or not os.path.isdir(directory):
        return ops
    for path in sorted(glob.glob(os.path.join(directory, "*.py"))):
        stem = os.path.splitext(os.path.basename(path))[0]
        if stem.startswith("_"):
            continue  # convention: `_foo.py` is a private helper, not a plugin
        mod_name = "pathstitch_plugin_" + stem
        try:
            spec = importlib.util.spec_from_file_location(mod_name, path)
            if spec is None or spec.loader is None:
                continue
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            mod_ops = getattr(mod, "OPERATIONS", None)
            if isinstance(mod_ops, dict):
                for name, fn in mod_ops.items():
                    if callable(fn):
                        ops[str(name)] = fn
        except Exception:
            continue  # a plugin that fails to import must never take down the worker
    return ops


def list_plugins(directory: Optional[str] = None) -> Dict[str, Any]:
    """Worker op: report the loaded plugin op names (so a UI can list what's available)."""
    ops = load_operations(directory if directory else None)
    return {"status": "ok", "data": {"ops": sorted(ops.keys()), "count": len(ops),
                                      "dir": directory or plugins_dir()}}


# Built-in ops of the `plugins` module itself (discovery). User ops are merged on
# top of these at dispatch time by `load_operations` in the worker.
OPERATIONS = {
    "list": lambda args: list_plugins(args.get("dir")),
}
