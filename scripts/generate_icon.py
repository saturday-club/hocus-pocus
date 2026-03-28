#!/usr/bin/env python3
"""Generate the Hocus Pocus app icon - circular lens with focus rings."""

from PIL import Image, ImageDraw, ImageFilter
import math

SIZE = 1024
CENTER = SIZE // 2


def make_icon() -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    # macOS rounded rect mask
    mask = Image.new("L", (SIZE, SIZE), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([40, 40, SIZE - 40, SIZE - 40], radius=200, fill=255)

    # Deep dark background with radial gradient
    bg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    for y in range(SIZE):
        for x in range(SIZE):
            dx = x - CENTER
            dy = y - CENTER
            dist = math.sqrt(dx * dx + dy * dy) / (SIZE * 0.7)
            dist = min(dist, 1.0)
            r = int(12 + dist * 6)
            g = int(8 + dist * 4)
            b = int(28 + dist * 12)
            bg.putpixel((x, y), (r, g, b, 255))
    bg.putalpha(mask)
    img = bg.copy()

    # Outer ambient glow (large, soft purple)
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    for r in range(350, 0, -2):
        alpha = int(25 * (1 - r / 350))
        glow_draw.ellipse(
            [CENTER - r, CENTER - r, CENTER + r, CENTER + r],
            fill=(90, 60, 200, alpha),
        )
    glow = glow.filter(ImageFilter.GaussianBlur(radius=40))
    img = Image.alpha_composite(img, glow)

    # Concentric focus rings (camera lens / target aesthetic)
    rings_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    rings_draw = ImageDraw.Draw(rings_layer)

    ring_radii = [300, 240, 180, 120]
    ring_colors = [
        (100, 80, 220, 40),
        (120, 100, 240, 50),
        (140, 120, 255, 55),
        (160, 140, 255, 60),
    ]

    for radius, color in zip(ring_radii, ring_colors):
        # Ring stroke (not filled)
        rings_draw.ellipse(
            [CENTER - radius, CENTER - radius, CENTER + radius, CENTER + radius],
            outline=color,
            width=2,
        )

    # Soft blur on rings
    rings_blur = rings_layer.filter(ImageFilter.GaussianBlur(radius=3))
    img = Image.alpha_composite(img, rings_blur)
    img = Image.alpha_composite(img, rings_layer)

    # Frosted glass disc in center (the "focused" area)
    disc = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    disc_draw = ImageDraw.Draw(disc)

    # Multi-layer frosted disc
    for r in range(160, 0, -1):
        t = r / 160
        alpha = int(45 * (1 - t * t))
        blue = int(180 + 60 * (1 - t))
        purple = int(140 + 80 * (1 - t))
        disc_draw.ellipse(
            [CENTER - r, CENTER - r, CENTER + r, CENTER + r],
            fill=(purple, 130, blue, alpha),
        )

    disc = disc.filter(ImageFilter.GaussianBlur(radius=12))
    img = Image.alpha_composite(img, disc)

    # Bright inner ring (highlight)
    highlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    h_draw = ImageDraw.Draw(highlight)
    h_draw.ellipse(
        [CENTER - 90, CENTER - 90, CENTER + 90, CENTER + 90],
        outline=(200, 190, 255, 100),
        width=2,
    )
    highlight = highlight.filter(ImageFilter.GaussianBlur(radius=2))
    img = Image.alpha_composite(img, highlight)

    # Center bright dot (focal point)
    focal = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    focal_draw = ImageDraw.Draw(focal)
    for r in range(30, 0, -1):
        t = r / 30
        alpha = int(200 * (1 - t))
        focal_draw.ellipse(
            [CENTER - r, CENTER - r, CENTER + r, CENTER + r],
            fill=(220, 210, 255, alpha),
        )
    focal_glow = focal.filter(ImageFilter.GaussianBlur(radius=6))
    img = Image.alpha_composite(img, focal_glow)

    draw = ImageDraw.Draw(img)
    draw.ellipse(
        [CENTER - 6, CENTER - 6, CENTER + 6, CENTER + 6],
        fill=(255, 255, 255, 240),
    )

    # Crosshair lines (subtle, extends from center)
    cross = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    cross_draw = ImageDraw.Draw(cross)
    line_color = (180, 170, 255, 50)

    # Horizontal
    cross_draw.line([(CENTER - 300, CENTER), (CENTER - 40, CENTER)], fill=line_color, width=1)
    cross_draw.line([(CENTER + 40, CENTER), (CENTER + 300, CENTER)], fill=line_color, width=1)
    # Vertical
    cross_draw.line([(CENTER, CENTER - 300), (CENTER, CENTER - 40)], fill=line_color, width=1)
    cross_draw.line([(CENTER, CENTER + 40), (CENTER, CENTER + 300)], fill=line_color, width=1)

    cross_blur = cross.filter(ImageFilter.GaussianBlur(radius=1))
    img = Image.alpha_composite(img, cross_blur)
    img = Image.alpha_composite(img, cross)

    # Small tick marks on crosshairs
    ticks = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ticks_draw = ImageDraw.Draw(ticks)
    tick_color = (180, 170, 255, 60)
    tick_len = 8

    for offset in [-200, -150, -100, 100, 150, 200]:
        # Horizontal ticks
        ticks_draw.line(
            [(CENTER + offset, CENTER - tick_len), (CENTER + offset, CENTER + tick_len)],
            fill=tick_color, width=1,
        )
        # Vertical ticks
        ticks_draw.line(
            [(CENTER - tick_len, CENTER + offset), (CENTER + tick_len, CENTER + offset)],
            fill=tick_color, width=1,
        )

    img = Image.alpha_composite(img, ticks)

    # Sparkle accents (top-right quadrant primarily)
    sparkle_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sparkle_draw = ImageDraw.Draw(sparkle_layer)

    sparkles = [
        (650, 300, 4, 200), (700, 370, 3, 170), (620, 260, 3, 160),
        (340, 290, 3, 150), (380, 680, 3, 140), (680, 600, 2, 130),
        (290, 400, 2, 120), (720, 450, 2, 110),
    ]

    for sx, sy, sr, alpha in sparkles:
        # Four-pointed star
        length = sr * 5
        for angle in [0, math.pi / 2]:
            x1 = sx + math.cos(angle) * length
            y1 = sy + math.sin(angle) * length
            x2 = sx - math.cos(angle) * length
            y2 = sy - math.sin(angle) * length
            sparkle_draw.line([(x1, y1), (x2, y2)], fill=(220, 210, 255, alpha), width=1)
        sparkle_draw.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill=(255, 255, 255, alpha))

    sparkle_glow = sparkle_layer.filter(ImageFilter.GaussianBlur(radius=3))
    img = Image.alpha_composite(img, sparkle_glow)
    img = Image.alpha_composite(img, sparkle_layer)

    # Subtle border
    border = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    border_draw = ImageDraw.Draw(border)
    border_draw.rounded_rectangle(
        [40, 40, SIZE - 40, SIZE - 40],
        radius=200,
        outline=(255, 255, 255, 15),
        width=2,
    )
    img = Image.alpha_composite(img, border)

    # Final mask
    img.putalpha(mask)
    return img


def make_iconset(icon: Image.Image, out_dir: str) -> None:
    """Generate all sizes needed for .icns."""
    import os
    os.makedirs(out_dir, exist_ok=True)

    sizes = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    for filename, size in sizes:
        resized = icon.resize((size, size), Image.LANCZOS)
        resized.save(os.path.join(out_dir, filename))
        print(f"  {filename} ({size}x{size})")


if __name__ == "__main__":
    import os

    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    resources = os.path.join(base, "Sources", "HocusPocus", "Resources")

    print("Generating icon...")
    icon = make_icon()

    png_path = os.path.join(resources, "AppIcon.png")
    icon.save(png_path)
    print(f"Saved {png_path}")

    iconset_dir = os.path.join(base, "build", "AppIcon.iconset")
    print(f"Generating iconset at {iconset_dir}...")
    make_iconset(icon, iconset_dir)

    icns_path = os.path.join(resources, "AppIcon.icns")
    os.system(f'iconutil -c icns -o "{icns_path}" "{iconset_dir}"')
    print(f"Saved {icns_path}")
