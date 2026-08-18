import Foundation

final class OnboardingService: OnboardingServiceProtocol {
    
    func fetchHooks() async throws -> [Hook] {
        guard let url = URL(string: "https://jsonplaceholder.typicode.com/posts") else {
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
        
        do {
            return try JSONDecoder().decode([Hook].self, from: data)
        } catch {
            throw NetworkError.decodingError
        }
    }
}
