import Vapor
import Leaf
import Authentication
//import SendGrid

struct WebsiteController: RouteCollection {

  let imageFolder = "ProfilePictures/"

  func boot(router: Router) throws {
    let authSessionRoutes = router.grouped(User.authSessionsMiddleware())
    authSessionRoutes.get(use: indexHandler)
    authSessionRoutes.get("loveds", Loved.parameter, use: lovedHandler)
    authSessionRoutes.get("users", User.parameter, use: userHandler)
    authSessionRoutes.get("users", use: allUsersHandler)
    authSessionRoutes.get("categories", use: allCategoriesHandler)
    authSessionRoutes.get("categories", Category.parameter, use: categoryHandler)
    authSessionRoutes.get("login", use: loginHandler)
    authSessionRoutes.post(LoginPostData.self, at: "login", use: loginPostHandler)
    authSessionRoutes.post("logout", use: logoutHandler)
    authSessionRoutes.get("register", use: registerHandler)
    authSessionRoutes.post(RegisterData.self, at: "register", use: registerPostHandler)
//    authSessionRoutes.get("forgottenPassword", use: forgottenPasswordHandler)
//    authSessionRoutes.post("forgottenPassword", use: forgottenPasswordPostHandler)
//    authSessionRoutes.get("resetPassword", use: resetPasswordHandler)
//    authSessionRoutes.post(ResetPasswordData.self, at: "resetPassword", use: resetPasswordPostHandler)
//    authSessionRoutes.get("users", User.parameter, "profilePicture", use: getUsersProfilePictureHandler)

    let protectedRoutes = authSessionRoutes.grouped(RedirectMiddleware<User>(path: "/login"))
    protectedRoutes.get("loved", "create", use: createLovedHandler)
    protectedRoutes.post(CreateLovedData.self, at: "loved", "create", use: createLovedPostHandler)
    protectedRoutes.get("loved", Loved.parameter, "edit", use: editLovedHandler)
    protectedRoutes.post("loved", Loved.parameter, "edit", use: editLovedPostHandler)
    protectedRoutes.post("loved", Loved.parameter, "delete", use: deleteLovedHandler)
//    protectedRoutes.get("users", User.parameter, "addProfilePicture", use: addProfilePictureHandler)
//    protectedRoutes.post("users", User.parameter, "addProfilePicture", use: addProfilePicturePostHandler)
  }

  func indexHandler(_ req: Request) throws -> Future<View> {
    return Loved.query(on: req).all().flatMap(to: View.self) { loveds in
      let userLoggedIn = try req.isAuthenticated(User.self)
      let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
      let context = IndexContext(title: "Home page", loveds: loveds, userLoggedIn: userLoggedIn,
                                 showCookieMessage: showCookieMessage)
      return try req.view().render("index", context)
    }
  }

  func lovedHandler(_ req: Request) throws -> Future<View> {
    return try req.parameters.next(Loved.self).flatMap(to: View.self) { loved in
      return loved.user.get(on: req).flatMap(to: View.self) { user in
        let categories = try loved.categories.query(on: req).all()
        let context = LovedContext(title: loved.loved, loved: loved, user: user, categories: categories)
        return try req.view().render("loved", context)
      }
    }
  }

  func userHandler(_ req: Request) throws -> Future<View> {
    return try req.parameters.next(User.self).flatMap(to: View.self) { user in
      return try user.loveds.query(on: req).all().flatMap(to: View.self) { loveds in
        let loggedInUser = try req.authenticated(User.self)
        let context = UserContext(title: user.name, user: user, loveds: loveds, authenticatedUser: loggedInUser)
        return try req.view().render("user", context)
      }
    }
  }

  func allUsersHandler(_ req: Request) throws -> Future<View> {
    return User.query(on: req).all().flatMap(to: View.self) { users in
      let context = AllUsersContext(title: "All Users", users: users)
      return try req.view().render("allUsers", context)
    }
  }

  func allCategoriesHandler(_ req: Request) throws -> Future<View> {
    let categories = Category.query(on: req).all()
    let context = AllCategoriesContext(categories: categories)
    return try req.view().render("allCategories", context)
  }

  func categoryHandler(_ req: Request) throws -> Future<View> {
    return try req.parameters.next(Category.self).flatMap(to: View.self) { category in
      let loveds = try category.loveds.query(on: req).all()
      let context = CategoryContext(title: category.name, category: category, loveds: loveds)
      return try req.view().render("category", context)
    }
  }

  func createLovedHandler(_ req: Request) throws -> Future<View> {
    let token = try CryptoRandom().generateData(count: 16).base64EncodedString()
    let context = CreateLovedContext(csrfToken: token)
    try req.session()["CSRF_TOKEN"] = token
    return try req.view().render("createLoved", context)
  }

  func createLovedPostHandler(_ req: Request, data: CreateLovedData) throws -> Future<Response> {
    let expectedToken = try req.session()["CSRF_TOKEN"]
    try req.session()["CSRF_TOKEN"] = nil
    guard let csrfToken = data.csrfToken, expectedToken == csrfToken else {
      throw Abort(.badRequest)
    }
    let user = try req.requireAuthenticated(User.self)
    let loved = try Loved(loved: data.loved, userID: user.requireID())
    return loved.save(on: req).flatMap(to: Response.self) { loved in
      guard let id = loved.id else {
        throw Abort(.internalServerError)
      }
      var categorySaves: [Future<Void>] = []
      for category in data.categories ?? [] {
        try categorySaves.append(
          Category.addCategory(category, to: loved, on: req))
      }
      let redirect = req.redirect(to: "/loveds/\(id)")
      return categorySaves.flatten(on: req).transform(to: redirect)
    }
  }

  func editLovedHandler(_ req: Request) throws -> Future<View> {
    return try req.parameters.next(Loved.self).flatMap(to: View.self) { loved in
      let categories = try loved.categories.query(on: req).all()
      let context = EditLovedContext(loved: loved, categories: categories)
      return try req.view().render("createLoved", context)
    }
  }

  func editLovedPostHandler(_ req: Request) throws -> Future<Response> {
    return try flatMap(to: Response.self, req.parameters.next(Loved.self),
                       req.content.decode(CreateLovedData.self)) { loved, data in
      let user = try req.requireAuthenticated(User.self)
      loved.loved = data.loved
      loved.userID = try user.requireID()

      guard let id = loved.id else {
        throw Abort(.internalServerError)
      }

      return loved.save(on: req).flatMap(to: [Category].self) { _ in
        try loved.categories.query(on: req).all()
      }.flatMap(to: Response.self) { existingCategories in
        let existingStringArray = existingCategories.map { $0.name }

        let existingSet = Set<String>(existingStringArray)
        let newSet = Set<String>(data.categories ?? [])

        let categoriesToAdd = newSet.subtracting(existingSet)
        let categoriesToRemove = existingSet.subtracting(newSet)

        var categoryResults: [Future<Void>] = []
        for newCategory in categoriesToAdd {
          categoryResults.append(try Category.addCategory(newCategory, to: loved, on: req))
        }

        for categoryNameToRemove in categoriesToRemove {
          let categoryToRemove = existingCategories.first { $0.name == categoryNameToRemove }
          if let category = categoryToRemove {
            categoryResults.append(loved.categories.detach(category, on: req))
          }
        }

        let redirect = req.redirect(to: "/loveds/\(id)")
        return categoryResults.flatten(on: req).transform(to: redirect)
      }
    }
  }

  func deleteLovedHandler(_ req: Request) throws -> Future<Response> {
    return try req.parameters.next(Loved.self).delete(on: req).transform(to: req.redirect(to: "/"))
  }

  func loginHandler(_ req: Request) throws -> Future<View> {
    let context: LoginContext
    if req.query[Bool.self, at: "error"] != nil {
      context = LoginContext(loginError: true)
    } else {
      context = LoginContext()
    }
    return try req.view().render("login", context)
  }

  func loginPostHandler(_ req: Request, userData: LoginPostData) throws -> Future<Response> {
    return User.authenticate(username: userData.username, password: userData.password,
                             using: BCryptDigest(), on: req).map(to: Response.self) { user in
      guard let user = user else {
        return req.redirect(to: "/login?error")
      }
      try req.authenticateSession(user)
      return req.redirect(to: "/")
    }
  }

  func logoutHandler(_ req: Request) throws -> Response {
    try req.unauthenticateSession(User.self)
    return req.redirect(to: "/")
  }

  func registerHandler(_ req: Request) throws -> Future<View> {
    let context: RegisterContext
    if let message = req.query[String.self, at: "message"] {
      context = RegisterContext(message: message)
    } else {
      context = RegisterContext()
    }
    return try req.view().render("register", context)
  }

  func registerPostHandler(_ req: Request, data: RegisterData) throws -> Future<Response> {
    do {
      try data.validate()
    } catch (let error) {
      let redirect: String
      if let error = error as? ValidationError,
        let message = error.reason.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
        redirect = "/register?message=\(message)"
      } else {
        redirect = "/register?message=Unknown+error"
      }
      return req.future(req.redirect(to: redirect))
    }

    let password = try BCrypt.hash(data.password)
    let user = User(name: data.name, username: data.username, password: password, email: data.emailAddress)
    return user.save(on: req).map(to: Response.self) { user in
      try req.authenticateSession(user)
      return req.redirect(to: "/")
    }
  }

//  func forgottenPasswordHandler(_ req: Request) throws -> Future<View> {
//    return try req.view().render("forgottenPassword", ["title": "Reset Your Password"])
//  }
//
//  func forgottenPasswordPostHandler(_ req: Request) throws -> Future<View> {
//    let email = try req.content.syncGet(String.self, at: "email")
//    return User.query(on: req).filter(\.email == email).first().flatMap(to: View.self) { user in
//      guard let user = user else {
//        return try req.view().render("forgottenPasswordConfirmed", ["title": "Password Reset Email Sent"])
//      }
//
//      let resetTokenString = try CryptoRandom().generateData(count: 32).base32EncodedString()
//      let resetToken = try ResetPasswordToken(token: resetTokenString, userID: user.requireID())
//      return resetToken.save(on: req).flatMap(to: View.self) { _ in
//        let emailContent = """
//        <p>You've requested to reset your password. <a href=\"http://localhost:8080/resetPassword?token=\(resetTokenString)\">Click here</a> to reset your password.</p>
//        """
//        let emailAddress = EmailAddress(email: user.email, name: user.name)
//        let fromEmail = EmailAddress(email: "0xtimc@gmail.com", name: "Vapor TIL")
//        let emailConfig = Personalization(to: [emailAddress], subject: "Reset Your Password")
//        let email = SendGridEmail(personalizations: [emailConfig], from: fromEmail, content: [["type": "text/html",
//                                                                                               "value": emailContent]])
//        let sendGridClient = try req.make(SendGridClient.self)
//        return try sendGridClient.send([email], on: req.eventLoop).flatMap(to: View.self) { _ in
//          return try req.view().render("forgottenPasswordConfirmed", ["title": "Password Reset Email Sent"])
//        }
//      }
//    }
//  }

//  func resetPasswordHandler(_ req: Request) throws -> Future<View> {
//    guard let token = req.query[String.self, at: "token"] else {
//      return try req.view().render("resetPassword", ResetPasswordContext(error: true))
//    }
//    return ResetPasswordToken.query(on: req).filter(\.token == token).first().map(to: ResetPasswordToken.self) { token in
//      guard let token = token else {
//        throw Abort.redirect(to: "/")
//      }
//      return token
//    }.flatMap { token in
//      return token.user.get(on: req).flatMap { user in
//        try req.session().set("ResetPasswordUser", to: user)
//        return token.delete(on: req)
//      }
//    }.flatMap {
//      try req.view().render("resetPassword", ResetPasswordContext())
//    }
//  }

//  func resetPasswordPostHandler(_ req: Request, data: ResetPasswordData) throws -> Future<Response> {
//    guard data.password == data.confirmPassword else {
//      return try req.view().render("resetPassword", ResetPasswordContext(error: true)).encode(for: req)
//    }
//    let resetPasswordUser = try req.session().get("ResetPasswordUser", as: User.self)
//    try req.session()["ResetPasswordUser"] = nil
//    let newPassword = try BCrypt.hash(data.password)
//    resetPasswordUser.password = newPassword
//    return resetPasswordUser.save(on: req).transform(to: req.redirect(to: "/login"))
//  }
//
//  func addProfilePictureHandler(_ req: Request) throws -> Future<View> {
//    return try req.parameters.next(User.self).flatMap { user in
//      try req.view().render("addProfilePicture", ["title": "Add Profile Picture", "username": user.name])
//    }
//  }
//
//  func addProfilePicturePostHandler(_ req: Request) throws -> Future<Response> {
//    return try flatMap(to: Response.self, req.parameters.next(User.self), req.content.decode(ImageUploadData.self)) { user, imageData in
//      let workPath = try req.make(DirectoryConfig.self).workDir
//      let name = try "\(user.requireID())-\(UUID().uuidString).jpg"
//      let path = workPath + self.imageFolder + name
//      FileManager().createFile(atPath: path, contents: imageData.picture, attributes: nil)
//      user.profilePicture = name
//      let redirect = try req.redirect(to: "/users/\(user.requireID())")
//      return user.save(on: req).transform(to: redirect)
//    }
//  }
//
//  func getUsersProfilePictureHandler(_ req: Request) throws -> Future<Response> {
//    return try req.parameters.next(User.self).flatMap(to: Response.self) { user in
//      guard let filename = user.profilePicture else {
//        throw Abort(.notFound)
//      }
//      let path = try req.make(DirectoryConfig.self).workDir + self.imageFolder + filename
//      return try req.streamFile(at: path)
//    }
//  }
}

struct IndexContext: Encodable {
  let title: String
  let loveds: [Loved]
  let userLoggedIn: Bool
  let showCookieMessage: Bool
}

struct LovedContext: Encodable {
  let title: String
  let loved: Loved
  let user: User
  let categories: Future<[Category]>
}

struct UserContext: Encodable {
  let title: String
  let user: User
  let loveds: [Loved]
  let authenticatedUser: User?
}

struct AllUsersContext: Encodable {
  let title: String
  let users: [User]
}

struct AllCategoriesContext: Encodable {
  let title = "All Categories"
  let categories: Future<[Category]>
}

struct CategoryContext: Encodable {
  let title: String
  let category: Category
  let loveds: Future<[Loved]>
}

struct CreateLovedContext: Encodable {
  let title = "Create An Loved"
  let csrfToken: String
}

struct EditLovedContext: Encodable {
  let title = "Edit Loved"
  let loved: Loved
  let editing = true
  let categories: Future<[Category]>
}

struct CreateLovedData: Content {
  let loved: String
  let categories: [String]?
  let csrfToken: String?
}

struct LoginContext: Encodable {
  let title = "Log In"
  let loginError: Bool

  init(loginError: Bool = false) {
    self.loginError = loginError
  }
}

struct LoginPostData: Content {
  let username: String
  let password: String
}

struct RegisterContext: Encodable {
  let title = "Register"
  let message: String?

  init(message: String? = nil) {
    self.message = message
  }
}

struct RegisterData: Content {
  let name: String
  let username: String
  let password: String
  let confirmPassword: String
  let emailAddress: String
}

extension RegisterData: Validatable, Reflectable {
  static func validations() throws -> Validations<RegisterData> {
    var validations = Validations(RegisterData.self)
    try validations.add(\.name, .ascii)
    try validations.add(\.username, .alphanumeric && .count(3...))
    try validations.add(\.password, .count(8...))
    try validations.add(\.emailAddress, .email)
    validations.add("passwords match") { model in
      guard model.password == model.confirmPassword else {
        throw BasicValidationError("passwords don’t match")
      }
    }
    return validations
  }
}

struct ResetPasswordContext: Encodable {
  let title = "Reset Password"
  let error: Bool?

  init(error: Bool? = false) {
    self.error = error
  }
}

struct ResetPasswordData: Content {
  let password: String
  let confirmPassword: String
}

struct ImageUploadData: Content {
  var picture: Data
}
