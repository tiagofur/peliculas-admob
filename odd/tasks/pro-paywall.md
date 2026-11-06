# Pro pago único — Películas Pro (quitar ads + funciones Pro)

Objetivo: compra lifetime que quita anuncios y desbloquea funciones Pro, Apple-fit.
Branch: feat/pro-paywall (base main b4a40e5). Estrategia: single-pr (si ≥400 líneas, chain).
Runner: dart format + flutter analyze + flutter test. Mirror Engram: pending (sin herramientas en sesión).

## Specs

- S1: pago único lifetime quita-ads (móvil AdMob + web AdSense). Usuario: "y si hago de solo 1 pago al final gano solo 1x".
- S2: funciones Pro (temas personalizados, listas, stats avanzados). Usuario: "que ideas de monetizacion podemos implementar?"
- S3: rewarded solo opt-in voluntario, también en Pro. Usuario: "no me gusta, que la app tenga propaganda".
- S4: restore purchases + entitlement persistente offline (cache + restore al login).
- S5: Apple-fit para App Store (non-consumable, Restore, sin pago externo). Usuario: "quiero ponerla en Apple Store pero creo que no les gusta las apps con propaganda tanpoco".
- S6: calidad repo (format/analyze/test verdes, Conventional Commits, PR template checklist).

## Tasks

- T1 (S1,S4,S5) PurchasesService abstracto + isPro en prefs + tests. Route: inline. Status: done. Commit: ver L4.
- T2 (S1) Gatear AdaptiveMonetizationManager (early-return Pro) + tests. Route: inline. Status: done. Commit: ver L5.
- T3 (S1) Gatear ControlledAdWidget/AdIntegrationHelper/widgets/AdAwareScreen + widget tests. Route: inline. Status: done. Commit: ver L5.
- T4 (S5) Cableado nativo StoreKit/Play (IDs, Sandbox) + docs. Route: inline. Status: done. Commit: ver L6.
- T5 (S1,S4) Paywall + restaurar + entry settings/perfil + tests. Route: inline. Status: done. Commit: ver L7.
- T6 (S2) Funciones Pro por adición (sin recortar gratis) + tests. Route: inline. Status: pending. Commit: -.
- T7 (S3,S6) QA e2e ads-on/ads-off/restore + analyze/test + docs. Route: inline. Status: pending. Commit: -.
- T8 Verificador independiente (agente revisor) + push + PR Fixes #N. Route: delegated verify. Status: pending.

## Log

- L1 (2026-11-06, usuario): "bueno amigo, me ayudaste bastante a mejorar y actualizar la app para que Google Play la acepte como actualizacion que por señal era necesaria... ahora lo que no me gusta, que la app tenga propaganda, pero no veo otra forma de ganar algo sin cobrar mensualidad... y si hago de solo 1 pago al final gano solo 1x... que ideas de monetizacion podemos implementar? otro tema es que quiero ponerla en Apple Store pero creo que no les gusta las apps con propaganda tanpoco."
- L2 (2026-11-06, usuario): "me encanta, armamos el Pro primero (Issue y plan), impmlementamos, agente revisor, PR y al terminar continuamos con las demas opciones"
- L3: workflow research confirma premiumUser/optedOutOfAds muertos (ningún gate los consulta), sin IAP (solo google_mobile_ads ^9.2.0), seams en UserMonetizationPreferencesService + AdaptiveMonetizationManager. Rama base main limpia (stash wip actor-profile-screen aplicado).
- L4: T1 commit 7fd2b65ed8510fd4701240c6df1075775be69a36 (prefs isPro/setProActive/guardas + purchases_service + 7 tests verdes en pro_entitlement_test.dart + format). Issue GitHub pendiente: timeout de red en gh issue create, reintento antes del PR.
- L5: T2 commit de627c2e479edd00ce889fbdd8094cb3e8de4720 (RED observado en contador Pro, gates manager+AdMob, 9/9 tests). T3 commit 4c9ddbdd6584a4ac5f4bd400de02ec3a738626e2 (pro_ad_gate + guards en 5 leaf + 5 WebSafe + adaptive + Controlled + helper isPro + 2 listados + AdAware/AdTrigger/ListAdInserter + 8 widget tests verdes + analyze limpio).
- L6: T4 docs-only honesto (sin cambios nativos requeridos hasta agregar plugin de billing): docs/guides/pro-store-setup.md con producto peliculas_pro_lifetime, pasos Play + App Store Connect, Sandbox y checklist anti-rechazo.
- L7: T5 commit pendiente: ProPaywallScreen (comprar/restaurar) + ruta /pro-paywall + card Pro en settings + 10 keys l10n x4 locales + 3 widget tests verdes + analyze limpio.
