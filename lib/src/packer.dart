part of open_packer;

class ScoreResult {
  Rectangle node;
  num primary;
  num tieBreaker;
  
  ScoreResult(this.node, this.primary, this.tieBreaker);
}

class PackMethod {
  static const String totalArea = 'totalArea';
  static const String shortSide = 'shortSide'; 
  static const String bottomLeft = 'bottomLeft';
  static const String longSide = 'longSide';
  static const String area = 'area';
  static const String contactPoint = 'contactPoint';
}

class Packer extends DisplayObjectContainer {
  static const MAX = 1000000;
  static const _defaultPackMethod = PackMethod.totalArea;
  
  List<Packee> _packees, _toPack, _packed;
  List<Rectangle> _freeRects, _usedRects;
  bool _allowRotation;
  String _packMethod;
  int _num, _binWidth, _binHeight;
  Bitmap _visualRects;
  Random _rand = new Random();
  
  Packer(Map<String, dynamic> options) {
    
    _num = options['number'];
    _binWidth = options['width'];
    _binHeight = options['height'];
    _allowRotation = options['rotation'];
    _packees = [];
    _toPack = [];
    _packed = [];
    
    _visualRects = new Bitmap(new BitmapData(_binWidth, _binHeight, true, Color.Transparent))..alpha=.4..addTo(this);
    
    //TEMPORARY - randomly generate rectangles to test
    _generateSample(options);
    //end temporary
 
    
  }
  
  void reset(Map<String, dynamic> options) {
    _num = options['number'];
    _binWidth = options['width'];
    _binHeight = options['height'];
    
    _allowRotation = options['rotation'];
    removeChildren();
    _visualRects = new Bitmap(new BitmapData(_binWidth, _binHeight, true, Color.Transparent))..alpha=.4..addTo(this);
    _generateSample(options);
    _reset();
    pack(options['method']);
  }
  
  void _generateSample(Map<String, dynamic> options) {
    _packees.clear();
    
    for (int i=0; i<_num; i++) {
      var w = options['min']+_rand.nextInt(options['var']);
      var h = options['min']+_rand.nextInt(options['var']);
      var c = _randColor();
      
      var packee = new Packee((i+1).toString(), 0, 0, w, h, color: c)..alpha=0;
      _packees.add(packee);
      addChild(packee);
    }
  }
  
  /// Computes the ratio of used surface area.
  num _occupancy() {
    //fail if not fully packed
    if(_packed.length != _packees.length) return -1.0;
    num usedSurfaceArea = 0;
    for(var i = 0; i < _usedRects.length; i++)
      usedSurfaceArea += _usedRects[i].width * _usedRects[i].height;
    
    var usedRect = _totalUsedRect();
    return usedSurfaceArea / (usedRect.width * usedRect.height);
      
  }

  
  double pack([String packMethod = _defaultPackMethod]) {
    
    _reset();
    bool packing = true;
    while(_toPack.length > 0 && packing) packing = _packNext(packMethod);
    
    return _occupancy();
        
  }
  
  void packOne([String packMethod = _defaultPackMethod]) {
    if(_toPack.length == 0) _reset();
    _packNext(packMethod);
  }
  
  void _reset() {
    _usedRects = [];
    
    /*
    stage
        ..width = _binWidth
        ..height = _binHeight;
    */
    
    _freeRects = [new Rectangle(0, 0, _binWidth, _binHeight)];
    _packees.forEach((p) => p..rotated=false..rotation=0..x=0..y=0..alpha=0);
    _packed.clear();
    _toPack = new List.from(_packees);
  }
  
  bool _packNext(String packMethod) {
    num primary = MAX, tieBreaker = MAX, bestRectIndex = -1;
    Rectangle bestNode;
    
    for(var i=0; i<_toPack.length; i++) {
      var packee = _toPack[i];
      
      ScoreResult result;
      
      switch(packMethod) {
        case PackMethod.totalArea: result = _totalAreaFit(packee.width.toInt(), packee.height.toInt()); break;
        case PackMethod.shortSide: result = _shortSideFit(packee.width.toInt(), packee.height.toInt()); break;
        case PackMethod.longSide: result = _longSideFit(packee.width.toInt(), packee.height.toInt()); break;
        case PackMethod.bottomLeft: result = _bottomLeft(packee.width.toInt(), packee.height.toInt()); break;
        case PackMethod.area: result = _areaFit(packee.width.toInt(), packee.height.toInt()); break;
        case PackMethod.contactPoint: result = _contactPoint(packee.width.toInt(), packee.height.toInt()); break;
      }
             
      if (result.primary < primary || (result.primary == primary && result.tieBreaker < tieBreaker))
      {
        primary = result.primary;
        tieBreaker = result.tieBreaker;
        bestNode = result.node;
        bestRectIndex = i;
      }
      
    }
    
    if (bestRectIndex == -1) return false;

    _placeRect(bestNode);
    var packee = _toPack.removeAt(bestRectIndex);
    
    if(bestNode.width != packee.width) { //she be flipped
      packee
          ..x = bestNode.left + packee.height
          ..rotated = true
          ..rotation = PI/2;
    } else {
      packee
          ..x = bestNode.left
          ..rotated = false
          ..rotation = 0;  
    }
    
    packee
        ..y = bestNode.top
        ..alpha = 1;
    
    _packed.add(packee);
    
    return true;
    
  }
  
  void _placeRect(Rectangle node)
  {
    var numRectanglesToProcess = _freeRects.length;
    for(var i=0; i < numRectanglesToProcess; i++)
    {
      if (_splitFreeNode(_freeRects[i], node))
      {
        _freeRects.removeAt(i);
        --i;
        --numRectanglesToProcess;
      }
    }

    _pruneFreeList();

    _usedRects.add(node);

  }
    
  // Pack Methods ----------------------------------------------------------------------------
  ScoreResult _totalAreaFit(int width, int height) {
      var bestArea = MAX, bestShortSide = MAX, rectArea = 0;
      var bestNode = new Rectangle(0, 0, 0, 0);
      
      for(var i = 0; i < _freeRects.length; i++) {
        // Try to place the rectangle in upright (non-flipped) orientation.
        if (_freeRects[i].width >= width && _freeRects[i].height >= height)
        {
          _usedRects.add(new Rectangle.from(_freeRects[i])..width=width..height=height);
          var usedRect = _totalUsedRect();
          var newRect = _usedRects.removeLast(); 
          
          //weight heuristic to lay larger down first
          var area = usedRect.width * usedRect.height / (newRect.width * newRect.height);
          var shortSide = min(usedRect.width, usedRect.height);

          
          if (area < bestArea || (area == bestArea && shortSide < bestShortSide))
          {
            bestNode = newRect;
            bestArea = area;
            bestShortSide = shortSide;
          }
          
        }

        if (_allowRotation && _freeRects[i].width >= height && _freeRects[i].height >= width) {
          //temporarily add and measure
          _usedRects.add(new Rectangle.from(_freeRects[i])..width=height..height=width);
          var usedRect = _totalUsedRect();
          var newRect = _usedRects.removeLast();
          var area = usedRect.width * usedRect.height / (newRect.width * newRect.height);
          var shortSide = min(usedRect.width, usedRect.height);
          
          if (area < bestArea || (area == bestArea && shortSide < bestShortSide))
          {
            bestNode = newRect;
            bestArea = area;
            bestShortSide = shortSide;
          }
        }
              
      }
      
        if(bestNode.height == 0) {
          bestArea = bestShortSide = MAX;
        }
        return new ScoreResult(bestNode, bestArea, bestShortSide);
        
    }
  
  ScoreResult _shortSideFit(int width, int height) {
    int bestShortSide = MAX, bestLongSide = MAX;
    var bestNode = new Rectangle(0, 0, 0, 0);
    
    for(var i = 0; i < _freeRects.length; i++)
      {
        // Try to place the rectangle in upright (non-flipped) orientation.
        if (_freeRects[i].width >= width && _freeRects[i].height >= height)
        {
          int leftoverHoriz = (_freeRects[i].width - width).abs().toInt();
          int leftoverVert = (_freeRects[i].height - height).abs().toInt();
          int shortSide = min(leftoverHoriz, leftoverVert);
          int longSide = max(leftoverHoriz, leftoverVert);

          if (shortSide < bestShortSide || (shortSide == bestShortSide && longSide < bestLongSide)) {
            bestNode
                ..left = _freeRects[i].left
                ..top = _freeRects[i].top
                ..width = width
                ..height = height;
            
            bestShortSide = shortSide;
            bestLongSide = longSide;
          }
        }

        if (_allowRotation && _freeRects[i].width >= height && _freeRects[i].height >= width) {
          int flippedLeftoverHoriz = (_freeRects[i].width - height).abs().toInt();
          int flippedLeftoverVert = (_freeRects[i].height - width).abs().toInt();
          int flippedShortSide = min(flippedLeftoverHoriz, flippedLeftoverVert);
          int flippedLongSide = max(flippedLeftoverHoriz, flippedLeftoverVert);

          if (flippedShortSide < bestShortSide || (flippedShortSide == bestShortSide && flippedLongSide < bestLongSide)) {
            bestNode
                ..left = _freeRects[i].left
                ..top = _freeRects[i].top
                ..width = height
                ..height = width;
            
            bestShortSide = flippedShortSide;
            bestLongSide = flippedLongSide;
          }
        }
        
        
      }
    
      if(bestNode.height == 0) {
        bestShortSide = bestLongSide = MAX;
      }
      return new ScoreResult(bestNode, bestShortSide, bestLongSide);
      
  }
  
  ScoreResult _longSideFit(int width, int height) {
      int bestShortSide = MAX, bestLongSide = MAX;
      var bestNode = new Rectangle(0, 0, 0, 0);
      
      for(var i = 0; i < _freeRects.length; i++)
        {
          // Try to place the rectangle in upright (non-flipped) orientation.
          if (_freeRects[i].width >= width && _freeRects[i].height >= height)
          {
            int leftoverHoriz = (_freeRects[i].width - width).abs().toInt();
            int leftoverVert = (_freeRects[i].height - height).abs().toInt();
            int shortSide = min(leftoverHoriz, leftoverVert);
            int longSide = max(leftoverHoriz, leftoverVert);

            if (longSide < bestLongSide || (longSide == bestLongSide && shortSide < bestShortSide)) {
              bestNode
                  ..left = _freeRects[i].left
                  ..top = _freeRects[i].top
                  ..width = width
                  ..height = height;
              
              bestShortSide = shortSide;
              bestLongSide = longSide;
            }
          }

          if (_allowRotation && _freeRects[i].width >= height && _freeRects[i].height >= width) {
            int flippedLeftoverHoriz = (_freeRects[i].width - height).abs().toInt();
            int flippedLeftoverVert = (_freeRects[i].height - width).abs().toInt();
            int flippedShortSide = min(flippedLeftoverHoriz, flippedLeftoverVert);
            int flippedLongSide = max(flippedLeftoverHoriz, flippedLeftoverVert);

            if (flippedLongSide < bestLongSide || (flippedLongSide == bestLongSide && flippedShortSide < bestShortSide)) {
              bestNode
                  ..left = _freeRects[i].left
                  ..top = _freeRects[i].top
                  ..width = height
                  ..height = width;
              
              bestShortSide = flippedShortSide;
              bestLongSide = flippedLongSide;
            }
          }
          
          
        }
      
        if(bestNode.height == 0) {
          bestShortSide = bestLongSide = MAX;
        }
        return new ScoreResult(bestNode, bestShortSide, bestLongSide);
        
    }
  
  ScoreResult _areaFit(int width, int height) {
      int bestArea = MAX, bestShortSide = MAX;
      var bestNode = new Rectangle(0, 0, 0, 0);
      
      for(var i = 0; i < _freeRects.length; i++)
        {
          int area = _freeRects[i].width * _freeRects[i].height - width * height;
        
          // Try to place the rectangle in upright (non-flipped) orientation.
          if (_freeRects[i].width >= width && _freeRects[i].height >= height)
          {
            int leftoverHoriz = (_freeRects[i].width - width).abs().toInt();
            int leftoverVert = (_freeRects[i].height - height).abs().toInt();
            int shortSide = min(leftoverHoriz, leftoverVert);

            if (area < bestArea || (area == bestArea && shortSide < bestShortSide)) {
              bestNode
                  ..left = _freeRects[i].left
                  ..top = _freeRects[i].top
                  ..width = width
                  ..height = height;
              
              bestShortSide = shortSide;
              bestArea= area;
            }
          }

          if (_allowRotation && _freeRects[i].width >= height && _freeRects[i].height >= width) {
            int flippedLeftoverHoriz = (_freeRects[i].width - height).abs().toInt();
            int flippedLeftoverVert = (_freeRects[i].height - width).abs().toInt();
            int flippedShortSide = min(flippedLeftoverHoriz, flippedLeftoverVert);

            if (area < bestArea || (area == bestArea && flippedShortSide < bestShortSide)) {
              bestNode
                  ..left = _freeRects[i].left
                  ..top = _freeRects[i].top
                  ..width = height
                  ..height = width;
              
              bestShortSide = flippedShortSide;
              bestArea = area;
            }
          }
          
          
        }
      
        if(bestNode.height == 0) {
          bestShortSide = bestArea = MAX;
        }
        return new ScoreResult(bestNode, bestArea, bestShortSide);
        
    }
  
  ScoreResult _bottomLeft(int width, int height) {

    int bestY = MAX, bestX = MAX;
    var bestNode = new Rectangle(0, 0, 0, 0);
    
    for(var i = 0; i < _freeRects.length; i++)
      {
        // Try to place the rectangle in upright (non-flipped) orientation.
        if (_freeRects[i].width >= width && _freeRects[i].height >= height) {
          int topSideY = _freeRects[i].top + height;

          if (topSideY < bestY || (topSideY == bestY && _freeRects[i].left < bestX)) {
            bestNode
                ..left = _freeRects[i].left
                ..top = _freeRects[i].top
                ..width = width
                ..height = height;
            
            bestY = topSideY;
            bestX = _freeRects[i].left;
          }
        }

        if (_allowRotation && _freeRects[i].width >= height && _freeRects[i].height >= width) {
          int topSideY = _freeRects[i].top + width;
          
          if (topSideY < bestY || (topSideY == bestY && _freeRects[i].left < bestX)) {
            bestNode
                ..left = _freeRects[i].left
                ..top = _freeRects[i].top
                ..width = height
                ..height = width;
            
            bestY = topSideY;
            bestX = _freeRects[i].left;
          }
        }
          
      }
    
      if(bestNode.height == 0) {
        bestY = bestX = MAX;
      }
      
      return new ScoreResult(bestNode, bestY, bestX);
      
  }
  
  int _commonIntervalLength(int i1start, int i1end, int i2start, int i2end) {
    if (i1end < i2start || i2end < i1start)
      return 0;
    return min(i1end, i2end) - max(i1start, i2start);
  }
  
  int _contactPointScoreNode(int x, int y, int width, int height) {
    int score = 0;

    if (x == 0 || x + width == _binWidth)
      score += height;
    if (y == 0 || y + height == _binHeight)
      score += width;

    for(var i = 0; i < _usedRects.length; ++i)
    {
      if (_usedRects[i].left == x + width || _usedRects[i].left + _usedRects[i].width == x)
        score += _commonIntervalLength(_usedRects[i].top, _usedRects[i].top + _usedRects[i].height, y, y + height);
      if (_usedRects[i].top == y + height || _usedRects[i].top + _usedRects[i].height == y)
        score += _commonIntervalLength(_usedRects[i].left, _usedRects[i].left + _usedRects[i].width, x, x + width);
    }
    return score;
  }
  
  ScoreResult _contactPoint(int width, int height) {

      int bestContactScore = 0;
      var bestNode = new Rectangle(0, 0, 0, 0);
      
      for(var i = 0; i < _freeRects.length; i++)
        {
          // Try to place the rectangle in upright (non-flipped) orientation.
          if (_freeRects[i].width >= width && _freeRects[i].height >= height) {
            
            int score = _contactPointScoreNode(_freeRects[i].left, _freeRects[i].top, width, height);
            
            if (score > bestContactScore) {
              bestNode
                  ..left = _freeRects[i].left
                  ..top = _freeRects[i].top
                  ..width = width
                  ..height = height;
              
              bestContactScore = score;
            }
          }

          if (_allowRotation && _freeRects[i].width >= height && _freeRects[i].height >= width) {
            
            int score = _contactPointScoreNode(_freeRects[i].left, _freeRects[i].top, height, width);
            
            if (score > bestContactScore) {
              bestNode
                  ..left = _freeRects[i].left
                  ..top = _freeRects[i].top
                  ..width = height
                  ..height = width;
              
              bestContactScore = score;
            }
          }
            
        }
      
        if(bestNode.height == 0) {
          bestContactScore = MAX * -1;
        }
        
        return new ScoreResult(bestNode, bestContactScore * -1, 0);
        
    }
  
  // End Pack Methods -----------------------------------------------------------------------------------
  
  bool _splitFreeNode(Rectangle freeNode, Rectangle usedNode)
  {
    // Test with SAT if the rectangles even intersect.
    if (usedNode.left >= freeNode.left + freeNode.width || usedNode.left + usedNode.width <= freeNode.left ||
      usedNode.top >= freeNode.top + freeNode.height || usedNode.top + usedNode.height <= freeNode.top)
      return false;

    if (usedNode.left < freeNode.left + freeNode.width && usedNode.left + usedNode.width > freeNode.left)
    {
      // New node at the top side of the used node.
      if (usedNode.top > freeNode.top && usedNode.top < freeNode.top + freeNode.height)
      {
        Rectangle newNode = freeNode.clone();
        newNode.height = usedNode.top - newNode.top;
        _freeRects.add(newNode);
      }

      // New node at the bottom side of the used node.
      if (usedNode.top + usedNode.height < freeNode.top + freeNode.height)
      {
        Rectangle newNode = freeNode.clone();
        newNode.top = usedNode.top + usedNode.height;
        newNode.height = freeNode.top + freeNode.height - (usedNode.top + usedNode.height);
        _freeRects.add(newNode);
      }
    }

    if (usedNode.top < freeNode.top + freeNode.height && usedNode.top + usedNode.height > freeNode.top)
    {
      // New node at the left side of the used node.
      if (usedNode.left > freeNode.left && usedNode.left < freeNode.left + freeNode.width)
      {
        Rectangle newNode = freeNode.clone();
        newNode.width = usedNode.left - newNode.left;
        _freeRects.add(newNode);
      }

      // New node at the right side of the used node.
      if (usedNode.left + usedNode.width < freeNode.left + freeNode.width)
      {
        Rectangle newNode = freeNode.clone();
        newNode.left = usedNode.left + usedNode.width;
        newNode.width = freeNode.left + freeNode.width - (usedNode.left + usedNode.width);
        _freeRects.add(newNode);
      }
    }

    _drawFreeRects();
    return true;
  }
  
  void _drawFreeRects() {
    _visualRects.bitmapData.clear();
    _freeRects.forEach((r) {
      var rect = new Graphics()
                      ..rect(r.left, r.top, r.width, r.height)
                      ..fillColor(_randColor());
      
      _visualRects.bitmapData.draw(new Shape()..graphics = rect);
          
    });
  }
  
  Rectangle _totalUsedRect() {
    var left = MAX, top = MAX, width = 0, height = 0;
    _usedRects.forEach((r) {
      left = min(left, r.left);
      top = min(top, r.top);
      width = max(width, r.right);
      height = max(height, r.bottom);
    });
    
    return new Rectangle(left, top, width, height);
    
  }
  
  void _pruneFreeList() {
    /* 
    ///  Would be nice to do something like this, to avoid a Theta(n^2) loop through each pair.
    ///  But unfortunately it doesn't quite cut it, since we also want to detect containment. 
    ///  Perhaps there's another way to do this faster than Theta(n^2).

    if (freeRectangles.size() > 0)
      clb::sort::QuickSort(&freeRectangles[0], freeRectangles.size(), NodeSortCmp);

    for(size_t i = 0; i < freeRectangles.size()-1; ++i)
      if (freeRectangles[i].left == freeRectangles[i+1].left &&
          freeRectangles[i].top == freeRectangles[i+1].top &&
          freeRectangles[i].width == freeRectangles[i+1].width &&
          freeRectangles[i].height == freeRectangles[i+1].height)
      {
        freeRectangles.erase(freeRectangles.begin() + i);
        --i;
      }
    */

    /// Go through each pair and remove any rectangle that is redundant.
    for(var i = 0; i < _freeRects.length; ++i)
      for(var j = i+1; j < _freeRects.length; ++j)
      {
        if (_freeRects[j].containsRectangle(_freeRects[i]))
        {
          _freeRects.removeAt(i);
          --i;
          break;
        }
        if (_freeRects[i].containsRectangle(_freeRects[j]))
        {
          _freeRects.removeAt(j);
          --j;
        }
      }
  }
  
  int _randColor() {
    return _rand.nextInt(16777215) + 0xFF000000;
  }
   
}
  