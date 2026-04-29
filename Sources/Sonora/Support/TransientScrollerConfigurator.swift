import AppKit
import SwiftUI

struct TransientScrollerConfigurator: NSViewRepresentable {
  var hideDelay: TimeInterval = 1.1

  func makeCoordinator() -> Coordinator {
    Coordinator(hideDelay: hideDelay)
  }

  func makeNSView(context: Context) -> NSView {
    let view = NSView(frame: .zero)
    view.postsFrameChangedNotifications = false
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    DispatchQueue.main.async {
      context.coordinator.attachIfNeeded(to: nsView)
    }
  }

  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    coordinator.detach()
  }

  @MainActor
  final class Coordinator {
    private weak var scrollView: NSScrollView?
    private var observer: NSObjectProtocol?
    private var hideWorkItem: DispatchWorkItem?
    private let hideDelay: TimeInterval

    init(hideDelay: TimeInterval) {
      self.hideDelay = hideDelay
    }

    func attachIfNeeded(to view: NSView) {
      guard let scrollView = enclosingScrollView(from: view) else { return }
      guard self.scrollView !== scrollView else { return }

      detach()

      self.scrollView = scrollView
      scrollView.scrollerStyle = .overlay
      scrollView.autohidesScrollers = false
      scrollView.hasVerticalScroller = true
      scrollView.verticalScroller?.alphaValue = 0

      observer = NotificationCenter.default.addObserver(
        forName: NSView.boundsDidChangeNotification,
        object: scrollView.contentView,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor [weak self] in
          self?.showScrollerTemporarily()
        }
      }
    }

    func detach() {
      hideWorkItem?.cancel()
      hideWorkItem = nil

      if let observer {
        NotificationCenter.default.removeObserver(observer)
        self.observer = nil
      }

      scrollView?.verticalScroller?.animator().alphaValue = 0
      scrollView = nil
    }

    private func showScrollerTemporarily() {
      guard let scroller = scrollView?.verticalScroller else { return }

      scroller.animator().alphaValue = 1
      hideWorkItem?.cancel()

      let workItem = DispatchWorkItem { [weak scroller] in
        scroller?.animator().alphaValue = 0
      }

      hideWorkItem = workItem
      DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay, execute: workItem)
    }

    private func enclosingScrollView(from view: NSView) -> NSScrollView? {
      var currentView: NSView? = view

      while let candidate = currentView {
        if let scrollView = candidate as? NSScrollView {
          return scrollView
        }

        currentView = candidate.superview
      }

      return nil
    }
  }
}
