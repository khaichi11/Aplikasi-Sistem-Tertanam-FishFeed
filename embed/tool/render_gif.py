"""Susun GIF demo dari bingkai PNG test/demo_render_test.dart, di dalam bingkai ponsel generik.

Bingkai digambar di laptop (tanpa emulator), sehingga prosesnya ringan: setiap bingkai dikecilkan, diberi bingkai
ponsel, lalu palet warnanya dibuat sekali untuk seluruh GIF.

    DEMO_FRAMES=build/frames flutter test test/demo_render_test.dart
    python3 tool/render_gif.py build/frames ../docs/images/demo.gif
"""

import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from phone_frame import phone  # noqa: E402

BG = (238, 243, 248)


def main(folder: str, out: str, width: int = 300) -> None:
    root = Path(folder)
    manifest = json.loads((root / "manifest.json").read_text())
    frames, durations, scenes = [], [], []
    for item in manifest:
        im = Image.open(root / item["file"]).convert("RGB")
        im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
        framed = phone(im, status_bar=False)
        canvas = Image.new("RGB", framed.size, BG)
        canvas.paste(framed, (0, 0), framed)
        # bingkai yang sama berturut-turut digabung supaya GIF lebih kecil
        if frames and list(canvas.getdata()) == list(frames[-1].getdata()):
            durations[-1] += item["ms"]
            continue
        frames.append(canvas)
        durations.append(item["ms"])
        scenes.append(item["scene"])
    # satu palet per adegan: palet bersama untuk seluruh GIF memudarkan warna foto (buah naga menjadi abu-abu), sedangkan
    # palet per bingkai membuat warna berkedip; dalam satu adegan warnanya tetap sama
    gif = []
    for scene in dict.fromkeys(scenes):
        members = [f for f, sc in zip(frames, scenes) if sc == scene]
        picks = members[:: max(1, len(members) // 8)]
        w, h = picks[0].size
        sample = Image.new("RGB", (w * len(picks), h))
        for i, f in enumerate(picks):
            sample.paste(f, (i * w, 0))
        palette = sample.quantize(colors=255, method=Image.Quantize.MEDIANCUT)
        # foto bahan diberi dither supaya gradasi warnanya halus; layar antarmuka yang rata tidak perlu
        dither = Image.Dither.FLOYDSTEINBERG if scene == "foto" else Image.Dither.NONE
        gif += [f.quantize(palette=palette, dither=dither) for f in members]
    gif[0].save(out, save_all=True, append_images=gif[1:], duration=durations, loop=0, optimize=False, disposal=1)
    print(f"{out}: {len(gif)} bingkai, {sum(durations) / 1000:.1f} detik")


if __name__ == "__main__":
    main(*sys.argv[1:3])
