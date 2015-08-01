/**
 * Created with IntelliJ IDEA.
 * User: Andrey Assaul
 * Date: 31.07.2015
 * Time: 16:35
 */
package com.trembit.contentCache {
import com.leeburrows.encoders.supportClasses.AsyncImageEncoderEvent;

import flash.data.EncryptedLocalStore;
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.LoaderInfo;
import flash.events.AsyncErrorEvent;
import flash.events.ErrorEvent;
import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.SecurityErrorEvent;
import flash.filesystem.File;
import flash.filesystem.FileMode;
import flash.filesystem.FileStream;
import flash.net.URLRequest;
import flash.utils.ByteArray;

import mx.collections.ArrayCollection;
import mx.utils.UIDUtil;

import spark.core.ContentCache;
import spark.core.ContentRequest;

[Event(name="contentSaved", type="flash.events.Event")]
public class MobileContentCache extends ContentCache {

    private static const URL_MAP:Object = loadContentMap();
    private static const URLS_IN_PROCESS:ArrayCollection = new ArrayCollection();

    private static function isRemoteURL(source:String):Boolean {
        return (source.indexOf("http") == 0);
    }

    private static function loadContentMap():Object{
        var mapBytes:ByteArray = EncryptedLocalStore.getItem("contentCache");
        var map:Object = (!mapBytes || !mapBytes.bytesAvailable)?{}:mapBytes.readObject();
        var keysForDelete:Array = [];
        for (var key:String in map) {
            if(map.hasOwnProperty(key) && !(map[key] is ContentInfo)){
                keysForDelete[keysForDelete.length] = key;
            }
        }
        //removing old version data
        if(keysForDelete.length){
            for each (var keyForDelete:String in keysForDelete) {
                var object:Object = map[keyForDelete];
                if(object.hasOwnProperty("fileName")){
                    var file:File = File.cacheDirectory.resolvePath(object.fileName);
                    if(file.exists){
                        file.deleteFileAsync();
                    }
                }
                delete map[keyForDelete];
            }
        }
        return map;
    }

    private static function deleteOldData(oldContentThreshold:Number):void{
        if(isNaN(oldContentThreshold)){
            return;
        }
        var keysForDelete:Array = [];
        var nowTime:Number = new Date().time;
        for (var key:String in URL_MAP) {
            if(URL_MAP.hasOwnProperty(key) && ((nowTime - ContentInfo(URL_MAP[key]).lastTime) > oldContentThreshold)){
                keysForDelete[keysForDelete.length] = key;
            }
        }
        if(keysForDelete.length){
            for each (var keyForDelete:String in keysForDelete) {
                var file:File = getContentFileByName(URL_MAP[keyForDelete].fileName);
                if(file){
                    file.deleteFile();
                }
                delete URL_MAP[keyForDelete];
            }
        }
        saveContentMap();
    }

    private static function saveContentMap():void{
        var mapBytes:ByteArray = new ByteArray();
        mapBytes.writeObject(URL_MAP);
        EncryptedLocalStore.setItem("contentCache", mapBytes);
    }

    private static function getContentFileByName(name:String):File{
        var contentDir:File = File.cacheDirectory.resolvePath("contentCache");
        if(!contentDir.exists){
            return null;
        }
        var file:File = contentDir.resolvePath(name);
        return (file.exists)?file:null;
    }

    private static function createContentFile():File{
        var contentDir:File = File.cacheDirectory.resolvePath("contentCache");
        contentDir.createDirectory();
        var file:File = contentDir.resolvePath(UIDUtil.createUID()+".png");
        return file;
    }

    private var _oldContentThreshold:Number;

    public function get oldContentThreshold():Number{
        return _oldContentThreshold;
    }

    public function set oldContentThreshold(value:Number):void{
        _oldContentThreshold = value;
        deleteOldData(oldContentThreshold);
    }

    /**
     * @param oldContentThreshold time after old unused entries should be deleted. put NaN if don't need deleting of the data;
     * @param maxActiveRequests
     * @param maxCacheEntries
     */
    public function MobileContentCache(maxActiveRequests:int = 50, maxCacheEntries:int = 1000, oldContentThreshold:Number = 2592000000) {
        super();
        this.maxActiveRequests = maxActiveRequests;
        this.maxCacheEntries = maxCacheEntries;
        this.oldContentThreshold = oldContentThreshold;
        enableCaching = true;
        enableQueueing = true;
    }

    override public function load(source:Object, contentLoaderGrouping:String = null):ContentRequest {
        var key:Object = source is URLRequest ? URLRequest(source).url : source;
        if ((key is String) && isRemoteURL(String(key))) {
            var contentInfo:ContentInfo = URL_MAP[key];
            if(contentInfo){
                var file:File = getContentFileByName(contentInfo.fileName);
                if(file){
                    if (!cachedData[key]){
                        contentInfo.lastTime = new Date().time;
                        saveContentMap();
                        return super.load(file.url, contentLoaderGrouping);
                    }else{
                        super.load(source, contentLoaderGrouping);
                    }
                }else{
                    delete URL_MAP[key];
                    saveContentMap();
                    return startListenForContent(super.load(source, contentLoaderGrouping));
                }
            } else if(URLS_IN_PROCESS.getItemIndex(key) == -1) {
                return startListenForContent(super.load(source, contentLoaderGrouping));
            } else {
                super.load(source, contentLoaderGrouping);
            }
        }
        return super.load(source, contentLoaderGrouping);
    }

    private function startListenForContent(contentRequest:ContentRequest):ContentRequest{
        var loaderInfo:LoaderInfo = contentRequest.content as LoaderInfo;
        if(loaderInfo){
            URLS_IN_PROCESS.addItem(loaderInfo.url);
            attachLoadingListeners(loaderInfo);
        }
        return contentRequest;
    }

    private function attachLoadingListeners(loadingContent:LoaderInfo):void {
        if (loadingContent) {
            loadingContent.addEventListener(Event.COMPLETE, onLoadComplete);
            loadingContent.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);
            loadingContent.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onLoadError);
            loadingContent.addEventListener(AsyncErrorEvent.ASYNC_ERROR, onLoadError);
        }
    }

    private function removeLoadingListeners(loadingContent:LoaderInfo):void {
        if (loadingContent) {
            loadingContent.removeEventListener(Event.COMPLETE, onLoadComplete);
            loadingContent.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
            loadingContent.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onLoadError);
            loadingContent.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, onLoadError);
        }
    }

    private function onLoadComplete(event:Event):void {
        var loaderInfo:LoaderInfo = LoaderInfo(event.currentTarget);
        removeLoadingListeners(loaderInfo);
        var bitmap:Bitmap = loaderInfo.content as Bitmap;
        if(bitmap){
            saveContent(loaderInfo.url, bitmap.bitmapData);
        } else {
            URLS_IN_PROCESS.removeItem(loaderInfo.url);
        }
    }

    private function onLoadError(event:ErrorEvent):void {
        var loaderInfo:LoaderInfo = LoaderInfo(event.currentTarget);
        removeLoadingListeners(loaderInfo);
        URLS_IN_PROCESS.removeItem(loaderInfo.url);
    }

    private function saveContent(remoteUrl:String, bitmapData:BitmapData):void{
        var encoder:ContentAsyncPNGEncoder = new ContentAsyncPNGEncoder();
        encoder.addEventListener(AsyncImageEncoderEvent.COMPLETE, onEncodeComplete);
        encoder.url = remoteUrl;
        encoder.start(bitmapData);
    }

    private function onEncodeComplete(event:AsyncImageEncoderEvent):void{
        var encoder:ContentAsyncPNGEncoder = ContentAsyncPNGEncoder(event.currentTarget);
        encoder.removeEventListener(AsyncImageEncoderEvent.COMPLETE, onEncodeComplete);
        var file:File = createContentFile();
        var url:String = encoder.url;
        file.preventBackup = true;
        var fs:FileStream = new FileStream();
        try{
            fs.open(file, FileMode.WRITE);
            fs.writeBytes(encoder.encodedBytes, 0, encoder.encodedBytes.length);
            var contentInfo:ContentInfo = new ContentInfo(file.name, url, new Date().time);
            URL_MAP[url] = contentInfo;
            saveContentMap();
            dispatchEvent(new Event("contentSaved"));
        }catch(e:*){
            trace("Save content error ", e);
        }finally{
            fs.close();
            encoder.dispose();
            URLS_IN_PROCESS.removeItem(url);
        }
    }
}
}

import com.leeburrows.encoders.AsyncPNGEncoder;

internal class ContentAsyncPNGEncoder extends AsyncPNGEncoder{
    public var url:String;
}
