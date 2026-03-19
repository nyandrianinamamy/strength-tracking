# flutter_body_heatmap

A Flutter widget to display an interactive human body heatmap with highlightable muscle regions. Supports male and female body types, front and back views, left/right muscle sides, and customizable color scales.

**Zero external dependencies** — uses only Flutter SDK.

## Features

- 23 anatomical muscle regions
- Male and female body silhouettes
- Front and back views
- Left/right side highlighting for bilateral muscles
- Continuous color interpolation from intensity values
- Tap callback per muscle region
- Body outline border (optional)
- Pure `CustomPaint` rendering

## Usage

```dart
import 'package:flutter_body_heatmap/flutter_body_heatmap.dart';

BodyHeatmap(
  side: BodySide.front,
  gender: BodyGender.male,
  data: {
    Muscle.chest: MuscleData(intensity: 0.8),
    Muscle.biceps: MuscleData(intensity: 0.5),
    Muscle.quadriceps: MuscleData(intensity: 0.3, side: MuscleSide.left),
  },
  colors: [Colors.blue, Colors.green, Colors.yellow, Colors.red],
  bodyColor: Color(0xFFE2E8F0),
  borderColor: Color(0xFFDFDFDF),
  onMusclePressed: (muscle, side) {
    print('Tapped $muscle ($side)');
  },
)
```

## Available Muscles

| Muscle | Slug | Front | Back |
|--------|------|-------|------|
| Abs | `abs` | yes | |
| Adductors | `adductors` | yes | yes |
| Ankles | `ankles` | yes | yes |
| Biceps | `biceps` | yes | |
| Calves | `calves` | yes | yes |
| Chest | `chest` | yes | |
| Deltoids | `deltoids` | yes | yes |
| Feet | `feet` | yes | yes |
| Forearm | `forearm` | yes | yes |
| Gluteal | `gluteal` | | yes |
| Hamstring | `hamstring` | | yes |
| Hands | `hands` | yes | yes |
| Hair | `hair` | yes | yes |
| Head | `head` | yes | yes |
| Knees | `knees` | yes | yes |
| Lower Back | `lower-back` | | yes |
| Neck | `neck` | yes | yes |
| Obliques | `obliques` | yes | |
| Quadriceps | `quadriceps` | yes | |
| Tibialis | `tibialis` | yes | |
| Trapezius | `trapezius` | yes | yes |
| Triceps | `triceps` | yes | yes |
| Upper Back | `upper-back` | | yes |

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `side` | `BodySide` | `front` | Front or back view |
| `gender` | `BodyGender` | `male` | Male or female body shape |
| `data` | `Map<Muscle, MuscleData>` | `{}` | Muscle highlight data |
| `colors` | `List<Color>` | blue scale | Color gradient for intensity |
| `bodyColor` | `Color` | `#3F3F3F` | Default body color when not highlighted |
| `borderColor` | `Color` | `#DFDFDF` | Body outline color |
| `showBorder` | `bool` | `true` | Whether to show body outline |
| `onMusclePressed` | `Function?` | `null` | Callback when a muscle is tapped |

## MuscleData

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `intensity` | `double` | `1.0` | Value from 0.0 to 1.0, mapped to color scale |
| `color` | `Color?` | `null` | Override color (ignores color scale) |
| `side` | `MuscleSide` | `both` | Highlight left, right, or both sides |

## Credits

Body SVG data sourced from [react-native-body-highlighter](https://github.com/HichamELBSI/react-native-body-highlighter) by [HichamELBSI](https://github.com/HichamELBSI), licensed under MIT.

## License

MIT
