// 
//  FilterMenu.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
// 
//  Created by Aphro Hares on 2020/10/23.
// 
//  Copyright © 2015-2020 Clipy Project.
//

import Foundation
import Cocoa
import RealmSwift
import RxSwift
import RxCocoa
import RxOptional


class FilterMenu: NSMenu {
    fileprivate let bag = DisposeBag()
    fileprivate let realm = try! Realm()
    
    fileprivate let filterRelay = BehaviorRelay<String>(value: "")
    fileprivate let clipResultsRelay = BehaviorRelay<Results<CPYClip>?>(value: nil)
    
    let item: TextFieldMenuItem
    override init(title: String) {
        item = TextFieldMenuItem(title: title, action: nil)
        
        super.init(title: title)
        
        delegate = self
        
        addItem(item)
        
        clipResultsRelay
            .flatMap { [weak self](res) -> Observable<String> in
                guard let self = self, res != nil else { return .empty() }
                return self.filterRelay.asObservable() }
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .default))
            .distinctUntilChanged()
            .flatMapLatest { (filter)  -> Observable<NSPredicate?> in
                guard !filter.isEmpty else { return Observable.just(nil) }
                let predicate = NSPredicate(format: "title LIKE[cd] %@", "*" + filter + "*")
                return Observable.just(predicate) }
            .withLatestFrom(clipResultsRelay) { (predicate, clipResults) -> [NSMenuItem]? in
                var res = clipResults
                if let predicate = predicate {
                    res = res?.filter(predicate)
                }
                return res?.enumerated().map { (obj) in
                    return NSMenuItem(title: obj.element.title, action: #selector(AppDelegate.selectClipMenuItem(_:)))
                } }
            .filterNil()
            .catchErrorJustReturn([])
            .observeOn(ConcurrentMainScheduler.instance)
            .subscribe { [weak self](event) in
                guard let self = self, case .next(var new) = event else { return }
                new.insert(self.item, at: 0)
                
                Array(new)
                    .difference(from: Array(self.items)) { $0.title == $1.title }
                    .forEach { (change) in
                    switch change {
                    case let .insert(offset, element, _):
                        self.insertItem(element, at: offset)
                    case let .remove(_, element, _):
                        self.removeItem(element)
                    }
                }
                self.update()
            }.disposed(by: bag)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func cleanFilter() {
        filterRelay.accept("")
        item.content.queryTF.stringValue = ""
        item.content.updateVisibility()
    }
    
    func update(filter: String) {
        filterRelay.accept(filter)
    }
}

extension FilterMenu: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        let ascending = !AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.reorderClipsAfterPasting)
        let res =  realm
            .objects(CPYClip.self)
            .sorted(byKeyPath: #keyPath(CPYClip.updateTime), ascending: ascending)
            .lazy
        clipResultsRelay.accept(res)
    }
}
