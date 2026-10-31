import Foundation
import InfrastructureLocations
import Testing

@Suite struct LocationsTests {
    @Test func sandboxIsLaidOutLikeAHomeFolder() {
        let root = URL(fileURLWithPath: "/tmp/home")
        let locations = Locations.sandbox(root: root)
        #expect(locations.home == root)
        #expect(locations.applicationSupport.path == "/tmp/home/Library/Application Support")
        #expect(locations.applications.map(\.path) == ["/tmp/home/Applications"])
    }
}
