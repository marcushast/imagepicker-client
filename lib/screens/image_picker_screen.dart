import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../models/image_item.dart';
import '../services/selection_persistence_service.dart';
import '../services/app_config_service.dart';
import 'subfolder_picker_screen.dart';

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

  @override
  void initState() {
    super.initState();
    // If an initial directory was provided, load it immediately
    if (widget.initialDirectory != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDirectoryDirectly(widget.initialDirectory!);
      });
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
        appBar: AppBar(
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
          Icon(
            Icons.photo_library,
            size: 100,
            color: Colors.grey[700],
          ),
          const SizedBox(height: 20),
          Text(
            'No images loaded',
            style: TextStyle(
              fontSize: 24,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Click the button below to select a folder',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageView() {
    final currentImage = _images[_currentIndex];

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Image.file(
              currentImage.file,
              fit: BoxFit.contain,
            ),
          ),
        ),
        _buildStatusBar(currentImage),
        _buildNavigationBar(),
      ],
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
    final pickCount = _images.where((img) => img.status == ImageStatus.pick).length;
    final rejectCount = _images.where((img) => img.status == ImageStatus.reject).length;
    final noneCount = _images.where((img) => img.status == ImageStatus.none).length;

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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.cancel),
                label: const Text('Reject (X)'),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _clearStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.clear),
                label: const Text('Clear (C)'),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _pickImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.check_circle),
                label: const Text('Pick (P)'),
              ),
              const SizedBox(width: 40),
              IconButton(
                onPressed: _currentIndex < _images.length - 1 ? _nextImage : null,
                icon: const Icon(Icons.arrow_forward),
                iconSize: 32,
                color: Colors.white,
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

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (_images.isEmpty) return;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _previousImage();
        break;
      case LogicalKeyboardKey.arrowRight:
        _nextImage();
        break;
      case LogicalKeyboardKey.arrowUp:
        _pickImageWithoutAdvance();
        break;
      case LogicalKeyboardKey.arrowDown:
        _rejectImageWithoutAdvance();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading directory: $e')),
        );
      }
    }
  }

  /// Load images from a directory (shared logic)
  Future<void> _loadImagesFromDirectory(String selectedDirectory) async {
    final directory = Directory(selectedDirectory);
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) {
          final ext = file.path.toLowerCase();
          return ext.endsWith('.jpg') ||
              ext.endsWith('.jpeg') ||
              ext.endsWith('.png') ||
              ext.endsWith('.gif') ||
              ext.endsWith('.bmp') ||
              ext.endsWith('.webp');
        })
        .toList();

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
            builder: (context) => SubfolderPickerScreen(
              baseDirectory: defaultDir,
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading images: $e')),
        );
      }
    }
  }

  void _previousImage() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  void _nextImage() {
    if (_currentIndex < _images.length - 1) {
      setState(() => _currentIndex++);
    }
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keyboard Shortcuts'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('← / → : Navigate between images', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('↑ : Mark as Pick (stay on image)', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('↓ : Mark as Reject (stay on image)', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('P : Mark as Pick (advance to next)', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('X : Mark as Reject (advance to next)', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('C : Clear status', style: TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
