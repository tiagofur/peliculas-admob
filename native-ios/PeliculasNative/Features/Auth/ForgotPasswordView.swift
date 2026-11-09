import SwiftUI

/// "Olvidé mi contraseña": 1) el correo → el backend manda un código de 6 dígitos
/// (Resend); 2) código + contraseña nueva → sesión iniciada (la hoja de login se
/// cierra sola al detectar la sesión). Un código en vez de un enlace evita
/// páginas web y universal links extra, y es igual en Android.
struct ForgotPasswordView: View {
  @EnvironmentObject private var session: SessionStore

  @State private var email: String
  @State private var code = ""
  @State private var password = ""
  @State private var codeSent = false
  @State private var error: String?
  @FocusState private var focus: Field?

  enum Field { case email, code, password }

  init(initialEmail: String) {
    _email = State(initialValue: initialEmail)
  }

  private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        VStack(spacing: 10) {
          Image(systemName: codeSent ? "envelope.open.fill" : "key.horizontal.fill")
            .font(.system(size: 44))
            .foregroundStyle(.tint)
            .contentTransition(.symbolEffect(.replace))
          Text("Restablecer contraseña")
            .font(.title.weight(.bold))
          Group {
            if codeSent {
              Text("Si \(trimmedEmail) tiene una cuenta con contraseña, te llegará un código en unos segundos. Revisa también el spam.")
            } else {
              Text("Escribe el correo de tu cuenta y te enviaremos un código de 6 dígitos.")
            }
          }
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
        }
        .padding(.top, 8)

        VStack(spacing: 12) {
          if codeSent {
            field {
              TextField("Código de 6 dígitos", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focus, equals: .code)
                .onChange(of: code) { _, v in code = String(v.filter(\.isNumber).prefix(6)) }
            }
            field {
              SecureField("Contraseña (mín. 8)", text: $password)
                .textContentType(.newPassword)
                .focused($focus, equals: .password)
                .onSubmit(primary)
            }
          } else {
            field {
              TextField("Correo", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .email)
                .onSubmit(primary)
            }
          }
        }

        if let error {
          Label(error, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Error: \(error)")
        }

        Button(action: primary) {
          Group {
            if session.busy {
              ProgressView()
            } else {
              Text(codeSent ? "Guardar y entrar" : "Enviar código")
            }
          }
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 6)
        }
        .glassProminentButtonStyle()
        .controlSize(.large)
        .disabled(session.busy || (codeSent ? code.count != 6 || password.isEmpty : trimmedEmail.isEmpty))

        if codeSent {
          // Reenviar: el backend ignora pedidos seguidos (1 por minuto), así que no hay spam.
          Button("Reenviar código") { send() }
            .font(.subheadline)
            .disabled(session.busy)
          Button("Usar otro correo") {
            withAnimation { codeSent = false; code = ""; error = nil }
          }
          .font(.subheadline)
        }
      }
      .padding(24)
      .animation(.default, value: codeSent)
    }
    .scrollDismissesKeyboardIfAvailable()
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { focus = trimmedEmail.isEmpty ? .email : nil }
  }

  private func field<C: View>(@ViewBuilder _ content: () -> C) -> some View {
    content()
      .padding(.horizontal, 16)
      .frame(height: 52)
      .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private func primary() {
    codeSent ? reset() : send()
  }

  private func send() {
    Task {
      await run {
        try await session.requestPasswordReset(email: trimmedEmail)
        withAnimation { codeSent = true }
        focus = .code
      }
    }
  }

  private func reset() {
    guard password.count >= 8 else {
      error = String(localized: "La contraseña necesita al menos 8 caracteres.")
      return
    }
    Task {
      await run {
        try await session.resetPassword(email: trimmedEmail, code: code, password: password)
        Haptics.success()
      }
    }
  }

  private func run(_ work: () async throws -> Void) async {
    error = nil
    do {
      try await work()
    } catch {
      Haptics.warning()
      self.error = (error as? LocalizedError)?.errorDescription ?? String(localized: "No se pudo iniciar sesión.")
    }
  }
}
