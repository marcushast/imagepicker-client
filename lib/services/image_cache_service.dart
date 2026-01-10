import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

/// Service for preloading and caching decoded images to improve navigation performance
class ImageCacheService {
  // Cache to store decoded images
  final Map<String, ui.Image> _imageCache = {};

  // Track which images are currently being loaded to avoid duplicate work
  final Set<String> _loadingImages = {};

  // Maximum number of images to keep in cache (current + 2 before + 2 after = 5 total)
  final int _maxCacheSize;

  // Number of images to preload ahead and behind current position
  final int _preloadDistance;

  ImageCacheService({
    int maxCacheSize = 5,
    int preloadDistance = 2,
  })  : _maxCacheSize = maxCacheSize,
        _preloadDistance = preloadDistance;

  /// Get a cached image if available
  ui.Image? getCachedImage(String filePath) {
    return _imageCache[filePath];
  }

  /// Check if an image is cached
  bool isCached(String filePath) {
    return _imageCache.containsKey(filePath);
  }

  /// Preload images around the current index
  Future<void> preloadImagesAround(
    List<File> imageFiles,
    int currentIndex,
  ) async {
    if (imageFiles.isEmpty) return;

    // Determine which images to preload
    final imagesToPreload = <String>{};

    // Add current image (highest priority)
    imagesToPreload.add(imageFiles[currentIndex].path);

    // Add images before current
    for (int i = 1; i <= _preloadDistance; i++) {
      final index = currentIndex - i;
      if (index >= 0) {
        imagesToPreload.add(imageFiles[index].path);
      }
    }

    // Add images after current
    for (int i = 1; i <= _preloadDistance; i++) {
      final index = currentIndex + i;
      if (index < imageFiles.length) {
        imagesToPreload.add(imageFiles[index].path);
      }
    }

    // Remove images from cache that are outside our preload window
    final pathsToRemove = _imageCache.keys
        .where((path) => !imagesToPreload.contains(path))
        .toList();

    for (final path in pathsToRemove) {
      _imageCache[path]?.dispose();
      _imageCache.remove(path);
    }

    // Load images that aren't cached yet (prioritize current, then next, then previous)
    final loadPriority = <String>[];

    // 1. Current image (highest priority)
    final currentPath = imageFiles[currentIndex].path;
    if (!_imageCache.containsKey(currentPath) && !_loadingImages.contains(currentPath)) {
      loadPriority.add(currentPath);
    }

    // 2. Next images
    for (int i = 1; i <= _preloadDistance; i++) {
      final index = currentIndex + i;
      if (index < imageFiles.length) {
        final path = imageFiles[index].path;
        if (!_imageCache.containsKey(path) && !_loadingImages.contains(path)) {
          loadPriority.add(path);
        }
      }
    }

    // 3. Previous images
    for (int i = 1; i <= _preloadDistance; i++) {
      final index = currentIndex - i;
      if (index >= 0) {
        final path = imageFiles[index].path;
        if (!_imageCache.containsKey(path) && !_loadingImages.contains(path)) {
          loadPriority.add(path);
        }
      }
    }

    // Load images in priority order
    for (final path in loadPriority) {
      // Load current image synchronously, others in background
      if (path == currentPath) {
        await _loadImage(path);
      } else {
        _loadImage(path); // Fire and forget for preloading
      }
    }
  }

  /// Load and decode an image file
  Future<void> _loadImage(String filePath) async {
    // Prevent duplicate loading
    if (_loadingImages.contains(filePath) || _imageCache.containsKey(filePath)) {
      return;
    }

    _loadingImages.add(filePath);

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return;
      }

      // Read file bytes
      final bytes = await file.readAsBytes();

      // Decode image
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      // Store in cache (respect max cache size)
      if (_imageCache.length >= _maxCacheSize) {
        // Remove oldest entry (first in map)
        final oldestKey = _imageCache.keys.first;
        _imageCache[oldestKey]?.dispose();
        _imageCache.remove(oldestKey);
      }

      _imageCache[filePath] = frame.image;
    } catch (e) {
      debugPrint('Error loading image $filePath: $e');
    } finally {
      _loadingImages.remove(filePath);
    }
  }

  /// Clear all cached images
  void clearCache() {
    for (final image in _imageCache.values) {
      image.dispose();
    }
    _imageCache.clear();
    _loadingImages.clear();
  }

  /// Get current cache size
  int get cacheSize => _imageCache.length;

  /// Dispose of resources
  void dispose() {
    clearCache();
  }
}
