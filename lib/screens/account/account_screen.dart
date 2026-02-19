import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';

/// Account management screen showing the user's service tier,
/// role, usage stats, breed lock status, team info, and upgrade options.
class AccountScreen extends StatelessWidget {
  final UserProfile profile;

  const AccountScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final tierInfo = getTierInfo(profile.serviceTier);

    return Scaffold(
      appBar: AppBar(title: const Text('My Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileCard(context),
          const SizedBox(height: 16),
          _buildRoleCard(context),
          const SizedBox(height: 16),
          _buildTierCard(context, tierInfo),
          const SizedBox(height: 16),
          _buildUsageCard(context, tierInfo),
          const SizedBox(height: 16),
          _buildTeamCard(context, tierInfo),
          const SizedBox(height: 16),
          _buildBreedLockCard(context),
          if (profile.serviceTier != ServiceTier.enterprise) ...[
            const SizedBox(height: 24),
            _buildUpgradeSection(context),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.person,
                    size: 28,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.username,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        profile.email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (profile.farmName != null && profile.farmName!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.home_work, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(profile.farmName!),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _getRoleColor(profile.role).withValues(alpha: 0.15),
              child: Icon(
                _getRoleIcon(profile.role),
                color: _getRoleColor(profile.role),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Role: ${profile.roleLabel}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    getUserRoleDescription(profile.role),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
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

  Widget _buildTierCard(BuildContext context, ServiceTierInfo tierInfo) {
    return Card(
      color: AppTheme.primaryColor.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium, color: AppTheme.accentColor),
                const SizedBox(width: 8),
                Text(
                  '${tierInfo.label} Plan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tierInfo.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFeatureChip(
                  tierInfo.isUnlimited ? 'Unlimited' : '${tierInfo.maxAnimals} max',
                  Icons.pets,
                ),
                _buildFeatureChip(
                  tierInfo.allowsMultiBreed ? 'Multi-breed' : 'Single breed',
                  tierInfo.allowsMultiBreed ? Icons.check_circle : Icons.lock,
                  color: tierInfo.allowsMultiBreed
                      ? AppTheme.primaryColor
                      : Colors.orange,
                ),
                _buildFeatureChip(
                  tierInfo.hasUnlimitedUsers
                      ? 'Unlimited users'
                      : '${tierInfo.maxUsers} users',
                  Icons.group,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageCard(BuildContext context, ServiceTierInfo tierInfo) {
    final usagePercent = tierInfo.isUnlimited
        ? 0.0
        : profile.animalCount / tierInfo.maxAnimals!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usage',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Animals'),
                Text(
                  tierInfo.isUnlimited
                      ? '${profile.animalCount} (unlimited)'
                      : '${profile.animalCount} / ${tierInfo.maxAnimals}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (!tierInfo.isUnlimited) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: usagePercent.clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(
                  usagePercent > 0.9 ? AppTheme.errorColor : AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                profile.animalsRemaining != null
                    ? '${profile.animalsRemaining} remaining'
                    : '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: usagePercent > 0.9
                          ? AppTheme.errorColor
                          : Colors.grey.shade600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTeamCard(BuildContext context, ServiceTierInfo tierInfo) {
    final teamUsage = tierInfo.hasUnlimitedUsers
        ? 0.0
        : profile.teamCount / tierInfo.maxUsers!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Team',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (profile.canManageUsers)
                  TextButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/team'),
                    icon: const Icon(Icons.manage_accounts, size: 18),
                    label: const Text('Manage'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Team Members'),
                Text(
                  tierInfo.hasUnlimitedUsers
                      ? '${profile.teamCount} (unlimited)'
                      : '${profile.teamCount} / ${tierInfo.maxUsers}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (!tierInfo.hasUnlimitedUsers) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: teamUsage.clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(
                  teamUsage > 0.9 ? AppTheme.errorColor : AppTheme.primaryColor,
                ),
              ),
            ],
            if (!profile.canManageUsers) ...[
              const SizedBox(height: 8),
              Text(
                'Contact your account administrator to manage team members.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBreedLockCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Breed Registration',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (profile.allowsMultiBreed)
              Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 18),
                  const SizedBox(width: 8),
                  const Text('Enterprise - All species and breeds allowed'),
                ],
              )
            else if (profile.isBreedLocked)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      const Text('Locked to single breed:'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Text(
                      '${profile.registeredSpecies} - ${profile.registeredBreed}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Text(
                      'All animals must be this breed. Upgrade to Enterprise for multi-breed.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade400, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Not yet set. Your breed will be locked when you add your first animal.',
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Upgrade Plan',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ...serviceTiers
            .where((t) => t.tier.index > profile.serviceTier.index)
            .map((tier) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.upgrade, color: AppTheme.accentColor),
                    title: Text(tier.label),
                    subtitle: Text(tier.description),
                    trailing: ElevatedButton(
                      onPressed: () {
                        // In production, call ApiService().changeTier(...)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Upgrade to ${tier.label} requested'),
                          ),
                        );
                      },
                      child: const Text('Upgrade'),
                    ),
                  ),
                )),
      ],
    );
  }

  Widget _buildFeatureChip(String label, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? AppTheme.primaryColor).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color ?? AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return Colors.purple;
      case UserRole.admin:
        return Colors.blue;
      case UserRole.contributor:
        return AppTheme.primaryColor;
      case UserRole.readOnly:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return Icons.star;
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.contributor:
        return Icons.edit;
      case UserRole.readOnly:
        return Icons.visibility;
    }
  }
}
