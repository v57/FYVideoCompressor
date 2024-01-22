import Foundation
import AVFoundation
import CoreMedia

public extension URL {
  func compressVideo(_ config: FYVideoCompressor.CompressionConfig, frameReducer: VideoFrameReducer = .evenlySpaced, progress: ((CMTime, CMTime) -> Void)? = nil, completion: @escaping (Result<URL, Error>) -> Void) {
    FYVideoCompressor().compressVideo(self, config: config, frameReducer: frameReducer, progress: progress, completion: completion)
  }
  @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
  @discardableResult
  func compressVideo(_ config: FYVideoCompressor.CompressionConfig, frameReducer: VideoFrameReducer = .evenlySpaced, progress: ((CMTime, CMTime) -> Void)? = nil) async throws -> URL {
    try await withCheckedThrowingContinuation { continuation in
      compressVideo(config, frameReducer: frameReducer, progress: progress, completion: continuation.resume)
    }
  }
}

// sample video https://download.blender.org/demo/movies/BBB/

/// A high-performance, flexible and easy to use Video compressor library written by Swift.
/// Using hardware-accelerator APIs in AVFoundation.
public class FYVideoCompressor {
  public enum VideoCompressorError: Error, LocalizedError {
    case noVideo
    case outputPathNotValid(_ path: URL)
    
    public var errorDescription: String? {
      switch self {
      case .noVideo:
        return "No video"
      case .outputPathNotValid(let path):
        return "Output path is invalid: \(path)"
      }
    }
  }
  
  // Compression Encode Parameters
  public struct CompressionConfig {
    public static func h264(fps: Float = 24, bitrate: Int = 1_000_000, size: CGSize? = nil, maxKeyframeInterval: Int = 10, frameReordering: Bool = true, profile: H264.ProfileLevel = .highAuto, entropy: H264.Entropy = .cabac) -> Self {
      let settings = VideoCompressorSettings()
        .codec(.h264)
        .compression(bitrate: Float(bitrate), frameReordering: frameReordering, profile: profile, entropy: entropy)
        .keyframeInterval(maxKeyframeInterval)
      var config = CompressionConfig(settings: settings, fps: fps, fileType: .mp4, scale: size)
      config.bitrate = Float(bitrate)
      return config
    }
    public static func hevc(fps: Float, quality: Float, size: CGSize?, frameReordering: Bool, profile: Hevc.ProfileLevel = .main) -> Self {
      other(codec: .hevc, fps: fps, quality: quality, size: size, frameReordering: frameReordering)
    }
    public static func other(codec: AVVideoCodecType, fps: Float, quality: Float, size: CGSize?, frameReordering: Bool = true, profile: Hevc.ProfileLevel = .main) -> Self {
      let settings = VideoCompressorSettings()
        .codec(codec)
        .compression(quality: quality, frameReordering: frameReordering, profile: profile)
      var config = CompressionConfig(settings: settings, fps: fps, fileType: .mov, scale: size)
      config.quality = quality
      return config
    }
    
    public var settings: VideoCompressorSettings
    
    /// If video's fps less than this value, this value will be ignored. Default is 24.
    public var fps: Float
    
    //Tag: audio
    
    /// Sample rate must be between 8.0 and 192.0 kHz inclusive
    /// Default 44100
    public var audioSampleRate: Int = 44100
    
    /// Default is 128_000
    /// If the input audio bitrate is less than this value, it will be ignored.
    public var audioBitrate: Int = 128_000
    
    /// Default is mp4
    public var fileType: AVFileType
    
    /// Scale (resize) the input video
    /// 1. If you need to simply resize your video to a specific size (e.g 320×240), you can use the scale: CGSize(width: 320, height: 240)
    /// 2. If you want to keep the aspect ratio, you need to specify only one component, either width or height, and set the other component to -1
    ///    e.g CGSize(width: 320, height: -1)
    public var scale: CGSize?
    
    ///  compressed video will be moved to this path. If no value is set, `FYVideoCompressor` will create it for you.
    ///  Default is nil.
    public var outputPath: URL?
    
    var bitrate: Float?
    var quality: Float?
    
    init(settings: VideoCompressorSettings, fps: Float, fileType: AVFileType, scale: CGSize?) {
      self.settings = settings
      self.fps = fps
      self.fileType = fileType
      self.scale = scale
    }
    
    public func audio(bitrate: Int, sampleRate: Int = 44100) -> Self {
      var a = self
      a.audioBitrate = bitrate
      a.audioSampleRate = sampleRate
      return a
    }
    public func output(_ url: URL) -> Self {
      var a = self
      a.outputPath = url
      return a
    }
  }
  
  private let group = DispatchGroup()
  private let videoCompressQueue = DispatchQueue.init(label: "com.video.compress_queue")
  private lazy var audioCompressQueue = DispatchQueue.init(label: "com.audio.compress_queue")
  private var reader: AVAssetReader?
  private var writer: AVAssetWriter?
  private var compressVideoPaths: [URL] = []
  
  @available(*, deprecated, renamed: "init()", message: "In the case of batch compression, singleton causes a crash, be sure to use init method - init()")
  static public let shared: FYVideoCompressor = FYVideoCompressor()
  
  public var videoFrameReducer: VideoFrameReducer!
  
  public init() { }
  
  /// Compress Video with config.
  public func compressVideo(_ url: URL, config: CompressionConfig, frameReducer: VideoFrameReducer = .evenlySpaced, progress: ((CMTime, CMTime) -> Void)? = nil, completion: @escaping (Result<URL, Error>) -> Void) {
    self.videoFrameReducer = frameReducer
    
    let asset = AVAsset(url: url)
    // setup
    guard let videoTrack = asset.tracks(withMediaType: .video).first else {
      completion(.failure(VideoCompressorError.noVideo))
      return
    }
    
    let targetSize = calculateSizeWithScale(config.scale, originalSize: videoTrack.naturalSize)
    let videoSettings = config.settings.width(targetSize.width).height(targetSize.height).settings
    
    var audioTrack: AVAssetTrack?
    var audioSettings: [String: Any]?
    
    if let adTrack = asset.tracks(withMediaType: .audio).first {
      audioTrack = adTrack
      let targetAudioBitrate: Float
      if Float(config.audioBitrate) < adTrack.estimatedDataRate {
        targetAudioBitrate = Float(config.audioBitrate)
      } else {
        targetAudioBitrate = 64_000
      }
      
      let targetSampleRate: Int
      if config.audioSampleRate < 8000 {
        targetSampleRate = 8000
      } else if config.audioSampleRate > 192_000 {
        targetSampleRate = 192_000
      } else {
        targetSampleRate = config.audioSampleRate
      }
      audioSettings = createAudioSettingsWithAudioTrack(adTrack, bitrate: targetAudioBitrate, sampleRate: targetSampleRate)
    }
    
    var _outputPath: URL
    if let outputPath = config.outputPath {
      _outputPath = outputPath
    } else {
      _outputPath = FileManager.tempDirectory(with: "CompressedVideo")
    }
    
#if DEBUG
    print("🎬: \(url.sizePerMB())MB, \(Int(videoTrack.naturalSize.width))x\(Int(videoTrack.naturalSize.height)), \(Int(videoTrack.estimatedDataRate / 1024)) kb/s, \(videoTrack.nominalFrameRate) fps")
    if let bitrate = config.bitrate {
      print("📦: \(Int(targetSize.width))x\(Int(targetSize.height)), \(Int(bitrate / 1024)) kb/s, \(config.fps) fps")
    } else if let quality = config.quality {
      print("📦: \(Int(targetSize.width))x\(Int(targetSize.height)), \(quality)q, \(config.fps) fps")
    }
#endif
    
    let progress = CompressionProgress(duration: asset.duration, callback: progress)
    _compress(asset: asset,
              fileType: config.fileType,
              videoTrack,
              videoSettings,
              audioTrack,
              audioSettings,
              targetFPS: config.fps,
              outputPath: _outputPath,
              progress: progress,
              completion: completion)
  }
  
  /// Remove all cached compressed videos
  public func removeAllCompressedVideo() {
    var candidates = [Int]()
    for index in 0..<compressVideoPaths.count {
      do {
        try FileManager.default.removeItem(at: compressVideoPaths[index])
        candidates.append(index)
      } catch {
        print("❌ remove compressed item error: \(error)")
      }
    }
    
    for candidate in candidates.reversed() {
      compressVideoPaths.remove(at: candidate)
    }
  }
  
  // MARK: - Private methods
  private func _compress(asset: AVAsset,
                         fileType: AVFileType,
                         _ videoTrack: AVAssetTrack,
                         _ videoSettings: [String: Any],
                         _ audioTrack: AVAssetTrack?,
                         _ audioSettings: [String: Any]?,
                         targetFPS: Float,
                         outputPath: URL,
                         progress: CompressionProgress,
                         completion: @escaping (Result<URL, Error>) -> Void) {
    // video
    let videoOutput = AVAssetReaderTrackOutput.init(track: videoTrack,
                                                    outputSettings: [kCVPixelBufferPixelFormatTypeKey as String:
                                                                      kCVPixelFormatType_32BGRA])
    let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    videoInput.transform = videoTrack.preferredTransform // fix output video orientation
    do {
      guard FileManager.default.isValidDirectory(atPath: outputPath) else {
        completion(.failure(VideoCompressorError.outputPathNotValid(outputPath)))
        return
      }
      
      var outputPath = outputPath
      let videoName = UUID().uuidString + ".\(fileType.fileExtension)"
      outputPath.appendPathComponent("\(videoName)")
      
      // store urls for deleting
      compressVideoPaths.append(outputPath)
      
      let reader = try AVAssetReader(asset: asset)
      let writer = try AVAssetWriter(url: outputPath, fileType: fileType)
      self.reader = reader
      self.writer = writer
      
      // video output
      if reader.canAdd(videoOutput) {
        reader.add(videoOutput)
        videoOutput.alwaysCopiesSampleData = false
      }
      if writer.canAdd(videoInput) {
        writer.add(videoInput)
      }
      
      // audio output
      var audioInput: AVAssetWriterInput?
      var audioOutput: AVAssetReaderTrackOutput?
      if let audioTrack = audioTrack, let audioSettings = audioSettings {
        // Specify the number of audio channels we want when decompressing the audio from the asset to avoid error when handling audio data.
        // It really matters when the audio has more than 2 channels, e.g: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'
        audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM,
                                                                           AVNumberOfChannelsKey: 2])
        let adInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput = adInput
        if reader.canAdd(audioOutput!) {
          reader.add(audioOutput!)
        }
        if writer.canAdd(adInput) {
          writer.add(adInput)
        }
      }
      
#if DEBUG
      let startTime = Date()
#endif
      // start compressing
      reader.startReading()
      writer.startWriting()
      writer.startSession(atSourceTime: CMTime.zero)
      
      // output video
      group.enter()
      
      let reduceFPS = targetFPS < videoTrack.nominalFrameRate
      
      let frameIndexArr = videoFrameReducer.reduce(originalFPS: videoTrack.nominalFrameRate,
                                                   to: targetFPS,
                                                   with: Float(videoTrack.asset?.duration.seconds ?? 0.0))
      
      outputVideoDataByReducingFPS(videoInput: videoInput,
                                   videoOutput: videoOutput,
                                   frameIndexArr: reduceFPS ? frameIndexArr : [], progress: progress) {
        self.group.leave()
      }
      
      
      // output audio
      if let realAudioInput = audioInput, let realAudioOutput = audioOutput {
        group.enter()
        // todo: drop audio sample buffer
        outputAudioData(realAudioInput, audioOutput: realAudioOutput, frameIndexArr: []) {
          self.group.leave()
        }
      }
      
      // completion
      group.notify(queue: .main) {
        switch writer.status {
        case .writing, .completed:
          writer.finishWriting {
#if DEBUG
            let endTime = Date()
            let elapse = endTime.timeIntervalSince(startTime)
            print("🎉 \(elapse), \(outputPath.sizePerMB())MB")
            print("📍 \(outputPath)")
#endif
            DispatchQueue.main.sync {
              completion(.success(outputPath))
            }
          }
        default:
          completion(.failure(writer.error!))
        }
      }
      
    } catch {
      completion(.failure(error))
    }
    
  }
  
  private func createVideoSettingsWithBitrate(_ bitrate: Float, maxKeyFrameInterval: Int, size: CGSize) -> [String: Any] {
    return [AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
           AVVideoHeightKey: size.height,
      AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: bitrate,
                                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                                 AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
                             AVVideoMaxKeyFrameIntervalKey: maxKeyFrameInterval
                                 ]
    ]
  }
  
  private func createAudioSettingsWithAudioTrack(_ audioTrack: AVAssetTrack, bitrate: Float, sampleRate: Int) -> [String: Any] {
    let format = kAudioFormatMPEG4AAC
    let channels = 2
#if DEBUG
    if let audioFormatDescs = audioTrack.formatDescriptions as? [CMFormatDescription], let formatDescription = audioFormatDescs.first {
      if let stream = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee {
        print("🔊 \(stream.mFormatID) \(stream.mChannelsPerFrame)c, \(stream.mSampleRate) Hz, \(audioTrack.estimatedDataRate / 1024) kb/s")
      } else {
        print("🔊 \(audioTrack.estimatedDataRate / 1024) kb/s")
      }
      print("📦 \(format) \(channels)c, \(sampleRate) Hz, \(bitrate / 1024) kb/s")
    }
#endif
    
    var audioChannelLayout = AudioChannelLayout()
    memset(&audioChannelLayout, 0, MemoryLayout<AudioChannelLayout>.size)
    audioChannelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo
    
    return [
      AVFormatIDKey: format,
      AVSampleRateKey: sampleRate,
      AVEncoderBitRateKey: bitrate,
      AVNumberOfChannelsKey: channels,
      AVChannelLayoutKey: Data(bytes: &audioChannelLayout, count: MemoryLayout<AudioChannelLayout>.size)
    ]
  }
  
  private func outputVideoDataByReducingFPS(videoInput: AVAssetWriterInput,
                                            videoOutput: AVAssetReaderTrackOutput,
                                            frameIndexArr: [Int],
                                            progress: CompressionProgress,
                                            completion: @escaping(() -> Void)) {
    var counter = 0
    var index = 0
    
    videoInput.requestMediaDataWhenReady(on: videoCompressQueue) {
      while videoInput.isReadyForMoreMediaData {
        if let buffer = videoOutput.copyNextSampleBuffer() {
          progress.send(progress: CMSampleBufferGetPresentationTimeStamp(buffer))
          if frameIndexArr.isEmpty {
            videoInput.append(buffer)
          } else { // reduce FPS
            // append first frame
            if index < frameIndexArr.count {
              let frameIndex = frameIndexArr[index]
              if counter == frameIndex {
                index += 1
                videoInput.append(buffer)
              }
              counter += 1
            } else {
              // Drop this frame
              CMSampleBufferInvalidate(buffer)
            }
          }
          
        } else {
          videoInput.markAsFinished()
          completion()
          break
        }
      }
    }
  }
  
  private func outputAudioData(_ audioInput: AVAssetWriterInput,
                               audioOutput: AVAssetReaderTrackOutput,
                               frameIndexArr: [Int],
                               completion:  @escaping(() -> Void)) {
    
    var counter = 0
    var index = 0
    
    audioInput.requestMediaDataWhenReady(on: audioCompressQueue) {
      while audioInput.isReadyForMoreMediaData {
        if let buffer = audioOutput.copyNextSampleBuffer() {
          
          if frameIndexArr.isEmpty {
            audioInput.append(buffer)
            counter += 1
          } else {
            // append first frame
            if index < frameIndexArr.count {
              let frameIndex = frameIndexArr[index]
              if counter == frameIndex {
                index += 1
                audioInput.append(buffer)
              }
              counter += 1
            } else {
              // Drop this frame
              CMSampleBufferInvalidate(buffer)
            }
          }
          
        } else {
          audioInput.markAsFinished()
          completion()
          break
        }
      }
    }
  }
  
  // MARK: - Calculation
  
  func calculateSizeWithScale(_ scale: CGSize?, originalSize: CGSize) -> CGSize {
    guard let scale = scale else {
      return originalSize
    }
    if scale.width == -1 && scale.height == -1 {
      return originalSize
    } else if scale.width != -1 && scale.height != -1 {
      return scale
    } else if scale.width == -1 {
      let targetWidth = Int(scale.height * originalSize.width / originalSize.height)
      return CGSize(width: CGFloat(targetWidth), height: scale.height)
    } else {
      let targetHeight = Int(scale.width * originalSize.height / originalSize.width)
      return CGSize(width: scale.width, height: CGFloat(targetHeight))
    }
  }
}

private struct CompressionProgress {
  var duration: CMTime
  var callback: ((CMTime, CMTime) -> ())?
  func send(progress: CMTime) {
    callback?(duration, progress)
  }
}
