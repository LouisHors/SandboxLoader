import AppKit
import Combine

class FileBrowserViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var viewModel: ContentViewModel!
    private var cancellables = Set<AnyCancellable>()

    // UI Components
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let backButton = NSButton(image: NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")!, target: nil, action: nil)
    private let pathLabel = NSTextField(labelWithString: "")
    private let downloadButton = NSButton(image: NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "Download")!, target: nil, action: nil)
    private let toAppListButton = NSButton(image: NSImage(systemSymbolName: "square.grid.3x3", accessibilityDescription: "Back to App List")!, target: nil, action: nil)

    override func loadView() {
        self.view = NSView()
        setupUI()
    }

    private func setupUI() {
        // --- Header ---
        let headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        headerView.layer?.borderWidth = 1.0
        headerView.layer?.borderColor = NSColor.separatorColor.cgColor


        backButton.target = self
        backButton.action = #selector(navigateBack)
        backButton.bezelStyle = .texturedRounded
        downloadButton.target = self
        downloadButton.action = #selector(downloadSelected)
        downloadButton.bezelStyle = .texturedRounded
        toAppListButton.target = self
        toAppListButton.action = #selector(backToAppList)
        toAppListButton.bezelStyle = .texturedRounded

        pathLabel.font = .systemFont(ofSize: 14, weight: .medium)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingTail
        pathLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)


        let headerStack = NSStackView(views: [toAppListButton, backButton, pathLabel, NSView(), downloadButton])
        headerStack.orientation = .horizontal
        headerStack.spacing = 12
        headerStack.alignment = .centerY
        headerStack.distribution = .fill
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(headerStack)

        // --- Table View ---
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let mainStack = NSStackView(views: [headerView, scrollView])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 0
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)

        NSLayoutConstraint.activate([
            headerStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
            headerStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -12),
            headerStack.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 50),

            mainStack.topAnchor.constraint(equalTo: view.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.widthAnchor.constraint(equalTo: mainStack.widthAnchor)
        ])

        // --- Table Column Setup ---
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("NameColumn"))
        nameColumn.title = "Name"
        nameColumn.width = 300

        let sizeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SizeColumn"))
        sizeColumn.title = "Size"
        sizeColumn.minWidth = 100
        sizeColumn.maxWidth = 200


        tableView.addTableColumn(nameColumn)
        tableView.addTableColumn(sizeColumn)
        tableView.headerView = NSTableHeaderView()
        tableView.backgroundColor = .white
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.gridStyleMask = [.solidVerticalGridLineMask, .solidHorizontalGridLineMask]
        tableView.style = .inset
        tableView.rowHeight = 40
        tableView.sizeLastColumnToFit()
        tableView.allowsMultipleSelection = true
        tableView.doubleAction = #selector(tableViewDoubleClicked)

        tableView.dataSource = self
        tableView.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
    }

    private func bindViewModel() {
        viewModel.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.tableView.reloadData() }
            .store(in: &cancellables)

        viewModel.$currentPath
            .map { $0 as String? ?? "" }
            .receive(on: DispatchQueue.main)
            .assign(to: \.stringValue, on: pathLabel)
            .store(in: &cancellables)

        viewModel.$pathStack
            .map { $0.count > 1 }
            .receive(on: DispatchQueue.main)
            .assign(to: \.isEnabled, on: backButton)
            .store(in: &cancellables)

        viewModel.$selectedItems
             .map { !$0.isEmpty }
             .receive(on: DispatchQueue.main)
             .assign(to: \.isEnabled, on: downloadButton)
             .store(in: &cancellables)
    }

    // MARK: - Actions
    @objc private func navigateBack() {
        viewModel.navigateBack()
    }

    @objc private func downloadSelected() {
        viewModel.downloadSelectedFile()
    }

    @objc private func backToAppList() {
        viewModel.selectedApp = nil
    }

    @objc private func tableViewDoubleClicked() {
        guard tableView.clickedRow >= 0 else { return }
        let item = viewModel.items[tableView.clickedRow]
        viewModel.navigateTo(item: item)
    }

    // MARK: - NSTableViewDataSource & Delegate
    func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModel.items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn else { return nil }

        let item = viewModel.items[row]
        let cellIdentifier = NSUserInterfaceItemIdentifier(column.identifier.rawValue + "Cell")

        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView

        if column.identifier.rawValue == "NameColumn" {
            if cell == nil {
                cell = NSTableCellView()
                let imageView = NSImageView()
                let textField = NSTextField(string: "")
                textField.isBezeled = false
                textField.drawsBackground = false
                textField.isEditable = false
                textField.font = .systemFont(ofSize: 14)

                cell?.imageView = imageView
                cell?.textField = textField

                let stack = NSStackView(views: [imageView, textField])
                stack.orientation = .horizontal
                stack.spacing = 10
                stack.translatesAutoresizingMaskIntoConstraints = false

                cell?.addSubview(stack)
                NSLayoutConstraint.activate([
                    stack.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 8),
                    stack.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -8),
                    stack.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
                ])
            }

            cell?.textField?.stringValue = item.name
            let iconName = item.type == .directory ? "folder.fill" : "doc.text.fill"
            cell?.imageView?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: iconName)
            cell?.imageView?.contentTintColor = item.type == .directory ? NSColor(calibratedRed: 0.2, green: 0.6, blue: 0.9, alpha: 1.0) : .secondaryLabelColor

        } else if column.identifier.rawValue == "SizeColumn" {
            if cell == nil {
                cell = NSTableCellView()
                let textField = NSTextField(string: "")
                textField.isBezeled = false
                textField.drawsBackground = false
                textField.isEditable = false
                textField.font = .systemFont(ofSize: 14)
                textField.textColor = .secondaryLabelColor
                textField.alignment = .right

                cell?.textField = textField
                cell?.addSubview(textField)

                textField.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                    textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -8),
                    textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
                ])
            }
            cell?.textField?.stringValue = item.type == .file ? formatBytes(item.size) : "--"
        }

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedIDs = tableView.selectedRowIndexes.map { viewModel.items[$0].id }
        viewModel.selectedItems = Set(selectedIDs)
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
