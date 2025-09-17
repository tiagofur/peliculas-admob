import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/providers/custom_lists_providers.dart';
import '../../../services/lists_fix_service.dart';

/// Widget temporal para probar y debugear las listas
class ListsDebugView extends ConsumerStatefulWidget {
  const ListsDebugView({super.key});

  @override
  ConsumerState<ListsDebugView> createState() => _ListsDebugViewState();
}

class _ListsDebugViewState extends ConsumerState<ListsDebugView> {
  final TextEditingController _movieIdController = TextEditingController();
  String? _selectedListId;
  bool _isProcessing = false;

  @override
  void dispose() {
    _movieIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(userListsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug: Listas Personalizadas'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Herramientas de diagnóstico
            ListsFixService.buildDiagnosticWidget(ref, onMessage: _showMessage),

            const SizedBox(height: 20),

            // Estado de las listas
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.list, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Estado de las Listas',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    listsAsync.when(
                      data: (lists) {
                        final defaultLists =
                            lists.where((list) => list.isDefault).toList();
                        final customLists =
                            lists.where((list) => !list.isDefault).toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('✅ Total de listas: ${lists.length}'),
                            Text(
                                '📋 Listas por defecto: ${defaultLists.length}'),
                            Text(
                                '📝 Listas personalizadas: ${customLists.length}'),
                            const SizedBox(height: 16),
                            const Text('Listas por defecto:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            ...defaultLists.map((list) => Padding(
                                  padding:
                                      const EdgeInsets.only(left: 16, top: 4),
                                  child: Text(
                                      '${list.emoji} ${list.name} (${list.movieIds.length} películas)'),
                                )),
                            if (customLists.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Text('Listas personalizadas:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              ...customLists.map((list) => Padding(
                                    padding:
                                        const EdgeInsets.only(left: 16, top: 4),
                                    child: Text(
                                        '${list.emoji} ${list.name} (${list.movieIds.length} películas)'),
                                  )),
                            ],
                          ],
                        );
                      },
                      loading: () => const Row(
                        children: [
                          SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Cargando listas...'),
                        ],
                      ),
                      error: (error, stack) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('❌ Error cargando listas:',
                              style: TextStyle(color: Colors.red)),
                          Text(error.toString(),
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Herramienta para añadir película a lista
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.movie, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Añadir Película a Lista',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Selector de lista
                    listsAsync.when(
                      data: (lists) {
                        if (lists.isEmpty) {
                          return const Text(
                              'No hay listas disponibles. Crea algunas primero.');
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Selecciona una lista:'),
                            const SizedBox(height: 8),
                            DropdownButton<String>(
                              value: _selectedListId,
                              hint: const Text('Seleccionar lista'),
                              isExpanded: true,
                              onChanged: (String? value) {
                                setState(() {
                                  _selectedListId = value;
                                });
                              },
                              items:
                                  lists.map<DropdownMenuItem<String>>((list) {
                                return DropdownMenuItem<String>(
                                  value: list.id,
                                  child: Text('${list.emoji} ${list.name}'),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 16),

                            // Campo para ID de película
                            TextField(
                              controller: _movieIdController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'ID de Película (TMDB)',
                                hintText: 'Ej: 550 (Fight Club)',
                                border: OutlineInputBorder(),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Botón para añadir
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _selectedListId != null &&
                                        _movieIdController.text.isNotEmpty &&
                                        !_isProcessing
                                    ? () => _addMovieToList()
                                    : null,
                                icon: _isProcessing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.add),
                                label: Text(_isProcessing
                                    ? 'Añadiendo...'
                                    : 'Añadir Película'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            const Text(
                              'IDs de ejemplo: 550 (Fight Club), 238 (Shawshank), 680 (Pulp Fiction)',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        );
                      },
                      loading: () => const Text('Cargando listas...'),
                      error: (error, stack) => Text('Error: $error'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Botón para recargar todo
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(userListsProvider);
                  ref.invalidate(customListsNotifierProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Recargar Listas'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addMovieToList() async {
    final movieIdText = _movieIdController.text.trim();
    final movieId = int.tryParse(movieIdText);

    if (movieId == null || _selectedListId == null) {
      _showMessage(
          'Por favor, ingresa un ID de película válido y selecciona una lista.');
      return;
    }

    if (_isProcessing) {
      _showMessage('Ya hay una operación en proceso. Espera un momento.');
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
      });

      _showMessage('🎬 Añadiendo película...', isError: false);

      final result = await ListsFixService.testAddMovieToList(
          ref, _selectedListId!, movieId);

      _showMessage(result, isError: !result.contains('✅'));

      if (result.contains('✅')) {
        _movieIdController.clear();
        setState(() {
          _selectedListId = null;
        });
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }
}
