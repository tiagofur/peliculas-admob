import AuthenticationServices
import SwiftUI

/// Iniciar sesión: Sign in with Apple primero (HIG), correo como alternativa.
struct SignInView: View {
  @EnvironmentObject private var session: SessionStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  @State private var mode: Mode = .signIn
  @State private var email = ""
  @State private var password = ""
  @State private var name = ""
  @State private var error: String?
  @FocusState private var focus: Field?

  enum Mode { case signIn, signUp }
  enum Field { case name, email, password }

  var body: some View {
    AppNavigation {
      ScrollView {
        VStack(spacing: 24) {
          header
          SignInWithAppleButton(.continue) { request in
            session.prepare(request)
          } onCompletion: { result in
            Task { await run { try await session.complete(result) } }
          }
          .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
          .frame(height: 52)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

          HStack {
            Rectangle().fill(Color(.separator)).frame(height: 0.5)
            Text("o con tu correo").font(.footnote).foregroundStyle(.secondary).fixedSize()
            Rectangle().fill(Color(.separator)).frame(height: 0.5)
          }

          VStack(spacing: 12) {
            if mode == .signUp {
              field { TextField("Tu nombre (opcional)", text: $name).textContentType(.name).focused($focus, equals: .name) }
            }
            field {
              TextField("Correo", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .email)
            }
            field {
              SecureField(passwordPlaceholder, text: $password)
                .textContentType(mode == .signUp ? .newPassword : .password)
                .focused($focus, equals: .password)
                .onSubmit(submit)
            }
          }

          if let error {
            Label(error, systemImage: "exclamationmark.triangle.fill")
              .font(.footnote)
              .foregroundStyle(.red)
              .frame(maxWidth: .infinity, alignment: .leading)
              .accessibilityLabel("Error: \(error)")
          }

          Button(action: submit) {
            Group {
              if session.busy { ProgressView() } else { Text(submitTitle) }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
          }
          .glassProminentButtonStyle()
          .controlSize(.large)
          .disabled(session.busy || email.isEmpty || password.isEmpty)

          Button(switchModeTitle) {
            withAnimation { mode = mode == .signIn ? .signUp : .signIn }
            error = nil
          }
          .font(.subheadline)

          legal
        }
        .padding(24)
      }
      .scrollDismissesKeyboardIfAvailable()
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
      }
    }
    .onChange(of: session.isSignedIn) { _, isSignedIn in if isSignedIn { dismiss() } }
  }

  private var header: some View {
    VStack(spacing: 10) {
      Image(systemName: "icloud.and.arrow.up.fill")
        .font(.system(size: 44))
        .foregroundStyle(.tint)
        .padding(.bottom, 4)
      Text(headerTitle)
        .font(.largeTitle.weight(.bold))
      Text("Tu biblioteca, tus series y tu progreso en todos tus dispositivos.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(.top, 8)
  }

  private var passwordPlaceholder: LocalizedStringKey { mode == .signUp ? "Contraseña (mín. 8)" : "Contraseña" }
  private var submitTitle: LocalizedStringKey { mode == .signIn ? "Iniciar sesión" : "Crear cuenta" }
  private var switchModeTitle: LocalizedStringKey { mode == .signIn ? "¿No tienes cuenta? Crear una" : "Ya tengo cuenta" }
  private var headerTitle: LocalizedStringKey { mode == .signIn ? "Inicia sesión" : "Crea tu cuenta" }

  private func field<C: View>(@ViewBuilder _ content: () -> C) -> some View {
    content()
      .padding(.horizontal, 16)
      .frame(height: 52)
      .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private var legal: some View {
    VStack(spacing: 4) {
      Text("Al continuar aceptas los Términos y la Política de privacidad.")
      HStack(spacing: 16) {
        if let t = AppConfig.termsURL { Link("Términos", destination: t) }
        if let p = AppConfig.privacyURL { Link("Privacidad", destination: p) }
      }
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .multilineTextAlignment(.center)
  }

  private func submit() {
    let mail = email.trimmingCharacters(in: .whitespacesAndNewlines)
    if mode == .signUp && password.count < 8 {
      error = String(localized: "La contraseña necesita al menos 8 caracteres.")
      return
    }
    Task {
      await run {
        if mode == .signIn {
          try await session.signIn(email: mail, password: password)
        } else {
          try await session.signUp(email: mail, password: password, name: name)
        }
      }
    }
  }

  private func run(_ work: () async throws -> Void) async {
    error = nil
    do {
      try await work()
      Haptics.success()
    } catch {
      Haptics.warning()
      self.error = (error as? LocalizedError)?.errorDescription ?? String(localized: "No se pudo iniciar sesión.")
    }
  }
}

extension View {
  @ViewBuilder
  func scrollDismissesKeyboardIfAvailable() -> some View {
    if #available(iOS 16, *) {
      self.scrollDismissesKeyboard(.interactively)
    } else {
      self
    }
  }
}
