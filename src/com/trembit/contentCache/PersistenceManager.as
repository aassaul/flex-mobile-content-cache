/**
 * Created with IntelliJ IDEA.
 * User: Andrey Assaul
 * Date: 12.08.2015
 * Time: 17:49
 */
package com.trembit.contentCache {
	import flash.net.SharedObject;

	internal class PersistenceManager {
		//--------------------------------------------------------------------------
		//
		//  Constants
		//
		//--------------------------------------------------------------------------

		private var _sharedobjectname:String;

		//--------------------------------------------------------------------------
		//
		//  Constructor
		//
		//--------------------------------------------------------------------------
		public function PersistenceManager(soName:String){
			super();
			_sharedobjectname = soName;
		}
		//--------------------------------------------------------------------------
		//
		//  Variables
		//
		//--------------------------------------------------------------------------

		/**
		 *  @private
		 *  Returns whether the persistence manager has been initialized.
		 */
		private var initialized:Boolean = false;

		/**
		 *  @private
		 *  The shared object used by the persistence manager.
		 */
		private var so:SharedObject;

		//--------------------------------------------------------------------------
		//
		//  IPersistenceManager Methods
		//
		//--------------------------------------------------------------------------

		/**
		 *  @inheritDoc
		 *
		 *  @langversion 3.0
		 *  @playerversion AIR 2.5
		 *  @productversion Flex 4.5
		 */
		public function load():Boolean
		{
			if (initialized)
				return true;

			try
			{
				so = SharedObject.getLocal(_sharedobjectname);
				initialized = true;
			}
			catch (e:Error)
			{
				// Fail silently
			}

			return initialized;
		}

		/**
		 *  @inheritDoc
		 *
		 *  @langversion 3.0
		 *  @playerversion AIR 2.5
		 *  @productversion Flex 4.5
		 */
		public function setProperty(key:String, value:Object):void
		{
			// If the persistence manager hasn't been initialized, do so now
			if (!initialized)
				load();

			// Make sure the shared object is valid since initialization fails silently
			if (so != null)
				so.data[key] = value;
		}

		/**
		 *  @inheritDoc
		 *
		 *  @langversion 3.0
		 *  @playerversion AIR 2.5
		 *  @productversion Flex 4.5
		 */
		public function getProperty(key:String):Object
		{
			// If the persistence manager hasn't been initialized, do so now
			if (!initialized)
				load();

			// Make sure the shared object is valid since initialization fails silently
			if (so != null)
				return so.data[key];

			return null;
		}

		/**
		 *  @inheritDoc
		 *
		 *  @langversion 3.0
		 *  @playerversion AIR 2.5
		 *  @productversion Flex 4.5
		 */
		public function save():Boolean
		{
			try
			{
				// We assume the flush suceeded and don't check the flush status
				so.flush();
			}
			catch (e:Error)
			{
				// Fail silently
				return false;
			}

			return true;
		}
	}
}
