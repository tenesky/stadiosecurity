import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../services/db_service.dart';

/// Displays a detailed overview of a single stadium.  This page shows
/// the stadium's basic information (name, address, default leader and
/// club) and all associated maps.  If multiple maps are present,
/// they are displayed in a tabbed view so users can switch between
/// them easily.
class StadiumDetailPage extends StatefulWidget {
  /// Map representing the stadium record.  It must include at least
  /// the `id`, `name`, `address`, `default_leader` and
  /// `default_club` fields.
  final Map<String, dynamic> stadium;

  const StadiumDetailPage({super.key, required this.stadium});

  @override
  State<StadiumDetailPage> createState() => _StadiumDetailPageState();
}

class _StadiumDetailPageState extends State<StadiumDetailPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  List<Map<String, dynamic>> _maps = [];

  /// Controller used to drive the fixed set of tabs for plans,
  /// contacts, documents and checklists.  Using a
  /// [SingleTickerProviderStateMixin] allows this widget to provide
  /// a suitable vsync for the controller.
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Initialize the tab controller with four tabs.  The vsync comes
    // from the SingleTickerProviderStateMixin mixed into this class.
    _tabController = TabController(length: 4, vsync: this);
    _loadMaps();
  }

  @override
  void dispose() {
    // Dispose the tab controller to release resources when the page
    // is destroyed.  Failing to dispose controllers can lead to
    // memory leaks or unwanted animations continuing in the
    // background.
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMaps() async {
    setState(() => _loading = true);
    final maps = await DbService.getStadiumMaps(widget.stadium['id'] as int);
    if (!mounted) return;
    setState(() {
      _maps = maps;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stadium = widget.stadium;
    return Scaffold(
      appBar: AppBar(
        title: Text('Stadion: ${stadium['name']}'),
        backgroundColor: const Color(0xFF78B1C6),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Basic information about the stadium
                  Text(
                    stadium['name'] as String,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  if (stadium['address'] != null && stadium['address'] != '')
                    Text('Adresse: ${stadium['address']}'),
                  if (stadium['default_leader'] != null && stadium['default_leader'] != '')
                    Text('Standard-Einsatzleiter: ${stadium['default_leader']}'),
                  if (stadium['default_leader_phone'] != null && stadium['default_leader_phone'] != '')
                    Text('Telefon: ${stadium['default_leader_phone']}'),
                  if (stadium['default_leader_email'] != null && stadium['default_leader_email'] != '')
                    Text('E-Mail: ${stadium['default_leader_email']}'),
                  if (stadium['default_club'] != null && stadium['default_club'] != '')
                    Text('Standard-Verein: ${stadium['default_club']}'),
                  const SizedBox(height: 16),
                  // Tabbed content: the stadium details page shows four
                  // fixed tabs: plans, contacts, documents and checklists.
                  Expanded(
                    child: Column(
                      children: [
                        TabBar(
                          controller: _tabController,
                          isScrollable: false,
                          tabs: const [
                            Tab(text: 'Stadionpläne'),
                            Tab(text: 'Ansprechpartner'),
                            Tab(text: 'Dokumente'),
                            Tab(text: 'Checklisten'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildPlansTab(),
                              _buildContactsTab(),
                              _buildDocumentsTab(),
                              _buildChecklistsTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Builds the "Stadionpläne" tab.  This displays a list of all
  /// maps associated with the stadium.  Each entry shows the map
  /// name along with its upload time (if it can be determined).
  /// Tapping an entry opens a full screen preview.
  Widget _buildPlansTab() {
    // When there are no plans, show a friendly message.  This avoids
    // showing an empty list which could be confusing to users.
    if (_maps.isEmpty) {
      return const Center(
        child: Text('Keine Lagepläne vorhanden'),
      );
    }
    return ListView.separated(
      itemCount: _maps.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final map = _maps[index];
        final String name = map['map_name'] as String;
        final String uploadTime = _formatMapTime(map);
        return ListTile(
          title: Text(name),
          subtitle: uploadTime.isNotEmpty ? Text('Hochgeladen: $uploadTime') : null,
          // Show a small preview for image-based plans and an icon for PDFs or
          // unknown file types.  When binary data is available and the
          // extension indicates an image, a thumbnail is rendered directly
          // from the bytes using Image.memory.  Otherwise a generic icon is
          // displayed.  This provides a richer overview of uploaded plans
          // without requiring the user to tap each entry.
          leading: (() {
            final lower = name.toLowerCase();
            // Always display a PDF icon for documents with a .pdf extension.
            if (lower.endsWith('.pdf')) {
              return const Icon(Icons.picture_as_pdf);
            }
            // Attempt to show a thumbnail for images from binary data.  This
            // covers maps that were saved locally and loaded from disk or
            // decoded from base64.  Only non-empty Uint8List data is
            // rendered to avoid errors when data is null or empty.
            final dynamic data = map['map_data'];
            if (data is Uint8List && data.isNotEmpty) {
              return Image.memory(
                data,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              );
            }
            // If no local data is available but a remote URL exists (e.g. a
            // Firebase download URL), display the image from the network.
            final String? mapUrl = map['map_url'] as String?;
            if (mapUrl != null && mapUrl.isNotEmpty) {
              // Only attempt to preview images; PDFs are handled by the
              // extension check above.  The Image.network constructor
              // automatically handles caching and loading indicators.
              return Image.network(
                mapUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              );
            }
            // Fallback icon when no preview is available.
            return const Icon(Icons.insert_drive_file);
          })(),
          onTap: () => _openMap(map),
        );
      },
    );
  }

  /// Builds the "Ansprechpartner" tab.  This displays the default
  /// leader, phone number, email and club associated with the stadium.
  /// If none of these fields are present, a message is shown.
  Widget _buildContactsTab() {
    final stadium = widget.stadium;
    final List<Widget> items = [];
    if (stadium['default_leader'] != null && stadium['default_leader'] != '') {
      items.add(Text('Einsatzleiter: ${stadium['default_leader']}'));
    }
    if (stadium['default_leader_phone'] != null && stadium['default_leader_phone'] != '') {
      items.add(Text('Telefon: ${stadium['default_leader_phone']}'));
    }
    if (stadium['default_leader_email'] != null && stadium['default_leader_email'] != '') {
      items.add(Text('E-Mail: ${stadium['default_leader_email']}'));
    }
    if (stadium['default_club'] != null && stadium['default_club'] != '') {
      items.add(Text('Verein: ${stadium['default_club']}'));
    }
    if (items.isEmpty) {
      return const Center(
        child: Text('Keine Ansprechpartner vorhanden'),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items) ...[
            item,
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  /// Placeholder for the "Dokumente" tab.  In a future iteration,
  /// additional documents (beyond stadium plans) could be displayed
  /// here.  Currently this displays a simple message.
  Widget _buildDocumentsTab() {
    return const Center(
      child: Text('Keine Dokumente vorhanden'),
    );
  }

  /// Placeholder for the "Checklisten" tab.  Checklists related to
  /// stadium operations could be added in the future.  Currently this
  /// displays a simple message.
  Widget _buildChecklistsTab() {
    return const Center(
      child: Text('Keine Checklisten vorhanden'),
    );
  }

  /// Opens the selected map in a full screen view.  The preview
  /// supports zooming via [InteractiveViewer] for image formats.
  void _openMap(Map<String, dynamic> map) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenMapPage(map: map),
      ),
    );
  }

  /// Attempts to derive an upload timestamp for a map.  The
  /// timestamp is extracted from the saved file name in `map_path`,
  /// which is generated by [DbService.uploadPlanFile] and includes a
  /// millisecond epoch prefix (e.g. `1681234567890_filename.png`).  If
  /// no timestamp can be parsed, the method falls back to reading the
  /// file's last modified time.  If neither approach succeeds, an
  /// empty string is returned.
  String _formatMapTime(Map<String, dynamic> map) {
    final String? filePath = map['map_path'] as String?;
    if (filePath != null) {
      try {
        // Extract the base file name (e.g. 1681234567890_name.pdf).
        // Because [filePath] may use either forward slashes or backslashes
        // (depending on operating system or the format stored in the
        // database), split on both separators via a regex and grab the
        // final component.
        final List<String> partsPath = filePath.split(RegExp(r'[\\/]'));
        final String base = partsPath.isNotEmpty ? partsPath.last : filePath;
        final List<String> parts = base.split('_');
        if (parts.isNotEmpty) {
          final String tsString = parts.first;
          if (RegExp(r'^\d{13}\$').hasMatch(tsString)) {
            final int? millis = int.tryParse(tsString);
            if (millis != null) {
              final DateTime dt = DateTime.fromMillisecondsSinceEpoch(millis);
              return _formatDateTime(dt);
            }
          }
        }
        // Fall back to the file system's last modified time
        final File f = File(filePath);
        if (f.existsSync()) {
          final DateTime mod = f.lastModifiedSync();
          return _formatDateTime(mod);
        }
      } catch (_) {
        // Ignore any errors during timestamp parsing
      }
    }
    return '';
  }

  /// Formats a [DateTime] into a human readable string.  This helper
  /// avoids introducing a dependency on the intl package.  The
  /// resulting format is `DD.MM.YYYY HH:MM`.
  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    final day = two(dt.day);
    final month = two(dt.month);
    final year = dt.year.toString();
    final hour = two(dt.hour);
    final minute = two(dt.minute);
    return '$day.$month.$year $hour:$minute';
  }
}

/// A full screen page that displays a single stadium map.  For image
/// formats, the preview supports pinch and scroll zooming via
/// [InteractiveViewer].  For PDF files, a placeholder icon and
/// message are shown since PDF rendering is not supported in this
/// lightweight example.
class _FullScreenMapPage extends StatelessWidget {
  final Map<String, dynamic> map;

  const _FullScreenMapPage({required this.map});

  @override
  Widget build(BuildContext context) {
    final String name = map['map_name'] as String;
    final String lower = name.toLowerCase();
    final String? path = map['map_path'] as String?;
    final String? url = map['map_url'] as String?;
    final Uint8List? data = map['map_data'] as Uint8List?;

    Widget buildContent() {
      // Attempt to display using the local file path when provided. If
      // the file does not exist on disk, fall back to the in-memory
      // bytes if available.
      if (path != null) {
        final file = File(path);
        if (file.existsSync()) {
          if (lower.endsWith('.pdf')) {
            // Use pdfrx to render local PDF files.  PdfViewer.file
            // automatically handles zooming and paging.  If the file
            // cannot be opened, a placeholder icon will be shown via
            // fallback below.
            return PdfViewer.file(path);
          }
          return InteractiveViewer(
            child: Image.file(file, fit: BoxFit.contain),
          );
        }
        // If the file does not exist but we have the binary data, use it.
        if (data != null && !lower.endsWith('.pdf')) {
          return InteractiveViewer(
            child: Image.memory(data, fit: BoxFit.contain),
          );
        }
      }
      // Remote URL
      if (url != null) {
        if (lower.endsWith('.pdf')) {
          // For PDF URLs, attempt to render using PdfViewer.uri.  If
          // rendering fails (e.g. due to CORS or unsupported scheme) the
          // widget will show an error; in such cases a placeholder is
          // acceptable.  Since PdfViewer.uri requires a Uri, construct it.
          try {
            return PdfViewer.uri(Uri.parse(url));
          } catch (_) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.picture_as_pdf, size: 96),
                SizedBox(height: 16),
                Text('PDF Datei – Vorschau nicht verfügbar'),
              ],
            );
          }
        }
        return InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        );
      }
      // Raw binary data
      if (data != null) {
        if (lower.endsWith('.pdf')) {
          // For PDF binary data, render directly from memory using
          // PdfViewer.data.  If rendering fails, fall back to a
          // placeholder widget.  The sourceName helps pdfrx display a
          // helpful title in its built‑in UI.
          try {
            return PdfViewer.data(data, sourceName: name);
          } catch (_) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.picture_as_pdf, size: 96),
                SizedBox(height: 16),
                Text('PDF Datei – Vorschau nicht verfügbar'),
              ],
            );
          }
        }
        return InteractiveViewer(
          child: Image.memory(data, fit: BoxFit.contain),
        );
      }
      // Fallback
      return const Center(
        child: Text('Kein Vorschau verfügbar'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        backgroundColor: const Color(0xFF78B1C6),
        foregroundColor: Colors.white,
      ),
      body: Center(child: buildContent()),
    );
  }
}