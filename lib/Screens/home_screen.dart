import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:onepetri/Objects/ml_parameters.dart';
import 'package:onepetri/Screens/dish_selection_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  //Home screen

  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {

  ml_Parameters parameters = ml_Parameters();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _getPref();
    _getPermission();
  }

  Future<void> _getPref() async {
    parameters = await ml_Parameters().update();
    setState(() {
    });
  }

  void _getPermission() async{
    //request relevant permission if not granted before
    //These wont work for IOS at the moment as I do not have podfile file in IOS folder, need to
    //request permission there as well
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.storage,
      Permission.photos,
    ].request();
  }

  //Define button actions:
  void _toAlbum() async{
    final navigator = Navigator.of(context); //Because we don't want to BuildContext after the async call
    final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
    if (photo != null){
      navigator.push(MaterialPageRoute(builder: (_) => DishSelection(imageFile:photo,parameters:parameters)));
    }
  }

  void _toCamera() async{
    final navigator = Navigator.of(context);
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null){
      navigator.push(MaterialPageRoute(builder: (_) => DishSelection(imageFile:photo,parameters:parameters)));
    }
  }

  //toAssay is currently a placeholder. TODO: actually implement this function
  Future<void> _toAssay() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Coming soon!',
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: const <Widget>[
                SizedBox(height:10),
                Text('This function is under construction.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 20
                  ),
                ),
                SizedBox(height: 20),
                Text('For now please use quick counts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 20
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('ok',
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

  Future<void> _toTips() async {
  if (!await launchUrl(Uri.parse('https://onepetri.ai/tips/'))) {
    throw 'Could not launch tips';
  }
  }

  void _toSettings(){
    Navigator.pushNamed(context, '/settings',);
  }
  //End of buttons actions

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
        body: Container(
          padding: const EdgeInsets.only(top: 100),
          child:Column(
            children: [
              SizedBox(
                width: 250,
                height: 250,
                child: Image.asset('assets/logo.png'),
              ),
              const SizedBox(height: 80,),
              Column(
                mainAxisSize: MainAxisSize.min,
                children:[
                  const Text('Quick count:'),
                  const SizedBox(height: 10,),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        padding: const EdgeInsets.all(0),
                        alignment: Alignment.center,
                        icon: const Icon(Icons.collections_rounded,size:50),
                        color: Colors.blue[500],
                        onPressed: _toAlbum,
                      ),
                      const SizedBox(width: 10,),
                      IconButton(
                        padding: const EdgeInsets.all(0),
                        alignment: Alignment.center,
                        icon: const Icon(Icons.photo_camera,size:50),
                        color: Colors.blue[500],
                        onPressed: _toCamera,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10,),
                  const Text('Perform an assay:'),
                  const SizedBox(height: 10,),
                  ElevatedButton(
                    onPressed: _toAssay,
                    style: ElevatedButton.styleFrom(
                      primary: Colors.purple,
                    ),
                    child: const Text('Plague Assay'),
                  ),
                ],
              ),
              const SizedBox(height: 10,),
              const Text('Additional assays and bacterial\n CFU support coming soon!',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 120),
              Expanded(
                child:Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(width: 30),
                    SizedBox(width: 120, child: Text('Version ${parameters.package.version} - ${parameters.package.buildNumber}'),),
                    const SizedBox(width: 120),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.all(Radius.circular(10),
                        ),
                      ),
                      child: IconButton(
                        padding: const EdgeInsets.all(0),
                        alignment: Alignment.center,
                        icon: const Icon(Icons.lightbulb_outline,size:30),
                        color: Colors.white,
                        onPressed: _toTips,
                      ),
                    ),
                    const SizedBox(width: 30),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.all(Radius.circular(10),
                        ),
                      ),
                      child: IconButton(
                        padding: const EdgeInsets.all(0),
                        alignment: Alignment.center,
                        icon: const Icon(Icons.settings,size:30),
                        color: Colors.white,
                        onPressed: _toSettings,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
    );
  }
}
