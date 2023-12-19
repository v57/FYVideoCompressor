//
//  File.swift
//  
//
//  Created by Unicorn on 18.12.23.
//

import Foundation
import AVFoundation

public struct VideoCompressorSettings {
  public var settings: [String: Any] = [:]
  public init(settings: [String : Any] = [:]) {
    self.settings = settings
  }
}
public extension VideoCompressorSettings {
  func codec(_ value: AVVideoCodecType) -> Self {
    set(AVVideoCodecKey, value)
  }
  func scaling(_ value: ScalingMode) -> Self {
    set(AVVideoScalingModeKey, value.rawValue)
  }
  func width(_ value: Double) -> Self {
    set(AVVideoWidthKey, value)
  }
  func height(_ value: Double) -> Self {
    set(AVVideoHeightKey, value)
  }
  func wideColor(_ value: Bool = true) -> Self {
    set(AVVideoAllowWideColorKey, value)
  }
  func pixelAspectRatio(horizontal: Double = 1, vertical: Double = 1) -> Self {
    set(AVVideoPixelAspectRatioKey, [
      AVVideoPixelAspectRatioHorizontalSpacingKey: horizontal,
      AVVideoPixelAspectRatioVerticalSpacingKey: vertical
    ])
  }
  func cleanAperture(frame: CGRect) -> Self {
    set(AVVideoCleanApertureKey, [
      AVVideoCleanApertureWidthKey: frame.width,
      AVVideoCleanApertureHeightKey: frame.height,
      AVVideoCleanApertureHorizontalOffsetKey: frame.minX,
      AVVideoCleanApertureVerticalOffsetKey: frame.minY,
    ])
  }
  func color(_ value: Color) -> Self {
    set(AVVideoColorPropertiesKey, value.rawValue)
  }
  func allowFrameReordering(_ value: Bool) -> Self {
    set(AVVideoAllowFrameReorderingKey, value)
  }
  func compression(bitrate: Float, quality: Float, frameReordering: Bool, profile: H264.ProfileLevel = .highAuto, entropy: H264.Entropy = .cabac) -> Self {
    compression {
      if bitrate > 0 {
        $0[AVVideoAverageBitRateKey] = bitrate
      }
      if quality > 0 {
        $0[AVVideoQualityKey] = quality
      }
      $0[AVVideoAllowFrameReorderingKey] = frameReordering
      $0[AVVideoProfileLevelKey] = profile.rawValue
      $0[AVVideoH264EntropyModeKey] = entropy.rawValue
    }
  }
  func keyframeInterval(_ value: Int) -> Self {
    compression { $0[AVVideoMaxKeyFrameIntervalKey] = value }
  }
  func expectedFramerate(_ value: Float) -> Self {
    compression { $0[AVVideoExpectedSourceFrameRateKey] = value }
  }
  func nonDroppableFramerate(_ value: Float) -> Self {
    compression { $0[AVVideoAverageNonDroppableFrameRateKey] = value }
  }
  private func compression(_ edit: (inout [String: Any]) -> ()) -> Self {
    var settings = settings
    var compression: [String: Any] = settings[AVVideoCompressionPropertiesKey] as? [String: Any] ?? [:]
    edit(&compression)
    settings[AVVideoCompressionPropertiesKey] = compression
    return VideoCompressorSettings(settings: settings)
  }
  
  private func set(_ key: String, _ value: Any) -> Self {
    var compressor = self
    compressor.settings[key] = value
    return compressor
  }
  enum ScalingMode {
    case fit, resize, aspectFit, aspectFill
    var rawValue: String {
      switch self {
      case .fit: return AVVideoScalingModeFit
      case .resize: return AVVideoScalingModeResize
      case .aspectFit: return AVVideoScalingModeResizeAspect
      case .aspectFill: return AVVideoScalingModeResizeAspectFill
      }
    }
  }
  enum Color {
    case hd, sd, wideGamut, wideGamut10Bit
    @available(iOS 16.0, *)
    case hdrLinear
    var rawValue: [String: String] {
      switch self {
      case .hd:
        return [
          AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
          AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
          AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ]
      case .sd:
        return [
          AVVideoColorPrimariesKey: AVVideoColorPrimaries_SMPTE_C,
          AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
          AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_601_4,
        ]
      case .wideGamut:
        return [
          AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
          AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
          AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ]
      case .wideGamut10Bit:
        return [
          AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
          AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
          AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ]
      case .hdrLinear:
        if #available(iOS 16.0, *) {
          return [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_Linear,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
          ]
        } else {
          return [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
          ]
        }
      }
    }
  }
}

public enum H264 {
  public enum ProfileLevel {
    case baseline30, baseline31, baseline41, baselineAuto
    case main30, main31, main32, main41, mainAuto
    case high40, high41, highAuto
    
    var rawValue: String {
      switch self {
      case .baseline30: return AVVideoProfileLevelH264Baseline30
      case .baseline31: return AVVideoProfileLevelH264Baseline31
      case .baseline41: return AVVideoProfileLevelH264Baseline41
      case .baselineAuto: return AVVideoProfileLevelH264BaselineAutoLevel
      case .main30: return AVVideoProfileLevelH264Main30
      case .main31: return AVVideoProfileLevelH264Main31
      case .main32: return AVVideoProfileLevelH264Main32
      case .main41: return AVVideoProfileLevelH264Main41
      case .mainAuto: return AVVideoProfileLevelH264MainAutoLevel
      case .high40: return AVVideoProfileLevelH264High40
      case .high41: return AVVideoProfileLevelH264High41
      case .highAuto: return AVVideoProfileLevelH264HighAutoLevel
      }
    }
  }
  public enum Entropy {
    case cavlc, cabac
    var rawValue: String {
      switch self {
      case .cavlc: return AVVideoH264EntropyModeCAVLC
      case .cabac: return AVVideoH264EntropyModeCABAC
      }
    }
  }
}
