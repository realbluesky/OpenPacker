part of open_packer;

class Packer extends DisplayObjectContainer {
  static const MAX = 1000000;
  
  List<Packee> _packees;
  List<Rectangle> _freeRects, _usedRects;
  bool _allowRotation;
  
  Packer(int number, int width, int height, {bool allowRotation: true}) {
    
    _allowRotation = allowRotation;
    this.width = width;
    this.height = height;
    _packees = [];
    _usedRects = [];
    _freeRects = [new Rectangle(0, 0, width, height)];
    
    //TEMPORARY - randomly generate rectangles to test
    var rand = new Random();
    var totalWidth = 0, totalHeight = 0, rowHeight = 0;
    for (var i=0; i<number; i++) {
      var w = 50+rand.nextInt(400);
      var h = 50+rand.nextInt(400);
      var c = rand.nextInt(16777215) + 0xAA000000;
      
      if(totalWidth + w > width) {
        totalWidth = 0;
        totalHeight += rowHeight;
        rowHeight = 0;
      }
      
      var packee = new Packee(totalWidth, totalHeight, w, h, color: c);

      totalWidth += w;
      rowHeight = max(h, rowHeight);
      _packees.add(packee);
      addChild(packee);
      
    }
    //end temporary
 
    
  }
  
  /// Computes the ratio of used surface area.
  num occupancy() {
    num usedSurfaceArea = 0;
    for(var i = 0; i < _usedRects.length; i++)
      usedSurfaceArea += _usedRects[i].width * _usedRects[i].height;
  
    return usedSurfaceArea / (width * height);
      
  }

  
  void pack() {
    
    List<Packee> toPack = new List.from(_packees);
    var packed = [];

    while(toPack.length > 0) {
      int bestShortSide = MAX, bestLongSide = MAX, bestRectIndex = -1;
      Rectangle bestNode;
      
      for(var i=0; i<toPack.length; i++) {
        var packee = toPack[i];
        
        var result = _scoreRect(packee.width.toInt(), packee.height.toInt());
        var newNode = result.keys.first;
        var sides = result.values.first;
        var shortSide = sides.first;
        var longSide = sides.last;
                
        if (shortSide < bestShortSide || (shortSide == bestShortSide && longSide < bestLongSide))
        {
          bestShortSide = shortSide;
          bestLongSide = longSide;
          bestNode = newNode;
          bestRectIndex = i;
        }
        
      }
      
      if (bestRectIndex == -1)
        return;

      print(bestNode);
      
      _placeRect(bestNode);
      var packee = toPack.removeAt(bestRectIndex);
      
      if(bestNode.width != packee.width) { //she be flipped
        print('flipped');
        packee
            ..x = bestNode.x + packee.height
            ..y = bestNode.y
            ..rotated = true
            ..rotation = PI/2;
      } else {
        packee
            ..x = bestNode.x
            ..y = bestNode.y;  
      }
      
      
      packed.add(packee);
      
    }
    
    print('packed ${packed.length} of ${_packees.length} with ${occupancy().toStringAsFixed(2)} occupancy');
        
  }
  
  void _placeRect(Rectangle node)
  {
    print(_freeRects.length);
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
    
  Map<Rectangle, List<int>> _scoreRect(int width, int height) {
    int bestShortSide = MAX, bestLongSide = MAX;
    var bestNode = new Rectangle.zero();
    
    for(var i = 0; i < _freeRects.length; i++)
      {
        // Try to place the rectangle in upright (non-flipped) orientation.
        if (_freeRects[i].width >= width && _freeRects[i].height >= height)
        {
          int leftoverHoriz = (_freeRects[i].width - width).abs().toInt();
          int leftoverVert = (_freeRects[i].height - height).abs().toInt();
          int shortSide = min(leftoverHoriz, leftoverVert);
          int longSide = max(leftoverHoriz, leftoverVert);

          if (shortSide < bestShortSide || (shortSide == bestShortSide && longSide < bestLongSide))
          {
            bestNode.x = _freeRects[i].x;
            bestNode.y = _freeRects[i].y;
            bestNode.width = width;
            bestNode.height = height;
            bestShortSide = shortSide;
            bestLongSide = longSide;
          }
        }

        if (_allowRotation && _freeRects[i].width >= height && _freeRects[i].height >= width) {
          int flippedLeftoverHoriz = (_freeRects[i].width - height).abs().toInt();
          int flippedLeftoverVert = (_freeRects[i].height - width).abs().toInt();
          int flippedShortSide = min(flippedLeftoverHoriz, flippedLeftoverVert);
          int flippedLongSide = max(flippedLeftoverHoriz, flippedLeftoverVert);

          if (flippedShortSide < bestShortSide || (flippedShortSide == bestShortSide && flippedLongSide < bestLongSide))
          {
            bestNode.x = _freeRects[i].x;
            bestNode.y = _freeRects[i].y;
            bestNode.width = height;
            bestNode.height = width;
            bestShortSide = flippedShortSide;
            bestLongSide = flippedLongSide;
          }
        }
        
        
      }
    
      return new Map()..putIfAbsent(bestNode, ()=> [bestShortSide, bestLongSide]);
      
  }
  
  bool _splitFreeNode(Rectangle freeNode, Rectangle usedNode)
  {
    // Test with SAT if the rectangles even intersect.
    if (usedNode.x >= freeNode.x + freeNode.width || usedNode.x + usedNode.width <= freeNode.x ||
      usedNode.y >= freeNode.y + freeNode.height || usedNode.y + usedNode.height <= freeNode.y)
      return false;

    if (usedNode.x < freeNode.x + freeNode.width && usedNode.x + usedNode.width > freeNode.x)
    {
      // New node at the top side of the used node.
      if (usedNode.y > freeNode.y && usedNode.y < freeNode.y + freeNode.height)
      {
        print('new top free');
        Rectangle newNode = freeNode.clone();
        newNode.height = usedNode.y - newNode.y;
        _freeRects.add(newNode);
      }

      // New node at the bottom side of the used node.
      if (usedNode.y + usedNode.height < freeNode.y + freeNode.height)
      {
        print('new bottom free');
        Rectangle newNode = freeNode.clone();
        newNode.y = usedNode.y + usedNode.height;
        newNode.height = freeNode.y + freeNode.height - (usedNode.y + usedNode.height);
        _freeRects.add(newNode);
      }
    }

    if (usedNode.y < freeNode.y + freeNode.height && usedNode.y + usedNode.height > freeNode.y)
    {
      // New node at the left side of the used node.
      if (usedNode.x > freeNode.x && usedNode.x < freeNode.x + freeNode.width)
      {
        print('new left free');
        Rectangle newNode = freeNode.clone();
        newNode.width = usedNode.x - newNode.x;
        _freeRects.add(newNode);
      }

      // New node at the right side of the used node.
      if (usedNode.x + usedNode.width < freeNode.x + freeNode.width)
      {
        print('new right free');
        Rectangle newNode = freeNode.clone();
        newNode.x = usedNode.x + usedNode.width;
        newNode.width = freeNode.x + freeNode.width - (usedNode.x + usedNode.width);
        _freeRects.add(newNode);
      }
    }

    return true;
  }
  
  void _pruneFreeList()
  {
    /* 
    ///  Would be nice to do something like this, to avoid a Theta(n^2) loop through each pair.
    ///  But unfortunately it doesn't quite cut it, since we also want to detect containment. 
    ///  Perhaps there's another way to do this faster than Theta(n^2).

    if (freeRectangles.size() > 0)
      clb::sort::QuickSort(&freeRectangles[0], freeRectangles.size(), NodeSortCmp);

    for(size_t i = 0; i < freeRectangles.size()-1; ++i)
      if (freeRectangles[i].x == freeRectangles[i+1].x &&
          freeRectangles[i].y == freeRectangles[i+1].y &&
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
        if (_freeRects[j].containsRect(_freeRects[i]))
        {
          _freeRects.removeAt(i);
          --i;
          break;
        }
        if (_freeRects[i].containsRect(_freeRects[j]))
        {
          _freeRects.removeAt(j);
          --j;
        }
      }
  }
  
}
  
  /*

/** @file MaxRectsBinPack.cpp
  @author Jukka Jylänki

  @brief Implements different bin packer algorithms that use the MAXRECTS data structure.

  This work is released to Public Domain, do whatever you want with it.
*/
#include <utility>
#include <iostream>
#include <limits>

#include <cassert>
#include <cstring>
#include <cmath>

#include "MaxRectsBinPack.h"

void MaxRectsBinPack::Insert(std::vector<RectSize> &rects, std::vector<Rect> &dst, FreeRectChoiceHeuristic method)
{
  dst.clear();

  while(rects.size() > 0)
  {
    int bestScore1 = std::numeric_limits<int>::max();
    int bestScore2 = std::numeric_limits<int>::max();
    int bestRectIndex = -1;
    Rect bestNode;

    for(size_t i = 0; i < rects.size(); ++i)
    {
      int score1;
      int score2;
      Rect newNode = ScoreRect(rects[i].width, rects[i].height, method, score1, score2);

      if (score1 < bestScore1 || (score1 == bestScore1 && score2 < bestScore2))
      {
        bestScore1 = score1;
        bestScore2 = score2;
        bestNode = newNode;
        bestRectIndex = i;
      }
    }

    if (bestRectIndex == -1)
      return;

    PlaceRect(bestNode);
    rects.erase(rects.begin() + bestRectIndex);
  }
}

void MaxRectsBinPack::PlaceRect(const Rect &node)
{
  size_t numRectanglesToProcess = freeRectangles.size();
  for(size_t i = 0; i < numRectanglesToProcess; ++i)
  {
    if (SplitFreeNode(freeRectangles[i], node))
    {
      freeRectangles.erase(freeRectangles.begin() + i);
      --i;
      --numRectanglesToProcess;
    }
  }

  PruneFreeList();

  usedRectangles.push_back(node);
  //    dst.push_back(bestNode); ///\todo Refactor so that this compiles.
}

Rect MaxRectsBinPack::ScoreRect(int width, int height, FreeRectChoiceHeuristic method, int &score1, int &score2) const
{
  Rect newNode;
  score1 = std::numeric_limits<int>::max();
  score2 = std::numeric_limits<int>::max();
  switch(method)
  {
  case RectBestShortSideFit: newNode = FindPositionForNewNodeBestShortSideFit(width, height, score1, score2); break;
  case RectBottomLeftRule: newNode = FindPositionForNewNodeBottomLeft(width, height, score1, score2); break;
  case RectContactPointRule: newNode = FindPositionForNewNodeContactPoint(width, height, score1); 
    score1 = -score1; // Reverse since we are minimizing, but for contact point score bigger is better.
    break;
  case RectBestLongSideFit: newNode = FindPositionForNewNodeBestLongSideFit(width, height, score2, score1); break;
  case RectBestAreaFit: newNode = FindPositionForNewNodeBestAreaFit(width, height, score1, score2); break;
  }

  // Cannot fit the current rectangle.
  if (newNode.height == 0)
  {
    score1 = std::numeric_limits<int>::max();
    score2 = std::numeric_limits<int>::max();
  }

  return newNode;
}

/// Computes the ratio of used surface area.
float MaxRectsBinPack::Occupancy() const
{
  unsigned long usedSurfaceArea = 0;
  for(size_t i = 0; i < usedRectangles.size(); ++i)
    usedSurfaceArea += usedRectangles[i].width * usedRectangles[i].height;

  return (float)usedSurfaceArea / (binWidth * binHeight);
}


Rect MaxRectsBinPack::FindPositionForNewNodeBestShortSideFit(int width, int height, 
  int &bestShortSideFit, int &bestLongSideFit) const
{
  Rect bestNode;
  memset(&bestNode, 0, sizeof(Rect));

  bestShortSideFit = std::numeric_limits<int>::max();

  for(size_t i = 0; i < freeRectangles.size(); ++i)
  {
    // Try to place the rectangle in upright (non-flipped) orientation.
    if (freeRectangles[i].width >= width && freeRectangles[i].height >= height)
    {
      int leftoverHoriz = abs(freeRectangles[i].width - width);
      int leftoverVert = abs(freeRectangles[i].height - height);
      int shortSideFit = min(leftoverHoriz, leftoverVert);
      int longSideFit = max(leftoverHoriz, leftoverVert);

      if (shortSideFit < bestShortSideFit || (shortSideFit == bestShortSideFit && longSideFit < bestLongSideFit))
      {
        bestNode.x = freeRectangles[i].x;
        bestNode.y = freeRectangles[i].y;
        bestNode.width = width;
        bestNode.height = height;
        bestShortSideFit = shortSideFit;
        bestLongSideFit = longSideFit;
      }
    }

    if (freeRectangles[i].width >= height && freeRectangles[i].height >= width)
    {
      int flippedLeftoverHoriz = abs(freeRectangles[i].width - height);
      int flippedLeftoverVert = abs(freeRectangles[i].height - width);
      int flippedShortSideFit = min(flippedLeftoverHoriz, flippedLeftoverVert);
      int flippedLongSideFit = max(flippedLeftoverHoriz, flippedLeftoverVert);

      if (flippedShortSideFit < bestShortSideFit || (flippedShortSideFit == bestShortSideFit && flippedLongSideFit < bestLongSideFit))
      {
        bestNode.x = freeRectangles[i].x;
        bestNode.y = freeRectangles[i].y;
        bestNode.width = height;
        bestNode.height = width;
        bestShortSideFit = flippedShortSideFit;
        bestLongSideFit = flippedLongSideFit;
      }
    }
  }
  return bestNode;
}


/// Returns 0 if the two intervals i1 and i2 are disjoint, or the length of their overlap otherwise.
int CommonIntervalLength(int i1start, int i1end, int i2start, int i2end)
{
  if (i1end < i2start || i2end < i1start)
    return 0;
  return min(i1end, i2end) - max(i1start, i2start);
}


bool MaxRectsBinPack::SplitFreeNode(Rect freeNode, const Rect &usedNode)
{
  // Test with SAT if the rectangles even intersect.
  if (usedNode.x >= freeNode.x + freeNode.width || usedNode.x + usedNode.width <= freeNode.x ||
    usedNode.y >= freeNode.y + freeNode.height || usedNode.y + usedNode.height <= freeNode.y)
    return false;

  if (usedNode.x < freeNode.x + freeNode.width && usedNode.x + usedNode.width > freeNode.x)
  {
    // New node at the top side of the used node.
    if (usedNode.y > freeNode.y && usedNode.y < freeNode.y + freeNode.height)
    {
      Rect newNode = freeNode;
      newNode.height = usedNode.y - newNode.y;
      freeRectangles.push_back(newNode);
    }

    // New node at the bottom side of the used node.
    if (usedNode.y + usedNode.height < freeNode.y + freeNode.height)
    {
      Rect newNode = freeNode;
      newNode.y = usedNode.y + usedNode.height;
      newNode.height = freeNode.y + freeNode.height - (usedNode.y + usedNode.height);
      freeRectangles.push_back(newNode);
    }
  }

  if (usedNode.y < freeNode.y + freeNode.height && usedNode.y + usedNode.height > freeNode.y)
  {
    // New node at the left side of the used node.
    if (usedNode.x > freeNode.x && usedNode.x < freeNode.x + freeNode.width)
    {
      Rect newNode = freeNode;
      newNode.width = usedNode.x - newNode.x;
      freeRectangles.push_back(newNode);
    }

    // New node at the right side of the used node.
    if (usedNode.x + usedNode.width < freeNode.x + freeNode.width)
    {
      Rect newNode = freeNode;
      newNode.x = usedNode.x + usedNode.width;
      newNode.width = freeNode.x + freeNode.width - (usedNode.x + usedNode.width);
      freeRectangles.push_back(newNode);
    }
  }

  return true;
}

void MaxRectsBinPack::PruneFreeList()
{
  /* 
  ///  Would be nice to do something like this, to avoid a Theta(n^2) loop through each pair.
  ///  But unfortunately it doesn't quite cut it, since we also want to detect containment. 
  ///  Perhaps there's another way to do this faster than Theta(n^2).

  if (freeRectangles.size() > 0)
    clb::sort::QuickSort(&freeRectangles[0], freeRectangles.size(), NodeSortCmp);

  for(size_t i = 0; i < freeRectangles.size()-1; ++i)
    if (freeRectangles[i].x == freeRectangles[i+1].x &&
        freeRectangles[i].y == freeRectangles[i+1].y &&
        freeRectangles[i].width == freeRectangles[i+1].width &&
        freeRectangles[i].height == freeRectangles[i+1].height)
    {
      freeRectangles.erase(freeRectangles.begin() + i);
      --i;
    }
  */

  /// Go through each pair and remove any rectangle that is redundant.
  for(size_t i = 0; i < freeRectangles.size(); ++i)
    for(size_t j = i+1; j < freeRectangles.size(); ++j)
    {
      if (IsContainedIn(freeRectangles[i], freeRectangles[j]))
      {
        freeRectangles.erase(freeRectangles.begin()+i);
        --i;
        break;
      }
      if (IsContainedIn(freeRectangles[j], freeRectangles[i]))
      {
        freeRectangles.erase(freeRectangles.begin()+j);
        --j;
      }
    }
}

}
 
   */
  