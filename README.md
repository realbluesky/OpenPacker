OpenPacker
==========

OpenPacker is [going to be] a completely free, open-source, online texture packer written in [Dart](https://www.dartlang.org/).

##Where it stands##

You can preview the packing test suite at http://openpacker.realbluesky.com

OpenPacker implements the MaxRects algorithm and original heuristics as clearly described by Jukka Jylänki at https://github.com/juj/RectangleBinPack
These are the same Packing Methods used by the well-known commercial product, [TexturePacker](http://www.codeandweb.com/texturepacker)

OpenPacker also introduces a new Packing Method - "Weighted Total Area" - which generally outperforms previous methods by ~10%

##Where we're heading##

* Drag-n-drop, locally-stored image assets with something like https://github.com/ebidel/idb.filesystem.js/
* Saving png, jpg, or webp (in Chrome) using https://github.com/blueimp/JavaScript-Canvas-to-Blob
* Support for several Texture Atlas formats - starting with Texture Packer JSON
* Trimming of transparent pixels in fixed-size animation frames
