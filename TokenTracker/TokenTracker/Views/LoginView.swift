import SwiftUI

private let bg = Color(red: 0.09, green: 0.07, blue: 0.14)

struct LoginView: View {
    let onLoginSuccess: () -> Void
    var isSheet: Bool = false
    @State private var sessionToken = ""
    @State private var step: Step = .intro
    @State private var isValidating = false
    @State private var error: String? = nil
    @State private var orgIdInput = ""
    @State private var showToken = false

    enum Step { case intro, paste, orgId }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 0) {
                if !isSheet {
                    HStack(spacing: 10) {
                        Image("ClaudeLogo")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundStyle(.white.opacity(0.85))
                        Text("TokenTracker")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 28)
                    .padding(.bottom, 24)

                    Rectangle().fill(.white.opacity(0.06)).frame(height: 0.5).padding(.horizontal, 24)
                }

                switch step {
                case .intro:  introContent
                case .paste:  pasteContent
                case .orgId:  orgIdContent
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, isSheet ? 16 : 0)
            .padding(.bottom, 28)
        }
        .frame(width: 340)
        .environment(\.colorScheme, .dark)
        .onAppear { if isSheet { step = .paste } }
    }

    // MARK: - Intro

    private var introContent: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(.white.opacity(0.05))
                    .overlay(Circle().strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
                    .frame(width: 72, height: 72)
                Image("ClaudeLogo")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.bottom, 20)

            // Headline
            Text(L10n.connectClaude)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.bottom, 8)

            Text(L10n.loginDescription)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 4)
                .padding(.bottom, 28)

            // Primary button
            Button {
                NSWorkspace.shared.open(URL(string: "https://claude.ai")!)
                step = .paste
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "safari")
                    Text(L10n.openClaudeAi)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.15), lineWidth: 0.5)))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 10)

            // Already have token
            Button { step = .paste } label: {
                Text(L10n.s("Уже есть токен", "I already have a token"))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .buttonStyle(.plain)

            Spacer()

            if !isSheet {
                Rectangle().fill(.white.opacity(0.06)).frame(height: 0.5)
                    .padding(.bottom, 12)

                HStack(spacing: 16) {
                    footerLink("FAQ", url: "https://github.com/avedevelop/TokenTracker/blob/main/FAQ.md")
                    Text("·").foregroundStyle(.white.opacity(0.15)).font(.system(size: 10))
                    footerLink(L10n.s("Условия", "Terms"), url: "https://github.com/avedevelop/TokenTracker/blob/main/TERMS.md")
                    Text("·").foregroundStyle(.white.opacity(0.15)).font(.system(size: 10))
                    footerLink("GitHub", url: "https://github.com/avedevelop/TokenTracker")
                }
                .padding(.bottom, 4)
            }
        }
        .padding(.top, 12)
    }

    private func footerLink(_ label: String, url: String) -> some View {
        Button {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        } label: {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.3))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Paste

    private var pasteContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer().frame(height: 2)

            Text(L10n.pasteSessionToken).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)

            // Instructions
            VStack(alignment: .leading, spacing: 7) {
                instructionStep(1, L10n.s("Нажмите **Cmd+Option+I** — откроется DevTools", "Press **Cmd+Option+I** to open DevTools"))
                instructionStep(2, L10n.s("Вкладка **Application** → **Cookies** → **claude.ai**", "Tab **Application** → **Cookies** → **claude.ai**"))
                instructionStep(3, L10n.s("Найдите **sessionKey** → скопируйте значение", "Find **sessionKey** → copy the value"))
            }
            .padding(11)
            .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.07), lineWidth: 0.5)))

            // Token field
            HStack(spacing: 8) {
                Group {
                    if showToken {
                        TextField("sk-ant-sid02-...", text: $sessionToken)
                    } else {
                        SecureField("sk-ant-sid02-...", text: $sessionToken)
                    }
                }
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white)
                .onChange(of: sessionToken) { _, _ in error = nil }

                Button {
                    showToken.toggle()
                } label: {
                    Image(systemName: showToken ? "eye.slash" : "eye")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
            .padding(11)
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(
                    error != nil ? Color.red.opacity(0.5) : .white.opacity(0.12), lineWidth: 0.5)))
            // Hidden Cmd+V handler — macOS SwiftUI TextField workaround
            .background(
                Button("") {
                    if let s = NSPasteboard.general.string(forType: .string) {
                        sessionToken = s.trimmingCharacters(in: .whitespacesAndNewlines)
                        error = nil
                    }
                }
                .keyboardShortcut("v", modifiers: .command)
                .opacity(0)
            )

            // Error message
            if let err = error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.8))
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.8))
                }
                .padding(.horizontal, 4)
                .transition(.opacity)
            }

            HStack(spacing: 10) {
                if !isSheet {
                    Button(L10n.back) { step = .intro; error = nil }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .buttonStyle(.plain)
                }
                Spacer()
                Button { validate() } label: {
                    HStack(spacing: 6) {
                        if isValidating {
                            ProgressView().controlSize(.mini).tint(.white)
                        }
                        Text(isValidating
                             ? L10n.s("Проверка…", "Checking…")
                             : L10n.connect)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tokenEmpty ? .white.opacity(0.3) : .white)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(tokenEmpty ? 0.05 : 0.12))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.15), lineWidth: 0.5)))
                }
                .buttonStyle(.plain)
                .disabled(tokenEmpty || isValidating)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: error)
    }

    // MARK: - Org ID (fallback)

    private var orgIdContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer().frame(height: 2)

            Text(L10n.s("Введите Org ID", "Enter Org ID"))
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)

            Text(L10n.s(
                "ID не удалось получить автоматически. Найдите его в cookies браузера на claude.ai.",
                "Could not get Org ID automatically. Find it in browser cookies on claude.ai."
            ))
            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4)).lineSpacing(3)

            // Instruction
            VStack(alignment: .leading, spacing: 7) {
                instructionStep(1, L10n.s("Откройте **claude.ai** → нажмите **Cmd+Option+I**", "Open **claude.ai** → press **Cmd+Option+I**"))
                instructionStep(2, L10n.s("Вкладка **Application** → **Cookies** → **claude.ai**", "Tab **Application** → **Cookies** → **claude.ai**"))
                instructionStep(3, L10n.s("Найдите **lastActiveOrg** → скопируйте значение", "Find **lastActiveOrg** → copy its value"))
            }
            .padding(11)
            .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.07), lineWidth: 0.5)))

            TextField("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", text: $orgIdInput)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white)
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.12), lineWidth: 0.5)))

            if let err = error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11)).foregroundStyle(.red.opacity(0.8))
                    Text(err).font(.system(size: 11)).foregroundStyle(.red.opacity(0.8))
                }
            }

            HStack(spacing: 10) {
                Button(L10n.back) { step = .paste; error = nil }
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.4)).buttonStyle(.plain)
                Spacer()
                Button { saveOrgId() } label: {
                    HStack(spacing: 6) {
                        if isValidating { ProgressView().controlSize(.mini).tint(.white) }
                        Text(isValidating ? L10n.s("Проверка…", "Checking…") : L10n.s("Сохранить", "Save"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(orgIdInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .white.opacity(0.3) : .white)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.15), lineWidth: 0.5)))
                }
                .buttonStyle(.plain)
                .disabled(orgIdInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: error)
    }

    private func saveOrgId() {
        let orgId = orgIdInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !orgId.isEmpty else { return }
        isValidating = true
        error = nil

        Task {
            guard let token = AccountStore.shared.activeToken() ?? KeychainStore.load() else {
                await MainActor.run { isValidating = false; step = .paste }
                return
            }
            do {
                let poller = LimitsPoller()
                let limits = token.hasPrefix("sk-ant-oat")
                    ? try await poller.fetchLimitsWithOAuthToken(token)
                    : try await poller.fetchLimits(sessionKey: token)
                // Save org ID only after successful validation
                UserDefaults.standard.set(orgId, forKey: "com.tokentracker.orgId")
                try? SharedStore.updateLimits(limits)
                await MainActor.run { isValidating = false; onLoginSuccess() }
            } catch {
                await MainActor.run {
                    isValidating = false
                    self.error = L10n.s("Неверный Org ID или токен", "Invalid Org ID or token")
                }
            }
        }
    }

    // MARK: - Validation

    private var tokenEmpty: Bool { sessionToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func validate() {
        let token = sessionToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        isValidating = true
        error = nil

        Task {
            do {
                let poller = LimitsPoller()
                // Clear cached orgId to force fresh lookup with new token
                UserDefaults.standard.removeObject(forKey: "com.tokentracker.orgId")
                let limits = token.hasPrefix("sk-ant-oat")
                    ? try await poller.fetchLimitsWithOAuthToken(token)
                    : try await poller.fetchLimits(sessionKey: token)

                // Success — save and proceed
                if isSheet {
                    await AccountStore.shared.addNewProfile(token: token)
                } else {
                    await AccountStore.shared.ensureProfile(token: token)
                }
                try? SharedStore.updateLimits(limits)
                await MainActor.run {
                    isValidating = false
                    onLoginSuccess()
                }
            } catch LimitsPoller.PollerError.unauthorized {
                await MainActor.run {
                    isValidating = false
                    error = L10n.s("Токен недействителен или истёк", "Token is invalid or expired")
                }
            } catch LimitsPoller.PollerError.missingOrgId {
                if isSheet {
                    await AccountStore.shared.addNewProfile(token: token)
                } else {
                    await AccountStore.shared.ensureProfile(token: token)
                }
                await MainActor.run {
                    isValidating = false
                    step = .orgId
                }
            } catch LimitsPoller.PollerError.unexpectedResponse {
                // Token valid but usage endpoint unavailable (e.g. free plan — no limits data)
                if isSheet {
                    await AccountStore.shared.addNewProfile(token: token)
                } else {
                    await AccountStore.shared.ensureProfile(token: token)
                }
                await MainActor.run {
                    isValidating = false
                    onLoginSuccess()
                }
            } catch {
                await MainActor.run {
                    isValidating = false
                    self.error = L10n.s("Ошибка сети. Проверьте интернет.", "Network error. Check your connection.")
                }
            }
        }
    }

    // MARK: - Helpers

    private func instructionStep(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 16, height: 16)
                .background(Circle().fill(.white.opacity(0.08)))
            Text(LocalizedStringKey(text))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
