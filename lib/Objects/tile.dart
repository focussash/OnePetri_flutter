import 'package:image/image.dart' as img;

//Defines a tile object for separating a petri dish's image into tiles
//Here the coordinates will be in pixels, hence integer
class Tile{
  late int xmin;
  late int ymin;
  late int xmax;
  late int ymax;
  late img.Image image;

  Tile(this.xmin,this.ymin,this.xmax,this.ymax,this.image);
}