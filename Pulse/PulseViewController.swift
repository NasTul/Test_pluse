//
//  PulseViewController.swift
//  Pulse
//
//  Created by Athanasios Papazoglou on 18/7/20.
//  Copyright © 2020 Athanasios Papazoglou. All rights reserved.
//

import UIKit
import AVFoundation
import Charts



class PulseViewController: UIViewController, ChartViewDelegate {
    
    @IBOutlet weak var previewLayerShadowView: UIView!
    @IBOutlet weak var previewLayer: UIView!
    @IBOutlet weak var toplabel: UILabel!
    @IBOutlet weak var infolabel: UILabel!
    @IBOutlet weak var bpminfolabel: UILabel!
    @IBOutlet weak var testvalue: UILabel!
    
//    @IBOutlet weak var subview: UIView!
    private var validFrameCounter = 0
    private var heartRateManager: HeartRateManager!
    private var hueFilter = Filter()
    private var pulseDetector = PulseDetector()
    private var inputs: [CGFloat] = []
    private var measurementStartedFlag = false
    private var timer = Timer()
    let number1 = 0
    
    var i = 1
    
    @IBOutlet weak var linchartview: LineChartView!
    var timerForHRValue = Timer()
    var startDate : Date?
    
    init() {
        super.init(nibName: "PulseViewController", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initVideoCapture()
        
        infolabel.text = "Cover the back camera"
        infolabel.lineBreakMode = NSLineBreakMode.byWordWrapping;
        infolabel.textAlignment =
            NSTextAlignment.center;
        bpminfolabel.textAlignment =     NSTextAlignment.center;
        toplabel.textAlignment =
            NSTextAlignment.center;
        

        let set_a: LineChartDataSet = LineChartDataSet(entries:[ChartDataEntry(x: Double(0), y: Double(0))], label: "Hue Value")
        
        set_a.drawCirclesEnabled = false
        set_a.setColor(UIColor.red)
        set_a.drawValuesEnabled = false
        self.linchartview.pinchZoomEnabled = false
        self.linchartview.doubleTapToZoomEnabled = false
        
        
        linchartview.setVisibleYRange(minYRange: 4, maxYRange: -4, axis: .left)
        linchartview.scaleYEnabled = false
        
        
        self.linchartview.data = LineChartData(dataSets: [set_a])
        
//        timerForHRValue = Timer.scheduledTimer(timeInterval: 0.010, target: self, selector: #selector(updateCounter), userInfo: nil, repeats: true)
        
    }
    
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        print(entry)
    }
    


//
//    // add point
//
//    @objc func updateCounter() {
//
//
//        if (self.linchartview.data?.entryCount)! > 310 {
//            self.linchartview.data?.removeEntry(xValue: 0, dataSetIndex: 0)
//        }
//
//        self.linchartview.data?.addEntry(ChartDataEntry(x: Double(i), y: Double(number1)), dataSetIndex: 0)
//        self.linchartview.setVisibleXRange(minXRange: 1, maxXRange: 300)
//        self.linchartview.notifyDataSetChanged()
//        i = i + 1
//
//        print("add new msg")
//    }


    //MARK: -
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        return ""
    }
    
    

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        setupPreviewView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        initCaptureSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        deinitCaptureSession()
    }
    
    // MARK: - Setup Views
    private func setupPreviewView() {
        previewLayer.layer.cornerRadius = 60.0
        previewLayer.layer.masksToBounds = true

        previewLayerShadowView.backgroundColor = .clear
        previewLayerShadowView.layer.shadowColor = UIColor.blue.cgColor
        previewLayerShadowView.layer.shadowOpacity = 0.25
        previewLayerShadowView.layer.shadowOffset = CGSize(width: 0, height: 3)
        previewLayerShadowView.layer.shadowRadius = 3
        previewLayerShadowView.clipsToBounds = false
    }

    // MARK: - Frames Capture Methods
    private func initVideoCapture() {
        let specs = VideoSpec(fps: 30, size: CGSize(width: 300, height: 300))
        heartRateManager = HeartRateManager(cameraType: .back, preferredSpec: specs, previewContainer: previewLayer.layer)
        heartRateManager.imageBufferHandler = { [unowned self] (imageBuffer) in
            self.handle(buffer: imageBuffer)
        }
    }
    
    // MARK: - AVCaptureSession Helpers
    private func initCaptureSession() {
        heartRateManager.startCapture()
    }
    
    private func deinitCaptureSession() {
        heartRateManager.stopCapture()
        toggleTorch(status: false)
    }
    
    private func toggleTorch(status: Bool) {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        device.toggleTorch(on: status)
    }
    
    // MARK: - Measurement
    private func startMeasurement() {
        DispatchQueue.main.async {
            self.toggleTorch(status: true)
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] (timer) in
                guard let self = self else { return }
                let average = self.pulseDetector.getAverage()
                let pulse = 60.0/average
                if pulse == -60 {
                    UIView.animate(withDuration: 0.2, animations: {
                        self.bpminfolabel.alpha = 0
                    }) { (finished) in
                        self.bpminfolabel.isHidden = finished
                    }
                } else {
                    UIView.animate(withDuration: 0.2, animations: {
                        self.bpminfolabel.alpha = 1.0
                    }) { (_) in
                        self.bpminfolabel.isHidden = false
                        self.bpminfolabel.text = "\(lroundf(pulse)) BPM"
                    }
                }
            })
        }
    }
}

//MARK: - Handle Image Buffer
extension PulseViewController {
    fileprivate func handle(buffer: CMSampleBuffer) {
        var redmean:CGFloat = 0.0;
        var greenmean:CGFloat = 0.0;
        var bluemean:CGFloat = 0.0;
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(buffer)
        let cameraImage = CIImage(cvPixelBuffer: pixelBuffer!)

        let extent = cameraImage.extent
        let inputExtent = CIVector(x: extent.origin.x, y: extent.origin.y, z: extent.size.width, w: extent.size.height)
        let averageFilter = CIFilter(name: "CIAreaAverage",
                              parameters: [kCIInputImageKey: cameraImage, kCIInputExtentKey: inputExtent])!
        let outputImage = averageFilter.outputImage!

        let ctx = CIContext(options:nil)
        let cgImage = ctx.createCGImage(outputImage, from:outputImage.extent)!
        
        let rawData:NSData = cgImage.dataProvider!.data!
        let pixels = rawData.bytes.assumingMemoryBound(to: UInt8.self)
        let bytes = UnsafeBufferPointer<UInt8>(start:pixels, count:rawData.length)
        var BGRA_index = 0
        for pixel in UnsafeBufferPointer(start: bytes.baseAddress, count: bytes.count) {
            switch BGRA_index {
            case 0:
                bluemean = CGFloat (pixel)
            case 1:
                greenmean = CGFloat (pixel)
            case 2:
                redmean = CGFloat (pixel)
            case 3:
                break
            default:
                break
            }
            BGRA_index += 1
        }
        
        let hsv = rgb2hsv((red: redmean, green: greenmean, blue: bluemean, alpha: 1.0))
        // Do a sanity check to see if a finger is placed over the camera
        if (hsv.1 > 0.5 && hsv.2 > 0.5) {
            DispatchQueue.main.async {
                self.infolabel.text = "Waiting for measurement"
                self.toggleTorch(status: true)
                if !self.measurementStartedFlag {
                    self.startMeasurement()
                    self.measurementStartedFlag = true
                }
                self.testvalue.text = hsv.0.description;
                
                        if (self.linchartview.data?.entryCount)! > 150 {
                            self.linchartview.data?.removeEntry(xValue: 0, dataSetIndex: 0)
                        }
//                let filterd_data = self.hueFilter.processValue(value: Double(hsv.0))*100
                self.linchartview.data?.addEntry(ChartDataEntry(x: Double(self.i), y: Double(hsv.0)), dataSetIndex: 0)
                self.linchartview.data?.addEntry(ChartDataEntry(x: Double(self.i), y: Double(hsv.0)), dataSetIndex: 0)
//                self.linchartview.setVisibleXRange(minXRange: 1, maxXRange: 100)
                
                self.linchartview.notifyDataSetChanged()
                self.i = self.i + 1
                
                
                
            }
            
            
            validFrameCounter += 1
            inputs.append(hsv.0)
            // Filter the hue value - the filter is a simple BAND PASS FILTER that removes any DC component and any high frequency noise
            let filtered = hueFilter.processValue(value: Double(hsv.0))
            if validFrameCounter > 60 {
                self.pulseDetector.addNewValue(newVal: filtered, atTime: CACurrentMediaTime())
            }
            
            
        } else {
            validFrameCounter = 0
            measurementStartedFlag = false
            pulseDetector.reset()
            DispatchQueue.main.async {
                self.infolabel.text = "Cover the back camera"
            }
        }
    }
}
