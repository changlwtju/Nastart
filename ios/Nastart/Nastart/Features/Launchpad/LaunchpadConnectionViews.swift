import SwiftUI
import UIKit

/// A saved connection being restored is not a first-time NAS setup.
struct NASConnectionRecoveryView: View {
    let state: NASConnectionRecoveryState
    var compact = false
    var rejection: DSMClientError? = nil
    var cachedAt: Date? = nil
    let retry: () -> Void
    let settings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if state == .restoring {
                ProgressView("connect.restore.title")
                    .tint(AppTheme.accent)
            } else {
                Label(rejection == nil ? "connect.restore.failed" : "connect.restore.rejected",
                      systemImage: rejection == nil ? "wifi.exclamationmark" : "person.crop.circle.badge.exclamationmark")
                    .font(.headline)
            }
            Group {
                if let message = rejection?.errorDescription {
                    Text(message)
                } else {
                    Text(LocalizedStringKey(state == .restoring ? "connect.restore.detail" : "connect.restore.failed_detail"))
                }
            }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let cachedAt {
                Text(LaunchpadCachedTime.text(cachedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("nas.connection.cachedAt")
            }
            if state == .failed {
                HStack(spacing: 24) {
                    if rejection?.allowsRetryWithSameCredential ?? true {
                        Button("action.retry", action: retry)
                    }
                    Button("connect.restore.settings", action: settings)
                }
            }
        }
        .padding(compact ? 16 : 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { NastartThemeBackground() }
        .accessibilityIdentifier("nas.connection.recovery")
    }
}

enum LaunchpadCachedTime {
    static func text(_ date: Date) -> String {
        String(format: NSLocalizedString("data.refresh.cached_at", comment: ""),
               date.formatted(date: .abbreviated, time: .shortened))
    }
}

enum DSMCertificateTrustPolicy {
    /// A private HTTPS address is trusted automatically, and that trust is saved with the
    /// connection. It is not the user's choice, so it must not carry over to a public address
    /// typed into this form. A public address keeps its saved value, with a visible warning.
    static func initialToggle(savedTrust: Bool, savedAddress: String) -> Bool {
        guard savedTrust, let host = URL(string: savedAddress)?.host else { return false }
        return !NetworkHostClassifier.isPrivate(host)
    }
}

struct NASConnectionWelcomeView: View {
    let addNASAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "server.rack")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(AppTheme.primaryAction)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("connect.welcome.title")
                        .font(.title2.weight(.bold))
                    Text("connect.welcome.subtitle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: addNASAction) {
                    Label("connect.welcome.action", systemImage: "plus")
                }
                .buttonStyle(NastartPrimaryButtonStyle())

                Label("connect.welcome.security", systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 34)
        }
        .background { NastartThemeBackground() }
    }
}

struct ManualServiceEditorView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""
    @State private var category: ServiceCategory = .tools
    @State private var showsValidationError = false

    init(initialName: String = "", initialCategory: ServiceCategory = .tools) {
        _name = State(initialValue: initialName)
        _category = State(initialValue: initialCategory)
    }

    var body: some View {
        Form {
            Section {
                Text("manual.service.intro")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }.nastartListSection()

            Section {
                TextField("manual.service.name.placeholder", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                TextField("manual.service.url.placeholder", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                Picker("manual.service.category", selection: $category) {
                    ForEach(ServiceCategory.defaultOrder.filter { $0 != .favorites }) { category in
                        Label(LocalizedStringKey(category.titleKey), systemImage: category.symbolName)
                            .tag(category)
                    }
                }
            } footer: {
                Text("manual.service.footer")
            }.nastartListSection()
        }
        .nastartReadableWidth().nastartPageTheme()
        .navigationTitle("manual.service.add")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("action.cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("action.save") {
                    guard let endpoint = normalizedURL, !normalizedName.isEmpty else {
                        showsValidationError = true
                        return
                    }
                    dataStore.addManualService(
                        name: normalizedName,
                        endpoint: endpoint,
                        category: category,
                        iconText: ""
                    )
                    dismiss()
                }
            }
        }
        .alert("manual.service.invalid", isPresented: $showsValidationError) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedURL: URL? {
        UserConfiguredServiceURLPolicy.normalizedURL(from: address)
    }
}

private enum DSMConnectionProtocol: String, CaseIterable, Identifiable {
    case http
    case https

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
}

private enum DSMConnectionInputError: LocalizedError {
    case remoteLocalOnlyHost
}

private enum DSMConnectionLocation: String, CaseIterable, Identifiable {
    case local
    case remote

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .local: return "connect.location.local"
        case .remote: return "connect.location.remote"
        }
    }

    var hostPlaceholderKey: String {
        switch self {
        case .local: return "connect.host.example.local"
        case .remote: return "connect.host.example.remote"
        }
    }

    var hostHintKey: String {
        switch self {
        case .local: return "connect.host.hint.local"
        case .remote: return "connect.host.hint.remote"
        }
    }
}

struct DSMConnectionFlowView: View {
    let onConnected: () -> Void
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("connect.remember.nas") private var rememberNAS = true
    @AppStorage("connect.remember.account") private var rememberAccount = true
    @AppStorage("connect.remember.password") private var rememberPassword = true
    @AppStorage("connect.remembered.host") private var rememberedHost = ""
    @AppStorage("connect.remembered.account") private var rememberedAccount = ""
    @AppStorage("connect.remembered.location") private var rememberedLocationRaw = DSMConnectionLocation.remote.rawValue
    @AppStorage("connect.remembered.protocol") private var rememberedProtocolRaw = DSMConnectionProtocol.https.rawValue
    @AppStorage("connect.remembered.self_signed") private var rememberedAllowsSelfSignedCertificates = false
    @AppStorage("connect.remembered.fixed_address") private var rememberedUsesOnlyConfiguredAddress = false
    @State private var host = ""
    @State private var account = ""
    @State private var password = ""
    @State private var oneTimeCode = ""
    @State private var accessLocation: DSMConnectionLocation = .remote
    @State private var connectionProtocol: DSMConnectionProtocol = .https
    @State private var port = "443"
    @State private var portWasEdited = false
    @State private var basePath = ""
    @State private var allowsSelfSignedCertificates = false
    @State private var usesOnlyConfiguredAddress = false
    @State private var showsPassword = false
    @State private var isConnecting = false
    @State private var connectionStatusKey = "connect.review.authenticating"
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var connectionTask: Task<Void, Never>?
    @State private var connectionAttemptID: UUID?
    @State private var didLoadRememberedLogin = false

    var body: some View {
        List {
            Section {
                NavigationLink {
                    LANDiscoveryView(selectedHost: $host)
                } label: {
                    Label("connect.scan.title", systemImage: "dot.radiowaves.left.and.right")
                }

                Picker("connect.protocol", selection: $connectionProtocol) {
                    ForEach(DSMConnectionProtocol.allCases) { connectionProtocol in
                        Text(connectionProtocol.title).tag(connectionProtocol)
                    }
                }
                .pickerStyle(.menu)
                .disabled(accessLocation == .remote)
                .onChange(of: connectionProtocol) { connectionProtocol in
                    if connectionProtocol == .http {
                        allowsSelfSignedCertificates = false
                    }
                    refreshDefaultPortIfNeeded()
                }

                formTextField(
                    titleKey: "connect.host",
                    placeholderKey: "connect.input.host",
                    text: $host,
                    keyboardType: .URL
                )
                .onChange(of: host) { value in
                    adoptAddressInput(from: value)
                }

                formTextField(
                    titleKey: "connect.path",
                    placeholderKey: "connect.input.path",
                    text: $basePath,
                    keyboardType: .URL
                )

                formTextField(
                    titleKey: "connect.port",
                    placeholderKey: "connect.port.example",
                    text: Binding(
                        get: { port },
                        set: { value in
                            port = value
                            portWasEdited = true
                        }
                    ),
                    keyboardType: .numberPad
                )
                Toggle("connect.address.fixed", isOn: $usesOnlyConfiguredAddress)
            } header: {
                Text("connect.section.target")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("connect.input.address_hint")
                    if usesOnlyConfiguredAddress { Text("connect.address.fixed.hint") }
                }
            }.nastartListSection()

            Section {
                formTextField(
                    titleKey: "connect.account",
                    placeholderKey: "connect.input.account",
                    text: $account,
                    keyboardType: .asciiCapable
                )
                .textContentType(.username)

                HStack(spacing: 12) {
                    Text("connect.password")
                        .frame(width: 84, alignment: .leading)
                        .foregroundStyle(.primary)
                    Group {
                        if showsPassword {
                            TextField("connect.input.password", text: $password)
                        } else {
                            SecureField("connect.input.password", text: $password)
                        }
                    }
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.leading)

                    Button {
                        showsPassword.toggle()
                    } label: {
                        Image(systemName: showsPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(showsPassword ? "connect.password.hide" : "connect.password.show"))
                }

                formTextField(
                    titleKey: "connect.input.otp_label",
                    placeholderKey: "connect.input.otp",
                    text: $oneTimeCode,
                    keyboardType: .numberPad
                )
                .textContentType(.oneTimeCode)
            } header: {
                Text("connect.section.account")
            }.nastartListSection()

            Section {
                if automaticallyTrustsLocalHTTPSCertificate {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("connect.local_https_auto_trust")
                            Text("connect.local_https_auto_trust.inline_hint")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Toggle(isOn: $allowsSelfSignedCertificates) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("connect.trust_self_signed")
                            if allowsSelfSignedCertificates, accessLocation == .remote {
                                Text("connect.trust_self_signed.public_warning")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.accent)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text("connect.trust_self_signed.inline_hint")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(connectionProtocol == .http)
                }

                Toggle("connect.remember.filled", isOn: rememberFilledBinding)
                Toggle("connect.remember.password", isOn: $rememberPassword)
                    .disabled(!rememberNAS || !rememberAccount)
                    .onChange(of: rememberPassword) { value in
                        if value {
                            rememberNAS = true
                            rememberAccount = true
                        } else {
                            KeychainStore.shared.clearNASCredentials()
                        }
                    }
            } header: {
                Text("connect.section.security")
            } footer: {
                Text("connect.remember.hint")
            }.nastartListSection()
        }
        .listStyle(.insetGrouped)
        .disabled(isConnecting)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            connectButton
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.regularMaterial)
        }
        .nastartReadableWidth().nastartPageTheme()
        .navigationTitle("connect.nav")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("action.cancel") {
                    connectionTask?.cancel()
                    if let connectionAttemptID { connectionStore.cancelDSMConnectionAttempt(ownedBy: connectionAttemptID) }
                    dismiss()
                }
            }
        }
        .alert("connect.error.title", isPresented: $showError) {
            Button("action.ok", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadRememberedLoginIfNeeded()
        }
    }

    private func formTextField(
        titleKey: String,
        placeholderKey: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType
    ) -> some View {
        HStack(spacing: 12) {
            Text(LocalizedStringKey(titleKey))
                .frame(width: 84, alignment: .leading)
                .foregroundStyle(.primary)
            TextField(LocalizedStringKey(placeholderKey), text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .multilineTextAlignment(.leading)
        }
    }

    private var connectButton: some View {
        Button {
            connectDSM()
        } label: {
            HStack {
                if isConnecting {
                    ProgressView()
                        .tint(.white)
                }
                Text(LocalizedStringKey(isConnecting ? connectionStatusKey : "connect.action"))
                    .font(.headline.weight(.semibold))
            }
        }
        .buttonStyle(NastartPrimaryButtonStyle())
        .disabled(!canConnect)
    }

    private var canConnect: Bool {
        !isConnecting
            && !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !account.isEmpty
            && !password.isEmpty
            && isPortValid
            && !usesLocalOnlyHostInRemoteMode
    }

    private var usesLocalOnlyHostInRemoteMode: Bool {
        guard accessLocation == .remote else { return false }
        guard let normalizedHost = normalizedHostForValidation else { return false }
        return Self.isLocalOnlyHost(normalizedHost)
    }

    private var normalizedHostForValidation: String? {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        return URLComponents(string: candidate)?.host ?? trimmed
    }

    private var rememberFilledBinding: Binding<Bool> {
        Binding(
            get: { rememberNAS && rememberAccount },
            set: { value in
                rememberNAS = value
                rememberAccount = value
                if !value {
                    rememberPassword = false
                    rememberedHost = ""
                    rememberedAccount = ""
                    rememberedUsesOnlyConfiguredAddress = false
                    KeychainStore.shared.clearNASCredentials()
                }
            }
        )
    }

    private var isPortValid: Bool {
        let trimmed = port.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        guard let value = Int(trimmed) else { return false }
        return (1...65_535).contains(value)
    }

    private var defaultPort: String {
        if accessLocation == .remote {
            return connectionProtocol == .http ? "80" : "443"
        }
        return connectionProtocol == .http ? "5000" : "5001"
    }

    private var composedAddress: String {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedHost.contains("://") {
            return trimmedHost
        }

        var components = URLComponents()
        components.scheme = defaultSchemeForCurrentLocation
        components.host = trimmedHost
        if let portValue = Int(port.trimmingCharacters(in: .whitespacesAndNewlines)),
           (1...65_535).contains(portValue) {
            components.port = portValue
        }
        let normalizedPath = normalizedBasePath
        if !normalizedPath.isEmpty {
            components.path = normalizedPath
        }
        return components.string ?? "\(defaultSchemeForCurrentLocation)://\(trimmedHost)"
    }

    private var normalizedBasePath: String {
        let trimmed = basePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "/" else { return "" }
        return trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
    }

    @MainActor
    private func connectDSM() {
        let operationID = dataStore.beginDSMConnectionAttempt(using: connectionStore)
        connectionAttemptID = operationID
        isConnecting = true
        connectionStatusKey = "connect.review.authenticating"
        errorMessage = ""
        connectionTask = Task {
            var unpublishedSession: DSMSession?
            do {
                guard !usesLocalOnlyHostInRemoteMode else {
                    throw DSMConnectionInputError.remoteLocalOnlyHost
                }
                let baseURL = try DSMClient.normalizedBaseURL(
                    from: composedAddress,
                    defaultScheme: defaultSchemeForCurrentLocation
                )
                let effectiveAllowsSelfSignedCertificates = allowsSelfSignedCertificates
                    || Self.shouldAutomaticallyTrustLocalHTTPSCertificate(for: baseURL)
                let endpoints = DSMConnectionEndpoints(
                    primaryDomain: NetworkHostClassifier.isPrivate(baseURL.host) ? nil : baseURL,
                    lanAddress: NetworkHostClassifier.isPrivate(baseURL.host) ? baseURL : nil
                )
                let loginResult = try await DSMClient.login(
                    endpoints: endpoints,
                    allowsSelfSignedCertificates: effectiveAllowsSelfSignedCertificates,
                    account: account,
                    password: password,
                    oneTimeCode: oneTimeCode
                )
                let mainSession = loginResult.session
                unpublishedSession = mainSession
                try Task.checkCancellation()
                guard connectionStore.ownsDSMConnectionAttempt(operationID) else { throw CancellationError() }
                connectionStatusKey = "connect.review.connected"
                rememberSuccessfulConnection(
                    baseURL: baseURL,
                    account: account,
                    allowsSelfSignedCertificates: effectiveAllowsSelfSignedCertificates
                )
                if rememberPassword {
                    try KeychainStore.shared.saveNASCredential(
                        StoredNASCredential(
                            baseURLString: baseURL.absoluteString,
                            account: account,
                            password: password,
                            useAgent: false,
                            allowsSelfSignedCertificates: effectiveAllowsSelfSignedCertificates,
                            deviceID: mainSession.deviceID,
                            endpoints: mainSession.endpoints,
                            lastKnownRoute: mainSession.actualRoute,
                            usesOnlyConfiguredAddress: usesOnlyConfiguredAddress
                        )
                    )
                } else {
                    KeychainStore.shared.clearNASCredentials()
                }
                let shouldRememberPassword = rememberPassword
                let savedOneTimeCode = oneTimeCode
                let credential = StoredNASCredential(baseURLString: baseURL.absoluteString,
                    account: account, password: password, useAgent: false,
                    allowsSelfSignedCertificates: effectiveAllowsSelfSignedCertificates,
                    deviceID: mainSession.deviceID, endpoints: mainSession.endpoints,
                    lastKnownRoute: mainSession.actualRoute,
                    usesOnlyConfiguredAddress: usesOnlyConfiguredAddress)
                dataStore.activateDSMSession(session: mainSession, useAgent: false)
                connectionStore.connect(device: dataStore.device, session: mainSession)
                unpublishedSession = nil
                isConnecting = false
                connectionTask = nil
                onConnected()
                dismiss()

                Task {
                    try? await dataStore.finishDSMConnection(loginResult, credential: credential,
                        operationID: operationID, using: connectionStore, useAgent: false,
                        saveCredential: shouldRememberPassword, oneTimeCode: savedOneTimeCode)
                }
            } catch is CancellationError {
                if let session = unpublishedSession {
                    await DSMConnectionOperations().logout(session, connectionStore)
                }
                guard connectionStore.ownsDSMConnectionAttempt(operationID) else { return }
                isConnecting = false
                connectionTask = nil
            } catch {
                if let session = unpublishedSession {
                    await DSMConnectionOperations().logout(session, connectionStore)
                }
                guard !Task.isCancelled, connectionStore.ownsDSMConnectionAttempt(operationID) else { return }
                isConnecting = false
                connectionTask = nil
                errorMessage = connectionErrorMessage(for: error)
                showError = true
            }
        }
    }

    private var defaultSchemeForCurrentLocation: String {
        accessLocation == .remote ? DSMConnectionProtocol.https.rawValue : connectionProtocol.rawValue
    }

    private func loadRememberedLoginIfNeeded() {
        guard !didLoadRememberedLogin else { return }
        didLoadRememberedLogin = true

        if let location = DSMConnectionLocation(rawValue: rememberedLocationRaw) {
            accessLocation = location
        }
        if let rememberedProtocol = DSMConnectionProtocol(rawValue: rememberedProtocolRaw) {
            connectionProtocol = rememberedProtocol
        }
        let credential = KeychainStore.shared.loadNASCredential()
        usesOnlyConfiguredAddress = credential?.usesOnlyConfiguredAddress ?? rememberedUsesOnlyConfiguredAddress
        allowsSelfSignedCertificates = DSMCertificateTrustPolicy.initialToggle(
            savedTrust: credential?.allowsSelfSignedCertificates ?? rememberedAllowsSelfSignedCertificates,
            savedAddress: credential?.baseURLString ?? rememberedHost)
        if accessLocation == .remote {
            connectionProtocol = .https
        }

        if rememberNAS, host.isEmpty {
            host = credential?.baseURLString ?? rememberedHost
            adoptAddressInput(from: host)
        }
        if rememberAccount, account.isEmpty {
            account = credential?.account ?? rememberedAccount
        }
        if rememberPassword, password.isEmpty {
            password = credential?.password ?? ""
        }
    }

    private var automaticallyTrustsLocalHTTPSCertificate: Bool {
        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = try? DSMClient.normalizedBaseURL(
                from: composedAddress,
                defaultScheme: defaultSchemeForCurrentLocation
              )
        else {
            return false
        }
        return Self.shouldAutomaticallyTrustLocalHTTPSCertificate(for: url)
    }

    private static func shouldAutomaticallyTrustLocalHTTPSCertificate(for url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && NetworkHostClassifier.isPrivate(url.host)
    }

    private func rememberSuccessfulConnection(
        baseURL: URL,
        account: String,
        allowsSelfSignedCertificates: Bool
    ) {
        if rememberNAS {
            rememberedHost = baseURL.absoluteString
            rememberedLocationRaw = NetworkHostClassifier.isPrivate(baseURL.host)
                ? DSMConnectionLocation.local.rawValue
                : DSMConnectionLocation.remote.rawValue
            rememberedProtocolRaw = baseURL.scheme?.lowercased() ?? defaultSchemeForCurrentLocation
            rememberedAllowsSelfSignedCertificates = allowsSelfSignedCertificates
            rememberedUsesOnlyConfiguredAddress = usesOnlyConfiguredAddress
        } else {
            rememberedHost = ""
            rememberedUsesOnlyConfiguredAddress = false
        }

        if rememberAccount {
            rememberedAccount = account
        } else {
            rememberedAccount = ""
        }
    }

    private func adoptAddressInput(from value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let hasExplicitScheme = trimmed.contains("://")
        let urlText = hasExplicitScheme ? trimmed : "https://\(trimmed)"
        guard
            let components = URLComponents(string: urlText),
            let hostValue = components.host,
            !hostValue.isEmpty
        else {
            return
        }
        let parsedLocation: DSMConnectionLocation = NetworkHostClassifier.isPrivate(hostValue)
            ? .local
            : .remote
        if host != hostValue {
            host = hostValue
        }
        accessLocation = parsedLocation
        if hasExplicitScheme,
           let scheme = components.scheme?.lowercased(),
           let parsedProtocol = DSMConnectionProtocol(rawValue: scheme) {
            connectionProtocol = parsedProtocol
            if parsedProtocol == .http {
                allowsSelfSignedCertificates = false
            }
        } else if parsedLocation == .local,
                  components.port == 5_000 {
            connectionProtocol = .http
        } else if parsedLocation == .remote {
            connectionProtocol = .https
        }
        if let parsedPort = components.port {
            let parsedPortText = "\(parsedPort)"
            if port != parsedPortText {
                port = parsedPortText
            }
            portWasEdited = true
        } else if hasExplicitScheme {
            portWasEdited = false
            port = defaultPort
        } else if !portWasEdited {
            refreshDefaultPortIfNeeded()
        }
        let parsedPath = components.path == "/" ? "" : components.path
        if hasExplicitScheme || !parsedPath.isEmpty {
            basePath = parsedPath
        }
    }

    private func refreshDefaultPortIfNeeded() {
        guard !portWasEdited else { return }
        let trimmed = port.trimmingCharacters(in: .whitespacesAndNewlines)
        let commonDefaults = ["", "443", "5000", "5001"]
        guard commonDefaults.contains(trimmed) else { return }
        port = defaultPort
    }

    private func connectionErrorMessage(for error: Error) -> String {
        if let inputError = error as? DSMConnectionInputError {
            switch inputError {
            case .remoteLocalOnlyHost:
                return NSLocalizedString("connect.error.remote_local_host", comment: "")
            }
        }
        guard let urlError = error as? URLError else {
            return error.localizedDescription
        }
        switch urlError.code {
        case .networkConnectionLost, .cannotConnectToHost, .timedOut, .notConnectedToInternet:
            let key = accessLocation == .remote
                ? "connect.error.remote_unreachable"
                : "connect.error.local_unreachable"
            return NSLocalizedString(key, comment: "")
        case .serverCertificateUntrusted, .serverCertificateHasBadDate,
                .serverCertificateHasUnknownRoot, .secureConnectionFailed:
            return NSLocalizedString("connect.error.certificate", comment: "")
        default:
            return error.localizedDescription
        }
    }

    private static func isLocalOnlyHost(_ host: String) -> Bool {
        var normalized = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasPrefix("[") && normalized.hasSuffix("]") {
            normalized.removeFirst()
            normalized.removeLast()
        }
        normalized = normalized.split(separator: "%", maxSplits: 1).first.map(String.init) ?? normalized
        return normalized == "localhost"
            || normalized.hasSuffix(".local")
            || normalized.hasSuffix(".lan")
    }

    private func fallbackSnapshot(baseURL: URL, session: DSMSession) -> DSMDataSnapshot {
        let trimmedHost = baseURL.host?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayName = trimmedHost.isEmpty ? "DSM" : trimmedHost
        let device = NASDevice(
            id: UUID(),
            name: displayName,
            subtitle: "DSM",
            model: nil,
            dsmVersion: nil,
            mode: .dsmOnly,
            cpu: nil,
            memory: nil,
            memoryUsedText: nil,
            memoryTotalText: nil,
            storageUsed: nil,
            storageUsedText: nil,
            storageTotalText: nil,
            storageFreeText: "-",
            uptimeMinutes: nil,
            temperatureText: nil,
            certificate: nil,
            sshStatus: .unavailable
        )
        let dsmService = LaunchpadService(
            id: UUID(uuidString: "A1F38D26-9B9F-43B3-965F-001A21D22401") ?? UUID(),
            name: "DSM",
            iconText: "DSM",
            category: .favorites,
            status: .online,
            subtitle: "service.dsm.subtitle",
            detail: "service.dsm.detail",
            isMedia: false,
            cpu: nil,
            memoryText: nil,
            endpoint: session.baseURL,
            source: .dsm
        )
        return DSMDataSnapshot(
            device: device,
            services: [dsmService],
            containers: [],
            files: [],
            tasks: [],
            videoLibraryItems: [],
            audioLibraryItems: [],
            discoveredDevices: [],
            containerInventoryAvailable: false,
            packageInventoryAvailable: false,
            reverseProxyInventoryAvailable: false,
            agentHealth: nil
        )
    }

    private func connectionFieldLabel(_ key: String, optional: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(LocalizedStringKey(key))
                .font(.subheadline.weight(.medium))
            if optional {
                Text("connect.optional")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, -8)
    }
}

private struct LANDiscoveryView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedHost: String
    @StateObject private var discoveryService = LANDiscoveryService()

    var body: some View {
        List {
            Section {
                Text("connect.scan.description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }.nastartListSection()

            Section {
                if discoveryService.devices.isEmpty {
                    VStack(spacing: 10) {
                        if discoveryService.isSearching {
                            ProgressView()
                            Text("connect.scan.searching")
                        } else {
                            Image(systemName: discoveryService.errorKey == nil ? "server.rack" : "exclamationmark.triangle")
                                .font(.title2)
                            Text(LocalizedStringKey(discoveryService.errorKey ?? "connect.scan.empty"))
                                .multilineTextAlignment(.center)
                            Button("connect.scan.retry") {
                                discoveryService.start()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                } else {
                    ForEach(discoveryService.devices) { device in
                        HStack(spacing: 12) {
                            Image(systemName: "server.rack")
                                .frame(width: 36, height: 36)
                                .nastartSurface()
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name)
                                    .font(.body.weight(.medium))
                                Text(device.host)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("connect.scan.use") {
                                selectedHost = device.host
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                            .tint(AppTheme.accent)
                        }
                        .padding(.vertical, 3)
                    }
                }
            } header: {
                Text("connect.scan.results")
            }.nastartListSection()
        }
        .listStyle(.insetGrouped)
        .nastartReadableWidth().nastartPageTheme()
        .navigationTitle("connect.scan.title")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            discoveryService.start()
        }
        .onDisappear {
            discoveryService.stop()
        }
    }
}

private extension View {
    func connectionInputStyle() -> some View {
        self
            .padding(.horizontal, 13)
            .frame(minHeight: 48)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            }
    }

    func connectionSectionStyle() -> some View {
        self
            .padding(16)
            .nastartSurface()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct AgentSetupGuideView: View {
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @EnvironmentObject private var dataStore: AppDataStore
    @State private var agentAddress = ""
    @State private var pairingCode = ""
    @State private var allowsSelfSignedCertificates = false
    @State private var isPairing = false
    @State private var resultMessage: String?
    @State private var errorMessage: String?
    @State private var showCopyHint = false

    private var desktopCommand: String {
        let host = connectionStore.dsmSession?.baseURL.host ?? "NAS_HOST"
        return "./scripts/install_agent_via_ssh.sh --host \(host) --user SSH_USER --pairing-code 123456"
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("connect.agent.guide")
                        .font(.title2.weight(.bold))
                    Text("connect.agent.description")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }.nastartListSection()

            Section {
                compactAgentTextField(
                    titleKey: "agent.address",
                    placeholderKey: "agent.address.placeholder",
                    text: $agentAddress,
                    keyboardType: .URL
                )
                compactAgentTextField(
                    titleKey: "agent.pairing_code",
                    placeholderKey: "agent.pairing_code.placeholder",
                    text: $pairingCode,
                    keyboardType: .numberPad
                )
                Toggle("connect.trust_self_signed", isOn: $allowsSelfSignedCertificates)

                Button {
                    pairAgent()
                } label: {
                    HStack {
                        if isPairing { ProgressView() }
                        Label(
                            connectionStore.usesAgent ? "agent.action.repair" : "agent.action.pair",
                            systemImage: "link"
                        )
                    }
                }
                .disabled(
                    isPairing
                        || agentAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || pairingCode.count != 6
                )

                if connectionStore.usesAgent {
                    LabeledContent("agent.connected_host") {
                        Text(connectionStore.agentConnection?.hostIdentity ?? "-")
                            .foregroundStyle(.green)
                    }
                    Button(role: .destructive) {
                        connectionStore.disconnectAgent()
                        resultMessage = NSLocalizedString("agent.disconnected", comment: "")
                    } label: {
                        Label("agent.action.disconnect", systemImage: "link.badge.minus")
                    }
                }

                if let resultMessage {
                    Label(resultMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("agent.pairing.section")
            } footer: {
                Text("agent.pairing.footer")
            }.nastartListSection()

            Section {
                AgentStepRow(number: 1, titleKey: "connect.agent.step.package", detailKey: "connect.agent.step.package_detail")
                AgentStepRow(number: 2, titleKey: "connect.agent.step.token", detailKey: "connect.agent.step.token_detail")
                AgentStepRow(number: 3, titleKey: "connect.agent.step.verify", detailKey: "connect.agent.step.verify_detail")

                Text(desktopCommand)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                Button("connect.agent.copy") {
                    UIPasteboard.general.string = desktopCommand
                    showCopyHint = true
                }
            } header: {
                Text("agent.desktop_ssh.section")
            } footer: {
                Text("agent.desktop_ssh.footer")
            }.nastartListSection()

            Section {
                NavigationLink {
                    MobileSSHAgentInstallerView()
                } label: {
                    Label("agent.mobile_ssh.title", systemImage: "iphone.and.arrow.forward")
                }
            } header: {
                Text("agent.mobile_ssh.section")
            } footer: {
                Text("agent.mobile_ssh.footer")
            }.nastartListSection()
        }
        .listStyle(.insetGrouped)
        .nastartReadableWidth().nastartPageTheme()
        .navigationTitle("connect.agent.guide")
        .task {
            guard agentAddress.isEmpty, let host = connectionStore.dsmSession?.baseURL.host else { return }
            agentAddress = "http://\(host):8787"
        }
        .alert("connect.agent.copy_hint", isPresented: $showCopyHint) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private func pairAgent() {
        errorMessage = nil
        resultMessage = nil
        isPairing = true
        Task {
            do {
                guard let url = UserConfiguredServiceURLPolicy.normalizedURL(from: agentAddress) else {
                    throw AgentClientError.invalidAddress
                }
                let client = try AgentClient(
                    baseURL: url,
                    allowsSelfSignedCertificates: allowsSelfSignedCertificates
                )
                let connection = try await client.pair(
                    code: pairingCode,
                    allowsSelfSignedCertificates: allowsSelfSignedCertificates
                )
                _ = try await client.handshake(connection: connection)
                try await MainActor.run {
                    try connectionStore.connectAgent(connection)
                }
                if let session = connectionStore.dsmSession {
                    await dataStore.refreshDSM(session: session, useAgent: true)
                }
                await MainActor.run {
                    pairingCode = ""
                    resultMessage = NSLocalizedString("agent.pairing.success", comment: "")
                    isPairing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isPairing = false
                }
            }
        }
    }

    private func compactAgentTextField(
        titleKey: LocalizedStringKey,
        placeholderKey: LocalizedStringKey,
        text: Binding<String>,
        keyboardType: UIKeyboardType
    ) -> some View {
        HStack(spacing: 12) {
            Text(titleKey)
                .foregroundStyle(.primary)
            TextField(placeholderKey, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct MobileSSHAgentInstallerView: View {
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @EnvironmentObject private var dataStore: AppDataStore
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var password = ""
    @State private var pairingCode = ""
    @State private var inspectedIdentity: SSHHostIdentity?
    @State private var trustedHostKey: String?
    @State private var isInspecting = false
    @State private var isInstalling = false
    @State private var resultMessage: String?
    @State private var errorMessage: String?

    private var normalizedHost: String {
        let value = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.hasPrefix("["), value.hasSuffix("]") else { return value }
        return String(value.dropFirst().dropLast())
    }

    private var sshPort: Int? {
        Int(port).flatMap { (1...65_535).contains($0) ? $0 : nil }
    }

    private var hasTrustedCurrentKey: Bool {
        guard let inspectedIdentity, let trustedHostKey else { return false }
        return inspectedIdentity.openSSHKey == trustedHostKey
    }

    var body: some View {
        Form {
            Section {
                compactSSHTextField(
                    titleKey: "agent.ssh.host",
                    placeholderKey: "agent.ssh.host.example",
                    text: $host,
                    keyboardType: .URL
                )
                compactSSHTextField(
                    titleKey: "agent.ssh.port",
                    placeholderKey: "agent.ssh.port.example",
                    text: $port,
                    keyboardType: .numberPad
                )
                compactSSHTextField(
                    titleKey: "agent.ssh.username",
                    placeholderKey: "agent.ssh.username.example",
                    text: $username,
                    keyboardType: .asciiCapable
                )
                HStack(spacing: 12) {
                    Text("agent.ssh.password")
                    SecureField("agent.ssh.password.example", text: $password)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                }
                compactSSHTextField(
                    titleKey: "agent.pairing_code",
                    placeholderKey: "agent.pairing_code.placeholder",
                    text: $pairingCode,
                    keyboardType: .numberPad
                )
            } header: {
                Text("agent.ssh.connection.section")
            } footer: {
                Text("agent.ssh.connection.footer")
            }.nastartListSection()

            Section {
                Button {
                    inspectHostKey()
                } label: {
                    HStack {
                        if isInspecting { ProgressView() }
                        Label("agent.ssh.inspect", systemImage: "checkmark.shield")
                    }
                }
                .disabled(isInspecting || isInstalling || normalizedHost.isEmpty || sshPort == nil)

                if let identity = inspectedIdentity {
                    LabeledContent("agent.ssh.fingerprint") {
                        Text(identity.fingerprint)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                    if hasTrustedCurrentKey {
                        Label("agent.ssh.trusted", systemImage: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("agent.ssh.trust") {
                            trustInspectedHostKey()
                        }
                    }
                }
            } header: {
                Text("agent.ssh.host_key.section")
            } footer: {
                Text("agent.ssh.host_key.footer")
            }.nastartListSection()

            Section {
                Button {
                    installAndPair()
                } label: {
                    HStack {
                        if isInstalling { ProgressView() }
                        Label("agent.ssh.install", systemImage: "shippingbox.and.arrow.backward")
                    }
                }
                .disabled(
                    isInstalling
                        || !hasTrustedCurrentKey
                        || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || password.isEmpty
                        || pairingCode.count != 6
                )

                if let resultMessage {
                    Label(resultMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("agent.ssh.install.section")
            } footer: {
                Text("agent.ssh.install.footer")
            }.nastartListSection()
        }
        .nastartReadableWidth().nastartPageTheme()
        .navigationTitle("agent.mobile_ssh.title")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard host.isEmpty, let dsmHost = connectionStore.dsmSession?.baseURL.host else { return }
            host = dsmHost
            reloadTrustedHostKey()
        }
        .onChange(of: host) { _ in
            inspectedIdentity = nil
            reloadTrustedHostKey()
        }
        .onChange(of: port) { _ in
            inspectedIdentity = nil
            reloadTrustedHostKey()
        }
    }

    private func compactSSHTextField(
        titleKey: LocalizedStringKey,
        placeholderKey: LocalizedStringKey,
        text: Binding<String>,
        keyboardType: UIKeyboardType
    ) -> some View {
        HStack(spacing: 12) {
            Text(titleKey)
            TextField(placeholderKey, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .multilineTextAlignment(.trailing)
        }
    }

    private func reloadTrustedHostKey() {
        guard let sshPort, !normalizedHost.isEmpty else {
            trustedHostKey = nil
            return
        }
        trustedHostKey = KeychainStore.shared.loadSSHHostKey(host: normalizedHost, port: sshPort)
    }

    private func inspectHostKey() {
        guard let sshPort else { return }
        isInspecting = true
        errorMessage = nil
        resultMessage = nil
        Task {
            do {
                let identity = try await SSHAgentInstaller.inspectHost(host: normalizedHost, port: sshPort)
                await MainActor.run {
                    inspectedIdentity = identity
                    reloadTrustedHostKey()
                    isInspecting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isInspecting = false
                }
            }
        }
    }

    private func trustInspectedHostKey() {
        guard let identity = inspectedIdentity, let sshPort else { return }
        do {
            try KeychainStore.shared.saveSSHHostKey(
                identity.openSSHKey,
                host: normalizedHost,
                port: sshPort
            )
            trustedHostKey = identity.openSSHKey
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func installAndPair() {
        guard let sshPort, let trustedHostKey else { return }
        isInstalling = true
        errorMessage = nil
        resultMessage = nil
        let installationPassword = password
        Task {
            do {
                _ = try await SSHAgentInstaller.install(
                    host: normalizedHost,
                    port: sshPort,
                    username: username,
                    password: installationPassword,
                    pairingCode: pairingCode,
                    trustedHostKey: trustedHostKey
                )
                var components = URLComponents()
                components.scheme = "http"
                components.host = normalizedHost
                components.port = 8_787
                guard let baseURL = components.url else {
                    throw AgentClientError.invalidAddress
                }
                let client = try AgentClient(baseURL: baseURL, allowsSelfSignedCertificates: false)
                let connection = try await client.pair(
                    code: pairingCode,
                    allowsSelfSignedCertificates: false
                )
                _ = try await client.handshake(connection: connection)
                try await MainActor.run {
                    try connectionStore.connectAgent(connection)
                }
                if let session = connectionStore.dsmSession {
                    await dataStore.refreshDSM(session: session, useAgent: true)
                }
                await MainActor.run {
                    password = ""
                    pairingCode = ""
                    resultMessage = NSLocalizedString("agent.ssh.install.success", comment: "")
                    isInstalling = false
                }
                DiagnosticLogStore.shared.record(
                    .info,
                    categoryKey: "diagnostics.category.agent",
                    messageKey: "diagnostics.agent.install_succeeded"
                )
            } catch {
                await MainActor.run {
                    password = ""
                    errorMessage = error.localizedDescription
                    isInstalling = false
                }
                DiagnosticLogStore.shared.record(
                    .warning,
                    categoryKey: "diagnostics.category.agent",
                    messageKey: "diagnostics.agent.install_failed",
                    details: ["error": String(describing: error)]
                )
            }
        }
    }
}

struct AgentStepRow: View {
    let number: Int
    let titleKey: LocalizedStringKey
    let detailKey: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .frame(width: 26, height: 26)
                .nastartSurface()
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(titleKey)
                    .font(.body.weight(.medium))
                Text(detailKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}
