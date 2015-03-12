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

package weave.data.DataSources
{
    import flash.net.URLRequest;
    
    import mx.charts.chartClasses.IColumn;
    import mx.rpc.events.FaultEvent;
    import mx.rpc.events.ResultEvent;
    
    import weave.api.data.ColumnMetadata;
    import weave.api.data.DataType;
    import weave.api.data.IAttributeColumn;
    import weave.api.data.IColumnReference;
    import weave.api.data.IDataSource;
    import weave.api.data.IWeaveTreeNode;
    import weave.api.newDisposableChild;
    import weave.api.newLinkableChild;
    import weave.api.registerDisposableChild;
    import weave.api.registerLinkableChild;
    import weave.api.reportError;
    import weave.compiler.Compiler;
    import weave.compiler.StandardLib;
    import weave.core.LinkablePromise;
    import weave.core.LinkableString;
    import weave.data.AttributeColumns.ProxyColumn;
    import weave.data.hierarchy.ColumnTreeNode;
    import weave.primitives.Dictionary2D;
    import weave.services.JsonCache;
    import weave.services.addAsyncResponder;

    public class FREDDataSource extends AbstractDataSource 
    {
        WeaveAPI.ClassRegistry.registerImplementation(IDataSource, FREDDataSource, "Federal Reserve Economic Data");

        

        public function FREDDataSource()
        {
        }

		
		
        override protected function initialize():void
        {
            // recalculate all columns previously requested
            //refreshAllProxyColumns();
            
            super.initialize();
        }
        
		private const jsonCache:JsonCache = newLinkableChild(this, JsonCache);
		
		public const apiKey:LinkableString = registerLinkableChild(this, new LinkableString("fa99c080bdbd1d486a55e7cb6ab7acbb"));
		
		/**
		 * @param method Examples: "category", "category/series"
		 * @param params Example: {category_id: 125}
		 */
		private function getUrl(method:String, params:Object):String
		{
			params['api_key'] = apiKey.value;
			params['file_type'] = 'json';
			var paramsStr:String = '';
			for (var key:String in params)
				paramsStr += (paramsStr ? '&' : '?') + key + '=' + params[key];
			return "http://api.stlouisfed.org/fred/" + method + paramsStr;
		}
		/**
		 * @param method Examples: "category", "category/series"
		 * @param params Example: {category_id: 125}
		 */
		private function getJson(method:String, params:Object):Object
		{
			return jsonCache.getJsonObject(getUrl(method, params));
		}
		
		private var functionCache:Dictionary2D = new Dictionary2D();
		
		public function createCategoryNode(data:Object = null, ..._):ColumnTreeNode
		{
			if (!data)
			{
				var name:String = WeaveAPI.globalHashMap.getName(this);
				data = {id: 0, name: name};
			}
			var node:ColumnTreeNode = functionCache.get(createCategoryNode, data.id);
			if (!node)
			{
				node = new ColumnTreeNode({
					source: this,
					data: data,
					label: data.name,
					isBranch: true,
					hasChildBranches: true,
					children: function(node:ColumnTreeNode):Array {
						return [].concat(
							getCategoryChildren(node),
							getCategorySeries(node)
						);
					}
				});
				functionCache.set(createCategoryNode, data.id, node);
			}
			return node;
		}
		
		private function getCategoryChildren(node:ColumnTreeNode):Array
		{
			var result:Object = getJson('category/children', {category_id: node.data.id});
			
			if(!result.categories)
				return [];
			return result.categories.map(createCategoryNode);
		}
		
		private function getCategorySeries(node:ColumnTreeNode):Array
		{
			var result:Object = getJson('category/series', {category_id: node.data.id});
			
			if(!result.seriess)
				return [];
			
			return result.seriess.map(createSeriesNode);
		}
		
		public function getObservationsCSV(series_id:String):CSVDataSource
		{
			var csv:CSVDataSource = functionCache.get(getObservationsCSV, series_id);
			if (!csv)
			{
				csv = newLinkableChild(this, CSVDataSource);
				functionCache.set(getObservationsCSV, series_id, csv);
				
				var request1:URLRequest = new URLRequest(getUrl('series', {series_id: series_id}));
				addAsyncResponder(
					WeaveAPI.URLRequestUtils.getURL(csv, request1),
					function(event:ResultEvent, csv:CSVDataSource):void {
						var data:Object = JsonCache.parseJSON(event.result.toString());
						data = data.seriess[0];
						var request2:URLRequest = new URLRequest(getUrl('series/observations', {series_id: series_id}));
						addAsyncResponder(
							WeaveAPI.URLRequestUtils.getURL(csv, request2),
							function(event:ResultEvent, csv:CSVDataSource):void
							{
								var result:Object = JsonCache.parseJSON(event.result.toString());
								var columnOrder:Array = ['date', 'realtime_start', 'realtime_end', 'value'];
								var rows:Array = WeaveAPI.CSVParser.convertRecordsToRows(result.observations, columnOrder);
								csv.csvData.setSessionState(rows);
								var valueTitle:String = lang("{0} ({1})", data.title, data.units);
								var metadataArray:Array = [
									{title: 'date', dataType: DataType.DATE, dateFormat: 'YYYY-MM-DD'},
									{title: 'realtime_start', dataType: DataType.DATE, dateFormat: 'YYYY-MM-DD'},
									{title: 'realtime_end', dataType: DataType.DATE, dateFormat: 'YYYY-MM-DD'},
									{title: valueTitle, dataType: DataType.NUMBER},
								];
								csv.metadata.setSessionState(metadataArray);
							},
							handleFault,
							csv
						);
					},
					handleFault,
					csv
				);
			}
			return csv;
		}
		private function handleFault(event:FaultEvent, token:Object = null):void
		{
			reportError(event);
		}
			
		public function createSeriesNode(data:Object, ..._):IWeaveTreeNode
		{
			var node:IWeaveTreeNode = functionCache.get(createSeriesNode, data.id);
			if (!node)
			{
				node = new ColumnTreeNode({
					label: data.title,
					source: this,
					data: data,
					isBranch: true,
					hasChildBranches: false,
					children: function(node:ColumnTreeNode):Array {
						var csv:CSVDataSource = getObservationsCSV(data.id);
						var csvRoot:IWeaveTreeNode = csv.getHierarchyRoot();
						node.source = csv;
						return csvRoot.getChildren().map(function(csvNode:IColumnReference, ..._):IWeaveTreeNode {
							var meta:Object = csvNode.getColumnMetadata();
							meta[META_SERIES_ID] = data.id;
							meta[META_COLUMN_NAME] = meta[CSVDataSource.METADATA_COLUMN_NAME];
							return generateHierarchyNode(meta);
						});
					}
				});
				functionCache.set(createSeriesNode, data.id, node);
			}
			return node;
		}
		
		
        override public function getHierarchyRoot():IWeaveTreeNode
        {
			
            if (!_rootNode)
            {
                var source:FREDDataSource = this;
                _rootNode = createCategoryNode();
            }
            return _rootNode;
        }
		
		public static const META_SERIES_ID:String = 'FRED_series_id';
		public static const META_COLUMN_NAME:String = 'FRED_column_name';
		
		public static const META_ID_FIELDS:Array = [META_SERIES_ID, META_COLUMN_NAME];
		
		override public function findHierarchyNode(metadata:Object):IWeaveTreeNode
		{
			return null;
		}
		
		override protected function generateHierarchyNode(metadata:Object):IWeaveTreeNode
		{
			if (!metadata)
				return null;
			
			return new ColumnTreeNode({
				source: this,
				idFields: META_ID_FIELDS,
				columnMetadata: metadata
			});
		}
        
        override protected function requestColumnFromSource(proxyColumn:ProxyColumn):void
        {
            var series:String = proxyColumn.getMetadata(META_SERIES_ID);
			//var columnName:String = proxyColumn.getMetadata(META_COLUMN_NAME);
			var csv:CSVDataSource = getObservationsCSV(series);
			var csvColumn:IAttributeColumn = csv.getAttributeColumn(ColumnMetadata.getAllMetadata(proxyColumn));
			proxyColumn.setInternalColumn(csvColumn);
        }
    }
}
