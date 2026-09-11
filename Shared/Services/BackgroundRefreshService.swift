import BackgroundTasks
import SwiftData
import WidgetKit

enum BackgroundRefreshService {
    static let taskIdentifier = "com.mfrankland.certwatch.refresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(refreshTask)
        }
    }

    static func scheduleNextRefresh() {
        guard AppSettings.isProUnlocked, AppSettings.backgroundRefreshEnabled else { return }

        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Calendar.current.date(byAdding: .hour, value: 24, to: .now)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask) {
        scheduleNextRefresh()

        final class RefreshTaskBox: @unchecked Sendable {
            let task: BGAppRefreshTask
            init(_ task: BGAppRefreshTask) { self.task = task }
        }

        let taskBox = RefreshTaskBox(task)
        let operation = Task {
            let success = await performRefresh()
            taskBox.task.setTaskCompleted(success: success)
        }

        task.expirationHandler = {
            operation.cancel()
        }
    }

    @MainActor
    private static func performRefresh() async -> Bool {
        do {
            let container = try ModelContainerFactory.makeContainer()
            let context = ModelContext(container)
            let store = EndpointStore(modelContext: context)
            await store.refreshAll()
            WidgetCenter.shared.reloadAllTimelines()
            return true
        } catch {
            return false
        }
    }
}
