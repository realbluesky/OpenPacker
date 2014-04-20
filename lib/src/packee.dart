part of open_packer;

class Packee extends Sprite {
  Bitmap visual;
  int color;
  bool rotated;
  bool trimmed;
  
  Packee(int x, int y, int w, int h, {int color: 0xAA000000}) {
    this
        ..x = x
        ..y = y
        ..color = color
        ..width = w
        ..height = h;
    
    var rect = new BitmapData(w, h, true, color);
    visual = new Bitmap(rect);
    
    addChild(visual);
   
    onMouseClick.listen((e) => print('x:$x y:$y w:$width h:$height rot:$rotation'));
    onMouseRightClick.listen((e) => rotation+=PI/2);
    
  }
  
}