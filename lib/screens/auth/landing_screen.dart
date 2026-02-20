import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/animal_provider.dart';
import '../../services/api_service.dart';
import '../../services/demo_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';

/// Public-facing landing page for the web app.
/// Showcases features, service tiers, and provides login/register CTAs.
///
/// Pricing tiers are fetched from the backend API so that any changes
/// made via Django Admin are reflected immediately. Falls back to the
/// hardcoded [serviceTiers] constant if the API is unreachable.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  List<ServiceTierInfo> _tiers = serviceTiers; // fallback to hardcoded
  bool _tiersLoading = true;
  bool _isDemoLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchTiers();
  }

  Future<void> _fetchTiers() async {
    try {
      final api = ApiService();
      final data = await api.getTiers();
      if (data.isNotEmpty && mounted) {
        setState(() {
          _tiers = data;
          _tiersLoading = false;
        });
      } else if (mounted) {
        setState(() => _tiersLoading = false);
      }
    } catch (_) {
      // API unavailable – keep hardcoded defaults
      if (mounted) setState(() => _tiersLoading = false);
    }
  }

  Future<void> _enterDemo() async {
    if (_isDemoLoading) return;
    setState(() => _isDemoLoading = true);

    final provider = context.read<AnimalProvider>();
    final demoService = DemoService();
    final success = await demoService.enterDemoMode(provider);

    if (!mounted) return;
    setState(() => _isDemoLoading = false);

    if (success) {
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load demo. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(child: _buildHeroSection(context)),
          SliverToBoxAdapter(child: _buildFeaturesSection(context)),
          SliverToBoxAdapter(child: _buildPricingSection(context)),
          SliverToBoxAdapter(child: _buildSpeciesSection(context)),
          SliverToBoxAdapter(child: _buildCtaSection(context)),
          SliverToBoxAdapter(child: _buildFooter(context)),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 0,
      backgroundColor: AppTheme.primaryColor,
      title: Row(
        children: [
          const Icon(Icons.pets, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            'Pedigree Manager',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _scrollToSection(context, 'features'),
          child: const Text('Features', style: TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: () => _scrollToSection(context, 'pricing'),
          child: const Text('Pricing', style: TextStyle(color: Colors.white70)),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: _isDemoLoading ? null : _enterDemo,
          icon: _isDemoLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.play_circle_outline, size: 18),
          label: const Text('Try Demo'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/login'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: const Text('Log In'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/register'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Get Started'),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.primaryColor, Color(0xFF1B5E20)],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 80 : 24,
          vertical: isWide ? 80 : 48,
        ),
        child: isWide
            ? Row(
                children: [
                  Expanded(child: _heroText(context)),
                  const SizedBox(width: 48),
                  Expanded(child: _heroVisual(context)),
                ],
              )
            : Column(
                children: [
                  _heroText(context),
                  const SizedBox(height: 32),
                  _heroVisual(context),
                ],
              ),
      ),
    );
  }

  Widget _heroText(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Professional Pedigree\nManagement',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
        ),
        const SizedBox(height: 20),
        Text(
          'Track lineage, manage breeding programmes, and get genetic '
          'compatibility suggestions for your farm animals and horses. '
          'All from one powerful platform.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white70,
                height: 1.5,
              ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Start Free Trial'),
            ),
            OutlinedButton.icon(
              onPressed: _isDemoLoading ? null : _enterDemo,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
              icon: _isDemoLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_circle_outline),
              label: const Text('Try Demo'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _heroVisual(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _heroStat(context, '10K+', 'Animals Managed'),
              _heroStat(context, '500+', 'Farms'),
              _heroStat(context, '99.9%', 'Uptime'),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _featureIcon(Icons.account_tree, 'Pedigree\nTracking'),
              const SizedBox(width: 24),
              _featureIcon(Icons.favorite, 'Breeding\nSuggestions'),
              const SizedBox(width: 24),
              _featureIcon(Icons.medical_services, 'Health\nRecords'),
              const SizedBox(width: 24),
              _featureIcon(Icons.science, 'Genetic\nAnalysis'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.accentColor,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }

  Widget _featureIcon(IconData icon, String label) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.white.withValues(alpha: 0.15),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    final features = [
      _FeatureData(
        Icons.account_tree,
        'Pedigree Tracking',
        'Visualise multi-generation pedigree trees. Track sires, dams, and offspring '
            'with complete lineage records going back generations.',
      ),
      _FeatureData(
        Icons.science,
        'Genetic Analysis',
        'Calculate Coefficient of Inbreeding (COI) using Wright\'s method. '
            'Identify common ancestors and make informed breeding decisions.',
      ),
      _FeatureData(
        Icons.favorite,
        'Breeding Suggestions',
        'Get AI-powered compatibility scores and breeding pair recommendations '
            'based on genetic diversity, health history, and trait predictions.',
      ),
      _FeatureData(
        Icons.medical_services,
        'Health Records',
        'Track vaccinations, exams, surgeries, and medications. Get reminders '
            'for upcoming and overdue health events.',
      ),
      _FeatureData(
        Icons.tune,
        'Custom Fields',
        'Define your own fields to track breed-specific data like ear tags, '
            'fleece weight, horn status, or any other attribute you need.',
      ),
      _FeatureData(
        Icons.devices,
        'Cross-Platform',
        'Access your data from iOS, Android, or the web. Everything stays '
            'in sync across all your devices.',
      ),
    ];

    return Container(
      color: Colors.grey.shade50,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 24,
        vertical: 64,
      ),
      child: Column(
        children: [
          Text(
            'Everything You Need',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Powerful tools for professional pedigree management',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: features
                .map((f) => SizedBox(
                      width: isWide ? 340 : double.infinity,
                      child: _FeatureCard(feature: f),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 24,
        vertical: 64,
      ),
      child: Column(
        children: [
          Text(
            'Simple, Transparent Pricing',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the plan that fits the size of your operation',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 40),
          if (_tiersLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: _tiers
                  .map((tier) => SizedBox(
                        width: isWide ? 260 : double.infinity,
                        child: _PricingCard(tier: tier),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Only the Enterprise plan supports multiple species and breeds. '
                    'All other plans are limited to a single breed.',
                    style: TextStyle(color: Colors.orange.shade900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeciesSection(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    final speciesData = [
      ('Horse', Icons.cruelty_free, '20 breeds'),
      ('Cattle', Icons.cruelty_free, '20 breeds'),
      ('Sheep', Icons.cruelty_free, '15 breeds'),
      ('Goat', Icons.cruelty_free, '13 breeds'),
      ('Pig', Icons.cruelty_free, '13 breeds'),
      ('Alpaca', Icons.cruelty_free, 'Custom breeds'),
      ('Donkey', Icons.cruelty_free, 'Custom breeds'),
      ('Poultry', Icons.cruelty_free, 'Custom breeds'),
    ];

    return Container(
      color: Colors.grey.shade50,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 24,
        vertical: 64,
      ),
      child: Column(
        children: [
          Text(
            'Built for Farm Animals & Horses',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pre-configured with species-specific breeds, gestation periods, and breeding ages',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: speciesData
                .map((s) => _SpeciesChip(name: s.$1, icon: s.$2, detail: s.$3))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCtaSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor, Color(0xFF1B5E20)],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Ready to Get Started?',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Join hundreds of farms and studs already using Pedigree Manager',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/register'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
              textStyle: const TextStyle(fontSize: 18),
            ),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Create Free Account'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      color: const Color(0xFF1B1B1B),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pets, color: Colors.white54),
              const SizedBox(width: 8),
              Text(
                'Pedigree Manager',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Professional pedigree management for farm animals and horses.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white38,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {},
                child:
                    const Text('Privacy', style: TextStyle(color: Colors.white38)),
              ),
              TextButton(
                onPressed: () {},
                child:
                    const Text('Terms', style: TextStyle(color: Colors.white38)),
              ),
              TextButton(
                onPressed: () {},
                child:
                    const Text('Contact', style: TextStyle(color: Colors.white38)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _scrollToSection(BuildContext context, String section) {
    // For SliverAppBar, just scroll to approximate positions
    // In production, use scroll controller with keys
  }
}

class _FeatureData {
  final IconData icon;
  final String title;
  final String description;
  _FeatureData(this.icon, this.title, this.description);
}

class _FeatureCard extends StatelessWidget {
  final _FeatureData feature;

  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Icon(feature.icon, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              feature.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              feature.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final ServiceTierInfo tier;

  const _PricingCard({required this.tier});

  @override
  Widget build(BuildContext context) {
    final isEnterprise = tier.tier == ServiceTier.enterprise;

    return Card(
      elevation: isEnterprise ? 4 : 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isEnterprise
            ? const BorderSide(color: AppTheme.accentColor, width: 2)
            : BorderSide.none,
      ),
      child: Column(
        children: [
          if (isEnterprise)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(
                color: AppTheme.accentColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: const Text(
                'MOST POPULAR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  tier.label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  tier.isUnlimited ? 'Unlimited' : 'Up to ${tier.maxAnimals}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'animals',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                _pricingFeature(
                  'Pedigree tracking',
                  true,
                ),
                _pricingFeature(
                  'Breeding suggestions',
                  true,
                ),
                _pricingFeature(
                  'Health records',
                  true,
                ),
                _pricingFeature(
                  'Custom fields',
                  true,
                ),
                _pricingFeature(
                  'Multiple breeds',
                  tier.allowsMultiBreed,
                ),
                _pricingFeature(
                  tier.hasUnlimitedUsers
                      ? 'Unlimited team members'
                      : '${tier.maxUsers} team member${tier.maxUsers == 1 ? '' : 's'}',
                  (tier.maxUsers ?? 0) > 1 || tier.hasUnlimitedUsers,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/register'),
                    style: isEnterprise
                        ? ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentColor,
                          )
                        : null,
                    child: const Text('Get Started'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pricingFeature(String text, bool included) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            included ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: included ? AppTheme.primaryColor : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: included ? Colors.grey.shade800 : Colors.grey.shade500,
                decoration: included ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeciesChip extends StatelessWidget {
  final String name;
  final IconData icon;
  final String detail;

  const _SpeciesChip({
    required this.name,
    required this.icon,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Icon(icon, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
            Text(
              detail,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
