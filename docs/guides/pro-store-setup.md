# Películas Pro: alta en tiendas (compra lifetime)

> Estado: el código ya soporta el entitlement (`LocalPurchasesService`,
> `isPro`, gates, paywall). Este doc cubre lo único que requiere acción
> humana en consolas: crear el producto `peliculas_pro_lifetime` y probar
> la compra real. Sin este paso, la app compila y funciona con el
> entitlement local (ideal para desarrollo y review de código).

## 1. Crear el producto (mismo ID en ambas tiendas)

- ID: `peliculas_pro_lifetime`
- Tipo: **non-consumable** (pago único, de por vida).
- Precio: lo defines tú por tier (sugerencia: anclar lifetime caro frente
  a un anual barato si más adelante agregas suscripción).
- Family Sharing (Apple): decide sí/no antes de enviar a review; no se puede
  cambiar después sin nuevo producto.

## 2. Google Play Console

1. Monetizar > Productos > Compras únicas > Crear (`peliculas_pro_lifetime`).
2. Activar el producto y agregar una cuenta de prueba de licencias
   (Configuración > Cuentas de prueba).
3. Probar con un APK firmado subido a testing interno: comprar, cerrar
   sesión, reinstalar y usar **Restaurar** del paywall.
4. El plugin de billing (`in_app_purchase` o RevenueCat) se conecta
   implementando `PurchasesService` (ver §5); el `BILLING` permission lo
   agrega solo la librería, no toques el manifest.

## 3. App Store Connect

1. Mi app > Compras dentro de la app > Non-Consumable >
   `peliculas_pro_lifetime`, con captura y texto de review.
2. Crear usuario Sandbox (Usuarios y acceso > Sandbox) y probar en
   dispositivo/Simulador: comprar, restaurar, modo avión (entitlement
   cacheado debe seguir activo).
3. En la ficha de review: deja nota con cuenta demo Sandbox y explica que
   el botón **Restaurar compras** es obligatorio y está en el paywall.
4. No pongas botones ni links a pago externo, ni menciones precios fuera
   del IAP: es motivo directo de rechazo.

## 4. Checklist anti-rechazo Apple

- [ ] Restore Purchases visible y funcional.
- [ ] Cero links/botones a pagos fuera del IAP.
- [ ] Sin mención de precios fuera del diálogo del sistema.
- [ ] Probado en Sandbox + TestFlight.
- [ ] Nota de review con cuenta demo.
- [ ] Privacidad: la compra no agrega tracking (ATT sin cambios).

## 5. Dónde se conecta el billing real en el código

- `lib/services/monetization/purchases_service.dart`: contrato
  `PurchasesService` + `LocalPurchasesService` (offline-first actual).
- Un `StorePurchasesService` futuro implementa `purchasePro()` /
  `restorePurchases()` contra el plugin y delega la persistencia en
  `UserMonetizationPreferencesService.setProActive()`; los gates
  (`AdaptiveMonetizationManager`, widgets, listas) no cambian.
- No se necesita nada en `Info.plist` ni en el manifest para IAP más
  allá de lo que agregue el plugin.
