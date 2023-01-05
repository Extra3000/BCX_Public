import 'dart:convert';

import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:vector_math/vector_math_64.dart' as VectorMath;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire/geoflutterfire.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vux_app/examples/lamp_details_page.dart';

class ExternalModelManagementWidget extends StatefulWidget {
  ExternalModelManagementWidget({Key? key}) : super(key: key);

  @override
  _ExternalModelManagementWidgetState createState() =>
      _ExternalModelManagementWidgetState();
}

final duckModel = AvailableModel(
    name: "Duck",
    uri:
        "https://github.com/KhronosGroup/glTF-Sample-Models/raw/master/2.0/Duck/glTF-Binary/Duck.glb",
    image: "",
    nodeType: NodeType.webGLB);

final lightbulbModel = AvailableModel(
  name: "Lightbulb",
  uri: "assets/models/lightbulb/lightbulb.gltf",
  image: "",
  nodeType: NodeType.localGLTF2,
);

final arrowModel = AvailableModel(
  name: "Arrow",
  uri: "assets/models/simple_red_arrow/simple_red_arrow.gltf",
  image: "",
  nodeType: NodeType.localGLTF2,
);

final foxModel = AvailableModel(
  name: "Fox",
  uri: "assets/models/fox/fox.gltf",
  image: "",
  nodeType: NodeType.localGLTF2,
);

class _ExternalModelManagementWidgetState
    extends State<ExternalModelManagementWidget> {
  // Firebase stuff
  bool _initialized = false;
  bool _error = false;
  bool _uploading = false;
  FirebaseManager firebaseManager = FirebaseManager();
  Map<String, Map> anchorsInDownloadProgress = Map<String, Map>();

  late ARSessionManager arSessionManager;
  late ARObjectManager arObjectManager;
  late ARAnchorManager arAnchorManager;
  late ARLocationManager arLocationManager;

  List<ARNode> nodes = [];
  List<ARAnchor> anchors = [];
  String lastUploadedAnchor = "";

  OnPlaneOrPointTappedMode onPlaneOrPointTappedMode =
      OnPlaneOrPointTappedMode.doNothing;

  @override
  void initState() {
    firebaseManager.initializeFlutterFire().then((value) => setState(() {
          _initialized = value;
          _error = !value;
        }));

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    arSessionManager.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show error message if initialization failed
    if (_error) {
      return Scaffold(
          appBar: AppBar(
            title: const Text('VUX'),
          ),
          body: Container(
              child: Center(
                  child: Column(
            children: [
              Text("Firebase initialization failed"),
              ElevatedButton(
                  child: Text("Retry"), onPressed: () => {initState()})
            ],
          ))));
    }

    // Show a loader until FlutterFire is initialized
    if (!_initialized) {
      return Scaffold(
          appBar: AppBar(
            title: const Text('External Model Management'),
          ),
          body: Container(
              child: Center(
                  child: Column(children: [
            CircularProgressIndicator(),
            Text("Initializing Firebase")
          ]))));
    }

    return Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            child: const Text('VUX'),
            onDoubleTap: () {
              arSessionManager.onError("VUX mode enabled");
              onPlaneOrPointTappedMode = OnPlaneOrPointTappedMode.placeVuxFox;
            },
            onLongPress: () {
              arSessionManager.onError("Developer mode enabled");
              onPlaneOrPointTappedMode =
                  OnPlaneOrPointTappedMode.placeLightbulb;
            },
          ),
          actions: [
            GestureDetector(
              onLongPress: onRemoveEverything,
              child: Icon(Icons.delete_forever),
            ),
            IconButton(
              onPressed: onDownloadButtonPressed,
              icon: Icon(Icons.refresh),
            ),
            IconButton(
              onPressed: () {
                arSessionManager.onError("Tap anywhere to place a bug report");
                onPlaneOrPointTappedMode =
                    OnPlaneOrPointTappedMode.placeFacilityManagementReport;
              },
              icon: Icon(Icons.bug_report),
            )
          ],
        ),
        body: Container(
            child: Stack(children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
          if (_uploading)
            SizedBox.expand(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            )
        ])));
  }

  void onARViewCreated(
      ARSessionManager arSessionManager,
      ARObjectManager arObjectManager,
      ARAnchorManager arAnchorManager,
      ARLocationManager arLocationManager) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;
    this.arLocationManager = arLocationManager;

    this.arSessionManager.onInitialize(
          showFeaturePoints: false,
          showPlanes: true,
          customPlaneTexturePath: "assets/images/triangle.png",
          //   showWorldOrigin: true,
        );
    this.arObjectManager.onInitialize();
    this.arAnchorManager.initGoogleCloudAnchorMode();

    this.arSessionManager.onPlaneOrPointTap = onPlaneOrPointTapped;
    this.arObjectManager.onNodeTap = onNodeTapped;
    this.arAnchorManager.onAnchorUploaded = onAnchorUploaded;
    this.arAnchorManager.onAnchorDownloaded = onAnchorDownloaded;

    this
        .arLocationManager
        .startLocationUpdates()
        .then((value) => null)
        .onError((error, stackTrace) {
      switch (error.toString()) {
        case 'Location services disabled':
          {
            showAlertDialog(
                context,
                "Action Required",
                "To use cloud anchor functionality, please enable your location services",
                "Settings",
                this.arLocationManager.openLocationServicesSettings,
                "Cancel");
            break;
          }

        case 'Location permissions denied':
          {
            showAlertDialog(
                context,
                "Action Required",
                "To use cloud anchor functionality, please allow the app to access your device's location",
                "Retry",
                this.arLocationManager.startLocationUpdates,
                "Cancel");
            break;
          }

        case 'Location permissions permanently denied':
          {
            showAlertDialog(
                context,
                "Action Required",
                "To use cloud anchor functionality, please allow the app to access your device's location",
                "Settings",
                this.arLocationManager.openAppPermissionSettings,
                "Cancel");
            break;
          }

        default:
          {
            this.arSessionManager.onError(error.toString());
            break;
          }
      }
      this.arSessionManager.onError(error.toString());
    });
  }

  Future<void> onRemoveEverything() async {
    anchors.forEach((anchor) {
      this.arAnchorManager.removeAnchor(anchor);
    });
    anchors = [];
    firebaseManager.deleteAnchorsAndObjects();

    this.arSessionManager.onError('Deleted everything');
  }

  Future<void> onNodeTapped(List<String> nodeNames) async {
    var foregroundNode =
        nodes.firstOrNullWhere((element) => element.name == nodeNames.first);
    if (foregroundNode == null) return;

    // TODO switch on data in node which contains which page to open

    final arNodeTypeString = foregroundNode.data!['type'] as String?;
    final arNodeType =
        ARNodeType.values.firstOrNullWhere((e) => e.name == arNodeTypeString);
    if (arNodeType == null) {
      return;
    }

    switch (arNodeType) {
      case ARNodeType.vuxFox:
        final audioPlayer = AssetsAudioPlayer.newPlayer();
        audioPlayer.open(
          Audio("assets/sounds/what_does_the_fox_say.mp3"),
          autoStart: true,
        );

        await showAlertDialog(
          context,
          'Congratulations!',
          foregroundNode.data!['onTapText'],
          'Ok',
          () {},
        );

        audioPlayer.stop();
        break;
      case ARNodeType.lighting:
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => LampDetailsPage(title: 'Meine Lampe')),
        );
        break;
      case ARNodeType.facilityManagementReport:
        showAlertDialog(
          context,
          'Facility Management Report',
          foregroundNode.data!['onTapText'],
          'Ok',
          () {},
        );
    }
  }

  Future<void> onPlaneOrPointTapped(
      List<ARHitTestResult> hitTestResults) async {
    var singleHitTestResult = hitTestResults.firstOrNullWhere(
        (hitTestResult) => hitTestResult.type == ARHitTestResultType.plane);

    if (singleHitTestResult == null) {
      return;
    }

    late final String onTapText;
    late final AvailableModel selectedModel;
    late final ARNodeType arNodeType;
    switch (onPlaneOrPointTappedMode) {
      case OnPlaneOrPointTappedMode.placeVuxFox:
        onTapText = "Sie sind ein Vux!";
        selectedModel = foxModel;
        arNodeType = ARNodeType.vuxFox;
        break;
      case OnPlaneOrPointTappedMode.placeLightbulb:
        selectedModel = lightbulbModel;
        onTapText = "I am a lighting";
        arNodeType = ARNodeType.lighting;
        break;
      case OnPlaneOrPointTappedMode.placeFacilityManagementReport:
        final result = await showDialog<String>(
            context: context,
            builder: (context) => FacilityManagementReportDialog());
        if (result == null || result.isEmpty) {
          return;
        }

        onTapText = result;
        selectedModel = arrowModel;
        arNodeType = ARNodeType.facilityManagementReport;
        break;

      case OnPlaneOrPointTappedMode.doNothing:
        return;
    }

    var newAnchor = ARPlaneAnchor(
        transformation: singleHitTestResult.worldTransform, ttl: 2);
    bool didAddAnchor = (await this.arAnchorManager.addAnchor(newAnchor))!;
    if (didAddAnchor) {
      this.anchors.add(newAnchor);
      // Add note to anchor
      var newNode = ARNode(
        type: selectedModel.nodeType,
        uri: selectedModel.uri,
        scale: VectorMath.Vector3(0.2, 0.2, 0.2),
        position: VectorMath.Vector3(0.0, 0.0, 0.0),
        rotation: VectorMath.Vector4(1.0, 0.0, 0.0, 0.0),
        data: {"onTapText": onTapText, "type": arNodeType.name},
      );
      bool didAddNodeToAnchor = (await this
          .arObjectManager
          .addNode(newNode, planeAnchor: newAnchor))!;
      if (didAddNodeToAnchor) {
        this.nodes.add(newNode);
        onPlaneOrPointTappedMode = OnPlaneOrPointTappedMode.doNothing;
        setState(() {
          _uploading = true;
        });
        this
            .arAnchorManager
            .uploadAnchor(newAnchor)
            .then((value) => setState(() => _uploading = false));
      } else {
        this.arSessionManager.onError("Adding Node to Anchor failed");
      }
    } else {
      this.arSessionManager.onError("Adding Anchor failed");
    }
  }

  Future<void> onUploadButtonPressed() async {
    this.arAnchorManager.uploadAnchor(this.anchors.last);
  }

  onAnchorUploaded(ARAnchor anchor) {
    // Upload anchor information to firebase
    firebaseManager.uploadAnchor(anchor,
        currentLocation: this.arLocationManager.currentLocation);
    // Upload child nodes to firebase
    if (anchor is ARPlaneAnchor) {
      anchor.childNodes.forEach((nodeName) => firebaseManager.uploadObject(
          nodes.firstWhere((element) => element.name == nodeName)));
    }
    this.arSessionManager.onError("Upload successful");
  }

  ARAnchor onAnchorDownloaded(Map<String, dynamic> serializedAnchor) {
    final anchor = ARPlaneAnchor.fromJson(
        anchorsInDownloadProgress[serializedAnchor["cloudanchorid"]]
            as Map<String, dynamic>);
    anchorsInDownloadProgress.remove(anchor.cloudanchorid);
    this.anchors.add(anchor);

    // Download nodes attached to this anchor
    firebaseManager.getObjectsFromAnchor(anchor, (snapshot) {
      snapshot.docs.forEach((objectDoc) {
        ARNode object =
            ARNode.fromMap(objectDoc.data() as Map<String, dynamic>);
        arObjectManager.addNode(object, planeAnchor: anchor);
        this.nodes.add(object);
      });
    });

    return anchor;
  }

// TODO download periodically
  Future<void> onDownloadButtonPressed() async {
    //this.arAnchorManager.downloadAnchor(lastUploadedAnchor);
    //firebaseManager.downloadLatestAnchor((snapshot) {
    //  final cloudAnchorId = snapshot.docs.first.get("cloudanchorid");
    //  anchorsInDownloadProgress[cloudAnchorId] = snapshot.docs.first.data();
    //  arAnchorManager.downloadAnchor(cloudAnchorId);
    //});

    // Get anchors within a radius of 100m of the current device's location
    if (this.arLocationManager.currentLocation != null) {
      firebaseManager.downloadAnchorsByLocation((snapshot) {
        final cloudAnchorId = snapshot.get("cloudanchorid");
        anchorsInDownloadProgress[cloudAnchorId] =
            snapshot.data() as Map<String, dynamic>;
        arAnchorManager.downloadAnchor(cloudAnchorId);
      }, this.arLocationManager.currentLocation, 0.5);

      this.arSessionManager.onError('Downloaded everything');
    } else {
      this
          .arSessionManager
          .onError("Location updates not running, can't download anchors");
    }
  }

  Future<void> showAlertDialog(BuildContext context, String title,
      String content, String buttonText, Function buttonFunction,
      [String? cancelButtonText]) {
    // set up the buttons
    Widget? cancelButton = cancelButtonText != null
        ? ElevatedButton(
            child: Text(cancelButtonText),
            onPressed: () {
              Navigator.of(context).pop();
            },
          )
        : null;
    Widget actionButton = ElevatedButton(
      child: Text(buttonText),
      onPressed: () {
        buttonFunction();
        Navigator.of(context).pop();
      },
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        if (cancelButton != null) cancelButton,
        actionButton,
      ],
    );

    // show the dialog
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }
}

// Class for managing interaction with Firebase (in your own app, this can be put in a separate file to keep everything clean and tidy)
typedef FirebaseListener = void Function(QuerySnapshot snapshot);
typedef FirebaseDocumentStreamListener = void Function(
    DocumentSnapshot snapshot);

class FirebaseManager {
  late FirebaseFirestore firestore;
  late Geoflutterfire geo;
  late CollectionReference anchorCollection;
  late CollectionReference objectCollection;
  late CollectionReference modelCollection;

  // Firebase initialization function
  Future<bool> initializeFlutterFire() async {
    try {
      // Wait for Firebase to initialize
      await Firebase.initializeApp();
      geo = Geoflutterfire();
      firestore = FirebaseFirestore.instance;
      anchorCollection = FirebaseFirestore.instance.collection('anchors');
      objectCollection = FirebaseFirestore.instance.collection('objects');
      modelCollection = FirebaseFirestore.instance.collection('models');
      return true;
    } catch (e) {
      return false;
    }
  }

  void deleteAnchorsAndObjects() {
    anchorCollection.get().then((snapshot) {
      for (DocumentSnapshot ds in snapshot.docs) {
        ds.reference.delete();
      }
    });
    objectCollection.get().then((snapshot) {
      for (DocumentSnapshot ds in snapshot.docs) {
        ds.reference.delete();
      }
    });
  }

  void uploadAnchor(ARAnchor anchor, {Position? currentLocation}) {
    if (firestore == null) return;

    var serializedAnchor = anchor.toJson();
    var expirationTime = DateTime.now().millisecondsSinceEpoch / 1000 +
        serializedAnchor["ttl"] * 24 * 60 * 60;
    serializedAnchor["expirationTime"] = expirationTime;
    // Add location
    if (currentLocation != null) {
      GeoFirePoint myLocation = geo.point(
          latitude: currentLocation.latitude,
          longitude: currentLocation.longitude);
      serializedAnchor["position"] = myLocation.data;
    }

    anchorCollection
        .add(serializedAnchor)
        .then((value) =>
            print("Successfully added anchor: " + serializedAnchor["name"]))
        .catchError((error) => print("Failed to add anchor: $error"));
  }

  void uploadObject(ARNode node) {
    if (firestore == null) return;

    var serializedNode = node.toMap();

    objectCollection
        .add(serializedNode)
        .then((value) =>
            print("Successfully added object: " + serializedNode["name"]))
        .catchError((error) => print("Failed to add object: $error"));
  }

  void downloadLatestAnchor(FirebaseListener listener) {
    anchorCollection
        .orderBy("expirationTime", descending: false)
        .limitToLast(1)
        .get()
        .then((value) => listener(value))
        .catchError(
            (error) => (error) => print("Failed to download anchor: $error"));
  }

  void downloadAnchorsByLocation(FirebaseDocumentStreamListener listener,
      Position location, double radius) {
    GeoFirePoint center =
        geo.point(latitude: location.latitude, longitude: location.longitude);

    Stream<List<DocumentSnapshot>> stream = geo
        .collection(collectionRef: anchorCollection)
        .within(center: center, radius: radius, field: 'position');

    stream.listen((List<DocumentSnapshot> documentList) {
      documentList.forEach((element) {
        listener(element);
      });
    });
  }

  void downloadAnchorsByChannel() {}

  void getObjectsFromAnchor(ARPlaneAnchor anchor, FirebaseListener listener) {
    objectCollection
        .where("name", whereIn: anchor.childNodes)
        .get()
        .then((value) => listener(value))
        .catchError((error) => print("Failed to download objects: $error"));
  }

  void deleteExpiredDatabaseEntries() {
    WriteBatch batch = FirebaseFirestore.instance.batch();
    anchorCollection
        .where("expirationTime",
            isLessThan: DateTime.now().millisecondsSinceEpoch / 1000)
        .get()
        .then((anchorSnapshot) => anchorSnapshot.docs.forEach((anchorDoc) {
              // Delete all objects attached to the expired anchor
              objectCollection
                  .where("name", arrayContainsAny: anchorDoc.get("childNodes"))
                  .get()
                  .then((objectSnapshot) => objectSnapshot.docs.forEach(
                      (objectDoc) => batch.delete(objectDoc.reference)));
              // Delete the expired anchor
              batch.delete(anchorDoc.reference);
            }));
    batch.commit();
  }

  void downloadAvailableModels(FirebaseListener listener) {
    modelCollection
        .get()
        .then((value) => listener(value))
        .catchError((error) => print("Failed to download objects: $error"));
  }
}

class AvailableModel {
  String name;
  String uri;
  String image;
  NodeType nodeType;

  AvailableModel(
      {required this.name,
      required this.uri,
      required this.image,
      required this.nodeType});
}

enum OnPlaneOrPointTappedMode {
  placeLightbulb,
  placeFacilityManagementReport,
  placeVuxFox,
  doNothing,
}

class FacilityManagementReportDialog extends StatelessWidget {
  FacilityManagementReportDialog({Key? key}) : super(key: key);

  String text = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Create Facility Management Report'),
      content: TextField(
          decoration: InputDecoration(border: OutlineInputBorder()),
          onChanged: (value) => text = value),
      actions: <Widget>[
        TextButton(
            child: Text('Cancel'),
            onPressed: () {
              Navigator.pop(context);
            }),
        ElevatedButton(
            child: Text('Ok'),
            onPressed: () {
              Navigator.pop(context, text);
            })
      ],
    );
  }
}

enum ARNodeType { lighting, facilityManagementReport, vuxFox }
