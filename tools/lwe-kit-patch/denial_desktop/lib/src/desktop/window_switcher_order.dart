/// Wraps a switcher index around the selected item. An exactly opposite item
/// in an even-length list keeps the sign of its original index difference.
int windowSwitcherSignedDistance({
  required int index,
  required int selectedIndex,
  required int length,
}) {
  var distance = index - selectedIndex;
  final half = length / 2.0;
  if (distance > half) {
    distance -= length;
  } else if (distance < -half) {
    distance += length;
  }
  return distance;
}

/// Position on one side of the expanded switcher, ordered nearest first.
///
/// Distances on each side are consecutive, so no candidate list or sort is
/// needed per window. Even counts give the opposite item to its original side.
({int index, int count}) windowSwitcherRail({
  required int distance,
  required int selectedIndex,
  required int length,
}) {
  assert(length > 1 && selectedIndex >= 0 && selectedIndex < length);
  assert(distance != 0 && distance.abs() <= length ~/ 2);
  final negativeCount =
      (length - 1) ~/ 2 +
      (length.isEven && selectedIndex >= length ~/ 2 ? 1 : 0);
  return (
    index: distance.abs() - 1,
    count: distance.isNegative ? negativeCount : length - 1 - negativeCount,
  );
}

/// Immutable candidate order with indexed lookup for larger switchers.
/// Selection and animation phases can share this object until candidates change.
final class WindowSwitcherOrder {
  factory WindowSwitcherOrder(Iterable<int> ids) {
    final objectIds = List<int>.unmodifiable(ids);
    // Short contiguous scans beat hashing for typical small switchers and
    // avoid allocating a map. Keep large-session lookups constant-time.
    if (objectIds.length <= _linearLookupLimit) {
      return WindowSwitcherOrder._(objectIds, null);
    }
    final indices = <int, int>{};
    for (final (index, id) in objectIds.indexed) {
      indices.putIfAbsent(id, () => index);
    }
    return WindowSwitcherOrder._(objectIds, indices);
  }

  const WindowSwitcherOrder._(this.objectIds, this._indices);

  static const _linearLookupLimit = 16;

  final List<int> objectIds;
  final Map<int, int>? _indices;

  bool contains(int objectId) => _indices == null
      ? objectIds.contains(objectId)
      : _indices.containsKey(objectId);

  int indexOf(int objectId) =>
      _indices == null ? objectIds.indexOf(objectId) : _indices[objectId] ?? -1;
}
