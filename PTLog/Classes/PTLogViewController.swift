//
//  PTLogViewController.swift
//  PTLog
//
//  Created by soso on 2017/7/21.
//  Copyright © 2017年 soso. All rights reserved.
//

import UIKit

fileprivate extension Level {
    var colorHex: Int {
        get {
            switch self {
            case .trace:    return 0xffffff
            case .debug:    return 0x0000ff
            case .info:     return 0x00ff00
            case .warning:  return 0xff8800
            case .error:    return 0xff0000
            }
        }
    }
}

fileprivate extension TimeInterval {
    static let oneMinuteSeconds: TimeInterval   = 60
    static let oneHourSeconds: TimeInterval     = 60 * 60
    static let oneDaySeconds: TimeInterval      = 24 * 60 * 60
}

fileprivate let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd\nHH:mm:ss"
    return f
}()

fileprivate let LogViewBorder: CGFloat = 6

class PTLogViewController: UIViewController {
    
    // MARK: Life cycle
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.hidesBottomBarWhenPushed = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.black
        self.view.addSubview(textView)
        self.view.addSubview(toolBar)
        self.level = .trace
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        textView.frame = UIEdgeInsetsInsetRect(self.view.bounds, UIEdgeInsets(top: 20,
                                                                              left: 0,
                                                                              bottom: toolBar.bounds.height,
                                                                              right: 0))
        toolBar.center = CGPoint(x: self.view.bounds.width / 2.0, y: self.view.bounds.height - toolBar.bounds.height / 2.0)
    }
    
    // MARK: Lazy
    fileprivate lazy var toolBar: PTLogToolBar = {
        let bar = PTLogToolBar(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 44))
        bar.closeButton.addTarget(self, action: #selector(closeSelect), for: .touchUpInside)
        bar.selectButton.addTarget(self, action: #selector(levelSelect), for: .touchUpInside)
        bar.startButton.addTarget(self, action: #selector(startSelect), for: .touchUpInside)
        bar.endButton.addTarget(self, action: #selector(endSelect), for: .touchUpInside)
        bar.limitButton.addTarget(self, action: #selector(limitSelect), for: .touchUpInside)
        return bar
    }()
    
    fileprivate lazy var textView: UITextView = {
        let tv = UITextView(frame: self.view.bounds)
        tv.backgroundColor = UIColor.black
        tv.indicatorStyle = .white
        tv.isEditable = false
        return tv
    }()
    
    // MARK: Action
    @objc fileprivate func closeSelect() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc fileprivate func levelSelect() {
        let alert = UIAlertController(title: "Select", message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        [Level.trace,
         Level.debug,
         Level.info,
         Level.warning,
         Level.error].forEach { (lv) in
            let action = UIAlertAction(title: lv.description, style: lv == level ? .destructive : .default, handler: { [weak self] (action) in
                guard let `self` = self else { return }
                self.level = lv
            })
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) { (action) in
            
        })
        self.present(alert, animated: true, completion: nil)
    }
    
    @objc fileprivate func startSelect() {
        let picker = PTDatePicker(Date(timeIntervalSince1970: start))
        picker.datePicker.maximumDate = Date()
        picker.show(self.view) { [weak self] (date) in
            self?.start = date.timeIntervalSince1970
        }
    }
    
    @objc fileprivate func endSelect() {
        let picker = PTDatePicker(Date(timeIntervalSince1970: end))
        picker.datePicker.minimumDate = Date(timeIntervalSince1970: start)
        picker.datePicker.maximumDate = Date()
        picker.show(self.view) { [weak self] (date) in
            self?.end = date.timeIntervalSince1970
        }
    }
    
    @objc fileprivate func limitSelect() {
        let alert = UIAlertController(title: "Select", message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        let step: [Int] = [10, 50, 100, 500, 1000, 5000]
        step.forEach { (value) in
            let action = UIAlertAction(title: "\(value)", style: value == limit ? .destructive : .default, handler: { [weak self] (action) in
                guard let `self` = self else { return }
                self.limit = value
            })
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) { (action) in
            
        })
        self.present(alert, animated: true, completion: nil)
    }
    
    fileprivate var level: Level = .trace {
        didSet {
            self.toolBar.selectButton.setTitle(level.description, for: .normal)
            self.query(level: self.level, limit: self.limit, start: self.start, end: self.end)
        }
    }
    
    fileprivate var limit: Int = 10 {
        didSet {
            self.toolBar.limitButton.setTitle("\(limit)", for: .normal)
            self.query(level: self.level, limit: self.limit, start: self.start, end: self.end)
        }
    }
    
    fileprivate var start: TimeInterval = Date().timeIntervalSince1970 - TimeInterval.oneDaySeconds {
        didSet {
            self.toolBar.startButton.setTitle(dateFormatter.string(from: Date(timeIntervalSince1970: start)), for: .normal)
            self.query(level: self.level, limit: self.limit, start: self.start, end: self.end)
        }
    }
    
    fileprivate var end: TimeInterval = Date().timeIntervalSince1970 {
        didSet {
            self.toolBar.endButton.setTitle(dateFormatter.string(from: Date(timeIntervalSince1970: end)), for: .normal)
            self.query(level: self.level, limit: self.limit, start: self.start, end: self.end)
        }
    }
    
    fileprivate func query(level: Level, limit: Int = Int.max, start: TimeInterval, end: TimeInterval) {
        DispatchQueue.global().async { [weak self] _ in
            guard let `self` = self, let rows = PTLogDB.shared.query(level: level, limit: limit, start: start, end: end)?.reversed() else {
                return
            }
            let attText = NSMutableAttributedString()
            rows.forEach({ (row) in
                let hexValue = row.level.colorHex
                let color = UIColor(red: CGFloat((hexValue >> 16) & 0xff) / 255,
                                    green: CGFloat((hexValue >> 8) & 0xff) / 255,
                                    blue: CGFloat((hexValue >> 0) & 0xff) / 255, alpha: 1)
                let att = [NSForegroundColorAttributeName:color]
                let attStr = NSAttributedString(string: row.description + "\n", attributes: att)
                attText.append(attStr)
            })
            DispatchQueue.main.async {
                self.textView.attributedText = attText
                self.textView.scrollRangeToVisible(NSRange(location: attText.length - 1, length: 1))
            }
        }
    }
    
}


fileprivate class PTLogToolBar: UIToolbar {
    
    // MARK: Life cycle
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(closeButton)
        self.addSubview(selectButton)
        self.addSubview(startButton)
        self.addSubview(endButton)
        self.addSubview(limitButton)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        var center = CGPoint(x: closeButton.bounds.width / 2.0 + LogViewBorder, y: self.bounds.height / 2.0)
        
        closeButton.center = center
        
        center.x += (closeButton.bounds.width + selectButton.bounds.width) / 2.0 + LogViewBorder
        selectButton.center = center
        
        let lessWidth = (self.bounds.width - (closeButton.bounds.width + selectButton.bounds.width + limitButton.bounds.width + LogViewBorder * 5)) / 2.0
        var sf = startButton.frame
        sf.size.width = lessWidth
        startButton.frame = sf
        endButton.frame = sf
        
        center.x += (selectButton.bounds.width + startButton.bounds.width) / 2.0 + LogViewBorder
        startButton.center = center
        
        center.x += (startButton.bounds.width + endButton.bounds.width) / 2.0 - 1
        endButton.center = center
        
        center.x += (endButton.bounds.width + limitButton.bounds.width) / 2.0 + LogViewBorder
        limitButton.center = center
    }
    
    // MARK: Lazy
    fileprivate lazy var closeButton: UIButton = {
        let b = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 30))
        b.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        b.setTitleColor(.purple, for: .normal)
        b.setTitle("Close", for: .normal)
        b.clipsToBounds = true
        b.layer.cornerRadius = 2.0
        b.layer.borderColor = UIColor.purple.cgColor
        b.layer.borderWidth = 1
        return b
    }()
    
    fileprivate lazy var selectButton: UIButton = {
        let b = UIButton(frame: CGRect(x: 0, y: 0, width: 80, height: 30))
        b.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        b.setTitleColor(.purple, for: .normal)
        b.setTitle("Select", for: .normal)
        b.clipsToBounds = true
        b.layer.cornerRadius = 2.0
        b.layer.borderColor = UIColor.purple.cgColor
        b.layer.borderWidth = 1
        return b
    }()
    
    fileprivate lazy var startButton: UIButton = {
        let b = UIButton(frame: CGRect(x: 0, y: 0, width: 60, height: 30))
        b.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        b.setTitleColor(.purple, for: .normal)
        b.setTitle(dateFormatter.string(from: Date(timeIntervalSince1970: Date().timeIntervalSince1970 - TimeInterval.oneDaySeconds)), for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        b.titleLabel?.numberOfLines = 0
        b.titleLabel?.textAlignment = .center
        b.layer.cornerRadius = 2.0
        b.layer.borderColor = UIColor.purple.cgColor
        b.layer.borderWidth = 1
        return b
    }()
    
    fileprivate lazy var endButton: UIButton = {
        let b = UIButton(frame: CGRect(x: 0, y: 0, width: 60, height: 30))
        b.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        b.setTitleColor(.purple, for: .normal)
        b.setTitle(dateFormatter.string(from: Date()), for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        b.titleLabel?.numberOfLines = 0
        b.titleLabel?.textAlignment = .center
        b.layer.cornerRadius = 2.0
        b.layer.borderColor = UIColor.purple.cgColor
        b.layer.borderWidth = 1
        return b
    }()
    
    fileprivate lazy var limitButton: UIButton = {
        let b = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 30))
        b.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        b.setTitleColor(.purple, for: .normal)
        b.setTitle("10", for: .normal)
        b.layer.cornerRadius = 2.0
        b.layer.borderColor = UIColor.purple.cgColor
        b.layer.borderWidth = 1
        return b
    }()
    
}


fileprivate class PTDatePicker: UIView {
    
    var callback: ((Date) -> ())?
    
    func show(_ inView: UIView, _ callback: ((Date) -> ())?) {
        self.callback = callback
        self.frame = inView.bounds
        inView.addSubview(self)
        
        self.datePicker.frame = CGRect(x: 0, y: self.bounds.height + self.toolBar.bounds.height, width: self.bounds.width, height: 200)
        self.toolBar.frame = CGRect(x: 0, y: self.datePicker.frame.minY - self.toolBar.bounds.height, width: self.bounds.width, height: self.toolBar.bounds.height)
        
        UIView.animate(withDuration: 0.35) {
            self.datePicker.frame = CGRect(x: 0, y: self.bounds.height - 200, width: self.bounds.width, height: 200)
            self.toolBar.frame = CGRect(x: 0, y: self.datePicker.frame.minY - self.toolBar.bounds.height, width: self.bounds.width, height: self.toolBar.bounds.height)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(_ date: Date?) {
        super.init(frame: .zero)
        self.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        self.addSubview(datePicker)
        self.addSubview(toolBar)
        if let `date` = date {
            self.datePicker.date = date
        }
        toolBar.cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        toolBar.doneButton.addTarget(self, action: #selector(done), for: .touchUpInside)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        datePicker.frame = CGRect(x: 0, y: self.bounds.height - 200, width: self.bounds.width, height: 200)
        toolBar.frame = CGRect(x: 0, y: datePicker.frame.minY - toolBar.bounds.height / 2.0, width: self.bounds.width, height: toolBar.bounds.height)
    }
    
    fileprivate lazy var toolBar: PTPickerToolBar = {
        let tb = PTPickerToolBar(frame: CGRect(x: 0, y: 0, width: self.bounds.width, height: 40))
        return tb
    }()
    
    fileprivate lazy var datePicker: UIDatePicker = {
        let p = UIDatePicker()
        p.backgroundColor = .white
        p.timeZone = TimeZone.current
        return p
    }()
    
    @objc fileprivate func cancel() {
        dismiss()
    }
    
    @objc fileprivate func done() {
        callback?(datePicker.date)
        dismiss()
    }
    
    fileprivate func dismiss() {
        UIView.animate(withDuration: 0.35, animations: {
            self.datePicker.frame = CGRect(x: 0, y: self.bounds.height + self.toolBar.bounds.height, width: self.bounds.width, height: 200)
            self.toolBar.frame = CGRect(x: 0, y: self.datePicker.frame.minY - self.toolBar.bounds.height, width: self.bounds.width, height: self.toolBar.bounds.height)
        }) { (finished) in
            self.removeFromSuperview()
        }
    }
    
}

fileprivate class PTPickerToolBar: UIView {
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .white
        self.addSubview(cancelButton)
        self.addSubview(doneButton)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        cancelButton.center = CGPoint(x: cancelButton.bounds.width, y: self.bounds.height / 2.0)
        doneButton.center = CGPoint(x: self.bounds.width - doneButton.bounds.width, y: self.bounds.height / 2.0)
    }
    
    fileprivate lazy var cancelButton: UIButton = {
        let b = UIButton(frame: CGRect(x: 0, y: 0, width: 60, height: 30))
        b.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        b.setTitleColor(.purple, for: .normal)
        b.setTitle("Cancel", for: .normal)
        return b
    }()
    
    fileprivate lazy var doneButton: UIButton = {
        let b = UIButton(frame: CGRect(x: 0, y: 0, width: 60, height: 30))
        b.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        b.setTitleColor(.purple, for: .normal)
        b.setTitle("Done", for: .normal)
        return b
    }()
    
}
