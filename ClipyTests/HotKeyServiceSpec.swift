import Quick
import Nimble
import Magnet
import Carbon
@testable import Clipy

// swiftlint:disable function_body_length

class HotKeyServiceSpec: QuickSpec {
    override func spec() {

        describe("Migrate HotKey") {

            beforeEach {
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: Constants.UserDefaults.hotKeys)
                defaults.removeObject(forKey: Constants.HotKey.migrateNewKeyCombo)
                defaults.removeObject(forKey: Constants.HotKey.historyKeyCombo)
                defaults.removeObject(forKey: Constants.HotKey.snippetKeyCombo)
                defaults.synchronize()
            }

            it("Migrate default settings") {
                let service = HotKeyService()
                expect(service.historyKeyCombo).to(beNil())
                expect(service.snippetKeyCombo).to(beNil())

                let defaults = UserDefaults.standard

                expect(defaults.bool(forKey: Constants.HotKey.migrateNewKeyCombo)).to(beFalse())
                service.setupDefaultHotKeys()
                expect(defaults.bool(forKey: Constants.HotKey.migrateNewKeyCombo)).to(beTrue())

                expect(service.historyKeyCombo).toNot(beNil())
                expect(service.historyKeyCombo?.QWERTYKeyCode) == 9
                expect(service.historyKeyCombo?.modifiers) == 768
                expect(service.historyKeyCombo?.doubledModifiers).to(beFalse())
                expect(service.historyKeyCombo?.keyEquivalent.uppercased()) == "V"

                expect(service.snippetKeyCombo).toNot(beNil())
                expect(service.snippetKeyCombo?.QWERTYKeyCode) == 11
                expect(service.snippetKeyCombo?.modifiers) == 768
                expect(service.snippetKeyCombo?.doubledModifiers).to(beFalse())
                expect(service.snippetKeyCombo?.keyEquivalent.uppercased()) == "B"
            }

            it("Migrate customize settings") {
                let service = HotKeyService()
                expect(service.historyKeyCombo).to(beNil())
                expect(service.snippetKeyCombo).to(beNil())

                let defaults = UserDefaults.standard
                let defaultKeyCombos: [String: Any] = [Constants.Menu.history: ["keyCode": 9, "modifiers": 768],
                                                       Constants.Menu.snippet: ["keyCode": 11, "modifiers": 4352]]
                defaults.register(defaults: [Constants.UserDefaults.hotKeys: defaultKeyCombos])
                defaults.synchronize()

                expect(defaults.bool(forKey: Constants.HotKey.migrateNewKeyCombo)).to(beFalse())
                service.setupDefaultHotKeys()
                expect(defaults.bool(forKey: Constants.HotKey.migrateNewKeyCombo)).to(beTrue())

                expect(service.historyKeyCombo).toNot(beNil())
                expect(service.historyKeyCombo?.QWERTYKeyCode) == 9
                expect(service.historyKeyCombo?.modifiers) == 768
                expect(service.historyKeyCombo?.doubledModifiers).to(beFalse())
                expect(service.historyKeyCombo?.keyEquivalent.uppercased()) == "V"

                expect(service.snippetKeyCombo).toNot(beNil())
                expect(service.snippetKeyCombo?.QWERTYKeyCode) == 11
                expect(service.snippetKeyCombo?.modifiers) == 4352
                expect(service.snippetKeyCombo?.doubledModifiers).to(beFalse())
                expect(service.snippetKeyCombo?.keyEquivalent.uppercased()) == "B"
            }

            afterEach {
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: Constants.UserDefaults.hotKeys)
                defaults.removeObject(forKey: Constants.HotKey.migrateNewKeyCombo)
                defaults.removeObject(forKey: Constants.HotKey.historyKeyCombo)
                defaults.removeObject(forKey: Constants.HotKey.snippetKeyCombo)
                defaults.synchronize()
            }
        }

        describe("Save HotKey") {

            beforeEach {
                let defaults = UserDefaults.standard
                defaults.set(true, forKey: Constants.HotKey.migrateNewKeyCombo)
                defaults.removeObject(forKey: Constants.HotKey.historyKeyCombo)
                defaults.removeObject(forKey: Constants.HotKey.snippetKeyCombo)
                defaults.synchronize()
            }

            it("Save key combos") {
                let service = HotKeyService()
                expect(service.historyKeyCombo).to(beNil())
                expect(service.snippetKeyCombo).to(beNil())

                let defaults = UserDefaults.standard
                expect(defaults.archiveDataForKey(KeyCombo.self, key: Constants.HotKey.historyKeyCombo)).to(beNil())
                expect(defaults.archiveDataForKey(KeyCombo.self, key: Constants.HotKey.snippetKeyCombo)).to(beNil())

                service.setupDefaultHotKeys()
                expect(service.historyKeyCombo).to(beNil())
                expect(service.snippetKeyCombo).to(beNil())

                let historyKeyCombo = KeyCombo(QWERTYKeyCode: 9, carbonModifiers: 768)
                let snippetKeyCombo = KeyCombo(QWERTYKeyCode: 0, cocoaModifiers: .shift)

                service.change(with: .history, keyCombo: historyKeyCombo)
                service.change(with: .snippet, keyCombo: snippetKeyCombo)

                let savedHistoryKeyCombo = defaults.archiveDataForKey(KeyCombo.self, key: Constants.HotKey.historyKeyCombo)
                let savedSnippetKeyCombo = defaults.archiveDataForKey(KeyCombo.self, key: Constants.HotKey.snippetKeyCombo)

                expect(savedHistoryKeyCombo).toNot(beNil())
                expect(savedHistoryKeyCombo?.QWERTYKeyCode) == 9
                expect(savedHistoryKeyCombo?.modifiers) == 768
                expect(savedHistoryKeyCombo?.doubledModifiers).to(beFalse())
                expect(savedHistoryKeyCombo?.keyEquivalent.uppercased()) == "V"

                expect(savedSnippetKeyCombo).toNot(beNil())
                expect(savedSnippetKeyCombo?.QWERTYKeyCode) == 0
                expect(savedSnippetKeyCombo?.modifiers) == shiftKey
                expect(savedSnippetKeyCombo?.doubledModifiers).to(beFalse())
                expect(savedSnippetKeyCombo?.keyEquivalent.uppercased()) == "A"

                service.change(with: .history, keyCombo: nil)
                expect(service.historyKeyCombo).to(beNil())
                expect(defaults.archiveDataForKey(KeyCombo.self, key: Constants.HotKey.historyKeyCombo)).to(beNil())
            }

            it("Unarchive saved key combos") {
                let historyKeyCombo = KeyCombo(QWERTYKeyCode: 9, carbonModifiers: 768)
                let snippetKeyCombo = KeyCombo(QWERTYKeyCode: 0, cocoaModifiers: .shift)

                let defaults = UserDefaults.standard
                defaults.setArchiveData(historyKeyCombo!, forKey: Constants.HotKey.historyKeyCombo)
                defaults.setArchiveData(snippetKeyCombo!, forKey: Constants.HotKey.snippetKeyCombo)

                let service = HotKeyService()
                expect(service.historyKeyCombo).to(beNil())
                expect(service.snippetKeyCombo).to(beNil())

                service.setupDefaultHotKeys()

                expect(service.historyKeyCombo).toNot(beNil())
                expect(service.historyKeyCombo?.QWERTYKeyCode) == 9
                expect(service.historyKeyCombo?.modifiers) == 768
                expect(service.historyKeyCombo?.doubledModifiers).to(beFalse())
                expect(service.historyKeyCombo?.keyEquivalent.uppercased()) == "V"

                expect(service.snippetKeyCombo).toNot(beNil())
                expect(service.snippetKeyCombo?.QWERTYKeyCode) == 0
                expect(service.snippetKeyCombo?.modifiers) == shiftKey
                expect(service.snippetKeyCombo?.doubledModifiers).to(beFalse())
                expect(service.snippetKeyCombo?.keyEquivalent.uppercased()) == "A"
            }

            afterEach {
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: Constants.UserDefaults.hotKeys)
                defaults.removeObject(forKey: Constants.HotKey.migrateNewKeyCombo)
                defaults.removeObject(forKey: Constants.HotKey.historyKeyCombo)
                defaults.removeObject(forKey: Constants.HotKey.snippetKeyCombo)
                defaults.synchronize()
            }
        }

        describe("Key comobos") {
            it("Default key combos") {
                let keyCombos = HotKeyService.defaultKeyCombos
                let historyCombos = keyCombos[Constants.Menu.history] as? [String: Int]
                let snippetCombos = keyCombos[Constants.Menu.snippet] as? [String: Int]

                expect(historyCombos?["keyCode"]) == 9
                expect(historyCombos?["modifiers"]) == 768

                expect(snippetCombos?["keyCode"]) == 11
                expect(snippetCombos?["modifiers"]) == 768
            }
        }

        describe("Folder HotKey") {
            beforeEach {
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: Constants.HotKey.folderKeyCombos)
                defaults.synchronize()
            }

            it("Add and Remove folder hotkey") {
                let service = HotKeyService()

                let identifier = NSUUID().uuidString
                expect(service.snippetKeyCombo(forIdentifier: identifier)).to(beNil())

                let keyCombo = KeyCombo(QWERTYKeyCode: 0, carbonModifiers: cmdKey)!
                service.registerSnippetHotKey(with: identifier, keyCombo: keyCombo)

                expect(service.snippetKeyCombo(forIdentifier: identifier)).toNot(beNil())
                expect(service.snippetKeyCombo(forIdentifier: identifier)) == keyCombo

                let changeKeyCombo = KeyCombo(doubledCarbonModifiers: shiftKey)!
                service.registerSnippetHotKey(with: identifier, keyCombo: changeKeyCombo)

                expect(service.snippetKeyCombo(forIdentifier: identifier)) != keyCombo
                expect(service.snippetKeyCombo(forIdentifier: identifier)) == changeKeyCombo

                service.unregisterSnippetHotKey(with: identifier)
                expect(service.snippetKeyCombo(forIdentifier: identifier)).to(beNil())
            }

            afterEach {
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: Constants.HotKey.folderKeyCombos)
                defaults.synchronize()
            }
        }
    }
}
