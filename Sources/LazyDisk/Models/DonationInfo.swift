import SwiftUI

struct DonationNetwork: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let address: String
    let icon: String
    let accent: Color
    let gradient: [Color]

    static let all: [DonationNetwork] = [
        DonationNetwork(
            id: "tron",
            name: "TRON",
            symbol: "TRC-20",
            address: "TAcW3UvfPF95Higtyjo133rAAx51Ru8VhB",
            icon: "bolt.circle.fill",
            accent: Color(red: 0.92, green: 0.0, blue: 0.16),
            gradient: [Color(red: 1.0, green: 0.22, blue: 0.28), Color(red: 0.85, green: 0.0, blue: 0.12)]
        ),
        DonationNetwork(
            id: "polygon",
            name: "Polygon",
            symbol: "MATIC",
            address: "0xF8Ebe674D471cBc5fF9924bE85829090364F4318",
            icon: "hexagon.fill",
            accent: Color(red: 0.51, green: 0.28, blue: 0.9),
            gradient: [Color(red: 0.62, green: 0.35, blue: 1.0), Color(red: 0.45, green: 0.18, blue: 0.78)]
        ),
        DonationNetwork(
            id: "ethereum",
            name: "Ethereum",
            symbol: "ETH",
            address: "0xF8Ebe674D471cBc5fF9924bE85829090364F4318",
            icon: "diamond.fill",
            accent: Color(red: 0.38, green: 0.49, blue: 0.92),
            gradient: [Color(red: 0.45, green: 0.58, blue: 1.0), Color(red: 0.28, green: 0.35, blue: 0.75)]
        ),
        DonationNetwork(
            id: "bitcoin",
            name: "Bitcoin",
            symbol: "BTC",
            address: "0xF8Ebe674D471cBc5fF9924bE85829090364F4318",
            icon: "bitcoinsign.circle.fill",
            accent: Color(red: 0.95, green: 0.58, blue: 0.12),
            gradient: [Color(red: 1.0, green: 0.72, blue: 0.2), Color(red: 0.9, green: 0.45, blue: 0.05)]
        ),
    ]
}
