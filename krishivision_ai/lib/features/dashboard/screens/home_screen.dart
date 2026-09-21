import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../widgets/bottom_nav.dart';
import '../../../core/theme/app_theme.dart';

import '../../../core/services/startup_trace.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StartupTrace.markT5('HomeScreen');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(dashboardProvider.notifier).loadDashboard();
    }
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good Morning 🌅';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon ☀️';
    } else if (hour >= 17 && hour < 21) {
      return 'Good Evening 🌇';
    } else {
      return 'Good Night 🌙';
    }
  }

  String _getFormattedDate() {
    return DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
  }

  void _showNotificationsDialog(BuildContext context, List<dynamic> list, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.notifications_active_outlined, color: AppColors.primaryDark),
              const SizedBox(width: 10),
              const Text('Notifications'),
            ],
          ),
          content: list.isEmpty
              ? const SizedBox(
                  height: 100,
                  child: Center(
                    child: Text('No new alerts. You are all caught up!'),
                  ),
                )
              : SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final item = list[i];
                      IconData icon = Icons.info_outline;
                      Color iconColor = AppColors.info;
                      if (item['type'] == 'weather') {
                        icon = Icons.cloud_outlined;
                        iconColor = AppColors.atRisk;
                      } else if (item['type'] == 'disease') {
                        icon = Icons.bug_report_outlined;
                        iconColor = AppColors.danger;
                      } else if (item['type'] == 'harvest') {
                        icon = Icons.eco_outlined;
                        iconColor = AppColors.healthy;
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: iconColor.withOpacity(0.1),
                          child: Icon(icon, color: iconColor),
                        ),
                        title: Text(
                          item['title'] ?? 'Alert',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(item['message'] ?? '', style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              item['created_at'] != null
                                  ? DateFormat('dd MMM hh:mm a').format(DateTime.parse(item['created_at']))
                                  : '',
                              style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextGrey : AppColors.textGrey),
                            ),
                          ],
                        ),
                        contentPadding: EdgeInsets.zero,
                      );
                    },
                  ),
                ),
          actions: [
            if (list.isNotEmpty)
              TextButton(
                onPressed: () {
                  ref.read(dashboardProvider.notifier).markNotificationsAsRead();
                  Navigator.pop(context);
                },
                child: const Text('Mark all read'),
              ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final dashState = ref.watch(dashboardProvider);
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    final unreadCount = dashState.notifications.where((n) => !(n['read'] as bool? ?? false)).length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      drawer: Drawer(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: ClipOval(
                  child: authState.profilePicture != null && authState.profilePicture!.isNotEmpty
                      ? (authState.profilePicture!.startsWith('http') || authState.profilePicture!.startsWith('/static/'))
                          ? Image.network(
                              authState.fullProfilePictureUrl,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  'assets/app_logo.png',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : File(authState.profilePicture!).existsSync()
                              ? Image.file(
                                  File(authState.profilePicture!),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                )
                              : Image.asset(
                                  'assets/app_logo.png',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                )
                      : Image.asset(
                          'assets/app_logo.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              accountName: Text(
                authState.fullName ?? 'Farmer Profile',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(authState.email ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined, color: AppColors.primaryDark),
              title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined, color: AppColors.primaryDark),
              title: const Text('Interactive Map'),
              onTap: () {
                Navigator.pop(context);
                context.go('/map');
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded, color: AppColors.primaryDark),
              title: const Text('Analysis History'),
              onTap: () {
                Navigator.pop(context);
                context.go('/history');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline, color: AppColors.primaryDark),
              title: const Text('Profile Settings'),
              onTap: () {
                Navigator.pop(context);
                context.go('/profile');
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: const Text('Logout', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                ref.read(authProvider.notifier).logout();
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('KrishiVision', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.primaryDark),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, size: 28, color: AppColors.primaryDark),
                onPressed: () => _showNotificationsDialog(context, dashState.notifications, ref),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(dashboardProvider.notifier).loadDashboard(),
        color: AppColors.primaryDark,
        child: dashState.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryDark))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dynamic Hello Greeting & Time/Date
                    Text(
                      'Hello, ${authState.fullName ?? 'Krishi Admin'}! 👋',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getTimeGreeting(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getFormattedDate(),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextGrey : AppColors.textGrey),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Here's your farm overview",
                      style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    // Large Monitored Area landscape card matching reference
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F5132), Color(0xFF198754)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F5132).withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -10,
                            bottom: -10,
                            child: Icon(
                              Icons.landscape_rounded,
                              size: 110,
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Monitored Area',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                NumberFormat('#,##,###').format(dashState.stats.monitoredAreaAcres),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Acres',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Four colored statistic cards matching reference colors
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.45,
                      children: [
                        _buildColorStatCard(
                          'Healthy Area',
                          '${NumberFormat('#,##,###').format(dashState.stats.healthyAreaAcres)} Acres',
                          Icons.favorite_rounded,
                          AppColors.healthy, // Green
                          isDark,
                        ),
                        _buildColorStatCard(
                          'At Risk Area',
                          '${NumberFormat('#,##,###').format(dashState.stats.atRiskAreaAcres)} Acres',
                          Icons.warning_rounded,
                          AppColors.atRisk, // Orange
                          isDark,
                        ),
                        _buildColorStatCard(
                          'Total Crops',
                          '${dashState.stats.totalCropsCount} Types',
                          Icons.grass_rounded,
                          AppColors.cropPurple, // Purple
                          isDark,
                        ),
                        _buildColorStatCard(
                          'Upcoming Harvest',
                          '${dashState.stats.upcomingHarvestCount} Crops',
                          Icons.alarm_rounded,
                          AppColors.info, // Blue
                          isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Recent alerts header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Alerts',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () => context.go('/history'),
                          child: const Text(
                            'View All',
                            style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (dashState.alerts.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        alignment: Alignment.center,
                        child: const Text('No active anomalies detected.', style: TextStyle(color: AppColors.textGrey)),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: dashState.alerts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final alert = dashState.alerts[idx];
                          final type = alert['type'] ?? 'info';
                          IconData alertIcon = Icons.info_outline;
                          Color alertColor = AppColors.info;
                          if (type == 'warning' || type == 'disease') {
                            alertIcon = Icons.bug_report_outlined;
                            alertColor = AppColors.atRisk;
                          } else if (type == 'harvest') {
                            alertIcon = Icons.eco_outlined;
                            alertColor = AppColors.healthy;
                          }

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: alertColor.withOpacity(0.1),
                                  child: Icon(alertIcon, color: alertColor),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        alert['title'] ?? 'Alert',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        alert['message'] ?? '',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _buildColorStatCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 16),
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textGrey),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
