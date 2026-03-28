import 'image_item.dart';

/// Represents a group of consecutive images in the picker.
/// Groups are separated by images with isNewGroup=true.
class ImageGroup {
  final int groupIndex;
  final int startIndex;
  final List<ImageItem> images;

  ImageGroup({
    required this.groupIndex,
    required this.startIndex,
    required this.images,
  });

  int get length => images.length;
  int get endIndex => startIndex + length - 1;
}

/// Builds groups from a flat list of images.
/// A new group starts at the first image and at any image with isNewGroup=true.
List<ImageGroup> buildGroups(List<ImageItem> images) {
  if (images.isEmpty) return [];

  final groups = <ImageGroup>[];
  int currentGroupStart = 0;

  for (int i = 0; i < images.length; i++) {
    // Start new group if: first image OR image has isNewGroup=true
    final isGroupStart = i == 0 || images[i].isNewGroup;

    if (isGroupStart && i > 0) {
      // Close previous group
      groups.add(ImageGroup(
        groupIndex: groups.length,
        startIndex: currentGroupStart,
        images: images.sublist(currentGroupStart, i),
      ));
      currentGroupStart = i;
    }
  }

  // Add final group
  groups.add(ImageGroup(
    groupIndex: groups.length,
    startIndex: currentGroupStart,
    images: images.sublist(currentGroupStart),
  ));

  return groups;
}

/// Convert flat index to (groupIndex, indexInGroup).
(int groupIndex, int indexInGroup) flatIndexToGroupPosition(
  List<ImageGroup> groups,
  int flatIndex,
) {
  for (int g = 0; g < groups.length; g++) {
    if (flatIndex >= groups[g].startIndex && flatIndex <= groups[g].endIndex) {
      return (g, flatIndex - groups[g].startIndex);
    }
  }
  return (0, 0); // Fallback
}

/// Convert (groupIndex, indexInGroup) to flat index.
int groupPositionToFlatIndex(
  List<ImageGroup> groups,
  int groupIndex,
  int indexInGroup,
) {
  if (groups.isEmpty || groupIndex >= groups.length) return 0;
  return groups[groupIndex].startIndex + indexInGroup;
}
