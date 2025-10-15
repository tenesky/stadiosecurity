import 'package:flutter/material.dart';
import '../services/db_service.dart';

/// Page for managing events (Veranstaltungen).  This page is accessible
/// from the system administration section and allows creating, editing
/// and deleting football events.  Events are categorised into past,
/// current and future based on their start and end times.  When
/// creating or editing an event, a comprehensive form is presented
/// allowing entry of key details such as the event name, schedule,
/// participating clubs, security category, expected spectators and
/// additional metadata like season, competition and kickoff time.  A
/// multi‑selection of roles determines which roles are associated with
/// the event.
class EventPage extends StatefulWidget {
  const EventPage({super.key});

  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEvents();
  }

  /// Loads all events from the database and updates local state.  While
  /// awaiting data, a loading indicator is shown to the user.
  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    final events = await DbService.getEvents();
    if (!mounted) return;
    setState(() {
      _events = events;
      _loading = false;
    });
  }

  /// Opens a dialog to create a new event or edit an existing one.  When
  /// editing, the provided [event] map contains the current values and
  /// selected roles.  On save, the event is persisted to the database and
  /// the list refreshed.  This form supports additional fields such as
  /// season, competition, matchday (for Regionalliga Nordost), kickoff
  /// time, numbers of area leaders and security personnel, and other
  /// information.
  Future<void> _showEventForm({Map<String, dynamic>? event}) async {
    final bool isEditing = event != null;
    // Controllers for text fields
    final TextEditingController nameController = TextEditingController(text: event?['name'] ?? '');
    final TextEditingController securityCategoryController = TextEditingController(text: event?['security_category'] ?? '');
    final TextEditingController totalSpectatorsController = TextEditingController(text: event?['expected_spectators_total']?.toString() ?? '');
    final TextEditingController homeSupportersController = TextEditingController(text: event?['expected_home_supporters']?.toString() ?? '');
    final TextEditingController awaySupportersController = TextEditingController(text: event?['expected_away_supporters']?.toString() ?? '');
    final TextEditingController eventLeaderController = TextEditingController(text: event?['event_leader'] ?? '');
    final TextEditingController eventLeaderPhoneController = TextEditingController(text: event?['event_leader_phone'] ?? '');
    final TextEditingController eventLeaderEmailController = TextEditingController(text: event?['event_leader_email'] ?? '');
    final TextEditingController homeClubController = TextEditingController(text: event?['home_club'] ?? '');
    final TextEditingController awayClubController = TextEditingController(text: event?['away_club'] ?? '');
    final TextEditingController descriptionController = TextEditingController(text: event?['description'] ?? '');

    // Date and time pickers use DateTime/TimeOfDay objects.  Initialise with
    // existing values when editing or sensible defaults when creating.
    DateTime? startDateTime = event != null ? (event['start_time'] as DateTime) : DateTime.now();
    DateTime? endDateTime = event != null ? (event['end_time'] as DateTime) : DateTime.now().add(const Duration(hours: 2));

    // IDs of selected stadium and roles.  These are loaded from the
    // database just before showing the dialog.
    int? selectedStadiumId = event?['stadium_id'] as int?;
    List<int> selectedRoleIds = [];
    // Data lists for dropdowns and checkboxes
    List<Map<String, dynamic>> stadiums = [];
    List<Map<String, dynamic>> roles = [];

    // Preload roles and stadiums plus existing assignments when editing
    await Future.wait([
      DbService.getRoles().then((r) => roles = r),
      DbService.getStadiums().then((s) => stadiums = s),
      if (isEditing) DbService.getEventRoleIds(event!['id'] as int).then((ids) => selectedRoleIds = ids) else Future.value(),
    ]);

    // Provide a helper to pick date and time separately then compose a
    // single DateTime.  This closure captures startDateTime/endDateTime by
    // reference and updates them using setStateDialog.
    Future<void> pickDateTime({required bool isStart, required StateSetter setStateDialog}) async {
      final initialDate = (isStart ? startDateTime : endDateTime) ?? DateTime.now();
      final date = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (date == null) return;
      final timeOfDay = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );
      if (timeOfDay == null) return;
      final combined = DateTime(date.year, date.month, date.day, timeOfDay.hour, timeOfDay.minute);
      setStateDialog(() {
        if (isStart) {
          startDateTime = combined;
        } else {
          endDateTime = combined;
        }
      });
    }

    // Controllers and state for new fields
    // Compute a list of seasons: current season and previous two seasons.
    List<String> seasonsList() {
      final now = DateTime.now();
      int startYear = now.month >= 7 ? now.year : now.year - 1;
      return List<String>.generate(3, (index) {
        final year = startYear - index;
        final nextYearShort = (year + 1) % 100;
        return '${year}/${nextYearShort.toString().padLeft(2, '0')}';
      });
    }
    String? selectedSeason = event?['season'] as String?;
    final List<String> seasonOptions = seasonsList();
    selectedSeason ??= seasonOptions.isNotEmpty ? seasonOptions.first : null;

    // Competition selection
    String? selectedCompetition = event?['competition'] as String?;
    final List<String> competitionOptions = [
      'Regionalliga Nordost',
      'Sachsenpokal',
      'Freundschaftsspiel',
    ];
    selectedCompetition ??= competitionOptions.first;

    // Matchday selection
    int? selectedMatchday = event?['matchday'] as int?;

    // Kickoff time as TimeOfDay
    TimeOfDay? kickoffTime;
    if (event != null && event['kickoff_time'] != null) {
      final DateTime dt = event['kickoff_time'] as DateTime;
      kickoffTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
    }

    // Controllers for numeric inputs
    final TextEditingController areaLeadersController = TextEditingController(
        text: event?['num_area_leaders'] != null ? (event!['num_area_leaders']).toString() : '');
    final TextEditingController securityController = TextEditingController(
        text: event?['num_security'] != null ? (event!['num_security']).toString() : '');

    // Controller for additional info
    final TextEditingController otherInfoController = TextEditingController(text: event?['other_info'] ?? '');

    // Local saving state for showing a loading indicator while persisting
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              scrollable: true,
              title: Text(isEditing ? 'Veranstaltung bearbeiten' : 'Veranstaltung erstellen'),
              content: StatefulBuilder(
                builder: (context, setStateInner) {
                  return Stack(
                    children: [
                      AbsorbPointer(
                        absorbing: isSaving,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(labelText: 'Bezeichnung*'),
                            ),
                            const SizedBox(height: 8),
                            // Season selection
                            DropdownButtonFormField<String>(
                              value: selectedSeason,
                              decoration: const InputDecoration(labelText: 'Saison*'),
                              items: seasonOptions
                                  .map(
                                    (season) => DropdownMenuItem<String>(
                                      value: season,
                                      child: Text(season),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setStateInner(() {
                                  selectedSeason = value;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            // Competition selection
                            DropdownButtonFormField<String>(
                              value: selectedCompetition,
                              decoration: const InputDecoration(labelText: 'Wettbewerb*'),
                              items: competitionOptions
                                  .map(
                                    (comp) => DropdownMenuItem<String>(
                                      value: comp,
                                      child: Text(comp),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setStateInner(() {
                                  selectedCompetition = value;
                                  if (selectedCompetition != 'Regionalliga Nordost') {
                                    selectedMatchday = null;
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            // Matchday when Regionalliga Nordost
                            if (selectedCompetition == 'Regionalliga Nordost')
                              DropdownButtonFormField<int>(
                                value: selectedMatchday,
                                decoration: const InputDecoration(labelText: 'Spieltag*'),
                                items: List<int>.generate(38, (index) => index + 1)
                                    .map((day) => DropdownMenuItem<int>(
                                          value: day,
                                          child: Text(day.toString()),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setStateInner(() {
                                    selectedMatchday = value;
                                  });
                                },
                              ),
                            if (selectedCompetition == 'Regionalliga Nordost') const SizedBox(height: 8),
                            // Stadium selection
                            DropdownButtonFormField<int>(
                              value: selectedStadiumId,
                              decoration: const InputDecoration(labelText: 'Stadion (optional)'),
                              items: stadiums
                                  .map((stadium) => DropdownMenuItem<int>(
                                        value: stadium['id'] as int,
                                        child: Text(stadium['name'] as String),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                setStateInner(() {
                                  selectedStadiumId = val;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            // Start time picker
                            Row(
                              children: [
                                Expanded(
                                  child: Text(startDateTime != null
                                      ? 'Start*: ${_formatDateTime(startDateTime!)}'
                                      : 'Startzeit wählen'),
                                ),
                                TextButton(
                                  onPressed: () => pickDateTime(isStart: true, setStateDialog: setStateInner),
                                  child: const Text('Auswählen'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // End time picker
                            Row(
                              children: [
                                Expanded(
                                  child: Text(endDateTime != null
                                      ? 'Ende*: ${_formatDateTime(endDateTime!)}'
                                      : 'Endzeit wählen'),
                                ),
                                TextButton(
                                  onPressed: () => pickDateTime(isStart: false, setStateDialog: setStateInner),
                                  child: const Text('Auswählen'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Kickoff time picker
                            Row(
                              children: [
                                Expanded(
                                  child: Text(kickoffTime != null
                                      ? 'Anstoß*: ${kickoffTime!.format(context)}'
                                      : 'Anstoßzeit wählen'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: kickoffTime ?? TimeOfDay.now(),
                                    );
                                    if (time != null) {
                                      setStateInner(() {
                                        kickoffTime = time;
                                      });
                                    }
                                  },
                                  child: const Text('Auswählen'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: securityCategoryController,
                              decoration: const InputDecoration(labelText: 'Sicherheitskategorie'),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: totalSpectatorsController,
                              decoration: const InputDecoration(labelText: 'Gesamtzuschauer'),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: homeSupportersController,
                              decoration: const InputDecoration(labelText: 'Zuschauer Heim'),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: awaySupportersController,
                              decoration: const InputDecoration(labelText: 'Zuschauer Gast'),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 8),
                            // Numbers of area leaders and security
                            TextField(
                              controller: areaLeadersController,
                              decoration: const InputDecoration(labelText: 'Anzahl Bereichsleiter'),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: securityController,
                              decoration: const InputDecoration(labelText: 'Anzahl Security'),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: eventLeaderController,
                              decoration: const InputDecoration(labelText: 'Einsatzleiter'),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: eventLeaderPhoneController,
                              decoration: const InputDecoration(labelText: 'Telefon Einsatzleiter'),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: eventLeaderEmailController,
                              decoration: const InputDecoration(labelText: 'E-Mail Einsatzleiter'),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: homeClubController,
                              decoration: const InputDecoration(labelText: 'Heimverein'),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: awayClubController,
                              decoration: const InputDecoration(labelText: 'Gastverein'),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: descriptionController,
                              decoration: const InputDecoration(labelText: 'Beschreibung'),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: otherInfoController,
                              decoration: const InputDecoration(labelText: 'Sonstige Informationen'),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Rollen zuweisen',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Column(
                              children: roles.map((role) {
                                final int roleId = role['id'] as int;
                                return CheckboxListTile(
                                  title: Text(role['name'] as String),
                                  value: selectedRoleIds.contains(roleId),
                                  onChanged: (bool? checked) {
                                    setStateInner(() {
                                      if (checked == true) {
                                        if (!selectedRoleIds.contains(roleId)) {
                                          selectedRoleIds.add(roleId);
                                        }
                                      } else {
                                        selectedRoleIds.remove(roleId);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      // Loading overlay
                      if (isSaving)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black45,
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                        ),
                    ],
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (!isSaving) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          // Basic validation
                          final String name = nameController.text.trim();
                          if (name.isEmpty || startDateTime == null || endDateTime == null) {
                            return;
                          }
                          setStateDialog(() {
                            isSaving = true;
                          });
                          final String? securityCategory = securityCategoryController.text.trim().isEmpty
                              ? null
                              : securityCategoryController.text.trim();
                          final int? totalSpectators = totalSpectatorsController.text.trim().isEmpty
                              ? null
                              : int.tryParse(totalSpectatorsController.text.trim());
                          final int? homeSpectators = homeSupportersController.text.trim().isEmpty
                              ? null
                              : int.tryParse(homeSupportersController.text.trim());
                          final int? awaySpectators = awaySupportersController.text.trim().isEmpty
                              ? null
                              : int.tryParse(awaySupportersController.text.trim());
                          final String? leader = eventLeaderController.text.trim().isEmpty
                              ? null
                              : eventLeaderController.text.trim();
                          final String? leaderPhone = eventLeaderPhoneController.text.trim().isEmpty
                              ? null
                              : eventLeaderPhoneController.text.trim();
                          final String? leaderEmail = eventLeaderEmailController.text.trim().isEmpty
                              ? null
                              : eventLeaderEmailController.text.trim();
                          final String? homeClub = homeClubController.text.trim().isEmpty
                              ? null
                              : homeClubController.text.trim();
                          final String? awayClub = awayClubController.text.trim().isEmpty
                              ? null
                              : awayClubController.text.trim();
                          final String? description = descriptionController.text.trim().isEmpty
                              ? null
                              : descriptionController.text.trim();
                          final String? otherInfo = otherInfoController.text.trim().isEmpty
                              ? null
                              : otherInfoController.text.trim();
                          final int? numAreaLeaders = areaLeadersController.text.trim().isEmpty
                              ? null
                              : int.tryParse(areaLeadersController.text.trim());
                          final int? numSecurity = securityController.text.trim().isEmpty
                              ? null
                              : int.tryParse(securityController.text.trim());
                          DateTime? kickoffDateTime;
                          if (kickoffTime != null && startDateTime != null) {
                            kickoffDateTime = DateTime(
                              startDateTime!.year,
                              startDateTime!.month,
                              startDateTime!.day,
                              kickoffTime!.hour,
                              kickoffTime!.minute,
                            );
                          }
                          final int? matchdayParam = selectedCompetition == 'Regionalliga Nordost' ? selectedMatchday : null;
                          if (isEditing) {
                            await DbService.updateEvent(
                              id: event!['id'] as int,
                              name: name,
                              stadiumId: selectedStadiumId,
                              startTime: startDateTime!,
                              endTime: endDateTime!,
                              securityCategory: securityCategory,
                              expectedSpectatorsTotal: totalSpectators,
                              expectedHomeSupporters: homeSpectators,
                              expectedAwaySupporters: awaySpectators,
                              eventLeader: leader,
                              eventLeaderPhone: leaderPhone,
                              eventLeaderEmail: leaderEmail,
                              homeClub: homeClub,
                              awayClub: awayClub,
                              description: description,
                              season: selectedSeason,
                              competition: selectedCompetition,
                              matchday: matchdayParam,
                              kickoffTime: kickoffDateTime,
                              numAreaLeaders: numAreaLeaders,
                              numSecurity: numSecurity,
                              otherInfo: otherInfo,
                              roleIds: List<int>.from(selectedRoleIds),
                            );
                          } else {
                            await DbService.createEvent(
                              name: name,
                              stadiumId: selectedStadiumId,
                              startTime: startDateTime!,
                              endTime: endDateTime!,
                              securityCategory: securityCategory,
                              expectedSpectatorsTotal: totalSpectators,
                              expectedHomeSupporters: homeSpectators,
                              expectedAwaySupporters: awaySpectators,
                              eventLeader: leader,
                              eventLeaderPhone: leaderPhone,
                              eventLeaderEmail: leaderEmail,
                              homeClub: homeClub,
                              awayClub: awayClub,
                              description: description,
                              season: selectedSeason,
                              competition: selectedCompetition,
                              matchday: matchdayParam,
                              kickoffTime: kickoffDateTime,
                              numAreaLeaders: numAreaLeaders,
                              numSecurity: numSecurity,
                              otherInfo: otherInfo,
                              roleIds: List<int>.from(selectedRoleIds),
                            );
                          }
                          if (mounted) {
                            Navigator.of(context).pop();
                            await _loadEvents();
                          }
                        },
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Formats a DateTime into a human‑friendly string of the form
  /// `dd.MM.yyyy HH:mm`.
  String _formatDateTime(DateTime dt) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final day = twoDigits(dt.day);
    final month = twoDigits(dt.month);
    final year = dt.year.toString();
    final hour = twoDigits(dt.hour);
    final minute = twoDigits(dt.minute);
    return '$day.$month.$year $hour:$minute';
  }

  /// Returns a list of events filtered by the provided [test] function.  This
  /// utility is used to separate events into past, current and future.
  List<Map<String, dynamic>> _filteredEvents(bool Function(Map<String, dynamic>) test) {
    return _events.where(test).toList();
  }

  /// Builds a list view for a given set of events.  Each item shows the
  /// event name and its date range.  Tapping an item opens a small details
  /// dialog; edit and delete icons allow modification or removal.
  Widget _buildEventList(List<Map<String, dynamic>> events, {bool shrinkWrap = false}) {
    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: events.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final ev = events[index];
        final DateTime start = ev['start_time'] as DateTime;
        final DateTime end = ev['end_time'] as DateTime;
        final String dateRange = '${_formatDateTime(start)} – ${_formatDateTime(end)}';
        return ListTile(
          title: Text(ev['name'] as String),
          subtitle: Text(dateRange),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEventForm(event: ev),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _showDeleteEventDialog(ev),
              ),
            ],
          ),
          onTap: () => _showEventDetails(ev),
        );
      },
    );
  }

  /// Shows a simple dialog with all details of the selected event.  This
  /// read‑only overview allows users to see the stored values without
  /// editing them.
  void _showEventDetails(Map<String, dynamic> ev) {
    showDialog(
      context: context,
      builder: (context) {
        final DateTime start = ev['start_time'] as DateTime;
        final DateTime end = ev['end_time'] as DateTime;
        return AlertDialog(
          title: Text(ev['name'] as String),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Zeitraum: ${_formatDateTime(start)} – ${_formatDateTime(end)}'),
                const SizedBox(height: 8),
                if (ev['season'] != null && (ev['season'] as String).isNotEmpty)
                  Text('Saison: ${ev['season']}'),
                if (ev['competition'] != null && (ev['competition'] as String).isNotEmpty)
                  Text('Wettbewerb: ${ev['competition']}'),
                if (ev['matchday'] != null)
                  Text('Spieltag: ${ev['matchday']}'),
                if (ev['kickoff_time'] != null)
                  Text('Anstoß: ${_formatDateTime(ev['kickoff_time'] as DateTime)}'),
                if (ev['stadium_name'] != null && (ev['stadium_name'] as String).isNotEmpty)
                  Text('Stadion: ${ev['stadium_name']}'),
                if (ev['home_club'] != null && (ev['home_club'] as String).isNotEmpty)
                  Text('Heim: ${ev['home_club']}'),
                if (ev['away_club'] != null && (ev['away_club'] as String).isNotEmpty)
                  Text('Gast: ${ev['away_club']}'),
                if (ev['security_category'] != null && (ev['security_category'] as String).isNotEmpty)
                  Text('Sicherheitskategorie: ${ev['security_category']}'),
                if (ev['expected_spectators_total'] != null)
                  Text('Erwartete Zuschauer: ${ev['expected_spectators_total']}'),
                if (ev['expected_home_supporters'] != null)
                  Text('Heimzuschauer: ${ev['expected_home_supporters']}'),
                if (ev['expected_away_supporters'] != null)
                  Text('Gastzuschauer: ${ev['expected_away_supporters']}'),
                if (ev['num_area_leaders'] != null)
                  Text('Bereichsleiter: ${ev['num_area_leaders']}'),
                if (ev['num_security'] != null)
                  Text('Security: ${ev['num_security']}'),
                if (ev['event_leader'] != null && (ev['event_leader'] as String).isNotEmpty)
                  Text('Einsatzleiter: ${ev['event_leader']}'),
                if (ev['event_leader_phone'] != null && (ev['event_leader_phone'] as String).isNotEmpty)
                  Text('Telefon: ${ev['event_leader_phone']}'),
                if (ev['event_leader_email'] != null && (ev['event_leader_email'] as String).isNotEmpty)
                  Text('E-Mail: ${ev['event_leader_email']}'),
                if (ev['description'] != null && (ev['description'] as String).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Beschreibung: ${ev['description']}'),
                  ),
                if (ev['other_info'] != null && (ev['other_info'] as String).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Sonstige Informationen: ${ev['other_info']}'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Schließen'),
            ),
          ],
        );
      },
    );
  }

  /// Shows a confirmation dialog before deleting the given event.  Upon
  /// confirmation the event is removed from the database and the list
  /// refreshed.
  void _showDeleteEventDialog(Map<String, dynamic> ev) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Veranstaltung löschen'),
        content: Text('Möchtest du die Veranstaltung ${ev['name']} wirklich löschen?'),
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
      await DbService.deleteEvent(ev['id'] as int);
      await _loadEvents();
    }
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
                // Manage Tab
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _events.isEmpty
                        ? const Center(child: Text('Keine Veranstaltungen vorhanden'))
                        : _buildManageContent(),
                // Create Tab
                Center(
                  child: ElevatedButton(
                    onPressed: () => _showEventForm(),
                    child: const Text('Neue Veranstaltung anlegen'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the manage tab content, grouping events into future, current and
  /// past lists.  Headers separate the categories for better clarity.
  Widget _buildManageContent() {
    final now = DateTime.now();
    final past = _filteredEvents((ev) {
      final DateTime end = ev['end_time'] as DateTime;
      return end.isBefore(now);
    });
    final current = _filteredEvents((ev) {
      final DateTime start = ev['start_time'] as DateTime;
      final DateTime end = ev['end_time'] as DateTime;
      return (start.isBefore(now) || start.isAtSameMomentAs(now)) && end.isAfter(now);
    });
    final future = _filteredEvents((ev) {
      final DateTime start = ev['start_time'] as DateTime;
      return start.isAfter(now);
    });
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (future.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Text('Zukünftige Veranstaltungen', style: Theme.of(context).textTheme.titleMedium),
            ),
            _buildEventList(future, shrinkWrap: true),
          ],
          if (current.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Text('Aktuelle Veranstaltungen', style: Theme.of(context).textTheme.titleMedium),
            ),
            _buildEventList(current, shrinkWrap: true),
          ],
          if (past.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Text('Vergangene Veranstaltungen', style: Theme.of(context).textTheme.titleMedium),
            ),
            _buildEventList(past, shrinkWrap: true),
          ],
          if (future.isEmpty && current.isEmpty && past.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Keine Veranstaltungen vorhanden'),
            ),
        ],
      ),
    );
  }
}