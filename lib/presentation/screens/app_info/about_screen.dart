import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const appVersion = '1.2.1+6'; // Versión hardcodeada desde pubspec.yaml

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acerca de'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Versión de la aplicación'),
            subtitle: Text(appVersion),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('Desarrollado por'),
            subtitle: Text('Tu Nombre o Nombre de tu Compañía'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Política de Privacidad'),
            onTap: () {
              context.push('/privacy-policy');
            },
          ),
        ],
      ),
    );
  }
}
