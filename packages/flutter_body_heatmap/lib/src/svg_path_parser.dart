import 'dart:math' as math;
import 'dart:ui';

/// Parse an SVG path `d` attribute string into a Flutter [Path],
/// with optional scaling and offset.
Path parseSvgPath(
  String d, {
  double scaleX = 1.0,
  double scaleY = 1.0,
  double offsetX = 0.0,
  double offsetY = 0.0,
}) {
  final path = Path();
  final segments = _parsePath(d);

  double cx = 0, cy = 0; // current point
  double sx = 0, sy = 0; // start of subpath
  double lastCx = 0, lastCy = 0; // last control point for S/T
  String lastCmd = '';

  double tx(double x) => (x + offsetX) * scaleX;
  double ty(double y) => (y + offsetY) * scaleY;

  for (final seg in segments) {
    final cmd = seg.command;
    final p = seg.params;

    switch (cmd) {
      case 'M':
        cx = p[0];
        cy = p[1];
        sx = cx;
        sy = cy;
        path.moveTo(tx(cx), ty(cy));
        for (int j = 2; j < p.length; j += 2) {
          cx = p[j];
          cy = p[j + 1];
          path.lineTo(tx(cx), ty(cy));
        }
      case 'm':
        cx += p[0];
        cy += p[1];
        sx = cx;
        sy = cy;
        path.moveTo(tx(cx), ty(cy));
        for (int j = 2; j < p.length; j += 2) {
          cx += p[j];
          cy += p[j + 1];
          path.lineTo(tx(cx), ty(cy));
        }
      case 'L':
        for (int j = 0; j < p.length; j += 2) {
          cx = p[j];
          cy = p[j + 1];
          path.lineTo(tx(cx), ty(cy));
        }
      case 'l':
        for (int j = 0; j < p.length; j += 2) {
          cx += p[j];
          cy += p[j + 1];
          path.lineTo(tx(cx), ty(cy));
        }
      case 'H':
        for (int j = 0; j < p.length; j++) {
          cx = p[j];
          path.lineTo(tx(cx), ty(cy));
        }
      case 'h':
        for (int j = 0; j < p.length; j++) {
          cx += p[j];
          path.lineTo(tx(cx), ty(cy));
        }
      case 'V':
        for (int j = 0; j < p.length; j++) {
          cy = p[j];
          path.lineTo(tx(cx), ty(cy));
        }
      case 'v':
        for (int j = 0; j < p.length; j++) {
          cy += p[j];
          path.lineTo(tx(cx), ty(cy));
        }
      case 'C':
        for (int j = 0; j + 5 < p.length; j += 6) {
          path.cubicTo(
            tx(p[j]),
            ty(p[j + 1]),
            tx(p[j + 2]),
            ty(p[j + 3]),
            tx(p[j + 4]),
            ty(p[j + 5]),
          );
          lastCx = p[j + 2];
          lastCy = p[j + 3];
          cx = p[j + 4];
          cy = p[j + 5];
        }
      case 'c':
        for (int j = 0; j + 5 < p.length; j += 6) {
          final x1 = cx + p[j], y1 = cy + p[j + 1];
          final x2 = cx + p[j + 2], y2 = cy + p[j + 3];
          final x = cx + p[j + 4], y = cy + p[j + 5];
          path.cubicTo(tx(x1), ty(y1), tx(x2), ty(y2), tx(x), ty(y));
          lastCx = x2;
          lastCy = y2;
          cx = x;
          cy = y;
        }
      case 'S':
        for (int j = 0; j + 3 < p.length; j += 4) {
          final rx = _reflectCtrl(lastCmd, lastCx, cx);
          final ry = _reflectCtrl(lastCmd, lastCy, cy);
          path.cubicTo(
            tx(rx),
            ty(ry),
            tx(p[j]),
            ty(p[j + 1]),
            tx(p[j + 2]),
            ty(p[j + 3]),
          );
          lastCx = p[j];
          lastCy = p[j + 1];
          cx = p[j + 2];
          cy = p[j + 3];
          lastCmd = 'S';
        }
      case 's':
        for (int j = 0; j + 3 < p.length; j += 4) {
          final rx = _reflectCtrl(lastCmd, lastCx, cx);
          final ry = _reflectCtrl(lastCmd, lastCy, cy);
          final x2 = cx + p[j], y2 = cy + p[j + 1];
          final x = cx + p[j + 2], y = cy + p[j + 3];
          path.cubicTo(tx(rx), ty(ry), tx(x2), ty(y2), tx(x), ty(y));
          lastCx = x2;
          lastCy = y2;
          cx = x;
          cy = y;
          lastCmd = 's';
        }
      case 'Q':
        for (int j = 0; j + 3 < p.length; j += 4) {
          path.quadraticBezierTo(
            tx(p[j]),
            ty(p[j + 1]),
            tx(p[j + 2]),
            ty(p[j + 3]),
          );
          lastCx = p[j];
          lastCy = p[j + 1];
          cx = p[j + 2];
          cy = p[j + 3];
        }
      case 'q':
        for (int j = 0; j + 3 < p.length; j += 4) {
          final x1 = cx + p[j], y1 = cy + p[j + 1];
          final x = cx + p[j + 2], y = cy + p[j + 3];
          path.quadraticBezierTo(tx(x1), ty(y1), tx(x), ty(y));
          lastCx = x1;
          lastCy = y1;
          cx = x;
          cy = y;
        }
      case 'T':
        for (int j = 0; j + 1 < p.length; j += 2) {
          lastCx = 2 * cx - lastCx;
          lastCy = 2 * cy - lastCy;
          path.quadraticBezierTo(
            tx(lastCx),
            ty(lastCy),
            tx(p[j]),
            ty(p[j + 1]),
          );
          cx = p[j];
          cy = p[j + 1];
        }
      case 't':
        for (int j = 0; j + 1 < p.length; j += 2) {
          lastCx = 2 * cx - lastCx;
          lastCy = 2 * cy - lastCy;
          final x = cx + p[j], y = cy + p[j + 1];
          path.quadraticBezierTo(tx(lastCx), ty(lastCy), tx(x), ty(y));
          cx = x;
          cy = y;
        }
      case 'A' || 'a':
        final isRel = cmd == 'a';
        for (int j = 0; j + 6 < p.length; j += 7) {
          final rx = p[j];
          final ry = p[j + 1];
          final rotation = p[j + 2];
          final largeArc = p[j + 3] != 0;
          final sweep = p[j + 4] != 0;
          final ex = isRel ? cx + p[j + 5] : p[j + 5];
          final ey = isRel ? cx + p[j + 6] : p[j + 6];
          _arcTo(
            path,
            cx,
            cy,
            rx,
            ry,
            rotation,
            largeArc,
            sweep,
            ex,
            ey,
            tx,
            ty,
          );
          cx = ex;
          cy = ey;
        }
      case 'Z' || 'z':
        path.close();
        cx = sx;
        cy = sy;
    }

    // Track last control point for smooth curves
    if (cmd != 'C' &&
        cmd != 'c' &&
        cmd != 'S' &&
        cmd != 's' &&
        cmd != 'Q' &&
        cmd != 'q' &&
        cmd != 'T' &&
        cmd != 't') {
      lastCx = cx;
      lastCy = cy;
    }
    lastCmd = cmd;
  }

  return path;
}

double _reflectCtrl(String lastCmd, double lastCtrl, double current) {
  final upper = lastCmd.toUpperCase();
  if (upper == 'C' || upper == 'S' || upper == 'Q' || upper == 'T') {
    return 2 * current - lastCtrl;
  }
  return current;
}

/// Approximate SVG arc with cubic bezier curves.
void _arcTo(
  Path path,
  double x1,
  double y1,
  double rxIn,
  double ryIn,
  double rotation,
  bool largeArc,
  bool sweep,
  double x2,
  double y2,
  double Function(double) tx,
  double Function(double) ty,
) {
  if (rxIn == 0 || ryIn == 0) {
    path.lineTo(tx(x2), ty(y2));
    return;
  }

  final phi = rotation * math.pi / 180.0;
  final cosPhi = math.cos(phi);
  final sinPhi = math.sin(phi);

  final dx2 = (x1 - x2) / 2.0;
  final dy2 = (y1 - y2) / 2.0;

  final x1p = cosPhi * dx2 + sinPhi * dy2;
  final y1p = -sinPhi * dx2 + cosPhi * dy2;

  var rx = rxIn.abs();
  var ry = ryIn.abs();

  final x1pSq = x1p * x1p;
  final y1pSq = y1p * y1p;
  var rxSq = rx * rx;
  var rySq = ry * ry;

  // Check if radii are large enough
  final lambda = x1pSq / rxSq + y1pSq / rySq;
  if (lambda > 1) {
    final lambdaSqrt = math.sqrt(lambda);
    rx *= lambdaSqrt;
    ry *= lambdaSqrt;
    rxSq = rx * rx;
    rySq = ry * ry;
  }

  var sq =
      ((rxSq * rySq - rxSq * y1pSq - rySq * x1pSq) /
          (rxSq * y1pSq + rySq * x1pSq));
  if (sq < 0) sq = 0;
  final root = math.sqrt(sq) * (largeArc == sweep ? -1 : 1);

  final cxp = root * rx * y1p / ry;
  final cyp = -root * ry * x1p / rx;

  final cx = cosPhi * cxp - sinPhi * cyp + (x1 + x2) / 2.0;
  final cy = sinPhi * cxp + cosPhi * cyp + (y1 + y2) / 2.0;

  final theta1 = _angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry);
  var dtheta = _angle(
    (x1p - cxp) / rx,
    (y1p - cyp) / ry,
    (-x1p - cxp) / rx,
    (-y1p - cyp) / ry,
  );

  if (!sweep && dtheta > 0) {
    dtheta -= 2 * math.pi;
  } else if (sweep && dtheta < 0) {
    dtheta += 2 * math.pi;
  }

  // Split arc into segments of at most pi/2
  final segments = (dtheta.abs() / (math.pi / 2)).ceil();
  final delta = dtheta / segments;

  for (int i = 0; i < segments; i++) {
    final t1 = theta1 + i * delta;
    final t2 = theta1 + (i + 1) * delta;
    _arcSegment(path, cx, cy, rx, ry, phi, t1, t2, tx, ty);
  }
}

void _arcSegment(
  Path path,
  double cx,
  double cy,
  double rx,
  double ry,
  double phi,
  double theta1,
  double theta2,
  double Function(double) tx,
  double Function(double) ty,
) {
  final alpha =
      math.sin(theta2 - theta1) *
      (math.sqrt(4 + 3 * math.tan((theta2 - theta1) / 2) * math.tan((theta2 - theta1) / 2)) - 1) /
      3.0;

  final cosTheta1 = math.cos(theta1);
  final sinTheta1 = math.sin(theta1);
  final cosTheta2 = math.cos(theta2);
  final sinTheta2 = math.sin(theta2);
  final cosPhi = math.cos(phi);
  final sinPhi = math.sin(phi);

  double ex(double cosT, double sinT) =>
      cosPhi * rx * cosT - sinPhi * ry * sinT + cx;
  double ey(double cosT, double sinT) =>
      sinPhi * rx * cosT + cosPhi * ry * sinT + cy;
  double edx(double cosT, double sinT) =>
      -cosPhi * rx * sinT - sinPhi * ry * cosT;
  double edy(double cosT, double sinT) =>
      -sinPhi * rx * sinT + cosPhi * ry * cosT;

  final p1x = ex(cosTheta1, sinTheta1);
  final p1y = ey(cosTheta1, sinTheta1);
  final p2x = ex(cosTheta2, sinTheta2);
  final p2y = ey(cosTheta2, sinTheta2);

  final dx1 = edx(cosTheta1, sinTheta1);
  final dy1 = edy(cosTheta1, sinTheta1);
  final dx2 = edx(cosTheta2, sinTheta2);
  final dy2 = edy(cosTheta2, sinTheta2);

  path.cubicTo(
    tx(p1x + alpha * dx1),
    ty(p1y + alpha * dy1),
    tx(p2x - alpha * dx2),
    ty(p2y - alpha * dy2),
    tx(p2x),
    ty(p2y),
  );
}

double _angle(double ux, double uy, double vx, double vy) {
  final n = math.sqrt(ux * ux + uy * uy) * math.sqrt(vx * vx + vy * vy);
  if (n == 0) return 0;
  var c = (ux * vx + uy * vy) / n;
  c = c.clamp(-1.0, 1.0);
  final angle = math.acos(c);
  return (ux * vy - uy * vx < 0) ? -angle : angle;
}

class _PathSegment {
  const _PathSegment(this.command, this.params);
  final String command;
  final List<double> params;
}

List<_PathSegment> _parsePath(String d) {
  final segments = <_PathSegment>[];
  final re = RegExp(r'([MmLlHhVvCcSsQqTtAaZz])([^MmLlHhVvCcSsQqTtAaZz]*)');

  for (final match in re.allMatches(d)) {
    final cmd = match.group(1)!;
    final paramStr = match.group(2)!.trim();
    final params = <double>[];

    if (paramStr.isNotEmpty) {
      // Parse numbers (handle negatives, decimals, comma/space separated)
      final numRe = RegExp(r'[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?');
      for (final numMatch in numRe.allMatches(paramStr)) {
        params.add(double.parse(numMatch.group(0)!));
      }
    }

    segments.add(_PathSegment(cmd, params));
  }

  return segments;
}
