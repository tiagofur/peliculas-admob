import 'package:flutter/material.dart';

import '../../../domain/entities/serie.dart';
import 'serie_card.dart';

class SerieHorizontalListview extends StatefulWidget {
  const SerieHorizontalListview({
    super.key,
    required this.series,
    this.title,
    this.subTitle,
    this.loadNextPage,
  });

  final List<Serie> series;
  final String? title;
  final String? subTitle;
  final VoidCallback? loadNextPage;

  @override
  State<SerieHorizontalListview> createState() =>
      _SerieHorizontalListviewState();
}

class _SerieHorizontalListviewState extends State<SerieHorizontalListview> {
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    scrollController.addListener(() {
      if (widget.loadNextPage == null) return;
      if (!scrollController.hasClients) return;
      final threshold = scrollController.position.maxScrollExtent * 0.8;
      if (scrollController.position.pixels >= threshold) {
        widget.loadNextPage!();
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title!,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.subTitle != null)
                  Text(
                    widget.subTitle!,
                    style: const TextStyle(fontSize: 13),
                  ),
              ],
            ),
          ),
        SizedBox(
          height: 250,
          child: ListView.builder(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: widget.series.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SerieCard(serie: widget.series[index]),
            ),
          ),
        ),
      ],
    );
  }
}
