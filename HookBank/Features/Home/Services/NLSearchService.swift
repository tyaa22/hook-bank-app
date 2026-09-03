import Foundation
import NaturalLanguage
import Core

/// Hybrid search over activities: literal keyword matching first, on-device semantic similarity
/// second. Both halves are needed — a sentence embedding dilutes a rare word like "spaghetti"
/// across a whole paragraph and ranks it near-randomly, while literal matching alone can't find
/// "ice breaker for new members" when no activity's text contains those exact words.
///
/// This runs entirely synchronously on whichever thread calls it — this app always calls it from
/// the main thread, so the vector cache below needs no locking, and there's no `LanguageModelSession`
/// involved: a real generation call is slow enough that this app's own PDF import needs a progress
/// UI for it, unsuitable for driving results on every keystroke.
class NLSearchService {
    static let shared = NLSearchService()

    private let embedding: NLEmbedding?

    /// Activity vectors, keyed by id. Embedding a full activity's text costs several milliseconds,
    /// and its content only changes when the hook is edited, so the vector is kept until the
    /// content hash stops matching. Without this, every keystroke re-embedded every activity from
    /// scratch.
    private var vectorCache: [UUID: (contentHash: Int, vector: [Double])] = [:]

    private init() {
        self.embedding = NLEmbedding.sentenceEmbedding(for: .english)
    }

    /// Calculates semantic similarity between a query and arbitrary text — an uncached one-off
    /// comparison, for callers that aren't ranking the activity list.
    func distance(for query: String, against text: String) -> Double {
        guard let embedding else { return 2.0 }
        return embedding.distance(between: query, and: text)
    }

    /// Ranks activities against the query, best match first.
    ///
    /// An activity whose known participant range excludes an explicit number in the query — "5
    /// people" against an activity that needs 8 to 12 — is demoted below every activity that could
    /// actually be played, no matter how well its name or goal happens to match on other words.
    /// That mismatch is a hard fact about the activity, not a matter of degree, so it can't be
    /// outweighed by an unrelated word coincidentally appearing in the activity's own name.
    ///
    /// Within the remaining activities, anything matching the query literally is ranked above
    /// anything matched only by meaning, because a hook that actually contains the typed word is
    /// nearly always the one being looked for.
    func search(query: String, activities: [Activity]) -> [Activity] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return activities }

        let (words, numbers) = tokenize(trimmed)
        let distances = semanticDistances(for: trimmed, activities: activities)
        forgetVectors(outside: activities)

        let threshold = 1.2
        var literalHits: [(activity: Activity, score: Int, distance: Double)] = []
        var semanticHits: [(activity: Activity, distance: Double)] = []
        var mismatchedHits: [(activity: Activity, score: Int, distance: Double)] = []

        for activity in activities {
            let distance = distances[activity.id] ?? .greatestFiniteMagnitude
            let score = literalScore(for: activity, words: words, numbers: numbers)
            if hasParticipantMismatch(activity, numbers: numbers) {
                mismatchedHits.append((activity, score, distance))
            } else if score > 0 {
                literalHits.append((activity, score, distance))
            } else if distance < threshold {
                semanticHits.append((activity, distance))
            }
        }

        // Strongest literal match wins; semantic distance only breaks ties between equal scores.
        literalHits.sort { $0.score != $1.score ? $0.score > $1.score : $0.distance < $1.distance }
        semanticHits.sort { $0.distance < $1.distance }
        mismatchedHits.sort { $0.score != $1.score ? $0.score > $1.score : $0.distance < $1.distance }

        let ranked = literalHits.map(\.activity) + semanticHits.map(\.activity) + mismatchedHits.map(\.activity)
        guard !ranked.isEmpty else {
            // Nothing matched at all: fall back to the closest guesses rather than an empty screen.
            return activities.sorted { (distances[$0.id] ?? 2) < (distances[$1.id] ?? 2) }
        }
        return ranked
    }

    // MARK: - Literal matching

    /// Connector words that would otherwise generate false-positive hits — "with" turning up in
    /// almost every `howToPlay` is what let an unrelated activity outrank a genuinely closer match.
    private static let stopwords: Set<String> = [
        "with", "and", "the", "a", "an", "for", "of", "in", "on", "at", "to", "by", "is", "are", "this", "that"
    ]

    /// Splits the query into searchable word tokens and standalone numbers, so "spaghetti and tape"
    /// can match a hook whose materials list both words, and "4 people" can match a participant
    /// count. Numbers are pulled out separately rather than dropped: a single-character token like
    /// "4" used to be discarded by a length filter, silently losing the most specific part of a
    /// query like "activities for 4 people".
    private func tokenize(_ query: String) -> (words: [String], numbers: [Int]) {
        let raw = query.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let numbers = raw.compactMap { Int($0) }
        let words = raw.filter { $0.count >= 2 && Int($0) == nil && !Self.stopwords.contains($0.lowercased()) }
        return (words, numbers)
    }

    /// Parses a `participants` string like "10-20", "4-6" or "20" into the range it describes.
    /// Returns `nil` for a placeholder like "-", which carries no participant-count information.
    private func participantRange(_ participants: String) -> ClosedRange<Int>? {
        let numbers = participants
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
        guard let lower = numbers.min(), let upper = numbers.max() else { return nil }
        return lower...upper
    }

    /// True when the query names a specific headcount and this activity's own participant range is
    /// known to exclude it — "5 people" against an activity that needs 8 to 12 can't be played as
    /// asked, regardless of how many other words happen to match.
    private func hasParticipantMismatch(_ activity: Activity, numbers: [Int]) -> Bool {
        guard !numbers.isEmpty, let range = participantRange(activity.participants) else { return false }
        return !numbers.contains(where: range.contains)
    }

    /// Sums how strongly the query hits this activity, weighted by how specific the match is.
    /// A number that falls inside the activity's participant range is the strongest signal —
    /// unlike a word match, it can't happen by coincidence — followed by a word appearing in the
    /// name, then in participants/properties, then in goal/howToPlay. `localizedStandardContains`
    /// is Apple's recommended comparison for user-facing search: case-insensitive,
    /// diacritic-insensitive and locale-aware.
    private func literalScore(for activity: Activity, words: [String], numbers: [Int]) -> Int {
        var total = 0

        if let range = participantRange(activity.participants) {
            total += numbers.filter(range.contains).count * 5
        }

        let properties = activity.possibleProperties.joined(separator: " ")
        for word in words {
            if activity.name.localizedStandardContains(word) {
                total += 3
            } else if activity.participants.localizedStandardContains(word)
                        || properties.localizedStandardContains(word) {
                total += 2
            } else if activity.goal.localizedStandardContains(word)
                        || activity.howToPlay.localizedStandardContains(word) {
                total += 1
            }
        }
        return total
    }

    // MARK: - Semantic matching (cached)

    private func semanticDistances(for query: String, activities: [Activity]) -> [UUID: Double] {
        guard let embedding, let queryVector = embedding.vector(for: query) else { return [:] }
        let queryNorm = norm(queryVector)
        guard queryNorm > 0 else { return [:] }

        var distances: [UUID: Double] = [:]
        distances.reserveCapacity(activities.count)
        for activity in activities {
            guard let vector = cachedVector(for: activity, using: embedding) else { continue }
            distances[activity.id] = distance(from: queryVector, norm: queryNorm, to: vector)
        }
        return distances
    }

    /// Every field goes into the embedded text on purpose, so meaning carried by any of them counts.
    private func embeddingText(for activity: Activity) -> String {
        "\(activity.name). Goal: \(activity.goal). Rules: \(activity.howToPlay). Properties: \(activity.possibleProperties.joined(separator: ", "))"
    }

    private func cachedVector(for activity: Activity, using embedding: NLEmbedding) -> [Double]? {
        let text = embeddingText(for: activity)
        let contentHash = text.hashValue
        if let cached = vectorCache[activity.id], cached.contentHash == contentHash {
            return cached.vector
        }
        guard let vector = embedding.vector(for: text) else { return nil }
        vectorCache[activity.id] = (contentHash, vector)
        return vector
    }

    /// Drops vectors for activities that no longer exist, so the cache can't grow without bound.
    private func forgetVectors(outside activities: [Activity]) {
        guard vectorCache.count > activities.count else { return }
        let live = Set(activities.map(\.id))
        vectorCache = vectorCache.filter { live.contains($0.key) }
    }

    /// Reproduces `NLEmbedding.distance(between:and:)` exactly from two already-computed vectors:
    /// that method returns the Euclidean distance between unit-normalised vectors, i.e.
    /// `sqrt(2 - 2 * cosineSimilarity)`. Computing it this way — instead of calling
    /// `embedding.distance(between:and:)`, which re-embeds both strings every time — is what lets
    /// the cached vector above actually save the embedding cost.
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
