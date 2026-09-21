import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  const AppBottomNav({super.key, required this.currentIndex});

  static const _routes = ['/home', '/map', '/upload', '/history', '/profile'];
  static const _labels = ['Home', 'Map', 'Scan', 'Reports', 'Profile'];
  
  static const _icons = [
    Icons.home_outlined,
    Icons.map_outlined,
    Icons.center_focus_weak_rounded, // Center Scan
    Icons.description_outlined,      // Reports
    Icons.person_outline_rounded,
  ];

  static const _activeIcons = [
    Icons.home_rounded,
    Icons.map_rounded,
    Icons.center_focus_weak_rounded,
    Icons.description_rounded,
    Icons.person_rounded,
  ];

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(5, (i) {
            final active = i == currentIndex;
            final color = active
                ? AppColors.primaryDark
                : (isDark ? AppColors.darkTextGrey : AppColors.textGrey);

            // Special circular green design for the center Scan button (Index 2)
            if (i == 2) {
              return GestureDetector(
                onTap: () => _onTap(context, i),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDark.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: const Icon(
                    Icons.center_focus_weak_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              );
            }

            return GestureDetector(
              onTap: () => _onTap(context, i),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 60,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      active ? _activeIcons[i] : _icons[i],
                      color: color,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _labels[i],
                      maxLines: 1,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: active ? FontWeight.bold : FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
