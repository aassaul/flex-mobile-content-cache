/**
 * Created with IntelliJ IDEA.
 * User: Andrey Assaul
 * Date: 22.06.2015
 * Time: 13:03
 */
package com.trembit.contentCache {
[RemoteClass]
public class ContentInfo {
	public var fileName:String;
	public var lastTime:Number;
	public var key:String;

	public function ContentInfo(fileName:String = null, key:String = null, lastTime:Number = 0){
		this.fileName = fileName;
		this.lastTime = lastTime;
		this.key = key;
	}
}
}
