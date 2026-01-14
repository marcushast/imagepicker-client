# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Deck Image Picker is a Flutter application for rapid image review and categorization, optimized for Steam Deck with full gamepad support. Users can mark images as "Pick" (green), "Reject" (red), or group them together with markers. Selections persist to JSON files in the image directory.

## Build and Development Commands

```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run -d linux

# Build release for Linux/Steam Deck
flutter build linux --release

# Run tests
flutter test

# Analyze code
flutter analyze

# Format code
flutter format lib/
```

## Architecture

### Core Structure
```
lib/
├── main.dart                           # App entry with Material 3 dark theme
├── models/
│   ├── image_item.dart                 # Image data + status enum (none/pick/reject) + isNewGroup flag
│   └── folder_info.dart                # Folder metadata for subfolder picker
├── screens/
│   ├── image_picker_screen.dart        # Main review UI with keyboard/gamepad handling
│   └── subfolder_picker_screen.dart    # Steam Deck folder browser (2-column grid)
├── services/
│   ├── gamepad_service.dart            # Controller input with debouncing (100ms)
│   ├── selection_persistence_service.dart  # JSON save/load to .deck-selections.json
│   ├── app_config_service.dart         # Platform-specific directory detection
│   └── image_cache_service.dart        # Preload ±2 adjacent images
└── widgets/
    └── cached_image_widget.dart        # Cached image display
```

### Key Patterns
- **MVC-lite**: Models in `/models`, views in `/screens`, services handle business logic
- **State Management**: Simple `setState()` - no external state libraries needed
- **Event-Driven Gamepad**: Callbacks from `GamepadService` trigger UI actions

### GamepadService Callbacks
The gamepad service communicates with screens via callbacks:
- Navigation: `onPreviousImage`, `onNextImage`, `onNavigateUp/Down/Left/Right`
- Actions: `onPickImage`, `onRejectImage`, `onAddGroupMarker`, `onPickWithoutAdvance`, `onRejectWithoutAdvance`
- System: `onShowMenu`, `onShowHelp`, `onExitApp`, `onOpenFolderPicker`
- Quick Jump: `onJumpToFirstUnreviewed`, `onJumpToNextUnreviewed`

### Important Technical Details
- Steam Deck D-pad reports as axes 6/7 with large values (~±32767)
- Analog thresholds: 0.5 for triggers, 0.2 dead zone for sticks
- Back buttons (L4/L5/R4/R5) require Steam Input config, not accessible via standard APIs
- Selections saved to `.deck-selections.json` in the image directory

## Input Mappings

### Keyboard
- Arrow keys: Navigate (←/→), mark without advancing (↑=pick, ↓=reject)
- P/X: Pick/Reject and advance
- C: Clear status
- M: Menu, H: Help, Y: Fullscreen
- ESC: Close dialog if open, otherwise exit

### Gamepad
- D-Pad/Left Stick: Navigate images, D-pad Down toggles group marker
- A/B: Pick/Reject and advance
- X: Clear, Y: Fullscreen
- LB/RB: Jump to first/next unreviewed
- Select: Menu, Start: Help
- Select+Start (hold 0.5s): Exit

## Steam Deck Deployment

Build on Linux, transfer the `build/linux/x64/release/bundle/` directory to Steam Deck. The entire bundle must stay together. Make executable with `chmod +x image_picker`. For back button support, add as Non-Steam Game and import `steam-input-config/deck-imagepicker.vdf`.
