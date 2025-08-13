import SwiftUI
import CoreLocation

// MARK: - Models

struct RockNewsItem: Identifiable, Codable, Equatable {
	let id: String
	let title: String
	let snippet: String
	let url: URL
	let imageURL: URL?
	let source: String
	let publishedAt: Date
}

// Minimal Bing News response types
private struct BingNewsResponse: Decodable { let value: [BingNewsItem] }
private struct BingNewsItem: Decodable {
	let name: String
	let url: String
	let description: String?
	let datePublished: String
	let provider: [BingProvider]?
	let image: BingImageWrapper?
}
private struct BingProvider: Decodable { let name: String? }
private struct BingImageWrapper: Decodable { let thumbnail: BingThumb? }
private struct BingThumb: Decodable { let contentUrl: String? }

// MARK: - Location helper

final class RFLocation: NSObject, ObservableObject, CLLocationManagerDelegate {
	@Published var coord: CLLocationCoordinate2D?
	@Published var suburb: String?
	@Published var city: String?
	@Published var state: String?

	private let mgr = CLLocationManager()
	private let geocoder = CLGeocoder()

	override init() {
		super.init()
		mgr.delegate = self
	}

	func start() {
		if CLLocationManager.authorizationStatus() == .notDetermined {
			mgr.requestWhenInUseAuthorization()
		}
		mgr.desiredAccuracy = kCLLocationAccuracyKilometer
		mgr.startUpdatingLocation()
	}

	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		guard let loc = locations.last else { return }
		self.coord = loc.coordinate
		geocoder.reverseGeocodeLocation(loc) { [weak self] p, _ in
			guard let pm = p?.first else { return }
			// In AU, subLocality is often the suburb
			self?.suburb = pm.subLocality ?? pm.locality
			self?.city = pm.locality
			self?.state = pm.administrativeArea
		}
		manager.stopUpdatingLocation()
	}

	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		print("Location failed: \(error)")
	}
}

// MARK: - Simple disk cache (1-hour TTL)

private struct CacheEnvelope<T: Codable>: Codable {
	let timestamp: Date
	let payload: T
}

final class RFNewsCache {
	private let fileURL: URL
	private let ttl: TimeInterval = 3600 // 1 hour

	init(filename: String = "rock_fishing_news_cache.json") {
		let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		self.fileURL = base.appendingPathComponent(filename)
	}

	func loadIfFresh() -> [RockNewsItem]? {
		guard let data = try? Data(contentsOf: fileURL),
				let env = try? JSONDecoder().decode(CacheEnvelope<[RockNewsItem]>.self, from: data)
		else { return nil }
		if Date().timeIntervalSince(env.timestamp) <= ttl {
			return env.payload
		}
		return nil
	}

	func save(_ items: [RockNewsItem]) {
		let env = CacheEnvelope(timestamp: Date(), payload: items)
		if let data = try? JSONEncoder().encode(env) {
			try? data.write(to: fileURL, options: .atomic)
		}
	}
}

// MARK: - Service (Azure AI Services → Bing News on your endpoint)

final class RockFishingNewsService {
	// Put these in Info.plist (or fetch from your backend)
	// Keys: RF_AZURE_AI_ENDPOINT, RF_AZURE_AI_KEY
	private let endpoint: String = {
		let env = ProcessInfo.processInfo.environment
		let candidates: [String?] = [
			env["RF_AZURE_AI_ENDPOINT"],
			env["AZURE_COGNITIVE_ENDPOINT"],
			env["BING_ENDPOINT"],
			Bundle.main.object(forInfoDictionaryKey: "RF_AZURE_AI_ENDPOINT") as? String
		]
		let trimmed = candidates.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
		return trimmed.first(where: { !$0.isEmpty }) ?? ""
	}()
	private let key: String = {
		let env = ProcessInfo.processInfo.environment
		let candidates: [String?] = [
			env["RF_AZURE_AI_KEY"],
			env["AZURE_COGNITIVE_KEY"],
			env["BING_SEARCH_V7_SUBSCRIPTION_KEY"],
			Bundle.main.object(forInfoDictionaryKey: "RF_AZURE_AI_KEY") as? String
		]
		let trimmed = candidates.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
		return trimmed.first(where: { !$0.isEmpty }) ?? ""
	}()

	private let cache = RFNewsCache()
	private let isoWithFrac: ISO8601DateFormatter = {
		let f = ISO8601DateFormatter()
		f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		return f
	}()
	private let isoBasic = ISO8601DateFormatter()

	enum ServiceError: Error { case config, request, http(Int), decode, empty }

	/// Fetch top 10 rock-fishing relevant news from last 30 days, localised by suburb/city/state.
	func fetch(localSuburb: String?, city: String?, state: String?) async throws -> [RockNewsItem] {
		if let fresh = cache.loadIfFresh(), !fresh.isEmpty { return fresh }

		guard !endpoint.isEmpty, !key.isEmpty else {
			#if DEBUG
			let eLen = endpoint.count
			let kLen = key.count
			print("Azure config missing: endpointLen=\(eLen) keyLen=\(kLen). Set RF_AZURE_AI_ENDPOINT and RF_AZURE_AI_KEY (env or Info.plist).")
			#endif
			throw ServiceError.config
		}

		// Build locality hint (best effort). Bing News doesn’t accept a radius, so we steer with keywords.
		let locTerms = [localSuburb, city, state].compactMap { $0 }.filter { !$0.isEmpty }
		let locationHint = locTerms.joined(separator: " ")

		// Rock-fishing emphasised query (Australia focus)
		let rockTerms = [
			"\"rock fishing\"", "rockfishing", "\"rock fisherman\"", "\"rock platform\"",
			"swell", "lifejacket", "PFD", "angel ring"
		].joined(separator: " OR ")

		// AU-only results via site + market
		let q = "\(rockTerms) \(locationHint) site:au"

		// Construct endpoint: {your-resource}.cognitiveservices.azure.com/bing/v7.0/news/search
		guard var comps = URLComponents(string: endpoint) else { throw ServiceError.request }
		// Ensure trailing slash handling
		var base = comps.url?.absoluteString ?? endpoint
		if !base.hasSuffix("/") { base += "/" }
		let urlString = base + "bing/v7.0/news/search"

		var searchComps = URLComponents(string: urlString)
		searchComps?.queryItems = [
			URLQueryItem(name: "q", value: q),
			URLQueryItem(name: "mkt", value: "en-AU"),
			URLQueryItem(name: "count", value: "50"),
			URLQueryItem(name: "sortBy", value: "Date"),
			URLQueryItem(name: "originalImg", value: "true")
		]

		guard let url = searchComps?.url else { throw ServiceError.request }

		var req = URLRequest(url: url)
		req.httpMethod = "GET"
		req.setValue(key, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")

		let (data, resp) = try await URLSession.shared.data(for: req)
		if let http = resp as? HTTPURLResponse, http.statusCode >= 300 {
			throw ServiceError.http(http.statusCode)
		}

		let decoded = try JSONDecoder().decode(BingNewsResponse.self, from: data)

		// Keep only last 30 days
		let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
		var items: [RockNewsItem] = []

		for v in decoded.value {
			let published = isoWithFrac.date(from: v.datePublished)
				?? isoBasic.date(from: v.datePublished)
				?? .distantPast
			guard published >= cutoff else { continue }

			guard let link = URL(string: v.url) else { continue }
			let img = URL(string: v.image?.thumbnail?.contentUrl ?? "")
			let src = v.provider?.first?.name ?? "Source"
			let snippet = v.description ?? ""

			items.append(
				RockNewsItem(
					id: link.absoluteString,
					title: v.name,
					snippet: snippet,
					url: link,
					imageURL: img,
					source: src,
					publishedAt: published
				)
			)
		}

		// De-dupe by URL
		let deduped = Array(Dictionary(grouping: items, by: { $0.url.absoluteString }).values.compactMap { $0.first })

		// Score for rock-fishing relevance (title weighted) + freshness + image presence
		func score(_ it: RockNewsItem) -> Double {
			let t = it.title.lowercased()
			let s = (it.title + " " + it.snippet).lowercased()
			let kwsTitle = ["rock fishing","rockfishing","rock fisherman","rock platform","lifejacket","pfd","angel ring","swell"]
				.reduce(0) { $0 + (t.contains($1) ? 1 : 0) }
			let kwsText  = ["rock fishing","rockfishing","rock fisherman","rock platform","lifejacket","pfd","angel ring","swell"]
				.reduce(0) { $0 + (s.contains($1) ? 1 : 0) }
			let freshness = max(0, 1.0 - Date().timeIntervalSince(it.publishedAt) / (30*24*3600)) // 0..1
			let pic = it.imageURL != nil ? 0.2 : 0.0
			return Double(kwsTitle) * 3.0 + Double(kwsText) * 1.5 + freshness + pic
		}

		let top10 = deduped
			.map { (score($0), $0) }
			.sorted { $0.0 > $1.0 }
			.map { $0.1 }
			.prefix(10)

		let result = Array(top10)
		if !result.isEmpty { cache.save(result) }
		return result
	}
}

// MARK: - SwiftUI view (place this above other providers)

struct RockFishingNewsSection: View {
	@StateObject private var loc = RFLocation()
	@State private var news: [RockNewsItem] = []
	@State private var loading = true
	@State private var err: String?

	private let service = RockFishingNewsService()

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				Text("Rock Fishing — Local News")
					.font(.title3).bold()
				Spacer()
				Button {
					Task { await reload(force: true) }
				} label: { Image(systemName: "arrow.clockwise") }
			}

			if loading { ProgressView("Loading…").padding(.vertical, 6) }
			if let err { Text(err).foregroundColor(.red).font(.footnote) }

			ForEach(news) { item in
				Link(destination: item.url) {
					HStack(alignment: .top, spacing: 12) {
						AsyncImage(url: item.imageURL) { phase in
							switch phase {
							case .success(let img): img.resizable().scaledToFill()
							case .failure: Color.gray.opacity(0.15)
							case .empty: ProgressView()
							@unknown default: Color.gray.opacity(0.15)
							}
						}
						.frame(width: 76, height: 76).clipped().cornerRadius(10)

						VStack(alignment: .leading, spacing: 6) {
							Text(item.title).font(.headline).lineLimit(2)
							Text(item.snippet).font(.subheadline).foregroundColor(.secondary).lineLimit(3)
							HStack(spacing: 6) {
								Text(item.source)
								Text("•")
								Text(item.publishedAt, style: .date)
							}.font(.caption).foregroundColor(.secondary)
						}
						Spacer(minLength: 0)
					}
					.padding(10)
					.background(Color(.secondarySystemBackground))
					.cornerRadius(12)
				}
			}

			if news.isEmpty && !loading && err == nil {
				Text("No rock-fishing news in the last 30 days for your area.")
					.font(.footnote).foregroundColor(.secondary)
			}
		}
		.onAppear { loc.start(); Task { await reload(force: false) } }
		.padding()
	}

	private func reload(force: Bool) async {
		loading = true; err = nil
		// give reverse-geocode a moment
		try? await Task.sleep(nanoseconds: 600_000_000)
		do {
			let list = try await service.fetch(
				localSuburb: loc.suburb,
				city: loc.city ?? "Sydney",
				state: loc.state ?? "NSW"
			)
			news = list
		} catch {
			err = "Couldn’t load news (\(error))"
		}
		loading = false
	}
}


