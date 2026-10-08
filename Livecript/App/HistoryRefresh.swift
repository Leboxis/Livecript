import Foundation
import Observation

/// Lets the history list refresh whenever a transcript may have changed:
/// switching to the tab, saving, renaming or deleting. Tab views are kept
/// alive, so a list built once goes stale as soon as another tab mutates data.
@Observable
final class HistoryRefresh {
    private(set) var generation = 0

    func bump() { generation += 1 }
}