import AppKit
import Foundation
let size=NSSize(width:1024,height:1024)
let image=NSImage(size:size)
image.lockFocus()
NSColor(calibratedRed:0.025,green:0.40,blue:0.39,alpha:1).setFill();NSBezierPath(rect:NSRect(origin:.zero,size:size)).fill()
NSColor(calibratedRed:1,green:0.79,blue:0.35,alpha:1).setFill();NSBezierPath(ovalIn:NSRect(x:650,y:675,width:210,height:210)).fill()
NSColor(calibratedRed:0.12,green:0.52,blue:0.49,alpha:1).setFill();let wave=NSBezierPath();wave.move(to:NSPoint(x:0,y:150));wave.curve(to:NSPoint(x:1024,y:260),controlPoint1:NSPoint(x:300,y:450),controlPoint2:NSPoint(x:500,y:-80));wave.line(to:NSPoint(x:1024,y:0));wave.line(to:.zero);wave.close();wave.fill()
NSColor.white.setFill();let p=NSBezierPath();p.move(to:NSPoint(x:225,y:510));p.line(to:NSPoint(x:830,y:765));p.line(to:NSPoint(x:584,y:190));p.line(to:NSPoint(x:475,y:410));p.line(to:NSPoint(x:225,y:510));p.close();p.fill()
NSColor(calibratedRed:0.75,green:0.90,blue:0.83,alpha:1).setFill();let fold=NSBezierPath();fold.move(to:NSPoint(x:475,y:410));fold.line(to:NSPoint(x:830,y:765));fold.line(to:NSPoint(x:435,y:485));fold.close();fold.fill()
image.unlockFocus()
let bitmap=NSBitmapImageRep(data:image.tiffRepresentation!)!
let data=bitmap.representation(using:.png,properties:[:])!
let root=URL(fileURLWithPath:CommandLine.arguments[1]);try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
try data.write(to:root.appendingPathComponent("Icon.png"))
let contents="""
{"images":[{"filename":"Icon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
"""
try contents.write(to:root.appendingPathComponent("Contents.json"),atomically:true,encoding:.utf8)
