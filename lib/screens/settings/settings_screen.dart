import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/animal_provider.dart';
import '../../utils/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SectionHeader('Appearance'),
          _ThemeModeTile(),
          const Divider(),
          _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Import Data'),
            subtitle: const Text('Import animals from CSV or JSON'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/import'),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export Data'),
            subtitle: const Text('Export animals to CSV or JSON'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/export'),
          ),
          ListTile(
            leading: const Icon(Icons.health_and_safety),
            title: const Text('Data Audit'),
            subtitle: const Text('Check for pedigree issues'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/data-audit'),
          ),
          const Divider(),
          _SectionHeader('Account'),
          Consumer<AnimalProvider>(
            builder: (context, provider, _) {
              final profile = provider.userProfile;
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('My Account'),
                    subtitle: Text(profile != null
                        ? '${profile.tierLabel} plan'
                        : 'Not logged in'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      if (profile != null) {
                        Navigator.pushNamed(context, '/account',
                            arguments: profile);
                      }
                    },
                  ),
                  if (provider.canManageUsers)
                    ListTile(
                      leading: const Icon(Icons.group),
                      title: const Text('Team Management'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pushNamed(context, '/team'),
                    ),
                ],
              );
            },
          ),
          const Divider(),
          _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Pedigree Manager'),
            subtitle: Text('Version 1.0.0'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AnimalProvider>(
      builder: (context, provider, _) {
        final mode = provider.themeMode;
        return ListTile(
          leading: Icon(
            mode == ThemeMode.dark
                ? Icons.dark_mode
                : mode == ThemeMode.light
                    ? Icons.light_mode
                    : Icons.brightness_auto,
          ),
          title: const Text('Theme'),
          subtitle: Text(
            mode == ThemeMode.dark
                ? 'Dark mode'
                : mode == ThemeMode.light
                    ? 'Light mode'
                    : 'System default',
          ),
          trailing: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto, size: 18),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode, size: 18),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode, size: 18),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) {
              provider.setThemeMode(selection.first);
            },
          ),
        );
      },
    );
  }
}
