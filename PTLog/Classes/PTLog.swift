//
//  PTLog.swift
//  PTLog
//
//  Created by soso on 2017/7/18.
//  Copyright © 2017年 soso. All rights reserved.
//

import Foundation

public enum Level: Int {
    case trace
    case debug
    case info
    case warning
    case error
    var description: String {
        get {
            return String(describing: self).uppercased()
        }
    }
}

open class PTLog {
    
    var isPrintEnabled: Bool = true
    var isLogEnabled: Bool = false
    
    var printMinLevel: Level = .warning
    var logMinLevel: Level = .warning
    
    private let queue = DispatchQueue(label: "com.putao.log.queue")
    
    public init(_ printMinLevel: Level = .trace, _ logMinLevel: Level = .trace) {
        self.printMinLevel = printMinLevel
        self.logMinLevel = logMinLevel
    }
    
    open func trace(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
        log(.trace, items, separator, terminator, file, line, column, function)
    }
    
    open func debug(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
        log(.debug, items, separator, terminator, file, line, column, function)
    }
    
    open func info(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
        log(.info, items, separator, terminator, file, line, column, function)
    }
    
    open func warning(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
        log(.warning, items, separator, terminator, file, line, column, function)
    }
    
    open func error(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
        log(.error, items, separator, terminator, file, line, column, function)
    }
    
    private func log(_ level: Level, _ items: [Any], _ separator: String, _ terminator: String, _ file: String, _ line: Int, _ column: Int, _ function: String) {
        let row = PTLogRow(level, items, separator, terminator, file, line, column, function)
        if isPrintEnabled, level.rawValue >= self.printMinLevel.rawValue {
            queue.async {
                Swift.print(row.description)
            }
        }
        if isLogEnabled, level.rawValue >= self.logMinLevel.rawValue {
            queue.async {
                PTLogDB.shared.insert(row)
            }
        }
    }
    
}
