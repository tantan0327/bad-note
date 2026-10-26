import Foundation
import OSLog
import SwiftUI

/// A logger for the BadNote module.
let logger: Logger = Logger(subsystem: "com.tange.badnote", category: "BadNote")

/// アプリの最上位のビュー。両プラットフォームの App デリゲートから読み込まれる。
///
/// **テンプレートのログ文言は消した**(2026-10-27)。
/// 起動のたびにコンソールへ 1 行出るだけだが、出荷するバイナリに
/// Skip の説明文が残っているのは筋が悪い。
public struct BadNoteRootView : View {
    public init() {
    }

    public var body: some View {
        ContentView()
    }
}

/// Global application delegate functions.
///
/// These functions can update a shared observable object to communicate app state changes to interested views.
public final class BadNoteAppDelegate : Sendable {
    public static let shared = BadNoteAppDelegate()

    private init() {
    }

    public func onInit() {
        logger.debug("onInit")
    }

    public func onLaunch() {
        logger.debug("onLaunch")
    }

    public func onResume() {
        logger.debug("onResume")
    }

    public func onPause() {
        logger.debug("onPause")
    }

    public func onStop() {
        logger.debug("onStop")
    }

    public func onDestroy() {
        logger.debug("onDestroy")
    }

    public func onLowMemory() {
        logger.debug("onLowMemory")
    }
}
