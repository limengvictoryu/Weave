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

package weave.api.core
{
	/**
	 * Implement this interface to detect when a full session state is missing properties or a session state contains extra properties.
	 */
	public interface ILinkableObjectWithNewProperties extends ILinkableObject
	{
		/**
		 * This function will be called by SessionManager.setSessionState() when a full session state is missing properties or a session state contains extra properties.
		 * @param newState The new session state for this object.
		 * @param missingProperty The name of the property, whether it is missing from the newState or this ILinkableObject.
		 */
		function handleMissingSessionStateProperty(newState:Object, property:String):void;
	}
}
