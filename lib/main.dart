import 'package:flutter/material.dart';
import 'package:flutter_project/chewie_list_item.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'package:camera/camera.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  // Fetch the available cameras before initializing the app.
  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
  } on CameraException catch (e) {
    logError(e.code, e.description);
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Alpha Player',
      theme: ThemeData(
        primarySwatch: Colors.yellow,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

/// Returns a suitable camera icon for [direction].
IconData getCameraLensIcon(CameraLensDirection direction) {
  switch (direction) {
    case CameraLensDirection.back:
      return Icons.camera_rear;
    case CameraLensDirection.front:
      return Icons.camera_front;
    case CameraLensDirection.external:
      return Icons.camera;
  }
  throw ArgumentError('Unknown lens direction');
}

void logError(String code, String message) =>
    print('Error: $code\nError Message: $message');

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  CameraController controller;
  VideoPlayerController videoController;
  VoidCallback videoPlayerListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before we got the chance to initialize.
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (controller != null) {
        onNewCameraSelected(controller.description);
      }
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget potrait() {
    return Center(
        child: Container(
            padding: EdgeInsets.all(4.0),
            constraints: BoxConstraints.expand(),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(
                  color: Colors.black, width: 2.0, style: BorderStyle.solid),
            ),
            child: Stack(children: <Widget>[
              ChewieListItem(
                videoPlayerController: VideoPlayerController.asset(
                  'videos/song.mp4',
                ),
                looping: true,
              ),
              Positioned(
                top: 350.0,
                left: 301.0,
                child: Container(
                  height: 80,
                  width: 80,
                  child: _cameraPreviewWidget(),
                ),
              ),
              Positioned(
                top: 115.0,
                left: 287.0,
                child: Container(
                  child: Padding(
                    padding: const EdgeInsets.all(0.0),
                    child: Row(
                      children: <Widget>[
                        _cameraTogglesRowWidget(),
                      ],
                    ),
                  ),
                ),
              ),
            ])));
  }

  Widget landscape() {
    return Center(
        child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: Colors.black, width: 2.0, style: BorderStyle.solid),
            ),
            child: Stack(children: <Widget>[
              ChewieListItem(
                videoPlayerController: VideoPlayerController.asset(
                  'videos/song.mp4',
                ),
                looping: true,
              ),
              Positioned(
                top: 161.0,
                left: 542.0,
                child: Container(
                  height: 100,
                  width: 100,
                  child: _cameraPreviewWidget(),
                ),
              ),
              Positioned(
                top: 0.0,
                left: 0.0,
                child: Container(
                  child: Padding(
                    padding: const EdgeInsets.all(0.0),
                    child: Row(
                      children: <Widget>[
                        _cameraTogglesRowWidget(),
                      ],
                    ),
                  ),
                ),
              ),
            ])));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("Alpha Video Player"),
        centerTitle: true,
        leading: GestureDetector(
          onTap: () {/* Write listener code here */},
          child: Icon(
            Icons.menu, // add custom icons also
          ),
        ),
        actions: <Widget>[
          Padding(
              padding: EdgeInsets.only(right: 20.0),
              child: GestureDetector(
                onTap: () {},
                child: Icon(
                  Icons.search,
                  size: 26.0,
                ),
              )),
          Padding(
              padding: EdgeInsets.only(right: 20.0),
              child: GestureDetector(
                onTap: () {},
                child: Icon(Icons.more_vert),
              )),
        ],
      ),
      body: OrientationBuilder(builder: (context, orientation) {
        if (orientation == Orientation.portrait) {
          return potrait();
        } else {
          return landscape();
        }
      }),
    );
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  Widget _cameraPreviewWidget() {
    if (controller == null || !controller.value.isInitialized) {
      return const Text(
        '',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: CameraPreview(controller),
      );
    }
  }

  /// Display a row of toggle to select the camera (or a message if no camera is available).
  Widget _cameraTogglesRowWidget() {
    final List<Widget> toggles = <Widget>[];

    if (cameras.isEmpty) {
      return const Text('No camera found');
    } else {
      for (CameraDescription cameraDescription in cameras) {
        toggles.add(
          SizedBox(
            width: 110.0,
            child: RadioListTile<CameraDescription>(
              title: Icon(getCameraLensIcon(cameraDescription.lensDirection)),
              groupValue: controller?.description,
              value: cameraDescription,
              onChanged: controller != null && controller.value.isRecordingVideo
                  ? null
                  : onNewCameraSelected,
            ),
          ),
        );
      }
    }
    return Column(children: toggles);
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller.dispose();
    }
    controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
    );

    try {
      await controller.initialize();
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _showCameraException(CameraException e) {
    logError(e.code, e.description);
  }
}
