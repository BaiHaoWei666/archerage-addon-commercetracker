"""以 Lua 5.1 檢查封裝來源，並執行本專案回歸測試。"""
import json
import os
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
os.chdir(root)
manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
sources = set()
for pattern in manifest["files"]:
    for match in root.glob(pattern):
        sources.update(match.rglob("*.lua") if match.is_dir() else ([match] if match.suffix == ".lua" else []))
if not sources:
    raise RuntimeError("找不到 Lua 原始碼")
runtime = LuaRuntime()
assert runtime.eval("_VERSION") == "Lua 5.1"
for path in sorted(sources):
    runtime.execute("assert(loadstring(...))", path.read_text(encoding="utf-8"), "@" + path.as_posix())
print(f"PASS: {len(sources)} 個 Lua 檔案語法檢查", flush=True)
for path in sorted((root / "tests").glob("*.lua")):
    print(f"執行：{path.relative_to(root)}", flush=True)
    LuaRuntime().execute(path.read_text(encoding="utf-8"))
