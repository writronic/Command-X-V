import Cocoa
import os.log

@MainActor
class SettingsViewController: NSSplitViewController {

    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "SettingsViewController")

    private let sidebarViewController = SettingsSidebarViewController()
    private let generalViewController = GeneralSettingsViewController()
    private let shortcutViewController = ShortcutSettingsViewController()
    private let aboutViewController = AboutViewController()

    private var detailItem: NSSplitViewItem!

    var onHideMenuBarRequested: ((@escaping (Bool) -> Void) -> Void)? {
        didSet {
            shortcutViewController.onHideMenuBarRequested = onHideMenuBarRequested
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
        sidebarItem.minimumThickness = SettingsLayout.sidebarWidth
        sidebarItem.maximumThickness = SettingsLayout.sidebarWidth
        sidebarItem.canCollapse = false
        addSplitViewItem(sidebarItem)

        detailItem = NSSplitViewItem(viewController: generalViewController)
        detailItem.minimumThickness = SettingsLayout.detailWidth
        addSplitViewItem(detailItem)

        sidebarViewController.onSelectionChanged = { [weak self] index in
            self?.switchToTab(index)
        }

        splitView.dividerStyle = .thin
        splitView.isVertical = true

        logger.info("Settings split view loaded")
    }

    private func switchToTab(_ index: Int) {
        removeSplitViewItem(detailItem)

        let targetVC: NSViewController
        switch index {
        case 0:
            targetVC = generalViewController
        case 1:
            targetVC = shortcutViewController
        case 2:
            targetVC = aboutViewController
        default:
            targetVC = generalViewController
        }

        detailItem = NSSplitViewItem(viewController: targetVC)
        detailItem.minimumThickness = SettingsLayout.detailWidth
        addSplitViewItem(detailItem)

        if let window = view.window {
            let origin = window.frame.origin
            window.setFrame(NSRect(x: origin.x, y: origin.y,
                                   width: SettingsLayout.windowWidth,
                                   height: SettingsLayout.windowHeight),
                            display: true)
        }

        logger.debug("Switched to settings tab: \(index)")
    }
}


@MainActor
class SettingsSidebarViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "SettingsSidebar")

    private var tableView: NSTableView!

    var onSelectionChanged: ((Int) -> Void)?

    private struct SidebarItem {
        let title: String
        let iconName: String
    }

    private let items: [SidebarItem] = [
        SidebarItem(title: "General", iconName: "gear"),
        SidebarItem(title: "Shortcuts", iconName: "command"),
        SidebarItem(title: "About", iconName: "info.circle")
    ]

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: SettingsLayout.sidebarWidth, height: SettingsLayout.contentHeight))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
    }

    private func setupTableView() {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.borderType = .noBorder
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        tableView = NSTableView()
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.rowHeight = 32
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
        tableView.style = .sourceList
        tableView.dataSource = self
        tableView.delegate = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SidebarColumn"))
        column.isEditable = false
        tableView.addTableColumn(column)

        scrollView.documentView = tableView

        DispatchQueue.main.async { [weak self] in
            self?.tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }


    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }


    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("SidebarCell")

        var cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView

        if cellView == nil {
            cellView = NSTableCellView()
            cellView?.identifier = identifier

            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.setContentHuggingPriority(.required, for: .horizontal)
            cellView?.addSubview(imageView)
            cellView?.imageView = imageView

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.font = NSFont.systemFont(ofSize: 13)
            textField.lineBreakMode = .byTruncatingTail
            cellView?.addSubview(textField)
            cellView?.textField = textField

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 4),
                imageView.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 18),
                imageView.heightAnchor.constraint(equalToConstant: 18),

                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])
        }

        let item = items[row]
        cellView?.textField?.stringValue = item.title
        cellView?.imageView?.image = NSImage(systemSymbolName: item.iconName, accessibilityDescription: item.title)
        cellView?.imageView?.contentTintColor = .secondaryLabelColor

        return cellView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 else { return }
        onSelectionChanged?(selectedRow)
    }
}
