import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../services/db_service.dart';
import 'stadium_detail_page.dart';

/// Page for managing stadiums.  When selected from the navigation
/// ('Stadien'), this page presents tabs for managing existing
/// stadiums and for creating new ones.
class StadiumPage extends StatefulWidget {
  const StadiumPage({super.key});

  @override
  State<StadiumPage> createState() => _StadiumPageState();
}

class _StadiumPageState extends State<StadiumPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loadingStadiums = true;
  List<Map<String, dynamic>> _stadiums = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStadiums();
  }

  Future<void> _loadStadiums() async {
    setState(() => _loadingStadiums = true);
    final stadia = await DbService.getStadiums();
    setState(() {
      _stadiums = stadia;
      _loadingStadiums = false;
    });
  }

  void _showDeleteStadiumDialog(Map<String, dynamic> stadium) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stadion löschen'),
        content: Text('Möchtest du das Stadion ${stadium['name']} wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DbService.deleteStadium(stadium['id'] as int);
      await _loadStadiums();
    }
  }

  void _showStadiumForm({Map<String, dynamic>? stadium}) async {
    final bool isEditing = stadium != null;
    final TextEditingController nameController = TextEditingController(text: stadium?['name'] ?? '');
    final TextEditingController addressController = TextEditingController(text: stadium?['address'] ?? '');
    final TextEditingController leaderController = TextEditingController(text: stadium?['default_leader'] ?? '');
    final TextEditingController leaderPhoneController = TextEditingController(text: stadium?['default_leader_phone'] ?? '');
    final TextEditingController leaderEmailController = TextEditingController(text: stadium?['default_leader_email'] ?? '');
    final TextEditingController clubController = TextEditingController(text: stadium?['default_club'] ?? '');

    // Load existing maps if editing
    List<Map<String, dynamic>> existingMaps = [];
    if (isEditing) {
      existingMaps = await DbService.getStadiumMaps(stadium['id'] as int);
    }
    List<Map<String, dynamic>> newMaps = [];
    // Local list to track maps that should be removed when editing
    final List<int> mapsToRemove = [];

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          Future<void> pickFiles() async {
            // Allow selection of images and PDF documents.  Using FileType.custom
            // with explicit extensions ensures that both images and PDFs can
            // be uploaded.
            final result = await FilePicker.platform.pickFiles(
              allowMultiple: true,
              type: FileType.custom,
              allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf'],
              withData: true,
            );
            if (result != null) {
              for (final file in result.files) {
                List<int>? bytes;
                // Prefer bytes from the picker, otherwise read from disk via path.
                if (file.bytes != null) {
                  bytes = file.bytes;
                } else if (file.path != null) {
                  try {
                    bytes = await File(file.path!).readAsBytes();
                  } catch (_) {}
                }
                if (bytes != null) {
                  // Always store map data as a Uint8List so that the DbService
                  // can properly encode or upload it later.  Converting here
                  // avoids accidental stringification of the list when passed
                  // through json or mysql1 which would corrupt the image.
                  final Uint8List u8 = Uint8List.fromList(bytes);
                  newMaps.add({
                    // Default map name is the file name; users can rename later.
                    'name': file.name,
                    'data': u8,
                  });
                }
              }
              setStateDialog(() {});
            }
          }

          return AlertDialog(
            title: Text(isEditing ? 'Stadion bearbeiten' : 'Stadion erstellen'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Adresse'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: leaderController,
                    decoration: const InputDecoration(labelText: 'Standard-Einsatzleiter'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: leaderPhoneController,
                    decoration: const InputDecoration(labelText: 'Telefon (Einsatzleiter)'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: leaderEmailController,
                    decoration: const InputDecoration(labelText: 'E-Mail (Einsatzleiter)'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: clubController,
                    decoration: const InputDecoration(labelText: 'Standard-Verein'),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Lagepläne',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Existing maps
                  if (existingMaps.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < existingMaps.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                // Show a thumbnail for images or a file icon for PDFs
                                if ((existingMaps[i]['map_name'] as String?)
                                        ?.toLowerCase()
                                        .endsWith('.pdf') ==
                                    true)
                                  const Icon(Icons.picture_as_pdf, size: 60)
                                else if (existingMaps[i]['map_data'] != null)
                                  Image.memory(
                                    existingMaps[i]['map_data'] as Uint8List,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  )
                                else
                                  const Icon(Icons.insert_drive_file, size: 60),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(existingMaps[i]['map_name'] as String),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    setStateDialog(() {
                                      final removed = existingMaps.removeAt(i);
                                      mapsToRemove.add(removed['id'] as int);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  // New maps
                  if (newMaps.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < newMaps.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                // Preview of the image or icon for PDFs
                                if ((newMaps[i]['name'] as String)
                                        .toLowerCase()
                                        .endsWith('.pdf'))
                                  const Icon(Icons.picture_as_pdf, size: 60)
                                else if (newMaps[i]['data'] != null)
                                  Image.memory(
                                    Uint8List.fromList(newMaps[i]['data'] as List<int>),
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  )
                                else
                                  const Icon(Icons.insert_drive_file, size: 60),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: newMaps[i]['name'] as String,
                                    decoration: const InputDecoration(labelText: 'Name des Plans'),
                                    onChanged: (val) {
                                      newMaps[i]['name'] = val;
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    setStateDialog(() {
                                      newMaps.removeAt(i);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if ((existingMaps.length + newMaps.length) >= 5) return;
                      await pickFiles();
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Dateien auswählen'),
                  ),
                  if ((existingMaps.length + newMaps.length) >= 5)
                    const Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Maximal 5 Lagepläne erlaubt.',
                        style: TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final address = addressController.text.trim().isEmpty
                      ? null
                      : addressController.text.trim();
                  final leader = leaderController.text.trim().isEmpty
                      ? null
                      : leaderController.text.trim();
                  final leaderPhone = leaderPhoneController.text.trim().isEmpty
                      ? null
                      : leaderPhoneController.text.trim();
                  final leaderEmail = leaderEmailController.text.trim().isEmpty
                      ? null
                      : leaderEmailController.text.trim();
                  final club = clubController.text.trim().isEmpty
                      ? null
                      : clubController.text.trim();
                  if (isEditing) {
                    await DbService.updateStadium(
                      id: stadium['id'] as int,
                      name: name,
                      address: address,
                      defaultLeader: leader,
                      defaultLeaderPhone: leaderPhone,
                      defaultLeaderEmail: leaderEmail,
                      defaultClub: club,
                    );
                    // Delete marked maps
                    for (final int mapId in mapsToRemove) {
                      await DbService.deleteStadiumMap(mapId);
                    }
                    // Add new maps
                    for (final map in newMaps) {
                      await DbService.addStadiumMap(
                        stadiumId: stadium['id'] as int,
                        name: map['name'] as String,
                        data: map['data'] as List<int>,
                      );
                    }
                  } else {
                    await DbService.createStadium(
                      name: name,
                      address: address,
                      defaultLeader: leader,
                      defaultLeaderPhone: leaderPhone,
                      defaultLeaderEmail: leaderEmail,
                      defaultClub: club,
                      plans: newMaps,
                    );
                  }
                  if (mounted) {
                    Navigator.of(context).pop();
                    await _loadStadiums();
                  }
                },
                child: const Text('Speichern'),
              ),
            ],
          );
        });
      },
    );
  }


  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Verwalten'),
              Tab(text: 'Erstellen'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Manage tab
                _loadingStadiums
                    ? const Center(child: CircularProgressIndicator())
                    : _stadiums.isEmpty
                        ? const Center(child: Text('Keine Stadien vorhanden'))
                        : ListView.separated(
                            itemCount: _stadiums.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final stadium = _stadiums[index];
                              return ListTile(
                                title: Text(stadium['name'] as String),
                                subtitle: Text((stadium['address'] ?? '') as String),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _showStadiumForm(stadium: stadium),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _showDeleteStadiumDialog(stadium),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  // Navigate to a detailed stadium overview when the list tile is tapped.
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => StadiumDetailPage(stadium: stadium),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                // Create tab
                Center(
                  child: ElevatedButton(
                    onPressed: () => _showStadiumForm(),
                    child: const Text('Neues Stadion anlegen'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}