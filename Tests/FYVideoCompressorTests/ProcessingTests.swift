//
//  File.swift
//  
//
//  Created by Unicorn on 23.01.24.
//

import XCTest
@testable import FYVideoCompressor
import AVFoundation
import VideoToolbox

let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
final class ProcessingTests: XCTestCase {
  @available (iOS 13.0, *)
  func testCompressVideoWithScale() async throws {
    let formatter = DateFormatter()
    formatter.dateFormat = "h-mm-ss"
    let video = documents.appendingPathComponent("input.mp4")
    let target = documents.appendingPathComponent("output-\(formatter.string(from: Date())).mp4")
    let output = try await video.compressVideo(.h264())
    try FileManager.default.moveItem(at: output, to: target)
  }
}
