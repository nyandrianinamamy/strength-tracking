/// Raw SVG path data for a body part.
class BodyPartData {
  const BodyPartData({
    required this.slug,
    this.commonPaths = const [],
    this.leftPaths = const [],
    this.rightPaths = const [],
  });

  final String slug;
  final List<String> commonPaths;
  final List<String> leftPaths;
  final List<String> rightPaths;
}
