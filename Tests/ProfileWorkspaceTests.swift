import Foundation
@main struct ProfileWorkspaceTests {
 @MainActor static func settle(_ store: WorkspaceStore) async throws {
  for _ in 0..<200 { if store.ready && !store.saving { return }; try await Task.sleep(for: .milliseconds(10)) }
  fatalError("Store did not settle: \(store.issue ?? "")")
 }
 @MainActor static func main() async throws {
  let root=URL(fileURLWithPath:"/private/tmp/nino-profiles-"+UUID().uuidString)
  try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
  defer { try? FileManager.default.removeItem(at:root) }
  let repo=WorkspaceRepository(directory:root.appendingPathComponent("Workspace"))
  var old=WorkProject(); old.title="Ancienne fiche"
  var state=WorkspaceState(); state.projects=[old]; state.selectedID=old.id
  var json=try JSONSerialization.jsonObject(with: WorkspaceRepository.encoder.encode(state)) as! [String:Any]
  var rows=json["projects"] as! [[String:Any]]; rows[0].removeValue(forKey:"profileID"); rows[0].removeValue(forKey:"workflowID"); json["projects"]=rows; json.removeValue(forKey:"selections")
  try repo.write(JSONSerialization.data(withJSONObject:json),name:"workspace.json")
  let store=WorkspaceStore(root:root,profileID:"editor"); try await settle(store)
  precondition(store.current == nil && store.visibleProjects.isEmpty && store.generalCount == 1)
  var video=WorkProfile.editor.workflows[0].project(profile:.editor)
  precondition(store.upsert(video)); try await settle(store)
  let first=video.id
  video=WorkProfile.editor.workflows[1].project(profile:.editor)
  precondition(store.upsert(video)); try await settle(store)
  store.select(first); try await settle(store)
  store.setSharing(true); try await settle(store)
  precondition(store.sharing)
  store.activateProfile("designer"); try await settle(store)
  precondition(store.current == nil && !store.sharing)
  let snapshot=try JSONSerialization.jsonObject(with:repo.read("context.json")) as! [String:Any]
  precondition(snapshot["sharingEnabled"] as? Bool == false && snapshot["project"] == nil)
  precondition(!store.upsert(video))
  let design=WorkProfile.designer.workflows[0].project(profile:.designer)
  precondition(store.upsert(design)); try await settle(store)
  store.activateProfile("editor"); try await settle(store)
  precondition(store.current?.id == first && store.visibleProjects.count == 2)
  store.activateProfile(nil); try await settle(store)
  precondition(store.current?.id == old.id)
  store.moveCurrent(to:"developer"); try await settle(store)
  precondition(store.current == nil && store.generalCount == 0)
  store.activateProfile("developer"); try await settle(store)
  precondition(store.current?.id == old.id)
  store.activateProfile("editor"); try await settle(store)
  let restarted=WorkspaceStore(root:root,profileID:"editor"); try await settle(restarted)
  precondition(restarted.current?.id == first && restarted.visibleProjects.count == 2)
  for profile in WorkProfile.allCases { for template in profile.workflows { _ = try template.project(profile:profile).validated() } }
  let persisted = try repo.load(); precondition(persisted.projects.count == 4)
  print("PASS Profiles: legacy migration, isolation, selections, move, sharing revocation, templates")
 }
}
