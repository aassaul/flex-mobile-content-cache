/**
 * Created with IntelliJ IDEA.
 * User: Andrey Assaul
 * Date: 01.08.2015
 * Time: 13:36
 */
package com.trembit.contentCache {
import flash.display.LoaderInfo;

import org.flexunit.asserts.assertEquals;
import org.flexunit.asserts.assertFalse;
import org.flexunit.async.Async;

import spark.core.ContentRequest;

public class MobileContentCacheTest {

    private static const cache:MobileContentCache = new MobileContentCache();
    private static const testUrl:String = "https://risehighershinebrighter.files.wordpress.com/2014/11/magic-of-blue-universe-images.jpg";

    [BeforeClass]
    public static function initTest():void{
        //remove all old caches
        cache.oldContentThreshold = 0;
    }

    [Test(async, order=0)]
    public function testSaveRemote():void {
        Async.proceedOnEvent(this, cache, "contentSaved", 30*1000);
        cache.oldContentThreshold = 2*60*1000;
        cache.load(testUrl);
    }

    [Test(order=1)]
    public function testLiveCached():void {
        var content:ContentRequest = cache.load(testUrl);
        assertEquals(LoaderInfo(content.content).url, testUrl);
    }

    [Test(order=2)]
    public function testLocalCached():void {
        cache.removeAllCacheEntries();
        var content:ContentRequest = cache.load(testUrl);
        assertFalse(LoaderInfo(content.content).url == testUrl);
    }
}
}
