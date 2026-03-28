import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../models/image_item.dart';
import '../models/image_group.dart';
import '../services/selection_persistence_service.dart';
import '../services/app_config_service.dart';
import '../services/gamepad_service.dart';
import '../services/image_cache_service.dart';
import '../services/thumbnail_worker_service.dart';
import '../widgets/cached_image_widget.dart';
import '../widgets/grid_thumbnail_widget.dart';
import 'subfolder_picker_screen.dart';

/// Direction for grid navigation
enum GridDirection { up, down, left, right }

class ImagePickerScreen extends StatefulWidget {
  final String? initialDirectory;

  const ImagePickerScreen({this.initialDirectory, super.key});

  @override
  State<ImagePickerScreen> createState() => _ImagePickerScreenState();
}

class _ImagePickerScreenState extends State<ImagePickerScreen> {
  List<ImageItem> _images = [];
  int _currentIndex = 0;
  bool _isLoading = false;
  String? _currentDirectory;
  bool _usedDefaultPath = false;
  GamepadService? _gamepadService;
  bool _isDialogOpen = false;
  bool _isFullscreenMode = false; // Toggle for fullscreen viewing mode
  late ImageCacheService _imageCacheService;

  // Grid view state
  List<ImageGroup> _groups = [];
  late ThumbnailWorkerService _thumbnailWorker;
  final ScrollController _verticalScrollController = ScrollController();
  final Map<int, ScrollController> _groupScrollControllers = {};

  // Thumbnail size for grid
  static const double _thumbnailSize = 150.0;
  static const double _thumbnailSpacing = 8.0;
  static const double _groupHeaderHeight = 40.0;

  @override
  void initState() {
    super.initState();
    // Initialize image cache service for preloading
    _imageCacheService = ImageCacheService(maxCacheSize: 5, preloadDistance: 2);
    // Initialize thumbnail worker for grid view
    _thumbnailWorker =
        ThumbnailWorkerService(thumbnailSize: _thumbnailSize.toInt())
          ..onThumbnailsUpdated = () {
            if (mounted) setState(() {});
          };
    // Initialize gamepad support
    _initializeGamepad();

    // If an initial directory was provided, load it immediately
    if (widget.initialDirectory != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDirectoryDirectly(widget.initialDirectory!);
      });
    } else {
      // On Steam Deck, automatically show subfolder picker if default directory exists
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoShowSubfolderPickerIfAvailable();
      });
    }
  }

  /// Initialize gamepad service and wire up callbacks
  void _initializeGamepad() {
    _gamepadService = GamepadService()
      // Linear navigation - only used in fullscreen mode
      ..onPreviousImage = () {
        if (_isFullscreenMode) _previousImage();
      }
      ..onNextImage = () {
        if (_isFullscreenMode) _nextImage();
      }
      // Grid navigation - used in grid mode, also fires for subfolder picker
      ..onNavigateLeft = () {
        if (!_isFullscreenMode && _images.isNotEmpty) {
          _navigateInGrid(GridDirection.left);
        }
      }
      ..onNavigateRight = () {
        if (!_isFullscreenMode && _images.isNotEmpty) {
          _navigateInGrid(GridDirection.right);
        }
      }
      ..onNavigateUp = () {
        if (!_isFullscreenMode && _images.isNotEmpty) {
          _navigateInGrid(GridDirection.up);
        }
      }
      ..onNavigateDown = () {
        if (!_isFullscreenMode && _images.isNotEmpty) {
          _navigateInGrid(GridDirection.down);
        }
      }
      ..onPickImage = _pickImage
      ..onRejectImage = () {
        // B button: Close dialog if open, otherwise reject image
        if (_isDialogOpen) {
          Navigator.of(context).pop();
        } else {
          _rejectImage();
        }
      }
      ..onAddGroupMarker = () {
        // Only add group marker in fullscreen mode
        if (_isFullscreenMode) _addGroupMarker();
      }
      ..onClearStatus = _clearStatus
      ..onPickWithoutAdvance = _pickImageWithoutAdvance
      ..onRejectWithoutAdvance = _rejectImageWithoutAdvance
      ..onShowHelp = _showHelp
      ..onToggleFullscreen = () {
        // Y button: Toggle fullscreen mode
        setState(() {
          _isFullscreenMode = !_isFullscreenMode;
        });
      }
      ..onOpenFolderPicker = _pickFolder
      ..onShowMenu = _showMenu
      ..onExitApp = _exitApplication
      ..onJumpToFirstUnreviewed = _jumpToFirstUnreviewed
      ..onJumpToNextUnreviewed = _jumpToNextUnreviewed
      ..onJumpToLastUnreviewed = _jumpToResumePoint
      ..onConnectionChanged = (connected, name) {
        setState(() {}); // Rebuild to show/hide gamepad indicator
      }
      ..initialize();
  }

  @override
  void dispose() {
    _gamepadService?.dispose();
    _imageCacheService.dispose();
    _thumbnailWorker.dispose();
    _verticalScrollController.dispose();
    for (final controller in _groupScrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Automatically show the subfolder picker on Steam Deck if the default directory exists
  Future<void> _autoShowSubfolderPickerIfAvailable() async {
    final defaultDir = AppConfigService.getDefaultDirectory();

    if (defaultDir != null) {
      // Default directory exists on Steam Deck, show the subfolder picker
      await _pickFolder();
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        // Hide AppBar in fullscreen mode
        appBar: _isFullscreenMode
            ? null
            : AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Image Picker'),
                    if (_currentDirectory != null)
                      Text(
                        _getCurrentFolderName(),
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                  ],
                ),
                backgroundColor: Colors.grey[900],
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: _showMenu,
                    tooltip: 'Menu (M)',
                  ),
                  if (_images.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Center(
                        child: Text(
                          '${_currentIndex + 1} / ${_images.length}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  if (_gamepadService?.isConnected ?? false)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Tooltip(
                        message:
                            'Gamepad connected: ${_gamepadService?.connectedGamepadName ?? "Unknown"}',
                        child: const Icon(
                          Icons.videogame_asset,
                          color: Colors.greenAccent,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: _showHelp,
                  ),
                ],
              ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _images.isEmpty
            ? _buildEmptyState()
            : _buildImageView(),
        floatingActionButton: _images.isEmpty
            ? FloatingActionButton.extended(
                onPressed: _pickFolder,
                icon: const Icon(Icons.folder_open),
                label: const Text('Select Folder'),
              )
            : null,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library, size: 100, color: Colors.grey[700]),
          const SizedBox(height: 20),
          Text(
            'No images loaded',
            style: TextStyle(fontSize: 24, color: Colors.grey[500]),
          ),
          const SizedBox(height: 10),
          Text(
            'Click the button below to select a folder',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildImageView() {
    final currentImage = _images[_currentIndex];

    // Toggle between fullscreen and normal mode
    return _isFullscreenMode
        ? _buildFullscreenView(currentImage)
        : _buildNormalView(currentImage);
  }

  /// Fullscreen view: Image with right sidebar only
  Widget _buildFullscreenView(ImageItem currentImage) {
    // Get cached full image, or fall back to thumbnail as placeholder
    final cachedFullImage = _imageCacheService.getCachedImage(
      currentImage.file.path,
    );
    final thumbnail = _thumbnailWorker.getThumbnail(currentImage.file.path);

    return Row(
      children: [
        // Image takes remaining space
        Expanded(
          child: Stack(
            children: [
              Center(
                child: cachedFullImage != null
                    ? CachedImageWidget(
                        file: currentImage.file,
                        cachedImage: cachedFullImage,
                        fit: BoxFit.contain,
                      )
                    : thumbnail != null
                    // Use thumbnail as placeholder while full image loads
                    ? CachedImageWidget(
                        file: currentImage.file,
                        cachedImage: thumbnail,
                        fit: BoxFit.contain,
                      )
                    // Fall back to file loading
                    : CachedImageWidget(
                        file: currentImage.file,
                        fit: BoxFit.contain,
                      ),
              ),
              if (currentImage.isNewGroup)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_open, color: Colors.white, size: 20),
                        SizedBox(width: 4),
                        Text(
                          'NEW GROUP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Right sidebar with status indicators
        _buildRightSidebar(currentImage),
      ],
    );
  }

  /// Grid view: Shows images organized by groups with thumbnails
  Widget _buildNormalView(ImageItem currentImage) {
    if (_groups.isEmpty) {
      _rebuildGroups();
    }

    return Column(
      children: [
        // Grid of images organized by groups
        Expanded(child: _buildGridView()),
        // Stats bar at bottom
        _buildGridStatsBar(),
      ],
    );
  }

  /// Build the grid view with groups as rows
  Widget _buildGridView() {
    return ListView.builder(
      controller: _verticalScrollController,
      itemCount: _groups.length,
      itemBuilder: (context, groupIndex) {
        final group = _groups[groupIndex];
        return _buildGroupRow(group, groupIndex);
      },
    );
  }

  /// Build a single group row
  Widget _buildGroupRow(ImageGroup group, int groupIndex) {
    // Ensure scroll controller exists
    _groupScrollControllers[groupIndex] ??= ScrollController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header
        Container(
          height: _groupHeaderHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                'Group ${groupIndex + 1}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${group.length} images)',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
        // Horizontal list of thumbnails
        SizedBox(
          height: _thumbnailSize + _thumbnailSpacing,
          child: ListView.builder(
            controller: _groupScrollControllers[groupIndex],
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: group.length,
            itemBuilder: (context, indexInGroup) {
              final flatIndex = group.startIndex + indexInGroup;
              final image = group.images[indexInGroup];
              final isFocused = flatIndex == _currentIndex;

              return Padding(
                padding: EdgeInsets.only(right: _thumbnailSpacing),
                child: GridThumbnailWidget(
                  imageItem: image,
                  thumbnail: _thumbnailWorker.getThumbnail(image.file.path),
                  isFocused: isFocused,
                  height: _thumbnailSize,
                  onTap: () {
                    setState(() => _currentIndex = flatIndex);
                    _preloadImagesAroundCurrent();
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Build stats bar for grid view
  Widget _buildGridStatsBar() {
    final pickCount = _images
        .where((img) => img.status == ImageStatus.pick)
        .length;
    final rejectCount = _images
        .where((img) => img.status == ImageStatus.reject)
        .length;
    final noneCount = _images
        .where((img) => img.status == ImageStatus.none)
        .length;

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[900],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatChip('Picked', pickCount, Colors.green),
              const SizedBox(width: 8),
              _buildStatChip('Rejected', rejectCount, Colors.red),
              const SizedBox(width: 8),
              _buildStatChip('Unreviewed', noneCount, Colors.grey),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _pickImage,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Pick (P)'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _rejectImage,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Reject (X)'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _clearStatus,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                child: const Text('Clear (C)'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Navigation buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _jumpToResumePoint,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Resume'),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: _jumpToLastGroup,
                icon: const Icon(Icons.last_page, size: 18),
                label: const Text('Last Group'),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(ImageItem image) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (image.status) {
      case ImageStatus.pick:
        statusColor = Colors.green;
        statusText = 'PICKED';
        statusIcon = Icons.check_circle;
        break;
      case ImageStatus.reject:
        statusColor = Colors.red;
        statusText = 'REJECTED';
        statusIcon = Icons.cancel;
        break;
      case ImageStatus.none:
        statusColor = Colors.grey;
        statusText = 'NO STATUS';
        statusIcon = Icons.radio_button_unchecked;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: statusColor.withOpacity(0.2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(statusIcon, color: statusColor, size: 32),
          const SizedBox(width: 12),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationBar() {
    final pickCount = _images
        .where((img) => img.status == ImageStatus.pick)
        .length;
    final rejectCount = _images
        .where((img) => img.status == ImageStatus.reject)
        .length;
    final noneCount = _images
        .where((img) => img.status == ImageStatus.none)
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[900],
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatChip('Picked', pickCount, Colors.green),
              _buildStatChip('Rejected', rejectCount, Colors.red),
              _buildStatChip('Unreviewed', noneCount, Colors.grey),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _currentIndex > 0 ? _previousImage : null,
                icon: const Icon(Icons.arrow_back),
                iconSize: 32,
                color: Colors.white,
              ),
              const SizedBox(width: 40),
              ElevatedButton.icon(
                onPressed: _rejectImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.cancel),
                label: const Text('Reject (X)'),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _clearStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.clear),
                label: const Text('Clear (C)'),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _pickImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.check_circle),
                label: const Text('Pick (P)'),
              ),
              const SizedBox(width: 40),
              IconButton(
                onPressed: _currentIndex < _images.length - 1
                    ? _nextImage
                    : null,
                icon: const Icon(Icons.arrow_forward),
                iconSize: 32,
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _jumpToFirstUnreviewed,
                icon: const Icon(Icons.skip_previous, size: 18),
                label: const Text('First Unreviewed'),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: _jumpToResumePoint,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Resume'),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Chip(
      label: Text(
        '$label: $count',
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: color.withOpacity(0.7),
    );
  }

  /// Build the right sidebar for fullscreen mode with status indicators
  Widget _buildRightSidebar(ImageItem currentImage) {
    const double iconSize = 40.0;
    const double activeOpacity = 1.0;
    const double inactiveOpacity = 0.25;

    return Container(
      width: 80,
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pick icon (green check)
          IconButton(
            icon: Icon(
              Icons.check_circle,
              size: iconSize,
              color: Colors.green.withOpacity(
                currentImage.status == ImageStatus.pick
                    ? activeOpacity
                    : inactiveOpacity,
              ),
            ),
            onPressed: _pickImage,
          ),
          const SizedBox(height: 24),
          // Reject icon (red cancel)
          IconButton(
            icon: Icon(
              Icons.cancel,
              size: iconSize,
              color: Colors.red.withOpacity(
                currentImage.status == ImageStatus.reject
                    ? activeOpacity
                    : inactiveOpacity,
              ),
            ),
            onPressed: _rejectImage,
          ),
          const SizedBox(height: 24),
          // No status icon (grey circle)
          IconButton(
            icon: Icon(
              Icons.radio_button_unchecked,
              size: iconSize,
              color: Colors.grey.withOpacity(
                currentImage.status == ImageStatus.none
                    ? activeOpacity
                    : inactiveOpacity,
              ),
            ),
            onPressed: _clearStatus,
          ),
        ],
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    // Handle exit keys (ESC and Q) - work even when no images loaded
    // Don't exit app if dialog is open and ESC is pressed
    if (!_isDialogOpen &&
        (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.keyQ)) {
      _exitApplication();
      return;
    }

    // Close dialog if ESC is pressed
    if (_isDialogOpen && event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return;
    }

    // Handle help dialog (H key) - works even when no images loaded
    if (event.logicalKey == LogicalKeyboardKey.keyH) {
      _showHelp();
      return;
    }

    // Handle menu (M key) - works even when no images loaded
    if (event.logicalKey == LogicalKeyboardKey.keyM) {
      _showMenu();
      return;
    }

    // Close dialog if ESC is pressed
    if (_isDialogOpen && event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return;
    }

    if (_images.isEmpty) return;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        if (_isFullscreenMode) {
          _previousImage();
        } else {
          _navigateInGrid(GridDirection.left);
        }
        break;
      case LogicalKeyboardKey.arrowRight:
        if (_isFullscreenMode) {
          _nextImage();
        } else {
          _navigateInGrid(GridDirection.right);
        }
        break;
      case LogicalKeyboardKey.arrowUp:
        if (_isFullscreenMode) {
          _pickImageWithoutAdvance();
        } else {
          _navigateInGrid(GridDirection.up);
        }
        break;
      case LogicalKeyboardKey.arrowDown:
        if (_isFullscreenMode) {
          _rejectImageWithoutAdvance();
        } else {
          _navigateInGrid(GridDirection.down);
        }
        break;
      case LogicalKeyboardKey.keyP:
        _pickImage();
        break;
      case LogicalKeyboardKey.keyX:
        _rejectImage();
        break;
      case LogicalKeyboardKey.keyC:
        _clearStatus();
        break;
      case LogicalKeyboardKey.keyY:
        setState(() {
          _isFullscreenMode = !_isFullscreenMode;
        });
        break;
      case LogicalKeyboardKey.keyG:
        _addGroupMarker();
        break;
    }
  }

  /// Get the current folder name for display
  String _getCurrentFolderName() {
    if (_currentDirectory == null) return '';
    return _currentDirectory!.split('/').last;
  }

  /// Load images from a directory path directly (used for initial directory)
  Future<void> _loadDirectoryDirectly(String directoryPath) async {
    setState(() => _isLoading = true);

    try {
      final directory = Directory(directoryPath);

      if (!directory.existsSync()) {
        throw Exception('Directory does not exist: $directoryPath');
      }

      await _loadImagesFromDirectory(directoryPath);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading directory: $e')));
      }
    }
  }

  /// Load images from a directory (shared logic)
  Future<void> _loadImagesFromDirectory(String selectedDirectory) async {
    final directory = Directory(selectedDirectory);
    final files = directory.listSync().whereType<File>().where((file) {
      final ext = file.path.toLowerCase();
      return ext.endsWith('.jpg') ||
          ext.endsWith('.jpeg') ||
          ext.endsWith('.png') ||
          ext.endsWith('.gif') ||
          ext.endsWith('.bmp') ||
          ext.endsWith('.webp');
    }).toList();

    files.sort((a, b) => a.path.compareTo(b.path));

    // Create ImageItem list
    var images = files.map((file) => ImageItem(file: file)).toList();

    // AUTO-LOAD: Restore saved selections if they exist
    images = await SelectionPersistenceService.loadSelections(
      directoryPath: selectedDirectory,
      images: images,
    );

    setState(() {
      _images = images;
      _currentIndex = 0;
      _currentDirectory = selectedDirectory;
      _isLoading = false;
    });

    // Build groups for grid view
    _rebuildGroups();

    // Start thumbnail generation for grid view
    final allPaths = images.map((img) => img.file.path).toList();
    _thumbnailWorker.startGeneration(allPaths);

    // Preload images around the initial position
    _preloadImagesAroundCurrent();

    // Show feedback if selections were loaded
    final hasSelections = images.any((img) => img.status != ImageStatus.none);
    if (hasSelections && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Previous selections restored'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickFolder() async {
    setState(() => _isLoading = true);

    try {
      String? selectedDirectory;

      // STRATEGY: Try default path first on Steam Deck
      final defaultDir = AppConfigService.getDefaultDirectory();

      if (defaultDir != null) {
        // Show subfolder picker screen
        final result = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (context) =>
                SubfolderPickerScreen(baseDirectory: defaultDir),
          ),
        );

        if (result != null) {
          selectedDirectory = result;
          _usedDefaultPath = true;
        } else {
          // User cancelled or chose fallback - use native file picker
          selectedDirectory = await FilePicker.platform.getDirectoryPath();
          _usedDefaultPath = false;
        }
      } else {
        // Fallback: Use native file picker (existing behavior)
        selectedDirectory = await FilePicker.platform.getDirectoryPath();
        _usedDefaultPath = false;
      }

      if (selectedDirectory == null) {
        setState(() => _isLoading = false);
        return;
      }

      await _loadImagesFromDirectory(selectedDirectory);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading images: $e')));
      }
    }
  }

  /// Rebuild groups from the current image list
  void _rebuildGroups() {
    // Dispose old scroll controllers
    for (final controller in _groupScrollControllers.values) {
      controller.dispose();
    }
    _groupScrollControllers.clear();

    // Build new groups
    _groups = buildGroups(_images);

    // Create scroll controllers for each group
    for (int i = 0; i < _groups.length; i++) {
      _groupScrollControllers[i] = ScrollController();
    }
  }

  /// Navigate in grid view (2D navigation)
  void _navigateInGrid(GridDirection direction) {
    if (_images.isEmpty || _groups.isEmpty) return;

    final (currentGroup, currentCol) = flatIndexToGroupPosition(
      _groups,
      _currentIndex,
    );
    int newGroup = currentGroup;
    int newCol = currentCol;

    switch (direction) {
      case GridDirection.left:
        if (currentCol > 0) {
          newCol = currentCol - 1;
        }
        break;
      case GridDirection.right:
        if (currentCol < _groups[currentGroup].length - 1) {
          newCol = currentCol + 1;
        }
        break;
      case GridDirection.up:
        if (currentGroup > 0) {
          newGroup = currentGroup - 1;
          // Clamp column to new group's length
          newCol = currentCol.clamp(0, _groups[newGroup].length - 1);
        }
        break;
      case GridDirection.down:
        if (currentGroup < _groups.length - 1) {
          newGroup = currentGroup + 1;
          // Clamp column to new group's length
          newCol = currentCol.clamp(0, _groups[newGroup].length - 1);
        }
        break;
    }

    final newFlatIndex = groupPositionToFlatIndex(_groups, newGroup, newCol);
    if (newFlatIndex != _currentIndex) {
      setState(() => _currentIndex = newFlatIndex);
      _scrollToCurrentItem();
      _preloadImagesAroundCurrent();
    }
  }

  /// Get the thumbnail width based on actual aspect ratio from loaded thumbnails
  double _getThumbnailWidth() {
    // Find any loaded thumbnail to get the aspect ratio
    for (final image in _images) {
      final thumbnail = _thumbnailWorker.getThumbnail(image.file.path);
      if (thumbnail != null) {
        final aspectRatio = thumbnail.width / thumbnail.height;
        return _thumbnailSize * aspectRatio;
      }
    }
    // Fallback to square if no thumbnails loaded yet
    return _thumbnailSize;
  }

  /// Scroll to make the current item visible in grid view
  void _scrollToCurrentItem() {
    if (_groups.isEmpty) return;

    final (groupIndex, indexInGroup) = flatIndexToGroupPosition(
      _groups,
      _currentIndex,
    );

    // Scroll vertical list to show current group
    final groupOffset =
        groupIndex * (_thumbnailSize + _thumbnailSpacing + _groupHeaderHeight);
    if (_verticalScrollController.hasClients) {
      _verticalScrollController.animateTo(
        groupOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }

    // Scroll horizontal list within group to show current image
    final horizontalController = _groupScrollControllers[groupIndex];
    if (horizontalController != null && horizontalController.hasClients) {
      // Use actual thumbnail width based on aspect ratio
      final thumbnailWidth = _getThumbnailWidth();
      final itemOffset = indexInGroup * (thumbnailWidth + _thumbnailSpacing);
      horizontalController.animateTo(
        itemOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _previousImage() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _preloadImagesAroundCurrent();
    }
  }

  void _nextImage() {
    if (_currentIndex < _images.length - 1) {
      setState(() => _currentIndex++);
      _preloadImagesAroundCurrent();
    }
  }

  /// Preload images around the current index for faster navigation
  void _preloadImagesAroundCurrent() {
    if (_images.isEmpty) return;

    final imageFiles = _images.map((img) => img.file).toList();
    _imageCacheService.preloadImagesAround(imageFiles, _currentIndex);
  }

  void _pickImage() {
    setState(() {
      _images[_currentIndex].status = ImageStatus.pick;
    });
    _autoSave();
    if (_currentIndex < _images.length - 1) {
      _nextImage();
    }
  }

  void _pickImageWithoutAdvance() {
    setState(() {
      _images[_currentIndex].status = ImageStatus.pick;
    });
    _autoSave();
  }

  void _rejectImage() {
    setState(() {
      _images[_currentIndex].status = ImageStatus.reject;
    });
    _autoSave();
    if (_currentIndex < _images.length - 1) {
      _nextImage();
    }
  }

  void _rejectImageWithoutAdvance() {
    setState(() {
      _images[_currentIndex].status = ImageStatus.reject;
    });
    _autoSave();
  }

  void _clearStatus() {
    setState(() {
      _images[_currentIndex].status = ImageStatus.none;
    });
    _autoSave();
  }

  void _addGroupMarker() {
    setState(() {
      _images[_currentIndex].isNewGroup = !_images[_currentIndex].isNewGroup;
    });
    // Rebuild groups since group boundaries changed
    _rebuildGroups();
    _autoSave();
  }

  /// Jump to the first unreviewed image
  void _jumpToFirstUnreviewed() {
    if (_images.isEmpty) return;

    final firstUnreviewed = _images.indexWhere(
      (img) => img.status == ImageStatus.none,
    );
    if (firstUnreviewed != -1) {
      setState(() => _currentIndex = firstUnreviewed);
      _preloadImagesAroundCurrent();
    }
  }

  /// Jump to the next unreviewed image after the current one
  void _jumpToNextUnreviewed() {
    if (_images.isEmpty) return;

    final nextUnreviewed = _images
        .sublist(_currentIndex + 1)
        .indexWhere((img) => img.status == ImageStatus.none);
    if (nextUnreviewed != -1) {
      setState(() => _currentIndex = _currentIndex + 1 + nextUnreviewed);
      _preloadImagesAroundCurrent();
    }
  }

  /// Jump to the last group
  void _jumpToLastGroup() {
    if (_images.isEmpty || _groups.isEmpty) return;

    final lastGroup = _groups.last;
    setState(() => _currentIndex = lastGroup.startIndex);
    _scrollToCurrentItem();
    _preloadImagesAroundCurrent();
  }

  /// Jump to the resume point: the first unreviewed image after the last reviewed one.
  /// This helps you continue where you left off in your review session.
  void _jumpToResumePoint() {
    if (_images.isEmpty) return;

    // Find the last image that has been reviewed (picked or rejected)
    int lastReviewedIndex = -1;
    for (int i = _images.length - 1; i >= 0; i--) {
      if (_images[i].status != ImageStatus.none) {
        lastReviewedIndex = i;
        break;
      }
    }

    int resumeIndex;
    if (lastReviewedIndex == -1) {
      // No reviewed images, start from beginning
      resumeIndex = 0;
    } else {
      // Search forward from last reviewed index to find first unreviewed image
      int firstUnreviewedAfterLastReviewed = -1;
      for (int i = lastReviewedIndex + 1; i < _images.length; i++) {
        if (_images[i].status == ImageStatus.none) {
          firstUnreviewedAfterLastReviewed = i;
          break;
        }
      }

      if (firstUnreviewedAfterLastReviewed != -1) {
        // Found unreviewed image after last reviewed one, jump to it
        resumeIndex = firstUnreviewedAfterLastReviewed;
      } else {
        // All images after last reviewed are also reviewed, jump to last image
        resumeIndex = _images.length - 1;
      }
    }

    setState(() => _currentIndex = resumeIndex);
    _preloadImagesAroundCurrent();
  }

  /// Exit the application gracefully
  void _exitApplication() {
    // Auto-save before exit if images are loaded
    if (_images.isNotEmpty && _currentDirectory != null) {
      SelectionPersistenceService.saveSelections(
        directoryPath: _currentDirectory!,
        images: _images,
      );
    }
    // Gracefully exit the application
    SystemNavigator.pop();
  }

  /// Auto-save selections after any status change
  Future<void> _autoSave() async {
    if (_currentDirectory == null) {
      print('Auto-save skipped: no directory selected');
      return;
    }

    print('Auto-saving to $_currentDirectory');
    final success = await SelectionPersistenceService.saveSelections(
      directoryPath: _currentDirectory!,
      images: _images,
    );
    print('Auto-save result: $success');
  }

  void _showHelp() {
    final hasGamepad = _gamepadService?.isConnected ?? false;
    _isDialogOpen = true;

    showDialog(
      context: context,
      builder: (context) => KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            // Close dialog on ESC or B button
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.pop(context);
            }
          }
        },
        child: AlertDialog(
          title: const Text('Controls'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: SizedBox(
            width: double.maxFinite,
            height: 500, // Fixed height to ensure scrollability
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Grid View (Default)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildControlRow('← / →', 'Move within group'),
                  _buildControlRow('↑ / ↓', 'Move between groups'),
                  _buildControlRow('P', 'Mark as Pick'),
                  _buildControlRow('X', 'Mark as Reject'),
                  _buildControlRow('C', 'Clear status'),
                  _buildControlRow('G', 'Add group marker'),
                  _buildControlRow('Y', 'Enter fullscreen mode'),
                  _buildControlRow('H', 'Show this help'),
                  _buildControlRow('M', 'Show menu'),
                  _buildControlRow('ESC / Q', 'Exit application'),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Fullscreen View',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildControlRow('← / →', 'Navigate images'),
                  _buildControlRow('↑', 'Mark as Pick (stay on image)'),
                  _buildControlRow('↓', 'Mark as Reject (stay on image)'),
                  _buildControlRow('G', 'Add group marker'),
                  _buildControlRow('Y', 'Return to grid view'),

                  if (hasGamepad) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      'Gamepad Controls',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildControlRow(
                      'D-Pad ← / →',
                      'Grid: move in group / Full: prev/next',
                    ),
                    _buildControlRow(
                      'D-Pad ↑ / ↓',
                      'Grid: move between groups',
                    ),
                    _buildControlRow(
                      'D-Pad ↓ (Fullscreen)',
                      'Add group marker',
                    ),
                    _buildControlRow('A Button', 'Pick and advance'),
                    _buildControlRow('B Button', 'Close this dialog'),
                    _buildControlRow('X Button', 'Clear status'),
                    _buildControlRow('Y Button', 'Toggle fullscreen mode'),
                    _buildControlRow('LB Bumper', 'Jump to first unreviewed'),
                    _buildControlRow('RB Bumper', 'Jump to next unreviewed'),
                    _buildControlRow('LT / RT Triggers', 'Navigate images'),
                    _buildControlRow('Select', 'Show menu'),
                    _buildControlRow('Start', 'Show this help'),
                    _buildControlRow('Hold Select + Start', 'Exit application'),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(context),
              child: const Text('Close (B Button)'),
            ),
          ],
        ),
      ),
    ).then((_) {
      // Reset dialog state when closed
      _isDialogOpen = false;
    });
  }

  Widget _buildControlRow(String key, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              key,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(child: Text(description)),
        ],
      ),
    );
  }

  Future<void> _showMenu() async {
    _isDialogOpen = true;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Menu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Open Folder Picker'),
              onTap: () => Navigator.of(context).pop('folder'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Exit Application'),
              onTap: () => Navigator.of(context).pop('exit'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close (B Button)'),
          ),
        ],
      ),
    );

    _isDialogOpen = false;

    if (!mounted) return;

    switch (result) {
      case 'folder':
        _pickFolder();
        break;
      case 'exit':
        _exitApplication();
        break;
    }
  }
}
