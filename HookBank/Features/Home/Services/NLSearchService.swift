import Foundation
import NaturalLanguage
import Core

/// Hybrid search over activities: literal keyword matching first, on-device semantic similarity second.
///
/// Both halves are needed. Literal matching is what finds a material name or a participant count —
/// a sentence embedding dilutes a rare word like "spaghetti" across a whole paragraph and ranks it
/// near-randomly. Semantic matching is what finds "ice breaker for new members", which no literal
/// search can reach.
///
/// This is an `actor` for two reasons. First, `NLEmbedding` is not safe for concurrent use — Apple
/// documents that calling its query methods from several tasks at once can crash the app — and actor
/// isolation serialises every access for us. Second, embedding text is genuinely slow (~15 ms per
/// activity), so this work must stay off the main thread.
actor NLSearchService {
    static let shared = NLSearchService()

    /// One activity reduced to plain `Sendable` data, so SwiftData models never cross into the actor.
    /// Fields stay separate so literal matches can be weighted by where they hit.
    struct Candidate: Sendable {
        let id: UUID
        let name: String
        let participants: String
        let goal: String
        let howToPlay: String
        let properties: [String]
    }

    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)

    /// Activity vectors, keyed by id. Embedding an activity costs ~15 ms and its text only changes
    /// when the hook is edited, so the vector is kept until the content hash stops matching.
    /// Without this, every keystroke re-embedded every activity from scratch.
    private var cache: [UUID: (contentHash: Int, vector: [Double])] = [:]

    /// Ranks candidates against the query, best match first.
    ///
    /// Anything matching the query literally is ranked above anything matched only by meaning,
    /// because a hook that actually contains the typed word is nearly always the one being looked for.
    /// Semantic distances reproduce `NLEmbedding.distance(between:and:)` exactly — that method returns
    /// the Euclidean distance between unit-normalised vectors, i.e. `sqrt(2 - 2 * cosineSimilarity)` —
    /// so `threshold` keeps the meaning it had before this type cached anything.
    func rank(query: String, candidates: [Candidate], threshold: Double = 1.2) -> [UUID] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return candidates.map(\.id) }

        let tokens = tokenize(trimmed)
        let distances = semanticDistances(for: trimmed, candidates: candidates)
        forgetVectors(outside: candidates)

        var literalHits: [(id: UUID, score: Int, distance: Double)] = []
        var semanticHits: [(id: UUID, distance: Double)] = []

        for candidate in candidates {
            let distance = distances[candidate.id] ?? .greatestFiniteMagnitude
            let score = literalScore(for: candidate, tokens: tokens)
            if score > 0 {
                literalHits.append((candidate.id, score, distance))
            } else if distance < threshold {
                semanticHits.append((candidate.id, distance))
            }
        }

        // Strongest literal match wins; semantic distance only breaks ties between equal scores.
        literalHits.sort { $0.score != $1.score ? $0.score > $1.score : $0.distance < $1.distance }
        semanticHits.sort { $0.distance < $1.distance }

        let ranked = literalHits.map(\.id) + semanticHits.map(\.id)
        guard ranked.isEmpty else { return ranked }

        // Nothing matched either way: fall back to the closest guesses rather than an empty screen.
        return distances
            .sorted { $0.value < $1.value }
            .map(\.key)
    }

    // MARK: - Literal matching

    /// Splits the query into searchable tokens, so "spaghetti and tape" can match a hook whose
    /// materials list both words without containing that exact phrase.
    private func tokenize(_ query: String) -> [String] {
        let tokens = query
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }
        return tokens.isEmpty ? [query] : tokens
    }

    /// Sums how strongly each token hits, weighted by the field it was found in.
    /// `localizedStandardContains` is Apple's recommended comparison for user-facing search:
    /// case-insensitive, diacritic-insensitive and locale-aware.
    private func literalScore(for candidate: Candidate, tokens: [String]) -> Int {
        let properties = candidate.properties.joined(separator: " ")
        return tokens.reduce(into: 0) { total, token in
            if candidate.name.localizedStandardContains(token) {
                total += 3
            } else if candidate.participants.localizedStandardContains(token)
                        || properties.localizedStandardContains(token) {
                total += 2
            } else if candidate.goal.localizedStandardContains(token)
                        || candidate.howToPlay.localizedStandardContains(token) {
                total += 1
            }
        }
    }

    // MARK: - Semantic matching

    private func semanticDistances(for query: String, candidates: [Candidate]) -> [UUID: Double] {
        guard let embedding,
              let queryVector = embedding.vector(for: query)
        else { return [:] }

        let queryNorm = norm(queryVector)
        guard queryNorm > 0 else { return [:] }

        var distances: [UUID: Double] = [:]
        distances.reserveCapacity(candidates.count)
        for candidate in candidates {
            guard let vector = vector(for: candidate, using: embedding) else { continue }
            distances[candidate.id] = distance(from: queryVector, norm: queryNorm, to: vector)
        }
        return distances
    }

    /// Every field goes into the embedded text on purpose, so meaning carried by any of them counts.
    private func embeddingText(for candidate: Candidate) -> String {
        "\(candidate.name). Goal: \(candidate.goal). Rules: \(candidate.howToPlay). Properties: \(candidate.properties.joined(separator: ", "))"
    }

    private func vector(for candidate: Candidate, using embedding: NLEmbedding) -> [Double]? {
        let text = embeddingText(for: candidate)
        let contentHash = text.hashValue
        if let cached = cache[candidate.id], cached.contentHash == contentHash {
            return cached.vector
        }
        guard let vector = embedding.vector(for: text) else { return nil }
        cache[candidate.id] = (contentHash, vector)
        return vector
    }

    /// Drops vectors for activities that no longer exist, so the cache can't grow without bound.
    private func forgetVectors(outside candidates: [Candidate]) {
        guard cache.count > candidates.count else { return }
        let live = Set(candidates.map(\.id))
        cache = cache.filter { live.contains($0.key) }
    }

    private func norm(_ vector: [Double]) -> Double {
        vector.reduce(0) { $0 + $1 * $1 }.squareRoot()
    }

    private func distance(from query: [Double], norm queryNorm: Double, to vector: [Double]) -> Double {
        let vectorNorm = norm(vector)
        guard vectorNorm > 0 else { return 2 }

        var dot = 0.0
        for index in 0..<min(query.count, vector.count) {
            dot += query[index] * vector[index]
        }
        let similarity = dot / (queryNorm * vectorNorm)
        return max(0, 2 - 2 * similarity).squareRoot()
    }
}

// MARK: - Building candidates

extension NLSearchService.Candidate {
    @MainActor
    init(_ activity: Activity) {
        self.init(
            id: activity.id,
            name: activity.name,
            participants: activity.participants,
            goal: activity.goal,
            howToPlay: activity.howToPlay,
            properties: activity.possibleProperties
        )
    }
}
