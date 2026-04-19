import SwiftUI
import GoogleSignInSwift

struct AuthView: View {
    @ObservedObject var auth: AuthManager
    @Environment(\.colorScheme) var colorScheme

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false

    var bgColor: Color {
        colorScheme == .dark
            ? Color(red: 0.06, green: 0.06, blue: 0.09)
            : Color(red: 0.96, green: 0.96, blue: 0.98)
    }

    var textPrimary: Color { colorScheme == .dark ? .white : .black }
    var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.45) }
    var cardBg: Color { colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03) }
    var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08) }
    var fieldBg: Color { colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04) }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 60)

                    // Logo
                    VStack(spacing: 12) {
                        Image(systemName: "shoeprints.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.cyan)

                        Text("PEDISENSE")
                            .font(.system(size: 24, weight: .heavy, design: .monospaced))
                            .tracking(6)
                            .foregroundColor(textPrimary)

                        Text("Smart Plantar Pressure Analysis")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(textSecondary)
                    }

                    Spacer().frame(height: 20)

                    // Auth form
                    VStack(spacing: 16) {
                        Text(isSignUp ? "Create Account" : "Welcome Back")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(textPrimary)

                        // Google Sign In
                        Button(action: {
                            auth.signInWithGoogle()
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "g.circle.fill")
                                    .font(.system(size: 20))
                                Text("Continue with Google")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.1)
                                    : Color.white
                            )
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(cardBorder, lineWidth: 1)
                            )
                        }
                        .foregroundColor(textPrimary)
                        .disabled(auth.isLoading)

                        // Divider
                        HStack {
                            Rectangle()
                                .fill(cardBorder)
                                .frame(height: 1)
                            Text("or")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(textSecondary)
                            Rectangle()
                                .fill(cardBorder)
                                .frame(height: 1)
                        }

                        // Email fields
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(textSecondary)
                                    .frame(width: 20)
                                TextField("Email", text: $email)
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .foregroundColor(textPrimary)
                            }
                            .padding(14)
                            .background(fieldBg)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(cardBorder, lineWidth: 1)
                            )

                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(textSecondary)
                                    .frame(width: 20)
                                SecureField("Password", text: $password)
                                    .textContentType(isSignUp ? .newPassword : .password)
                                    .foregroundColor(textPrimary)
                            }
                            .padding(14)
                            .background(fieldBg)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(cardBorder, lineWidth: 1)
                            )
                        }

                        if let error = auth.error {
                            Text(error)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }

                        // Email sign in/up button
                        Button(action: {
                            if isSignUp {
                                auth.signUp(email: email, password: password)
                            } else {
                                auth.signIn(email: email, password: password)
                            }
                        }) {
                            HStack {
                                if auth.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(isSignUp ? "SIGN UP" : "SIGN IN")
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.cyan)
                            .cornerRadius(12)
                        }
                        .foregroundColor(.white)
                        .disabled(email.isEmpty || password.isEmpty || auth.isLoading)
                        .opacity(email.isEmpty || password.isEmpty ? 0.5 : 1)

                        Button(action: { isSignUp.toggle() }) {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(.cyan)
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(cardBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(cardBorder, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 40)
                }
            }
        }
    }
}
