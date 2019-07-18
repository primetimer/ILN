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

final class LovedTests: XCTestCase {

  let lovedsURI = "/api/loveds/"
  let lovednr = "123"
//  let lovedLong = "Oh My God"
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

  func testLovedsCanBeRetrievedFromAPI() throws {
    let loved1 = try Loved.create(nr: lovednr, on: conn)
    _ = try Loved.create(on: conn)

    let loveds = try app.getResponse(to: lovedsURI, decodeTo: [Loved].self)

    XCTAssertEqual(loveds.count, 2)
    XCTAssertEqual(loveds[0].loved, lovednr)
//    XCTAssertEqual(loveds[0].long, lovedLong)
    XCTAssertEqual(loveds[0].id, loved1.id)
  }

  func testLovedCanBeSavedWithAPI() throws {
    let user = try User.create(on: conn)
    let loved = Loved(loved: lovednr, userID: user.id!)
    let receivedLoved = try app.getResponse(to: lovedsURI, method: .POST,
                                              headers: ["Content-Type": "application/json"], data: loved,
                                              decodeTo: Loved.self, loggedInRequest: true)

    XCTAssertEqual(receivedLoved.loved, lovednr)
//    XCTAssertEqual(receivedLoved.long, lovedLong)
    XCTAssertNotNil(receivedLoved.id)

    let loveds = try app.getResponse(to: lovedsURI, decodeTo: [Loved].self)

    XCTAssertEqual(loveds.count, 1)
    XCTAssertEqual(loveds[0].loved, lovednr)
//    XCTAssertEqual(loveds[0].long, lovedLong)
    XCTAssertEqual(loveds[0].id, receivedLoved.id)
  }

  func testGettingASingleLovedFromTheAPI() throws {
    let loved = try Loved.create(nr : lovednr, on:conn)
//    let loved = try Loved.create(short: lovedShort, long: lovedLong, on: conn)

    let returnedLoved = try app.getResponse(to: "\(lovedsURI)\(loved.id!)", decodeTo: Loved.self)

    XCTAssertEqual(returnedLoved.loved, lovednr)
//    XCTAssertEqual(returnedLoved.long, lovedLong)
    XCTAssertEqual(returnedLoved.id, loved.id)
  }

  func testUpdatingAnLoved() throws {
    let loved = try Loved.create(nr: lovednr, on: conn)
    let newUser = try User.create(on: conn)
    let newLong = "Oh My Gosh"
    let updatedLoved = Loved(loved: lovednr, userID: newUser.id!)

    try app.sendRequest(to: "\(lovedsURI)\(loved.id!)", method: .PUT,
                        headers: ["Content-Type": "application/json"], data: updatedLoved, loggedInUser: newUser)

    let returnedLoved = try app.getResponse(to: "\(lovedsURI)\(loved.id!)", decodeTo: Loved.self)

    XCTAssertEqual(returnedLoved.loved, lovednr)
//    XCTAssertEqual(returnedLoved.long, newLong)
    XCTAssertEqual(returnedLoved.userID, newUser.id)
  }

  func testDeletingAnLoved() throws {
    let loved = try Loved.create(on: conn)
    var loveds = try app.getResponse(to: lovedsURI, decodeTo: [Loved].self)

    XCTAssertEqual(loveds.count, 1)

    _ = try app.sendRequest(to: "\(lovedsURI)\(loved.id!)", method: .DELETE, loggedInRequest: true)
    loveds = try app.getResponse(to: lovedsURI, decodeTo: [Loved].self)

    XCTAssertEqual(loveds.count, 0)
  }

  func testSearchLovedShort() throws {
    let loved = try Loved.create(nr: lovednr, on: conn)
    let loveds = try app.getResponse(to: "\(lovedsURI)search?term=123", decodeTo: [Loved].self)

    XCTAssertEqual(loveds.count, 1)
    XCTAssertEqual(loveds[0].id, loved.id)
    XCTAssertEqual(loveds[0].loved, lovednr)
//    XCTAssertEqual(loveds[0].long, lovedLong)
  }

//  func testSearchLovedLong() throws {
//    let loved = try Loved.create(loved: lovednr, on: conn)
//    let loveds = try app.getResponse(to: "\(lovedsURI)search?term=Oh+My+God", decodeTo: [Loved].self)
//
//    XCTAssertEqual(loveds.count, 1)
//    XCTAssertEqual(loveds[0].id, loved.id)
//    XCTAssertEqual(loveds[0].short, lovedShort)
//    XCTAssertEqual(loveds[0].long, lovedLong)
//  }

  func testGetFirstLoved() throws {
    let loved = try Loved.create(nr: lovednr, on: conn)
    _ = try Loved.create(on: conn)
    _ = try Loved.create(on: conn)

    let firstLoved = try app.getResponse(to: "\(lovedsURI)first", decodeTo: Loved.self)

    XCTAssertEqual(firstLoved.id, loved.id)
    XCTAssertEqual(firstLoved.loved, lovednr)
//    XCTAssertEqual(firstLoved.long, lovedLong)
  }

  func testSortingLoveds() throws {
    let short2 = "256"
    let long2 = "Laugh Out Loud"
    let loved1 = try Loved.create(nr: lovednr, on: conn)
    let loved2 = try Loved.create(nr: short2, on: conn)

    let sortedLoveds = try app.getResponse(to: "\(lovedsURI)sorted", decodeTo: [Loved].self)

    XCTAssertEqual(sortedLoveds[0].id, loved2.id)
    XCTAssertEqual(sortedLoveds[1].id, loved1.id)
  }

  func testGettingAnLovedsUser() throws {
    let user = try User.create(on: conn)
    let loved = try Loved.create(user: user, on: conn)

    let lovedsUser = try app.getResponse(to: "\(lovedsURI)\(loved.id!)/user", decodeTo: User.Public.self)
    XCTAssertEqual(lovedsUser.id, user.id)
    XCTAssertEqual(lovedsUser.name, user.name)
    XCTAssertEqual(lovedsUser.username, user.username)
  }

  func testLovedsCategories() throws {
    let category = try Category.create(on: conn)
    let category2 = try Category.create(name: "Funny", on: conn)
    let loved = try Loved.create(on: conn)

    _ = try app.sendRequest(to: "\(lovedsURI)\(loved.id!)/categories/\(category.id!)",
                            method: .POST, loggedInRequest: true)
    _ = try app.sendRequest(to: "\(lovedsURI)\(loved.id!)/categories/\(category2.id!)",
                            method: .POST, loggedInRequest: true)

    let categories = try app.getResponse(to: "\(lovedsURI)\(loved.id!)/categories", decodeTo: [App.Category].self)

    XCTAssertEqual(categories.count, 2)
    XCTAssertEqual(categories[0].id, category.id)
    XCTAssertEqual(categories[0].name, category.name)
    XCTAssertEqual(categories[1].id, category2.id)
    XCTAssertEqual(categories[1].name, category2.name)

    _ = try app.sendRequest(to: "\(lovedsURI)\(loved.id!)/categories/\(category.id!)", method: .DELETE,
                            loggedInRequest: true)
    let newCategories = try app.getResponse(to: "\(lovedsURI)\(loved.id!)/categories", decodeTo: [App.Category].self)

    XCTAssertEqual(newCategories.count, 1)
  }

  static let allTests = [
    ("testLovedsCanBeRetrievedFromAPI", testLovedsCanBeRetrievedFromAPI),
    ("testLovedCanBeSavedWithAPI", testLovedCanBeSavedWithAPI),
    ("testGettingASingleLovedFromTheAPI", testGettingASingleLovedFromTheAPI),
    ("testUpdatingAnLoved", testUpdatingAnLoved),
    ("testDeletingAnLoved", testDeletingAnLoved),
    ("testSearchLovedShort", testSearchLovedShort),
//    ("testSearchLovedLong", testSearchLovedLong),
    ("testGetFirstLoved", testGetFirstLoved),
    ("testSortingLoveds", testSortingLoveds),
    ("testGettingAnLovedsUser", testGettingAnLovedsUser),
    ("testLovedsCategories", testLovedsCategories),
    ]
}
