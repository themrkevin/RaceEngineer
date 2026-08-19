import SwiftUI
import TelemetryKit

public struct SessionDetailView: View {
	public let session: RecordedSessionSummary

	public init(session: RecordedSessionSummary) {
		self.session = session
	}

	public var body: some View {
		Form {
			Section("Recording") {
				LabeledContent("File", value: session.fileName)
				LabeledContent("Duration", value: session.formattedDuration)
				LabeledContent("Frames", value: "\(session.totalFrames)")
				LabeledContent("Size", value: session.formattedFileSize)
			}

			Section {
				Button {
					// Playback wiring belongs in the next feature slice.
				} label: {
					Label("Review Session", systemImage: "play.fill")
				}
				.disabled(session.totalFrames == 0)
			}
		}
		.navigationTitle("Session Details")
	}
}
