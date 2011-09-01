/*
 * ND2D - A Flash Molehill GPU accelerated 2D engine
 *
 * Author: Lars Gerckens
 * Copyright (c) nulldesign 2011
 * Repository URL: http://github.com/nulldesign/nd2d
 * Getting started: https://github.com/nulldesign/nd2d/wiki
 *
 *
 * Licence Agreement
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

package de.nulldesign.nd2d.materials {

    import de.nulldesign.nd2d.utils.TextureHelper;

    import flash.display.BitmapData;
    import flash.geom.Point;
    import flash.geom.Rectangle;
    import flash.utils.Dictionary;

    public class TextureAtlas extends ASpriteSheetBase {

        protected var frames:Vector.<Rectangle> = new Vector.<Rectangle>();
        protected var offsets:Vector.<Point> = new Vector.<Point>();
        protected var sourceSizes:Vector.<Point> = new Vector.<Point>();
        protected var frameNameToIndex:Dictionary = new Dictionary();
        protected var xmlData:XML;
        protected var uvRects:Vector.<Rectangle>;

        public function TextureAtlas(textureBitmap:BitmapData, cocos2DXML:XML, fps:uint) {
            this.fps = fps;
            this.bitmapData = textureBitmap;
            this.xmlData = cocos2DXML;

            var textureDimensions:Point = TextureHelper.getTextureDimensionsFromBitmap(bitmapData);

            _textureWidth = textureDimensions.x;
            _textureHeight = textureDimensions.y;

            parseCocos2DXML(xmlData);
        }

        public function getOffsetForFrame():Point {
            return offsets[frame];
        }

        override public function getUVRectForFrame():Rectangle {

            if(uvRects[frame]) {
                return uvRects[frame];
            }

            var rect:Rectangle = frames[frame].clone();

            rect.x += 0.5;
            rect.y += 0.5;

            rect.width -= 1.0;
            rect.height -= 1.0;

            rect.x /= textureWidth;
            rect.y /= textureHeight;
            rect.width /= textureWidth;
            rect.height /= textureHeight;

            uvRects[frame] = rect;

            return rect;
        }

        override public function set frame(value:uint):void {
            super.frame = value;
            _spriteWidth = frames[frame].width;
            _spriteHeight = frames[frame].height;
        }

        override public function addAnimation(name:String, keyFrames:Array, loop:Boolean,
                                              keyIsString:Boolean = false):void {

            // make indices out of names
            var keyFramesIndices:Array = [];

            if(keyIsString) {
                for(var i:int = 0; i < keyFrames.length; i++) {
                    keyFramesIndices.push(frameNameToIndex[keyFrames[i]]);
                }
            } else {
                keyFramesIndices = keyFrames;
            }

            super.addAnimation(name, keyFramesIndices, loop);
        }

        /**
         * Parser code "borrowed" from: http://blog.kaourantin.net/?p=110
         * @param cocos2DXML
         */
        protected function parseCocos2DXML(cocos2DXML:XML):void {

            var type:String;
            var data:String;
            var array:Array;

            var topKeys:XMLList = cocos2DXML.dict.key;
            var topDicts:XMLList = cocos2DXML.dict.dict;

            for(var k:uint = 0; k < topKeys.length(); k++) {
                switch(topKeys[k].toString()) {
                    case "frames":
                    {
                        var frameKeys:XMLList = topDicts[k].key;
                        var frameDicts:XMLList = topDicts[k].dict;

                        for(var l:uint = 0; l < frameKeys.length(); l++) {

                            var keyName:String = frameKeys[l];
                            var propKeys:XMLList = frameDicts[l].key;
                            var propAll:XMLList = frameDicts[l].*;

                            frameNameToIndex[keyName] = l;

                            for(var m:uint = 0; m < propKeys.length(); m++) {

                                type = propAll[propKeys[m].childIndex() + 1].name();
                                data = propAll[propKeys[m].childIndex() + 1];

                                switch(propKeys[m].toString()) {
                                    case "frame":
                                    {
                                        if(type == "string") {
                                            array = data.split(/[^0-9-]+/);
                                            frames.push(new Rectangle(array[1], array[2], array[3], array[4]));
                                        } else {
                                            throw new Error("Error parsing descriptor format");
                                        }
                                    }
                                        break;
                                    case "offset":
                                    {
                                        if(type == "string") {
                                            array = data.split(/[^0-9-]+/);
                                            // our coordinate system is different than the cocos one
                                            offsets.push(new Point(array[1], -array[2]));
                                        } else {
                                            throw new Error("Error parsing descriptor format");
                                        }
                                    }
                                        break;
                                    case "sourceSize":
                                    {
                                        if(type == "string") {
                                            array = data.split(/[^0-9-]+/);
                                            sourceSizes.push(new Point(array[1], array[2]));
                                        } else {
                                            throw new Error("Error parsing descriptor format");
                                        }
                                    }
                                        break;
                                    case "rotated":
                                    {
                                        if(type != "false") {
                                            throw new Error("Rotated elements not supported (yet)");
                                        }
                                    }
                                        break;
                                }
                            }
                        }
                    }
                        break;
                }
            }

            if(frames.length == 0) {
                throw new Error("Error parsing descriptor format");
            }

            uvRects = new Vector.<Rectangle>(frames.length, true);

            /*
             Frame:
             Top-Left originating rectangle of the sprite's pixel texture coordinates. Cocos2'd will convert these to UV coordinates (0-1) when loading based on the texture size.

             Offset:
             Zwoptex trim's transparency off sprites. Because of this sprite's need to be offset to ensure their texture is drawn in correct alignment to their original size.

             Source Color Rect:
             This is the Top-Left originating rectangle that is the valid pixel data of the sprite. Say you have a 512x512 sprite that only has 10x10 pixels of data inside of it located at 500x500. The source color rect could be {500,500,10,10}.

             Format:
             Version number related to what version of Zwoptex was used so cocos2d knows how to parse the plist properly.
             Flash Version: 0
             Desktop Version 0-0.4b: 1
             Desktop Version 1.x: 2
             */
        }

        override public function clone():ASpriteSheetBase {

            var t:TextureAtlas = new TextureAtlas(bitmapData, xmlData, fps);

            for(var name:String in animationMap) {
                var anim:SpriteSheetAnimation = animationMap[name];
                t.addAnimation(name, anim.frames.concat(), anim.loop, false);
            }

            t.frame = frame;

            return t;
        }
    }
}
