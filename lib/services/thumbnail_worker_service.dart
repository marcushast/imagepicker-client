import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

/// Service for background thumbnail generation.
/// Pre-generates thumbnails for all images when a folder is opened.
class ThumbnailWorkerService {
  // Cache of decoded thumbnails keyed by file path
  final Map<String, ui.Image> _thumbnailCache = {};

  // Track which images are currently being loaded
  final Set<String> _loadingPaths = {};

  // Queue of paths to process
  final List<String> _queue = [];

  // Whether the worker is currently processing
  bool _isProcessing = false;

  // Callback when thumbnails are updated
  VoidCallback? onThumbnailsUpdated;

  // Callback for progress updates (loaded, total)
  void Function(int loaded, int total)? onProgress;

  // Thumbnail size (width and height)
  final int thumbnailSize;

  // Total images to process (for progress)
  int _totalImages = 0;

  ThumbnailWorkerService({
    this.thumbnailSize = 150,
  });

  /// Get a cached thumbnail if available
  ui.Image? getThumbnail(String filePath) {
    return _thumbnailCache[filePath];
  }

  /// Check if a thumbnail is cached
  bool hasThumbnail(String filePath) {
    return _thumbnailCache.containsKey(filePath);
  }

  /// Get current progress (loaded count)
  int get loadedCount => _thumbnailCache.length;

  /// Get total images count
  int get totalCount => _totalImages;

  /// Start generating thumbnails for all images.
  /// Priority paths will be processed first.
  Future<void> startGeneration(
    List<String> allPaths, {
    List<String> priorityPaths = const [],
  }) async {
    // Clear existing cache and queue
    clearCache();
    _queue.clear();
    _totalImages = allPaths.length;

    if (allPaths.isEmpty) return;

    // Build queue with priority paths first
    final prioritySet = priorityPaths.toSet();
    for (final path in priorityPaths) {
      if (allPaths.contains(path)) {
        _queue.add(path);
      }
    }
    for (final path in allPaths) {
      if (!prioritySet.contains(path)) {
        _queue.add(path);
      }
    }

    // Start processing
    _processQueue();
  }

  /// Update priority - move these paths to the front of the queue
  void updatePriority(List<String> priorityPaths) {
    if (_queue.isEmpty) return;

    final prioritySet = priorityPaths.toSet();
    final toMove = <String>[];

    // Find paths in queue that should be prioritized
    _queue.removeWhere((path) {
      if (prioritySet.contains(path)) {
        toMove.add(path);
        return true;
      }
      return false;
    });

    // Insert at front
    _queue.insertAll(0, toMove);
  }

  /// Process the queue in the background
  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final path = _queue.removeAt(0);

      // Skip if already cached or loading
      if (_thumbnailCache.containsKey(path) || _loadingPaths.contains(path)) {
        continue;
      }

      await _loadThumbnail(path);

      // Notify progress
      onProgress?.call(_thumbnailCache.length, _totalImages);

      // Small yield to allow UI updates
      await Future.delayed(Duration.zero);
    }

    _isProcessing = false;
  }

  /// Load and decode a thumbnail
  Future<void> _loadThumbnail(String filePath) async {
    if (_loadingPaths.contains(filePath) ||
        _thumbnailCache.containsKey(filePath)) {
      return;
    }

    _loadingPaths.add(filePath);

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return;
      }

      // Read file bytes
      final bytes = await file.readAsBytes();

      // Decode image at thumbnail height, preserving aspect ratio
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetHeight: thumbnailSize,
      );
      final frame = await codec.getNextFrame();

      _thumbnailCache[filePath] = frame.image;

      // Notify listeners
      onThumbnailsUpdated?.call();
    } catch (e) {
      debugPrint('Error loading thumbnail $filePath: $e');
    } finally {
      _loadingPaths.remove(filePath);
    }
  }

  /// Clear all cached thumbnails
  void clearCache() {
    for (final image in _thumbnailCache.values) {
      image.dispose();
    }
    _thumbnailCache.clear();
    _loadingPaths.clear();
    _totalImages = 0;
  }

  /// Stop processing and clear
  void stop() {
    _queue.clear();
    _isProcessing = false;
  }

  /// Get current cache size
  int get cacheSize => _thumbnailCache.length;

  /// Dispose of resources
  void dispose() {
    stop();
    clearCache();
  }
}
