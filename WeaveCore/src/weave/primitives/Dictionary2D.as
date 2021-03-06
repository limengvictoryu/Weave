/* ***** BEGIN LICENSE BLOCK *****
 *
 * This file is part of Weave.
 *
 * The Initial Developer of Weave is the Institute for Visualization
 * and Perception Research at the University of Massachusetts Lowell.
 * Portions created by the Initial Developer are Copyright (C) 2008-2015
 * the Initial Developer. All Rights Reserved.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 * 
 * ***** END LICENSE BLOCK ***** */

package weave.primitives
{
	import flash.utils.Dictionary;

	/**
	 * This is a wrapper for a 2-dimensional Dictionary.
	 * 
	 * @author adufilie
	 */
	public class Dictionary2D
	{
		public function Dictionary2D(weakPrimaryKeys:Boolean = false, weakSecondaryKeys:Boolean = false, defaultType:Class = null)
		{
			dictionary = new Dictionary(weakPrimaryKeys);
			weak2 = weakSecondaryKeys;
			this.defaultType = defaultType;
		}
		
		/**
		 * The primary Dictionary object.
		 */		
		public var dictionary:Dictionary;
		
		private var weak2:Boolean; // used as a constructor parameter for nested Dictionaries
		private var defaultType:Class; // used for creating objects automatically via get()
		
		/**
		 * 
		 * @param key1 The first dictionary key.
		 * @param key2 The second dictionary key.
		 * @return The value in the dictionary.
		 */
		public function get(key1:Object, key2:Object):*
		{
			var d2:* = dictionary[key1];
			if (d2)
				return d2[key2];
			if (defaultType)
			{
				var value:* = new defaultType();
				set(key1, key2, value);
				return value;
			}
			return undefined;
		}
		
		/**
		 * This will add or replace an entry in the dictionary.
		 * @param key1 The first dictionary key.
		 * @param key2 The second dictionary key.
		 * @param value The value to put into the dictionary.
		 */
		public function set(key1:Object, key2:Object, value:Object):void
		{
			var d2:Dictionary = dictionary[key1] as Dictionary;
			if (d2 == null)
				dictionary[key1] = d2 = new Dictionary(weak2);
			d2[key2] = value;
		}
		
		/**
		 * This removes all values associated with the given primary key.
		 * @param key1 The first dictionary key.
		 */		
		public function removeAllPrimary(key1:Object):void
		{
			delete dictionary[key1];
		}
		
		/**
		 * This removes all values associated with the given secondary key.
		 * @param key2 The second dictionary key.
		 */		
		public function removeAllSecondary(key2:Object):void
		{
			for (var key1:* in dictionary)
				delete dictionary[key1][key2];
		}
		
		/**
		 * This removes a value associated with the given primary and secondary keys.
		 * @param key1 The first dictionary key.
		 * @param key2 The second dictionary key.
		 * @return The value that was in the dictionary.
		 */
		public function remove(key1:Object, key2:Object):*
		{
			var value:* = undefined;
			var d2:* = dictionary[key1];
			if (d2)
			{
				value = d2[key2];
				delete d2[key2];
			}
			
			// if entries remain in d2, keep it
			for (var v2:* in d2)
				return value;
			
			// otherwise, remove it
			delete dictionary[key1];
			
			return value;
		}
	}
}
