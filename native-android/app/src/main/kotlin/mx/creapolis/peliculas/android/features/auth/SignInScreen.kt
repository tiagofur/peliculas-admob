package mx.creapolis.peliculas.android.features.auth

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CloudSync
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentType
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import kotlinx.coroutines.launch
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.auth.SessionStore
import mx.creapolis.peliculas.android.core.network.ApiError
import mx.creapolis.peliculas.android.core.network.AppConfig
import java.security.SecureRandom

/**
 * Iniciar sesión (port de `SignInView`): Google primero — el equivalente en
 * Android de Sign in with Apple —, correo como alternativa.
 */
@Composable
fun SignInScreen(session: SessionStore, onDone: () -> Unit, onForgotPassword: (email: String) -> Unit = {}) {
  val state by session.state.collectAsState()
  val context = LocalContext.current
  val haptics = LocalHapticFeedback.current
  val scope = rememberCoroutineScope()
  var isSignUp by rememberSaveable { mutableStateOf(false) }
  var email by rememberSaveable { mutableStateOf("") }
  var password by remember { mutableStateOf("") }
  var name by rememberSaveable { mutableStateOf("") }
  var error by remember { mutableStateOf<String?>(null) }
  val weakPassword = stringResource(R.string.auth_error_weak_password)

  LaunchedEffect(state.isSignedIn) { if (state.isSignedIn) onDone() }

  suspend fun run(work: suspend () -> Unit) {
    error = null
    try {
      work()
      haptics.performHapticFeedback(HapticFeedbackType.Confirm)
    } catch (e: GetCredentialCancellationException) {
      // El usuario cerró la hoja de Google: nada que decir.
    } catch (e: androidx.credentials.exceptions.NoCredentialException) {
      // No hay cuenta de Google en el teléfono (o ninguna disponible para esta app).
      haptics.performHapticFeedback(HapticFeedbackType.Reject)
      error = context.getString(R.string.auth_error_google_no_account)
    } catch (e: androidx.credentials.exceptions.GetCredentialException) {
      // Suele ser configuración: cliente Android (paquete + SHA-1) no registrado en Google Cloud.
      android.util.Log.w("SignIn", "Google: ${e.type} ${e.message}")
      haptics.performHapticFeedback(HapticFeedbackType.Reject)
      error = context.getString(R.string.auth_error_google)
    } catch (e: ApiError) {
      haptics.performHapticFeedback(HapticFeedbackType.Reject)
      error = context.getString(authErrorRes(e.code))
    } catch (e: kotlinx.coroutines.CancellationException) {
      throw e
    } catch (_: Exception) {
      haptics.performHapticFeedback(HapticFeedbackType.Reject)
      error = context.getString(R.string.auth_error_generic)
    }
  }

  fun submit() {
    val mail = email.trim()
    if (isSignUp && password.length < 8) {
      error = weakPassword
      return
    }
    scope.launch {
      run {
        if (isSignUp) session.signUp(mail, password, name.trim()) else session.signIn(mail, password)
      }
    }
  }

  Column(
    Modifier
      .fillMaxSize()
      .imePadding()
      .verticalScroll(rememberScrollState())
      .padding(24.dp),
    verticalArrangement = Arrangement.spacedBy(16.dp),
    horizontalAlignment = Alignment.CenterHorizontally,
  ) {
    Icon(Icons.Filled.CloudSync, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(48.dp))
    Text(
      stringResource(if (isSignUp) R.string.signup_title else R.string.signin_title),
      style = MaterialTheme.typography.headlineLarge.copy(fontWeight = FontWeight.Bold),
    )
    Text(
      stringResource(R.string.signin_subtitle),
      style = MaterialTheme.typography.bodyMedium,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
      textAlign = TextAlign.Center,
    )

    if (AppConfig.GOOGLE_WEB_CLIENT_ID.isNotBlank()) {
      OutlinedButton(
        onClick = { scope.launch { run { signInWithGoogle(context, session) } } },
        enabled = !state.busy,
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier.fillMaxWidth().height(52.dp),
      ) {
        Text("G", fontWeight = FontWeight.Black, color = MaterialTheme.colorScheme.primary)
        Spacer(Modifier.width(10.dp))
        Text(stringResource(R.string.signin_google), fontWeight = FontWeight.SemiBold)
      }
      Row(verticalAlignment = Alignment.CenterVertically) {
        HorizontalDivider(Modifier.weight(1f))
        Text(
          stringResource(R.string.signin_or_email),
          style = MaterialTheme.typography.labelMedium,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
          modifier = Modifier.padding(horizontal = 10.dp),
        )
        HorizontalDivider(Modifier.weight(1f))
      }
    }

    AnimatedVisibility(isSignUp) {
      OutlinedTextField(
        value = name,
        onValueChange = { name = it },
        label = { Text(stringResource(R.string.field_name_optional)) },
        singleLine = true,
        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Next),
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier.fillMaxWidth().semantics { contentType = ContentType.PersonFullName },
      )
    }
    OutlinedTextField(
      value = email,
      onValueChange = { email = it },
      label = { Text(stringResource(R.string.field_email)) },
      singleLine = true,
      keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Next, autoCorrectEnabled = false),
      shape = RoundedCornerShape(14.dp),
      modifier = Modifier.fillMaxWidth().semantics { contentType = ContentType.EmailAddress + ContentType.Username },
    )
    OutlinedTextField(
      value = password,
      onValueChange = { password = it },
      label = { Text(stringResource(if (isSignUp) R.string.field_password_new else R.string.field_password)) },
      singleLine = true,
      visualTransformation = PasswordVisualTransformation(),
      keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
      keyboardActions = KeyboardActions(onDone = { if (email.isNotBlank() && password.isNotEmpty()) submit() }),
      shape = RoundedCornerShape(14.dp),
      modifier = Modifier
        .fillMaxWidth()
        .semantics { contentType = if (isSignUp) ContentType.NewPassword else ContentType.Password },
    )

    if (!isSignUp) {
      TextButton(
        onClick = { onForgotPassword(email.trim()) },
        modifier = Modifier.align(Alignment.End),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 4.dp),
      ) { Text(stringResource(R.string.forgot_password)) }
    }

    error?.let {
      Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Filled.Warning, contentDescription = null, tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
      }
    }

    Button(
      onClick = ::submit,
      enabled = !state.busy && email.isNotBlank() && password.isNotEmpty(),
      shape = RoundedCornerShape(14.dp),
      modifier = Modifier.fillMaxWidth().height(52.dp),
    ) {
      if (state.busy) {
        CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp, color = MaterialTheme.colorScheme.onPrimary)
      } else {
        Text(stringResource(if (isSignUp) R.string.signup_cta else R.string.signin_cta), fontWeight = FontWeight.Bold)
      }
    }
    TextButton(onClick = { isSignUp = !isSignUp; error = null }) {
      Text(stringResource(if (isSignUp) R.string.switch_to_signin else R.string.switch_to_signup))
    }

    // Legal (como en iOS): términos y privacidad enlazados.
    Text(
      stringResource(R.string.signin_legal),
      style = MaterialTheme.typography.labelSmall,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
      textAlign = TextAlign.Center,
    )
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
      TextButton(onClick = { openUrl(context, AppConfig.TERMS_URL) }) { Text(stringResource(R.string.terms)) }
      TextButton(onClick = { openUrl(context, AppConfig.PRIVACY_URL) }) { Text(stringResource(R.string.privacy)) }
    }
  }
}

/** Credential Manager → ID token de Google → backend (`/v1/auth/google`). */
private suspend fun signInWithGoogle(context: Context, session: SessionStore) {
  val nonce = ByteArray(24).also { SecureRandom().nextBytes(it) }.joinToString("") { "%02x".format(it) }
  val option = GetSignInWithGoogleOption.Builder(AppConfig.GOOGLE_WEB_CLIENT_ID).setNonce(nonce).build()
  val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
  val result = CredentialManager.create(context).getCredential(context, request)
  val credential = result.credential
  if (credential !is CustomCredential || credential.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
    throw ApiError(0, "google_no_token")
  }
  val google = GoogleIdTokenCredential.createFrom(credential.data)
  session.signInWithGoogle(google.idToken, nonce, google.displayName)
}

/** Mensaje por código del backend (port de `errorDescription` de `APIError`). */
fun authErrorRes(code: String): Int = when (code) {
  "invalid_email" -> R.string.auth_error_invalid_email
  "weak_password" -> R.string.auth_error_weak_password
  "email_taken" -> R.string.auth_error_email_taken
  "invalid_credentials" -> R.string.auth_error_invalid_credentials
  "rate_limited" -> R.string.auth_error_rate_limited
  "offline" -> R.string.auth_error_offline
  "invalid_reset_code" -> R.string.auth_error_reset_code
  "mail_not_configured" -> R.string.auth_error_mail_unavailable
  "google_no_token" -> R.string.auth_error_google
  else -> R.string.auth_error_generic
}

fun openUrl(context: Context, url: String) {
  runCatching {
    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
  }
}
