import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:onepetri/Objects/ml_parameters.dart';
import 'package:onepetri/Objects/detected_obj.dart';
import 'package:onepetri/Methods/NMS.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

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
  //late img.Image croppedImage;
  late TensorImage tensorImage;
  final ImagePicker _picker = ImagePicker();
  late double petriConfThreshold,petriIOUThreshold;
  late tfl.Interpreter interpreter;
  late ImageProcessor imageProcessor;

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

  void _initialize(XFile? file) async{
    //Take the passed parameters
    //Raw image needs to be center-cropped to 640X640 pixels for trained model
    image = File(file!.path);
    await _loadModel();
    //Read the image and center crop it to size used for models
    setState(() {
      //Temporarily, not using the imageProcessor provided by TensorImage as that cropping method loses too much info
      var _image = img.decodeImage(image.readAsBytesSync())!;
      //_image = img.copyResizeCropSquare(_image,widget.pxSize);
      _image = scaleImageCentered(_image, widget.pxSize, widget.pxSize, img.getColor(0, 0, 0));
      image.writeAsBytesSync(img.encodePng(_image));
      tensorImage = TensorImage.fromFile(image);
      //tensorImage = imageProcessor.process(tensorImage);
      //image.writeAsBytesSync(img.encodePng(tensorImage.image));
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
    imageProcessor = ImageProcessorBuilder().add(ResizeWithCropOrPadOp(widget.pxSize,widget.pxSize)).build();
    interpreter = await tfl.Interpreter.fromAsset("models/Yv5-fp16.tflite");

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
          for (var j = 0;j<4;j++){
            temp2[i][j] *= widget.pxSize; //To convert back the relative coordinates to pixel coordinates
          }
          detected.add(DetectedObj(max(0,temp2[i][0]-0.5*temp2[i][2]), max(0,temp2[i][1]-0.5*temp2[i][3]), temp2[i][0]+0.5*temp2[i][2], temp2[i][1]+0.5*temp2[i][3], temp2[i][4]));
        }
    }
    //Debug.TODO:remove
    //print('Pre NMS output is: ');
    //print(detected.length);
    detected = NMS(detected,petriIOUThreshold);
    _getRecCords();
    _drawRec();
  }

  //Map detected objects into preview coordinates, then draw rectangles in this stack, on top of preview
  _getRecCords(){
    //Calculate the coordinates to plot rectangles
    for (var obj in detected){
      obj.xmax *= (360/widget.pxSize);
      obj.ymax *= (360/widget.pxSize);
      obj.xmin *= (360/widget.pxSize);
      obj.ymin *= (360/widget.pxSize);
    }
  }
  _drawRec(){
    for (var obj in detected){
      drawStack.add(
          Positioned(
            left: obj.xmin,
            top: obj.ymin,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() {
                  // TODO: Bring this petri dish to further analysis
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.yellow,  // red as border color
                    width: 3,
                  ),
                ),
                width: obj.xmax-obj.xmin,
                height: obj.ymax - obj.ymin,
              ),
            ),
          )
      );
    }
  }

  //A cool snippet for resizing image without cropping
  //Found it here: https://gist.github.com/slightfoot/1039d28a2161af4ef6f733bfe4d4e10e
  img.Image scaleImageCentered(img.Image source, int maxWidth, int maxHeight, int colorBackground) {
    final double scaleX = maxWidth/ source.width ;
    final double scaleY = maxHeight/ source.height ;
    final double scale = (scaleX * source.height > maxHeight) ? scaleY : scaleX;
    final int width = (source.width * scale).round();
    final int height = (source.height * scale).round();
    return img.drawImage(
        new img.Image(maxWidth, maxHeight)..fill(colorBackground),
        img.copyResize(source,width:width,height: height),
        dstX: ((maxWidth - width) / 2).round(),
        dstY: ((maxHeight - height) / 2).round());
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

  //Create an alert dialog for Help menu
  //As mentioned before, I don't fully understand the future usage here so it's copied from official guide
  //https://api.flutter.dev/flutter/material/AlertDialog-class.html
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
  //End of alert dialog

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child:Text('Select petri dish')),
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
            Text('${detected.length} petri dish detected. Tap the petri dish of interest to proceed with analysis.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18
              ),
            ),
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
              ],),
          ],
        ),
    ),
    );
  }
}