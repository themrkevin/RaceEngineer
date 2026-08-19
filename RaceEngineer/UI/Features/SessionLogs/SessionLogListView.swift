import SwiftUI
import Observation
import TelemetryKit

@MainActor
public struct SessionLogListView: View {
	@State private var viewModel: SessionLogListViewModel

	public init(viewModel: SessionLogListViewModel? = nil) {
		_viewModel = State(initialValue: viewModel ?? SessionLogListViewModel())
	}

	public var body: some View {
		NavigationStack {
			Group {
				if viewModel.isLoading {
					ProgressView("Loading sessions...")
				} else if let errorMessage = viewModel.errorMessage {
					ContentUnavailableView(
						"Sessions Unavailable",
						systemImage: "exclamationmark.triangle",
						description: Text(errorMessage)
					)
				} else if viewModel.sessions.isEmpty {
					ContentUnavailableView(
						"No Recorded Sessions",
						systemImage: "tray",
						description: Text("Recorded .race files will appear here.")
					)
				} else {
					List(viewModel.sessions) { session in
						NavigationLink {
							SessionDetailView(session: session)
						} label: {
							SessionSummaryCardView(session: session)
						}
					}
					.listStyle(.plain)
				}
			}
			.navigationTitle("Session Logs")
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						viewModel.reload()
					} label: {
						Image(systemName: "arrow.clockwise")
					}
					.disabled(viewModel.isLoading)
				}
			}
		}
		.task {
			viewModel.loadIfNeeded()
		}
	}
}

@MainActor
@Observable
public final class SessionLogListViewModel {
	public private(set) var sessions: [RecordedSessionSummary] = []
	public private(set) var isLoading = false
	public private(set) var errorMessage: String?

	private let library: RecordedSessionLibrary
	private var hasLoaded = false

	public init(directoryURL: URL? = nil) {
		let directory = directoryURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
		self.library = RecordedSessionLibrary(directoryURL: directory)
	}

	public func loadIfNeeded() {
		guard !hasLoaded else { return }
		reload()
	}

	public func reload() {
		hasLoaded = true
		isLoading = true
		errorMessage = nil

		Task { [weak self] in
			guard let self else { return }
			do {
				self.sessions = try await self.library.sessions()
			} catch {
				self.errorMessage = error.localizedDescription
			}
			self.isLoading = false
		}
	}
}

#Preview("Session Logs - Empty") {
	SessionLogListView(viewModel: SessionLogListViewModel(directoryURL: URL(fileURLWithPath: "/missing")))
}
