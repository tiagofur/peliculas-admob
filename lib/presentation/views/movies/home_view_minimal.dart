import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger_factory.dart';
import '../../widgets/widgets.dart';

class HomeViewMinimal extends ConsumerStatefulWidget {
  const HomeViewMinimal({super.key});

  @override
  HomeViewMinimalState createState() => HomeViewMinimalState();
}

class HomeViewMinimalState extends ConsumerState<HomeViewMinimal>
    with AutomaticKeepAliveClientMixin {
  @override
  void initState() {
    super.initState();
    LoggerFactory.info('🏠 HomeViewMinimal - initState called');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    LoggerFactory.info('🏠 HomeViewMinimal - build called');

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverAppBar(
            floating: true,
            flexibleSpace: FlexibleSpaceBar(
              title: CustomAppbar(),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return const Column(
                  children: [
                    SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Películas App',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Versión mínima para debug',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    SizedBox(height: 40),
                    Card(
                      margin: EdgeInsets.all(16),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.movie,
                              size: 64,
                              color: Colors.blue,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'UI cargada exitosamente',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'La aplicación está funcionando correctamente',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                );
              },
              childCount: 1,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}