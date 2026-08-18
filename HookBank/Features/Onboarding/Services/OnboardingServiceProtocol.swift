import Foundation

protocol OnboardingServiceProtocol: Sendable {
    func fetchHooks() async throws -> [Hook]
}
