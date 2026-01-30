import Foundation
import SwiftUI

// MARK: - Pagination Configuration

struct PaginationConfig {
    let pageSize: Int
    let prefetchThreshold: Int  // Load more when this many items from the end

    static let `default` = PaginationConfig(pageSize: 20, prefetchThreshold: 5)
    static let small = PaginationConfig(pageSize: 10, prefetchThreshold: 3)
    static let large = PaginationConfig(pageSize: 50, prefetchThreshold: 10)
}

// MARK: - Pagination State

@MainActor
class PaginationState<Item: Identifiable>: ObservableObject {
    @Published private(set) var displayedItems: [Item] = []
    @Published private(set) var hasMore: Bool = true
    @Published private(set) var isLoading: Bool = false

    private var allItems: [Item] = []
    private let config: PaginationConfig
    private var currentPage: Int = 0

    init(config: PaginationConfig = .default) {
        self.config = config
    }

    /// Reset with new data source
    func reset(with items: [Item]) {
        allItems = items
        currentPage = 0
        displayedItems = []
        hasMore = !items.isEmpty
        loadNextPage()
    }

    /// Load the next page of items
    func loadNextPage() {
        guard hasMore && !isLoading else { return }

        isLoading = true

        let startIndex = currentPage * config.pageSize
        let endIndex = min(startIndex + config.pageSize, allItems.count)

        if startIndex < allItems.count {
            let newItems = Array(allItems[startIndex..<endIndex])
            displayedItems.append(contentsOf: newItems)
            currentPage += 1
            hasMore = endIndex < allItems.count
        } else {
            hasMore = false
        }

        isLoading = false
    }

    /// Check if we should load more (called when item appears)
    func onItemAppear(_ item: Item) {
        guard hasMore && !isLoading else { return }

        if let index = displayedItems.firstIndex(where: { $0.id == item.id }) {
            let threshold = displayedItems.count - config.prefetchThreshold
            if index >= threshold {
                loadNextPage()
            }
        }
    }

    /// Get remaining items count
    var remainingCount: Int {
        allItems.count - displayedItems.count
    }

    /// Total items count
    var totalCount: Int {
        allItems.count
    }
}

// MARK: - Load More View

struct LoadMoreView: View {
    let remainingCount: Int
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.down.circle")
                }
                Text("Carica altri (\(remainingCount))")
                    .font(.subheadline)
            }
            .foregroundColor(.blue)
            .padding()
            .frame(maxWidth: .infinity)
        }
        .disabled(isLoading)
    }
}

// MARK: - Paginated List Modifier

struct PaginatedListModifier<Item: Identifiable>: ViewModifier {
    @ObservedObject var paginationState: PaginationState<Item>
    let item: Item

    func body(content: Content) -> some View {
        content
            .onAppear {
                paginationState.onItemAppear(item)
            }
    }
}

extension View {
    func paginated<Item: Identifiable>(
        state: PaginationState<Item>,
        item: Item
    ) -> some View {
        modifier(PaginatedListModifier(paginationState: state, item: item))
    }
}
