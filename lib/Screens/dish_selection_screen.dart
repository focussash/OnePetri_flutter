import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:onepetri/Objects/ml_parameters.dart';
import 'package:onepetri/Objects/detected_obj.dart';
import 'package:onepetri/Methods/NMS.dart';
import 'package:onepetri/Methods/image_processing.dart';
import 'package:onepetri/Screens/plaque_counting_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'package:path_provider/path_provider.dart';

//Screen for taking and processing the image user selected
class DishSelection extends StatefulWidget {
  const DishSelection({super.key, required this.imageFile,required this.parameters});
  final int pxSize = 640;//The pixel size used in model. Here the unit is PIXEL, NOT LOGICAL PIXEL
  final double previewSize = 360;//The size (both height and width) of the preview image displayed
  final XFile imageFile;
  final ml_Parameters parameters;

  @override
  State<DishSelection> createState() => _DishSelectionState();
}

class _DishSelectionState extends State<DishSelection> {

  late File image;
  late File imageOriginal; //To keep the image not rescaled to 640X640, for cropping petri dish from
  late TensorImage tensorImage;
  final ImagePicker _picker = ImagePicker();
  late double petriConfThreshold,petriIOUThreshold;
  late tfl.Interpreter interpreter;

  late List<int> _outputShape;
  late tfl.TfLiteType _outputType;
  late TensorBuffer _outputBuffer;
  late TensorBuffer _inputBuffer; //This is necessary because the model takes batch size as an extra dimension
  late List<int> _inputShape;
  var detected = <DetectedObj>[];//To store detected objects

  List<Widget> drawStack = <Widget>[];//This is used to display the picture and draw rectangular boxes on identified petri dishes

  @override
  void initState() {
    super.initState();
    _initialize(widget.imageFile);
  }

  @override
  void dispose() {
    interpreter.close();
    super.dispose();
  }

  //TODO: it seems the initialization step, especially loading the image, is slow. Could use some optimization here
  void _initialize(XFile? file) async{
    //Get path to the cache
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = tempDir.path;
    //Take the passed parameters
    //Raw image needs to be center-cropped to 640X640 pixels for trained model
    image = File(file!.path);
    imageOriginal = await image.copy('${tempPath}temp.jpg');//Create a copy of the original image for later use
    await _loadModel();
    //Read the image and center crop it to size used for models
    setState(() {
      var _image = img.decodeImage(image.readAsBytesSync())!;
      _image = scaleImageCentered(_image, widget.pxSize, widget.pxSize, img.getColor(0, 0, 0));
      image.writeAsBytesSync(img.encodePng(_image));
      tensorImage = TensorImage.fromFile(image);
    });
    //Remove all previous detections
    drawStack.clear();
    detected.clear();
    //Add the initial layer (actual image) to the stack
    drawStack.add(SizedBox(
      height: widget.previewSize,
      width: widget.previewSize,
      child: Image.file(image,fit: BoxFit.cover,),
    ));
    await _detectPetri();
  }

  _loadModel() async{
    petriConfThreshold = widget.parameters.petriConfThreshold;
    petriIOUThreshold = widget.parameters.petriIOUThreshold;
    interpreter = await tfl.Interpreter.fromAsset("models/petridish-fp16.tflite");//This is the model for petri dish

    //Get and initialize output (the input is known and fixed by pre-processing above)
    interpreter.allocateTensors();
    _outputShape = interpreter.getOutputTensor(0).shape;
    _outputType = interpreter.getOutputTensor(0).type;
    _outputBuffer = TensorBuffer.createFixedSize(_outputShape, _outputType);

    //For debugging TODO:Remove
    _inputShape = interpreter.getInputTensor(0).shape;
    _inputBuffer = TensorBuffer.createFixedSize(_inputShape, _outputType);
    //End of debugging.
}

  _detectPetri() async{
    //detect petri dish
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
        if (temp2[i][4]>petriConfThreshold){
          detected.add(DetectedObj(max(0,temp2[i][0]-0.5*temp2[i][2]), max(0,temp2[i][1]-0.5*temp2[i][3]), temp2[i][0]+0.5*temp2[i][2], temp2[i][1]+0.5*temp2[i][3], temp2[i][4]));
        }
    }
    //Debug.TODO:remove
    //print('Pre NMS output is: ');
    //print(detected.length);
    detected = NMS(detected,petriIOUThreshold);
    _drawRec();
  }

  //Map detected objects into preview coordinates, then draw rectangles in this stack, on top of preview
  //Gesture detectors for each detected object is also built here
  _drawRec(){
    for (var obj in detected){
      drawStack.add(
          Positioned(
            left: obj.xmin*widget.previewSize,
            top: obj.ymin*widget.previewSize,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                  // TODO: Bring this petri dish to further analysis
                  final navigator = Navigator.of(context);
                  var tempImage = img.decodeImage(imageOriginal.readAsBytesSync())!;
                  tempImage = padCropObj(tempImage,obj.xmin,obj.ymin,obj.xmax,obj.ymax,img.getColor(0, 0, 0));
                  imageOriginal.writeAsBytesSync(img.encodePng(tempImage));
                  navigator.push(MaterialPageRoute(builder: (_) => PlaqueCounting(imageFile:imageOriginal,parameters:widget.parameters)));
                },
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.yellow,  // red as border color
                    width: 3,
                  ),
                ),
                width: (obj.xmax - obj.xmin)*widget.previewSize,
                height: (obj.ymax - obj.ymin)*widget.previewSize,
              ),
            ),
          )
      );
    }
  }

  void _toAlbum() async{
    _initialize(await _picker.pickImage(source: ImageSource.gallery));
  }

  void _toCamera() async{
    _initialize(await _picker.pickImage(source: ImageSource.camera));
  }

  Future<void> _sendEmail() async {
    //TODO: Implement a function so this automatically adds the picture in question as attachment
    //That would need to use another plugin
    if (!await launchUrl(Uri.parse('mailto:support@onepetri.ai'))) {
      throw 'Could not connect to Email';
    }
  }

  Future<void> _toHelp() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Missing Petri dish?',
            textAlign: TextAlign.center,
          ),
          content: const SingleChildScrollView(
            child: Center(
              child: Text("If a Petri dish was not detected, you may submit the selected image to help improve future iterations of OnePetri's AI models. Would you like to submit this image for analysis?",
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

  //Display the text depending on how many petri dishes are detected
  Widget petriDishText(){
    if (detected.isEmpty) {
      return const Text('No petri dish detected. Tap help to submit the picture and help us improve OnePetri!',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 18
        ),
      );
    }
    if (detected.length == 1) {
      return const Text('1 petri dish detected. Tap the petri dish to proceed with analysis.',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 18
        ),
      );
    }
    else{
      return Text('${detected.length} petri dishes detected. Tap the petri dish of interest to proceed with analysis.',
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 18
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child:Text('Select Petri Dish')),
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
            const SizedBox(height: 80),
            petriDishText(),
            const SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children:[
                IconButton(
                  padding: const EdgeInsets.all(0),
                  alignment: Alignment.center,
                  icon: const Icon(Icons.collections_rounded,size:50),
                  color: Colors.blue[500],
                  onPressed: _toAlbum,
                ),
                const SizedBox(width: 20,),
                IconButton(
                  padding: const EdgeInsets.all(0),
                  alignment: Alignment.center,
                  icon: const Icon(Icons.photo_camera,size:50),
                  color: Colors.blue[500],
                  onPressed: _toCamera,
                ),
                const SizedBox(width: 20,),
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
          ],
        ),
    ),
    );
  }
}