#!/usr/bin/env python3
"""Generate the Hocus Pocus app icon - frosted glass magic wand aesthetic."""

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import math
import random

SIZE = 1024
CENTER = SIZE // 2
random.seed(42)


def make_icon() -> Image.Image:
    # Base: dark background with macOS super-ellipse shape
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # macOS-style rounded rect background
    bg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg)
    bg_draw.rounded_rectangle(
        [40, 40, SIZE - 40, SIZE - 40],
        radius=200,
        fill=(18, 14, 32, 255),
    )

    # Gradient overlay: deep purple to dark blue
    gradient = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    for y in range(SIZE):
        t = y / SIZE
        r = int(18 + t * 12)
        g = int(14 + t * 8)
        b = int(32 + t * 28)
        for x in range(SIZE):
            gradient.putpixel((x, y), (r, g, b, 255))
    bg.paste(Image.composite(gradient, bg, bg), (0, 0))

    # Re-mask to rounded rect
    mask = Image.new("L", (SIZE, SIZE), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([40, 40, SIZE - 40, SIZE - 40], radius=200, fill=255)
    bg.putalpha(mask)

    img = bg.copy()
    draw = ImageDraw.Draw(img)

    # Frosted glass circles (layered, translucent)
    glass_circles = [
        (420, 380, 280, (80, 60, 180, 35)),   # large purple
        (580, 520, 220, (40, 80, 200, 30)),    # medium blue
        (350, 550, 180, (100, 50, 160, 25)),   # small purple
        (620, 350, 150, (50, 100, 220, 28)),   # small blue
        (480, 460, 320, (70, 70, 190, 20)),    # extra large subtle
    ]

    for cx, cy, radius, color in glass_circles:
        circle_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        circle_draw = ImageDraw.Draw(circle_layer)
        circle_draw.ellipse(
            [cx - radius, cy - radius, cx + radius, cy + radius],
            fill=color,
        )
        # Blur for frosted effect
        circle_layer = circle_layer.filter(ImageFilter.GaussianBlur(radius=40))
        img = Image.alpha_composite(img, circle_layer)

    # Central glow
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    for r in range(200, 0, -2):
        alpha = int(40 * (1 - r / 200))
        glow_draw.ellipse(
            [CENTER - r, CENTER - r + 20, CENTER + r, CENTER + r + 20],
            fill=(120, 100, 255, alpha),
        )
    glow = glow.filter(ImageFilter.GaussianBlur(radius=30))
    img = Image.alpha_composite(img, glow)

    # Magic wand
    draw = ImageDraw.Draw(img)
    wand_start = (340, 700)
    wand_end = (650, 320)

    # Wand body (thick line with gradient feel)
    for offset in range(-6, 7):
        t = abs(offset) / 6
        alpha = int(255 * (1 - t * 0.6))
        r = int(200 + 55 * (1 - t))
        g = int(180 + 55 * (1 - t))
        b = int(220 + 35 * (1 - t))
        draw.line(
            [(wand_start[0] + offset, wand_start[1]),
             (wand_end[0] + offset, wand_end[1])],
            fill=(r, g, b, alpha),
            width=2,
        )

    # Wand tip glow
    tip_glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    tip_draw = ImageDraw.Draw(tip_glow)
    for r in range(80, 0, -1):
        alpha = int(120 * (1 - r / 80))
        tip_draw.ellipse(
            [wand_end[0] - r, wand_end[1] - r,
             wand_end[0] + r, wand_end[1] + r],
            fill=(180, 160, 255, alpha),
        )
    tip_glow = tip_glow.filter(ImageFilter.GaussianBlur(radius=15))
    img = Image.alpha_composite(img, tip_glow)

    # Bright tip point
    draw = ImageDraw.Draw(img)
    draw.ellipse(
        [wand_end[0] - 8, wand_end[1] - 8,
         wand_end[0] + 8, wand_end[1] + 8],
        fill=(255, 255, 255, 240),
    )

    # Sparkles around the wand tip
    sparkles = [
        (610, 280, 4, (255, 255, 255, 220)),
        (690, 340, 3, (200, 180, 255, 200)),
        (680, 270, 5, (180, 160, 255, 180)),
        (720, 310, 3, (220, 200, 255, 190)),
        (640, 250, 3, (255, 240, 255, 170)),
        (580, 270, 4, (200, 200, 255, 200)),
        (700, 380, 3, (180, 170, 255, 160)),
        (660, 230, 2, (255, 255, 255, 150)),
        (740, 350, 2, (200, 190, 255, 140)),
        (600, 350, 3, (220, 210, 255, 180)),
    ]

    sparkle_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sparkle_draw = ImageDraw.Draw(sparkle_layer)

    for sx, sy, sr, color in sparkles:
        # Four-pointed star
        for angle in [0, math.pi / 2]:
            length = sr * 4
            x1 = sx + math.cos(angle) * length
            y1 = sy + math.sin(angle) * length
            x2 = sx - math.cos(angle) * length
            y2 = sy - math.sin(angle) * length
            sparkle_draw.line([(x1, y1), (x2, y2)], fill=color, width=1)

        # Center dot
        sparkle_draw.ellipse(
            [sx - sr, sy - sr, sx + sr, sy + sr],
            fill=color,
        )

    # Soft glow on sparkles
    sparkle_glow = sparkle_layer.filter(ImageFilter.GaussianBlur(radius=4))
    img = Image.alpha_composite(img, sparkle_glow)
    img = Image.alpha_composite(img, sparkle_layer)

    # Subtle inner border on the icon shape
    border = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    border_draw = ImageDraw.Draw(border)
    border_draw.rounded_rectangle(
        [40, 40, SIZE - 40, SIZE - 40],
        radius=200,
        outline=(255, 255, 255, 20),
        width=3,
    )
    img = Image.alpha_composite(img, border)

    # Re-apply mask for clean edges
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
    resources = os.path.join(base, "Sources", "AutoFocus", "Resources")

    print("Generating icon...")
    icon = make_icon()

    # Save 1024 PNG
    png_path = os.path.join(resources, "AppIcon.png")
    icon.save(png_path)
    print(f"Saved {png_path}")

    # Generate iconset
    iconset_dir = os.path.join(base, "build", "AppIcon.iconset")
    print(f"Generating iconset at {iconset_dir}...")
    make_iconset(icon, iconset_dir)

    # Convert to .icns
    icns_path = os.path.join(resources, "AppIcon.icns")
    os.system(f'iconutil -c icns -o "{icns_path}" "{iconset_dir}"')
    print(f"Saved {icns_path}")
