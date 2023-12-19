import XCTest
@testable import FYVideoCompressor
import AVFoundation

final class FYVideoCompressorTests: XCTestCase {
    // sample video websites: https://file-examples.com/index.php/sample-video-files/sample-mp4-files/
    // https://www.learningcontainer.com/mp4-sample-video-files-download/#Sample_MP4_Video_File_Download_for_Testing
    
    // http://clips.vorwaerts-gmbh.de/VfE_html5.mp4  5.3
//    static let testVideoURL = URL(string: "https://file-examples.com/storage/fe92e8a57762aaf72faee17/2017/04/file_example_MP4_1280_10MG.mp4")! // video size 5.3M
    
//    static let testVideoURL = URL(string: "https://www.learningcontainer.com/wp-content/uploads/2020/05/sample-mov-file.mov")!

// https://jsoncompare.org/LearningContainer/SampleFiles/Video/MP4/Sample-MP4-Video-File-for-Testing.mp4
    static let testVideoURL = URL(string: "https://jsoncompare.org/LearningContainer/SampleFiles/Video/MP4/Sample-MP4-Video-File-for-Testing.mp4")!
    
//    let localVideoURL = Bundle.module.url(forResource: "sample2", withExtension: "MOV")!
    
    let sampleVideoPath: URL = FileManager.tempDirectory(with: "UnitTestSampleVideo").appendingPathComponent("sample.mp4")
//    var compressedVideoPath: URL?
    var compressedVideoPaths: [URL] = []
    
    var task: URLSessionDataTask?
    
    let compressor = FYVideoCompressor()
    
    override func setUpWithError() throws {
        let expectation = XCTestExpectation(description: "video cache downloading remote video")
        var error: Error?
        downloadSampleVideo { result in
            switch result {
            case .failure(let _error):
                print("failed to download sample video: \(_error)")
                error = _error
            case .success(let path):
                print("sample video downloaded at path: \(path)")
                expectation.fulfill()
            }
        }
        if let error = error {
            throw error
        }
        wait(for: [expectation], timeout: 100)
    }
    
    override func tearDownWithError() throws {
        task?.cancel()
        
        try FileManager.default.removeItem(at: sampleVideoPath)
        
        for path in compressedVideoPaths {
            try FileManager.default.removeItem(at: path)
        }
    }
    
    func testAVFileTypeExtension() {
        let mp4Extension = AVFileType("public.mpeg-4")
        XCTAssertEqual(mp4Extension.fileExtension, "mp4")
        
        let movExtension = AVFileType("com.apple.quicktime-movie")
        XCTAssertEqual(movExtension.fileExtension, "mov")
    }
    
    func testCompressVideo() {
        let expectation = XCTestExpectation(description: "compress video")
        
//        var sampleVideoPath = localVideoURL // sampleVideoPath
        var compressedVideoPath: URL!
        compressor.compressVideo(sampleVideoPath, config: .h264(), frameReducer: ReduceFrameRandomly()) { result in
            switch result {
            case .success(let video):
                compressedVideoPath = video
                expectation.fulfill()
            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
        }
        wait(for: [expectation], timeout: 30)
        XCTAssertNotNil(compressedVideoPath)
        compressedVideoPaths.append(compressedVideoPath)
        XCTAssertTrue(sampleVideoPath.sizePerMB() > compressedVideoPath.sizePerMB())
    }
    
    func testCompressVideoWithScale() {
        let expectation = XCTestExpectation(description: "compress video")
        
        var compressedVideoPath: URL!
        compressor.compressVideo(sampleVideoPath, config: .h264(size: CGSize(width: -1, height: -1))) { result in
            switch result {
            case .success(let video):
                compressedVideoPath = video
                expectation.fulfill()
            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
        }
        
        wait(for: [expectation], timeout: 30)
        XCTAssertNotNil(compressedVideoPath)
        compressedVideoPaths.append(compressedVideoPath)
        XCTAssertTrue(self.sampleVideoPath.sizePerMB() > compressedVideoPath.sizePerMB())
    }
    
    func testCompressVideoWithVideoBitrate() {
        let expectation = XCTestExpectation(description: "compress video")
        
        var compressedVideoPath: URL!
        compressor.compressVideo(sampleVideoPath, config: .h264(bitrate: 200000)) { result in
            switch result {
            case .success(let video):
                compressedVideoPath = video
                expectation.fulfill()
            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
        }
        
        wait(for: [expectation], timeout: 30)
        XCTAssertNotNil(compressedVideoPath)
        compressedVideoPaths.append(compressedVideoPath)
        XCTAssertTrue(self.sampleVideoPath.sizePerMB() > compressedVideoPath.sizePerMB())
    }
    
    func testCompressVideoWithVideomaxKeyFrameInterval() {
        let expectation = XCTestExpectation(description: "compress video")
        
        var compressedVideoPath: URL!
        compressor.compressVideo(sampleVideoPath, config: .h264(maxKeyframeInterval: 1)) { result in
            switch result {
            case .success(let video):
                compressedVideoPath = video
                expectation.fulfill()
            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
        }
        
        wait(for: [expectation], timeout: 30)
        XCTAssertNotNil(compressedVideoPath)
        
        compressedVideoPaths.append(compressedVideoPath)
        XCTAssertTrue(self.sampleVideoPath.sizePerMB() > compressedVideoPath.sizePerMB())
    }
    
    func testCompressVideoWithFPS() {
        let expectation = XCTestExpectation(description: "compress video")
        
        var compressedVideoPath: URL!
        compressor.compressVideo(sampleVideoPath, config: .h264(fps: 24)) { result in
            switch result {
            case .success(let video):
                compressedVideoPath = video
                expectation.fulfill()
            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
        }
        
        wait(for: [expectation], timeout: 30)
        XCTAssertNotNil(compressedVideoPath)
        
        compressedVideoPaths.append(compressedVideoPath)
        XCTAssertTrue(self.sampleVideoPath.sizePerMB() > compressedVideoPath.sizePerMB())
    }
    
    func testCompressVideoWithAudioSampleRate() {
        let expectation = XCTestExpectation(description: "compress video")
        
        var compressedVideoPath: URL!
        compressor.compressVideo(sampleVideoPath, config: .h264().audio(bitrate: 128000, sampleRate: 44100)) { result in
            switch result {
            case .success(let video):
                compressedVideoPath = video
                expectation.fulfill()
            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
        }
        
        wait(for: [expectation], timeout: 30)
        XCTAssertNotNil(compressedVideoPath)
        compressedVideoPaths.append(compressedVideoPath)
        XCTAssertTrue(self.sampleVideoPath.sizePerMB() > compressedVideoPath.sizePerMB())
    }
    
    func testCompressVideoWithAudioBitrate() {
        let expectation = XCTestExpectation(description: "compress video")
        
        var compressedVideoPath: URL!
        compressor.compressVideo(sampleVideoPath, config: .h264().audio(bitrate: 128000)) { result in
            switch result {
            case .success(let video):
                compressedVideoPath = video
                expectation.fulfill()
            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
        }
        
        wait(for: [expectation], timeout: 30)
        XCTAssertNotNil(compressedVideoPath)
        compressedVideoPaths.append(compressedVideoPath)
        XCTAssertTrue(self.sampleVideoPath.sizePerMB() > compressedVideoPath.sizePerMB())
    }
    
    func testTargetVideoSizeWithConfig() {
        let scale1 = compressor.calculateSizeWithScale(CGSize(width: -1, height: 224), originalSize: CGSize(width: 1920, height: 1080))
        XCTAssertEqual(scale1, CGSize(width: 398, height: 224))
        
        let scale2 = compressor.calculateSizeWithScale(CGSize(width: 640, height: -1), originalSize: CGSize(width: 1920, height: 1080))
        XCTAssertEqual(scale2, CGSize(width: 640, height: 360))
    }
    
    // MARK: Download sample video
    func downloadSampleVideo(_ completion: @escaping ((Result<URL, Error>) -> Void)) {
        if FileManager.default.fileExists(atPath: self.sampleVideoPath.path) {
            completion(.success(self.sampleVideoPath))
        } else {
            request(Self.testVideoURL) { result in
                switch result {
                case .success(let data):
                    do {
                        try (data as NSData).write(to: self.sampleVideoPath, options: NSData.WritingOptions.atomic)
                        completion(.success(self.sampleVideoPath))
                    } catch {
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func request(_ url: URL, completion: @escaping ((Result<Data, Error>) -> Void)) {
        if task != nil {
            task?.cancel()
        }
        
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                self.task = nil
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                self.task = nil
                return
            }

            if (200...299).contains(httpResponse.statusCode) {
                if let data = data {
                    DispatchQueue.main.async {
                        self.task = nil
                        completion(.success(data))
                    }
                }
            } else {
                let domain = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                let error = NSError(domain: domain, code: httpResponse.statusCode, userInfo: nil)
                DispatchQueue.main.async {
                    self.task = nil
                    completion(.failure(error))
                }
            }
        }
        task.resume()
        self.task = task
    }
}
