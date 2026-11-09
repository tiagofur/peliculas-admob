package mx.creapolis.peliculas.android.features.auth

import androidx.compose.animation.AnimatedContent
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
import androidx.compose.material.icons.filled.LockReset
import androidx.compose.material.icons.filled.MarkEmailRead
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import mx.creapolis.peliculas.android.R
import mx.creapolis.peliculas.android.core.auth.SessionStore
import mx.creapolis.peliculas.android.core.network.ApiError

/**
 * "Olvidé mi contraseña": 1) el correo → el backend manda un código de 6 dígitos
 * (Resend); 2) código + contraseña nueva → sesión iniciada. Un código en vez de un
 * enlace funciona igual en Android e iOS sin páginas web ni App Links extra.
 */
@Composable
fun ForgotPasswordScreen(session: SessionStore, initialEmail: String, onDone: () -> Unit) {
  val state by session.state.collectAsState()
  val context = LocalContext.current
  val haptics = LocalHapticFeedback.current
  val scope = rememberCoroutineScope()
  var email by rememberSaveable { mutableStateOf(initialEmail) }
  var codeSent by rememberSaveable { mutableStateOf(false) }
  var code by rememberSaveable { mutableStateOf("") }
  var password by remember { mutableStateOf("") }
  var error by remember { mutableStateOf<String?>(null) }
  var info by remember { mutableStateOf<String?>(null) }

  LaunchedEffect(state.isSignedIn) { if (state.isSignedIn) onDone() }

  fun fail(e: Exception) {
    haptics.performHapticFeedback(HapticFeedbackType.Reject)
    // Un error no previsto aquí no es "no se pudo iniciar sesión": es que no salió el código.
    val res = if (e is ApiError) authErrorRes(e.code) else R.string.auth_error_generic
    error = context.getString(if (res == R.string.auth_error_generic) R.string.reset_error_generic else res)
  }

  fun sendCode() {
    error = null
    scope.launch {
      try {
        session.requestPasswordReset(email.trim())
        codeSent = true
        info = context.getString(R.string.reset_code_sent, email.trim())
      } catch (e: kotlinx.coroutines.CancellationException) {
        throw e
      } catch (e: Exception) {
        fail(e)
      }
    }
  }

  fun reset() {
    error = null
    if (password.length < 8) {
      error = context.getString(R.string.auth_error_weak_password)
      return
    }
    scope.launch {
      try {
        session.resetPassword(email.trim(), code.trim(), password)
        haptics.performHapticFeedback(HapticFeedbackType.Confirm)
      } catch (e: kotlinx.coroutines.CancellationException) {
        throw e
      } catch (e: Exception) {
        fail(e)
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
    Icon(
      if (codeSent) Icons.Filled.MarkEmailRead else Icons.Filled.LockReset,
      contentDescription = null,
      tint = MaterialTheme.colorScheme.primary,
      modifier = Modifier.size(48.dp),
    )
    Text(
      stringResource(R.string.reset_title),
      style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.Bold),
      textAlign = TextAlign.Center,
    )

    AnimatedContent(targetState = codeSent, label = "reset-step") { step2 ->
      Column(verticalArrangement = Arrangement.spacedBy(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
          info?.takeIf { step2 } ?: stringResource(R.string.reset_subtitle),
          style = MaterialTheme.typography.bodyMedium,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
          textAlign = TextAlign.Center,
        )
        if (!step2) {
          OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text(stringResource(R.string.field_email)) },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Send, autoCorrectEnabled = false),
            keyboardActions = KeyboardActions(onSend = { if (email.isNotBlank()) sendCode() }),
            shape = RoundedCornerShape(14.dp),
            modifier = Modifier.fillMaxWidth().semantics { contentType = ContentType.EmailAddress },
          )
        } else {
          OutlinedTextField(
            value = code,
            onValueChange = { v -> code = v.filter(Char::isDigit).take(6) },
            label = { Text(stringResource(R.string.reset_code_label)) },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword, imeAction = ImeAction.Next),
            shape = RoundedCornerShape(14.dp),
            modifier = Modifier.fillMaxWidth().semantics { contentType = ContentType.SmsOtpCode },
          )
          OutlinedTextField(
            value = password,
            onValueChange = { password = it },
            label = { Text(stringResource(R.string.field_password_new)) },
            singleLine = true,
            visualTransformation = PasswordVisualTransformation(),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { if (code.length == 6) reset() }),
            shape = RoundedCornerShape(14.dp),
            modifier = Modifier.fillMaxWidth().semantics { contentType = ContentType.NewPassword },
          )
        }
      }
    }

    error?.let {
      Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Filled.Warning, contentDescription = null, tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
      }
    }

    Button(
      onClick = { if (codeSent) reset() else sendCode() },
      enabled = !state.busy && if (codeSent) code.length == 6 && password.isNotEmpty() else email.isNotBlank(),
      shape = RoundedCornerShape(14.dp),
      modifier = Modifier.fillMaxWidth().height(52.dp),
    ) {
      if (state.busy) {
        CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp, color = MaterialTheme.colorScheme.onPrimary)
      } else {
        Text(stringResource(if (codeSent) R.string.reset_cta_save else R.string.reset_cta_send), fontWeight = FontWeight.Bold)
      }
    }
    if (codeSent) {
      // Reenviar: el backend ignora pedidos seguidos (1 por minuto), así que no hay spam.
      TextButton(onClick = ::sendCode, enabled = !state.busy) { Text(stringResource(R.string.reset_resend)) }
      TextButton(onClick = { codeSent = false; code = ""; error = null }) { Text(stringResource(R.string.reset_change_email)) }
    }
  }
}
