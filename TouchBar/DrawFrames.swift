import AppKit
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
let ninoAccent = Color(red:0.48,green:0.78,blue:0.64)
@main struct RenderRetina {
 @MainActor static func main() throws {
  let folder=URL(fileURLWithPath:CommandLine.arguments[1]);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
  let modes:[(String,CompanionMood)] = [("idle",.idle),("call",.call),("record",.dictate),("transcribe",.transcribing),("think",.thinking),("timer",.timer),("ready",.success),("error",.error)]
  for (name,mood) in modes {
   for frame in 0..<128 {
    let renderer=ImageRenderer(content:CompanionView(mood:mood,sampleTime:Double(frame)/24).frame(width:120,height:100));renderer.scale=2
    guard let sprite=renderer.nsImage else {fatalError("No sprite")}
    // 48 physical pixels; MTMR supplies the 24-point logical size without discarding pixels.
    let image=NSImage(size:NSSize(width:48,height:48));image.lockFocus()
    NSColor.black.setFill();NSRect(x:0,y:0,width:48,height:48).fill()
    NSGraphicsContext.current?.imageInterpolation = .high
    let dx = name == "idle" ? sin(Double(frame)/128 * .pi*2)*2 : 0
    sprite.draw(in:NSRect(x:dx,y:0,width:48,height:48),from:NSRect(x:18,y:8,width:88,height:88),operation:.sourceOver,fraction:1)
    image.unlockFocus()
    let bitmap=NSBitmapImageRep(data:image.tiffRepresentation!)!
    assert(bitmap.pixelsWide == 48 && bitmap.pixelsHigh == 48)
    try bitmap.representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent("\(name)-\(frame).png"))
   }
  }
  print("1024 Retina frames 48×48")
 }
}
