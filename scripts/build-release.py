"""依 manifest 白名單封裝插件；Release 附件是安裝器唯一下載來源。"""
import hashlib
import json
import re
import shutil
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

root = Path(__file__).resolve().parents[1]
m = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
name, version = m["name"], m["version"]
if m["schemaVersion"] != 1 or not re.fullmatch(r"[A-Za-z0-9_-]+", name) or not re.fullmatch(r"\d+\.\d+\.\d+", version):
    raise ValueError("插件名稱、版本或格式不合法")
dist = root / "dist"
dist.mkdir(exist_ok=True)
files = set()
for pattern in m["files"]:
    if pattern.startswith(("/", "\\")) or ".." in Path(pattern).parts:
        raise ValueError("封裝路徑必須位於插件目錄內")
    matches = list(root.glob(pattern))
    if not matches:
        raise ValueError(f"封裝項目不存在：{pattern}")
    for match in matches:
        for file in match.rglob("*") if match.is_dir() else [match]:
            if not file.is_file():
                continue
            relative = file.relative_to(root)
            if not file.resolve().is_relative_to(root.resolve()) or any(part.startswith(".") or part in {"dist", "tests", "scripts", "__pycache__"} for part in relative.parts):
                raise ValueError(f"不允許封裝開發檔案：{relative}")
            files.add(file)
archive = dist / f"{name}.zip"
with ZipFile(archive, "w", ZIP_DEFLATED) as z:
    for file in sorted(files):
        z.write(file, f"{name}/{file.relative_to(root).as_posix()}")
    z.writestr(f"{name}/version.txt", version)
with ZipFile(archive) as z:
    assert z.read(f"{name}/version.txt").decode() == version
    for file in files:
        assert z.read(f"{name}/{file.relative_to(root).as_posix()}") == file.read_bytes()
published = {k: v for k, v in m.items() if k != "files"}
published["sha256"] = hashlib.sha256(archive.read_bytes()).hexdigest()
(dist / "manifest.json").write_text(json.dumps(published, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
shutil.copy2(root / "README.md", dist / f"{name}.md")
if (root / "icon.png").is_file():
    shutil.copy2(root / "icon.png", dist / f"{name}.png")
(root / "version.txt").write_text(version, encoding="ascii")
print(f"已封裝並核對 {name} {version}")
