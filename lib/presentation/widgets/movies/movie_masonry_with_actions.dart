import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../domain/entities/movie.dart';
import 'movie_card_with_actions.dart';

class MovieMasonryWithActions extends StatefulWidget {
  const MovieMasonryWithActions(
      {super.key, required this.movies, this.loadNextPage});

  final List<Movie> movies;
  final VoidCallback? loadNextPage;

  @override
  State<MovieMasonryWithActions> createState() =>
      _MovieMasonryWithActionsState();
}

class _MovieMasonryWithActionsState extends State<MovieMasonryWithActions> {
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    scrollController.addListener(() {
      if (widget.loadNextPage == null) return;

      if ((scrollController.position.pixels + 100) >=
          scrollController.position.maxScrollExtent) {
        widget.loadNextPage?.call();
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: MasonryGridView.count(
        controller: scrollController,
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        itemCount: widget.movies.length,
        itemBuilder: (context, index) {
          if (index == 1) {
            return Column(
              children: [
                const SizedBox(height: 20),
                MovieCardWithActions(movie: widget.movies[index])
              ],
            );
          }

          return MovieCardWithActions(movie: widget.movies[index]);
        },
      ),
    );
  }
}
