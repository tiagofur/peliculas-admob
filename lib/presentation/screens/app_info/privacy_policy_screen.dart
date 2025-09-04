import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Política de Privacidad'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Política de Privacidad',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Última actualización: Enero 2025',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 24),
            _SectionWidget(
              title: '1. Información que Recopilamos',
              content:
                  'Recopilamos información que nos proporcionas directamente, como cuando creas una cuenta, agregas películas a tus listas, o nos contactas para soporte. Esta información puede incluir:\n\n• Información de cuenta (nombre de usuario, email)\n• Preferencias de películas y listas personalizadas\n• Información de uso de la aplicación\n• Datos de dispositivo y técnicos para mejorar el rendimiento',
            ),
            _SectionWidget(
              title: '2. Cómo Utilizamos tu Información',
              content:
                  'Utilizamos la información recopilada para:\n\n• Proporcionar y mantener nuestros servicios\n• Personalizar tu experiencia con recomendaciones\n• Sincronizar tus datos entre dispositivos\n• Mejorar la funcionalidad de la aplicación\n• Comunicarnos contigo sobre actualizaciones o soporte\n• Analizar el uso para mejorar nuestros servicios',
            ),
            _SectionWidget(
              title: '3. Compartir Información',
              content:
                  'No vendemos, intercambiamos o transferimos tu información personal a terceros, excepto en los siguientes casos:\n\n• Con tu consentimiento explícito\n• Para cumplir con obligaciones legales\n• Para proteger nuestros derechos y seguridad\n• Con proveedores de servicios que nos ayudan a operar la aplicación (bajo estrictos acuerdos de confidencialidad)',
            ),
            _SectionWidget(
              title: '4. Seguridad de Datos',
              content:
                  'Implementamos medidas de seguridad técnicas y organizativas apropiadas para proteger tu información personal contra acceso no autorizado, alteración, divulgación o destrucción. Esto incluye:\n\n• Encriptación de datos en tránsito y en reposo\n• Autenticación segura\n• Monitoreo regular de seguridad\n• Acceso limitado a datos personales por parte del personal',
            ),
            _SectionWidget(
              title: '5. Tus Derechos',
              content:
                  'Tienes derecho a:\n\n• Acceder a tu información personal\n• Corregir información inexacta\n• Solicitar la eliminación de tus datos\n• Portabilidad de datos\n• Retirar el consentimiento en cualquier momento\n• Presentar una queja ante las autoridades de protección de datos\n\nPara ejercer estos derechos, contáctanos a través de los medios proporcionados en esta política.',
            ),
            _SectionWidget(
              title: '6. Retención de Datos',
              content:
                  'Conservamos tu información personal solo durante el tiempo necesario para cumplir con los propósitos descritos en esta política, a menos que la ley requiera o permita un período de retención más largo. Cuando elimines tu cuenta, procederemos a eliminar o anonimizar tu información personal.',
            ),
            _SectionWidget(
              title: '7. Servicios de Terceros',
              content:
                  'Nuestra aplicación puede integrar servicios de terceros como:\n\n• The Movie Database (TMDb) para información de películas\n• Servicios de autenticación\n• Servicios de análisis\n\nEstos servicios tienen sus propias políticas de privacidad que te recomendamos revisar.',
            ),
            _SectionWidget(
              title: '8. Cambios a esta Política',
              content:
                  'Podemos actualizar esta política de privacidad ocasionalmente. Te notificaremos sobre cambios significativos publicando la nueva política en la aplicación y actualizando la fecha de "última actualización". Te recomendamos revisar esta política periódicamente.',
            ),
            _SectionWidget(
              title: '9. Contacto',
              content:
                  'Si tienes preguntas sobre esta política de privacidad o sobre cómo manejamos tu información personal, puedes contactarnos a través de:\n\n• Email: privacy@peliculasapp.com\n• Dentro de la aplicación: Configuración > Soporte\n\nNos comprometemos a responder a tus consultas de manera oportuna y transparente.',
            ),
            SizedBox(height: 32),
            Center(
              child: Text(
                'Gracias por confiar en nosotros con tu información.',
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionWidget extends StatelessWidget {
  const _SectionWidget({
    required this.title,
    required this.content,
  });
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
