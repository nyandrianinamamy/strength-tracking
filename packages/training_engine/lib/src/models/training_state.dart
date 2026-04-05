import 'daily_load.dart';
import 'e1rm_estimate.dart';
import 'ewma_state.dart';
import 'fatigue_impulse.dart';
import 'hrv_record.dart';
import 'logged_set.dart';
import 'sleep_record.dart';
import 'user_profile.dart';

/// Snapshot of all engine state that can be persisted and restored.
///
/// Serialises every sub-system's working data so that the engine can be
/// resumed from cold-start without re-ingesting historical sessions.
class TrainingState {
  final UserProfile profile;

  /// Per-exercise e1RM history, keyed by exercise ID.
  final Map<String, List<E1rmEstimate>> e1rmHistory;

  /// Per-muscle fatigue impulse log, keyed by muscle ID.
  final Map<String, List<FatigueImpulse>> fatigueLog;

  /// Daily training load entries for ACWR computation.
  final List<DailyLoad> dailyLoads;

  /// Persisted ACWR EWMA state (null before first session ingested).
  final EwmaState? acwrState;

  /// Recent sleep records for readiness scoring.
  final List<SleepRecord> sleepHistory;

  /// Recent HRV records for readiness scoring.
  final List<HrvRecord> hrvHistory;

  /// Heaviest working set per exercise from the most recent session.
  ///
  /// Updated during [TrainingEngine.ingestSession]. Used by [TrainingEngine.recommendLoad]
  /// to determine the last top set without storing full session history.
  final Map<String, LoggedSet> lastTopSets;

  /// Wall-clock time of the last state mutation.
  final DateTime lastUpdated;

  /// How many workout sessions have been ingested into this state.
  final int sessionsIngested;

  /// Wall-clock time of the last HealthKit data fetch, or `null` if never fetched.
  final DateTime? lastHealthKitFetch;

  const TrainingState({
    required this.profile,
    required this.e1rmHistory,
    required this.fatigueLog,
    required this.dailyLoads,
    required this.acwrState,
    required this.sleepHistory,
    required this.hrvHistory,
    required this.lastTopSets,
    required this.lastUpdated,
    required this.sessionsIngested,
    this.lastHealthKitFetch,
  });

  // ---------------------------------------------------------------------------
  // Factory: initial / empty state
  // ---------------------------------------------------------------------------

  /// Creates an empty [TrainingState] for a new [profile].
  factory TrainingState.initial(UserProfile profile) => TrainingState(
        profile: profile,
        e1rmHistory: {},
        fatigueLog: {},
        dailyLoads: [],
        acwrState: null,
        sleepHistory: [],
        hrvHistory: [],
        lastTopSets: {},
        lastUpdated: DateTime.now(),
        sessionsIngested: 0,
        lastHealthKitFetch: null,
      );

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  TrainingState copyWith({
    UserProfile? profile,
    Map<String, List<E1rmEstimate>>? e1rmHistory,
    Map<String, List<FatigueImpulse>>? fatigueLog,
    List<DailyLoad>? dailyLoads,
    // Use a sentinel to allow explicitly passing null for acwrState.
    Object? acwrState = _sentinel,
    List<SleepRecord>? sleepHistory,
    List<HrvRecord>? hrvHistory,
    Map<String, LoggedSet>? lastTopSets,
    DateTime? lastUpdated,
    int? sessionsIngested,
    Object? lastHealthKitFetch = _sentinel,
  }) {
    return TrainingState(
      profile: profile ?? this.profile,
      e1rmHistory: e1rmHistory ?? this.e1rmHistory,
      fatigueLog: fatigueLog ?? this.fatigueLog,
      dailyLoads: dailyLoads ?? this.dailyLoads,
      acwrState: acwrState == _sentinel
          ? this.acwrState
          : acwrState as EwmaState?,
      sleepHistory: sleepHistory ?? this.sleepHistory,
      hrvHistory: hrvHistory ?? this.hrvHistory,
      lastTopSets: lastTopSets ?? this.lastTopSets,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      sessionsIngested: sessionsIngested ?? this.sessionsIngested,
      lastHealthKitFetch: lastHealthKitFetch == _sentinel
          ? this.lastHealthKitFetch
          : lastHealthKitFetch as DateTime?,
    );
  }

  // ---------------------------------------------------------------------------
  // JSON serialisation
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'profile': profile.toJson(),
        'e1rmHistory': e1rmHistory.map(
          (key, list) => MapEntry(key, list.map((e) => e.toJson()).toList()),
        ),
        'fatigueLog': fatigueLog.map(
          (key, list) => MapEntry(key, list.map((e) => e.toJson()).toList()),
        ),
        'dailyLoads': dailyLoads.map((e) => e.toJson()).toList(),
        'acwrState': acwrState?.toJson(),
        'sleepHistory': sleepHistory.map((e) => e.toJson()).toList(),
        'hrvHistory': hrvHistory.map((e) => e.toJson()).toList(),
        'lastTopSets': lastTopSets.map((key, set) => MapEntry(key, set.toJson())),
        'lastUpdated': lastUpdated.toIso8601String(),
        'sessionsIngested': sessionsIngested,
        'lastHealthKitFetch': lastHealthKitFetch?.toIso8601String(),
      };

  factory TrainingState.fromJson(Map<String, dynamic> json) {
    // e1rmHistory
    final e1rmRaw = json['e1rmHistory'] as Map<String, dynamic>;
    final e1rmHistory = e1rmRaw.map(
      (key, value) => MapEntry(
        key,
        (value as List).map((e) => E1rmEstimate.fromJson(e as Map<String, dynamic>)).toList(),
      ),
    );

    // fatigueLog
    final fatigueRaw = json['fatigueLog'] as Map<String, dynamic>;
    final fatigueLog = fatigueRaw.map(
      (key, value) => MapEntry(
        key,
        (value as List).map((e) => FatigueImpulse.fromJson(e as Map<String, dynamic>)).toList(),
      ),
    );

    // lastTopSets — optional for backward compat with older snapshots
    final lastTopSetsRaw = json['lastTopSets'] as Map<String, dynamic>?;
    final lastTopSets = lastTopSetsRaw != null
        ? lastTopSetsRaw.map(
            (key, value) =>
                MapEntry(key, LoggedSet.fromJson(value as Map<String, dynamic>)),
          )
        : <String, LoggedSet>{};

    return TrainingState(
      profile: UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
      e1rmHistory: e1rmHistory,
      fatigueLog: fatigueLog,
      dailyLoads: (json['dailyLoads'] as List)
          .map((e) => DailyLoad.fromJson(e as Map<String, dynamic>))
          .toList(),
      acwrState: json['acwrState'] == null
          ? null
          : EwmaState.fromJson(json['acwrState'] as Map<String, dynamic>),
      sleepHistory: (json['sleepHistory'] as List)
          .map((e) => SleepRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      hrvHistory: (json['hrvHistory'] as List)
          .map((e) => HrvRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastTopSets: lastTopSets,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      sessionsIngested: json['sessionsIngested'] as int,
      lastHealthKitFetch: json['lastHealthKitFetch'] == null
          ? null
          : DateTime.parse(json['lastHealthKitFetch'] as String),
    );
  }
}

// Sentinel object used by copyWith to distinguish "not provided" from null.
const Object _sentinel = Object();
