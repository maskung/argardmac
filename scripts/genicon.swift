// วาดไอคอน Argard 1024x1024 → scripts/appicon_1024.png
// รัน: swift scripts/genicon.swift
import AppKit

let size = 1024.0

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no context") }

// พื้นหลัง gradient ฟ้า
let colors = [NSColor(calibratedRed: 0.13, green: 0.44, blue: 0.85, alpha: 1).cgColor,
              NSColor(calibratedRed: 0.05, green: 0.70, blue: 0.78, alpha: 1).cgColor] as CFArray
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

func circle(_ x: Double, _ y: Double, _ r: Double, _ color: NSColor) {
    ctx.setFillColor(color.cgColor)
    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
}

// ดวงอาทิตย์
circle(600, 640, 200, NSColor(calibratedRed: 1, green: 0.78, blue: 0.25, alpha: 1))
circle(600, 640, 160, NSColor(calibratedRed: 1, green: 0.88, blue: 0.35, alpha: 1))

// เมฆ (วงกลม 3 อัน + base)
let cloudWhite = NSColor.white.withAlphaComponent(0.97)
circle(430, 400, 130, cloudWhite)
circle(580, 430, 160, cloudWhite)
circle(710, 380, 110, cloudWhite)
ctx.setFillColor(cloudWhite.cgColor)
ctx.fill(CGRect(x: 330, y: 310, width: 480, height: 90))

// หยดฝน
ctx.setFillColor(NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.95, alpha: 1).cgColor)
for (i, x) in [400.0, 500.0, 600.0].enumerated() {
    let y = 230.0 - Double(i) * 12
    let drop = CGPath(roundedRect: CGRect(x: x - 26, y: y - 70, width: 52, height: 76),
                      cornerWidth: 26, cornerHeight: 26, transform: nil)
    ctx.addPath(drop)
    ctx.fillPath()
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { fatalError("png fail") }

let out = URL(fileURLWithPath: "scripts/appicon_1024.png")
try! png.write(to: out)
print("saved \(out.path)")