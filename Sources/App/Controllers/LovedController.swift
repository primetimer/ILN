import Vapor
import Fluent
import Authentication

struct LovedsController: RouteCollection {
  func boot(router: Router) throws {
    let lovedsRoutes = router.grouped("api", "loveds")
    lovedsRoutes.get(use: getAllHandler)
    lovedsRoutes.get(Loved.parameter, use: getHandler)
    lovedsRoutes.get("search", use: searchHandler)
    lovedsRoutes.get("first", use: getFirstHandler)
    lovedsRoutes.get("sorted", use: sortedHandler)
    lovedsRoutes.get(Loved.parameter, "user", use: getUserHandler)
    lovedsRoutes.get(Loved.parameter, "categories", use: getCategoriesHandler)

    let tokenAuthMiddleware = User.tokenAuthMiddleware()
    let guardAuthMiddleware = User.guardAuthMiddleware()
    let tokenAuthGroup = lovedsRoutes.grouped(tokenAuthMiddleware, guardAuthMiddleware)
    tokenAuthGroup.post(LovedCreateData.self, use: createHandler)
    tokenAuthGroup.put(Loved.parameter, use: updateHandler)
    tokenAuthGroup.delete(Loved.parameter, use: deleteHandler)
    tokenAuthGroup.post(Loved.parameter, "categories", Category.parameter, use: addCategoriesHandler)
    tokenAuthGroup.delete(Loved.parameter, "categories", Category.parameter, use: removeCategoriesHandler)
  }

  func getAllHandler(_ req: Request) throws -> Future<[Loved]> {
    return Loved.query(on: req).all()
  }

  func createHandler(_ req: Request, data: LovedCreateData) throws -> Future<Loved> {
    let user = try req.requireAuthenticated(User.self)
    let loved = try Loved(loved: data.loved, userID: user.requireID())
    return loved.save(on: req)
  }

  func getHandler(_ req: Request) throws -> Future<Loved> {
    return try req.parameters.next(Loved.self)
  }

  func updateHandler(_ req: Request) throws -> Future<Loved> {
    return try flatMap(to: Loved.self,
                       req.parameters.next(Loved.self),
                       req.content.decode(LovedCreateData.self)) { loved, updateData in
      loved.loved = updateData.loved
      let user = try req.requireAuthenticated(User.self)
      loved.userID = try user.requireID()
      return loved.save(on: req)
    }
  }

  func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
    return try req.parameters.next(Loved.self).delete(on: req).transform(to: .noContent)
  }

  func searchHandler(_ req: Request) throws -> Future<[Loved]> {
    guard let searchTerm = req.query[String.self, at: "term"] else {
      throw Abort(.badRequest)
    }
    return Loved.query(on: req).group(.or) { or in
      or.filter(\.loved, .ilike, searchTerm)
//      or.filter(\.long == searchTerm)
      }.all()
  }

  func getFirstHandler(_ req: Request) throws -> Future<Loved> {
    return Loved.query(on: req).first().unwrap(or: Abort(.notFound))
  }

  func sortedHandler(_ req: Request) throws -> Future<[Loved]> {
    return Loved.query(on: req).sort(\.loved, .ascending).all()
  }

  func getUserHandler(_ req: Request) throws -> Future<User.Public> {
    return try req.parameters.next(Loved.self).flatMap(to: User.Public.self) { loved in
      loved.user.get(on: req).convertToPublic()
    }
  }

  func addCategoriesHandler(_ req: Request) throws -> Future<HTTPStatus> {
    return try flatMap(to: HTTPStatus.self, req.parameters.next(Loved.self),
                       req.parameters.next(Category.self)) { loved, category in
      return loved.categories.attach(category, on: req).transform(to: .created)
    }
  }

  func getCategoriesHandler(_ req: Request) throws -> Future<[Category]> {
    return try req.parameters.next(Loved.self).flatMap(to: [Category].self) { loved in
      try loved.categories.query(on: req).all()
    }
  }

  func removeCategoriesHandler(_ req: Request) throws -> Future<HTTPStatus> {
    return try flatMap(to: HTTPStatus.self, req.parameters.next(Loved.self),
                       req.parameters.next(Category.self)) { loved, category in
      return loved.categories.detach(category, on: req).transform(to: .noContent)
    }
  }
}

struct LovedCreateData: Content {
  let loved: String
}
