import AuthenticationServices
import LocalAuthentication
import UIKit

enum AutofillContentType: Int {
    case passwords = 0
}

final class CredentialProviderViewController: ASCredentialProviderViewController {
    private let store = AutofillCredentialStore()
    private let biometricAuth = BiometricAuthManager()
    private var credentials: [AutofillCredential] = []
    private var filteredCredentials: [AutofillCredential] = []
    private var latestServiceIdentifiers: [ASCredentialServiceIdentifier] = []
    private var isShowingAllCredentials = false
    private var searchText: String = ""
    private var lastDomainFilterWasEmpty = false
    private var currentContentType: AutofillContentType = .passwords
    private var isAuthenticated = false
    private var pendingCredentialIdentity: ASPasswordCredentialIdentity?
    
    // MARK: - UI Components
    
    private lazy var customHeaderView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGroupedBackground
        
        // Cancel button - plain text only
        let cancelButton = UIButton(type: .system)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("İptal", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17)
        cancelButton.setTitleColor(.systemBlue, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        
        // Title label
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "FluPass"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        
        view.addSubview(cancelButton)
        view.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            cancelButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        return view
    }()

    private lazy var segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["🔑 Şifreler"])
        control.translatesAutoresizingMaskIntoConstraints = false
        control.selectedSegmentIndex = 0
        control.isHidden = true
        control.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        return control
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .onDrag
        tableView.register(CredentialTableViewCell.self, forCellReuseIdentifier: CredentialTableViewCell.reuseIdentifier)
        return tableView
    }()

    private lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = "Şifrelerde ara..."
        searchBar.searchBarStyle = .minimal
        searchBar.autocapitalizationType = .none
        searchBar.delegate = self
        return searchBar
    }()

    private lazy var showAllButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.font = .systemFont(ofSize: 15)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        button.addTarget(self, action: #selector(toggleCredentialFilter), for: .touchUpInside)
        return button
    }()
    
    private lazy var headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        
        let stack = UIStackView(arrangedSubviews: [segmentedControl, searchBar, showAllButton])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])
        
        return view
    }()

    private lazy var emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private lazy var authOverlayView: AuthenticationOverlayView = {
        let view = AuthenticationOverlayView(biometricType: biometricAuth.biometricType)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        updateAuthOverlayVisibility()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeaderLayout()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !isAuthenticated && store.isBiometricEnabled {
            performAuthentication()
        }
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        
        view.addSubview(customHeaderView)
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        view.addSubview(authOverlayView)
        
        tableView.tableHeaderView = headerView
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            customHeaderView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            customHeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customHeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            customHeaderView.heightAnchor.constraint(equalToConstant: 44),
            
            tableView.topAnchor.constraint(equalTo: customHeaderView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateView.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: tableView.centerYAnchor, constant: 50),
            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            emptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
            
            authOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            authOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            authOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            authOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func updateHeaderLayout() {
        guard let header = tableView.tableHeaderView else { return }
        header.setNeedsLayout()
        header.layoutIfNeeded()
        let targetSize = CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        let headerSize = header.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let newSize = CGSize(width: tableView.bounds.width, height: headerSize.height)
        if header.frame.size != newSize {
            header.frame.size = newSize
            tableView.tableHeaderView = header
        }
    }
    
    // MARK: - Actions
    
    @objc
    private func cancelButtonTapped() {
        let error = NSError(
            domain: ASExtensionErrorDomain,
            code: ASExtensionError.Code.userCanceled.rawValue
        )
        extensionContext.cancelRequest(withError: error)
    }
    
    // MARK: - Authentication
    
    private func updateAuthOverlayVisibility() {
        let shouldShowAuth = store.isBiometricEnabled && !isAuthenticated
        authOverlayView.isHidden = !shouldShowAuth
        customHeaderView.isHidden = shouldShowAuth
        tableView.isHidden = shouldShowAuth
        updateEmptyState()
    }
    
    private func performAuthentication() {
        biometricAuth.authenticate(reason: "FluPass şifrelerinize erişmek için kimliğinizi doğrulayın") { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                self.handleAuthSuccess()
                
            case .cancelled:
                self.cancelButtonTapped()
                
            case .failed(let error):
                NSLog("[CredentialProvider] Authentication failed: \(String(describing: error))")
                self.authOverlayView.showError("Doğrulama başarısız. Tekrar deneyin.")
                
            case .notAvailable, .notEnrolled:
                self.handleAuthSuccess()
            }
        }
    }
    
    private func handleAuthSuccess() {
        isAuthenticated = true
        
        UIView.animate(withDuration: 0.3) {
            self.updateAuthOverlayVisibility()
        }
        
        reloadAllData()
        applyCurrentFilter()
        tableView.reloadData()
        updateEmptyState()
        updateHeaderControls()
        
        if let identity = pendingCredentialIdentity {
            pendingCredentialIdentity = nil
            provideCredentialAfterAuth(for: identity)
        }
    }

    @objc
    private func segmentChanged() {
        currentContentType = .passwords
        searchBar.placeholder = "Şifrelerde ara..."
        
        UIView.transition(with: tableView, duration: 0.2, options: .transitionCrossDissolve) {
            self.applyCurrentFilter()
            self.tableView.reloadData()
        }
        
        updateEmptyState()
        updateHeaderControls()
    }

    private func reloadAllData() {
        credentials = store.loadCredentials()
        filteredCredentials = credentials
        lastDomainFilterWasEmpty = false
    }

    private func applyCurrentFilter() {
        applyPasswordFilter()
    }

    private func applyPasswordFilter() {
        let hasIdentifiers = !latestServiceIdentifiers.isEmpty
        
        let domainMatches: [AutofillCredential] = {
            guard hasIdentifiers else { return credentials }
            let identifiers = latestServiceIdentifiers.map { $0.identifier }
            return DomainMatcher.filterCredentials(credentials, for: identifiers)
        }()

        lastDomainFilterWasEmpty = hasIdentifiers && !isShowingAllCredentials && domainMatches.isEmpty

        var base: [AutofillCredential]
        if isShowingAllCredentials || !hasIdentifiers {
            base = credentials
        } else {
            base = domainMatches
        }

        if !searchText.isEmpty {
            let term = searchText.lowercased()
            base = base.filter { credential in
                credential.displayName.lowercased().contains(term)
                    || credential.username.lowercased().contains(term)
                    || (credential.website?.lowercased().contains(term) ?? false)
                    || credential.title.lowercased().contains(term)
            }
        }

        filteredCredentials = base
    }

    private func updateEmptyState() {
        guard authOverlayView.isHidden else {
            emptyStateView.isHidden = true
            return
        }
        
        let isEmpty = filteredCredentials.isEmpty

        if isEmpty {
            if !searchText.isEmpty {
                emptyStateView.configure(
                    icon: "magnifyingglass",
                    title: "Sonuç Bulunamadı",
                    message: "'\(searchText)' için eşleşme bulunamadı."
                )
            } else if lastDomainFilterWasEmpty {
                emptyStateView.configure(
                    icon: "globe",
                    title: "Eşleşme Yok",
                    message: "Bu site için kayıtlı şifre bulunamadı.\nTüm şifreleri görmek için aşağıdaki butona dokunun."
                )
            } else {
                emptyStateView.configure(
                    icon: "key",
                    title: "Şifre Yok",
                    message: "FluPass uygulamasından şifre ekleyin."
                )
            }
            emptyStateView.isHidden = false
        } else {
            emptyStateView.isHidden = true
        }
    }

    private func updateHeaderControls() {
        let shouldShowToggle = !latestServiceIdentifiers.isEmpty && !credentials.isEmpty
        
        if shouldShowToggle {
            let title = isShowingAllCredentials ? "📍 Bu siteye ait olanları göster" : "📋 Tüm şifreleri göster"
            showAllButton.setTitle(title, for: .normal)
        }
        
        UIView.animate(withDuration: 0.2) {
            self.showAllButton.isHidden = !shouldShowToggle
            self.showAllButton.alpha = shouldShowToggle ? 1 : 0
        }
        
        updateHeaderLayout()
    }

    @objc
    private func toggleCredentialFilter() {
        isShowingAllCredentials.toggle()
        if !isShowingAllCredentials && latestServiceIdentifiers.isEmpty {
            isShowingAllCredentials = true
        }
        
        UIView.transition(with: tableView, duration: 0.2, options: .transitionCrossDissolve) {
            self.applyCurrentFilter()
            self.tableView.reloadData()
        }
        
        updateEmptyState()
        updateHeaderControls()
    }

    // MARK: - ASCredentialProviderViewController

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        latestServiceIdentifiers = serviceIdentifiers
        isShowingAllCredentials = false
        searchText = ""
        searchBar.text = ""
        currentContentType = .passwords
        segmentedControl.selectedSegmentIndex = 0
        
        if store.isBiometricEnabled && !isAuthenticated {
            updateAuthOverlayVisibility()
            return
        }
        
        reloadAllData()
        applyCurrentFilter()
        tableView.reloadData()
        updateEmptyState()
        updateHeaderControls()
    }

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        if store.isBiometricEnabled {
            let error = NSError(
                domain: ASExtensionErrorDomain,
                code: ASExtensionError.Code.userInteractionRequired.rawValue
            )
            extensionContext.cancelRequest(withError: error)
            return
        }
        
        reloadAllData()
        guard let credential = lookupCredential(for: credentialIdentity) else {
            let error = NSError(
                domain: ASExtensionErrorDomain,
                code: ASExtensionError.Code.credentialIdentityNotFound.rawValue
            )
            extensionContext.cancelRequest(withError: error)
            return
        }

        let passwordCredential = credential.makePasswordCredential()
        extensionContext.completeRequest(withSelectedCredential: passwordCredential, completionHandler: nil)
    }

    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        latestServiceIdentifiers = [credentialIdentity.serviceIdentifier]
        isShowingAllCredentials = false
        searchText = ""
        searchBar.text = ""
        currentContentType = .passwords
        segmentedControl.selectedSegmentIndex = 0
        
        if store.isBiometricEnabled && !isAuthenticated {
            pendingCredentialIdentity = credentialIdentity
            updateAuthOverlayVisibility()
            return
        }
        
        provideCredentialAfterAuth(for: credentialIdentity)
    }
    
    private func provideCredentialAfterAuth(for credentialIdentity: ASPasswordCredentialIdentity) {
        reloadAllData()
        guard let credential = lookupCredential(for: credentialIdentity) else {
            let error = NSError(
                domain: ASExtensionErrorDomain,
                code: ASExtensionError.Code.credentialIdentityNotFound.rawValue
            )
            extensionContext.cancelRequest(withError: error)
            return
        }

        // Kullanıcı QuickType bar'dan şifre seçtiğinde UI göstermeden doğrudan doldur
        let passwordCredential = credential.makePasswordCredential()
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        extensionContext.completeRequest(withSelectedCredential: passwordCredential, completionHandler: nil)
    }

    private func lookupCredential(for identity: ASPasswordCredentialIdentity) -> AutofillCredential? {
        credentials.first { String($0.id) == identity.recordIdentifier }
    }

    private func showCopiedFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        let toast = ToastView(message: "Kopyalandı ✓")
        toast.show(in: view)
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension CredentialProviderViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredCredentials.count
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let count = filteredCredentials.count
        return count > 0 ? "\(count) şifre" : nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return configureCredentialCell(for: indexPath, in: tableView)
    }

    private func configureCredentialCell(for indexPath: IndexPath, in tableView: UITableView) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: CredentialTableViewCell.reuseIdentifier, for: indexPath) as? CredentialTableViewCell else {
            return UITableViewCell()
        }
        let credential = filteredCredentials[indexPath.row]
        cell.configure(with: credential)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < filteredCredentials.count else { return }
        let credential = filteredCredentials[indexPath.row]
        let passwordCredential = credential.makePasswordCredential()
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        extensionContext.completeRequest(withSelectedCredential: passwordCredential, completionHandler: nil)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }
}

// MARK: - UISearchBarDelegate

extension CredentialProviderViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText = searchText
        applyCurrentFilter()
        tableView.reloadData()
        updateEmptyState()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - AuthenticationOverlayViewDelegate

extension CredentialProviderViewController: AuthenticationOverlayViewDelegate {
    func authenticationOverlayDidRequestAuthentication() {
        performAuthentication()
    }
    
    func authenticationOverlayDidRequestCancel() {
        cancelButtonTapped()
    }
}

// MARK: - Custom Views

protocol AuthenticationOverlayViewDelegate: AnyObject {
    func authenticationOverlayDidRequestAuthentication()
    func authenticationOverlayDidRequestCancel()
}

final class AuthenticationOverlayView: UIView {
    weak var delegate: AuthenticationOverlayViewDelegate?
    
    private let errorLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .systemRed
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()
    
    init(biometricType: BiometricAuthManager.BiometricType) {
        super.init(frame: .zero)
        setupUI(biometricType: biometricType)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI(biometricType: BiometricAuthManager.BiometricType) {
        backgroundColor = .systemBackground
        
        let biometricIcon: String
        let biometricName: String
        
        switch biometricType {
        case .faceID:
            biometricIcon = "faceid"
            biometricName = "Face ID"
        case .touchID:
            biometricIcon = "touchid"
            biometricName = "Touch ID"
        case .opticID:
            biometricIcon = "opticid"
            biometricName = "Optic ID"
        case .none:
            biometricIcon = "lock.fill"
            biometricName = "Şifre"
        }
        
        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .systemBlue
        iconImageView.image = UIImage(systemName: biometricIcon)?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 64, weight: .regular)
        )
        
        let titleLabel = UILabel()
        titleLabel.text = "FluPass Kilitli"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Şifrelerinize erişmek için\n\(biometricName) ile doğrulayın"
        subtitleLabel.font = .systemFont(ofSize: 15)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        let authenticateButton = UIButton(type: .system)
        authenticateButton.setTitle("Kilidi Aç", for: .normal)
        authenticateButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        authenticateButton.backgroundColor = .systemBlue
        authenticateButton.setTitleColor(.white, for: .normal)
        authenticateButton.layer.cornerRadius = 12
        authenticateButton.contentEdgeInsets = UIEdgeInsets(top: 14, left: 24, bottom: 14, right: 24)
        authenticateButton.addTarget(self, action: #selector(authenticateTapped), for: .touchUpInside)
        
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("İptal", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        
        let stackView = UIStackView(arrangedSubviews: [
            iconImageView,
            titleLabel,
            subtitleLabel,
            errorLabel,
            authenticateButton,
            cancelButton
        ])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.setCustomSpacing(24, after: subtitleLabel)
        stackView.setCustomSpacing(8, after: errorLabel)
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 80),
            iconImageView.heightAnchor.constraint(equalToConstant: 80),
            authenticateButton.widthAnchor.constraint(equalToConstant: 200),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32)
        ])
    }
    
    func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
        
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.5
        animation.values = [-10, 10, -8, 8, -5, 5, -2, 2, 0]
        layer.add(animation, forKey: "shake")
    }
    
    @objc private func authenticateTapped() {
        errorLabel.isHidden = true
        delegate?.authenticationOverlayDidRequestAuthentication()
    }
    
    @objc private func cancelTapped() {
        delegate?.authenticationOverlayDidRequestCancel()
    }
}

final class EmptyStateView: UIView {
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .tertiaryLabel
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .label
        return label
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        let stackView = UIStackView(arrangedSubviews: [iconImageView, titleLabel, messageLabel])
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 56),
            iconImageView.heightAnchor.constraint(equalToConstant: 56),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(icon: String, title: String, message: String) {
        iconImageView.image = UIImage(systemName: icon)?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 48, weight: .light)
        )
        titleLabel.text = title
        messageLabel.text = message
    }
}

final class CredentialTableViewCell: UITableViewCell {
    static let reuseIdentifier = "CredentialTableViewCell"
    
    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        return imageView
    }()
    
    private let iconContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBlue
        view.layer.cornerRadius = 10
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textColor = .label
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        iconContainer.addSubview(iconView)
        
        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(iconContainer)
        contentView.addSubview(textStack)
        
        accessoryType = .disclosureIndicator
        
        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 44),
            iconContainer.heightAnchor.constraint(equalToConstant: 44),
            
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            textStack.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    func configure(with credential: AutofillCredential) {
        titleLabel.text = credential.displayName
        subtitleLabel.text = credential.username
        iconView.image = UIImage(systemName: "key.fill")
        
        let colors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemPink, .systemTeal]
        let index = abs(credential.displayName.hashValue) % colors.count
        iconContainer.backgroundColor = colors[index]
    }
}

final class ToastView: UIView {
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    init(message: String) {
        super.init(frame: .zero)
        messageLabel.text = message
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.8)
        layer.cornerRadius = 20
        translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(messageLabel)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            messageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    
    func show(in parentView: UIView) {
        parentView.addSubview(self)
        
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: parentView.centerXAnchor),
            bottomAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.bottomAnchor, constant: -50)
        ])
        
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.2) {
            self.alpha = 1
            self.transform = .identity
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            UIView.animate(withDuration: 0.2, animations: {
                self.alpha = 0
                self.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            }) { _ in
                self.removeFromSuperview()
            }
        }
    }
}
