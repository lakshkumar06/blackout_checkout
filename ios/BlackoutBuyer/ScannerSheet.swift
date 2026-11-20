import SwiftUI
import AVFoundation
import Vision

struct ScannerSheet: View {
  let onCode:(String)->Void
  @Environment(\.dismiss) private var dismiss
  @State private var captureID=0
  @State private var scanMessage="Point the camera at the merchant QR."
  var body:some View {
    NavigationStack {
      ZStack {Color.black.ignoresSafeArea();VStack(spacing:20){CameraScanner(captureID:captureID,onCode:{onCode($0);dismiss()},onError:{scanMessage=$0}).clipShape(RoundedRectangle(cornerRadius:20)).frame(height:390);Text(scanMessage).foregroundStyle(.white).multilineTextAlignment(.center);Spacer();Button {captureID += 1} label:{Circle().stroke(.white,lineWidth:3).frame(width:76,height:76).overlay(Circle().fill(.white).frame(width:58,height:58))}.accessibilityLabel("Capture and scan QR code").padding(.bottom,20)}.padding(24)}
      .navigationTitle("Scan to pay").navigationBarTitleDisplayMode(.inline).toolbar {ToolbarItem(placement:.topBarTrailing){Button("Cancel"){dismiss()}}}
    }
  }
}
struct CameraScanner:UIViewRepresentable {
  let captureID:Int
  let onCode:(String)->Void
  let onError:(String)->Void
  func makeCoordinator()->Coordinator{Coordinator(onCode:onCode,onError:onError)}
  func makeUIView(context:Context)->UIView {
    let view=PreviewView();view.backgroundColor = .black
    let coordinator=context.coordinator
    switch AVCaptureDevice.authorizationStatus(for:.video) {
    case .authorized: coordinator.configure(view)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for:.video) { allowed in
        DispatchQueue.main.async { if allowed {coordinator.configure(view)} else {view.showMessage("Allow camera access in Settings to scan an invoice.")} }
      }
    default: view.showMessage("Allow camera access in Settings to scan an invoice.")
    }
    return view
  }
  func updateUIView(_ view:UIView,context:Context){
    if captureID != context.coordinator.lastCaptureID {
      context.coordinator.lastCaptureID=captureID
      context.coordinator.capture()
    }
  }
  static func dismantleUIView(_ view:UIView,coordinator:Coordinator){let session=coordinator.session;DispatchQueue.global(qos:.userInitiated).async {session?.stopRunning()}}
  final class PreviewView:UIView {
    override class var layerClass:AnyClass {AVCaptureVideoPreviewLayer.self}
    var previewLayer:AVCaptureVideoPreviewLayer {layer as! AVCaptureVideoPreviewLayer}
    func showMessage(_ text:String){
      let label=UILabel();label.text=text;label.textColor = .white;label.textAlignment = .center;label.numberOfLines=0
      label.translatesAutoresizingMaskIntoConstraints=false;addSubview(label)
      NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo:centerXAnchor),label.centerYAnchor.constraint(equalTo:centerYAnchor),label.widthAnchor.constraint(lessThanOrEqualTo:widthAnchor,constant:-32)])
    }
  }
  final class Coordinator:NSObject,AVCaptureMetadataOutputObjectsDelegate {
    let onCode:(String)->Void;let onError:(String)->Void
    var session:AVCaptureSession?;var photoOutput:AVCapturePhotoOutput?;var found=false;var lastCaptureID=0;var capturing=false
    init(onCode:@escaping(String)->Void,onError:@escaping(String)->Void){self.onCode=onCode;self.onError=onError}
    func configure(_ view:PreviewView){
      guard session == nil else{return}
      let capture=AVCaptureSession()
      guard let camera=AVCaptureDevice.default(.builtInWideAngleCamera,for:.video,position:.back),let input=try? AVCaptureDeviceInput(device:camera),capture.canAddInput(input) else {view.showMessage("Camera unavailable. Enable camera access in Settings.");return}
      capture.addInput(input)
      let output=AVCaptureMetadataOutput()
      guard capture.canAddOutput(output) else {view.showMessage("QR scanning unavailable. Try reopening the scanner.");return}
      capture.addOutput(output);output.setMetadataObjectsDelegate(self,queue:.main);output.metadataObjectTypes=[.qr]
      let photo=AVCapturePhotoOutput()
      if capture.canAddOutput(photo){capture.addOutput(photo);photoOutput=photo}
      session=capture;view.previewLayer.videoGravity = .resizeAspectFill;view.previewLayer.session=capture
      DispatchQueue.global(qos:.userInitiated).async {capture.startRunning()}
    }
    func capture(){
      guard !found,!capturing,session?.isRunning == true,let photoOutput else {onError("Camera is starting. Try again in a moment.");return}
      capturing=true;photoOutput.capturePhoto(with:AVCapturePhotoSettings(),delegate:self)
    }
    func metadataOutput(_ output:AVCaptureMetadataOutput,didOutput objects:[AVMetadataObject],from connection:AVCaptureConnection){guard !found,let qr=objects.first as? AVMetadataMachineReadableCodeObject,let value=qr.stringValue else{return};found=true;onCode(value)}
  }
}
extension CameraScanner.Coordinator:AVCapturePhotoCaptureDelegate {
  func photoOutput(_ output:AVCapturePhotoOutput,didFinishProcessingPhoto photo:AVCapturePhoto,error:Error?){
    capturing=false
    guard !found,error == nil,let data=photo.fileDataRepresentation() else {onError("Could not capture the QR. Try again.");return}
    let request=VNDetectBarcodesRequest();request.symbologies=[.qr]
    do {
      try VNImageRequestHandler(data:data,options:[:]).perform([request])
      guard let code=request.results?.first?.payloadStringValue else {onError("No QR code found. Move closer and try again.");return}
      found=true;onCode(code)
    } catch {onError("Could not read the QR. Try again.")}
  }
}
