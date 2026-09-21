import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/admin_provider.dart';
import '../../../core/theme/app_theme.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminProvider);
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrative Control'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/profile'),
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(state.error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => ref.read(adminProvider.notifier).loadAdminData(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Stats metrics row
                      Row(
                        children: [
                          Expanded(
                            child: _AdminStatTile(
                              label: 'Total Users',
                              value: '${state.stats.totalUsers}',
                              color: AppColors.info,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _AdminStatTile(
                              label: 'Total Farms',
                              value: '${state.stats.totalFarms}',
                              color: AppColors.healthy,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _AdminStatTile(
                              label: 'Analyses Run',
                              value: '${state.stats.totalAnalyses}',
                              color: AppColors.atRisk,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Chart visualization
                      const Text(
                        'Crop Distribution Analytics',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 180,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                        ),
                        child: state.stats.cropDistribution.isEmpty
                            ? const Center(child: Text('No crop data available'))
                            : PieChart(
                                PieChartData(
                                  sections: state.stats.cropDistribution.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final val = entry.value;
                                    final count = val['count'] as int;

                                    // Rotate through colors
                                    final colors = [
                                      AppColors.primary,
                                      AppColors.primaryLight,
                                      AppColors.info,
                                      AppColors.atRisk,
                                      AppColors.danger,
                                    ];
                                    final color = colors[index % colors.length];

                                    return PieChartSectionData(
                                      color: color,
                                      value: count.toDouble(),
                                      title: '${val['crop']}\n($count)',
                                      radius: 65,
                                      titleStyle: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    );
                                  }).toList(),
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 15,
                                ),
                              ),
                      ),
                      const SizedBox(height: 24),

                      // User list
                      const Text(
                        'User Profiles',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.usersList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final user = state.usersList[i];
                          final role = user['role'] ?? 'user';
                          final isUserAdmin = role == 'admin';

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : AppColors.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isUserAdmin ? Colors.orange.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                                  child: Icon(
                                    isUserAdmin ? Icons.admin_panel_settings_outlined : Icons.person_outline,
                                    color: isUserAdmin ? Colors.orange : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user['full_name'] ?? 'Farmer',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        user['email'] ?? '',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppColors.darkTextGrey : AppColors.textGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DropdownButton<String>(
                                  value: role,
                                  items: const [
                                    DropdownMenuItem(value: 'user', child: Text('User')),
                                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      ref.read(adminProvider.notifier).updateUserRole(user['id'], val);
                                    }
                                  },
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
    );
  }
}

class _AdminStatTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _AdminStatTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppColors.darkTextGrey : AppColors.textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
