# Build Deck Image Picker for Steam Deck

## Overview
Build the Flutter-based Deck Image Picker application to run natively on Steam Deck in Desktop Mode. Steam Deck runs SteamOS 3.0 (based on Arch Linux), so we'll build a standard Linux desktop application that can be transferred and run directly.

## Prerequisites Setup

### On Your Linux Desktop

1. **Install Flutter SDK for Linux**
   - Download Flutter SDK: `https://docs.flutter.dev/get-started/install/linux`
   - Extract to a permanent location (e.g., `~/development/flutter`)
   - Add to PATH: `export PATH="$PATH:$HOME/development/flutter/bin"`
   - Run `flutter doctor` to verify installation

2. **Install Required Linux Development Tools**
   ```bash
   # For Ubuntu/Debian-based systems:
   sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev

   # For Arch-based systems (similar to Steam Deck):
   sudo pacman -S clang cmake ninja pkgconf gtk3
   ```

3. **Enable Flutter Linux Desktop Support**
   ```bash
   flutter config --enable-linux-desktop
   ```

4. **Verify Setup**
   ```bash
   flutter doctor -v
   # Should show Linux toolchain and GTK+ libraries as available
   ```

## Build Process

### Step 1: Prepare the Project
Navigate to the project directory and get dependencies:
```bash
cd /path/to/deck-imagepicker/image_picker
flutter pub get
flutter analyze  # Verify no issues
```

### Step 2: Build for Linux
Create a release build optimized for production:
```bash
flutter build linux --release
```

This creates a self-contained application bundle at:
`build/linux/x64/release/bundle/`

### Step 3: Understand the Build Output
The bundle directory contains:
- `image_picker` - Main executable binary
- `lib/` - Shared libraries and Flutter engine
- `data/` - Application assets (images, fonts, etc.)

**Important**: The entire `bundle/` directory must be kept together as a unit.

## Deployment to Steam Deck

### Option 1: Direct Transfer (Recommended for Testing)

1. **Enable SSH on Steam Deck** (in Desktop Mode):
   ```bash
   # On Steam Deck, open Konsole terminal
   passwd  # Set a password for 'deck' user
   sudo systemctl enable sshd
   sudo systemctl start sshd
   ip addr  # Note the IP address
   ```

2. **Transfer from Linux Desktop**:
   ```bash
   # Create a directory structure
   scp -r build/linux/x64/release/bundle/ deck@<steam-deck-ip>:~/Applications/DeckImagePicker/
   ```

3. **Make Executable on Steam Deck**:
   ```bash
   ssh deck@<steam-deck-ip>
   chmod +x ~/Applications/DeckImagePicker/image_picker
   ```

### Option 2: USB Drive Transfer

1. **Copy build to USB drive on Linux desktop**:
   ```bash
   cp -r build/linux/x64/release/bundle /media/usb-drive/DeckImagePicker
   ```

2. **On Steam Deck** (Desktop Mode):
   - Insert USB drive
   - Open Dolphin file manager
   - Copy `DeckImagePicker` folder to `~/Applications/` or `~/Games/`
   - Right-click the `image_picker` executable → Properties → Permissions → Check "Is executable"

## Running the Application

### In Desktop Mode

1. **Via File Manager**:
   - Navigate to `~/Applications/DeckImagePicker/`
   - Double-click `image_picker` executable

2. **Via Terminal**:
   ```bash
   cd ~/Applications/DeckImagePicker
   ./image_picker
   ```

3. **Create Desktop Shortcut** (Optional):
   - Right-click desktop → Create New → Link to Application
   - Name: "Deck Image Picker"
   - Command: `/home/deck/Applications/DeckImagePicker/image_picker`
   - Working Directory: `/home/deck/Applications/DeckImagePicker`
   - Add a custom icon if desired

### In Gaming Mode (Recommended)

The Deck Image Picker has full native Steam Deck controller support! For the best experience, launch it through Steam:

1. **Add as Non-Steam Game**:
   - In Desktop Mode, open Steam
   - Games → Add a Non-Steam Game to My Library
   - Browse to `~/Applications/DeckImagePicker/image_picker`
   - Add it to library

2. **Configure Launch Options**:
   - Right-click game → Properties → General
   - Launch Options: (leave empty)
   - Start In: `/home/deck/Applications/DeckImagePicker`

3. **Import Controller Configuration (for back buttons)**:
   - Right-click game → Properties → Controller → Edit Layout
   - Click settings icon (⚙️) → Browse Configs → Import Config
   - Navigate to: `steam-input-config/deck-imagepicker.vdf`
   - Import and apply the configuration

   This maps the back buttons (L4/L5/R4/R5) to quick review actions.

## Native Gamepad Controls

The application has full native controller support with these default mappings:

### Navigation
- **D-Pad** or **Left Stick** → Navigate between images (Left/Right) and mark images (Up/Down)
- **Left Trigger (LT)** → Previous image
- **Right Trigger (RT)** → Next image

### Actions
- **A Button** → Pick image and advance to next
- **B Button** → Reject image and advance to next
- **X Button** → Clear image status
- **Y Button** → Show help dialog

### Quick Navigation
- **Left Bumper (LB)** → Jump to first unreviewed image
- **Right Bumper (RB)** → Jump to next unreviewed image

### Menu
- **Select Button** → Show menu (Open folder picker or exit)
- **Start Button** → Show help dialog
- **Hold Select + Start (0.5s)** → Exit application

### Back Buttons (with Steam Input config)
- **L4** → Pick and advance (same as P key)
- **L5** → Pick without advancing (same as Up arrow)
- **R4** → Reject and advance (same as X key)
- **R5** → Reject without advancing (same as Down arrow)

### Visual Indicators
When a gamepad is connected, you'll see a gamepad icon (🎮) in the top-right corner of the app.

## Controller Configuration Details

### Standard Buttons (Work Automatically)
All standard gamepad buttons work natively without any configuration:
- Face buttons (A/B/X/Y)
- D-Pad
- Left and right sticks
- Triggers (LT/RT)
- Bumpers (LB/RB)
- Select and Start

### Back Buttons (Require Steam Input)
The Steam Deck's back buttons (L4/L5/R4/R5) are not accessible through standard gamepad APIs and require Steam Input configuration. See the `steam-input-config/` directory for the configuration file and detailed import instructions.

## Testing and Validation

### On Linux Desktop (Before Transfer)
```bash
# Run in debug mode to catch any issues
flutter run -d linux

# Test the release build locally
cd build/linux/x64/release/bundle
./image_picker
```

### On Steam Deck
1. Test file picker functionality (folder selection)
2. Verify keyboard shortcuts work
3. Check image rendering and navigation
4. Confirm persistence (`.deck-selections.json` creation)
5. Test with various image formats (jpg, png, webp, etc.)

## Troubleshooting

### Missing Libraries Error
If you see "error while loading shared libraries":
```bash
# On Steam Deck, install missing GTK dependencies
sudo pacman -S gtk3
```

### Permission Issues
```bash
chmod +x ~/Applications/DeckImagePicker/image_picker
```

### Display Scaling Issues
Steam Deck's native resolution is 1280x800. The app should adapt automatically, but if UI is too small/large:
- Use KDE's Display Settings in Desktop Mode to adjust scaling
- Flutter's Material Design should handle this gracefully

### File Picker Not Opening
Ensure GTK file picker dependencies are installed:
```bash
sudo pacman -S zenity
```

### Gamepad Not Detected
If the gamepad icon doesn't appear in the app:
1. Make sure you're running the latest version of the app
2. Try disconnecting and reconnecting the controller
3. Check if the controller works in other applications
4. In Desktop Mode, the built-in Steam Deck controls may not be detected - this is normal; launch through Steam for full support

### Back Buttons Not Working
If L4/L5/R4/R5 don't trigger actions:
1. Make sure you've imported the Steam Input configuration (see above)
2. Verify you're launching the app through Steam (as a Non-Steam Game)
3. Back buttons only work when Steam Input is active
4. You can customize the mappings in Steam's controller configuration UI

### Controller Input Lag or Double-Presses
If buttons feel unresponsive or trigger twice:
1. This shouldn't happen with the built-in debouncing (100ms)
2. Make sure you're running on the latest app version
3. Try restarting the application
4. Check if Steam Input and native gamepad support are conflicting (shouldn't happen, but worth checking)

## Critical Files

### Build Configuration
- `image_picker/linux/CMakeLists.txt` - Linux build configuration
- `image_picker/pubspec.yaml` - Dependencies manifest
- `image_picker/lib/main.dart` - Application entry point

### Application Logic
- `image_picker/lib/screens/image_picker_screen.dart` - Main UI with keyboard handling
- `image_picker/lib/models/image_item.dart` - Image data model
- `image_picker/lib/services/selection_persistence_service.dart` - Save/load functionality

## Future Enhancements (Optional)

1. **Flatpak Package**: Create a proper Flatpak for Discover store distribution
2. **AppImage**: Single-file executable for easier distribution
3. **Gamepad UI Mode**: Native controller support without Steam Input mapping
4. **Steam Deck Optimizations**: Resolution-specific UI adjustments for 1280x800 display

## Summary

**Simplest Path**:
1. Build on Linux desktop: `flutter build linux --release`
2. Copy `build/linux/x64/release/bundle/` to Steam Deck via USB or SSH
3. Make executable: `chmod +x image_picker`
4. Run from Desktop Mode

The application is already well-suited for Steam Deck with its keyboard-driven workflow and dark theme. No code changes are required - just build and deploy!
