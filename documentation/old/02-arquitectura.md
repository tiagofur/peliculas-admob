# 2. Arquitectura y Estructura del Proyecto

Este documento describe la arquitectura de la aplicación y explica la organización de carpetas y responsabilidades de cada capa.

## 2.1 Visión General

La aplicación sigue un enfoque de **Domain-Driven Design (DDD)** y está dividida en varias capas:

- **Presentación** (`lib/presentation/`): Widgets, vistas, providers y controladores de UI.
- **Dominio** (`lib/domain/`): Entidades, casos de uso e interfaces.
- **Infraestructura** (`lib/infrastructure/`): Implementaciones de repositorios, clientes API, adaptadores externos.
- **Servicios** (`lib/services/`): Servicios genéricos y lógica de negocio compartida.
- **Configuración** (`lib/config/`): Router, temas, constantes y configuración global.

## 2.2 Estructura de Carpetas

```
lib/
├── main.dart              # Punto de entrada de la aplicación
├── config/                # Configuración de rutas, temas y constantes
├── core/                  # Servicios y utilidades comunes (logging, caching)
├── domain/                # Modelos de negocio, interfaces, casos de uso
├── infrastructure/        # Repositorios, adaptadores de API (Supabase, TMDB)
├── models/                # Data models (serialización json)
├── presentation/          # Widgets, vistas y providers (Riverpod)
├── services/              # Servicios específicos (ads, analytics, streaming)
└── widgets/               # Componentes UI reutilizables
```

## 2.3 Principios y Patrones

- **DDD**: Separación de responsabilidades y dependencia inversa.
- **Repository Pattern**: Interfaces en la capa de dominio y implementaciones en infraestructura.
- **Provider/Riverpod**: Gestión de estado escalable.
- **Offline-First**: Hive o Isar como caché local.
- **Clean Architecture**: Módulos desacoplados y testables.
