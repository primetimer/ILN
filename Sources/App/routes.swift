import Vapor
import Fluent

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    
 
  let lovedsController = LovedsController()
  try router.register(collection: lovedsController)

  let usersController = UsersController()
  try router.register(collection: usersController)

  let categoriesController = CategoriesController()
  try router.register(collection: categoriesController)

  let websiteController = WebsiteController()
  try router.register(collection: websiteController)

//  let imperialController = ImperialController()
//  try router.register(collection: imperialController)
}

