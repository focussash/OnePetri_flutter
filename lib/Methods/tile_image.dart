import 'package:image/image.dart' as img;
import 'package:onepetri/Objects/tile.dart';
import 'package:onepetri/Methods/image_processing.dart';
//This implements a method to tile an image into tiles based on the size of input

//Tiling logic:
//1. Create as many full-sized main tiles as possible
//2. For each axis that still has length after main tiles, create extra tiles to account for these
//3. If both axes needed extra tiles, then create one last tile to account for the bottom right corner
//4. For each shared border between 2 tiles, add another overlap tile
//TODO: This is still under construction, AND NOT IN USE
// But downside of this method is it creates too many tiles and will likely hinder performance
// For now use tileImage2 (below)
tileImage(img.Image source, int tilePxSize){
  //This takes source image and tile it into smaller square images (wrapped with tile object) each of tilePxSize X tilePxSize
  //The coordinates of each tile, in pixels, will be absolute units (normalized to the size of source image).
  var tileList = <Tile>[]; //Stores output
  //First, get the main tiles (full size, no need for padding)
  int tileCountX = (source.width/tilePxSize).floor();
  int tileCountY = (source.height/tilePxSize).floor();
  //Create main tiles

  //Now create extra tiles to account for each shared border between 2 main tiles
  int overlapTileCountX = (tileCountX/2).floor()*tileCountY; //Between each pair of main tiles along X Axis
  int overlapTileCountY = (tileCountY/2).floor()*tileCountX; //Between each pair of main tiles along Y Axis

  if (source.width - tilePxSize*tileCountX > 0){
    //If the Width has reminder, add extra X tiles here
    //Also add an overlap tile between each extra X tile and its left neighbour (last main tile)
  }
  if (source.height - tilePxSize*tileCountY > 0){
    //If the Height has reminder, add extra Y tiles here
    //Also add an overlap tile between each extra Y tile and its top neighbour (last main tile)
  }
  if ((source.width - tilePxSize*tileCountX > 0) && (source.height - tilePxSize*tileCountY > 0)){
    //Add final extra tile here
    //Add one overlap between X and this
    //Add another overlap between Y and this
  }

  //Now, give each tile its corresponding image from petri dish image
  for (Tile tile in tileList){
    cropTile(source,tile,tilePxSize);
  }
}

//Alternative tiling logic:
//1. Count how many full-sized main tile would be created per axis, add one more to each axis (ceil)
//2. Re-scale the tile size, such that this many main tiles cover ALL raw image space (meaning the final tiles will be smaller
//then originally defined full-size. Then, increase the tile size along each axis by X%
//3. Lay the tiles such that each subsequent tile is X% overlaid with the previous tile
tileImage2(img.Image source, int tilePxSize, {int overlayPercent = 25}){
  //This takes source image and tile it into smaller square images (wrapped with tile object) each of tilePxSize X tilePxSize
  //The coordinates of each tile, in pixels, will be absolute units (normalized to the size of source image).
  var tileList = <Tile>[]; //Stores output
  int tileCountX = (source.width/tilePxSize).ceil();
  int tileCountY = (source.height/tilePxSize).ceil();

  //Dynamically resize the tiles so they occupy the whole image, overlapping each other at set percentage
  int tileWidth = ((source.width/tileCountX)*(1+overlayPercent/100)).floor();
  int tileHeight = ((source.height/tileCountY)*(1+overlayPercent/100)).floor();
  //If the overlapping requirement make the tiles bigger than model, we add additional tiles to decrease tile size
  //This way we don't lose resolution due to too big tiles
  while (tileWidth > tilePxSize){
    tileCountX += 1;
    tileWidth = ((source.width/tileCountX)*(1+overlayPercent/100)).floor();
  }
  while(tileHeight > tilePxSize){
    tileCountY += 1;
    tileHeight = ((source.height/tileCountY)*(1+overlayPercent/100)).floor();
  }

  int totalWidth = 0,totalHeight = 0; //To track how much of initial image the tiles covered, and adjust the final tile if necessary due to rounding errors
  bool trimmed = false;
  for (var i = 0; i < tileCountX; i++){
    for (var j = 0; j < tileCountY; j++){
      //Make sure that the last tile doesn't extend beyond the source size. Otherwise, use normal height and width
      if (totalWidth + tileWidth > source.width){
        tileWidth = source.width - totalWidth;
        trimmed = true;
      }
      if(totalHeight + tileHeight > source.height){
        tileHeight = source.height - totalHeight;
        trimmed = true;
      }
      if (!trimmed){
         tileWidth = ((source.width/tileCountX)*(1+overlayPercent/100)).floor();
         tileHeight = ((source.height/tileCountY)*(1+overlayPercent/100)).floor();
      }
      img.Image tempImg = img.Image(0,0);//create a placeholder image
      Tile tile = Tile(totalWidth,totalHeight,totalWidth+tileWidth,totalHeight+tileHeight,tempImg);
      cropTile(source,tile,tilePxSize);
      //Debug. TODO: remove
      print('This tile has: xmin = ${tile.xmin}, ymin = ${tile.ymin}, xmax = ${tile.xmax}, ymax = ${tile.ymax}');
      //End of debug
      tileList.add(tile);
      //Now update the starting coordinates for the next tile, ensuring there is set overlap
      ////Update totalHeight at column level
      //This math should ensure that, without rounding error, the full source dimensions be covered by the tiles
      totalHeight += ((source.height/tileCountY)*(1-overlayPercent/100/(tileCountY-1))).ceil();
    }
    totalHeight = 0; //For each new row, reset totalHeight
    //Update totalWidth at row level
    totalWidth += ((source.width/tileCountX)*(1-overlayPercent/100/(tileCountX-1))).ceil();
  }
  return tileList;
}

cropTile(img.Image source, Tile tile, int tilePxSize){
  //For each tile, get its corresponding subimage
  //Crop an image to return the image of cropped tile.
  //If the tile is smaller than tilePxSize then we need to pad the remainder (in tileImage's case)
  //If the tile is bigger than tilePxSize then we need to "scale-to-fit" (in tileImage2's case)
  img.Image croppedImage;
  bool needPad = false;
  bool needScale = false;

  int xmin = tile.xmin;
  int ymin = tile.ymin;
  int xmax = tile.xmax;
  int ymax = tile.ymax;
  int width = xmax - xmin;
  int height = ymax - ymin;

  tile.image = cropPadTile(source, xmin, ymin, width, height, tilePxSize,img.getColor(0, 0, 0));
}


