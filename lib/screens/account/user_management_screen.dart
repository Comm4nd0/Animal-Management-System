import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/animal_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';

/// Screen for managing team members within an organization.
/// Accessible to account owners and admins.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnimalProvider>().loadTeamMembers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnimalProvider>();
    final profile = provider.userProfile;
    final members = provider.teamMembers;
    final tierInfo = profile != null ? getTierInfo(profile.serviceTier) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Management'),
      ),
      floatingActionButton: (profile?.canManageUsers ?? false)
          ? FloatingActionButton.extended(
              onPressed: () => _showInviteDialog(context),
              icon: const Icon(Icons.person_add),
              label: const Text('Add User'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTeamOverviewCard(context, profile, tierInfo, members.length),
          const SizedBox(height: 16),
          _buildRoleGuideCard(context),
          const SizedBox(height: 16),
          Text(
            'Team Members (${members.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          if (members.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('No team members yet. Add users to get started.'),
                ),
              ),
            )
          else
            ...members.map((m) => _buildMemberCard(context, m, profile)),
        ],
      ),
    );
  }

  Widget _buildTeamOverviewCard(
    BuildContext context,
    UserProfile? profile,
    ServiceTierInfo? tierInfo,
    int memberCount,
  ) {
    final maxUsers = tierInfo?.maxUsers;
    final usagePercent = maxUsers != null ? memberCount / maxUsers : 0.0;

    return Card(
      color: AppTheme.primaryColor.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.group, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Team Overview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Team Members'),
                Text(
                  maxUsers != null
                      ? '$memberCount / $maxUsers'
                      : '$memberCount (unlimited)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (maxUsers != null) ...[
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
                '${(maxUsers - memberCount).clamp(0, maxUsers)} slots remaining',
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

  Widget _buildRoleGuideCard(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.info_outline, color: AppTheme.primaryColor),
        title: const Text('Role Permissions Guide'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: UserRole.values.map((role) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRoleIcon(role),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              getUserRoleLabel(role),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              getUserRoleDescription(role),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(
    BuildContext context,
    TeamMember member,
    UserProfile? currentUser,
  ) {
    final isCurrentUser = currentUser != null && member.id == currentUser.id;
    final isOwnerMember = member.role == UserRole.owner;
    final canEdit = (currentUser?.canManageUsers ?? false) && !isOwnerMember && !isCurrentUser;

    // Admins can't manage other admins
    final isAdmin = currentUser?.isAdmin ?? false;
    final canEditThisMember = canEdit && !(isAdmin && member.role == UserRole.admin);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(member.role).withValues(alpha: 0.15),
          child: Icon(
            _getRoleIconData(member.role),
            color: _getRoleColor(member.role),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                member.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(member.email),
            const SizedBox(height: 4),
            _buildRoleBadge(member.role),
          ],
        ),
        trailing: canEditThisMember
            ? PopupMenuButton<String>(
                onSelected: (value) => _handleMemberAction(value, member),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'change_role',
                    child: ListTile(
                      leading: Icon(Icons.swap_horiz),
                      title: Text('Change Role'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      leading: Icon(Icons.person_remove, color: AppTheme.errorColor),
                      title: Text('Remove User', style: TextStyle(color: AppTheme.errorColor)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              )
            : null,
        isThreeLine: true,
      ),
    );
  }

  Widget _buildRoleBadge(UserRole role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getRoleColor(role).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        getUserRoleLabel(role),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _getRoleColor(role),
        ),
      ),
    );
  }

  Widget _buildRoleIcon(UserRole role) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: _getRoleColor(role).withValues(alpha: 0.15),
      child: Icon(
        _getRoleIconData(role),
        size: 16,
        color: _getRoleColor(role),
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

  IconData _getRoleIconData(UserRole role) {
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

  void _handleMemberAction(String action, TeamMember member) {
    switch (action) {
      case 'change_role':
        _showChangeRoleDialog(member);
        break;
      case 'remove':
        _showRemoveConfirmation(member);
        break;
    }
  }

  void _showInviteDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    UserRole selectedRole = UserRole.contributor;

    final provider = context.read<AnimalProvider>();
    final profile = provider.userProfile;

    // Build available roles based on current user's role
    final availableRoles = <UserRole>[
      UserRole.readOnly,
      UserRole.contributor,
    ];
    if (profile?.isOwner ?? false) {
      availableRoles.add(UserRole.admin);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Team Member'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Username *',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Username is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Email is required';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Temporary Password *',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.length < 8) return 'At least 8 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: firstNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: lastNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Last Name',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Role',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...availableRoles.map((role) => RadioListTile<UserRole>(
                        value: role,
                        groupValue: selectedRole,
                        onChanged: (v) {
                          if (v != null) setDialogState(() => selectedRole = v);
                        },
                        title: Text(getUserRoleLabel(role)),
                        subtitle: Text(
                          getUserRoleDescription(role),
                          style: const TextStyle(fontSize: 12),
                        ),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final member = TeamMember(
                    username: usernameCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    firstName: firstNameCtrl.text.trim(),
                    lastName: lastNameCtrl.text.trim(),
                    role: selectedRole,
                  );
                  provider.addTeamMember(member);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${member.displayName} added as ${member.roleLabel}',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Add User'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeRoleDialog(TeamMember member) {
    final provider = context.read<AnimalProvider>();
    final currentUser = provider.userProfile;
    UserRole selectedRole = member.role;

    final availableRoles = <UserRole>[
      UserRole.readOnly,
      UserRole.contributor,
    ];
    if (currentUser?.isOwner ?? false) {
      availableRoles.add(UserRole.admin);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Change Role for ${member.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableRoles.map((role) => RadioListTile<UserRole>(
                  value: role,
                  groupValue: selectedRole,
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedRole = v);
                  },
                  title: Text(getUserRoleLabel(role)),
                  subtitle: Text(
                    getUserRoleDescription(role),
                    style: const TextStyle(fontSize: 12),
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                )).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                provider.updateTeamMemberRole(member.id, selectedRole.index);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${member.displayName} is now ${getUserRoleLabel(selectedRole)}',
                    ),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveConfirmation(TeamMember member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Team Member'),
        content: Text(
          'Are you sure you want to remove ${member.displayName} '
          '(${member.email}) from the team?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () {
              context.read<AnimalProvider>().removeTeamMember(member.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${member.displayName} has been removed'),
                ),
              );
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
