import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class StatisticsView extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const StatisticsView({super.key, required this.navigationShell});

  @override
  State<StatisticsView> createState() => _StatisticsViewState();
}

class _StatisticsViewState extends State<StatisticsView>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2, // 2 tabs: overview, achievements
      vsync: this,
      initialIndex: widget.navigationShell.currentIndex,
    );

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        widget.navigationShell.goBranch(
          _tabController.index,
          initialLocation: _tabController.index == widget.navigationShell.currentIndex,
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant StatisticsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationShell.currentIndex != _tabController.index) {
      _tabController.index = widget.navigationShell.currentIndex;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                floating: true,
                pinned: true,
                snap: false,
                elevation: 0,
                backgroundColor: colors.surface,
                surfaceTintColor: colors.surface,
                title: Text(
                  'Estadísticas',
                  style: textStyles.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: colors.primary,
                  labelColor: colors.primary,
                  unselectedLabelColor: colors.onSurface.withAlpha(153),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                  isScrollable: false,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.analytics_outlined, size: 20),
                      text: 'Estadísticas',
                    ),
                    Tab(
                      icon: Icon(Icons.emoji_events_outlined, size: 20),
                      text: 'Logros',
                    ),
                  ],
                ),
              ),
            ];
          },
          body: widget.navigationShell,
        ),
      ),
    );
  }
}
