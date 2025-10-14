import 'package:flutter/material.dart';

import '../models/stadium_point.dart';
import '../models/stadium_area.dart';

/// A widget that displays a stadium plan and draws interactive points on top.
///
/// The map image is never stretched: it is shown at its original resolution
/// (or scaled down to fit the available space) and centered horizontally
/// and vertically. Any unused space is filled with a white background.
/// Points are specified in relative coordinates (0..1, 0..1) and are mapped
/// to absolute pixel positions within the displayed image. Markers are
/// drawn as coloured circles with labels centred beneath them. The
/// [onTogglePoint] and [onLongPressPoint] callbacks allow parent widgets
/// to respond to taps and long presses on markers (e.g. to toggle status
/// or delete points).
class StadiumMap extends StatelessWidget {
  /// Path to the image asset representing the stadium plan. Must be
  /// registered in `pubspec.yaml`.
  final String imageAsset;

  /// List of points to display on the map. Each point's position is
  /// interpreted as a fraction (0..1) of the map's width and height.
  final List<StadiumPoint> points;

  /// List of areas to draw as polygons on the map. Each area defines a
  /// list of vertex positions per map. The area is drawn with its
  /// assigned colour and a fixed opacity. Defaults to an empty list.
  final List<StadiumArea> areas;

  /// Callback when the user taps a point. If `null`, points cannot be
  /// toggled (useful for read‑only roles).
  final ValueChanged<StadiumPoint>? onTogglePoint;

  /// Callback when the user long‑presses a point. If `null`, points cannot be
  /// removed.
  final ValueChanged<StadiumPoint>? onLongPressPoint;

  /// Callback when the user taps the status marker of an area. If `null`,
  /// area readiness cannot be toggled.
  final ValueChanged<StadiumArea>? onToggleArea;

  /// Optional original width of the image in pixels. When provided with
  /// [originalHeight], the map will be displayed at its original size (or
  /// scaled down if the container is smaller) and centred in the available
  /// space. If not provided, the map will fill the entire space and may
  /// become distorted if the aspect ratio differs from the container.
  final double? originalWidth;

  /// Optional original height of the image in pixels. See [originalWidth].
  final double? originalHeight;

  /// Optional aspect ratio (width / height) of the image. Used only when
  /// [originalWidth] and [originalHeight] are not provided. Maintains
  /// letterboxing if the container ratio differs from this ratio.
  final double? aspectRatio;

  /// Index of the current stadium plan. Determines which coordinate from
  /// [StadiumPoint.positions] to use when drawing points. Defaults to 0
  /// if not specified. If a point has fewer positions than this index,
  /// the first position will be used.
  final int mapIndex;

  const StadiumMap({
    Key? key,
    required this.imageAsset,
    required this.points,
    this.onTogglePoint,
    this.onLongPressPoint,
    this.onToggleArea,
    this.originalWidth,
    this.originalHeight,
    this.aspectRatio,
    this.mapIndex = 0,
    this.areas = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double containerWidth = constraints.maxWidth;
        final double containerHeight = constraints.maxHeight;
        double imageWidth;
        double imageHeight;
        double offsetX = 0;
        double offsetY = 0;

        if (originalWidth != null && originalHeight != null) {
          // Scale the image down to fit into the container while preserving
          // its original aspect ratio. Never scale up beyond original size.
          final double scaleFactor = [
            containerWidth / originalWidth!,
            containerHeight / originalHeight!,
            1.0
          ].reduce((a, b) => a < b ? a : b);
          imageWidth = originalWidth! * scaleFactor;
          imageHeight = originalHeight! * scaleFactor;
          offsetX = (containerWidth - imageWidth) / 2;
          offsetY = (containerHeight - imageHeight) / 2;
        } else if (aspectRatio != null) {
          // Use the provided aspect ratio to letterbox the image if the
          // container's aspect ratio differs.
          final double ratio = aspectRatio!;
          final double containerRatio = containerWidth / containerHeight;
          if (containerRatio > ratio) {
            imageHeight = containerHeight;
            imageWidth = imageHeight * ratio;
            offsetX = (containerWidth - imageWidth) / 2;
          } else {
            imageWidth = containerWidth;
            imageHeight = imageWidth / ratio;
            offsetY = (containerHeight - imageHeight) / 2;
          }
        } else {
          // Fallback: fill entire space (may distort image if aspect ratio
          // differs). In this case there is no letterbox offset.
          imageWidth = containerWidth;
          imageHeight = containerHeight;
        }

        return Stack(
          children: [
            // White background to fill the entire container. This ensures
            // letterbox areas appear white rather than transparent.
            Positioned.fill(
              child: Container(color: Colors.white),
            ),
            // Stadium image positioned within the calculated letterbox area.
            Positioned(
              left: offsetX,
              top: offsetY,
              width: imageWidth,
              height: imageHeight,
              child: Image.asset(
                imageAsset,
                fit: BoxFit.fill,
              ),
            ),
            // Draw areas as polygons with semi-transparent fill.
            // Each area uses its own colour with a fixed alpha.
            if (areas.isNotEmpty)
              Positioned.fill(
                child: CustomPaint(
                  painter: _AreaPainter(
                    areas: areas,
                    offsetX: offsetX,
                    offsetY: offsetY,
                    imageWidth: imageWidth,
                    imageHeight: imageHeight,
                    mapIndex: mapIndex,
                  ),
                ),
              ),
            // Draw each point: compute absolute pixel coordinates relative
            // to the image (not container) and then offset by the letterbox
            // offsets. Marker size and label width are accounted for so
            // that the circle is centred exactly at the coordinate.
            ...points.map((point) {
              // Select the appropriate coordinate for the current map. If
              // the point does not have enough entries in its positions
              // list, fall back to the first coordinate.
              final Offset coord = (point.positions.length > mapIndex)
                  ? point.positions[mapIndex]
                  : (point.positions.isNotEmpty
                      ? point.positions[0]
                      : const Offset(0, 0));
              final double cx = offsetX + coord.dx * imageWidth;
              final double cy = offsetY + coord.dy * imageHeight;

              // Compute label width to centre the text below the marker.
              const textStyle = TextStyle(
                fontSize: 10,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(0, 0),
                    blurRadius: 3,
                    color: Colors.black,
                  ),
                ],
              );
              final textSpan = TextSpan(text: point.name, style: textStyle);
              final textPainter = TextPainter(
                text: textSpan,
                maxLines: 1,
                textDirection: TextDirection.ltr,
              )..layout();
              final double labelWidth = textPainter.width;
              const double markerSize = 24.0;
              const double markerRadius = markerSize / 2.0;

              return Stack(
                children: [
                  // Marker circle centred at (cx, cy)
                  Positioned(
                    left: cx - markerRadius,
                    top: cy - markerRadius,
                    child: GestureDetector(
                      onTap: onTogglePoint != null
                          ? () => onTogglePoint!(point)
                          : null,
                      onLongPress: onLongPressPoint != null
                          ? () => onLongPressPoint!(point)
                          : null,
                      child: Container(
                        width: markerSize,
                        height: markerSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: point.isReady
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          boxShadow: [
                            BoxShadow(
                              color: (point.isReady
                                      ? Colors.greenAccent
                                      : Colors.redAccent)
                                  .withOpacity(0.6),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Label centred under the marker
                  Positioned(
                    left: cx - labelWidth / 2,
                    top: cy + markerRadius + 2,
                    child: Text(point.name, style: textStyle),
                  ),
                ],
              );
            }),
            // Draw a status marker and label for each area. The marker is
            // positioned at the centroid of the polygon defined by the
            // area's vertices for the current map. Tapping the marker
            // toggles the area's readiness state via the onToggleArea
            // callback if provided.
            ...areas.map((area) {
              // Skip if there are no vertices for this map.
              List<Offset> vertices;
              if (area.positions.isNotEmpty) {
                if (area.positions.length > mapIndex && area.positions[mapIndex].isNotEmpty) {
                  vertices = area.positions[mapIndex];
                } else {
                  // Fallback: use the first set of vertices if current map has none
                  vertices = area.positions[0];
                }
              } else {
                vertices = [];
              }
              if (vertices.isEmpty) {
                return const SizedBox.shrink();
              }
              // Compute centroid of the polygon (simple average of vertices).
              double sumX = 0;
              double sumY = 0;
              for (final v in vertices) {
                sumX += v.dx;
                sumY += v.dy;
              }
              final double avgX = sumX / vertices.length;
              final double avgY = sumY / vertices.length;
              final double cx = offsetX + avgX * imageWidth;
              final double cy = offsetY + avgY * imageHeight;
              // Text style for area labels
              const textStyle = TextStyle(
                fontSize: 10,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(0, 0),
                    blurRadius: 3,
                    color: Colors.black,
                  ),
                ],
              );
              final textSpan = TextSpan(text: area.name, style: textStyle);
              final textPainter = TextPainter(
                text: textSpan,
                maxLines: 1,
                textDirection: TextDirection.ltr,
              )..layout();
              final double labelWidth = textPainter.width;
              const double markerSize = 24.0;
              const double markerRadius = markerSize / 2.0;
              return Stack(
                children: [
                  Positioned(
                    left: cx - markerRadius,
                    top: cy - markerRadius,
                    child: GestureDetector(
                      onTap: onToggleArea != null ? () => onToggleArea!(area) : null,
                      child: Container(
                        width: markerSize,
                        height: markerSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: area.isReady ? Colors.greenAccent : Colors.redAccent,
                          boxShadow: [
                            BoxShadow(
                              color: (area.isReady
                                      ? Colors.greenAccent
                                      : Colors.redAccent)
                                  .withOpacity(0.6),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: cx - labelWidth / 2,
                    top: cy + markerRadius + 2,
                    child: Text(area.name, style: textStyle),
                  ),
                ],
              );
            }),
          ],
        );
      },
    );
  }
}

/// A custom painter that draws polygons for areas on the stadium map.
class _AreaPainter extends CustomPainter {
  final List<StadiumArea> areas;
  final double offsetX;
  final double offsetY;
  final double imageWidth;
  final double imageHeight;
  final int mapIndex;

  _AreaPainter({
    required this.areas,
    required this.offsetX,
    required this.offsetY,
    required this.imageWidth,
    required this.imageHeight,
    required this.mapIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final area in areas) {
      // Skip if there are no positions for this map or fewer than 3 vertices.
      if (area.positions.length <= mapIndex ||
          area.positions[mapIndex].length < 3) {
        continue;
      }
      final vertices = area.positions[mapIndex];
      final path = Path();
      for (int i = 0; i < vertices.length; i++) {
        final vertex = vertices[i];
        final x = offsetX + vertex.dx * imageWidth;
        final y = offsetY + vertex.dy * imageHeight;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      final color = Color(area.colorValue);
      final paint = Paint()
        ..style = PaintingStyle.fill
        // Increase opacity of area fill so that areas are more visible.
        ..color = color.withOpacity(0.6);
      canvas.drawPath(path, paint);
      final outlinePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = color.withOpacity(0.8);
      canvas.drawPath(path, outlinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}