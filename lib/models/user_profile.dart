import '../utils/constants.dart';

class UserProfile {
  final String id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final ServiceTier serviceTier;
  final UserRole role;
  final String? registeredSpecies;
  final String? registeredBreed;
  final String? farmName;
  final String? contactPhone;
  final String? address;
  final int animalCount;
  final int? animalsRemaining; // null = unlimited
  final int? maxAnimals;       // null = unlimited
  final bool allowsMultiBreed;
  final int? maxUsers;         // null = unlimited
  final int teamCount;

  const UserProfile({
    required this.id,
    required this.username,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.serviceTier = ServiceTier.starter,
    this.role = UserRole.owner,
    this.registeredSpecies,
    this.registeredBreed,
    this.farmName,
    this.contactPhone,
    this.address,
    this.animalCount = 0,
    this.animalsRemaining,
    this.maxAnimals,
    this.allowsMultiBreed = false,
    this.maxUsers,
    this.teamCount = 1,
  });

  // ─── Tier helpers ──────────────────────────────────────────────

  String get tierLabel => getTierInfo(serviceTier).label;
  String get tierDescription => getTierInfo(serviceTier).description;
  bool get isUnlimited => maxAnimals == null;
  bool get isBreedLocked => registeredBreed != null && registeredBreed!.isNotEmpty;

  bool canAddAnimal() {
    if (maxAnimals == null) return true;
    return animalCount < maxAnimals!;
  }

  bool canUseBreed(String species, String breed) {
    if (allowsMultiBreed) return true;
    if (!isBreedLocked) return true; // first animal, any breed OK
    return registeredSpecies == species && registeredBreed == breed;
  }

  String? validateAnimalAddition(String species, String breed) {
    if (!canAddAnimal()) {
      return 'Animal limit reached. Your $tierLabel plan allows '
          'up to $maxAnimals animals. Upgrade your plan to add more.';
    }
    if (!canUseBreed(species, breed)) {
      return 'Your $tierLabel plan only allows a single breed. '
          'This account is registered for $registeredSpecies - '
          '$registeredBreed. Upgrade to Enterprise for '
          'multi-species/breed support.';
    }
    return null; // valid
  }

  // ─── Role helpers ──────────────────────────────────────────────

  String get roleLabel => getUserRoleLabel(role);

  bool get isOwner => role == UserRole.owner;
  bool get isAdmin => role == UserRole.admin;
  bool get isContributor => role == UserRole.contributor;
  bool get isReadOnly => role == UserRole.readOnly;

  /// Whether this user can manage team members (owners and admins).
  bool get canManageUsers => role == UserRole.owner || role == UserRole.admin;

  /// Whether this user can create/edit/delete data.
  bool get canWriteData =>
      role == UserRole.owner ||
      role == UserRole.admin ||
      role == UserRole.contributor;

  /// Whether the organization can add more users.
  bool canAddUser() {
    if (maxUsers == null) return true;
    return teamCount < maxUsers!;
  }

  // ─── Serialization ────────────────────────────────────────────

  factory UserProfile.fromApi(Map<String, dynamic> m) {
    final user = m['user'] as Map<String, dynamic>? ?? {};
    return UserProfile(
      id: m['id'] as String? ?? '',
      username: user['username'] as String? ?? '',
      email: user['email'] as String? ?? '',
      firstName: user['first_name'] as String? ?? '',
      lastName: user['last_name'] as String? ?? '',
      serviceTier: ServiceTier.values[m['service_tier'] as int? ?? 0],
      role: userRoleFromIndex(m['role'] as int? ?? 3),
      registeredSpecies: m['registered_species'] as String?,
      registeredBreed: m['registered_breed'] as String?,
      farmName: m['farm_name'] as String?,
      contactPhone: m['contact_phone'] as String?,
      address: m['address'] as String?,
      animalCount: m['animal_count'] as int? ?? 0,
      animalsRemaining: m['animals_remaining'] as int?,
      maxAnimals: m['max_animals'] as int?,
      allowsMultiBreed: m['allows_multi_breed'] as bool? ?? false,
      maxUsers: m['max_users'] as int?,
      teamCount: m['team_count'] as int? ?? 1,
    );
  }
}
