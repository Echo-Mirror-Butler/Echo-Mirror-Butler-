import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../core/themes/app_theme.dart';
import '../../features/dashboard/view/screens/dashboard_screen.dart';
import '../../features/logging/view/screens/logging_screen.dart';
import '../../features/settings/view/screens/settings_screen.dart';

/// Main navigation screen with bottom navigation bar
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: FontAwesomeIcons.chartLine,
      label: 'Dashboard',
      route: '/dashboard',
      screen: const DashboardScreen(),
    ),
    NavigationItem(
      icon: FontAwesomeIcons.book,
      label: 'Logging',
      route: '/logging',
      screen: const LoggingScreen(),
    ),
    NavigationItem(
      icon: FontAwesomeIcons.gear,
      label: 'Settings',
      route: '/settings',
      screen: const SettingsScreen(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 1.0,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync current index with current route
    _updateIndexFromRoute();
  }

  void _updateIndexFromRoute() {
    final currentLocation = GoRouterState.of(context).matchedLocation;
    final index = _navigationItems.indexWhere(
      (item) {
        // Match exact route or routes that start with the item route
        return currentLocation == item.route ||
               currentLocation.startsWith('${item.route}/');
      },
    );
    if (index != -1 && index != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentIndex = index;
          });
          _pageController.jumpToPage(index);
        }
      });
    }
  }

  void _onItemTapped(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });

      // Animate to the new page with smooth curve
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );

      // Navigate to the route for browser back/forward support
      context.go(_navigationItems[index].route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const ClampingScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Update route when page changes via swipe
          context.go(_navigationItems[index].route);
        },
        children: _navigationItems.map((item) => item.screen).toList(),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(theme, isDark),
    );
  }

  Widget _buildBottomNavigationBar(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, -8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: GNav(
            rippleColor: AppTheme.primaryColor.withOpacity(0.1),
            hoverColor: AppTheme.primaryColor.withOpacity(0.1),
            gap: 6,
            activeColor: AppTheme.primaryColor,
            iconSize: 26,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            duration: const Duration(milliseconds: 400),
            tabBackgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            color: isDark
                ? Colors.white.withOpacity(0.5)
                : Colors.black.withOpacity(0.5),
            selectedIndex: _currentIndex,
            onTabChange: _onItemTapped,
            tabs: [
              GButton(
                icon: FontAwesomeIcons.chartLine,
                text: 'Dashboard',
                textStyle: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              GButton(
                icon: FontAwesomeIcons.book,
                text: 'Logging',
                textStyle: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              GButton(
                icon: FontAwesomeIcons.gear,
                text: 'Settings',
                textStyle: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
            curve: Curves.easeInOutCubic,
            haptic: true,
          ),
        ),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final String route;
  final Widget screen;

  NavigationItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.screen,
  });
}
