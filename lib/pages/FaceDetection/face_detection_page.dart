import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';
import './/pages/FaceDetection/face_detection_live_page.dart';
import './/utils/helpers.dart';

class FaceDetectionPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String title;
  const FaceDetectionPage({
    Key? key,
    required this.cameras,
    required this.title,
  }) : super(key: key);

  @override
  _FaceDetectionPageState createState() => _FaceDetectionPageState();
}

class _FaceDetectionPageState extends State<FaceDetectionPage> {
  late FaceDetector faceDetector;
  late List<Face> faces;
  late ImagePicker imagePicker;
  Future<File>? imageFile;
  File? _image;
  List<String> result = [];
  var image;

  @override
  void initState() {
    super.initState();
    imagePicker = ImagePicker();
    faceDetector = GoogleMlKit.vision.faceDetector(
      FaceDetectorOptions(
        enableClassification: true,
        minFaceSize: 0.1,
        mode: FaceDetectorMode.fast,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    faceDetector.close();
  }

  doFaceDetection() async {
    result.clear();
    final inputImage = InputImage.fromFile(_image!);
    faces = await faceDetector.processImage(inputImage);
    print(faces.length.toString() + " faces");
    drawRectangleAroundFaces();
    if (faces.length > 0) {
      for (var face in faces) {
        if (face.smilingProbability! > 0.5) {
          result.add("Smiling");
        } else {
          result.add("Serious");
        }
      }
    }
  }

  drawRectangleAroundFaces() async {
    image = await _image!.readAsBytes();
    image = await decodeImageFromList(image);
    setState(() {
      faces;
      result;
    });
  }

  _getImageFromCamera() async {
    PickedFile? pickedFile = await imagePicker.getImage(
      source: ImageSource.camera,
    );

    setState(() {
      _image = pickedFile != null ? File(pickedFile.path) : _image;
      if (_image != null) {
        doFaceDetection();
      }
    });
  }

  _getImageFromGallery() async {
    PickedFile? pickedFile = await imagePicker.getImage(
      source: ImageSource.gallery,
    );
    setState(() {
      _image = pickedFile != null ? File(pickedFile.path) : _image;
      if (_image != null) {
        doFaceDetection();
      }
    });
  }

  _getLiveCamera() {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceDetectionLivePage(
          cameras: widget.cameras,
          title: "Face Detection Live",
        ),
      ),
    );
  }

  imageNull() {
    if (image == null) {
      return 200.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Helpers.showCameraOptionsDialog(
            context: context,
            camera: _getImageFromCamera,
            gallery: _getImageFromGallery,
            live: _getLiveCamera,
          );
        },
        child: Icon(Icons.camera_alt),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: imageNull(),
                  height: imageNull(),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      // isLive
                      //     ? controller.value.isInitialized
                      //         ? FittedBox(
                      //             child: Container(
                      //               width: _liveImage.width.toDouble(),
                      //               height: _liveImage.height.toDouble() * 2,
                      //               child: AspectRatio(
                      //                 aspectRatio: controller.value.aspectRatio,
                      //                 child: CameraPreview(controller),
                      //               ),
                      //             ),
                      //           )
                      //         : Icon(
                      //             Icons.camera_alt,
                      //             color: Colors.grey[500],
                      // )
                      // :
                      _image != null && image != null
                          ? FittedBox(
                              child: Container(
                                width: image.width.toDouble(),
                                height: image.height.toDouble(),
                                child: CustomPaint(
                                  painter: FacePainter(
                                    rect: faces,
                                    imageFile: image,
                                  ),
                                ),
                              ),
                            )
                          : Icon(
                              Icons.camera_alt,
                              color: Colors.grey[500],
                            ),
                ),
                Container(
                  margin: EdgeInsets.only(top: 20),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: result.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(
                          result[index],
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  List<Face>? rect;
  var imageFile;
  FacePainter({required this.rect, required this.imageFile});

  @override
  void paint(Canvas canvas, Size size) {
    if (imageFile != null) {
      canvas.drawImage(imageFile, Offset.zero, Paint());
    }
    Paint p = Paint();
    p.color = Colors.red;
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 4;

    if (rect != null) {
      for (Face rectangle in rect!) {
        canvas.drawRect(rectangle.boundingBox, p);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class FaceDetectorPainter extends CustomPainter {
  FaceDetectorPainter(this.absoluteImageSize, this.faces, this.camDire2);

  final Size absoluteImageSize;
  final List<Face> faces;
  CameraLensDirection camDire2;

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.red;

    for (Face face in faces) {
      canvas.drawRect(
        Rect.fromLTRB(
          camDire2 == CameraLensDirection.front
              ? (absoluteImageSize.width - face.boundingBox.right) * scaleX
              : face.boundingBox.left * scaleX,
          face.boundingBox.top * scaleY,
          camDire2 == CameraLensDirection.front
              ? (absoluteImageSize.width - face.boundingBox.left) * scaleX
              : face.boundingBox.right * scaleX,
          face.boundingBox.bottom * scaleY,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.faces != faces;
  }
}
