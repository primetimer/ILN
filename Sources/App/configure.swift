

import FluentPostgreSQL
import Vapor
import Leaf
import Authentication
//import SendGrid

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
  /// Register providers first
  try services.register(FluentPostgreSQLProvider())
  try services.register(LeafProvider())
  try services.register(AuthenticationProvider())
//  try services.register(SendGridProvider())

  /// Register routes to the router
  let router = EngineRouter.default()
  try routes(router)
  services.register(router, as: Router.self)

  /// Register middleware
  var middlewares = MiddlewareConfig() // Create _empty_ middleware config
  middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
  middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
  middlewares.use(SessionsMiddleware.self)
  services.register(middlewares)

  // Configure a database
  var databases = DatabasesConfig()
  let hostname = Environment.get("DATABASE_HOSTNAME") ?? "localhost"
  let databaseName: String
  let databasePort: Int
  if (env == .testing) {
    databaseName = "iln-test"
    if let testPort = Environment.get("DATABASE_PORT") {
      databasePort = Int(testPort) ?? 5434
    } else {
      databasePort = 5434
    }
  } else {
    databaseName = "ilndb"
    databasePort = 5432
  }

  let databaseConfig = PostgreSQLDatabaseConfig(
    hostname: hostname,
    port: databasePort,
    username: "ilnuser",
    database: databaseName,
    password: "ilnpassword")
  let database = PostgreSQLDatabase(config: databaseConfig)
  databases.add(database: database, as: .psql)
  services.register(databases)

  /// Configure migrations
  var migrations = MigrationConfig()
  migrations.add(model: User.self, database: .psql)
  migrations.add(model: Loved.self, database: .psql)
  migrations.add(model: Category.self, database: .psql)
  migrations.add(model: LovedCategoryPivot.self, database: .psql)
  migrations.add(model: Token.self, database: .psql)
  migrations.add(migration: AdminUser.self, database: .psql)
  migrations.add(model: ResetPasswordToken.self, database: .psql)
  services.register(migrations)

  var commandConfig = CommandConfig.default()
  commandConfig.useFluentCommands()
  services.register(commandConfig)

  config.prefer(LeafRenderer.self, for: ViewRenderer.self)
  config.prefer(MemoryKeyedCache.self, for: KeyedCache.self)
  
//  guard let sendGridAPIKey = Environment.get("SENDGRID_API_KEY") else {
//    fatalError("No Send Grid API Key specified")
//  }
//  let sendGridConfig = SendGridConfig(apiKey: sendGridAPIKey)
//  services.register(sendGridConfig)
    
    let serverConfigure = NIOServerConfig.default(hostname: "0.0.0.0", port: 8080)
    services.register(serverConfigure)
}
