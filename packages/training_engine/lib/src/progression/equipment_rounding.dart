import '../models/enums.dart';

/// Returns the plate/weight increment for a given [EquipmentClass].
///
/// - barbell: 2.5 kg
/// - dumbbell: 2.0 kg
/// - cable: 2.5 kg
/// - machine: 5.0 kg
/// - bodyweight: no rounding (returns weight as-is)
double roundToEquipment(double weight, EquipmentClass equipment) {
  switch (equipment) {
    case EquipmentClass.bodyweight:
      return weight;
    case EquipmentClass.barbell:
    case EquipmentClass.cable:
      return _roundToNearest(weight, 2.5);
    case EquipmentClass.dumbbell:
      return _roundToNearest(weight, 2.0);
    case EquipmentClass.machine:
      return _roundToNearest(weight, 5.0);
  }
}

double _roundToNearest(double value, double increment) {
  return (value / increment).round() * increment;
}
