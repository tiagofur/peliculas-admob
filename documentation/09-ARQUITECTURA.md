# 09-ARQUITECTURA├── services/ # Servicios de la aplicación

│ ├── ux_community/ # Phase 6: Advanced UX & Community Features
│ │ ├── theme/ # Advanced Theme System
│ │ ├── community/ # Community Features (Reviews, Social, Forums)
│ │ ├── gamification/ # Advanced Gamification System
│ │ ├── personalization/ # ML-based Personalization Engine
│ │ ├── ux_components/ # Advanced UX Components
│ │ ├── accessibility/ # WCAG 2.1 AA Accessibility System
│ │ └── phase6_manager.dart # Coordination Manager
│ └── other_services/ # Otros servicios de la aplicaciónmd

## Arquitectura de la Aplicación

La arquitectura de la aplicación "peliculas-admob" está diseñada para ser escalable, mantenible y eficiente, siguiendo principios de diseño de software modernos. A continuación, se describen los componentes clave y la estructura de la aplicación.

### Estructura del Proyecto

```
lib/
├── main.dart              # Punto de entrada de la aplicación
├── config/                # Configuración de la aplicación y temas
├── core/                  # Servicios y utilidades centrales
├── domain/                # Lógica de negocio e interfaces
├── infrastructure/        # Integraciones externas (Supabase, etc.)
├── models/                # Modelos de datos
├── presentation/          # Componentes de UI y proveedores
└── services/              # Servicios de la aplicación
```

### Capas de la Arquitectura

1. **Capa de Presentación**:

   - Utiliza **Riverpod** para la gestión del estado.
   - Contiene todos los widgets de la interfaz de usuario y la lógica de presentación.
   - Se encarga de la interacción del usuario y la visualización de datos.

2. **Capa de Dominio**:

   - Contiene la lógica de negocio pura y las interfaces.
   - Define las reglas de negocio y las operaciones que se pueden realizar sobre los datos.
   - Separa la lógica de negocio de la lógica de presentación.

3. **Capa de Infraestructura**:

   - Maneja las integraciones externas, como la conexión con Supabase y otras APIs.
   - Se encarga de la persistencia de datos y la comunicación con servicios externos.
   - Implementa patrones de repositorio para acceder a los datos de manera uniforme.

4. **Capa de Servicios**:
   - Proporciona servicios de aplicación que pueden ser utilizados por la capa de presentación y la capa de dominio.
   - Incluye servicios como autenticación, gestión de usuarios y sincronización de datos.
   - **Phase 6 Services**: Advanced UX & Community Features con 8 servicios integrados:
     - Advanced Theme System con temas dinámicos personalizables
     - Community Features (Reviews, Social Interactions, Forums)
     - Advanced Gamification con achievements y challenges
     - ML-based Personalization Engine
     - Advanced UX Components con haptic feedback y gesture recognition
     - Accessibility System con compliance WCAG 2.1 AA
     - Phase6Manager para coordinación centralizada

### Patrones de Diseño Utilizados

- **Patrón de Repositorio**: Facilita el acceso a los datos y la separación de la lógica de acceso a datos de la lógica de negocio.
- **Inyección de Dependencias**: Utiliza Riverpod para gestionar la inyección de dependencias, lo que mejora la testabilidad y la modularidad.
- **MVVM (Modelo-Vista-Modelo de Vista)**: Se aplica en la capa de presentación para separar la lógica de la interfaz de usuario de la lógica de negocio.

### Consideraciones de Escalabilidad

- La arquitectura está diseñada para permitir la adición de nuevas características y la integración de nuevos servicios sin afectar la funcionalidad existente.
- Se recomienda seguir el principio de **Single Responsibility** (Responsabilidad Única) para cada componente, lo que facilita el mantenimiento y la evolución de la aplicación.

### Conclusión

La arquitectura de "peliculas-admob" está orientada a proporcionar una base sólida para el desarrollo y la expansión futura de la aplicación. Se enfoca en la separación de preocupaciones, la reutilización de código y la facilidad de mantenimiento, lo que la convierte en una solución robusta para la gestión y navegación de películas.
