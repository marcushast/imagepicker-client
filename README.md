# Deck Image Picker

A Flutter-based image review application optimized for Steam Deck with full gamepad support. Quickly review and categorize images using keyboard shortcuts or controller inputs.

## Features

- 🎮 **Full Gamepad Support** - Native Steam Deck controller support with all buttons mapped
- ⌨️ **Keyboard Shortcuts** - Efficient keyboard-driven workflow
- 💾 **Auto-Save** - Selections automatically saved to JSON files
- 🎨 **Dark Theme** - Easy on the eyes with Material Design 3
- 📁 **Steam Deck Optimized** - Custom subfolder browser and automatic directory detection
- 🖼️ **Multiple Image Formats** - Supports JPG, PNG, GIF, BMP, and WebP
- 🔄 **Quick Navigation** - Jump to unreviewed images instantly

## Gamepad Support

### Supported Controllers

- Steam Deck (built-in controls)
- Xbox controllers
- PlayStation controllers
- Generic gamepads with standard button layouts

### Button Mappings

#### Navigation
- **D-Pad Left/Right** or **Left Stick** → Navigate between images
- **D-Pad Up/Down** or **Left Stick Up/Down** → Mark images without advancing
- **Left Trigger (LT)** → Previous image
- **Right Trigger (RT)** → Next image

#### Actions
- **A Button** → Pick image and advance
- **B Button** → Reject image and advance
- **X Button** → Clear status
- **Y Button** → Show help

#### Quick Navigation
- **Left Bumper (LB)** → Jump to first unreviewed image
- **Right Bumper (RB)** → Jump to next unreviewed image

#### Menu
- **Select** → Show menu (Open folder picker or exit)
- **Start** → Show help
- **Hold Select + Start (0.5s)** → Exit app

#### Steam Deck Back Buttons (L4/L5/R4/R5)
Back buttons require Steam Input configuration (see [steam-input-config/](steam-input-config/)):
- **L4** → Pick and advance
- **L5** → Pick without advancing
- **R4** → Reject and advance
- **R5** → Reject without advancing

### Gamepad Indicator
When a gamepad is connected, a controller icon (🎮) appears in the top-right corner of the app.

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `←` / `→` | Navigate between images |
| `↑` | Mark as Pick (stay on image) |
| `↓` | Mark as Reject (stay on image) |
| `P` | Mark as Pick and advance |
| `X` | Mark as Reject and advance |
| `C` | Clear status |
| `M` | Show menu |
| `H` | Show help |
| `Y` | Toggle fullscreen mode |
| `ESC` / `Q` | Exit application |

## Installation

### Steam Deck

See [STEAMDECK.md](STEAMDECK.md) for detailed Steam Deck build and deployment instructions.

Quick steps:
1. Build on Linux: `flutter build linux --release`
2. Copy `build/linux/x64/release/bundle/` to Steam Deck
3. Make executable: `chmod +x image_picker`
4. (Optional) Add to Steam as Non-Steam Game for back button support

### Desktop Linux

Requirements:
- Flutter SDK
- GTK3 development libraries
- CMake, Ninja, Clang

```bash
# Install dependencies (Ubuntu/Debian)
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev

# Get Flutter dependencies
flutter pub get

# Run the app
flutter run -d linux

# Or build a release version
flutter build linux --release
```

## Usage

1. Launch the application
2. Select a folder containing images
3. Review images using keyboard or gamepad:
   - Navigate with arrow keys or D-pad/stick
   - Mark images as "Pick" (green) or "Reject" (red)
   - Use quick navigation to jump to unreviewed images
4. Selections are automatically saved to `.deck-selections.json` in the image folder
5. Press ESC/Q or hold Select+Start to exit

## Project Structure

```
lib/
├── main.dart                           # App entry point
├── models/
│   ├── image_item.dart                 # Image data model
│   └── folder_info.dart                # Folder metadata
├── screens/
│   ├── image_picker_screen.dart        # Main review screen
│   └── subfolder_picker_screen.dart    # Steam Deck folder browser
└── services/
    ├── gamepad_service.dart            # Gamepad input handling
    ├── selection_persistence_service.dart  # Save/load selections
    └── app_config_service.dart         # Platform-specific config

steam-input-config/
├── deck-imagepicker.vdf                # Steam Input configuration
└── README.md                           # Import instructions
```

## Technical Details

### Dependencies

- `flutter` - Cross-platform UI framework
- `file_picker` - Native file/folder picker
- `path` - Path manipulation utilities
- `gamepads` - Cross-platform gamepad support

### Gamepad Implementation

The application uses the `gamepads` plugin for native controller support with:
- Event-driven input handling (no polling)
- 100ms debouncing to prevent double-triggers
- 0.5 analog threshold for triggers
- 0.2 dead zone for analog sticks
- Button combination support (Select + Start to exit)

Steam Deck back buttons (L4/L5/R4/R5) are not accessible through standard gamepad APIs and require Steam Input configuration.

## Development

```bash
# Run in debug mode
flutter run -d linux

# Run tests
flutter test

# Analyze code
flutter analyze

# Format code
flutter format lib/
```

## Contributing

Contributions are welcome! Areas for improvement:
- Additional gamepad profiles
- Haptic feedback support
- Image zoom/pan functionality
- Batch operations
- Custom keyboard shortcuts

## License

This project is provided as-is for personal use.

## Acknowledgments

- Built with [Flutter](https://flutter.dev/)
- Gamepad support via [gamepads](https://pub.dev/packages/gamepads) by flame-engine
- Optimized for [Steam Deck](https://www.steamdeck.com/)
