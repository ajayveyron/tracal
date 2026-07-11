import Foundation

enum MealLogLaunchMode: String, CaseIterable, Hashable, Sendable {
    case text
    case camera
    case gallery

    static let scheme = "tracal"
    static let host = "log"

    init?(url: URL) {
        guard
            url.scheme?.lowercased() == Self.scheme,
            url.host?.lowercased() == Self.host,
            let value = url.pathComponents.last,
            value != "/",
            let mode = Self(rawValue: value.lowercased())
        else {
            return nil
        }
        self = mode
    }

    var deepLinkURL: URL {
        URL(string: "\(Self.scheme)://\(Self.host)/\(rawValue)")!
    }
}
