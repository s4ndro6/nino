import Foundation
@main struct LibrarySmoke {
 static func main() throws {
  let root=FileManager.default.temporaryDirectory.appendingPathComponent("nino-library-test-" + UUID().uuidString)
  try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
  defer { try? FileManager.default.removeItem(at:root) }
  let repo=LibraryRepository(root:root)
  let empty=try repo.load(); precondition(empty.isEmpty)
  let doc=Document(title:"Test local",segments:[Segment(start:0,end:1,text:"Bonjour")])
  try repo.save(doc)
  let loaded=try repo.load()
  precondition(loaded.count == 1 && loaded.first?.transcript == "Bonjour")
  let invalid=repo.documents.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createSymbolicLink(at:invalid,withDestinationURL:repo.folder(doc.id))
  var warning=false
  let safe=try repo.load { _ in warning=true }
  precondition(safe.count == 1 && warning)
  print("PASS: bibliothèque vide, sauvegarde/lecture, lien symbolique refusé")
 }
}
