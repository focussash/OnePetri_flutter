import 'package:image/image.dart' as img;

//A cool snippet for resizing image without cropping
//Found it here: https://gist.github.com/slightfoot/1039d28a2161af4ef6f733bfe4d4e10e
//Basically to "scale-to-fit" an image in Apple's terms, but place raw image in center
//In use for dish_selection_screen
img.Image scaleImageCentered(img.Image source, int maxWidth, int maxHeight, int colorBackground) {
  final double scaleX = maxWidth/ source.width ;
  final double scaleY = maxHeight/ source.height ;
  final double scale = (scaleX * source.height > maxHeight) ? scaleY : scaleX;
  final int width = (source.width * scale).round();
  final int height = (source.height * scale).round();
  return img.drawImage(
      img.Image(maxWidth, maxHeight)..fill(colorBackground),
      img.copyResize(source,width:width,height: height),
      dstX: ((maxWidth - width) / 2).round(),
      dstY: ((maxHeight - height) / 2).round());
}

//To resize and pad an image to square size (original image on top left corner)
//in Apple's terms, to "scale-to-fit" an image, in use for tiling an image (in cropPadTile method)
img.Image scaleImageTopLeft(img.Image source, int maxWidth, int maxHeight, int colorBackground) {
  final double scaleX = maxWidth/ source.width ;
  final double scaleY = maxHeight/ source.height ;
  final double scale = (scaleX * source.height > maxHeight) ? scaleY : scaleX;
  final int width = (source.width * scale).round();
  final int height = (source.height * scale).round();
  return img.drawImage(
      img.Image(maxWidth, maxHeight)..fill(colorBackground),
      img.copyResize(source,width:width,height: height),
      dstX: 0,
      dstY: 0);
}

//To crop and image based on coordinates, then pad it to square shape and place at the top left corner
//For cropping images for tiles of petri dish
img.Image cropPadTile(img.Image source, int xmin, int ymin, int width, int height, int newDim, int colorBackground) {
  //Here, the input coordinates are the absolute coordinates of tile to crop, in pixels.
  //Regardless of the tile original size, the padded image should be padded to the same size as ML model requirements.

  img.Image tempImg;
  img.Image croppedImage = img.copyCrop(source, xmin, ymin, width, height); //Crop the tile original image from source

  //Check whether we need rescaling and padding of raw image
  if (((width > newDim) || (height > newDim)) || ((width < newDim) && (height < newDim))){
    //Either: 1) Too big, need to rescale and place in top left
    //Or: 2) Too small with both axes smaller than the required dimensions
    tempImg = scaleImageTopLeft(croppedImage,newDim,newDim,img.getColor(0, 0, 0));
  }
  else if ((width < newDim) || (height < newDim)){
    //Too small (one of the extra tiles), need to pad it bigger without rescaling (because one of the axes should be of the right size)
    if ((width != newDim) || (height != newDim)){ //Sanity check. In this case we should have at least one axis of the right size
      throw Exception('Tile height and width not matching');
    }
    tempImg = img.drawImage(
        img.Image(newDim, newDim)..fill(colorBackground),
        croppedImage,
        dstX: 0,
        dstY: 0);
  }
  else { //If the cropped image is already square and of the right size then we do nothing
    if (width != height){ //Sanity check. In this case we should have a square image
      throw Exception('Tile height and width not matching');
    }
    tempImg = croppedImage;
  }
  //Pad the tile original image to right size
  //We place the new image on top left corner so the coordinates will be continous
  return tempImg;
}

//To pad an image to square shape and place the original image at center, then crop it at given coordinates
//Used to send selected petri dish image for plaque counting
img.Image padCropObj(img.Image source, double xMinObj, double yMinObj, double xMaxObj, double yMaxObj, int colorBackground) {
  //Here, the input coordinates are the relative coordinates of petri dish found by YoloV5.
  double width = xMaxObj - xMinObj;
  double height = yMaxObj - yMinObj;

  //Get offsets for the new image to keep the original center.
  int newDim = (source.width > source.height)? source.width:source.height;
  double dX = (source.width < source.height)? (source.height - source.width)/2 : 0;
  double dY = (source.width > source.height)? (source.width - source.height)/2 : 0;

  //Create a square image of at least original resolution (take the larger side) to crop petri dish from
  img.Image tempImg = img.drawImage(
      img.Image(newDim, newDim)..fill(colorBackground),
      source,
      dstX: dX.round(),
      dstY: dY.round());
  return img.copyCrop(tempImg, (xMinObj*tempImg.width).round(), (yMinObj*tempImg.height).round(), (width*tempImg.width).round(), (height*tempImg.width).round());
}