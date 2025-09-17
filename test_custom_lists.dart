// Test manual para probar la creación de listas personalizadas
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lib/domain/entities/custom_list.dart';
import 'lib/infrastructure/datasources/supabase_custom_lists_datasource.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🧪 Iniciando test de listas personalizadas...');

  try {
    // Inicializar Supabase (usando configuración de test)
    await Supabase.initialize(
      url: 'https://your_supabase_url',
      anonKey: 'your_anon_key',
    );

    // Crear datasource
    final datasource = SupabaseCustomListsDataSource(Supabase.instance.client);

    // Crear lista de prueba
    final testList = CustomList(
      id: 'test_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Lista de Prueba',
      description: 'Lista creada para probar la funcionalidad',
      emoji: '🧪',
      movieIds: [],
      createdAt: DateTime.now(),
      lastModifiedAt: DateTime.now(),
      isDefault: false,
      color: 'blue',
      userId: 'test_user_id',
    );

    print('📝 Creando lista: ${testList.name}');

    // Intentar crear la lista
    final createdList = await datasource.createList(testList);

    print('✅ Lista creada exitosamente:');
    print('   ID: ${createdList.id}');
    print('   Nombre: ${createdList.name}');
    print('   Descripción: ${createdList.description}');
    print('   Usuario: ${createdList.userId}');

    // Verificar que se puede obtener
    final retrievedList = await datasource.getListById(createdList.id);

    if (retrievedList != null) {
      print('✅ Lista recuperada exitosamente');
    } else {
      print('❌ No se pudo recuperar la lista');
    }
  } catch (e) {
    print('❌ Error en el test: $e');
  }
}
