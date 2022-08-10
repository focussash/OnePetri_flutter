//Defines an object to store model-identified results such as petri dish info or viral plaque, and NMS later
class DetectedObj{
  late double xmin;
  late double ymin;
  late double xmax;
  late double ymax;
  late double confidence;

  DetectedObj(this.xmin,this.ymin,this.xmax,this.ymax,this.confidence);
}