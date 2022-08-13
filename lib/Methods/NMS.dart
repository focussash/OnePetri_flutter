import 'package:onepetri/Objects/detected_obj.dart';
import 'dart:math';

//This file contains functions related to implementing NMS over a list of objects
//It is written based on: https://learnopencv.com/non-maximum-suppression-theory-and-implementation-in-pytorch/
 NMS(List<DetectedObj> inputList,double iouThreshold){
   var outputList = <DetectedObj>[];
   inputList.sort((a, b) => a.confidence.compareTo(b.confidence));
   while (inputList.isNotEmpty){
     var keep = inputList[0];
     outputList.add(keep);
     inputList.remove(keep);
     if (inputList.isEmpty){
       break;
     }
     inputList.removeWhere((obj)=> iouCalc(obj,keep) > iouThreshold);
   }
   return outputList;
 }

 iouCalc(DetectedObj objA, DetectedObj objB){
   //Calculate the IOU fraction of 2 petri dish images
   double areaA = (objA.xmax - objA.xmin)*(objA.ymax - objA.ymin);
   double areaB = (objB.xmax - objB.xmin)*(objB.ymax - objB.ymin);
   double iouXmin = max(objA.xmin,objB.xmin);
   double iouYmin = max(objA.ymin,objB.ymin);
   double iouXmax = min(objA.xmax,objB.xmax);
   double iouYmax = min(objA.ymax,objB.ymax);
   double iouWidth = max(0,iouXmax - iouXmin);
   double iouHeight = max(0,iouYmax - iouYmin);
   double iouArea = iouWidth * iouHeight;
   double unionArea = areaA + areaB - iouArea;

   return iouArea/unionArea;
 }