import 'package:flutter/material.dart';

/// A simple placeholder page used until detailed implementations are
/// developed.  It displays a centred label describing the current
/// screen.  Developers can replace this with real functionality
/// later.
class PlaceholderPage extends StatelessWidget {
  final String title;

  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
    );
  }
}