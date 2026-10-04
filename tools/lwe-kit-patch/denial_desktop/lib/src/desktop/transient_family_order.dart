/// Orders an activated window's transient family from back to front.
/// Ancestors precede descendants, and the activated branch follows siblings.
/// Only [placements] are returned, but parent links may cross missing entries.
List<int> orderTransientFamily<T extends Object>({
  required int activatedObjectId,
  required Map<int, T> placements,
  required Map<int, int> parentIds,
  required int Function(T placement) zOrder,
}) {
  if (!placements.containsKey(activatedObjectId)) return const [];
  if (parentIds.isEmpty) return [activatedObjectId];

  var root = activatedObjectId;
  for (var steps = 0; ; steps++) {
    final parent = parentIds[root];
    if (parent == null || !placements.containsKey(parent)) break;
    if (steps == parentIds.length) {
      // Match the existing fallback for a malformed parent cycle.
      root = activatedObjectId;
      break;
    }
    root = parent;
  }
  if (!parentIds.containsValue(root)) return [root];

  final children = <int, List<int>>{};
  for (final entry in parentIds.entries) {
    (children[entry.value] ??= []).add(entry.key);
  }
  final ranks = <int, ({int depth, bool activated, int z})>{
    root: (
      depth: 0,
      activated: _isDescendant(root, activatedObjectId, parentIds),
      z: zOrder(placements[root]!),
    ),
  };
  final family = <int>[root];
  for (var index = 0; index < family.length; index++) {
    final parent = family[index];
    final rank = ranks[parent]!;
    for (final child in children[parent] ?? const <int>[]) {
      // Visiting each node once bounds traversal even for cyclic metadata.
      if (ranks.containsKey(child)) continue;
      final placement = placements[child];
      ranks[child] = (
        depth: rank.depth + 1,
        activated: rank.activated || child == activatedObjectId,
        z: placement == null ? 0 : zOrder(placement),
      );
      family.add(child);
    }
  }
  family.removeWhere((id) => !placements.containsKey(id));
  family.sort((left, right) {
    final a = ranks[left]!;
    final b = ranks[right]!;
    if (a.activated != b.activated) return a.activated ? 1 : -1;
    final depth = a.depth.compareTo(b.depth);
    if (depth != 0) return depth;
    final z = a.z.compareTo(b.z);
    return z != 0 ? z : left.compareTo(right);
  });
  return family;
}

bool _isDescendant(int id, int ancestor, Map<int, int> parents) {
  // Root selection stops at missing placements. Membership still follows
  // their parent links, including a cycle that reaches the activated branch.
  for (var depth = 0; depth <= parents.length; depth++) {
    if (id == ancestor) return true;
    final parent = parents[id];
    if (parent == null || parent == id) return false;
    id = parent;
  }
  return false;
}
