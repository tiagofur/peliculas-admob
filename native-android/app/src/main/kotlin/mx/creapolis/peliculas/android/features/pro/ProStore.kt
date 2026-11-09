package mx.creapolis.peliculas.android.features.pro

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.network.ApiClient
import mx.creapolis.peliculas.android.core.network.ApiError
import mx.creapolis.peliculas.android.core.network.AppConfig
import java.util.Date

/** Modelo de producto para el Paywall (port de `Product` en iOS). */
data class ProProduct(
  val id: String,
  val title: String,
  val description: String,
  val displayPrice: String,
  val isSubscription: Boolean,
  val productDetails: ProductDetails? = null,
)

/**
 * Pro con Google Play Billing 7 (port de `ProStore` en iOS con StoreKit 2).
 *
 * - El estado Pro sale de las compras que Play tiene en el dispositivo
 *   (`queryPurchasesAsync`); se cachea para arrancar sin red y se **revoca**
 *   cuando Play ya no devuelve ninguna compra activa (suscripción vencida o
 *   reembolsada), como `Transaction.currentEntitlements` en iOS.
 * - Cada compra se **reconoce** (acknowledge): si no, Google la reembolsa sola
 *   a los 3 días.
 * - Con sesión, cada compra se reclama en el backend (`POST /v1/play/transactions`)
 *   para que el servidor sepa quién es Pro.
 * - Solo en debug (emulador sin Play Store) las compras se simulan.
 */
class ProStore(
  private val context: Context? = null,
  private val scope: CoroutineScope = CoroutineScope(Dispatchers.IO),
  /** ¿Hay sesión? Lo cablea AppContainer (reclamar compras solo con cuenta). */
  var signedInCheck: () -> Boolean = { false },
) : PurchasesUpdatedListener {

  data class UiState(
    val isPro: Boolean = false,
    val activeProductId: String? = null,
    val expiresAt: Date? = null,
    val products: List<ProProduct> = emptyList(),
    val loadingProducts: Boolean = false,
    val purchasing: String? = null,
    val message: String? = null,
    val showingPaywall: Boolean = false,
    val paywallReason: String? = null,
  ) {
    /** Nombre del plan activo para Cuenta (como `planName` en iOS). */
    val planNameRes: Int
      get() = when (activeProductId) {
        AppConfig.Pro.LIFETIME -> R.string.pro_plan_lifetime
        AppConfig.Pro.YEARLY -> R.string.pro_plan_yearly
        AppConfig.Pro.MONTHLY -> R.string.pro_plan_monthly
        else -> R.string.pro_plan_generic
      }
  }

  @Serializable
  private data class ClaimBody(
    @SerialName("purchase_token") val purchaseToken: String,
    @SerialName("product_id") val productId: String,
    @SerialName("package_name") val packageName: String,
  )

  private val _state = MutableStateFlow(UiState())
  val state: StateFlow<UiState> = _state.asStateFlow()

  val isPro: Boolean get() = _state.value.isPro

  private val prefs = context?.getSharedPreferences("peliculas.pro.v1", Context.MODE_PRIVATE)
  private var billingClient: BillingClient? = null

  @Volatile
  private var billingConnected = false

  /** Compras activas vistas en el último `queryPurchases` (para reclamar al iniciar sesión). */
  @Volatile
  private var ownedPurchases: List<Purchase> = emptyList()

  init {
    loadCachedEntitlement()
    initBillingClient()
  }

  private fun str(res: Int, fallback: String): String = context?.getString(res) ?: fallback

  private fun loadCachedEntitlement() {
    val cachedPro = prefs?.getBoolean(KEY_IS_PRO, false) ?: false
    val cachedProduct = prefs?.getString(KEY_PRODUCT_ID, null)
    if (cachedPro) {
      _state.update { it.copy(isPro = true, activeProductId = cachedProduct) }
    }
  }

  private fun saveEntitlement(pro: Boolean, productId: String?) {
    prefs?.edit()
      ?.putBoolean(KEY_IS_PRO, pro)
      ?.putString(KEY_PRODUCT_ID, productId)
      ?.apply()
    _state.update { it.copy(isPro = pro, activeProductId = productId) }
  }

  private fun initBillingClient() {
    val ctx = context ?: return
    val client = BillingClient.newBuilder(ctx)
      .setListener(this)
      .enablePendingPurchases()
      .build()
    billingClient = client
    connect()
  }

  private fun connect(onReady: (() -> Unit)? = null) {
    val client = billingClient ?: return
    if (billingConnected) {
      onReady?.invoke()
      return
    }
    client.startConnection(object : BillingClientStateListener {
      override fun onBillingSetupFinished(billingResult: BillingResult) {
        if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
          billingConnected = true
          queryPurchases { onReady?.invoke() }
        } else {
          onReady?.invoke()
        }
      }

      override fun onBillingServiceDisconnected() {
        billingConnected = false
      }
    })
  }

  fun presentPaywall(reason: String? = null) {
    if (!AppConfig.Pro.SALES_ENABLED) return
    _state.update { it.copy(showingPaywall = true, paywallReason = reason) }
  }

  /** Límite de listas: paywall si Pro se vende; si no, un aviso que no menciona Pro. */
  fun presentListLimit(reason: String) {
    if (AppConfig.Pro.SALES_ENABLED) {
      presentPaywall(reason)
    } else {
      val fallback = "Llegaste al máximo de ${AppConfig.Pro.FREE_LIST_LIMIT} listas. Borra una para crear otra."
      val msg = context?.getString(R.string.list_limit_reached, AppConfig.Pro.FREE_LIST_LIMIT) ?: fallback
      _state.update { it.copy(message = msg) }
    }
  }

  fun dismissPaywall() {
    _state.update { it.copy(showingPaywall = false, paywallReason = null) }
  }

  fun clearMessage() {
    _state.update { it.copy(message = null) }
  }

  /** Al volver a primer plano: Play puede haber renovado, vencido o reembolsado algo. */
  fun refresh() {
    if (billingConnected) queryPurchases() else connect()
  }

  fun loadProducts() {
    if (_state.value.products.isNotEmpty()) return
    _state.update { it.copy(loadingProducts = true) }

    val client = billingClient
    if (client == null || !billingConnected) {
      if (AppConfig.SIMULATE_PURCHASES) {
        // Debug sin Play Store: precios orientativos para poder probar el flujo.
        _state.update { it.copy(loadingProducts = false, products = defaultProducts()) }
      } else {
        // Release: nunca precios inventados. El paywall ofrece reintentar (como iOS).
        _state.update { it.copy(loadingProducts = false) }
        connect()
      }
      return
    }

    val productList = listOf(
      QueryProductDetailsParams.Product.newBuilder()
        .setProductId(AppConfig.Pro.YEARLY)
        .setProductType(BillingClient.ProductType.SUBS)
        .build(),
      QueryProductDetailsParams.Product.newBuilder()
        .setProductId(AppConfig.Pro.MONTHLY)
        .setProductType(BillingClient.ProductType.SUBS)
        .build(),
      QueryProductDetailsParams.Product.newBuilder()
        .setProductId(AppConfig.Pro.LIFETIME)
        .setProductType(BillingClient.ProductType.INAPP)
        .build(),
    )

    val params = QueryProductDetailsParams.newBuilder().setProductList(productList).build()

    client.queryProductDetailsAsync(params) { billingResult, details ->
      if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
        val detailsMap = details.associateBy { it.productId }
        val mapped = AppConfig.Pro.ALL.mapNotNull { id ->
          val d = detailsMap[id] ?: return@mapNotNull null
          val isSub = d.productType == BillingClient.ProductType.SUBS
          val price = if (isSub) {
            // La última fase es el precio recurrente (la primera puede ser la prueba gratis).
            d.subscriptionOfferDetails?.firstOrNull()?.pricingPhases?.pricingPhaseList?.lastOrNull()?.formattedPrice
          } else {
            d.oneTimePurchaseOfferDetails?.formattedPrice
          } ?: return@mapNotNull null
          ProProduct(
            id = id,
            title = d.name,
            description = d.description,
            displayPrice = price,
            isSubscription = isSub,
            productDetails = d,
          )
        }
        _state.update {
          it.copy(
            loadingProducts = false,
            products = mapped.ifEmpty { if (AppConfig.SIMULATE_PURCHASES) defaultProducts() else emptyList() },
          )
        }
      } else {
        _state.update {
          it.copy(
            loadingProducts = false,
            products = if (AppConfig.SIMULATE_PURCHASES) defaultProducts() else emptyList(),
            message = if (AppConfig.SIMULATE_PURCHASES) null else str(R.string.pro_plans_unavailable, "No se pudieron cargar los planes. Revisa tu conexión."),
          )
        }
      }
    }
  }

  private fun defaultProducts(): List<ProProduct> = listOf(
    ProProduct(
      id = AppConfig.Pro.YEARLY,
      title = "Pro Anual",
      description = "Facturado anualmente. Ahorra 40%",
      displayPrice = "$11.99",
      isSubscription = true,
    ),
    ProProduct(
      id = AppConfig.Pro.MONTHLY,
      title = "Pro Mensual",
      description = "Facturado cada mes",
      displayPrice = "$1.99",
      isSubscription = true,
    ),
    ProProduct(
      id = AppConfig.Pro.LIFETIME,
      title = "Pro de por vida",
      description = "Un solo pago, tuyo para siempre",
      displayPrice = "$29.99",
      isSubscription = false,
    ),
  )

  fun purchase(product: ProProduct, activity: Activity?) {
    val details = product.productDetails
    val client = billingClient

    if (details == null || activity == null || client == null || !billingConnected) {
      if (AppConfig.SIMULATE_PURCHASES) {
        _state.update { it.copy(purchasing = product.id) }
        scope.launch {
          kotlinx.coroutines.delay(600)
          saveEntitlement(true, product.id)
          _state.update { it.copy(purchasing = null, showingPaywall = false) }
        }
      } else {
        _state.update { it.copy(message = str(R.string.pro_purchase_failed, "No se pudo completar la compra.")) }
      }
      return
    }

    _state.update { it.copy(purchasing = product.id) }
    val productParams = BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(details)
    if (product.isSubscription) {
      val offerToken = details.subscriptionOfferDetails?.firstOrNull()?.offerToken
      if (offerToken == null) {
        _state.update { it.copy(purchasing = null, message = str(R.string.pro_purchase_failed, "No se pudo completar la compra.")) }
        return
      }
      productParams.setOfferToken(offerToken)
    }
    val flow = BillingFlowParams.newBuilder()
      .setProductDetailsParamsList(listOf(productParams.build()))
    // Igual que `appAccountToken` en iOS: liga la compra a la cuenta del backend.
    accountId?.let { flow.setObfuscatedAccountId(it) }
    val result = client.launchBillingFlow(activity, flow.build())
    if (result.responseCode != BillingClient.BillingResponseCode.OK) {
      _state.update { it.copy(purchasing = null) }
    }
  }

  /** Id de usuario del backend (lo cablea AppContainer). */
  @Volatile
  var accountId: String? = null

  override fun onPurchasesUpdated(billingResult: BillingResult, purchases: List<Purchase>?) {
    _state.update { it.copy(purchasing = null) }
    when (billingResult.responseCode) {
      BillingClient.BillingResponseCode.OK -> purchases.orEmpty().forEach { handlePurchase(it, fromFlow = true) }
      BillingClient.BillingResponseCode.USER_CANCELED -> Unit
      BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> queryPurchases()
      else -> _state.update { it.copy(message = str(R.string.pro_purchase_failed, "No se pudo completar la compra.")) }
    }
  }

  private fun handlePurchase(purchase: Purchase, fromFlow: Boolean) {
    when (purchase.purchaseState) {
      Purchase.PurchaseState.PURCHASED -> {
        val productId = purchase.products.firstOrNull { it in AppConfig.Pro.ALL } ?: return
        saveEntitlement(true, productId)
        acknowledge(purchase)
        claim(purchase, productId)
        if (fromFlow) dismissPaywall()
      }
      Purchase.PurchaseState.PENDING -> if (fromFlow) {
        _state.update { it.copy(message = str(R.string.pro_purchase_pending, "Tu compra está pendiente de aprobación.")) }
      }
      else -> Unit
    }
  }

  /** Reconoce la compra (obligatorio en Play; si no, se reembolsa a los 3 días). */
  private fun acknowledge(purchase: Purchase) {
    if (purchase.isAcknowledged) return
    val client = billingClient ?: return
    val params = AcknowledgePurchaseParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build()
    client.acknowledgePurchase(params) { }
  }

  /**
   * Recalcula Pro con lo que Play tiene activo (suscripciones + de por vida).
   * Solo revoca si ambas consultas respondieron OK: sin Play no se quita nada.
   */
  private fun queryPurchases(onDone: (() -> Unit)? = null) {
    val client = billingClient
    if (client == null) {
      onDone?.invoke()
      return
    }
    client.queryPurchasesAsync(
      QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build(),
    ) { subResult, subs ->
      client.queryPurchasesAsync(
        QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build(),
      ) { inAppResult, inApps ->
        val ok = subResult.responseCode == BillingClient.BillingResponseCode.OK &&
          inAppResult.responseCode == BillingClient.BillingResponseCode.OK
        if (ok) {
          val active = (subs + inApps).filter {
            it.purchaseState == Purchase.PurchaseState.PURCHASED && it.products.any { p -> p in AppConfig.Pro.ALL }
          }
          ownedPurchases = active
          active.forEach(::acknowledge)
          // De por vida manda sobre una suscripción (como `planName` en iOS).
          val product = active.flatMap { it.products }.let { ids ->
            ids.firstOrNull { it == AppConfig.Pro.LIFETIME } ?: ids.firstOrNull { it in AppConfig.Pro.ALL }
          }
          saveEntitlement(product != null, product)
        }
        onDone?.invoke()
      }
    }
  }

  /** "Restaurar compras": vuelve a preguntar a Play y avisa del resultado. */
  fun restore() {
    _state.update { it.copy(loadingProducts = true) }
    val done = {
      claimAll()
      _state.update {
        it.copy(
          loadingProducts = false,
          message = if (it.isPro) {
            str(R.string.pro_restore_ok, "¡Listo! Tu Pro está activo.")
          } else {
            str(R.string.pro_restore_none, "No encontramos compras de Pro asociadas a tu cuenta de Google.")
          },
        )
      }
    }
    if (billingClient == null) done() else connect { queryPurchases { done() } }
  }

  /** Envía al backend todas las compras activas (al iniciar sesión, como iOS). */
  fun claimAll() {
    ownedPurchases.forEach { p -> p.products.firstOrNull { it in AppConfig.Pro.ALL }?.let { claim(p, it) } }
  }

  private fun claim(purchase: Purchase, productId: String) {
    if (!signedInCheck()) return
    val pkg = context?.packageName ?: return
    scope.launch {
      try {
        ApiClient.authed(
          "POST", "/v1/play/transactions",
          body = ApiClient.encodeToString(ClaimBody(purchase.purchaseToken, productId, pkg)),
        )
      } catch (e: ApiError) {
        if (e.code == "purchase_owned_by_other_account") {
          _state.update { it.copy(message = str(R.string.pro_owned_by_other, "Esta compra pertenece a otra cuenta.")) }
        }
        // Sin red o backend sin Play aún: la notificación RTDN lo completará.
      } catch (_: Exception) {
      }
    }
  }

  /** Gestionar la suscripción en Play Store (equivalente a `manageSubscriptionsSheet`). */
  fun manageSubscriptionIntent(): Intent? {
    val pkg = context?.packageName ?: return null
    val sku = _state.value.activeProductId?.takeIf { it != AppConfig.Pro.LIFETIME }
    val url = "https://play.google.com/store/account/subscriptions?package=$pkg" + (sku?.let { "&sku=$it" } ?: "")
    return Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
  }

  /** Método auxiliar para pruebas unitarias. */
  fun setProForTesting(pro: Boolean, productId: String? = null) {
    saveEntitlement(pro, productId)
  }

  companion object {
    private const val KEY_IS_PRO = "is_pro"
    private const val KEY_PRODUCT_ID = "product_id"
  }
}
