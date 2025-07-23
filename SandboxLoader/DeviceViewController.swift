import AppKit
import Combine

fileprivate class DeviceTableCellView: NSTableCellView {

    private let deviceNameField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with device: Device) {
        deviceNameField.stringValue = device.name
    }

    private func setupViews() {
        
        // Configure the views
        deviceNameField.font = .systemFont(ofSize: 14, weight: .medium)
        deviceNameField.translatesAutoresizingMaskIntoConstraints = false
        deviceNameField.backgroundColor = .alternateSelectedControlTextColor

        addSubview(deviceNameField)

        NSLayoutConstraint.activate([
            // Pin the text field to the cell's bounds with padding and center it vertically
            deviceNameField.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 0),
            deviceNameField.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: 0),
            deviceNameField.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        ])
    }
}


class DeviceViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var viewModel: ContentViewModel!
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI Components
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let headerView = NSView()
    private let titleLabel = NSTextField(labelWithString: "Devices")
    private let refreshButton = NSButton(image: NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")!, target: nil, action: nil)

    override func loadView() {
        self.view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        viewModel.refreshDevices()
    }

    private func setupUI() {
        // --- Header ---
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        headerView.layer?.borderWidth = 1.0
        headerView.layer?.borderColor = NSColor.separatorColor.cgColor

        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = .labelColor

        refreshButton.bezelStyle = .texturedRounded
        refreshButton.target = self
        refreshButton.action = #selector(refreshDevices)

        let headerStack = NSStackView(views: [titleLabel, NSView(), refreshButton])
        headerStack.orientation = .horizontal
        headerStack.distribution = .fill
        headerStack.alignment = .centerY
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(headerStack)

        // --- Table View ---
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let mainStack = NSStackView(views: [headerView, scrollView])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 0
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)

        NSLayoutConstraint.activate([
            headerStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            headerStack.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 50),

            mainStack.topAnchor.constraint(equalTo: view.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.widthAnchor.constraint(equalTo: mainStack.widthAnchor)
        ])

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("DeviceNameColumn"))
        column.title = "Devices"
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.backgroundColor = .white
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.gridStyleMask = [.solidHorizontalGridLineMask]
        tableView.style = .sourceList
        tableView.rowHeight = 50
        tableView.sizeLastColumnToFit()


        tableView.dataSource = self
        tableView.delegate = self
    }


    override func viewDidLayout() {
        super.viewDidLayout()
        // No need to manually resize columns when using sizeLastColumnToFit and proper constraints.
    }

    private func bindViewModel() {
        viewModel.$devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    @objc private func refreshDevices() {
        viewModel.refreshDevices()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModel.devices.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let device = viewModel.devices[row]
        let cellIdentifier = NSUserInterfaceItemIdentifier("DeviceCell")

        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? DeviceTableCellView

        if cell == nil {
            cell = DeviceTableCellView(frame: .zero)
            cell?.identifier = cellIdentifier
        }

        cell?.configure(with: device)

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < viewModel.devices.count else {
            viewModel.selectedDevice = nil
            Task {
                await viewModel.handleDeviceSelectionChange()
            }
            return
        }
        viewModel.selectedDevice = viewModel.devices[selectedRow]
        Task {
            await viewModel.handleDeviceSelectionChange()
        }
    }
}
