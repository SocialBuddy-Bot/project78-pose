// ignore_for_file: avoid_print

import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:body_detection/models/image_result.dart';
import 'package:body_detection/models/pose.dart';
import 'package:body_detection/models/body_mask.dart';
import 'package:body_detection/models/pose_landmark.dart';
import 'package:body_detection/models/pose_landmark_type.dart';
import 'package:body_detection/png_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'package:body_detection/body_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import 'pose_mask_painter.dart';

void main() {
  runApp(const NewApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedTabIndex = 0;

  bool _isDetectingPose = false;
  bool _isDetectingBodyMask = false;

  Image? _selectedImage;

  Pose? _detectedPose;
  ui.Image? _maskImage;
  Image? _cameraImage;
  Size _imageSize = Size.zero;

  Future<void> _selectImage() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path != null) {
      _resetState();
      setState(() {
        _selectedImage = Image.file(File(path));
      });
    }
  }

  Future<void> _detectImagePose() async {
    PngImage? pngImage = await _selectedImage?.toPngImage();
    if (pngImage == null) return;
    setState(() {
      _imageSize = Size(pngImage.width.toDouble(), pngImage.height.toDouble());
    });
    final pose = await BodyDetection.detectPose(image: pngImage);
    _handlePose(pose);
  }

  Future<void> _detectImageBodyMask() async {
    PngImage? pngImage = await _selectedImage?.toPngImage();
    if (pngImage == null) return;
    setState(() {
      _imageSize = Size(pngImage.width.toDouble(), pngImage.height.toDouble());
    });
    final mask = await BodyDetection.detectBodyMask(image: pngImage);
    _handleBodyMask(mask);
  }

  Future<void> _startCameraStream() async {
    final request = await Permission.camera.request();
    if (request.isGranted) {
      await BodyDetection.startCameraStream(
        onFrameAvailable: _handleCameraImage,
        onPoseAvailable: (pose) {
          if (!_isDetectingPose) return;
          _handlePose(pose);
        },
        onMaskAvailable: (mask) {
          if (!_isDetectingBodyMask) return;
          _handleBodyMask(mask);
        },
      );
    }
  }

  Future<void> _stopCameraStream() async {
    await BodyDetection.stopCameraStream();

    setState(() {
      _cameraImage = null;
      _imageSize = Size.zero;
    });
  }

  void _handleCameraImage(ImageResult result) {
    // Ignore callback if navigated out of the page.
    if (!mounted) return;

    // To avoid a memory leak issue.
    // https://github.com/flutter/flutter/issues/60160
    PaintingBinding.instance?.imageCache?.clear();
    PaintingBinding.instance?.imageCache?.clearLiveImages();

    final image = Image.memory(
      result.bytes,
      gaplessPlayback: true,
      fit: BoxFit.contain,
    );

    setState(() {
      _cameraImage = image;
      _imageSize = result.size;
      if (result.size.width > result.size.height) {
        log('Camera image size: width=${result.size.width}, height=${result.size.height}');
        turns = 0;
        verticalCount = 1;
        isCameraIsHorizontal = true;
      } else {
        turns = 3;
        isCameraIsHorizontal = false;
      }
    });
  }

  bool isCameraIsHorizontal = false;
  String title = "";
  void _handlePose(Pose? pose) {
    // Ignore if navigated out of the page.
    if (!mounted) return;

    setState(() {
      _detectedPose = pose;
      PoseLandmark? rightHand;
      try {
        rightHand = _detectedPose?.landmarks
            .firstWhere((l) => l.type == PoseLandmarkType.rightWrist);
      } catch (e) {
        print(e);
      }

      PoseLandmark? leftHand;
      try {
        leftHand = _detectedPose?.landmarks
            .firstWhere((l) => l.type == PoseLandmarkType.leftWrist);
      } catch (e) {
        print(e);
      }

      PoseLandmark? leftShoulder;
      try {
        leftShoulder = _detectedPose?.landmarks
            .firstWhere((l) => l.type == PoseLandmarkType.leftShoulder);
      } catch (e) {
        print(e);
      }
      PoseLandmark? rightShoulder;
      try {
        rightShoulder = _detectedPose?.landmarks
            .firstWhere((l) => l.type == PoseLandmarkType.rightShoulder);
      } catch (e) {
        print(e);
      }
      bool left = false;
      if (leftHand != null && leftShoulder != null) {
        if (isCameraIsHorizontal) {
          if (isHorizontal) {
            if (leftHand.position.y > leftShoulder.position.y) {
              left = true;
            }
          } else {
            if (leftHand.position.x > leftShoulder.position.x) {
              left = true;
            }
          }
        } else {
          if (isHorizontal) {
            if (leftHand.position.x > leftShoulder.position.x) {
              left = true;
            }
          } else {
            if (leftHand.position.y > leftShoulder.position.y) {
              left = true;
            }
          }
        }
      }

      bool right = false;
      if (rightHand != null && rightShoulder != null) {
        if (isCameraIsHorizontal) {
          if (isHorizontal) {
            if (rightHand.position.y > rightShoulder.position.y) {
              right = true;
            }
          } else {
            if (rightHand.position.x > rightShoulder.position.x) {
              right = true;
            }
          }
        } else {
          if (isHorizontal) {
            if (rightHand.position.x > rightShoulder.position.x) {
              right = true;
            }
          } else {
            if (rightHand.position.y > rightShoulder.position.y) {
              right = true;
            }
          }
        }
      }

      if (left) {
        if (right) {
          title = '';
        } else {
          title = isCameraIsHorizontal ? "No" : (isHorizontal ? "Yes" : "No");
        }
      } else {
        if (right) {
          title = isCameraIsHorizontal
              ? "Yes"
              : isHorizontal
                  ? "No"
                  : 'Yes';
        } else {
          title = "";
        }
      }
    });
  }

  void _handleBodyMask(BodyMask? mask) {
    // Ignore if navigated out of the page.
    if (!mounted) return;

    if (mask == null) {
      setState(() {
        _maskImage = null;
      });
      return;
    }

    final bytes = mask.buffer
        .expand(
          (it) => [0, 0, 0, (it * 255).toInt()],
        )
        .toList();
    ui.decodeImageFromPixels(Uint8List.fromList(bytes), mask.width, mask.height,
        ui.PixelFormat.rgba8888, (image) {
      setState(() {
        _maskImage = image;
      });
    });
  }

  Future<void> _toggleDetectPose() async {
    if (_isDetectingPose) {
      await BodyDetection.disablePoseDetection();
    } else {
      await BodyDetection.enablePoseDetection();
    }

    setState(() {
      _isDetectingPose = !_isDetectingPose;
      _detectedPose = null;
    });
  }

  Future<void> _toggleDetectBodyMask() async {
    if (_isDetectingBodyMask) {
      await BodyDetection.disableBodyMaskDetection();
    } else {
      await BodyDetection.enableBodyMaskDetection();
    }

    setState(() {
      _isDetectingBodyMask = !_isDetectingBodyMask;
      _maskImage = null;
    });
  }

  void _onTabEnter(int index) {
    // Camera tab
    if (index == 1) {
      _startCameraStream();
    }
  }

  void _onTabExit(int index) {
    // Camera tab
    if (index == 1) {
      _stopCameraStream();
    }
  }

  void _onTabSelectTapped(int index) {
    _onTabExit(_selectedTabIndex);
    _onTabEnter(index);

    setState(() {
      _selectedTabIndex = index;
    });
  }

  Widget? get _selectedTab => _selectedTabIndex == 0
      ? _imageDetectionView
      : _selectedTabIndex == 1
          ? _cameraDetectionView
          : null;

  void _resetState() {
    setState(() {
      _maskImage = null;
      _detectedPose = null;
      _imageSize = Size.zero;
    });
  }

  bool isPreviewEnable = false;
  bool smallPreview = false;
  Widget get _imageDetectionView => SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              GestureDetector(
                child: ClipRect(
                  child: CustomPaint(
                    child: _selectedImage,
                    foregroundPainter: PoseMaskPainter(
                      pose: _detectedPose,
                      mask: _maskImage,
                      imageSize: _imageSize,
                    ),
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: _selectImage,
                child: const Text('Select image'),
              ),
              OutlinedButton(
                onPressed: _detectImagePose,
                child: const Text('Detect pose'),
              ),
              OutlinedButton(
                onPressed: _detectImageBodyMask,
                child: const Text('Detect body mask'),
              ),
              OutlinedButton(
                onPressed: _resetState,
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
      );
  bool isHorizontal = false;
  int turns = 3;
  int verticalCount = 0;
  Widget get _cameraDetectionView =>
      LayoutBuilder(builder: (context, constrains) {
        isHorizontal = constrains.maxWidth > constrains.maxHeight;
        log("width: ${constrains.maxWidth} height: ${constrains.maxHeight}");
        log(isHorizontal.toString());
        log("isCameraIsHorizontal:" + isCameraIsHorizontal.toString());
        return Center(
          child: isHorizontal
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    isPreviewEnable
                        ? smallPreview
                            ? RotatedBox(
                                quarterTurns: isCameraIsHorizontal ? 0 : 3,
                                child: Container(
                                  padding: const EdgeInsets.all(8.0),
                                  width: _imageSize.width * 0.5,
                                  height: _imageSize.height * 0.5,
                                  child: ClipRect(
                                    child: CustomPaint(
                                      child: _cameraImage,
                                      foregroundPainter: PoseMaskPainter(
                                        pose: _detectedPose,
                                        mask: _maskImage,
                                        imageSize: _imageSize,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : RotatedBox(
                                quarterTurns: isCameraIsHorizontal ? 0 : 3,
                                child: ClipRect(
                                  child: CustomPaint(
                                    child: _cameraImage,
                                    foregroundPainter: PoseMaskPainter(
                                      pose: _detectedPose,
                                      mask: _maskImage,
                                      imageSize: _imageSize,
                                    ),
                                  ),
                                ),
                              )
                        : const SizedBox.shrink(),
                    SizedBox(
                      width: 20,
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            const Text("Camera Preview"),
                            Switch(
                              value: isPreviewEnable,
                              onChanged: (value) {
                                setState(() {
                                  isPreviewEnable = value;
                                  print(isPreviewEnable);
                                });
                              },
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            const Text("Small Preview"),
                            Switch(
                              value: smallPreview,
                              onChanged: (value) {
                                setState(() {
                                  smallPreview = value;

                                  print(smallPreview);
                                });
                              },
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            const Text("Pose Detection"),
                            Switch(
                              value: _isDetectingPose,
                              onChanged: (value) {
                                setState(() {
                                  _toggleDetectPose();
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    )

                    // OutlinedButton(
                    //   onPressed: _toggleDetectBodyMask,
                    //   child: _isDetectingBodyMask
                    //       ? const Text('Turn off body mask detection')
                    //       : const Text('Turn on body mask detection'),
                    // ),
                  ],
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      isPreviewEnable
                          ? smallPreview
                              ? RotatedBox(
                                  quarterTurns: isCameraIsHorizontal ? 1 : 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    width: _imageSize.width * 0.5,
                                    height: _imageSize.height * 0.5,
                                    child: ClipRect(
                                      child: CustomPaint(
                                        child: _cameraImage,
                                        foregroundPainter: PoseMaskPainter(
                                          pose: _detectedPose,
                                          mask: _maskImage,
                                          imageSize: _imageSize,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : RotatedBox(
                                  quarterTurns: isCameraIsHorizontal ? 1 : 0,
                                  child: ClipRect(
                                    child: CustomPaint(
                                      child: _cameraImage,
                                      foregroundPainter: PoseMaskPainter(
                                        pose: _detectedPose,
                                        mask: _maskImage,
                                        imageSize: _imageSize,
                                      ),
                                    ),
                                  ),
                                )
                          : const SizedBox.shrink(),
                      const SizedBox(
                        height: 20,
                      ),
                      Text(
                        title,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          const Text("Camera Preview"),
                          Switch(
                            value: isPreviewEnable,
                            onChanged: (value) {
                              setState(() {
                                isPreviewEnable = value;
                                print(isPreviewEnable);
                              });
                            },
                          ),
                        ],
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          const Text("Small Preview"),
                          Switch(
                            value: smallPreview,
                            onChanged: (value) {
                              setState(() {
                                smallPreview = value;

                                print(smallPreview);
                              });
                            },
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          const Text("Pose Detection"),
                          Switch(
                            value: _isDetectingPose,
                            onChanged: (value) {
                              setState(() {
                                _toggleDetectPose();
                              });
                            },
                          ),
                        ],
                      ),
                      // OutlinedButton(
                      //   onPressed: _toggleDetectBodyMask,
                      //   child: _isDetectingBodyMask
                      //       ? const Text('Turn off body mask detection')
                      //       : const Text('Turn on body mask detection'),
                      // ),
                    ],
                  ),
                ),
        );
      });

  @override
  void initState() {
    // TODO: implement initState

    _startCameraStream();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Body Detection Demo'),
        ),
        // bottomNavigationBar: BottomNavigationBar(
        //   items: const <BottomNavigationBarItem>[
        //     BottomNavigationBarItem(
        //       icon: Icon(Icons.image),
        //       label: 'Image',
        //     ),
        //     BottomNavigationBarItem(
        //       icon: Icon(Icons.camera),
        //       label: 'Camera',
        //     ),
        //   ],
        //   currentIndex: _selectedTabIndex,
        //   onTap: _onTabSelectTapped,
        // ),
        body: _cameraDetectionView,
      ),
    );
  }
}

class NewApp extends StatelessWidget {
  const NewApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyApp(),
    );
  }
}
