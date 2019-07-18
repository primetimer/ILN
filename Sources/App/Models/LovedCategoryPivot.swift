import FluentPostgreSQL
import Foundation

final class LovedCategoryPivot: PostgreSQLUUIDPivot {

  var id: UUID?
  var lovedID: Loved.ID
  var categoryID: Category.ID

  typealias Left = Loved
  typealias Right = Category
  static let leftIDKey: LeftIDKey = \.lovedID
  static let rightIDKey: RightIDKey = \.categoryID

  init(_ loved: Loved, _ category: Category) throws {
    self.lovedID = try loved.requireID()
    self.categoryID = try category.requireID()
  }
}
extension LovedCategoryPivot: ModifiablePivot {}

extension LovedCategoryPivot: Migration {
  static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
    return Database.create(self, on: connection) { builder in
      try addProperties(to: builder)
      builder.reference(from: \.lovedID, to: \Loved.id, onDelete: .cascade)
      builder.reference(from: \.categoryID, to: \Category.id, onDelete: .cascade)
    }
  }
}
