import 'dart:io';
import 'package:flutter/material.dart';
import '../models/folder_info.dart';

/// Screen for browsing and selecting subfolders within a base directory.
/// Designed to be touch-friendly for Steam Deck with large tap targets.
class SubfolderPickerScreen extends StatefulWidget {
  /// The base directory to scan for subfolders
  final String baseDirectory;

  const SubfolderPickerScreen({
    required this.baseDirectory,
    super.key,
  });

  @override
  State<SubfolderPickerScreen> createState() => _SubfolderPickerScreenState();
}

class _SubfolderPickerScreenState extends State<SubfolderPickerScreen> {
  List<FolderInfo> _subfolders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSubfolders();
  }

  /// Load all subfolders from the base directory
  Future<void> _loadSubfolders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final baseDir = Directory(widget.baseDirectory);

      if (!await baseDir.exists()) {
        setState(() {
          _errorMessage = 'Directory does not exist: ${widget.baseDirectory}';
          _isLoading = false;
        });
        return;
      }

      final List<FolderInfo> folders = [];

      // List all entries in the base directory
      final entities = baseDir.listSync();

      for (final entity in entities) {
        // Only process directories (not files)
        if (entity is Directory) {
          try {
            final folderInfo = await FolderInfo.fromDirectory(entity);
            folders.add(folderInfo);
          } catch (e) {
            // Skip folders we can't read
            continue;
          }
        }
      }

      // Sort by last modified date (most recent first)
      folders.sort((a, b) => b.lastModified.compareTo(a.lastModified));

      setState(() {
        _subfolders = folders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading folders: $e';
        _isLoading = false;
      });
    }
  }

  /// Select a folder and return its path to the caller
  void _selectFolder(FolderInfo folder) {
    Navigator.pop(context, folder.path);
  }

  /// Use the native file picker instead
  void _useFallbackPicker() {
    Navigator.pop(context, null);
  }

  /// Show dialog to create a new folder
  Future<void> _createNewFolder() async {
    final controller = TextEditingController();

    final folderName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter folder name',
            labelText: 'Folder Name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (folderName == null || folderName.trim().isEmpty) {
      return;
    }

    // Create the new folder
    try {
      final newFolderPath = '${widget.baseDirectory}/${folderName.trim()}';
      final newFolder = Directory(newFolderPath);

      if (await newFolder.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folder "$folderName" already exists')),
        );
        return;
      }

      await newFolder.create();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created folder "$folderName"')),
      );

      // Reload the folder list
      _loadSubfolders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating folder: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Review Folder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _useFallbackPicker,
            tooltip: 'Use File Picker Instead',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewFolder,
        icon: const Icon(Icons.create_new_folder),
        label: const Text('New Folder'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadSubfolders,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_subfolders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_open, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'No folders found',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Create a new folder to get started',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 columns for Steam Deck
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3, // Wider cards
      ),
      itemCount: _subfolders.length,
      itemBuilder: (context, index) => _buildFolderCard(_subfolders[index]),
    );
  }

  Widget _buildFolderCard(FolderInfo folder) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _selectFolder(folder),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder, size: 48, color: Colors.blue),
              const SizedBox(height: 8),
              Text(
                folder.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image, size: 16),
                  const SizedBox(width: 4),
                  Text('${folder.imageCount} images'),
                ],
              ),
              if (folder.hasSelections) ...[
                const SizedBox(height: 4),
                Chip(
                  label: const Text(
                    'Has selections',
                    style: TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.green.withOpacity(0.3),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
