library open_packer;

import 'dart:html';
import 'dart:math' hide Rectangle;
import 'package:stagexl/stagexl.dart';

part 'src/packee.dart';
part 'src/packer.dart';

void initPacker() {
  
  //let's randomly draw some rectangles to the screen
  var canvas = querySelector('#canvas');
  var stage = new Stage(canvas, webGL: false, color: 0x00FFFFFF)..scaleMode;
  var renderLoop = new RenderLoop()..addStage(stage);
  
  InputElement numberInput = querySelector('#number');
  int number = int.parse(numberInput.value);
  
  var packer = new Packer(number, stage.sourceWidth, stage.sourceHeight, allowRotation: true);
  
  stage.addChild(packer);
  
  querySelector('#pack').onClick.listen((e) {
    packer.pack();
  });
  
  
}

