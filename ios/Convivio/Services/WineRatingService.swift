import Foundation
import SwiftData

// MARK: - Wine Rating Service

actor WineRatingService {
    static let shared = WineRatingService()

    private init() {}

    // MARK: - Quick Rating Operations

    func fetchQuickRatings(for wineId: UUID, context: ModelContext) -> [QuickRating] {
        let descriptor = FetchDescriptor<QuickRating>(
            predicate: #Predicate { $0.wineId == wineId },
            sortBy: [SortDescriptor(\.dataAssaggio, order: .reverse)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("Error fetching quick ratings: \(error)")
            return []
        }
    }

    func fetchAllQuickRatings(context: ModelContext) -> [QuickRating] {
        let descriptor = FetchDescriptor<QuickRating>(
            sortBy: [SortDescriptor(\.dataAssaggio, order: .reverse)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("Error fetching all quick ratings: \(error)")
            return []
        }
    }

    func averageRating(for wineId: UUID, context: ModelContext) -> Double? {
        let ratings = fetchQuickRatings(for: wineId, context: context)
        guard !ratings.isEmpty else { return nil }
        let sum = ratings.reduce(0.0) { $0 + $1.rating }
        return sum / Double(ratings.count)
    }

    func saveQuickRating(_ rating: QuickRating, context: ModelContext) throws {
        context.insert(rating)
        try context.save()
    }

    func deleteQuickRating(_ rating: QuickRating, context: ModelContext) throws {
        context.delete(rating)
        try context.save()
    }

    // MARK: - Scheda AIS Operations

    func fetchSchedeAIS(for wineId: UUID, context: ModelContext) -> [SchedaAIS] {
        let descriptor = FetchDescriptor<SchedaAIS>(
            predicate: #Predicate { $0.wineId == wineId },
            sortBy: [SortDescriptor(\.dataAssaggio, order: .reverse)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("Error fetching AIS schede: \(error)")
            return []
        }
    }

    func fetchAllSchedeAIS(context: ModelContext) -> [SchedaAIS] {
        let descriptor = FetchDescriptor<SchedaAIS>(
            sortBy: [SortDescriptor(\.dataAssaggio, order: .reverse)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("Error fetching all AIS schede: \(error)")
            return []
        }
    }

    func latestSchedaAIS(for wineId: UUID, context: ModelContext) -> SchedaAIS? {
        fetchSchedeAIS(for: wineId, context: context).first
    }

    func hasSchedaAIS(for wineId: UUID, context: ModelContext) -> Bool {
        !fetchSchedeAIS(for: wineId, context: context).isEmpty
    }

    func saveSchedaAIS(_ scheda: SchedaAIS, context: ModelContext) throws {
        context.insert(scheda)
        try context.save()
    }

    func deleteSchedaAIS(_ scheda: SchedaAIS, context: ModelContext) throws {
        context.delete(scheda)
        try context.save()
    }

    // MARK: - Statistics

    struct WineRatingStats {
        let wineId: UUID
        let quickRatingCount: Int
        let aisSchedaCount: Int
        let averageQuickRating: Double?
        let averageAISScore: Int?
        let latestRatingDate: Date?
        let wouldBuyAgainPercentage: Double?
    }

    func stats(for wineId: UUID, context: ModelContext) -> WineRatingStats {
        let quickRatings = fetchQuickRatings(for: wineId, context: context)
        let aisSchede = fetchSchedeAIS(for: wineId, context: context)

        let avgQuick: Double? = quickRatings.isEmpty ? nil :
            quickRatings.reduce(0.0) { $0 + $1.rating } / Double(quickRatings.count)

        let avgAIS: Int? = aisSchede.isEmpty ? nil :
            aisSchede.reduce(0) { $0 + $1.punteggioTotale } / aisSchede.count

        let latestDate = [
            quickRatings.first?.dataAssaggio,
            aisSchede.first?.dataAssaggio
        ].compactMap { $0 }.max()

        let buyAgainResponses = quickRatings.compactMap { $0.loRicomprerei }
        let wouldBuyAgain: Double? = buyAgainResponses.isEmpty ? nil :
            Double(buyAgainResponses.filter { $0 }.count) / Double(buyAgainResponses.count) * 100

        return WineRatingStats(
            wineId: wineId,
            quickRatingCount: quickRatings.count,
            aisSchedaCount: aisSchede.count,
            averageQuickRating: avgQuick,
            averageAISScore: avgAIS,
            latestRatingDate: latestDate,
            wouldBuyAgainPercentage: wouldBuyAgain
        )
    }

    // MARK: - Top Rated Wines

    struct TopRatedWine {
        let wineId: UUID
        let averageRating: Double
        let ratingCount: Int
    }

    func topRatedWines(context: ModelContext, limit: Int = 10) -> [TopRatedWine] {
        let allRatings = fetchAllQuickRatings(context: context)

        // Group by wine
        var byWine: [UUID: [QuickRating]] = [:]
        for rating in allRatings {
            byWine[rating.wineId, default: []].append(rating)
        }

        // Calculate averages and sort
        let topWines = byWine.map { wineId, ratings in
            let avg = ratings.reduce(0.0) { $0 + $1.rating } / Double(ratings.count)
            return TopRatedWine(wineId: wineId, averageRating: avg, ratingCount: ratings.count)
        }
        .filter { $0.ratingCount >= 1 } // At least 1 rating
        .sorted { $0.averageRating > $1.averageRating }
        .prefix(limit)

        return Array(topWines)
    }

    // MARK: - Rating Trends

    struct RatingTrend {
        let month: Date
        let averageRating: Double
        let count: Int
    }

    func ratingTrends(for wineId: UUID?, context: ModelContext, months: Int = 6) -> [RatingTrend] {
        let calendar = Calendar.current
        let now = Date()

        var trends: [RatingTrend] = []

        for monthOffset in 0..<months {
            guard let monthStart = calendar.date(byAdding: .month, value: -monthOffset, to: now),
                  let monthEnd = calendar.date(byAdding: .month, value: -(monthOffset - 1), to: now) else {
                continue
            }

            let allRatings = fetchAllQuickRatings(context: context)
            let monthRatings = allRatings.filter { rating in
                let matchesWine = wineId == nil || rating.wineId == wineId
                let inRange = rating.dataAssaggio >= monthStart && rating.dataAssaggio < monthEnd
                return matchesWine && inRange
            }

            if !monthRatings.isEmpty {
                let avg = monthRatings.reduce(0.0) { $0 + $1.rating } / Double(monthRatings.count)
                trends.append(RatingTrend(
                    month: monthStart,
                    averageRating: avg,
                    count: monthRatings.count
                ))
            }
        }

        return trends.reversed()
    }
}

// MARK: - Wine Extension for Ratings

extension Wine {
    func averageQuickRating(context: ModelContext) async -> Double? {
        await WineRatingService.shared.averageRating(for: stableUUID, context: context)
    }

    func hasAISScheda(context: ModelContext) async -> Bool {
        await WineRatingService.shared.hasSchedaAIS(for: stableUUID, context: context)
    }

    func ratingStats(context: ModelContext) async -> WineRatingService.WineRatingStats {
        await WineRatingService.shared.stats(for: stableUUID, context: context)
    }
}
