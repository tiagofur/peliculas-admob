import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MyLibraryView extends StatefulWidget {
  const MyLibraryView({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  State<MyLibraryView> createState() => _MyLibraryViewState();
}

class _MyLibraryViewState extends State<MyLibraryView>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4, // 4 tabs: favorites, watchlist, watched, lists
      vsync: this,
      initialIndex: widget.navigationShell.currentIndex,
    );

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        widget.navigationShell.goBranch(
          _tabController.index,
          initialLocation:
              _tabController.index == widget.navigationShell.currentIndex,
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant MyLibraryView oldWidget) {
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
                  'Mi Biblioteca',
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
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.favorite_outline, size: 20),
                      text: 'Favoritos',
                    ),
                    Tab(
                      icon: Icon(Icons.bookmark_outline, size: 20),
                      text: 'Watchlist',
                    ),
                    Tab(
                      icon: Icon(Icons.visibility_outlined, size: 20),
                      text: 'Vistas',
                    ),
                    Tab(
                      icon: Icon(Icons.list_alt, size: 20),
                      text: 'Listas',
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
