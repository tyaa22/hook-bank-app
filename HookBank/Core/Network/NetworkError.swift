import Foundation

public enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    case custom(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "The URL is invalid."
        case .invalidResponse: return "The server returned an invalid response."
        case .decodingError: return "Failed to decode the response."
        case .custom(let error): return error.localizedDescription
        }
    }
}
