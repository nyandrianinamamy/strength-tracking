/// Single source of truth for mapping any muscle name variant to its
/// canonical engine ID.
///
/// Canonical IDs are defined by [defaultMuscles] in `muscle_registry.dart`.
/// This class adds alias resolution so that human-readable names, stale IDs,
/// and common misspellings all resolve to the same canonical key.
class MuscleNormalizer {
  const MuscleNormalizer._();

  /// Maps any known alias (lowercase, trimmed) to the canonical muscle ID.
  ///
  /// Stale engine IDs, human-readable app names, and common abbreviations
  /// are all covered. Add new aliases here — this is the **only** place
  /// muscle-name normalization should live.
  static const aliases = <String, String>{
    // ── Chest ──────────────────────────────────────────────────────────
    'chest':              'pectorals',
    'pectorals':          'pectorals',
    'pecs':               'pectorals',

    // ── Shoulders ──────────────────────────────────────────────────────
    'shoulders':          'anterior_deltoid',
    'shoulder':           'anterior_deltoid',
    'deltoid':            'anterior_deltoid',
    'deltoids':           'anterior_deltoid',
    'anterior deltoid':   'anterior_deltoid',
    'anterior_deltoid':   'anterior_deltoid',
    'lateral deltoid':    'lateral_deltoid',
    'lateral_deltoid':    'lateral_deltoid',
    'posterior deltoid':  'rear_deltoid',
    'rear delts':         'rear_deltoid',
    'rear_delt':          'rear_deltoid',
    'rear_deltoid':       'rear_deltoid',
    'rear deltoid':       'rear_deltoid',

    // ── Back ───────────────────────────────────────────────────────────
    'back':               'lats',
    'lats':               'lats',
    'latissimus dorsi':   'lats',
    'upper back':         'upper_back',
    'upper_back':         'upper_back',
    'trapezius':          'trapezius',
    'traps':              'trapezius',
    'upper_trapezius':    'trapezius',
    'rhomboids':          'rhomboids',
    'lower back':         'erector_spinae',
    'lower_back':         'lower_back',
    'erector spinae':     'erector_spinae',
    'erector_spinae':     'erector_spinae',

    // ── Arms ───────────────────────────────────────────────────────────
    'biceps':             'biceps',
    'bicep':              'biceps',
    'triceps':            'triceps',
    'tricep':             'triceps',
    'forearms':           'forearms',
    'forearm':            'forearms',
    'brachialis':         'brachialis',
    'brachioradialis':    'brachioradialis',

    // ── Legs ───────────────────────────────────────────────────────────
    'quadriceps':         'quadriceps',
    'quads':              'quadriceps',
    'quad':               'quadriceps',
    'legs':               'quadriceps',
    'hamstrings':         'hamstrings',
    'hamstring':          'hamstrings',
    'gluteus maximus':    'glutes',
    'glutes':             'glutes',
    'glute':              'glutes',
    'calves':             'calves',
    'calf':               'calves',
    'gastrocnemius':      'calves',
    'adductors':          'adductors',
    'abductors':          'abductors',
    'tibialis anterior':  'tibialis_anterior',
    'tibialis_anterior':  'tibialis_anterior',
    'hip flexors':        'hip_flexors',
    'hip_flexors':        'hip_flexors',

    // ── Core ───────────────────────────────────────────────────────────
    'core':               'core',
    'abs':                'core',
    'abdominals':         'core',
    'obliques':           'obliques',
    'serratus anterior':  'serratus_anterior',
    'serratus_anterior':  'serratus_anterior',

    // ── Misc ───────────────────────────────────────────────────────────
    'rotator_cuff':       'rotator_cuff',
    'rotator cuff':       'rotator_cuff',
    'neck':               'neck',
  };

  /// Resolves [raw] to a canonical engine muscle ID.
  ///
  /// Falls back to `lowercase + space→underscore` for truly unknown names
  /// (e.g. user-created custom muscles with novel names).
  static String normalize(String raw) {
    final key = raw.toLowerCase().trim();
    return aliases[key] ?? key.replaceAll(' ', '_');
  }
}
