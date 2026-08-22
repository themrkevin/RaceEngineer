import SwiftUI
import TelemetryKit

public struct SessionSummaryCardView: View {
	public let session: RecordedSessionSummary

	public init(session: RecordedSessionSummary) {
		self.session = session
	}

	public var body: some View {
		HStack(spacing: 12) {
			Image(systemName: "steeringwheel")
				.font(.title3)
				.foregroundStyle(TelemetryColors.steering)
				.frame(width: 34, height: 34)
				.background(TelemetryColors.surfaceSecondary)
				.clipShape(RoundedRectangle(cornerRadius: 6))

			VStack(alignment: .leading, spacing: 4) {
				Text(session.fileName)
					.font(TelemetryTypography.secondaryValue)
					.foregroundStyle(TelemetryColors.brightText)
					.lineLimit(1)

				Text(session.creationDate, style: .date)
					.font(TelemetryTypography.unit)
					.foregroundStyle(TelemetryColors.mutedText)
			}

			Spacer()

			VStack(alignment: .trailing, spacing: 4) {
				Text(session.formattedDuration)
					.font(TelemetryTypography.secondaryValue)
					.foregroundStyle(TelemetryColors.brightText)
					.telemetryMonospacedDigits()

				Text(session.formattedFileSize)
					.font(TelemetryTypography.unit)
					.foregroundStyle(TelemetryColors.mutedText)
			}
		}
		.padding(.vertical, 6)
	}
}
