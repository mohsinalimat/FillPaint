//
//  Image.swift
//  FillPaint
//
//  Created by Rajesh Thangaraj on 31/10/19.
//  Copyright © 2019 Rajesh Thangaraj. All rights reserved.
//

import UIKit
import CoreGraphics

 extension UIImage {
    
    var width: Int {
        return Int(size.width)
    }
    var height: Int {
         return Int(size.height)
     }
    
    /*
     tolerance varies from 4 * 255 * 255
     */
    func processPixels(from point: (Int, Int), color: UIColor, tolerance: Int) -> UIImage {
        guard let coreImage = self.cgImage else {
            return self
        }
        let bytesPerPixel    = 4
        let width            = coreImage.width
        let height           = coreImage.height
        let colorSpace       = CGColorSpaceCreateDeviceRGB()
        let bitsPerComponent = 8
        let bytesPerRow      = bytesPerPixel * width
        let bitmapInfo       = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
            return self
        }
        context.draw(coreImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let buffer = context.data else {
            return self
        }
        let pixelBuffer = buffer.assumingMemoryBound(to: UInt32.self)
        let processor = ImageProcessor(buffer: pixelBuffer, dataSize: (width, height))
        processor.floodFill(from: point, with: color, tolerance: tolerance)
        let outputCGImage = context.makeImage()!
        let outputImage = UIImage(cgImage: outputCGImage, scale: self.scale, orientation: self.imageOrientation)
        return outputImage
     }
 }

class ImageProcessor {
    let pixelBuffer: UnsafeMutablePointer<UInt32>
    let width: Int
    let height: Int
    
    init(buffer: UnsafeMutablePointer<UInt32>, dataSize: (Int,Int) ) {
        pixelBuffer = buffer
        width = dataSize.0
        height = dataSize.1
    }
    
    func indexFor(_ x: Int, _ y: Int) -> Int {
        return x + width*y
    }
    
    subscript(index: Int) -> Pixel {
        get {
            let pixelIndex = pixelBuffer + index
//             let pixelIndex = pixelBuffer
            return Pixel(memory: pixelIndex.pointee)
        }
        set(pixel) {
            self.pixelBuffer[index] = pixel.uInt32Value
        }
    }
    
    func floodFill(from point: (Int, Int), with: UIColor, tolerance: Int) {
        let toColor = Pixel(color: with)
        let initialIndex = indexFor(point.0, point.1)
        let fromInfo = self[initialIndex]
        let processedIndices = NSMutableIndexSet()
        let indices = NSMutableIndexSet(index: initialIndex)
        while indices.count > 0 {
            let index = indices.firstIndex
            indices.remove(index)
            if processedIndices.contains(index) {
                continue
            }
            processedIndices.add(index)
            
            if self[index].diff(fromInfo) > tolerance { continue }
            
            let pointX = index % width
            let y = index / width
            var minX = pointX
            var maxX = pointX + 1
            while minX >= 0 {
                    let index = indexFor(minX, y)
                    let pixelInfo = self[index]
                    let diff = pixelInfo.diff(fromInfo)
                    if diff > tolerance { break }
                    self[index] = toColor
                    minX -= 1
                }
                while maxX < width {
                    let index = indexFor(maxX, y)
                    let pixelInfo = self[index]
                    let diff = pixelInfo.diff(fromInfo)
                    if diff > tolerance { break }
                    self[index] = toColor
                    maxX += 1
                }
                for x in ((minX + 1)...(maxX - 1)) {
                    if y < height - 1 {
                        let index = indexFor(x, y + 1)
                        if !processedIndices.contains(index) && self[index].diff(fromInfo) <= tolerance {
                            indices.add(index)
                        }
                    }
                    if y > 0 {
                        let index = indexFor(x, y - 1)
                        if !processedIndices.contains(index) && self[index].diff(fromInfo) <= tolerance {
                            indices.add(index)
                        }
                    }
                }
            }
        }
}

struct Pixel {
    let r, g, b, a: UInt8
    
    init(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
    init(memory: UInt32) {
        self.a = UInt8((memory >> 24) & 255)
        self.r = UInt8((memory >> 16) & 255)
        self.g = UInt8((memory >> 8) & 255)
        self.b = UInt8((memory >> 0) & 255)
    }
    init(color: UIColor) {
        let model = color.cgColor.colorSpace?.model
        if model == .monochrome {
            var white: CGFloat = 0
            var alpha: CGFloat = 0
            color.getWhite(&white, alpha: &alpha)
            self.r = UInt8(white * 255)
            self.g = UInt8(white * 255)
            self.b = UInt8(white * 255)
            self.a = UInt8(alpha * 255)
        } else if model == .rgb {
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            self.r = UInt8(r * 255)
            self.g = UInt8(g * 255)
            self.b = UInt8(b * 255)
            self.a = UInt8(a * 255)
        } else {
            self.r = 0
            self.g = 0
            self.b = 0
            self.a = 0
        }
    }
    var color: UIColor {
        return UIColor(red: CGFloat(self.r) / 255, green: CGFloat(self.g) / 255, blue: CGFloat(self.b) / 255, alpha: CGFloat(self.a) / 255)
    }
    var uInt32Value: UInt32 {
        var total = (UInt32(self.a) << 24)
        total += (UInt32(self.r) << 16)
        total += (UInt32(self.g) << 8)
        total += (UInt32(self.b) << 0)
        return total
    }
    
    static func componentDiff(_ l: UInt8, _ r: UInt8) -> UInt8 {
        return max(l, r) - min(l, r)
    }
    
    func multiplyAlpha(_ alpha: CGFloat) -> Pixel {
        return Pixel(self.r, self.g, self.b, UInt8(CGFloat(self.a) * alpha))
    }
    
    func blend(_ other: Pixel) -> Pixel {
        let a1 = CGFloat(self.a) / 255.0
        let a2 = CGFloat(other.a) / 255.0
        return Pixel(
            UInt8((a1 * CGFloat(self.r)) + (a2 * (1 - a1) * CGFloat(other.r))),
            UInt8((a1 * CGFloat(self.g)) + (a2 * (1 - a1) * CGFloat(other.g))),
            UInt8((a1 * CGFloat(self.b)) + (a2 * (1 - a1) * CGFloat(other.b))),
            UInt8((255 * (a1 + a2 * (1 - a1))))
        )
    }
    
    func diff(_ other: Pixel) -> Int {
        let r = Int(Pixel.componentDiff(self.r, other.r))
        let g = Int(Pixel.componentDiff(self.g, other.g))
        let b = Int(Pixel.componentDiff(self.b, other.b))
        let a = Int(Pixel.componentDiff(self.a, other.a))
        return r*r + g*g + b*b + a*a
    }
}