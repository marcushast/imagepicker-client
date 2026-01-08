# Deck Image Picker - Design Document

## Project Overview

**Deck Image Picker** is a cross-platform image review and sorting application built with Flutter. It provides a streamlined interface for rapidly browsing through image collections and categorizing them into three states: picked, rejected, or unreviewed. The application emphasizes keyboard-driven workflows for maximum efficiency.

## Technology Stack

### Core Framework
- **Flutter SDK**: ^3.10.4
- **Language**: Dart
- **UI Framework**: Material Design 3 with dark theme optimization

### Platform Support
- Android
- iOS
- macOS
- Windows
- Linux
- Web (PWA-compatible)

### Key Dependencies
- `file_picker: ^8.1.6` - Native file/folder selection dialogs
- `path: ^1.9.1` - Cross-platform path manipulation
- `cupertino_icons: ^1.0.8` - iOS-style iconography
- `flutter_lints: ^6.0.0` - Code quality enforcement

## Architecture

### Application Structure

```
┌─────────────────────────────────────────┐
│          Application Entry              │
│            (main.dart)                   │
│  ┌───────────────────────────────────┐  │
│  │     Material App + Theme          │  │
│  │     - Dark Theme (MD3)            │  │
│  │     - Deep Purple Seed Color      │  │
│  └───────────────────────────────────┘  │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│      ImagePickerScreen (Stateful)       │
│  ┌───────────────────────────────────┐  │
│  │         State Variables           │  │
│  │  - _images: List<ImageItem>       │  │
│  │  - _currentIndex: int             │  │
│  │  - _isLoading: bool               │  │
│  └───────────────────────────────────┘  │
│                                          │
│  ┌───────────────────────────────────┐  │
│  │         UI Components             │  │
│  │  - AppBar (title, counter)        │  │
│  │  - Image Display                  │  │
│  │  - Status Bar                     │  │
│  │  - Navigation Controls            │  │
│  │  - Action Buttons                 │  │
│  │  - Statistics Display             │  │
│  └───────────────────────────────────┘  │
│                                          │
│  ┌───────────────────────────────────┐  │
│  │      Keyboard Handler             │  │
│  │  - Arrow Keys (navigation)        │  │
│  │  - P, X, C (actions)              │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│         ImageItem Model                 │
│  ┌───────────────────────────────────┐  │
│  │   Properties                      │  │
│  │   - file: File                    │  │
│  │   - status: ImageStatus           │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │   ImageStatus Enum                │  │
│  │   - none, pick, reject            │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### Design Patterns

1. **MVC-lite Pattern**
   - **Model**: [ImageItem](lib/models/image_item.dart) - Data representation
   - **View**: UI widgets in [ImagePickerScreen](lib/screens/image_picker_screen.dart)
   - **Controller**: State management methods within ImagePickerScreen

2. **State Pattern**
   - `ImageStatus` enum defines three distinct states
   - State transitions via user actions (pick/reject/clear)

3. **Builder Pattern**
   - Modular UI construction with helper methods:
     - `_buildEmptyState()`
     - `_buildImageView()`
     - `_buildStatusBar()`
     - `_buildNavigationBar()`

4. **Observer Pattern**
   - Flutter's `setState()` for reactive UI updates
   - Single source of truth in widget state

## Core Components

### 1. ImageItem Model ([lib/models/image_item.dart](lib/models/image_item.dart))

**Purpose**: Encapsulates image file data with review status

**Properties**:
- `File file` - Reference to physical image file
- `ImageStatus status` - Current review state (none/pick/reject)

**Methods**:
- `String get fileName` - Extracts filename from path
- `String get filePath` - Returns absolute file path

**Design Rationale**: Immutable-friendly structure with minimal overhead. Could be converted to immutable class with copyWith pattern if needed.

### 2. ImagePickerScreen ([lib/screens/image_picker_screen.dart](lib/screens/image_picker_screen.dart))

**Purpose**: Main application interface handling all user interactions

**State Management**:
```dart
List<ImageItem> _images = []      // Image collection
int _currentIndex = 0              // Current view index
bool _isLoading = false            // Loading indicator
```

**Key Methods**:

| Method | Responsibility |
|--------|----------------|
| `_pickFolder()` | Opens native folder picker, loads images |
| `_loadImagesFromDirectory()` | Recursively scans directory for supported formats |
| `_updateStatus()` | Updates current image status, triggers rebuild |
| `_previousImage()` | Navigate to previous image (with wraparound) |
| `_nextImage()` | Navigate to next image (with wraparound) |
| `_handleKeyPress()` | Processes keyboard shortcuts |

**UI Layout Hierarchy**:
```
Scaffold
├── AppBar
│   └── Title + Counter (current/total)
├── Body (KeyboardListener)
│   ├── Empty State (no images loaded)
│   │   ├── Icon
│   │   ├── Message
│   │   └── Select Folder Button
│   └── Image View (images loaded)
│       ├── Image Display (BoxFit.contain)
│       ├── Status Bar (color-coded)
│       └── Navigation Bar
│           ├── Previous Button
│           ├── Action Buttons (Pick/Reject/Clear)
│           ├── Next Button
│           └── Statistics Display
└── FloatingActionButton (Help Dialog)
```

## User Interface Design

### Color Coding System

| Status | Color | Semantic Meaning |
|--------|-------|------------------|
| PICKED | Green (`Colors.green`) | Approved/Selected |
| REJECTED | Red (`Colors.red`) | Declined/Removed |
| NO STATUS | Grey (`Colors.grey`) | Pending Review |

### Keyboard Shortcuts

| Key | Action | Description |
|-----|--------|-------------|
| ← / → | Navigate | Previous/Next image |
| P | Pick | Mark current image as selected |
| X | Reject | Mark current image as rejected |
| C | Clear | Remove status from current image |

### Theme Configuration

**Dark Theme Optimized**:
- Reduces eye strain during extended review sessions
- Material Design 3 components with Deep Purple seed color
- High contrast for status indicators

## Functional Workflows

### 1. Folder Selection Workflow

```
User clicks "Select Folder"
    ↓
Native folder picker opens (via file_picker package)
    ↓
User selects directory
    ↓
_loadImagesFromDirectory() executes
    ↓
Recursive directory scan for supported formats
    ↓
Files sorted by path
    ↓
ImageItem objects created with status: none
    ↓
UI rebuilds with first image displayed
```

**Supported Image Formats**:
- `.jpg`, `.jpeg`
- `.png`
- `.gif`
- `.bmp`
- `.webp`

### 2. Image Review Workflow

```
User navigates through images (arrow keys or buttons)
    ↓
Current image displayed with status bar
    ↓
User makes decision:
    - Press P → Status: PICKED (green)
    - Press X → Status: REJECTED (red)
    - Press C → Status: NO STATUS (grey)
    ↓
Statistics update in real-time
    ↓
Continue to next image
```

### 3. Statistics Tracking

Real-time computation on each render:
- **Picked**: Count of `ImageStatus.pick`
- **Rejected**: Count of `ImageStatus.reject`
- **Unreviewed**: Count of `ImageStatus.none`

**Implementation**: Direct list iteration with `where()` clauses - efficient for typical image collection sizes (< 10,000 images).

## Technical Considerations

### State Management Choice

**Current Implementation**: Simple `setState()` pattern

**Rationale**:
- Application state is localized to single screen
- No complex state sharing between widgets
- Minimal performance overhead for typical use cases
- Reduces dependency footprint

**Future Considerations**:
- For export functionality or multi-screen navigation: Consider Provider or Riverpod
- For undo/redo: Consider state management with history tracking

### Image Loading Strategy

**Current**: Synchronous file-based loading via `Image.file()`

**Characteristics**:
- Flutter automatically handles caching
- Lazy loading on navigation
- No pre-loading of adjacent images

**Performance Trade-offs**:
- Pro: Low memory footprint
- Con: Potential delay when navigating to unloaded images
- Future optimization: Implement LRU cache with pre-loading for ±1 images

### File System Operations

**Directory Scanning**:
- Recursive listing via `Directory.list(recursive: true)`
- Synchronous file filtering by extension
- Path-based sorting for predictable order

**Considerations**:
- Large directories (>1000 images) may cause UI freeze during initial load
- Future improvement: Async loading with progress indicator

## Cross-Platform Compatibility

### Desktop Platforms (macOS, Windows, Linux)

**Keyboard Support**: Full keyboard navigation optimized for desktop workflow

**File Picker**: Native OS dialogs via `file_picker` package

**Window Management**: Standard Flutter desktop configuration

### Mobile Platforms (Android, iOS)

**Touch Support**: All buttons accessible via touch
- Swipe gestures not currently implemented
- Navigation buttons as touch targets

**File Access**: Platform-specific permissions handled by `file_picker`

### Web Platform

**PWA Configuration**:
- Standalone display mode (app-like experience)
- Manifest configured for installation
- Service worker ready (template included)

**Limitations**:
- File system access restricted to user-selected directories
- No persistent file access across sessions

## Security & Privacy

### Data Storage
- **No persistent storage**: All data exists only in memory during session
- **No cloud sync**: Entirely local operation
- **No analytics**: No tracking or telemetry

### File Access
- User must explicitly select directory via native picker
- No background file access
- No modification of original files

## Testing Strategy

### Current Test Coverage
- Basic smoke test in [test/widget_test.dart](test/widget_test.dart)
- Template test (needs customization for actual features)

### Recommended Test Coverage

**Unit Tests**:
- `ImageItem` model serialization/deserialization
- Status transition logic
- Statistics calculation methods

**Widget Tests**:
- Empty state rendering
- Image display with different aspect ratios
- Status bar color changes
- Button interaction
- Keyboard shortcuts

**Integration Tests**:
- Full folder selection workflow
- Navigation through image collection
- Status persistence during navigation

## Build & Deployment

### Build Artifacts
- Generated in `/build` directory
- Platform-specific subdirectories (e.g., `build/web`, `build/macos`)

### Platform-Specific Notes

**macOS**: Requires signed entitlements for file access ([macos/Runner/Release.entitlements](macos/Runner/Release.entitlements))

**Android**: Gradle-based build with standard Flutter configuration

**Web**: PWA deployment compatible with static hosting (Firebase, Netlify, etc.)

## Future Enhancement Opportunities

### High Priority
1. **Export Functionality**: Save picked/rejected lists to CSV/JSON
2. **Undo/Redo**: Action history with keyboard shortcuts (Cmd+Z/Ctrl+Z)
3. **Image Pre-loading**: Cache ±1 images for smoother navigation
4. **Progress Indicator**: Show loading state for large directories

### Medium Priority
5. **Bulk Actions**: Select multiple images, apply status to all
6. **Filtering**: View only picked/rejected/unreviewed
7. **Search**: Find images by filename
8. **Image Metadata**: Display resolution, file size, date

### Low Priority
9. **Custom Categories**: Beyond pick/reject (e.g., favorites, archive)
10. **Swipe Gestures**: Mobile-optimized navigation
11. **Slideshow Mode**: Auto-advance with timer
12. **Zoom/Pan**: Detailed image inspection

## Performance Characteristics

### Memory Profile
- **Per Image**: ~100-500 KB (Flutter's image cache)
- **Collection**: O(n) where n = number of images
- **Cache Strategy**: Flutter's default image cache (1000 images or 100 MB)

### CPU Usage
- **Idle**: Minimal (static UI)
- **Navigation**: Brief spike during image decode
- **Directory Scan**: O(n) file operations, blocking on large directories

### Recommended Limits
- **Optimal**: < 500 images per session
- **Maximum**: < 5000 images (without optimization)

## Code Quality Standards

### Linting
- Enforced via `flutter_lints: ^6.0.0`
- Configuration in [analysis_options.yaml](analysis_options.yaml)

### Naming Conventions
- Private methods: `_camelCase`
- Public methods: `camelCase`
- Classes: `PascalCase`
- Constants: `SCREAMING_SNAKE_CASE` (if added)

### File Organization
```
lib/
  ├── main.dart              # Entry point only
  ├── models/                # Data structures
  └── screens/               # UI screens
```

**Scalability**: For future growth, add directories:
- `lib/services/` - Business logic
- `lib/widgets/` - Reusable UI components
- `lib/utils/` - Helper functions

---

## Conclusion

Deck Image Picker is a well-structured, lightweight Flutter application focused on a single task: efficient image review and categorization. The architecture prioritizes simplicity and cross-platform compatibility while maintaining extensibility for future enhancements. The keyboard-driven interface and dark theme optimization demonstrate attention to user experience for the target use case: rapid image triage workflows.
