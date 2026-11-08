import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/logging/logger_factory.dart';

/// Widget optimizado para listas grandes con control inteligente de memoria
/// y renderizado eficiente
class OptimizedListView<T> extends StatefulWidget {
  const OptimizedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.onLoadMore,
    this.loadMoreThreshold = 3,
    this.enableAutomaticKeepAlive = false,
    this.shrinkWrap = false,
    this.scrollDirection = Axis.vertical,
    this.physics,
    this.controller,
    this.addAutomaticKeepAlives = true,
    this.cacheExtent,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.clipBehavior = Clip.hardEdge,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.estimatedItemHeight,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final VoidCallback? onLoadMore;
  final int loadMoreThreshold;
  final bool enableAutomaticKeepAlive;
  final bool shrinkWrap;
  final Axis scrollDirection;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final bool addAutomaticKeepAlives;
  final double? cacheExtent;
  final int? semanticChildCount;
  final DragStartBehavior dragStartBehavior;
  final Clip clipBehavior;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final String? restorationId;
  final double? estimatedItemHeight;

  @override
  State<OptimizedListView<T>> createState() => _OptimizedListViewState<T>();
}

class _OptimizedListViewState<T> extends State<OptimizedListView<T>>
    with AutomaticKeepAliveClientMixin {
  final _logger = LoggerFactory.logger;
  ScrollController? _controller;
  bool _isLoadingMore = false;

  @override
  bool get wantKeepAlive => widget.enableAutomaticKeepAlive;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ScrollController();
    _setupLoadMoreListener();
  }

  @override
  void didUpdateWidget(OptimizedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller?.removeListener(_onScroll);
      _controller = widget.controller ?? ScrollController();
      _setupLoadMoreListener();
    }
  }

  void _setupLoadMoreListener() {
    if (widget.onLoadMore != null) {
      _controller?.addListener(_onScroll);
    }
  }

  void _onScroll() {
    if (_isLoadingMore || widget.onLoadMore == null) return;

    final position = _controller?.position;
    if (position == null) return;

    // Calcular umbral basado en altura estimada o usar pixels
    final threshold = widget.estimatedItemHeight != null
        ? widget.estimatedItemHeight! * widget.loadMoreThreshold
        : 200.0;

    if ((position.pixels + threshold) >= position.maxScrollExtent) {
      _triggerLoadMore();
    }
  }

  void _triggerLoadMore() {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    _logger.debug('Cargando más elementos...');

    // Usar post frame callback para evitar problemas de estado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onLoadMore?.call();
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller?.dispose();
    } else {
      _controller?.removeListener(_onScroll);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.items.isEmpty) {
      return const Center(
        child: Text('No hay elementos para mostrar'),
      );
    }

    return ListView.builder(
      scrollCacheExtent: widget.cacheExtent != null
          ? ScrollCacheExtent.pixels(widget.cacheExtent!)
          : null,
      controller: _controller,
      itemCount: widget.items.length + (_isLoadingMore ? 1 : 0),
      shrinkWrap: widget.shrinkWrap,
      scrollDirection: widget.scrollDirection,
      physics: widget.physics,
      addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
      semanticChildCount: widget.semanticChildCount,
      dragStartBehavior: widget.dragStartBehavior,
      clipBehavior: widget.clipBehavior,
      keyboardDismissBehavior: widget.keyboardDismissBehavior,
      restorationId: widget.restorationId,
      itemBuilder: (context, index) {
        // Loading indicator al final
        if (index >= widget.items.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final item = widget.items[index];

        // Wrap en RepaintBoundary para mejor performance
        return RepaintBoundary(
          child: widget.itemBuilder(context, item, index),
        );
      },
    );
  }
}

/// Widget para listas de grilla optimizadas
class OptimizedGridView<T> extends StatefulWidget {
  const OptimizedGridView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.crossAxisCount,
    this.onLoadMore,
    this.loadMoreThreshold = 6,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.childAspectRatio = 1.0,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
    this.cacheExtent,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.clipBehavior = Clip.hardEdge,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int crossAxisCount;
  final VoidCallback? onLoadMore;
  final int loadMoreThreshold;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final double? cacheExtent;
  final int? semanticChildCount;
  final DragStartBehavior dragStartBehavior;
  final Clip clipBehavior;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final String? restorationId;

  @override
  State<OptimizedGridView<T>> createState() => _OptimizedGridViewState<T>();
}

class _OptimizedGridViewState<T> extends State<OptimizedGridView<T>> {
  final _logger = LoggerFactory.logger;
  ScrollController? _controller;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ScrollController();
    _setupLoadMoreListener();
  }

  @override
  void didUpdateWidget(OptimizedGridView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller?.removeListener(_onScroll);
      _controller = widget.controller ?? ScrollController();
      _setupLoadMoreListener();
    }
  }

  void _setupLoadMoreListener() {
    if (widget.onLoadMore != null) {
      _controller?.addListener(_onScroll);
    }
  }

  void _onScroll() {
    if (_isLoadingMore || widget.onLoadMore == null) return;

    final position = _controller?.position;
    if (position == null) return;

    if ((position.pixels + 200) >= position.maxScrollExtent) {
      _triggerLoadMore();
    }
  }

  void _triggerLoadMore() {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    _logger.debug('Cargando más elementos en grilla...');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onLoadMore?.call();
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller?.dispose();
    } else {
      _controller?.removeListener(_onScroll);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Center(
        child: Text('No hay elementos para mostrar'),
      );
    }

    final totalItems =
        widget.items.length + (_isLoadingMore ? widget.crossAxisCount : 0);

    return GridView.builder(
      scrollCacheExtent: widget.cacheExtent != null
          ? ScrollCacheExtent.pixels(widget.cacheExtent!)
          : null,
      controller: _controller,
      itemCount: totalItems,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      semanticChildCount: widget.semanticChildCount,
      dragStartBehavior: widget.dragStartBehavior,
      clipBehavior: widget.clipBehavior,
      keyboardDismissBehavior: widget.keyboardDismissBehavior,
      restorationId: widget.restorationId,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        mainAxisSpacing: widget.mainAxisSpacing,
        crossAxisSpacing: widget.crossAxisSpacing,
        childAspectRatio: widget.childAspectRatio,
      ),
      itemBuilder: (context, index) {
        // Loading indicators al final
        if (index >= widget.items.length) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final item = widget.items[index];

        // Wrap en RepaintBoundary para mejor performance
        return RepaintBoundary(
          child: widget.itemBuilder(context, item, index),
        );
      },
    );
  }
}

/// Extensión para análisis de rendimiento de listas
extension ListPerformanceAnalyzer on Widget {
  /// Envuelve el widget con análisis de rendimiento
  Widget withPerformanceMonitoring({String? debugLabel}) {
    return Builder(
      builder: (context) {
        final logger = LoggerFactory.logger;

        return RepaintBoundary(
          child: Builder(
            builder: (context) {
              // Solo en modo debug
              if (kDebugMode && debugLabel != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final renderObject = context.findRenderObject();
                  if (renderObject is RenderBox) {
                    logger.debug('Performance [$debugLabel]: '
                        'Size: ${renderObject.size}, '
                        'Positioned: ${renderObject.attached}');
                  }
                });
              }

              return this;
            },
          ),
        );
      },
    );
  }
}
