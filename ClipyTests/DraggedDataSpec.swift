import Quick
import Nimble
@testable import Clipy

class DraggedDataSpec: QuickSpec {
    override func spec() {

        describe("NSCoding") {

            it("Archive data") {
                let draggedData = CPYDraggedData(type: .folder, folderIdentifier: NSUUID().uuidString, snippetIdentifier: nil, index: 10)

                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject: draggedData, requiringSecureCoding: false)

                    let unarchiveData = try NSKeyedUnarchiver.unarchivedObject(ofClass: CPYDraggedData.self, from: data)
                    expect(unarchiveData).toNot(beNil())
                    expect(unarchiveData?.type) == draggedData.type
                    expect(unarchiveData?.folderIdentifier) == draggedData.folderIdentifier
                    expect(unarchiveData?.snippetIdentifier).to(beNil())
                    expect(unarchiveData?.index) == draggedData.index
                } catch {
                    fail(error.localizedDescription)
                }
            }

        }

    }
}
