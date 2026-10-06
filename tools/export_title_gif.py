"""Encode the frames rendered by title_visual_check.gd as an animated GIF.

No image editing: the Godot scene renders the animation; Pillow only encodes
those frames. Run the graphical validator first. Requires Pillow.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
FRAMES = ROOT / ".godot" / "title_review" / "gif_frames"
OUTPUT = ROOT / "assets" / "art" / "title" / "fishing_boat_loop.gif"


def main():
    paths = sorted(FRAMES.glob("boat_*.png"))
    assert len(paths) == 48, f"Expected 48 rendered frames, got {len(paths)}"
    frames = []
    for path in paths:
        with Image.open(path) as source:
            frames.append(source.convert("RGB").quantize(colors=256))
    frames[0].save(OUTPUT, save_all=True, append_images=frames[1:], duration=100,
                   loop=0, disposal=2, optimize=False)
    with Image.open(OUTPUT) as saved:
        assert saved.n_frames == 48
        assert saved.info["loop"] == 0
        print(f"{OUTPUT}: {saved.n_frames} frames, {saved.size}, 4.8 s, {OUTPUT.stat().st_size} bytes")


if __name__ == "__main__":
    main()
