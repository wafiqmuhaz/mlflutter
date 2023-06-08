import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';
import './/utils/helpers.dart';

class ImageLabelingPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String title;
  const ImageLabelingPage({
    Key? key,
    required this.cameras,
    required this.title,
  }) : super(key: key);

  @override
  _ImageLabelingPageState createState() => _ImageLabelingPageState();
}

class _ImageLabelingPageState extends State<ImageLabelingPage> {
  late CameraController controller;
  late CameraImage _liveImage;
  late ImageLabeler imageLabeler;
  late ImagePicker imagePicker;
  late CameraDescription description;
  CameraLensDirection camDirec = CameraLensDirection.front;
  File? _image;
  bool isBusy = false;
  bool isLive = false;

  List<String> result = [];

  @override
  void initState() {
    super.initState();
    description = widget.cameras[1];
    imageLabeler = GoogleMlKit.vision.imageLabeler();
    imagePicker = ImagePicker();
  }

  @override
  void dispose() {
    super.dispose();
    imageLabeler.close();
  }

  _getImageFromCamera() async {
    setState(() {
      isLive = false;
      controller.stopImageStream();
    });
    PickedFile? pickedFile = await imagePicker.getImage(
      source: ImageSource.camera,
    );
    setState(() {
      _image = pickedFile != null ? File(pickedFile.path) : _image;
    });
    doImageLabeling(inputImage: InputImage.fromFile(_image!));
  }

  _getImageFromGallery() async {
    setState(() {
      isLive = false;
      controller.stopImageStream();
    });
    PickedFile? pickedFile = await imagePicker.getImage(
      source: ImageSource.gallery,
    );
    setState(() {
      _image = _image = pickedFile != null ? File(pickedFile.path) : _image;
    });
    doImageLabeling(inputImage: InputImage.fromFile(_image!));
  }

  _getLiveCamera() async {
    controller = CameraController(description, ResolutionPreset.max);
    await controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      controller.startImageStream((image) {
        if (!isBusy) {
          isBusy = true;
          _liveImage = image;
          isLive = true;
          doImageLabeling(inputImage: getLiveInputImage());
        }
      });
    });
  }

  void _toggleCameraDirection() async {
    if (camDirec == CameraLensDirection.back) {
      camDirec = CameraLensDirection.front;
      description = widget.cameras[1];
    } else {
      camDirec = CameraLensDirection.back;
      description = widget.cameras[0];
    }

    await controller.stopImageStream();

    setState(() {
      controller = new CameraController(
        description,
        ResolutionPreset.max,
      );
      _getLiveCamera();
    });
  }

  doImageLabeling({required InputImage inputImage}) async {
    result.clear();
    final _inputImage = inputImage;
    final List<ImageLabel> labels =
        await imageLabeler.processImage(_inputImage);
    result.clear();
    for (ImageLabel label in labels) {
      final String text = label.label;
      final double confidence = label.confidence * 100;
      result.add("$text - ${confidence.toStringAsFixed(2)}%");
    }
    setState(() {
      isBusy = false;
    });
  }

  InputImage getLiveInputImage() {
    final WriteBuffer allBytes = WriteBuffer();
    for (var plane in _liveImage.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
        Size(_liveImage.width.toDouble(), _liveImage.height.toDouble());

    final InputImageRotation imageRotation =
        InputImageRotationMethods.fromRawValue(description.sensorOrientation) ??
            InputImageRotation.Rotation_0deg;

    final InputImageFormat inputImageFormat =
        InputImageFormatMethods.fromRawValue(_liveImage.format.raw) ??
            InputImageFormat.NV21;

    final planeData = _liveImage.planes.map(
      (var plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList();

    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation,
      inputImageFormat: inputImageFormat,
      planeData: planeData,
    );

    final inputImage =
        InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);
    return inputImage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        actions: isLive
            ? controller.value.isInitialized
                ? [
                    IconButton(
                      onPressed: _toggleCameraDirection,
                      icon: Icon(Icons.cameraswitch),
                    ),
                  ]
                : []
            : [],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          isLive = false;
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
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isLive
                      ? controller.value.isInitialized
                          ? AspectRatio(
                              aspectRatio: controller.value.aspectRatio,
                              child: CameraPreview(controller),
                            )
                          : Icon(
                              Icons.camera_alt,
                              color: Colors.grey[500],
                            )
                      : _image != null
                          ? Image.file(
                              _image!,
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
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
