//
//  DateUtils.swift
//  PhotoManager
//
//  Created by Clément Mangin on 2024-02-25.
//

import Foundation

extension String {
    func asDate(withFormat format: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.date(from: self)
    }
}

extension Date {
    func asString(withFormat format: String) -> String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: self)
    }
}
