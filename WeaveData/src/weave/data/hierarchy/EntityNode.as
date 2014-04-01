/*
	Weave (Web-based Analysis and Visualization Environment)
	Copyright (C) 2008-2011 University of Massachusetts Lowell
	
	This file is a part of Weave.
	
	Weave is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License, Version 3,
	as published by the Free Software Foundation.
	
	Weave is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
	
	You should have received a copy of the GNU General Public License
	along with Weave.  If not, see <http://www.gnu.org/licenses/>.
*/
package weave.data.hierarchy
{
    import flash.utils.Dictionary;
    
    import mx.utils.ObjectUtil;
    
    import weave.api.WeaveAPI;
    import weave.api.core.ILinkableObject;
    import weave.api.data.ColumnMetadata;
    import weave.api.data.EntityType;
    import weave.api.data.IColumnReference;
    import weave.api.data.IDataSource;
    import weave.api.data.IWeaveTreeNode;
    import weave.api.getLinkableOwner;
    import weave.api.reportError;
    import weave.api.services.beans.Entity;
    import weave.api.services.beans.EntityHierarchyInfo;
    import weave.data.DataSources.WeaveDataSource;
    import weave.services.EntityCache;

	[RemoteClass]
    public class EntityNode implements IWeaveTreeNode, IColumnReference
    {
		/**
		 * Dual lookup: (EntityCache -> int) and (int -> EntityCache)
		 */
		private static const $cacheLookup:Dictionary = new Dictionary(true);
		private static var $cacheSerial:int = 0;
		
		public static var debug:Boolean = false;
		
		/**
		 * @param entityCache The entityCache which the Entity belongs to.
		 * @param rootFilterEntityType To be used by root node only.
		 * @param nodeFilterFunction Used for filtering children.
		 */
		public function EntityNode(entityCache:EntityCache = null, rootFilterEntityType:String = null, nodeFilterFunction:Function = null, overrideLabel:String = null)
		{
			setEntityCache(entityCache);
			this._rootFilterEntityType = rootFilterEntityType;
			this._nodeFilterFunction = nodeFilterFunction;
			this._overrideLabel = overrideLabel;
		}
		
		private var _rootFilterEntityType:String = null;
		private var _nodeFilterFunction:Function = null;
		/**
		 * @private
		 */
		public var _overrideLabel:String = null;
		
		/**
		 * This primitive value is used in place of a pointer to an EntityCache object
		 * so that this object may be serialized & copied by the Flex framework without losing this information.
		 * @private
		 */
		public var _cacheId:int = 0;
		
		/**
		 * The entity ID.
		 */
		public var id:int = -1;
		
		/**
		 * Sets the EntityCache associated with this node.
		 */
		public function setEntityCache(entityCache:EntityCache):void
		{
			if (entityCache && !$cacheLookup[entityCache])
				$cacheLookup[ $cacheLookup[entityCache] = ++$cacheSerial ] = entityCache;
			
			var cid:int = $cacheLookup[entityCache];
			if (cid != _cacheId)
			{
				_cacheId = cid;
				for each (var child:EntityNode in _childNodeCache)
					child.setEntityCache(entityCache);
			}
		}
		
		/**
		 * Gets the EntityCache associated with this node.
		 */
		public function getEntityCache():EntityCache
		{
			return $cacheLookup[_cacheId];
		}
		
		/**
		 * Gets the Entity associated with this node.
		 */
		public function getEntity():Entity
		{
			return getEntityCache().getEntity(id);
		}
		
		// the node can re-use the same children array
		private const _childNodes:Array = [];
		
		// We cache child nodes to avoid creating unnecessary objects.
		// Each node must have its own child cache (not static) because we can't have the same node in two places in a Tree.
		private const _childNodeCache:Object = {}; // id -> EntityNode
		
		/**
		 * @inheritDoc
		 */
		public function equals(other:IWeaveTreeNode):Boolean
		{
			if (other == this)
				return true;
			var node:EntityNode = other as EntityNode;
			return !!node
				&& this._cacheId == node._cacheId
				&& this.id == node.id;
		}
		
		/**
		 * @inheritDoc
		 */
		public function getDataSource():IDataSource
		{
			var cache:EntityCache = getEntityCache();
			var owner:ILinkableObject = cache;
			while (owner)
			{
				owner = getLinkableOwner(owner);
				if (owner is IDataSource)
					return owner as IDataSource;
			}
			return null;
		}
		
		/**
		 * @inheritDoc
		 */
		public function getColumnMetadata():Object
		{
			if (getEntity().getEntityType() == EntityType.COLUMN)
				return id;
			return null; // not a column
		}
		
		/**
		 * @inheritDoc
		 */
		public function getLabel():String
		{
			if (_overrideLabel)
				return _overrideLabel;
			
			var title:String;
			var entity:Entity;
			var entityType:String;
			var cache:EntityCache = getEntityCache();
			var branchInfo:EntityHierarchyInfo = cache.getBranchInfo(id);
			if (branchInfo)
			{
				// avoid calling getEntity()
				entityType = branchInfo.entityType || 'entity';
				title = branchInfo.title || lang("Untitled {0}#{1}", entityType, branchInfo.id);
				
				if (entityType == EntityType.TABLE)
					title = lang("{0} ({1})", title, branchInfo.numChildren);
			}
			else
			{
				entity = getEntity();
				
				title = entity.publicMetadata[ColumnMetadata.TITLE];
				if (!title)
				{
					var name:String = entity.publicMetadata['name'];
					if (name)
						title = '[name: ' + name + ']';
				}
				
				if (!title || debug)
					entityType = entity.getEntityType() || 'entity';
				
				if (!title && !entity.initialized)
				{
					if (_rootFilterEntityType)
						title = WeaveAPI.globalHashMap.getName(getDataSource()) || title;
					else
						title = '...';
				}
			}
			
			if (cache.entityIsCached(id))
			{
				if (!entity)
					entity = cache.getEntity(id);
				if (entity.getEntityType() != EntityType.COLUMN && entity.parentIds.length > 1)
					title += lang(" ; Warning: Multiple parents ({0})", entity.parentIds);
			}
			
			var idStr:String;
			if (!title || debug)
				idStr = lang("{0}#{1}", entityType, id);
			
			if (!title)
				title = idStr;
			
			if (debug)
			{
				var children:Array = getChildren();
				if (entityType != EntityType.COLUMN && children)
					idStr += '; ' + children.length + ' children';
				title = lang('({0}) {1} {2}', idStr, debugId(this), title);
			}
			
			return title;
		}
		
		/**
		 * @inheritDoc
		 */
		public function isBranch():Boolean
		{
			// root is a branch
			if (_rootFilterEntityType)
				return true;
			
			var cache:EntityCache = getEntityCache();
			
			var info:EntityHierarchyInfo = cache.getBranchInfo(id);
			if (info && info.entityType != EntityType.COLUMN)
				return true;
			
			var entity:Entity = cache.getEntity(id);
			
			// columns are leaf nodes
			if (entity.getEntityType() == EntityType.COLUMN)
				return false;
			
			// treat entities that haven't downloaded yet as leaf nodes
			return entity.childIds != null;
		}

		/**
		 * @inheritDoc
		 */
		public function hasChildBranches():Boolean
		{
			if (_rootFilterEntityType)
				return true;
			
			return getEntityCache().getEntity(id).hasChildBranches;
		}
		
		/**
		 * @inheritDoc
		 */
		public function getChildren():Array
		{
			var cache:EntityCache = getEntityCache();
			
			var childIds:Array;
			if (_rootFilterEntityType)
			{
				childIds = cache.getIdsByType(_rootFilterEntityType);
			}
			else
			{
				var entity:Entity = cache.getEntity(id);
				childIds = entity.childIds;
				if (entity.getEntityType() == EntityType.COLUMN)
					return null; // leaf node
			}
			
			if (!childIds)
			{
				_childNodes.length = 0;
				return isBranch() ? _childNodes : null;
			}
			
			var outputIndex:int = 0;
			for (var i:int = 0; i < childIds.length; i++)
			{
				var childId:int = childIds[i];
				var child:EntityNode = _childNodeCache[childId] as EntityNode;
				if (!child)
				{
					child = new EntityNode(cache, null, _nodeFilterFunction);
					child.id = childId;
					_childNodeCache[childId] = child;
				}
				
				if (child.id != childId)
				{
					reportError("BUG: EntityNode id has changed since it was first cached");
					child.id = childId;
				}
				
				if (_nodeFilterFunction != null && !_nodeFilterFunction(child))
					continue;
				
				_childNodes[outputIndex] = child;
				outputIndex++;
			}
			_childNodes.length = outputIndex;
			
			return _childNodes;
		}
		
		/**
		 * @inheritDoc
		 */
		public function addChildAt(child:IWeaveTreeNode, index:int):Boolean
		{
			var childNode:EntityNode = child as EntityNode;
			if (childNode)
			{
				// does not support adding children from a different EntityCache
				if (getEntityCache() != childNode.getEntityCache())
					return false;
				getEntityCache().add_child(this.id, childNode.id, index);
				return true;
			}
			return false;
		}
		
		/**
		 * @inheritDoc
		 */
		public function removeChild(child:IWeaveTreeNode):Boolean
		{
			var childNode:EntityNode = child as EntityNode;
			if (childNode)
			{
				// does not support removing children from a different EntityCache
				if (getEntityCache() != childNode.getEntityCache())
					return false;
				childNode.getEntityCache().remove_child(this.id, childNode.id);
				return true;
			}
			return false;
		}
    }
}
