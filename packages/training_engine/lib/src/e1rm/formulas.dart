import 'dart:math';

/// Returns Reps In Reserve from RPE (Rate of Perceived Exertion).
double rirFromRpe(double rpe) => 10.0 - rpe;

/// Returns the total reps-to-max (rMax) given performed reps and RPE.
double rMax(int reps, double rpe) => reps + rirFromRpe(rpe);

/// Epley e1RM formula.
double epley(double weight, double rMax) => weight * (1 + rMax / 30);

/// Brzycki e1RM formula. Returns null when rMax > 30 (formula breaks down).
double? brzycki(double weight, double rMax) {
  if (rMax > 30) return null;
  return weight * (36 / (37 - rMax));
}

/// Lander e1RM formula.
double lander(double weight, double rMax) =>
    (100 * weight) / (101.3 - 2.67123 * rMax);

/// Lombardi e1RM formula.
double lombardi(double weight, double rMax) => weight * pow(rMax, 0.10);
