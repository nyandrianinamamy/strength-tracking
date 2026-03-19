/// All muscle regions available for highlighting.
enum Muscle {
  abs,
  adductors,
  ankles,
  biceps,
  calves,
  chest,
  deltoids,
  feet,
  forearm,
  gluteal,
  hamstring,
  hands,
  hair,
  head,
  knees,
  lowerBack('lower-back'),
  neck,
  obliques,
  quadriceps,
  tibialis,
  trapezius,
  triceps,
  upperBack('upper-back');

  const Muscle([this._slug]);
  final String? _slug;

  /// The slug identifier used in SVG data.
  String get slug => _slug ?? name;

  /// Returns the Muscle for a given slug string, or null.
  static Muscle? fromSlug(String slug) {
    for (final m in values) {
      if (m.slug == slug) return m;
    }
    return null;
  }
}
