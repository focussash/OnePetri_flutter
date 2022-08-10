//Defines a plaque object to store model-identified petri dish info, and NMS later
class Plaque{
  late double xmin;
  late double ymin;
  late double xmax;
  late double ymax;
  late double confidence;

  Plaque(this.xmin,this.ymin,this.xmax,this.ymax,this.confidence);
}