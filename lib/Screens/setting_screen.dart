import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:onepetri/Settings/ml_parameters.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}
class _SettingsState extends State<Settings> {

  ml_Parameters _parameters = ml_Parameters();
  ml_Parameters _default_parameters = ml_Parameters();

  //Define text editing controllers
  final TextEditingController _petriConfController = TextEditingController(text: '');
  final TextEditingController _petriIOUController = TextEditingController(text: '');
  final TextEditingController _plaqueConfController = TextEditingController(text: '');
  final TextEditingController _plaqueIOUController = TextEditingController(text: '');

  final setting_entry _petriConfThreshold = setting_entry(name: 'petriConfThreshold',value:0);
  final setting_entry _petriIOUThreshold = setting_entry(name: 'petriIOUThreshold',value:0);
  final setting_entry _plaqueConfThreshold = setting_entry(name: 'plaqueConfThreshold',value:0);
  final setting_entry _plaqueIOUThreshold = setting_entry(name: 'plaqueIOUThreshold', value:0);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _petriConfController.dispose();
    _petriIOUController.dispose();
    _plaqueConfController.dispose();
    _plaqueIOUController.dispose();
    super.dispose();
  }

  Future<void> _getPref() async {
    _parameters = await ml_Parameters().update();
    setState(() {
      _updateEntry();
    });
  }

  void _initialize() async{
    await _getPref();
    _petriConfController.text = '${_parameters.petriConfThreshold}';
    _petriIOUController.text = '${_parameters.petriIOUThreshold}';
    _plaqueConfController.text = '${_parameters.plaqueConfThreshold}';
    _plaqueIOUController.text = '${_parameters.plaqueIOUThreshold}';
  }

  //Also define a method to update the new values to shared_preferences.
  Future<void> _setPref(String name, double newValue) async {
    // Shared preferences only supports 1 instance as of 2022/07/30 so no need to assign constructor names
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(name, newValue);
  }

  //Also a method to update these setting wrapper classes:
  void _updateEntry() {
    _petriConfThreshold.value = _parameters.petriConfThreshold;
    _petriIOUThreshold.value = _parameters.petriIOUThreshold;
    _plaqueConfThreshold.value = _parameters.plaqueConfThreshold;
    _plaqueIOUThreshold.value = _parameters.plaqueIOUThreshold;
  }

  //Create an alert dialog for invalid parameter setting entries
  //I don't fully understand the future usage here so it's copied from official guide
  //https://api.flutter.dev/flutter/material/AlertDialog-class.html
  Future<void> _callAlert() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Invalid threshold',
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: const <Widget>[
                Text('The value entered should be between 0.00 and 1.00 (exclusively).',
                  style: TextStyle(
                      fontSize: 20
                  ),
                ),
                SizedBox(height: 20),
                Text('Please re-enter a valid threshold.',
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
  //End of alert dialog

  //Define button actions:
  Future<void> _sendEmail() async {
    if (!await launchUrl(Uri.parse('mailto:support@onepetri.ai'))) {
      throw 'Could not launch tips';
    }
  }

  Future<void> _toTech() async {
    if (!await launchUrl(Uri.parse('https://onepetri.ai/technology/'))) {
      throw 'Could not launch technology info';
    }
  }

  void _resetSetting(){
    _setPref('petriConfThreshold',_default_parameters.petriConfThreshold);
    _setPref('petriIOUThreshold',_default_parameters.petriIOUThreshold);
    _setPref('plaqueConfThreshold',_default_parameters.plaqueConfThreshold);
    _setPref('plaqueIOUThreshold',_default_parameters.plaqueIOUThreshold);
    _getPref();
  }
  //End of buttons actions

  //Creates a textfield for inputting parameters and saving to preferences instead of wrapping isEditing status with a class...
  //There has to be a better way to code the following widgets but since dart doesn't allow values
  //to be passed by reference currently I'm using this ugly but works way around.

  Widget parametersInputField(setting_entry,controller) {
    if (setting_entry.isEditing) {
      return Center(
        child: TextField(
          style: const TextStyle(
              fontSize: 20
          ),
          decoration: const InputDecoration(
          errorText: '',
          ),
          onSubmitted: (newValue){
           if (double.tryParse(controller.value.text) == null){
            setState(() {
              _callAlert();
              controller.text = setting_entry.value;
              });
           }
            else if ((double.tryParse(controller.value.text)! >= 0) && (double.tryParse(controller.value.text)! <= 1 )) {
              setState(() {
                _setPref(setting_entry.name, double.parse(newValue));
                _getPref();
                controller.text = newValue;
                setting_entry.isEditing = false;
              });
            }
            else {
              setState(() {
                _callAlert();
                controller.text = setting_entry.value;
              });
            }
          },
          autofocus: true,
          controller: controller,
        ),
      );
    }
    return Material(
      child: InkWell(
        onTap: (){
          setState(() {
            setting_entry.isEditing = true;
          });
        },
        child: Text('${setting_entry.value}',
              style: const TextStyle(
              fontSize: 18
          ),
        ),
      ),
    );
  }

  //End of textfield

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [Text('Settings'),],
        ),
        actions: <Widget> [
          IconButton(
            padding: const EdgeInsets.all(0),
            alignment: Alignment.center,
            icon: const Icon(Icons.info_outline_rounded,size:30),
            onPressed: _toTech,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 60,),
            const Text('Petri dish detection',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            ),
            const SizedBox(height: 20,),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children:[
                const Text('Confidence threshold:',
                  style: TextStyle(
                  fontSize: 18
                  ),
                ),
                const SizedBox(width: 20,),
                SizedBox(width: 40,
                child:parametersInputField(_petriConfThreshold,_petriConfController)
                ),
              ],
            ),
            const SizedBox(height: 20,),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children:[
                const Text('NMS IOU threshold:',
                  style: TextStyle(
                      fontSize: 18
                  ),
                ),
                const SizedBox(width: 20,),
                SizedBox(width: 40,
                    child:parametersInputField(_petriIOUThreshold,_petriIOUController)
                ),
              ],
            ),
            const SizedBox(height: 40,),

            const Text('Plaque detection',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20,),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children:[
                const Text('Confidence threshold:',
                  style: TextStyle(
                      fontSize: 18
                  ),
                ),
                const SizedBox(width: 20,),
                SizedBox(width: 40,
                    child:parametersInputField(_plaqueConfThreshold,_plaqueConfController)
                ),
              ],
            ),
            const SizedBox(height: 20,),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children:[
                const Text('NMS IOU threshold:',
                  style: TextStyle(
                      fontSize: 18
                  ),
                ),
                const SizedBox(width: 20,),
                SizedBox(width: 40,
                    child:parametersInputField(_plaqueIOUThreshold,_plaqueIOUController)
                ),
              ],
            ),
            const SizedBox(height: 20,),
            ElevatedButton(
              onPressed: _resetSetting,
              child: const Text('Reset settings to default'),
            ),
            const SizedBox(height: 20,),
            const Text('Help improve OnePetri!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20,),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children:  [
                const SizedBox(width: 100,
                  child:
                  Text('Send us your feedback!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                    fontSize: 15,
                    ),
                  ),
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
                    icon: const Icon(Icons.email_outlined,size:30),
                    color: Colors.white,
                    onPressed: _sendEmail,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 90,),
            Text('OnePetri version ${_parameters.package.version} - ${_parameters.package.buildNumber}',
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20,),
            const Text('Petri dish model version ${ml_Parameters.petriDishModelVersion}',
              style: TextStyle(
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20,),
            const Text('Plaque model version ${ml_Parameters.plaqueModelVersion}',
              style: TextStyle(
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class setting_entry{
  //a dummy wrapper class for each entry in the settings
  setting_entry({required this.name, required this.value});
  bool isEditing = false;
  String name = '';
  double value = 0;
}