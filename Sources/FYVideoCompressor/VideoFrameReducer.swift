//
//  File.swift
//  
//
//  Created by xiaoyang on 2023/6/5.
//

import Foundation

/// A strategy protocol to let users to define their own strategy of reducing fps
public protocol VideoFrameReducer {
    /// Get frame buffer index array
    /// - Parameters:
    ///   - originalFPS: original fps
    ///   - targetFPS: target fps
    ///   - videoDuration: video duration
    /// - Returns: frame buffer index array
    func reduce(originalFPS: Float, to targetFPS: Float, with videoDuration: Float) -> [Int]
}

public extension VideoFrameReducer where Self == ReduceFrameEvenlySpaced {
  static var evenlySpaced: ReduceFrameEvenlySpaced { ReduceFrameEvenlySpaced() }
}
public extension VideoFrameReducer where Self == ReduceFrameRandomly {
  static var randomly: ReduceFrameRandomly { ReduceFrameRandomly() }
}

/// Get frame index array evenly spaced
public struct ReduceFrameEvenlySpaced: VideoFrameReducer {
    public init() {}
    
    public func reduce(originalFPS: Float, to targetFPS: Float, with videoDuration: Float) -> [Int] {
        let originalFrames = Int(originalFPS * videoDuration)
        let targetFrames = Int(videoDuration * targetFPS)
        
        //
        var rangeArr = Array(repeating: 0, count: targetFrames)
        for i in 0..<targetFrames {
            rangeArr[i] = Int(floor(Double(originalFrames) * Double(i) / Double(targetFrames)))
        }
        
        return rangeArr
    }
}

/// Get frame index array random in a every region
public struct ReduceFrameRandomly: VideoFrameReducer {
    public init() {}
    
    public func reduce(originalFPS: Float, to targetFPS: Float, with videoDuration: Float) -> [Int] {
        let originalFrames = Int(originalFPS * videoDuration)
        let targetFrames = Int(videoDuration * targetFPS)
        
        //
        var rangeArr = Array(repeating: 0, count: targetFrames)
        for i in 0..<targetFrames {
            rangeArr[i] = Int(ceil(Double(originalFrames) * Double(i+1) / Double(targetFrames)))
        }
        
        var randomFrames = Array(repeating: 0, count: rangeArr.count)
        
        guard !randomFrames.isEmpty else {
            return []
        }
        
        // first frame
        // avoid droping the first frame
        guard randomFrames.count > 1 else {
            return randomFrames
        }
        
        for index in 1..<rangeArr.count {
            let pre = rangeArr[index-1]
            let res = Int.random(in: pre..<rangeArr[index])
            randomFrames[index] = res
        }
        return randomFrames        
    }
}

