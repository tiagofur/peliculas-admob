import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/custom_lists_provider.dart';

class ListsView extends ConsumerWidget {
  const ListsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(listsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Listas'),
      ),
      body: ListView.builder(
        itemCount: lists.length,
        itemBuilder: (context, index) {
          final list = lists[index];
          return ListTile(
            leading: list.emoji.isNotEmpty
                ? Text(list.emoji, style: const TextStyle(fontSize: 24))
                : null,
            title: Text(list.name),
            subtitle:
                list.description.isNotEmpty ? Text(list.description) : null,
            trailing: Text('${list.movieIds.length} películas'),
            onTap: () {
              context.go('/my-library/lists/${list.id}');
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              final nameController = TextEditingController();
              final descriptionController = TextEditingController();
              final emojiController = TextEditingController();
              final colorController = TextEditingController();

              return AlertDialog(
                title: const Text('Crear nueva lista'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration:
                          const InputDecoration(labelText: 'Descripción'),
                    ),
                    TextField(
                      controller: emojiController,
                      decoration: const InputDecoration(labelText: 'Emoji'),
                    ),
                    TextField(
                      controller: colorController,
                      decoration:
                          const InputDecoration(labelText: 'Color (Hex)'),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(allListsNotifierProvider.notifier).createList(
                            name: nameController.text,
                            description: descriptionController.text,
                            emoji: emojiController.text,
                            color: colorController.text,
                          );
                      Navigator.of(context).pop();
                    },
                    child: const Text('Crear'),
                  ),
                ],
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
