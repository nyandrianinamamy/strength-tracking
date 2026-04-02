import 'dart:math';
import 'formulas.dart';
import '../models/models.dart';

/// Weights for each formula by rMax range.
/// Keys correspond to [Epley, Brzycki, Lander, Lombardi].
const _weights1to5 = [0.20, 0.35, 0.30, 0.15];
const _weights6to10 = [0.30, 0.25, 0.25, 0.20];
const _weights11to15 = [0.35, 0.10, 0.30, 0.25];
const _weightsAbove15 = [0.30, 0.05, 0.30, 0.35];

List<double> _weightsForRMax(double rm) {
  if (rm <= 5) return _weights1to5;
  if (rm <= 10) return _weights6to10;
  if (rm <= 15) return _weights11to15;
  return _weightsAbove15;
}

/// Composite e1RM using a weighted average across Epley, Brzycki, Lander,
/// and Lombardi. Formula weights vary by rMax range.
///
/// Returns [weight] directly when rMax <= 1 (single rep max).
double compositeE1rm({
  required double weight,
  required int reps,
  required double rpe,
}) {
  final rm = rMax(reps, rpe);

  if (rm <= 1) return weight;

  final epleyVal = epley(weight, rm);
  final brzyckiVal = brzycki(weight, rm); // null when rm > 30
  final landerVal = lander(weight, rm);
  final lombardiVal = lombardi(weight, rm);

  final rawWeights = _weightsForRMax(rm);
  // Index: 0=Epley, 1=Brzycki, 2=Lander, 3=Lombardi

  double totalWeight = 0;
  double weightedSum = 0;

  void addContribution(double value, double w) {
    weightedSum += value * w;
    totalWeight += w;
  }

  addContribution(epleyVal, rawWeights[0]);
  if (brzyckiVal != null) {
    addContribution(brzyckiVal, rawWeights[1]);
  }
  addContribution(landerVal, rawWeights[2]);
  addContribution(lombardiVal, rawWeights[3]);

  return weightedSum / totalWeight;
}

/// Returns confidence score (0–1) based on rMax.
double estimateConfidence(double rMax) {
  if (rMax <= 5) return 0.95;
  if (rMax <= 10) return 0.80;
  if (rMax <= 15) return 0.60;
  if (rMax <= 20) return 0.40;
  return 0.25;
}

/// Computes a rolling weighted e1RM from a list of [E1rmEstimate]s.
///
/// Weight for each estimate = recency * confidence * legacyPenalty, where:
/// - recency: exponential decay with half-life of 14 days
/// - legacyPenalty: 0.5 if [E1rmEstimate.fromEstimatedRpe], else 1.0
///
/// Returns null for an empty list.
double? rollingE1rm(List<E1rmEstimate> estimates, DateTime now) {
  if (estimates.isEmpty) return null;

  const halfLifeDays = 14.0;
  const ln2 = 0.6931471805599453;
  final decayConstant = ln2 / halfLifeDays;

  double totalWeight = 0;
  double weightedSum = 0;

  for (final est in estimates) {
    final ageDays = now.difference(est.estimatedAt).inSeconds / 86400.0;
    final recency = exp(-decayConstant * ageDays);
    final legacyPenalty = est.fromEstimatedRpe ? 0.5 : 1.0;
    final w = recency * est.confidence * legacyPenalty;

    weightedSum += est.value * w;
    totalWeight += w;
  }

  if (totalWeight == 0) return null;
  return weightedSum / totalWeight;
}
