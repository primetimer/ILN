import Vapor
import FluentPostgreSQL

final class Loved: Codable {
  var id: Int?
  var loved: String
  var userID: User.ID

  init(loved: String, userID: User.ID) {
    self.loved = loved
    self.userID = userID
  }
}

extension Loved: PostgreSQLModel {}
extension Loved: Content {}
extension Loved: Parameter {}

extension Loved {
  var user: Parent<Loved, User> {
    return parent(\.userID)
  }

  var categories: Siblings<Loved, Category, LovedCategoryPivot> {
    return siblings()
  }
}

extension Loved: Migration {
  static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
    return Database.create(self, on: connection) { builder in
      try addProperties(to: builder)
      builder.reference(from: \.userID, to: \User.id)
    }
  }
}
