import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:onepetri/Methods/tile_image.dart';
import 'package:onepetri/Objects/tile.dart';
import 'package:image/image.dart' as img;
import 'package:onepetri/Objects/ml_parameters.dart';
import 'package:onepetri/Objects/detected_obj.dart';
import 'package:onepetri/Methods/NMS.dart';
import 'package:onepetri/Methods/image_processing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

//Screen for taking and processing the image user selected
class PlaqueCounting extends StatefulWidget {
  const PlaqueCounting({super.key, required this.imageFile,required this.parameters});

  final File imageFile;
  final ml_Parameters parameters;
  final double previewSize = 360;//The size (both height and width) of the preview image displayed
  final int pxSize = 640;//The pixel size used in model. Here the unit is PIXEL, NOT LOGICAL PIXEL

  @override
  State<PlaqueCounting> createState() => _PlaqueCountingState();
}

class _PlaqueCountingState extends State<PlaqueCounting> {

  List<Widget> drawStack = <Widget>[];//This is used to display the picture and draw rectangular boxes on identified plaques

  late tfl.Interpreter interpreter;
  late double plaqueConfThreshold,plaqueIOUThreshold;
  late List<int> _outputShape;
  late tfl.TfLiteType _outputType;
  late tfl.TfLiteType _inputType;
  late TensorBuffer _outputBuffer;
  late TensorBuffer _inputBuffer; //This is necessary because the model takes batch size as an extra dimension
  late List<int> _inputShape;
  late img.Image image;
  late TensorImage tensorImage;

  var tileDetected = <DetectedObj>[];//To store detected objects in one tile
  var dishDetected = <DetectedObj>[];//To store detected objects for the whole petri dish
  var tileList = <Tile>[];//To store tiled images

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  _loadModel() async{
    plaqueConfThreshold = widget.parameters.plaqueConfThreshold;
    plaqueIOUThreshold = widget.parameters.plaqueIOUThreshold;
    interpreter = await tfl.Interpreter.fromAsset("models/plaque-fp16.tflite");//This is the model for petri dish

    //Get and initialize output (the input is known and fixed by pre-processing above)
    interpreter.allocateTensors();
    _outputShape = interpreter.getOutputTensor(0).shape;
    _outputType = interpreter.getOutputTensor(0).type;
    _outputBuffer = TensorBuffer.createFixedSize(_outputShape, _outputType);
    _inputType = interpreter.getInputTensor(0).type;

    //For debugging TODO:Remove
    _inputShape = interpreter.getInputTensor(0).shape;
    _inputBuffer = TensorBuffer.createFixedSize(_inputShape, _outputType);
    //End of debugging.
  }
  _initialize() async{
    await _loadModel();
    tensorImage = TensorImage(_inputType);
    setState(() {
      //Add the initial preview
      drawStack.add(SizedBox(
        height: widget.previewSize,
        width: widget.previewSize,
        child: Image.file(widget.imageFile,fit: BoxFit.cover,),
      ));
    });
  }

  Future<void> _alertDishSize() async{
    //If the petri dish selected is too small (too low resolution) then it cannot be classified
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Petri dish too small',
            textAlign: TextAlign.center,
          ),
          content: const SingleChildScrollView(
            child: Center(
              child: Text("The Petri dish selected is too small to proceed with analysis. Please select a higher resolution image.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20
                ),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: (){
                //In this case go back to home page to re-select
                Navigator.of(context).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
              },
              child: const Text('Go back',
                style: TextStyle(
                    fontSize: 20
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  Future<void> _toHelp() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Missing plaques?',
            textAlign: TextAlign.center,
          ),
          content: const SingleChildScrollView(
            child: Center(
              child: Text("If some plaques were not detected, you may submit the selected image to help improve future iterations of OnePetri's AI models. Would you like to submit this image for analysis?",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20
                ),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: _sendEmail,
              child: const Text('Send Image',
                style: TextStyle(
                    fontSize: 20
                ),
              ),
            ),
            TextButton(
              child: const Text('Cancel',
                style: TextStyle(
                    fontSize: 20
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  Future<void> _sendEmail() async {
    if (!await launchUrl(Uri.parse('mailto:support@onepetri.ai'))) {
      throw 'Could not connect to Email';
    }
  }

  convertTileCoords(Tile tile, DetectedObj obj){
    //This converts the coordinates of a detected object from relative coordinates into absolute pixels (of the petri dish image)
    //Note that normally objects detected use relative coordinates (and the conversion happens outside of function calls)
    //But after this function the coordinate attributes of the object will be absolute coordinates
    int tileWidth = tile.xmax - tile.xmin;
    int tileHeight = tile.ymax - tile.ymin;
    obj.xmin = tile.xmin + obj.xmin * tileWidth;
    obj.ymin = tile.ymin + obj.ymin * tileHeight;
    obj.xmax = tile.xmin + obj.xmax * tileWidth;
    obj.ymax = tile.ymin + obj.ymax * tileHeight;
    return obj;
  }
  _checkSize() {
    image = img.decodeImage(widget.imageFile.readAsBytesSync())!;
    //Debugging. TODO: remove//
    print('Dish width is: ${image.width},Dish height is: ${image.height}');
    //End of debug
    if ((image.width < 640) || (image.height < 640)) {
      _alertDishSize();
    }
    else {
      _classify();
    }
  }
  _classify (){
    //TODO: Actually implement classification code
    tileList = tileImage2(image,widget.pxSize);
    for (var tile in tileList){
      //Classify each tile. Empty detected list for each tile
      tileDetected = [];
      //The rest of classification is same method as done for petri dish
      tensorImage.loadImage(tile.image);
      List<double> temp = tensorImage.tensorBuffer.getDoubleList();
      //Normalize the values to 0-1
      for(var i=0;i<temp.length;i++){
        temp[i] = temp[i]/255;
      }
      _inputBuffer.loadList(temp,shape:[1,640,640,3]);
      interpreter.run(_inputBuffer.getBuffer(), _outputBuffer.getBuffer());
      List temp2 = _outputBuffer.getDoubleList().reshape([25200,6]);
      for (var i =0; i<25200;i++) {
        //If object has higher conf than threshold,consider it a petri dish
        if (temp2[i][4]>plaqueConfThreshold){
          tileDetected.add(DetectedObj(max(0,temp2[i][0]-0.5*temp2[i][2]), max(0,temp2[i][1]-0.5*temp2[i][3]), temp2[i][0]+0.5*temp2[i][2], temp2[i][1]+0.5*temp2[i][3], temp2[i][4]));
        }
      }
      tileDetected = NMS(tileDetected,plaqueIOUThreshold);
      //Now convert these coordinates back to absolute ones for the petri dish image, and add to dishDetected
      for (var obj in tileDetected){
        obj = convertTileCoords(tile, obj);
        dishDetected.add(obj);
      }
    }
    //Now do a NMS on the whole image

    //Debug. TODO: remove
    print('Found a total of ${dishDetected.length} plaques before NMS');
    //end of debug
    dishDetected = NMS(dishDetected,plaqueIOUThreshold);
    //Debug. TODO: remove
    for (var obj in dishDetected){
      print('Found plaque at: xmin = ${obj.xmin}, ymin = ${obj.ymin}, xmax = ${obj.xmax}, ymax = ${obj.ymax}, with confidence = ${obj.confidence}');
    }
    print('Found a total of ${dishDetected.length} plaques after NMS');
    //End of debugging.
    setState(() {
      _drawPlaques();
    });
  }

  //Draw detected plaques onto the original image
  _drawPlaques(){
    for (var obj in dishDetected){
      drawStack.add(
          Positioned(
            left: obj.xmin*widget.previewSize/image.width,
            top: obj.ymin*widget.previewSize/image.height,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.yellow,  // red as border color
                    width: 1,
                  ),
                ),
                width: (obj.xmax - obj.xmin)*widget.previewSize/image.width,
                height: (obj.ymax - obj.ymin)*widget.previewSize/image.height,
              ),
          ),
      );
    }
  }


  @override
  Widget build(BuildContext context){
    //TODO:Placeholder
    return Scaffold(
      appBar: AppBar(
        title: const Center(child:Text('Plaque Counts')),
      ),
      body:Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 100),
            SizedBox(
              height: widget.previewSize,
              width: widget.previewSize,
              child: Stack(
                children:drawStack,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _checkSize,
              style: ElevatedButton.styleFrom(
                primary: Colors.purple,
              ),
              child: const Text('Count plaques'),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: const BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.all(Radius.circular(10),
                ),
              ),
              child: IconButton(
                padding: const EdgeInsets.all(0),
                alignment: Alignment.center,
                icon: const Icon(Icons.help_outline,size:30),
                color: Colors.white,
                onPressed: _toHelp,
              ),
            ),
          ],
        ),
        ),
    );
  }
}

