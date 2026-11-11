import base64, pathlib
here = pathlib.Path(__file__).parent
t = (here / "template.html").read_text()
t = t.replace("__GRID__", (here / "grid.txt").read_text().strip())
t = t.replace("__PC__", base64.b64encode((here / "pc.jpg").read_bytes()).decode())
t = t.replace("__PHONE__", base64.b64encode((here / "phone.jpg").read_bytes()).decode())
(here / "arena_hardpoint_v0.1.html").write_text(t)
print(len(t))
