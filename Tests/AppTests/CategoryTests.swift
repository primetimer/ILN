/// Copyright (c) 2019 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

@testable import App
import Vapor
import XCTest
import FluentPostgreSQL

final class CategoryTests: XCTestCase {

  let categoriesURI = "/api/categories/"
  let categoryName = "Teenager"
  var app: Application!
  var conn: PostgreSQLConnection!

  override func setUp() {
    try! Application.reset()
    app = try! Application.testable()
    conn = try! app.newConnection(to: .psql).wait()
  }

  override func tearDown() {
    conn.close()
    try? app.syncShutdownGracefully()
  }

  func testCategoriesCanBeRetrievedFromAPI() throws {
    let category = try Category.create(name: categoryName, on: conn)
    _ = try Category.create(on: conn)

    let categories = try app.getResponse(to: categoriesURI, decodeTo: [App.Category].self)

    XCTAssertEqual(categories.count, 2)
    XCTAssertEqual(categories[0].name, categoryName)
    XCTAssertEqual(categories[0].id, category.id)
  }

  func testCategoryCanBeSavedWithAPI() throws {
    let category = Category(name: categoryName)
    let receivedCategory = try app.getResponse(to: categoriesURI, method: .POST,
                                               headers: ["Content-Type": "application/json"],
                                               data: category, decodeTo: Category.self, loggedInRequest: true)

    XCTAssertEqual(receivedCategory.name, categoryName)
    XCTAssertNotNil(receivedCategory.id)

    let categories = try app.getResponse(to: categoriesURI, decodeTo: [App.Category].self)

    XCTAssertEqual(categories.count, 1)
    XCTAssertEqual(categories[0].name, categoryName)
    XCTAssertEqual(categories[0].id, receivedCategory.id)
  }

  func testGettingASingleCategoryFromTheAPI() throws {
    let category = try Category.create(name: categoryName, on: conn)
    let returnedCategory = try app.getResponse(to: "\(categoriesURI)\(category.id!)", decodeTo: Category.self)

    XCTAssertEqual(returnedCategory.name, categoryName)
    XCTAssertEqual(returnedCategory.id, category.id)
  }

  func testGettingACategoriesLovedsFromTheAPI() throws {
    let lovednr = "123"
//    let lovedLong = "Oh My God"
    let loved = try Loved.create(nr: lovednr, on: conn)
    let loved2 = try Loved.create(on: conn)

    let category = try Category.create(name: categoryName, on: conn)

    _ = try app.sendRequest(to: "/api/loveds/\(loved.id!)/categories/\(category.id!)",
                            method: .POST, loggedInRequest: true)
    _ = try app.sendRequest(to: "/api/loveds/\(loved2.id!)/categories/\(category.id!)",
                            method: .POST, loggedInRequest: true)

    let loveds = try app.getResponse(to: "\(categoriesURI)\(category.id!)/loveds", decodeTo: [Loved].self)

    XCTAssertEqual(loveds.count, 2)
    XCTAssertEqual(loveds[0].id, loved.id)
    XCTAssertEqual(loveds[0].loved, lovednr)
//    XCTAssertEqual(loveds[0].long, lovedLong)
  }

  static let allTests = [
    ("testCategoriesCanBeRetrievedFromAPI", testCategoriesCanBeRetrievedFromAPI),
    ("testCategoryCanBeSavedWithAPI", testCategoryCanBeSavedWithAPI),
    ("testGettingASingleCategoryFromTheAPI", testGettingASingleCategoryFromTheAPI),
    ("testGettingACategoriesLovedsFromTheAPI", testGettingACategoriesLovedsFromTheAPI),
    ]
}
