import XCTest
import GLLinkExtensionKit
import GLLinkExtensionTesting

/// The package itself, run in GL-Link's runtime against a fake BatteryBridge.
@MainActor
final class GlassyBatteryTests: XCTestCase {
    static let package = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("GlassyBattery.ext")

    /// A BatteryBridge that hands out a new token on each registration, and has custom icons
    /// or not.
    static func bridge(icons: Bool) -> FakeNetwork {
        let registrations = Counter()
        return FakeNetwork(http: { request in
            switch (request.httpMethod, request.url?.path ?? "") {
            case (_, "/v1/health"): return (200, #"{"api":1,"app":"GlassyBattery","version":"test"}"#)
            case ("POST", "/v1/register"):
                return (201, #"{"clientID":"c1","status":"active","token":"gbb_\#(registrations.next())"}"#)
            case ("PUT", let path) where path.hasPrefix("/v1/icons/") && icons:
                return (200, #"{"icon":{"name":"x","format":"svg","bytes":1}}"#)
            default: return (404, #"{"error":{"code":"no_such_route","message":"Unknown endpoint"}}"#)
            }
        }, reply: { message in
            switch message["op"] as? String {
            case "hello": [#"{"event":"ready","client":{}}"#]
            case "upsert": [#"{"event":"ack","ref":"\#(message["ref"] ?? "")"}"#]
            default: []
            }
        })
    }

    static func routers() -> (FakeContext, UUID) {
        let mudi = UUID()
        let context = FakeContext()
        context.routers = [
            RouterInfo(id: mudi, name: "Mudi 7",
                       model: RouterModel(id: "e5800", code: "GL-E5800", name: "Mudi 7", symbol: "router.e5800"),
                       battery: BatteryReading(level: 85, charging: true), updated: Date()),
            RouterInfo(id: UUID(), name: "Home",
                       model: RouterModel(id: "be14000", code: "GL-BE14000", name: "Flint 4", symbol: "router.be14000"),
                       battery: nil, updated: Date()),
        ]
        return (context, mudi)
    }

    static func upserts(_ socket: FakeSocket) -> [[String: Any]] {
        socket.sent.filter { $0["op"] as? String == "upsert" }.compactMap { $0["device"] as? [String: Any] }
    }

    func testListsRoutersWithTheirModelsIcon() async throws {
        let network = Self.bridge(icons: true)
        let (context, mudi) = Self.routers()
        let ext = ScriptExtension(package: try ExtensionPackage(at: Self.package), context: context, network: network)
        ext.start()

        try await eventually("the router sent with its icon") {
            network.sockets.first.map { Self.upserts($0).contains { $0["customIcon"] != nil } } == true
        }
        let socket = try XCTUnwrap(network.sockets.first)
        XCTAssertEqual(socket.sent[0]["op"] as? String, "hello")
        XCTAssertEqual(socket.sent[0]["token"] as? String, "gbb_1")
        XCTAssertEqual(socket.sent[0]["onDisconnect"] as? String, "remove")
        XCTAssertEqual(context.secrets["token"], "gbb_1")

        // The model's icon, uploaded once, from the package: a plain SVG.
        let puts = network.requests.filter { $0.httpMethod == "PUT" }
        XCTAssertEqual(puts.map { $0.url?.path }, ["/v1/icons/router.e5800"], "only the router with a battery")
        XCTAssertEqual(puts.first?.value(forHTTPHeaderField: "Authorization"), "Bearer gbb_1")
        let body = try JSONSerialization.jsonObject(with: try XCTUnwrap(puts.first?.httpBody)) as? [String: String]
        XCTAssertEqual(body?["format"], "svg")
        let svg = String(decoding: try XCTUnwrap(Data(base64Encoded: body?["data"] ?? "")), as: UTF8.self)
        XCTAssertTrue(svg.hasPrefix("<svg"), "the glyph alone, not the symbol template")

        let device = try XCTUnwrap(Self.upserts(socket).last)
        XCTAssertEqual(device["id"] as? String, mudi.uuidString)
        XCTAssertEqual(device["name"] as? String, "Mudi 7")
        XCTAssertEqual(device["type"] as? String, "generic")
        XCTAssertEqual(device["icon"] as? String, "wifi.router.fill")
        XCTAssertEqual(device["customIcon"] as? String, "router.e5800")
        XCTAssertEqual(device["level"] as? Int, 85)
        XCTAssertEqual(device["charging"] as? Bool, true)
        XCTAssertEqual(device["model"] as? String, "GL-E5800")
        XCTAssertTrue(Self.upserts(socket).allSatisfy { $0["id"] as? String == mudi.uuidString }, "the Flint has no battery")
        try await eventually("the status") { ext.status == "Showing Mudi 7 in GlassyBattery." }
        XCTAssertEqual(ext.rows, [.init(title: "Mudi 7", value: "85% ⚡︎")])
        XCTAssertEqual(ext.actions.map(\.id), ["reset"])

        // A new reading goes out; an unchanged one doesn't.
        let before = Self.upserts(socket).count
        context.routers[0].battery = BatteryReading(level: 84, charging: false)
        ext.routersChanged()
        ext.routersChanged()
        try await eventually("the new level") { Self.upserts(socket).count == before + 1 }
        XCTAssertEqual(Self.upserts(socket).last?["level"] as? Int, 84)

        // Called something else: the model's name goes with its code.
        context.routers[0].name = "Travel"
        ext.routersChanged()
        try await eventually("the renamed router") { Self.upserts(socket).last?["name"] as? String == "Travel" }
        XCTAssertEqual(Self.upserts(socket).last?["model"] as? String, "Mudi 7 · GL-E5800")

        // Unpaired: taken out.
        context.routers.removeFirst()
        ext.routersChanged()
        try await eventually("the removal") { socket.sent.last?["op"] as? String == "remove" }
        XCTAssertEqual(socket.sent.last?["id"] as? String, mudi.uuidString)

        // Turned off: the stream closes, which takes everything out of GlassyBattery.
        ext.stop()
        XCTAssertTrue(socket.isClosed)
        XCTAssertEqual(ext.actions, [])
    }

    func testAGlassyBatteryWithoutCustomIconsGetsTheSymbol() async throws {
        let network = Self.bridge(icons: false)
        let (context, _) = Self.routers()
        let ext = ScriptExtension(package: try ExtensionPackage(at: Self.package), context: context, network: network)
        ext.start()
        try await eventually("the router sent") { network.sockets.first.map { !Self.upserts($0).isEmpty } == true }
        let device = try XCTUnwrap(network.sockets.first.flatMap { Self.upserts($0).last })
        XCTAssertEqual(device["icon"] as? String, "wifi.router.fill")
        XCTAssertNil(device["customIcon"])
        ext.stop()
    }

    func testResetConnectionSignsInAgain() async throws {
        let network = Self.bridge(icons: true)
        let (context, mudi) = Self.routers()
        let ext = ScriptExtension(package: try ExtensionPackage(at: Self.package), context: context, network: network)
        ext.start()
        try await eventually("connected") { network.sockets.first.map { !Self.upserts($0).isEmpty } == true }
        let first = try XCTUnwrap(network.sockets.first)
        let reset = try XCTUnwrap(ext.actions.first { $0.id == "reset" })
        XCTAssertNotNil(reset.confirm, "it asks first")

        ext.perform(reset)
        try await eventually("a second connection") {
            network.sockets.count == 2 && Self.upserts(network.sockets[1]).contains { $0["customIcon"] != nil }
        }
        XCTAssertTrue(first.isClosed, "the old stream is closed")
        let second = network.sockets[1]
        XCTAssertEqual(second.sent[0]["token"] as? String, "gbb_2", "a new token")
        XCTAssertEqual(context.secrets["token"], "gbb_2")
        XCTAssertEqual(Self.upserts(second).last?["id"] as? String, mudi.uuidString)
        XCTAssertEqual(network.requests.filter { $0.httpMethod == "PUT" }.count, 2, "the icon uploaded again")
        // The old socket closing doesn't end the new connection.
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(network.sockets.count, 2)
        XCTAssertFalse(second.isClosed)
        ext.stop()
    }
}


final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    func next() -> Int { lock.withLock { n += 1; return n } }
}
