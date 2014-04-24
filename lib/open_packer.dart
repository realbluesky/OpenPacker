library open_packer;

import 'dart:async';
import 'dart:html';
import 'dart:math' hide Rectangle;
import 'package:stagexl/stagexl.dart';

part 'src/packee.dart';
part 'src/packer.dart';

Packer _packer;
CanvasElement _canvas;
var _methodNames = {'totalArea': 'Weighted Total Area',
                    'shortSide': 'Short Side Fit',
                    'bottomLeft': 'Bottom Left',
                    'longSide': 'Long Side Fit',
                    'area': 'Area Fit',
                    'contactPoint': 'Contact Point'};

void initPacker() {
  
  _canvas = querySelector('#canvas');
  var stage = new Stage(_canvas, webGL: false, color: 0x00FFFFFF);
  var renderLoop = new RenderLoop()..addStage(stage);

  //scale canvas size with window
  window.onResize.listen((e) => _updateCanvasSize());
  
  var actions = new Map.fromIterable(querySelectorAll('.controls a[id]'),
      key: (e) => e.id, value: (e) => e);
  
  _packer = new Packer(_packerOptions());
  
  stage.addChild(_packer);
  
  actions['new-set'].onClick.listen((e) { _packer.reset(_packerOptions()); _updateCanvasSize(); });
  
  actions['pack'].onClick.listen((e) => _packer.pack(_packerOptions()['method']));
  actions['pack-one'].onClick.listen((e) => _packer.packOne(_packerOptions()['method']));
  actions['run-trials'].onClick.listen((e) => _initTrials());    

  _updateCanvasSize();
  _packer.pack(_packerOptions()['method']);
  
}

void _initTrials() {
  var methodResults = _methodResults();
  methodResults.forEach((k,v) {
      v.dataset = {'name': _methodNames[k], 'trials': '0', 'best': '0', 'occ': '0'};
    });
  
  var trials = new List.filled(_packerOptions()['trials'], null);
  Future.forEach(trials, (t) => _runTrial());
    
}

Future _runTrial() {
  return new Future(() {
    var bestOcc = 0.0, bestMethod = '';
    _packer.reset(_packerOptions());
    var methodResults = _methodResults();
    
    Future.forEach(methodResults.keys, (m) {
      return new Future(() {
        var occ = _packer.pack(m);
        if(occ>-1) { //packed successfully
          var e = methodResults[m];
          e.dataset['trials'] = (int.parse(e.dataset['trials']) + 1).toString();
          e.dataset['occ'] = (double.parse(e.dataset['occ']) + occ).toString();
          e.setInnerHtml('<td>${e.dataset['name']}</td><td>${e.dataset['trials']}</td><td>${e.dataset['best']}</td><td>${(double.parse(e.dataset['occ'])/double.parse(e.dataset['trials'])*100).toStringAsFixed(2)}%</td>');
        }
        
        if(occ > bestOcc) {
          bestOcc = occ;
          bestMethod = m;
        }
      });
    }).whenComplete(() {
      if(bestMethod != '') {
        var be = methodResults[bestMethod];
        be.dataset['best'] = (int.parse(be.dataset['best']) + 1).toString();
      }
      
      methodResults.forEach((m,e) { //update best
        e.setInnerHtml('<td>${e.dataset['name']}</td><td>${e.dataset['trials']}</td><td>${e.dataset['best']}</td><td>${(double.parse(e.dataset['occ'])/double.parse(e.dataset['trials'])*100).toStringAsFixed(2)}%</td>');
      });  
    });
      
  });
  
}

Map<String, Element> _methodResults() {
  return new Map.fromIterable(querySelectorAll('.controls tr[id]'),
        key: (e) => e.id, value: (e) => e);
}

Map<String, dynamic> _packerOptions() {
  return new Map.fromIterable(querySelectorAll('.controls input, .controls select'),
      key: (e) => e.id, value: (e) {
        switch(e.type) {
          case 'checkbox': return e.checked; break;
          case 'number': return int.parse(e.value); break;
          default: return e.value; break;
        }
      });
}

void _updateCanvasSize() {
  var aspect = _packerOptions()['width']/_packerOptions()['height'];
  var controls = querySelector('.controls');
  var availWidth = window.innerWidth - controls.offsetWidth - 80;
  var availHeight = window.innerHeight - 50;
  var boundDim = min(availWidth, availHeight);
  if(aspect>=1) { //horizontal - width is bound
    _canvas.width = boundDim;
    _canvas.height = boundDim ~/ aspect;
  } else { //vertical - height is bound 
    _canvas.height = boundDim;
    _canvas.width = (boundDim * aspect).toInt();
  }
}

