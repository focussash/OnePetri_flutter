import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

//A  class storing all the parameters used for ML in OnePetri, including settings as well as version numbers etc
class ml_Parameters {
  //model versions are hardcoded
  static const String petriDishModelVersion = "1.2";
  static const String plaqueModelVersion = "1.2";

  //Initialize the thresholds to default
  double petriConfThreshold= 0.8,petriIOUThreshold = 0.5,plaqueConfThreshold =0.8 ,plaqueIOUThreshold = 0.5;
  //plus other settings needed

  PackageInfo package = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
  );

  Future<ml_Parameters> update() async {
    //get user saved settings for parameters. If there is none, then take the default values
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final pref = await SharedPreferences.getInstance();

    package = packageInfo;
    //If settings aren't saved in preference, return back to default values
    petriConfThreshold = pref.getDouble('petriConfThreshold') ?? petriConfThreshold;
    petriIOUThreshold = pref.getDouble('petriIOUThreshold') ?? petriIOUThreshold;
    plaqueConfThreshold = pref.getDouble('plaqueConfThreshold') ?? plaqueConfThreshold;
    plaqueIOUThreshold = pref.getDouble('plaqueIOUThreshold') ?? plaqueIOUThreshold;
    return this;
  }

}