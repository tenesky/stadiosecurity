import 'package:flutter/material.dart';
import '../models/user.dart';
import 'placeholder_page.dart';
import 'login_page.dart';
import 'user_management_page.dart';
import 'role_management_page.dart';
import 'stadium_page.dart';

/// The main application shell shown after a successful login.  It
/// displays a responsive left navigation menu and a content area.
/// Menu entries and the available pages are defined within this file.
class HomePage extends StatefulWidget {
  final User user;
  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Map of display names to internal route identifiers.  These
  // identifiers are used to switch content in the right hand pane.
  static const Map<String, List<_MenuItem>> _menuConfig = {
    'Systemverwaltung': [
      _MenuItem('Funktionen', 'system_funktionen'),
      _MenuItem('Veranstaltungen', 'system_veranstaltungen'),
      _MenuItem('Checklisten / Aufgaben', 'system_checklisten'),
      _MenuItem('Dokumente', 'system_dokumente'),
      _MenuItem('Berechtigungen', 'system_berechtigungen'),
      _MenuItem('Stadien', 'system_stadien'),
    ],
    'Benutzerverwaltung': [
      _MenuItem('Mitarbeiter / Benutzer', 'benutzer_mitarbeiter'),
      _MenuItem('Rollen', 'benutzer_rollen'),
    ],
    'Operativ': [
      _MenuItem('Veranstaltung', 'operativ_veranstaltung'),
      _MenuItem('Protokoll', 'operativ_protokoll'),
    ],
  };

  String _selectedRoute = 'start';

  // Styling constants for the menu.  `menuWidth` controls the width of
  // the side navigation when displayed on a desktop.  `headerColor`
  // defines the tint used for the top bar and logo header.  `drawerBackground`
  // defines a light background colour for the drawer itself.
  static const double menuWidth = 320.0;
  static const Color headerColor = Color(0xFF78B1C6);
  static const Color drawerBackground = Color(0xFFF4F7F9);

  @override
  void initState() {
    super.initState();
    _selectedRoute = 'start';
  }

  /// Determines which widget to show in the content area based on the
  /// currently selected route.  The default is a simple welcome
  /// screen for the authenticated user.
  Widget _buildContent() {
    if (_selectedRoute == 'start') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Willkommen, ${widget.user.username}!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Rolle: ${widget.user.role}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const Text(
              'Bitte wähle einen Eintrag aus dem Menü auf der linken Seite.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    if (_selectedRoute == 'benutzer_mitarbeiter') {
      // Show user management page
      return const UserManagementPage();
    }
    if (_selectedRoute == 'benutzer_rollen') {
      // Show role management page
      return const RoleManagementPage();
    }
    if (_selectedRoute == 'system_stadien') {
      return const StadiumPage();
    }
    if (_selectedRoute == 'profil_verwalten') {
      return const PlaceholderPage(title: 'Profil verwalten');
    }
    // Find the selected menu item by searching all categories.
    String displayName = '';
    for (var entries in _menuConfig.values) {
      for (var item in entries) {
        if (item.route == _selectedRoute) {
          displayName = item.label;
          break;
        }
      }
    }
    return PlaceholderPage(title: displayName);
  }

  /// Builds the vertical navigation menu.  On large screens it is
  /// always visible; on small screens it is placed in a drawer.
  Widget _buildMenu() {
    // Build a modernised navigation menu using ExpansionTiles for each
    // category.  A header with the company logo is shown at the top.
    final primary = headerColor;
    return Column(
      children: [
        // Display only the logo at the top without a coloured background
        DrawerHeader(
          decoration: const BoxDecoration(
            color: headerColor,
            borderRadius: BorderRadius.zero,
          ),
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Image.asset(
              'assets/pss_logo.png',
              fit: BoxFit.contain,
              height: 80,
            ),
          ),
        ),
        // Main navigation area
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              for (final entry in _menuConfig.entries)
                Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    leading: _iconForCategory(entry.key),
                    title: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    initiallyExpanded: true,
                    children: [
                      for (final item in entry.value)
                        ListTile(
                          dense: true,
                          leading: _iconForItem(item.route),
                          title: Text(item.label),
                          selected: _selectedRoute == item.route,
                          selectedColor: primary,
                          // Use withValues(alpha: ...) instead of withOpacity()
                          // to avoid deprecation warnings in Flutter 3.27+.
                          selectedTileColor: primary.withValues(alpha: 0.1),
                          onTap: () {
                            setState(() {
                              _selectedRoute = item.route;
                            });
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Profile section at the bottom of the menu
        Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
          ),
          child: ExpansionTile(
            leading: const Icon(Icons.person),
            title: const Text('Profil', style: TextStyle(fontWeight: FontWeight.bold)),
            children: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.manage_accounts),
                title: const Text('Verwalten'),
                selected: _selectedRoute == 'profil_verwalten',
                selectedColor: primary,
                // Use withValues(alpha: ...) instead of withOpacity()
                selectedTileColor: primary.withValues(alpha: 0.1),
                onTap: () {
                  setState(() {
                    _selectedRoute = 'profil_verwalten';
                  });
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.logout),
                title: const Text('Abmelden'),
                onTap: () {
                  _logout();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 600;
    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('PSS Security'),
              backgroundColor: headerColor,
              foregroundColor: Colors.white,
            ),
      drawer: isDesktop
          ? null
          : Drawer(
              width: menuWidth,
              elevation: 0,
              backgroundColor: drawerBackground,
              child: _buildMenu(),
            ),
      body: Row(
        children: [
          if (isDesktop)
            SizedBox(
              width: menuWidth,
              child: Drawer(
                elevation: 0,
                backgroundColor: drawerBackground,
                child: _buildMenu(),
              ),
            ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  /// Returns an icon representing a top level category for the menu.
  /// These icons improve the visual clarity of the navigation.
  Icon _iconForCategory(String category) {
    switch (category) {
      case 'Systemverwaltung':
        return const Icon(Icons.settings);
      case 'Benutzerverwaltung':
        return const Icon(Icons.people);
      case 'Operativ':
        return const Icon(Icons.work);
      default:
        return const Icon(Icons.folder);
    }
  }

  /// Returns an icon for a specific menu item.  You can customise
  /// these further based on the route id.
  Icon _iconForItem(String route) {
    if (route.contains('funktionen')) return const Icon(Icons.extension);
    if (route.contains('veranstaltungen')) return const Icon(Icons.event);
    if (route.contains('checklisten')) return const Icon(Icons.checklist);
    if (route.contains('dokumente')) return const Icon(Icons.description);
    if (route.contains('berechtigungen')) return const Icon(Icons.lock);
    if (route.contains('stadien')) return const Icon(Icons.location_city);
    if (route.contains('mitarbeiter')) return const Icon(Icons.person);
    if (route.contains('rollen')) return const Icon(Icons.security);
    if (route.contains('protokoll')) return const Icon(Icons.note);
    return const Icon(Icons.chevron_right);
  }

  /// Logs the current user out by navigating back to the login page and
  /// clearing the navigation stack.
  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }
}

/// Lightweight helper class to couple a display label with a route
/// identifier.
class _MenuItem {
  final String label;
  final String route;
  const _MenuItem(this.label, this.route);
}