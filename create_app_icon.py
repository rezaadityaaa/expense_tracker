#!/usr/bin/env python3
"""
Script to create app icon PNG from SVG-like design using Python PIL
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_app_icon():
    # Create 1024x1024 image for high resolution
    size = (1024, 1024)
    
    # Create image with green background
    img = Image.new('RGBA', size, '#4CAF50')
    draw = ImageDraw.Draw(img)
    
    # Draw rounded rectangle background
    margin = 64
    draw.rounded_rectangle(
        [(margin, margin), (size[0] - margin, size[1] - margin)],
        radius=64,
        fill='#4CAF50'
    )
    
    # Draw wallet body (white background)
    wallet_x = size[0] // 2
    wallet_y = size[1] // 2
    wallet_width = 240
    wallet_height = 120
    
    # Main wallet rectangle
    wallet_rect = [
        (wallet_x - wallet_width//2, wallet_y - wallet_height//2),
        (wallet_x + wallet_width//2, wallet_y + wallet_height//2)
    ]
    draw.rounded_rectangle(wallet_rect, radius=20, fill='white')
    
    # Inner wallet rectangle (green)
    inner_margin = 10
    inner_rect = [
        (wallet_x - wallet_width//2 + inner_margin, wallet_y - wallet_height//2 + inner_margin),
        (wallet_x + wallet_width//2 - inner_margin, wallet_y + wallet_height//2 - inner_margin)
    ]
    draw.rounded_rectangle(inner_rect, radius=15, fill='#2E7D32')
    
    # Wallet opening line
    opening_y = wallet_y - 30
    draw.rounded_rectangle(
        [(wallet_x - 100, opening_y), (wallet_x + 100, opening_y + 10)],
        radius=5,
        fill='white'
    )
    
    # Try to add dollar sign
    try:
        # Try to use a system font
        font_size = 96
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", font_size)
        except:
            try:
                font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", font_size)
            except:
                font = ImageFont.load_default()
        
        # Draw dollar sign
        text = "$"
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        
        text_x = wallet_x - text_width // 2
        text_y = wallet_y - text_height // 2 + 15
        
        draw.text((text_x, text_y), text, fill='white', font=font)
        
    except Exception as e:
        print(f"Could not add text: {e}")
        # Draw simple circle as fallback
        circle_radius = 30
        draw.ellipse(
            [(wallet_x - circle_radius, wallet_y - circle_radius + 15),
             (wallet_x + circle_radius, wallet_y + circle_radius + 15)],
            fill='white'
        )
    
    return img

def main():
    # Create the icon
    icon = create_app_icon()
    
    # Save as PNG
    icon_path = "assets/icons/app_icon.png"
    os.makedirs(os.path.dirname(icon_path), exist_ok=True)
    icon.save(icon_path, "PNG", quality=100)
    print(f"Created app icon: {icon_path}")
    
    # Create foreground version (just the wallet without background)
    foreground = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))  # Transparent background
    draw = ImageDraw.Draw(foreground)
    
    # Draw wallet for adaptive icon foreground
    wallet_x = 512
    wallet_y = 512
    wallet_width = 300
    wallet_height = 150
    
    # Main wallet rectangle
    wallet_rect = [
        (wallet_x - wallet_width//2, wallet_y - wallet_height//2),
        (wallet_x + wallet_width//2, wallet_y + wallet_height//2)
    ]
    draw.rounded_rectangle(wallet_rect, radius=25, fill='white')
    
    # Inner wallet rectangle
    inner_margin = 15
    inner_rect = [
        (wallet_x - wallet_width//2 + inner_margin, wallet_y - wallet_height//2 + inner_margin),
        (wallet_x + wallet_width//2 - inner_margin, wallet_y + wallet_height//2 - inner_margin)
    ]
    draw.rounded_rectangle(inner_rect, radius=20, fill='#2E7D32')
    
    # Wallet opening
    opening_y = wallet_y - 40
    draw.rounded_rectangle(
        [(wallet_x - 120, opening_y), (wallet_x + 120, opening_y + 12)],
        radius=6,
        fill='white'
    )
    
    # Dollar sign
    try:
        font_size = 120
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", font_size)
        except:
            font = ImageFont.load_default()
        
        text = "$"
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        
        text_x = wallet_x - text_width // 2
        text_y = wallet_y - text_height // 2 + 20
        
        draw.text((text_x, text_y), text, fill='white', font=font)
        
    except:
        # Fallback circle
        circle_radius = 40
        draw.ellipse(
            [(wallet_x - circle_radius, wallet_y - circle_radius + 20),
             (wallet_x + circle_radius, wallet_y + circle_radius + 20)],
            fill='white'
        )
    
    # Save foreground
    foreground_path = "assets/icons/app_icon_foreground.png"
    foreground.save(foreground_path, "PNG")
    print(f"Created foreground icon: {foreground_path}")

if __name__ == "__main__":
    main()
