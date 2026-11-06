# Rewarded opcional — 24 h sin anuncios por ver un video

Objetivo: primera recompensa real con la infra rewarded existente (hoy cero usos en lib/): ver un anuncio opt-in otorga 24 h sin ads forzados, ofrecido en el paywall como alternativa gratis a Pro.
Branch: feat/rewarded-perks (base main). Estrategia: single-pr.
Runner: dart format + flutter analyze + flutter test. Mirror Engram: pending.

## Specs

- S1: recompensa "24 h sin anuncios" por rewarded opt-in (remove_ads_temporarily de la estrategia UX). Usuario eligió: "Rewarded primero (Recommended)".
- S2: el ad-break lo respetan manager + AdMob igual que Pro, pero sin marcar Pro (paywall no muestra "Pro", restore no lo recupera).
- S3: expira solo por tiempo (24 h), visible en paywall; offline funciona (timestamp local).
- S4: rewarded intacto para Pro (opt-in, S3 de Pro). Sin regresiones no-Pro.
- S5: calidad repo (format/analyze/test, Conventional Commits, PR template).

## Tasks

- R1 (S1,S3) Ad-break en prefs (grant/active/expiry + cache) + tests. Route: inline. Status: done. Commit: ver L3.
- R2 (S2) Gates manager + AdMob respetan ad-break + tests. Route: inline. Status: done. Commit: ver L3.
- R3 (S1,S3) Paywall: oferta ver-anuncio + l10n (3 keys x4) + tests. Route: inline. Status: done. Commit: ver L3.
- R4 (S4,S5) QA analyze/test + docs + push + PR. Route: inline. Status: pending. Commit: -.

## Log

- L1 (2026-11-06, usuario): "sigamos"
- L2: decisión de orden por pregunta al usuario: rewarded primero; afiliados después (requiere IDs de afiliado externos). Supuesto reversible: recompensa = 24 h sin anuncios (oferta canónica remove_ads_temporarily ya listada en la estrategia UX).
- L3: RED→GREEN (test compilaba en rojo por API inexistente; rompí prefs al insertar y lo reparé verificado). 9/9 verdes (4 ad-break + 5 paywall), analyze limpio. Rama rebasada a feat/pro-paywall (PR stacked contra esa rama): borré mi rama vacía recién creada de main, sin contenido afectado.
