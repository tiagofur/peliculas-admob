package mx.creapolis.peliculas.android.features.pro

import android.app.Activity
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FormatListBulleted
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.Tv
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.network.AppConfig

/**
 * Paywall Pro: diseño Material 3 Expressive oscuro, con selección de planes,
 * características de suscripción, botón de compra y restauración (port de `PaywallView` en iOS).
 */
@Composable
fun PaywallScreen(
  proStore: ProStore,
  onDismiss: () -> Unit,
) {
  val state by proStore.state.collectAsState()
  var selectedPlanId by remember { mutableStateOf(AppConfig.Pro.YEARLY) }
  val context = LocalContext.current
  // Dentro de un Dialog el contexto es un wrapper: hay que llegar a la Activity
  // o Play Billing no puede abrir su hoja de compra.
  val activity = remember(context) { context.findActivity() }

  LaunchedEffect(Unit) {
    proStore.loadProducts()
  }

  Surface(
    modifier = Modifier.fillMaxSize(),
    color = Color(0xFF100C0A),
  ) {
    Box(
      modifier = Modifier
        .fillMaxSize()
        .background(
          Brush.verticalGradient(
            colors = listOf(
              Color(0xFFFF5722).copy(alpha = 0.25f),
              Color(0xFF673AB7).copy(alpha = 0.15f),
              Color(0xFF100C0A),
            ),
          ),
        ),
    ) {
      Column(
        modifier = Modifier
          .fillMaxSize()
          .verticalScroll(rememberScrollState())
          .padding(horizontal = 24.dp)
          .padding(top = 48.dp, bottom = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
      ) {
        // Encabezado
        Box(
          modifier = Modifier
            .size(72.dp)
            .clip(CircleShape)
            .background(
              Brush.linearGradient(
                colors = listOf(Color(0xFFFFC107), Color(0xFFFF5722), Color(0xFFE91E63)),
              ),
            ),
          contentAlignment = Alignment.Center,
        ) {
          Icon(
            imageVector = Icons.Filled.Tv,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(40.dp),
          )
        }

        Spacer(Modifier.height(16.dp))

        Text(
          text = stringResource(R.string.paywall_title),
          style = MaterialTheme.typography.headlineLarge,
          fontWeight = FontWeight.ExtraBold,
          color = Color.White,
        )

        Spacer(Modifier.height(8.dp))

        Text(
          text = state.paywallReason ?: stringResource(R.string.paywall_subtitle_default),
          style = MaterialTheme.typography.bodyMedium,
          color = Color.White.copy(alpha = 0.75f),
          textAlign = TextAlign.Center,
        )

        Spacer(Modifier.height(28.dp))

        // Ventajas Pro
        Column(
          modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(Color.White.copy(alpha = 0.07f))
            .padding(18.dp),
          verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
          // Solo se promete lo que funciona en Android (sin FCM aún: ver AppConfig).
          if (AppConfig.EPISODE_PUSH_AVAILABLE) {
            FeatureItem(
              icon = Icons.Filled.NotificationsActive,
              iconTint = Color(0xFFFF9800),
              title = stringResource(R.string.paywall_feature_episodes_title),
              subtitle = stringResource(R.string.paywall_feature_episodes_desc),
            )
          }
          FeatureItem(
            icon = Icons.Filled.FormatListBulleted,
            iconTint = Color(0xFF9C27B0),
            title = stringResource(R.string.paywall_feature_lists_title),
            subtitle = stringResource(R.string.paywall_feature_lists_desc, AppConfig.Pro.FREE_LIST_LIMIT),
          )
          FeatureItem(
            icon = Icons.Filled.Favorite,
            iconTint = Color(0xFFF44336),
            title = stringResource(R.string.paywall_feature_support_title),
            subtitle = stringResource(R.string.paywall_feature_support_desc),
          )
        }

        Spacer(Modifier.height(24.dp))

        // Planes disponibles
        if (state.loadingProducts) {
          Box(modifier = Modifier.fillMaxWidth().height(120.dp), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
          }
        } else if (state.products.isEmpty()) {
          // Sin Play Store o sin red: nada de precios inventados (como iOS).
          Column(
            Modifier.fillMaxWidth().height(120.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
          ) {
            Text(
              stringResource(R.string.pro_plans_not_available),
              style = MaterialTheme.typography.bodySmall,
              color = Color.White.copy(alpha = 0.7f),
              textAlign = TextAlign.Center,
            )
            TextButton(onClick = { proStore.loadProducts() }) {
              Text(stringResource(R.string.retry), color = Color.White, fontWeight = FontWeight.SemiBold)
            }
          }
        } else {
          Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            state.products.forEach { product ->
              val isSelected = product.id == selectedPlanId
              PlanCard(
                product = product,
                selected = isSelected,
                onClick = { selectedPlanId = product.id },
              )
            }
          }
        }

        Spacer(Modifier.height(24.dp))

        // Botón CTA
        val selectedProduct = state.products.firstOrNull { it.id == selectedPlanId }
        Button(
          onClick = {
            selectedProduct?.let { proStore.purchase(it, activity) }
          },
          enabled = selectedProduct != null && state.purchasing == null,
          modifier = Modifier
            .fillMaxWidth()
            .height(54.dp),
          shape = RoundedCornerShape(16.dp),
          colors = ButtonDefaults.buttonColors(
            containerColor = Color(0xFFFF5722),
            contentColor = Color.White,
          ),
        ) {
          if (state.purchasing != null) {
            CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp), strokeWidth = 2.dp)
          } else {
            val ctaText = if (selectedProduct?.isSubscription == false) {
              stringResource(R.string.paywall_cta_buy, selectedProduct.displayPrice)
            } else {
              stringResource(R.string.paywall_cta_subscribe)
            }
            Text(ctaText, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
          }
        }

        Spacer(Modifier.height(10.dp))

        Text(
          text = if (selectedProduct?.isSubscription == false) {
            stringResource(R.string.paywall_legal_lifetime)
          } else {
            stringResource(R.string.paywall_legal_subscription)
          },
          style = MaterialTheme.typography.labelSmall,
          color = Color.White.copy(alpha = 0.55f),
          textAlign = TextAlign.Center,
        )

        Spacer(Modifier.height(20.dp))

        // Restaurar compras + legal (términos y privacidad, como el footer de iOS)
        TextButton(
          onClick = { proStore.restore() },
        ) {
          Text(
            stringResource(R.string.paywall_restore),
            color = Color.White.copy(alpha = 0.85f),
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
          )
        }
        androidx.compose.foundation.layout.Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
          TextButton(onClick = { mx.creapolis.peliculas.android.features.auth.openUrl(context, AppConfig.TERMS_URL) }) {
            Text(stringResource(R.string.terms), color = Color.White.copy(alpha = 0.6f), style = MaterialTheme.typography.labelMedium)
          }
          TextButton(onClick = { mx.creapolis.peliculas.android.features.auth.openUrl(context, AppConfig.PRIVACY_URL) }) {
            Text(stringResource(R.string.privacy), color = Color.White.copy(alpha = 0.6f), style = MaterialTheme.typography.labelMedium)
          }
        }
      }

      // Botón Cerrar (X) arriba a la derecha
      IconButton(
        onClick = onDismiss,
        modifier = Modifier
          .align(Alignment.TopEnd)
          .padding(16.dp)
          .size(36.dp)
          .clip(CircleShape)
          .background(Color.White.copy(alpha = 0.15f)),
      ) {
        Icon(
          imageVector = Icons.Filled.Close,
          contentDescription = stringResource(R.string.close),
          tint = Color.White,
          modifier = Modifier.size(20.dp),
        )
      }
    }
  }
}

@Composable
private fun FeatureItem(
  icon: ImageVector,
  iconTint: Color,
  title: String,
  subtitle: String,
) {
  Row(
    verticalAlignment = Alignment.Top,
    modifier = Modifier.fillMaxWidth(),
  ) {
    Icon(
      imageVector = icon,
      contentDescription = null,
      tint = iconTint,
      modifier = Modifier
        .size(24.dp)
        .padding(top = 2.dp),
    )
    Spacer(Modifier.width(14.dp))
    Column {
      Text(title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, color = Color.White)
      Text(subtitle, style = MaterialTheme.typography.labelSmall, color = Color.White.copy(alpha = 0.65f))
    }
  }
}

@Composable
private fun PlanCard(
  product: ProProduct,
  selected: Boolean,
  onClick: () -> Unit,
) {
  val borderColor = if (selected) Color(0xFFFF5722) else Color.White.copy(alpha = 0.15f)
  val backgroundColor = if (selected) Color.White.copy(alpha = 0.12f) else Color.White.copy(alpha = 0.05f)

  Row(
    modifier = Modifier
      .fillMaxWidth()
      .clip(RoundedCornerShape(16.dp))
      .border(if (selected) 2.dp else 1.dp, borderColor, RoundedCornerShape(16.dp))
      .background(backgroundColor)
      .clickable(onClick = onClick)
      .padding(16.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Icon(
      imageVector = if (selected) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked,
      contentDescription = null,
      tint = if (selected) Color(0xFFFF5722) else Color.White.copy(alpha = 0.4f),
      modifier = Modifier.size(24.dp),
    )
    Spacer(Modifier.width(12.dp))
    Column(modifier = Modifier.weight(1f)) {
      Row(verticalAlignment = Alignment.CenterVertically) {
        Text(product.title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold, color = Color.White)
        if (product.id == AppConfig.Pro.YEARLY) {
          Spacer(Modifier.width(8.dp))
          Text(
            text = "Ahorra 40%",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = Color.Black,
            modifier = Modifier
              .clip(RoundedCornerShape(6.dp))
              .background(Color(0xFFFF9800))
              .padding(horizontal = 6.dp, vertical = 2.dp),
          )
        }
      }
      Text(product.description, style = MaterialTheme.typography.labelSmall, color = Color.White.copy(alpha = 0.65f))
    }
    Spacer(Modifier.width(8.dp))
    Text(
      text = product.displayPrice,
      style = MaterialTheme.typography.titleMedium,
      fontWeight = FontWeight.Bold,
      color = Color.White,
    )
  }
}

private fun android.content.Context.findActivity(): Activity? {
  var ctx: android.content.Context? = this
  while (ctx is android.content.ContextWrapper) {
    if (ctx is Activity) return ctx
    ctx = ctx.baseContext
  }
  return null
}
