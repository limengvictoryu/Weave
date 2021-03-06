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

package weave.data.KeySets
{
	import flash.utils.Dictionary;
	
	import weave.api.data.ColumnMetadata;
	import weave.api.data.IKeyFilter;
	import weave.api.data.IQualifiedKey;
	import weave.api.newLinkableChild;
	import weave.api.registerLinkableChild;
	import weave.core.LinkableBoolean;
	import weave.core.LinkableNumber;
	import weave.data.AttributeColumns.DynamicColumn;

	public class NumberDataFilter implements IKeyFilter
	{
		public const enabled:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(true), _cacheVars);
		public const includeMissingKeyTypes:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(true), _cacheVars);
		public const min:LinkableNumber = registerLinkableChild(this, new LinkableNumber(-Infinity), _resetKeyLookup);
		public const max:LinkableNumber = registerLinkableChild(this, new LinkableNumber(Infinity), _resetKeyLookup);
		public const column:DynamicColumn = newLinkableChild(this, DynamicColumn, _resetKeyLookup);

		private var _enabled:Boolean;
		private var _includeMissingKeyTypes:Boolean;
		private var _min:Number;
		private var _max:Number;
		private var _keyType:String;
		private var _keyLookup:Dictionary = new Dictionary(true);

		private function _cacheVars():void
		{
			_enabled = enabled.value;
			_includeMissingKeyTypes = includeMissingKeyTypes.value;
		}
		private function _resetKeyLookup():void
		{
			_min = min.value;
			_max = max.value;
			_keyType = column.getMetadata(ColumnMetadata.KEY_TYPE);
			_keyLookup = new Dictionary(true);
		}

		public function containsKey(key:IQualifiedKey):Boolean
		{
			if (!_enabled)
				return true;
			
			var cached:* = _keyLookup[key];
			if (cached === undefined)
			{
				var value:Number = column.getValueFromKey(key, Number);
				cached = value >= _min && value <= _max;
				if (!cached && _includeMissingKeyTypes && key.keyType != _keyType)
					cached = true;
				_keyLookup[key] = cached;
			}
			return cached;
		}
	}
}
