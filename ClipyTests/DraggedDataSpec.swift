import Quick
import Nimble
@testable import Clipy

class DraggedDataSpec: QuickSpec {
    override func spec() {

        describe("NSCoding") {

            it("Archive data") {
                let draggedData = CPYDraggedData(type: .folder, folderIdentifier: NSUUID().uuidString, snippetIdentifier: nil, index: 10)

                if let data = draggedData.archive() {
                    let unarchiveData = data.unarchive() as? CPYDraggedData
                    expect(unarchiveData).toNot(beNil())
                    expect(unarchiveData?.type) == draggedData.type
                    expect(unarchiveData?.folderIdentifier) == draggedData.folderIdentifier
                    expect(unarchiveData?.snippetIdentifier).to(beNil())
                    expect(unarchiveData?.index) == draggedData.index
                } else {
                    fail("archive error")
                }
            }

        }

    }
}
