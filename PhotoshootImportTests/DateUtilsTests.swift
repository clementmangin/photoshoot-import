//
//  DateUtilsTests.swift
//  PhotoManagerTests
//
//  Created by Clément Mangin on 2024-03-04.
//

import XCTest

final class DateUtilsTests: XCTestCase {

    static func generateDate(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int
    ) -> Date {
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.timeZone = TimeZone.current
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = second

        let userCalendar = Calendar(identifier: .gregorian)
        let someDateTime = userCalendar.date(from: dateComponents)
        return someDateTime!
    }

    func testDateToString() throws {
        let datetime = Self.generateDate(1980, 7, 11, 13, 34, 56)
        XCTAssertEqual(datetime.asString(withFormat: "yyyy:MM:dd HH:mm:ss")!, "1980:07:11 13:34:56")
        XCTAssertEqual(datetime.asString(withFormat: "yy ss")!, "80 56")
    }

    func testStringToDate() throws {
        XCTAssertEqual(
            "1980:07:11 13:34:56".asDate(withFormat: "yyyy:MM:dd HH:mm:ss")!,
            Self.generateDate(1980, 7, 11, 13, 34, 56))
        XCTAssertEqual(
            "1980:07:11".asDate(withFormat: "yyyy:MM:dd")!, Self.generateDate(1980, 7, 11, 0, 0, 0))
    }
}
