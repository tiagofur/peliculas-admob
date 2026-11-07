import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/custom_drawer.dart';
import '../../widgets/shared/custom_bottom_navigation.dart';
import '../../widgets/sync/silent_sync_indicator.dart';

class SimpleHomeScreen extends StatelessWidget {
  const SimpleHomeScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const name = 'simple-home-screen';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      drawer: const CustomDrawer(),
      body: Stack(
        children: [
          navigationShell,
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SilentSyncIndicator(),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavigation(
        currentIndex: navigationShell.currentIndex,
        onItemTapped: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == 1,
          );
        },
      ),
    );
  }
}
