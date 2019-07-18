import Vapor
import Crypto

struct UsersController: RouteCollection {
  func boot(router: Router) throws {
    let usersRoute = router.grouped("api", "users")
    usersRoute.get(use: getAllHandler)
    usersRoute.get(User.parameter, use: getHandler)
    usersRoute.get(User.parameter, "loveds", use: getLovedsHandler)

    let basicAuthMiddleware = User.basicAuthMiddleware(using: BCryptDigest())
    let basicAuthGroup = usersRoute.grouped(basicAuthMiddleware)
    basicAuthGroup.post("login", use: loginHandler)

    let tokenAuthMiddleware = User.tokenAuthMiddleware()
    let guardAuthMiddleware = User.guardAuthMiddleware()
    let tokenAuthGroup = usersRoute.grouped(tokenAuthMiddleware, guardAuthMiddleware)
    tokenAuthGroup.post(User.self, use: createHandler)
  }

  func createHandler(_ req: Request, user: User) throws -> Future<User.Public> {
    user.password = try BCrypt.hash(user.password)
    return user.save(on: req).convertToPublic()
  }

  func getAllHandler(_ req: Request) throws -> Future<[User.Public]> {
    return User.query(on: req).decode(data: User.Public.self).all()
  }

  func getHandler(_ req: Request) throws -> Future<User.Public> {
    return try req.parameters.next(User.self).convertToPublic()
  }

  func getLovedsHandler(_ req: Request) throws -> Future<[Loved]> {
    return try req.parameters.next(User.self).flatMap(to: [Loved].self) { user in
      try user.loveds.query(on: req).all()
    }
  }

  func loginHandler(_ req: Request) throws -> Future<Token> {
    let user = try req.requireAuthenticated(User.self)
    let token = try Token.generate(for: user)
    return token.save(on: req)
  }
}
