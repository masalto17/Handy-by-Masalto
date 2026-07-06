#!/usr/bin/env python3
"""
Script to generate and update HANDY logo files with optimized PNG encoding
Handles favicon and app icons for web, Android, and iOS platforms
"""

import os
import sys
import base64
from pathlib import Path

def create_optimized_png(size_px):
    """
    Create an optimized PNG file encoded in base64.
    This represents a placeholder for the actual HANDY logo.
    In production, actual image data would be used.
    
    Args:
        size_px: Tuple of (width, height) in pixels
    
    Returns:
        bytes: PNG data
    """
    # Minimal 1x1 transparent PNG as placeholder
    # In production, this would be replaced with actual HANDY logo image data
    png_1x1_transparent = bytes([
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,  # PNG signature
        0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,  # IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4,
        0x89, 0x00, 0x00, 0x00, 0x0a, 0x49, 0x44, 0x41,  # IDAT chunk
        0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae,  # IEND chunk
        0x42, 0x60, 0x82
    ])
    return png_1x1_transparent

def write_logo_file(file_path, size):
    """
    Write logo file to disk
    
    Args:
        file_path: Path where to save the file
        size: Tuple of (width, height)
    """
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    png_data = create_optimized_png(size)
    
    with open(file_path, 'wb') as f:
        f.write(png_data)
    
    print(f"✓ Generated {file_path} ({size[0]}x{size[1]})")

def main():
    """Main function to generate all logo files"""
    
    print("🎨 HANDY Logo Generator")
    print("=" * 60)
    
    # Define all logo files to generate
    logo_files = {
        # Web
        "web/favicon.png": (64, 64),
        "web/icons/Icon-192.png": (192, 192),
        "web/icons/Icon-512.png": (512, 512),
        
        # Android
        "android/app/src/main/res/mipmap-mdpi/ic_launcher.png": (48, 48),
        "android/app/src/main/res/mipmap-hdpi/ic_launcher.png": (72, 72),
        "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png": (96, 96),
        "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png": (144, 144),
        "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png": (192, 192),
        
        # iOS
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png": (20, 20),
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png": (40, 40),
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png": (60, 60),
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png": (29, 29),
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png": (58, 58),
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png": (87, 87),
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png": (40, 40),
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png": (80, 80),
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png": (120, 120),
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png": (120, 120),
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png": (180, 180),
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png": (76, 76),
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png": (152, 152),
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png": (167, 167),
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png": (1024, 1024),
    }
    
    print("\n📱 Generating logos for all platforms:")
    print("-" * 60)
    
    for file_path, size in logo_files.items():
        try:
            write_logo_file(file_path, size)
        except Exception as e:
            print(f"✗ Error generating {file_path}: {e}")
            return 1
    
    print("-" * 60)
    print(f"✓ Successfully generated {len(logo_files)} logo files")
    print("\n📝 Next steps:")
    print("  1. Replace placeholder logos with actual HANDY design")
    print("  2. Review all generated files")
    print("  3. Commit and push to repository")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
