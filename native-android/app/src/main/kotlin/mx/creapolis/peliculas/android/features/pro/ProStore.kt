package mx.creapolis.peliculas.android.features.pro

import android.app.Activity
import android.content.Context
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
import kotlinx.coroutines.withContext
import mx.creapolis.peliculas.android.core.network.ApiClient
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
 * ProStore: gestiona las compras in-app y suscripciones con Google Play Billing 7
 * (port de `ProStore` en iOS StoreKit 2).
 *
 * - Funciona offline persistiendo el entitlement en SharedPreferences.
 * - Soporta fallback para emulador/tests sin Play Services.
 */
class ProStore(
  private val context: Context? = null,
  private val scope: CoroutineScope = CoroutineScope(Dispatchers.IO),
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
  )

  private val _state = MutableStateFlow(UiState())
  val state: StateFlow<UiState> = _state.asStateFlow()

  val isPro: Boolean get() = _state.value.isPro

  private val prefs = context?.getSharedPreferences("peliculas.pro.v1", Context.MODE_PRIVATE)
  private var billingClient: BillingClient? = null
  private var billingConnected = false

  init {
    loadCachedEntitlement()
    initBillingClient()
  }

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
    billingClient = BillingClient.newBuilder(ctx)
      .setListener(this)
      .enablePendingPurchases()
      .build()

    billingClient?.startConnection(object : BillingClientStateListener {
      override fun onBillingSetupFinished(billingResult: BillingResult) {
        if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
          billingConnected = true
          queryPurchases()
        }
      }

      override fun onBillingServiceDisconnected() {
        billingConnected = false
      }
    })
  }

  fun presentPaywall(reason: String? = null) {
    _state.update { it.copy(showingPaywall = true, paywallReason = reason) }
  }

  fun dismissPaywall() {
    _state.update { it.copy(showingPaywall = false, paywallReason = null) }
  }

  fun clearMessage() {
    _state.update { it.copy(message = null) }
  }

  fun loadProducts() {
    if (_state.value.products.isNotEmpty()) return
    _state.update { it.copy(loadingProducts = true) }

    val client = billingClient
    if (client == null || !billingConnected) {
      // Fallback predeterminado con precios orientativos (cuando no hay Play Store conectado)
      _state.update {
        it.copy(
          loadingProducts = false,
          products = defaultProducts(),
        )
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

    client.queryProductDetailsAsync(params) { billingResult, queryProductDetailsResult ->
      if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
        val detailsMap = queryProductDetailsResult.associateBy { it.productId }
        val mapped = AppConfig.Pro.ALL.mapNotNull { id ->
          val details = detailsMap[id] ?: return@mapNotNull null
          val isSub = details.productType == BillingClient.ProductType.SUBS
          val price = if (isSub) {
            details.subscriptionOfferDetails?.firstOrNull()?.pricingPhases?.pricingPhaseList?.firstOrNull()?.formattedPrice ?: "$1.99"
          } else {
            details.oneTimePurchaseOfferDetails?.formattedPrice ?: "$29.99"
          }
          ProProduct(
            id = id,
            title = details.name,
            description = details.description,
            displayPrice = price,
            isSubscription = isSub,
            productDetails = details,
          )
        }
        _state.update {
          it.copy(
            loadingProducts = false,
            products = mapped.ifEmpty { defaultProducts() },
          )
        }
      } else {
        _state.update {
          it.copy(
            loadingProducts = false,
            products = defaultProducts(),
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
    _state.update { it.copy(purchasing = product.id) }
    val details = product.productDetails

    if (details == null || activity == null || billingClient == null || !billingConnected) {
      // Simulación en entorno de desarrollo / tests sin Play Store
      scope.launch {
        kotlinx.coroutines.delay(600)
        saveEntitlement(true, product.id)
        _state.update { it.copy(purchasing = null, showingPaywall = false) }
      }
      return
    }

    val productDetailsParamsList = if (product.isSubscription) {
      val offerToken = details.subscriptionOfferDetails?.firstOrNull()?.offerToken ?: ""
      listOf(
        BillingFlowParams.ProductDetailsParams.newBuilder()
          .setProductDetails(details)
          .setOfferToken(offerToken)
          .build(),
      )
    } else {
      listOf(
        BillingFlowParams.ProductDetailsParams.newBuilder()
          .setProductDetails(details)
          .build(),
      )
    }

    val billingFlowParams = BillingFlowParams.newBuilder()
      .setProductDetailsParamsList(productDetailsParamsList)
      .build()

    billingClient?.launchBillingFlow(activity, billingFlowParams)
  }

  override fun onPurchasesUpdated(billingResult: BillingResult, purchases: List<Purchase>?) {
    _state.update { it.copy(purchasing = null) }
    if (billingResult.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
      for (purchase in purchases) {
        handlePurchase(purchase)
      }
    } else if (billingResult.responseCode == BillingClient.BillingResponseCode.USER_CANCELED) {
      // Cancelado por el usuario
    } else {
      _state.update { it.copy(message = "No se pudo completar la compra.") }
    }
  }

  private fun handlePurchase(purchase: Purchase) {
    if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED) {
      val productId = purchase.products.firstOrNull() ?: AppConfig.Pro.MONTHLY
      saveEntitlement(true, productId)
      dismissPaywall()

      // Claim al backend si hay sesión
      claimPurchase(purchase.purchaseToken, productId)
    }
  }

  private fun queryPurchases() {
    val client = billingClient ?: return
    client.queryPurchasesAsync(
      QueryPurchasesParams.newBuilder()
        .setProductType(BillingClient.ProductType.SUBS)
        .build(),
    ) { result, subPurchases ->
      if (result.responseCode == BillingClient.BillingResponseCode.OK) {
        val activeSub = subPurchases.firstOrNull { it.purchaseState == Purchase.PurchaseState.PURCHASED }
        if (activeSub != null) {
          val pid = activeSub.products.firstOrNull() ?: AppConfig.Pro.MONTHLY
          saveEntitlement(true, pid)
          return@queryPurchasesAsync
        }
      }

      // Chequear compras únicas (lifetime)
      client.queryPurchasesAsync(
        QueryPurchasesParams.newBuilder()
          .setProductType(BillingClient.ProductType.INAPP)
          .build(),
      ) { inAppResult, inAppPurchases ->
        if (inAppResult.responseCode == BillingClient.BillingResponseCode.OK) {
          val activeInApp = inAppPurchases.firstOrNull { it.purchaseState == Purchase.PurchaseState.PURCHASED }
          if (activeInApp != null) {
            val pid = activeInApp.products.firstOrNull() ?: AppConfig.Pro.LIFETIME
            saveEntitlement(true, pid)
          }
        }
      }
    }
  }

  fun restore() {
    _state.update { it.copy(loadingProducts = true) }
    val client = billingClient
    if (client == null || !billingConnected) {
      _state.update {
        it.copy(
          loadingProducts = false,
          message = if (it.isPro) "¡Listo! Tu Pro está activo." else "No encontramos compras de Pro asociadas a tu cuenta de Google.",
        )
      }
      return
    }

    queryPurchases()
    _state.update {
      it.copy(
        loadingProducts = false,
        message = if (it.isPro) "¡Listo! Tu Pro está activo." else "No encontramos compras de Pro asociadas a tu cuenta de Google.",
      )
    }
  }

  private fun claimPurchase(purchaseToken: String, productId: String) {
    scope.launch {
      runCatching {
        ApiClient.authed(
          "POST", "/v1/play/transactions",
          body = ApiClient.encodeToString(
            mapOf("purchase_token" to purchaseToken, "product_id" to productId),
          ),
        )
      }
    }
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
