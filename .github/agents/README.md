# Agentes Especializados - peliculas-admob

Este directorio contiene las instrucciones especializadas para diferentes agentes de desarrollo que asisten en el proyecto peliculas-admob.

## 📚 Índice de Agentes

### Agentes Principales

| Agente              | Archivo                 | Responsabilidad                                     |
| ------------------- | ----------------------- | --------------------------------------------------- |
| 🏛️ **Architecture** | `architecture-agent.md` | Diseño de sistema, patrones DDD, Clean Architecture |
| ✅ **Testing**      | `testing-agent.md`      | Estrategia de testing, QA, cobertura                |
| 🔌 **Backend**      | `backend-agent.md`      | Supabase, sincronización, persistencia              |
| 🎨 **UI/UX**        | `ui-agent.md`           | Widgets Flutter, diseño, accesibilidad              |
| ⚡ **Performance**  | `performance-agent.md`  | Optimización, profiling, bundle size                |
| 🔐 **Security**     | `security-agent.md`     | Seguridad, vulnerabilidades, API keys               |
| 🚀 **DevOps**       | `devops-agent.md`       | CI/CD, deployment, automatización                   |

### Agentes de Dominio

| Agente              | Archivo                                      | Dominio                       |
| ------------------- | -------------------------------------------- | ----------------------------- |
| 🎬 **Movies**       | `domain-agents/movies-domain-agent.md`       | Películas, búsqueda, metadata |
| 🔑 **Auth**         | `domain-agents/auth-domain-agent.md`         | Autenticación, sesiones       |
| 📋 **Watchlist**    | `domain-agents/watchlist-domain-agent.md`    | Listas de favoritos, sync     |
| 🎮 **Gamification** | `domain-agents/gamification-domain-agent.md` | Puntos, logros, niveles       |
| 📴 **Offline**      | `domain-agents/offline-domain-agent.md`      | Funcionalidad offline, cache  |

## 🎯 Cómo Usar los Agentes

### Método 1: Invocación Directa

Menciona el agente en tu consulta:

```
@workspace /agent architecture-agent

Necesito diseñar una nueva feature para compartir listas de películas.
¿Cómo debería estructurar esto siguiendo DDD?
```

### Método 2: Contexto Automático

Los agentes se activan automáticamente cuando:

- Editas archivos relacionados con su dominio
- Mencionas palabras clave de su especialidad
- Solicitas ayuda en su área de expertise

### Método 3: Múltiples Agentes

Combina expertise de varios agentes:

```
@workspace /agent architecture-agent /agent backend-agent

Necesito implementar sincronización en tiempo real para listas compartidas.
```

## 🔄 Flujo de Trabajo Típico

1. **Planning** → Architecture Agent define estructura
2. **Implementation** → Domain Agent (específico) implementa lógica
3. **Testing** → Testing Agent crea tests completos
4. **UI** → UI Agent construye interfaz de usuario
5. **Security Review** → Security Agent valida vulnerabilidades
6. **Performance** → Performance Agent optimiza
7. **Deployment** → DevOps Agent automatiza CI/CD

## 📊 Matriz de Responsabilidades

| Tarea                   | Agente Principal | Agentes de Soporte       |
| ----------------------- | ---------------- | ------------------------ |
| Nueva feature completa  | Architecture     | Domain-specific, Testing |
| Bug fix                 | Testing          | Domain-specific          |
| Integración API         | Backend          | Security, Performance    |
| Componente UI nuevo     | UI               | Testing (golden tests)   |
| Problema de performance | Performance      | Architecture             |
| Vulnerabilidad          | Security         | Backend                  |
| Pipeline CI/CD          | DevOps           | Testing, Security        |
| Release                 | DevOps           | All agents               |
| Refactor código         | Architecture     | Testing, Domain-specific |

## 🛠️ Especialización por Tipo de Archivo

Los agentes se activan automáticamente según el archivo:

- **`lib/domain/`** → Architecture + Domain-specific
- **`lib/infrastructure/`** → Backend + Security
- **`lib/presentation/`** → UI + Performance
- **`test/`** → Testing
- **`.github/workflows/`** → DevOps
- **`pubspec.yaml`** → Security (dependencies)

## 📖 Convenciones de Agentes

Todos los agentes siguen estos estándares del proyecto:

### Logging

```dart
// ✅ CORRECTO: Usar LoggerFactory
import '../../core/logging/logger_factory.dart';
LoggerFactory.info('Mensaje');

// ❌ INCORRECTO: Nunca usar print()
print('Mensaje');
```

### Colores

```dart
// ✅ CORRECTO: Usar .withValues()
Color.red.withValues(alpha: 0.5)

// ❌ INCORRECTO: withOpacity está deprecado
Color.red.withOpacity(0.5)
```

### Testing

- Todos los cambios requieren tests
- Coverage target: 80%+
- Golden tests para UI crítica

### Build Timeouts

- Unit tests: 15+ minutos
- Integration tests: 25+ minutos
- Builds: 20+ minutos
- **NUNCA cancelar** operaciones en progreso

## 🔍 Debugging con Agentes

Si encuentras un problema, invoca agentes en este orden:

1. **Testing Agent** → Reproduce el error con tests
2. **Domain Agent** → Identifica lógica de negocio incorrecta
3. **Architecture Agent** → Revisa diseño y estructura
4. **Performance Agent** → Analiza si es problema de rendimiento
5. **Security Agent** → Verifica si es vulnerabilidad

## 📚 Referencias

- **Instrucciones Principales**: `.github/copilot-instructions.md`
- **Documentación**: `docs/`
- **Scripts**: `scripts/`
- **CI/CD**: `.github/workflows/`

## 🆘 Soporte

Si un agente no tiene suficiente información:

1. Revisa `.github/copilot-instructions.md` primero
2. Consulta documentación en `docs/`
3. Ejecuta `./scripts/quality_check.sh` para validación
4. Revisa logs de CI/CD en GitHub Actions

## 📝 Contribuir Nuevos Agentes

Para agregar un nuevo agente:

1. Crea archivo en `.github/agents/`
2. Sigue estructura de agentes existentes
3. Define expertise y responsabilidades claramente
4. Incluye ejemplos de código
5. Actualiza este README.md
6. Agrega al flujo de trabajo apropiado

---

**Última actualización**: Octubre 2025  
**Versión**: 1.0.0  
**Proyecto**: peliculas-admob
