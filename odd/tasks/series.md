# Series — soporte Películas + Series

Objetivo: agregar Series con paridad de Películas + episodios marcables y extras. Branch: `feat/series-support`. Estrategia: `ask-on-risk`. Runner: `flutter test`.
## Specs
- S1: "quiero ver la posibilidad de poner series tambien"
- S2: "que se pueda marcar los episodios vistos, etc..."
- S3: "que tenga basicamente las mismas fuciones de las peliculas y aparte alguna mas que sea interesante par series"
- S4: "otro tema es como separamos los filtros y las diferencias entre ellas en alguna posible pantalla"
- S5: "planeamos junto con un subagente de design con $implecable y demas subagentes"
- S6: "asi que toma los agentes invetiguen como hacer, quiero todo perfecto y hermoso"
- S7: "me gusta, hagamos tu recomendacion" — recomendación aprobada: Opción A tabs Películas|Series en Home, `FiltersView<T>` genérico, entidades nuevas sin reusar `typeId 0/1`.
## Tasks
- T1 [S1,S2,S3] Entidades Serie/Temporada/Episodio/WatchedEpisode/SeriesProgress + Hive — route: inline — status: pending
- T2 [S1,S3] Datasource TMDB /tv + SeriesRepository + mapper Trakt — route: inline — status: pending
- T3 [S3,S4] Providers series + SeriesFilter — route: inline — status: pending
- T4 [S1,S2,S4] UI SerieDetail + rutas /serie — route: inline — status: pending
- T5 [S4] Filtros parametrizados + búsqueda tv — route: inline — status: pending
- T6 [S2,S3,S6] Progreso, próximos episodios, validación — route: inline — status: pending
## Log
- L1: "planeamos junto con un subagente de design con $implecable y demas subagentes, quiero ver la posibilidad de poner series tambien, que se pueda marcar los episodios vistos, etc... que tenga basicamente las mismas fuciones de las peliculas y aparte alguna mas que sea interesante par series, otro tema es como separamos los filtros y las diferencias entre ellas en alguna posible pantalla, asi que toma los agentes invetiguen como hacer, quiero todo perfecto y hermoso."
- L2: "me gusta, hagamos tu recomendacion"
- L3: Investigación previa con 6 agentes: base películas en `lib/domain/entities/movie.dart:7-39`, `watched_movie.dart:7-15`, `moviedb_datasource.dart:11-32`, `app_router.dart:54-213`; sin rutas serie; `ShowTrakt` en `show_trakt.dart:3-30` sin entidad dominio. Recomendación A aprobada.
