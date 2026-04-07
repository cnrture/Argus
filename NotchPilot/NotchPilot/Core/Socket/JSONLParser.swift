import Foundation

struct JSONLParser {
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    static func parse<T: Decodable>(_ line: String, as type: T.Type) throws -> T {
        guard let data = line.data(using: .utf8) else {
            throw JSONLError.invalidEncoding
        }
        return try decoder.decode(type, from: data)
    }

    static func encode<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw JSONLError.invalidEncoding
        }
        return string
    }
}

enum JSONLError: Error {
    case invalidEncoding
    case invalidJSON
}
