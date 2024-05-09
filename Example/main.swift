import SwiftCbor

struct Coordinate: Codable {
    let latitude: Double
    let longitude: Double
}

struct Landmark: Codable {
    let name: String
    let foundingYear: Int
    let location: Coordinate
}

let input = Landmark(
    name: "Mojave Desert",
    foundingYear: 0,
    location: Coordinate(
        latitude: 35.0110079,
        longitude: -115.4821313
    )
)
let encoder = CborEncoder()
let decoder = CborDecoder()
let data = try! encoder.encode(input)
let out = try! decoder.decode(Landmark.self, from: data)

print([UInt8](data))
// [163, 100, 110, 97, 109, 101, 109, 77, 111, 106,
//  97, 118, 101, 32, 68, 101, 115, 101, 114, 116,
//  108, 102, 111, 117, 110, 100, 105, 110, 103, 89,
//  101, 97, 114, 0, 104, 108, 111, 99, 97, 116,
//  105, 111, 110, 162, 104, 108, 97, 116, 105, 116,
//  117, 100, 101, 251, 64, 65, 129, 104, 180, 245,
//  63, 179, 105, 108, 111, 110, 103, 105, 116, 117,
//  100, 101, 251, 192, 92, 222, 219, 61, 61, 120,
//  49]

print(out)
// Landmark(
//   name: "Mojave Desert",
//   foundingYear: 0,
//   location: example.Coordinate(
//     latitude: 35.0110079,
//     longitude: -115.4821313
//   )
// )
