import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayuda y Soporte'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: const [
          Text(
            'Preguntas Frecuentes (FAQ)',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          ExpansionTile(
            title: Text('¿Cómo puedo agregar una película a mi watchlist?'),
            children: [
              Padding(
                padding: EdgeInsets.all(15.0),
                child: Text(
                    'Para agregar una película, simplemente ve a los detalles de la película y presiona el ícono de "Agregar a Watchlist".'),
              ),
            ],
          ),
          ExpansionTile(
            title: Text('¿Cómo funciona la sincronización?'),
            children: [
              Padding(
                padding: EdgeInsets.all(15.0),
                child: Text(
                    'Tus datos se sincronizan automáticamente entre todos tus dispositivos cuando tienes conexión a internet. Si estás offline, los cambios se guardarán localmente y se sincronizarán la próxima vez que te conectes.'),
              ),
            ],
          ),
          ExpansionTile(
            title: Text('¿Cómo contacto a soporte?'),
            children: [
              Padding(
                padding: EdgeInsets.all(15.0),
                child: Text(
                    'Puedes contactarnos por correo electrónico a: soporte@peliculasapp.com'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
