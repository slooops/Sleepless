import AppKit
import Foundation
import IOKit.pwr_mgt

// MARK: - Sleepless Menu Bar App
// A lightweight menu bar utility that prevents your Mac from sleeping.
// Uses IOPMAssertion (the native macOS power management API) — no subprocess needed.
// App Store compatible: works fully within the app sandbox.

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var assertionID: IOPMAssertionID = IOPMAssertionID(0)
    private var hasAssertion = false
    private var timer: Timer?
    private var remainingSeconds: Int = 0
    private var isActive = false

    // Menu items we need to update
    private var toggleItem: NSMenuItem!
    private var timerDisplayItem: NSMenuItem!
    private var durationItems: [NSMenuItem] = []
    private var selectedDuration: Int? = nil // nil = infinite

    private let durations: [(label: String, seconds: Int?)] = [
        ("Infinite", nil),
        ("30 minutes", 1800),
        ("1 hour", 3600),
        ("2 hours", 7200),
        ("4 hours", 14400),
        ("8 hours", 28800),
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()
        buildMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        deactivate()
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()

        // Status / toggle
        toggleItem = NSMenuItem(title: "Start Keeping Awake", action: #selector(toggle), keyEquivalent: "s")
        toggleItem.target = self
        menu.addItem(toggleItem)

        // Timer display (hidden when inactive)
        timerDisplayItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        timerDisplayItem.isHidden = true
        menu.addItem(timerDisplayItem)

        menu.addItem(NSMenuItem.separator())

        // Duration picker
        let durationHeader = NSMenuItem(title: "Duration:", action: nil, keyEquivalent: "")
        durationHeader.isEnabled = false
        menu.addItem(durationHeader)

        for (index, duration) in durations.enumerated() {
            let item = NSMenuItem(title: duration.label, action: #selector(selectDuration(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = (index == 0) ? .on : .off
            durationItems.append(item)
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Sleepless", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func toggle() {
        if isActive {
            deactivate()
        } else {
            activate()
        }
    }

    @objc private func selectDuration(_ sender: NSMenuItem) {
        let index = sender.tag
        selectedDuration = durations[index].seconds

        for item in durationItems {
            item.state = .off
        }
        sender.state = .on

        // If already active, restart with new duration
        if isActive {
            deactivate()
            activate()
        }
    }

    @objc private func quitApp() {
        deactivate()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Power Assertion (IOPMAssertion API)
    //
    // This is the same API that `caffeinate` uses internally.
    // It tells macOS "don't sleep" without needing to spawn a subprocess,
    // which means it works inside the App Store sandbox.

    private func activate() {
        guard !hasAssertion else { return }

        let reason = "Sleepless: User requested keep-awake" as CFString

        // PreventUserIdleDisplaySleep also prevents idle system sleep.
        // This is equivalent to `caffeinate -di`.
        let status = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )

        guard status == kIOReturnSuccess else {
            print("Failed to create power assertion: \(status)")
            return
        }

        hasAssertion = true
        isActive = true

        if let seconds = selectedDuration {
            remainingSeconds = seconds
            startCountdownTimer()
        }

        updateIcon()
        updateMenuState()
    }

    private func deactivate() {
        timer?.invalidate()
        timer = nil

        if hasAssertion {
            IOPMAssertionRelease(assertionID)
            hasAssertion = false
        }

        isActive = false
        remainingSeconds = 0
        updateIcon()
        updateMenuState()
    }

    // MARK: - Timer

    private func startCountdownTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remainingSeconds -= 1
            self.updateTimerDisplay()
            self.updateIcon()

            if self.remainingSeconds <= 0 {
                self.deactivate()
            }
        }
    }

    // MARK: - UI Updates

    private func updateIcon() {
        guard let button = statusItem.button else { return }

        if isActive {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            if let img = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: "Sleepless active") {
                button.image = img.withSymbolConfiguration(config) ?? img
            } else {
                button.title = "ZZ"
            }

            if selectedDuration != nil && remainingSeconds > 0 {
                button.title = " \(formatTime(remainingSeconds))"
                button.imagePosition = .imageLeading
            } else {
                button.title = ""
                button.imagePosition = .imageOnly
            }
        } else {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            if let img = NSImage(systemSymbolName: "moon.zzz", accessibilityDescription: "Sleepless inactive") {
                button.image = img.withSymbolConfiguration(config) ?? img
            } else {
                button.title = "zzz"
            }
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }

    private func updateMenuState() {
        if isActive {
            toggleItem.title = "Stop Keeping Awake"
            if selectedDuration == nil {
                timerDisplayItem.title = "Running indefinitely"
                timerDisplayItem.isHidden = false
            } else {
                updateTimerDisplay()
                timerDisplayItem.isHidden = false
            }
        } else {
            toggleItem.title = "Start Keeping Awake"
            timerDisplayItem.isHidden = true
        }
    }

    private func updateTimerDisplay() {
        if remainingSeconds > 0 {
            timerDisplayItem.title = "\(formatTime(remainingSeconds)) remaining"
        } else {
            timerDisplayItem.title = "Finished"
        }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Entry Point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
