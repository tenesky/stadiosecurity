import 'package:flutter/material.dart';

import '../models/stadium_point.dart';

/// Visual representation of a [StadiumPoint] on top of the map. This
/// widget draws a coloured circle (neon green when ready, neon red
/// otherwise) and the point's name beneath it. The size of the
/// circle scales with the map's zoom factor because it inherits
/// [Transform] from the wrapping [InteractiveViewer]. When tapped
/// the provided [onToggleReady] callback is invoked which should
/// toggle the readiness state.
class PointWidget extends StatelessWidget {
  final StadiumPoint point;
  /// Called when the point should toggle its ready state. Optional to allow
  /// read‑only roles to omit the callback.
  final VoidCallback? onToggleReady;
  /// Called when the user long‑presses the point. Optional to support
  /// deletion of points for privileged roles.
  final VoidCallback? onLongPress;

  const PointWidget({
    Key? key,
    required this.point,
    this.onToggleReady,
    this.onLongPress,
  }) : super(key: key);

  Color _statusColor(BuildContext context) {
    // Use accent colours that stand out on top of the map. These
    // values approximate a neon appearance without specifying fixed
    // colours in a theme. They can be customised via the app's
    // colour scheme if desired.
    return point.isReady ? Colors.greenAccent : Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggleReady,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _statusColor(context),
              boxShadow: [
                BoxShadow(
                  color: _statusColor(context).withOpacity(0.6),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            point.name,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(0, 0),
                  blurRadius: 3,
                  color: Colors.black,
                )
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}