//
//  SKLogDB.swift
//  SKLog
//
//  Created by soso on 2017/7/18.
//  Copyright © 2017年 soso. All rights reserved.
//

import Foundation
import SQLite

fileprivate extension String {
    
    func appendingPathComponent(_ component: String) -> String {
        return (self as NSString).appendingPathComponent(component)
    }
    
    var lastPathComponent: String {
        get {
            return (self as NSString).lastPathComponent
        }
    }
    
    var deletingLastPathComponent: String {
        get {
            return (self as NSString).deletingLastPathComponent
        }
    }
    
}

fileprivate var sqlite_level        = Expression<Int>("level")
fileprivate var sqlite_file         = Expression<String>("file")
fileprivate var sqlite_line         = Expression<Int>("line")
fileprivate var sqlite_column       = Expression<Int>("column")
fileprivate var sqlite_function     = Expression<String>("function")
fileprivate var sqlite_message      = Expression<String>("message")
fileprivate var sqlite_separator    = Expression<String>("separator")
fileprivate var sqlite_terminator   = Expression<String>("terminator")
fileprivate var sqlite_timeInt      = Expression<Double>("timeInt")

fileprivate let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return f
}()

public struct SKLogRow {
    
    var level: Level
    var file:String
    var line:Int
    var column:Int
    var function:String
    var message:String
    var separator:String
    var terminator:String
    var timeInt: Double
    
    init(_ level: Level,
         _ items: [Any],
         _ separator: String,
         _ terminator: String,
         _ file: String,
         _ line: Int,
         _ column: Int,
         _ function: String) {
        self.level = level
        self.file = file.lastPathComponent
        self.line = line
        self.column = column
        self.function = function
        
        let msg = items.map { (s) -> String in
            return "\(s)"
            }.joined(separator: separator)
        self.message = msg
        
        self.separator = separator
        self.terminator = terminator
        self.timeInt = Date().timeIntervalSince1970
    }
    
    init(with sqlite_row: Row) {
        self.level = Level(rawValue: sqlite_row[sqlite_level]) ?? .trace
        self.file = sqlite_row[sqlite_file]
        self.line = sqlite_row[sqlite_line]
        self.column = sqlite_row[sqlite_column]
        self.function = sqlite_row[sqlite_function]
        self.message = sqlite_row[sqlite_message]
        self.separator = sqlite_row[sqlite_separator]
        self.terminator = sqlite_row[sqlite_terminator]
        self.timeInt = sqlite_row[sqlite_timeInt]
    }
    
    var setters: [Setter] {
        get {
            return [sqlite_level <- level.rawValue,
                    sqlite_file <- file,
                    sqlite_line <- line,
                    sqlite_column <- column,
                    sqlite_function <- function,
                    sqlite_message <- message,
                    sqlite_separator <- separator,
                    sqlite_terminator <- terminator,
                    sqlite_timeInt <- timeInt]
        }
    }
    
    var description: String {
        get {
            var comps = ["[\(level.description)] Date:" + dateFormatter.string(from: Date(timeIntervalSince1970: timeInt))]
            comps.append("\nFile:\(file)")
            comps.append("\nLine:\(line)")
            comps.append("Col:\(column)")
            comps.append("Func:\(function)")
            comps.append("\nMsg:\(message)")
            return comps.joined(separator: separator).appending(terminator)
        }
    }
    
}

final public class SKLogDB: NSObject {
    
    static let shared = SKLogDB()
    
    fileprivate var path: String = NSHomeDirectory().appending("/Documents/Log/log.sqlite")
    
    init(_ path: String = NSHomeDirectory().appending("/Documents/Log"), _ name: String = "log.sqlite") {
        super.init()
        self.path = path.appendingPathComponent(name)
        databaseConfig()
    }
    
    // MARK: Sqlite
    fileprivate var sqlite_db: Connection?
    fileprivate let sqlite_table = Table("Log")
    
    private func databaseConfig() {
        do {
            if !createDirectoryIfNotExist(path.deletingLastPathComponent) {
                print("create directory failed")
            }
            try sqlite_db = Connection(path)
            tableConfig()
        }
        catch {
            print("db config failed:\(error.localizedDescription)")
        }
    }
    
    private func createDirectoryIfNotExist(_ path: String) -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: path) {
            return true
        }
        do {
            try fm.createDirectory(at:URL(fileURLWithPath:path), withIntermediateDirectories: false, attributes: nil)
            return true
        }
        catch {
            return false
        }
    }
    
    private func tableConfig() {
        do {
            try sqlite_db?.run(sqlite_table.create(ifNotExists: true, block:{ t in
                t.column(sqlite_level)
                t.column(sqlite_file)
                t.column(sqlite_line)
                t.column(sqlite_column)
                t.column(sqlite_function)
                t.column(sqlite_message)
                t.column(sqlite_separator)
                t.column(sqlite_terminator)
                t.column(sqlite_timeInt)
            }))
        }
        catch {
            print("table config failed:\(error.localizedDescription)")
        }
    }
    
    fileprivate let queue = DispatchQueue(label: "com.sk.log.db.queue", attributes: .concurrent)
    
}

// MARK: API
extension SKLogDB {
    
    public func insert(_ row: SKLogRow) {
        let writeItem = DispatchWorkItem(qos: .default, flags: .barrier) {
            try? _ = self.sqlite_db?.run(self.sqlite_table.insert(row.setters))
        }
        queue.async(execute: writeItem)
    }
    
    public func query(level: Level, limit: Int = Int.max, start: TimeInterval, end: TimeInterval, callback: (([SKLogRow]?) -> ())?) {
        let readItem = DispatchWorkItem.init(qos: .default, flags: .assignCurrentContext) { [weak self] _ in
            guard let `self` = self else { return }
            let predicate = sqlite_level == level.rawValue && sqlite_timeInt > start && sqlite_timeInt < end
            let query = self.sqlite_table.filter(predicate).order(sqlite_timeInt.desc).limit(limit)
            guard let table = try? self.sqlite_db?.prepare(query) else {
                callback?(nil)
                return
            }
            let rows = table?.flatMap({ (row) -> SKLogRow? in
                return SKLogRow(with: row)
            })
            callback?(rows)
        }
        queue.async(execute: readItem)
    }
    
}
