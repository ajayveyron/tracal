import Foundation
@preconcurrency import Vision

public struct RecognizedNutritionText: Hashable, Sendable {
    public struct Line: Hashable, Sendable {
        public var text: String
        public var confidence: Float

        public init(text: String, confidence: Float) {
            self.text = text
            self.confidence = confidence
        }
    }

    public var lines: [Line]

    public init(lines: [Line]) {
        self.lines = lines
    }

    public var text: String {
        lines.map(\.text).joined(separator: "\n")
    }

    public var meanConfidence: Float {
        guard !lines.isEmpty else { return 0 }
        return lines.reduce(0) { $0 + $1.confidence } / Float(lines.count)
    }
}

/// Vision OCR remains fully on device. It is intentionally separate from the
/// nutrition parser so the raw recognized lines can be tested with fixtures.
public actor VisionNutritionLabelOCRService {
    public init() {}

    public func recognizeText(in imageData: Data) throws -> RecognizedNutritionText {
        guard !imageData.isEmpty else {
            throw MealAnalysisError.unreadableImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        request.minimumTextHeight = 0.012

        let handler = VNImageRequestHandler(data: imageData, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw MealAnalysisError.unreadableImage
        }

        let lines = (request.results ?? []).compactMap { observation -> RecognizedNutritionText.Line? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return RecognizedNutritionText.Line(text: text, confidence: candidate.confidence)
        }

        guard !lines.isEmpty else {
            throw MealAnalysisError.noNutritionDetected
        }

        return RecognizedNutritionText(lines: lines)
    }
}
