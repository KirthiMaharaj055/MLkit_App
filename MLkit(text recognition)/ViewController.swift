//
//  ViewController.swift
//  MLkit(text recognition)
//
//  Created by Kirthi Maharaj on 2022/10/17.
//

import UIKit
import MLKit

class ViewController: UIViewController, UINavigationControllerDelegate {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var showText: UIButton!
    
    private lazy var textRecognizer = TextRecognizer.textRecognizer()
    var imagePicker = UIImagePickerController()
    var resultsText = ""
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        imageView.addSubview(annotationOverlayView)
        NSLayoutConstraint.activate([
          annotationOverlayView.topAnchor.constraint(equalTo: imageView.topAnchor),
          annotationOverlayView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
          annotationOverlayView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
          annotationOverlayView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
        ])
        
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
    }
    
    private func clearResults() {
      removeDetectionAnnotations()
      self.resultsText = ""
    }
    

    @IBAction func showTextTapped(_ sender: UIButton) {
        clearResults()
        runTextRecognition(with: imageView.image!)
    }
    
    
    
    @IBAction func PhotoLibrary(_ sender: UIButton) {
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: true)
    }
    
    
    func runTextRecognition(with image: UIImage) {
        let textReco = TextRecognizer.textRecognizer()
        let visionImage = VisionImage(image: image)
        
        visionImage.orientation = image.imageOrientation
        textRecognizer.process(visionImage) { features, error in
            self.processResult(visionImage, with: textReco, error: error)
        }
       
    }
  
    
    private func processResult(_ visionImage: VisionImage, with textRecognizer: TextRecognizer?, error: Error?) {
        removeDetectionAnnotations()
        weak var weakSelf = self
        
      textRecognizer?.process(visionImage) { text, error in
        guard let strongSelf = weakSelf else {
          print("Self is nil!")
          return
        }
          
        guard error == nil, let text = text else {
          let errorString = error?.localizedDescription ?? Constants.detectionNoResultsMessage
          strongSelf.resultsText = "Text recognizer failed with error: \(errorString)"
          strongSelf.showResults()
          return
        }
          
        // Blocks.
        for block in text.blocks {
          let transformedRect = block.frame.applying(strongSelf.transformMatrix())
          Utilities.addRectangle(transformedRect,to: strongSelf.annotationOverlayView,color: UIColor.purple)
            
            
          // Lines.
          for line in block.lines {
            let transformedRect = line.frame.applying(strongSelf.transformMatrix())
            Utilities.addRectangle(transformedRect,to:strongSelf.annotationOverlayView,color: UIColor.orange)
              
            // Elements.
            for element in line.elements {
              let transformedRect = element.frame.applying(strongSelf.transformMatrix())
              Utilities.addRectangle(transformedRect,to:strongSelf.annotationOverlayView,color: UIColor.green)
              let label = UILabel(frame: transformedRect)
              label.text = element.text
              label.adjustsFontSizeToFitWidth = true
              strongSelf.annotationOverlayView.addSubview(label)
            }
          }
        }
        strongSelf.resultsText += "\(text.text)\n"
        strongSelf.showResults()
      }
    }
    
    
    private func showResults() {
      let resultsAlertController = UIAlertController(title: "Show Text Results",message: nil,preferredStyle: .actionSheet)
      resultsAlertController.addAction(UIAlertAction(title: "OK", style: .destructive) { _ in
          resultsAlertController.dismiss(animated: true, completion: nil)})
      resultsAlertController.message = resultsText
      resultsAlertController.popoverPresentationController?.sourceView = self.view
      present(resultsAlertController, animated: true, completion: nil)
      print(resultsText)
    }
    
    private func transformMatrix() -> CGAffineTransform {
      guard let image = imageView.image else { return CGAffineTransform() }
      let imageViewWidth = imageView.frame.size.width
      let imageViewHeight = imageView.frame.size.height
      let imageWidth = image.size.width
      let imageHeight = image.size.height

      let imageViewAspectRatio = imageViewWidth / imageViewHeight
      let imageAspectRatio = imageWidth / imageHeight
      let scale = (imageViewAspectRatio > imageAspectRatio) ? imageViewHeight / imageHeight : imageViewWidth / imageWidth

      let scaledImageWidth = imageWidth * scale
      let scaledImageHeight = imageHeight * scale
      let xValue = (imageViewWidth - scaledImageWidth) / CGFloat(2.0)
      let yValue = (imageViewHeight - scaledImageHeight) / CGFloat(2.0)

      var transform = CGAffineTransform.identity.translatedBy(x: xValue, y: yValue)
      transform = transform.scaledBy(x: scale, y: scale)
      return transform
    }
    
    
    /// Removes the detection annotations from the annotation overlay view.
    private func removeDetectionAnnotations() {
      for annotationView in annotationOverlayView.subviews {
        annotationView.removeFromSuperview()
      }
    }
    
    /// An overlay view that displays detection annotations.
    private lazy var annotationOverlayView: UIView = {
      precondition(isViewLoaded)
      let annotationOverlayView = UIView(frame: .zero)
      annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
      return annotationOverlayView
    }()
    
    private func drawFrame(_ frame: CGRect, in color: UIColor, transform: CGAffineTransform) {
      let transformedRect = frame.applying(transform)
      Utilities.addRectangle(transformedRect, to: self.annotationOverlayView, color: color)
    }
    
   
    
    private func updateImageView(with image: UIImage) {
      let scaledImageWidth: CGFloat = 0.0
      let scaledImageHeight: CGFloat = 0.0
      DispatchQueue.global(qos: .userInitiated).async {
        var scaledImage = image.scaledImage(with: CGSize(width: scaledImageWidth, height:scaledImageHeight))
        scaledImage = scaledImage ?? image
        guard let finalImage = scaledImage else { return }
        DispatchQueue.main.async {
          self.imageView.image = finalImage
        }
      }
    }

    
}


extension ViewController: UIImagePickerControllerDelegate {

  func imagePickerController(_ picker: UIImagePickerController,didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
    
    let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)
    clearResults()
    if let pickedImage = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage{
      updateImageView(with: pickedImage)
    }
    dismiss(animated: true)
  }
}



fileprivate enum Constants {
  static let lineWidth: CGFloat = 3.0
  static let lineColor = UIColor.yellow.cgColor
  static let fillColor = UIColor.clear.cgColor
  static let smallDotRadius: CGFloat = 5.0
  static let largeDotRadius: CGFloat = 10.0
  static let detectionNoResultsMessage = "No results returned."

  static let images = ImageDisplay(file: "Image.jpg", name: "Image 1")
}

struct ImageDisplay {
  let file: String
  let name: String
}


private func convertFromUIImagePickerControllerInfoKeyDictionary(_ input:[UIImagePickerController.InfoKey: Any]) -> [String: Any] {
  return Dictionary(uniqueKeysWithValues: input.map { key, value in (key.rawValue, value) })
}


private func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
  return input.rawValue
}
