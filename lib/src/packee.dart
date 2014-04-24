part of open_packer;

class Packee extends Sprite {
  Bitmap visual;
  TextField label;
  int color;
  bool rotated;
  bool trimmed;
  
  Packee(String name, int x, int y, int w, int h, {int color: 0xFFFFFFFF}) {
    this
        ..name = name
        ..x = x
        ..y = y
        ..color = color
        ..width = w
        ..height = h;
    
    var rect = new BitmapData(w, h, true, color);
    visual = new Bitmap(rect);
    
    label = new TextField(name, new TextFormat('sans-serif', min(50,min(w, h)*.5), Color.White))
      ..width = w - 5
      ..height = h
      ..x = 5;
    
    addChild(visual);
    addChild(label);
     
  }
  
}