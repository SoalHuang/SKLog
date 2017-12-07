# SKLog

### 1.Use：
* let log = SKLog(true, true, .trace, .error)
* log.trace("hello")
* log.debug(["name":"xxx", "desc":"xxx"], separator: ", ", terminator: "\n")
* log.error("any error")

### 2.View:
* let logVC = SKLogViewController()
* present(logVC, animated: true, completion: nil)
