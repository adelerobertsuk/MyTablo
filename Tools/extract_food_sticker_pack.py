#!/usr/bin/env python3
"""Extract prototype sticker PNGs from the approved 5x4 food contact sheet."""

from __future__ import annotations

from collections import deque
from pathlib import Path
import zipfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont


SOURCE = Path("/Users/adeleroberts/Downloads/Gemini_Generated_Image_2orphl2orphl2orp.png")
OUTPUT = Path("StickerPacks/BritishTableFavourites-Prototype")
ZIP_PATH = Path("StickerPacks/BritishTableFavourites-Prototype.zip")

FILENAMES = [
    "01-empty-white-dinner-plate.png",
    "02-stainless-steel-fork.png",
    "03-stainless-steel-knife.png",
    "04-stainless-steel-spoon.png",
    "05-folded-cloth-napkin.png",
    "06-cup-of-tea-and-saucer.png",
    "07-full-english-breakfast.png",
    "08-fish-and-chips.png",
    "09-sunday-roast-with-yorkshire-pudding.png",
    "10-sausage-roll.png",
    "11-cornish-style-pasty.png",
    "12-beans-on-toast.png",
    "13-buttered-crumpets.png",
    "14-scone-with-jam-and-clotted-cream.png",
    "15-slice-of-victoria-sponge.png",
    "16-jam-doughnut.png",
    "17-tea-biscuits-assortment.png",
    "18-jacket-potato-with-cheese-and-beans.png",
    "19-bacon-sandwich.png",
    "20-curry-and-rice-in-plain-dishes.png",
]


def connected_components(mask: np.ndarray) -> list[tuple[int, list[tuple[int, int]]]]:
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    components: list[tuple[int, list[tuple[int, int]]]] = []
    for y in range(height):
        for x in range(width):
            if not mask[y, x] or seen[y, x]:
                continue
            queue = deque([(x, y)])
            seen[y, x] = True
            pixels: list[tuple[int, int]] = []
            while queue:
                px, py = queue.popleft()
                pixels.append((px, py))
                for nx, ny in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
                    if 0 <= nx < width and 0 <= ny < height and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        queue.append((nx, ny))
            components.append((len(pixels), pixels))
    return components


def fill_enclosed_holes(mask: np.ndarray) -> np.ndarray:
    height, width = mask.shape
    outside = np.zeros_like(mask, dtype=bool)
    queue: deque[tuple[int, int]] = deque()
    for x in range(width):
        for y in (0, height - 1):
            if not mask[y, x] and not outside[y, x]:
                outside[y, x] = True
                queue.append((x, y))
    for y in range(height):
        for x in (0, width - 1):
            if not mask[y, x] and not outside[y, x]:
                outside[y, x] = True
                queue.append((x, y))
    while queue:
        px, py = queue.popleft()
        for nx, ny in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
            if 0 <= nx < width and 0 <= ny < height and not mask[ny, nx] and not outside[ny, nx]:
                outside[ny, nx] = True
                queue.append((nx, ny))
    return mask | (~mask & ~outside)


def estimate_background(rgb: np.ndarray) -> np.ndarray:
    height, width, _ = rgb.shape
    border = np.concatenate(
        [
            rgb[0:8, 42:width].reshape(-1, 3),
            rgb[height - 8:height].reshape(-1, 3),
            rgb[:, 0:8].reshape(-1, 3),
            rgb[:, width - 8:width].reshape(-1, 3),
        ]
    )
    return np.median(border, axis=0)


def remove_background(tile: Image.Image) -> Image.Image:
    rgb = np.asarray(tile.convert("RGB"), dtype=np.float32).copy()
    height, width, _ = rgb.shape
    background = estimate_background(rgb)

    # Erase the contact-sheet number using the estimated tile background.
    rgb[0:min(31, height), 0:min(42, width)] = background

    distance = np.linalg.norm(rgb - background, axis=2)
    # Slightly favour chromatic differences so pale ceramics remain intact.
    channel_spread = rgb.max(axis=2) - rgb.min(axis=2)
    background_spread = float(background.max() - background.min())
    chroma_delta = np.abs(channel_spread - background_spread)
    score = distance + chroma_delta * 0.35

    # Start with a firm foreground seed. A lower threshold preserves more shadow,
    # but also turns the contact-sheet lighting gradient into a visible rectangle.
    binary_image = Image.fromarray(np.where(score > 18.0, 255, 0).astype(np.uint8), "L")
    binary_image = binary_image.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(3))
    binary = np.asarray(binary_image) > 0
    binary[:8, :] = False
    binary[-8:, :] = False
    binary[:, :8] = False
    binary[:, -8:] = False
    binary[:34, :46] = False

    components = connected_components(binary)
    minimum_area = max(35, int(height * width * 0.0012))
    kept = np.zeros_like(binary)
    for area, pixels in components:
        if area < minimum_area:
            continue
        xs = np.fromiter((p[0] for p in pixels), dtype=np.int32)
        ys = np.fromiter((p[1] for p in pixels), dtype=np.int32)
        centre_x = float(xs.mean()) / width
        centre_y = float(ys.mean()) / height
        near_work_area = 0.12 < centre_x < 0.92 and 0.12 < centre_y < 0.95
        if near_work_area:
            kept[ys, xs] = True

    kept = fill_enclosed_holes(kept)
    # Filled silhouettes keep pale plates and cutlery intact. Only the outer edge
    # is softened; low-level background variation never becomes semi-opaque.
    alpha_image = (
        Image.fromarray(np.where(kept, 255, 0).astype(np.uint8), "L")
        .filter(ImageFilter.MaxFilter(3))
        .filter(ImageFilter.GaussianBlur(0.7))
    )

    rgba = Image.fromarray(rgb.astype(np.uint8), "RGB").convert("RGBA")
    rgba.putalpha(alpha_image)
    return rgba


def square_and_resize(image: Image.Image, size: int = 1024) -> Image.Image:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cropped = image.crop(bbox)
    subject_extent = max(cropped.width, cropped.height)
    canvas_extent = max(1, int(round(subject_extent / 0.76)))
    canvas = Image.new("RGBA", (canvas_extent, canvas_extent), (0, 0, 0, 0))
    x = (canvas_extent - cropped.width) // 2
    y = (canvas_extent - cropped.height) // 2
    canvas.alpha_composite(cropped, (x, y))
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def checkerboard(size: tuple[int, int], cell: int = 16) -> Image.Image:
    width, height = size
    board = Image.new("RGB", size, (235, 235, 235))
    draw = ImageDraw.Draw(board)
    for y in range(0, height, cell):
        for x in range(0, width, cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(205, 205, 205))
    return board


def main() -> None:
    source = Image.open(SOURCE).convert("RGB")
    if source.size != (1408, 768):
        raise ValueError(f"Unexpected contact-sheet size: {source.size}")

    x_ranges = [(0, 269), (281, 555), (567, 841), (853, 1127), (1139, 1408)]
    y_ranges = [(0, 182), (194, 378), (390, 574), (586, 768)]
    OUTPUT.mkdir(parents=True, exist_ok=True)

    previews: list[Image.Image] = []
    index = 0
    for y0, y1 in y_ranges:
        for x0, x1 in x_ranges:
            tile = source.crop((x0, y0, x1, y1))
            extracted = square_and_resize(remove_background(tile))
            out_path = OUTPUT / FILENAMES[index]
            extracted.save(out_path, format="PNG", optimize=True)

            preview = checkerboard((240, 240))
            preview_rgba = extracted.resize((220, 220), Image.Resampling.LANCZOS)
            preview.paste(preview_rgba, (10, 10), preview_rgba)
            draw = ImageDraw.Draw(preview)
            draw.rounded_rectangle((6, 6, 40, 32), radius=5, fill=(25, 25, 25))
            draw.text((12, 9), f"{index + 1:02d}", fill="white")
            previews.append(preview)
            index += 1

    contact = Image.new("RGB", (5 * 240, 4 * 240), "white")
    for item_index, preview in enumerate(previews):
        contact.paste(preview, ((item_index % 5) * 240, (item_index // 5) * 240))
    contact.save(OUTPUT / "00-alpha-quality-check.jpg", quality=92)

    with zipfile.ZipFile(ZIP_PATH, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for filename in FILENAMES:
            archive.write(OUTPUT / filename, arcname=filename)

    print(f"Extracted {len(FILENAMES)} files to {OUTPUT}")
    print(f"Created {ZIP_PATH}")


if __name__ == "__main__":
    main()
