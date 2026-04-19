//
//  ProfileView.swift
//  Pedisense
//
//  Created by Harry Pall on 2026-04-19.
//

import SwiftUI
import Combine

struct ProfileView: View {
    @ObservedObject var auth: AuthManager
    @ObservedObject var calibration: CalibrationService
    @Environment(\.colorScheme) var colorScheme

    var bgColor: Color {
        colorScheme == .dark
            ? Color(red: 0.06, green: 0.06, blue: 0.09)
            : Color(red: 0.96, green: 0.96, blue: 0.98)
    }

    var textPrimary: Color { colorScheme == .dark ? .white : .black }
    var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.45) }
    var cardBg: Color { colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03) }
    var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08) }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PEDISENSE")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .tracking(4)
                            .foregroundColor(textPrimary.opacity(0.9))
                        Text("Profile")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(textPrimary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // User info card
                VStack(spacing: 16) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Text(String(auth.userEmail.prefix(1)).uppercased())
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                    }

                    VStack(spacing: 4) {
                        Text(auth.userEmail)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(textPrimary)
                        Text("User ID: \(String(auth.userId.prefix(8)))...")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(textSecondary)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(cardBorder, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)

                // Status cards
                VStack(spacing: 10) {
                    statusRow(
                        icon: "tuningfork",
                        title: "Calibration",
                        value: calibration.isCalibrated ? "Active" : "Not calibrated",
                        color: calibration.isCalibrated ? .green : .orange
                    )

                    statusRow(
                        icon: "icloud.fill",
                        title: "Cloud Sync",
                        value: "Supabase Connected",
                        color: .green
                    )

                    statusRow(
                        icon: "brain",
                        title: "AI Agent",
                        value: "Gemini 2.5 Flash",
                        color: .purple
                    )
                }
                .padding(.horizontal, 20)

                Spacer()

                // Sign out
                Button(action: {
                    let a = auth
                    let c = calibration
                    a.signOut()
                    c.reset()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 14))
                        Text("SIGN OUT")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                }
                .foregroundColor(.red)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    func statusRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(textPrimary)

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(value)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(textSecondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(cardBorder, lineWidth: 1)
                )
        )
    }
}
