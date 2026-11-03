// Rysuje ikonę aplikacji i logo ekranu startowego do ios/FamilyTodo/Assets.xcassets.
// Motyw: kartka e-papieru z trzema wierszami listy i ikonami priorytetu jak na wyświetlaczu
// (pełna flaga = wysoki, flaga w obrysie = normalny, kreska = niski). Kształty są te same co
// w todo::priorityIcon, ale grubsze, żeby były czytelne także w małej ikonie.
// Uruchom: swift tools/render-app-icon.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let paper = CGColor(srgbRed: 0.957, green: 0.945, blue: 0.918, alpha: 1)  // #F4F1EA
let ink = CGColor(srgbRed: 0.110, green: 0.110, blue: 0.118, alpha: 1)    // #1C1C1E

/// Rysuje motyw w kwadracie `size` (współrzędne projektu 1024 × 1024).
func render(size: Int, background: CGColor?, foreground: CGColor) -> CGImage? {
    guard let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    let scale = CGFloat(size) / 1024
    ctx.scaleBy(x: scale, y: scale)
    if let background {
        ctx.setFillColor(background)
        ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    }
    ctx.setFillColor(foreground)
    ctx.setStrokeColor(foreground)

    // Wiersze od góry (CG ma początek układu na dole).
    let rows: [(y: CGFloat, length: CGFloat, mark: Int)] = [(672, 484, 2), (512, 400, 1), (352, 300, 0)]
    for row in rows {
        // Znak w polu x 206...310: drzewce 20 px, płat 84 × 66 przy górze drzewca.
        let pole = CGRect(x: 206, y: row.y - 60, width: 20, height: 120)
        let cloth = CGRect(x: 226, y: row.y - 6, width: 84, height: 66)
        switch row.mark {
        case 2:
            ctx.fill(pole)
            ctx.fill(cloth)
        case 1:
            ctx.fill(pole)
            ctx.setLineWidth(14)
            ctx.stroke(cloth.insetBy(dx: 7, dy: 7))
        default:
            let dash = CGRect(x: 206, y: row.y - 11, width: 104, height: 22)
            ctx.addPath(CGPath(roundedRect: dash, cornerWidth: 11, cornerHeight: 11, transform: nil))
            ctx.fillPath()
        }
        let bar = CGRect(x: 350, y: row.y - 28, width: row.length, height: 56)
        ctx.addPath(CGPath(roundedRect: bar, cornerWidth: 28, cornerHeight: 28, transform: nil))
        ctx.fillPath()
    }
    return ctx.makeImage()
}

func write(_ image: CGImage?, to path: String) {
    let url = URL(fileURLWithPath: path)
    guard let image,
          let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fatalError("Nie udało się przygotować \(path)") }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("Nie udało się zapisać \(path)") }
}

let assets = "ios/FamilyTodo/Assets.xcassets"
write(render(size: 1024, background: paper, foreground: ink), to: "\(assets)/AppIcon.appiconset/AppIcon.png")
write(render(size: 1024, background: ink, foreground: paper), to: "\(assets)/AppIcon.appiconset/AppIcon-Dark.png")
write(render(size: 360, background: nil, foreground: ink), to: "\(assets)/LaunchLogo.imageset/LaunchLogo.png")
write(render(size: 360, background: nil, foreground: paper), to: "\(assets)/LaunchLogo.imageset/LaunchLogo-Dark.png")
print("Zapisano ikonę i logo startowe w \(assets)")
