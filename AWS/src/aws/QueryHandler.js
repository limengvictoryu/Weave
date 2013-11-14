goog.provide('aws.QueryHandler');

goog.require('aws');
goog.require('aws.RClient');
goog.require('aws.StataClient');
goog.require('aws.WeaveClient');

/**
 * This class is designed to receive a query object and interpret its content.
 * 
 * @constructor
 * 
 * @param {aws.queryObject} queryObject. The query object obtained from the UI, or alternatively, from a file.
 *
 **/

aws.QueryHandler = function(queryObject)
{
	// the idea here is that we "parse" the query Object into smaller entities (brokers) and use them as needed.
	/**@type {string}*/
	this.title = queryObject.title;
	
	this.dateGenerated = queryObject.date;
	this.author = queryObject.author;
	
	if(queryObject.hasOwnProperty("FilteredColumnRequest") &&
	   queryObject.hasOwnProperty("scriptSelected") ) {
		this.rRequestObject = {
				FilteredColumnRequest : queryObject.FilteredColumnRequest,
				scriptName : queryObject.scriptSelected
		};			

	}
	
	if(queryObject.hasOwnProperty("ColorColumn")) {
		this.ColorColumn = queryObject.ColorColumn;
	}

	this.keyType = "";
	
	this.visualizations = [];
	
	if (queryObject.hasOwnProperty("MapTool")) {
		this.keyType = queryObject.MapTool.keyType;
		this.visualizations.push(
				{
					type : "MapTool",
					parameters : queryObject.MapTool
				}
		);
	}	
	
	if (queryObject.hasOwnProperty("ScatterPlotTool")) {
		this.visualizations.push(
				{
					type : "ScatterPlotTool",
					parameters : queryObject.ScatterPlotTool
				}
		);
	}	
	if (queryObject.hasOwnProperty("BarChartTool")) {
		this.visualizations.push(
				{
					type : "BarChartTool",
					parameters : queryObject.BarChartTool
				}
		);
	}	
	
	if (queryObject.hasOwnProperty("DataTable")) {
		this.visualizations.push(
				{
					type : "DataTable",
					parameters : queryObject.DataTable
				}
		);
	}	
	
//	testing
//	this.weaveClient;
//    testing
    this.newWeaveWindow = null;
	
	// check what type of computation engine we have, to create the appropriate
	// computation client
	this.ComputationEngine = null;
	if(queryObject.ComputationEngine == 'r' || queryObject.ComputationEngine == 'R') {
		this.ComputationEngine = new aws.RClient(this.rRequestObject);
	}// else if (queryObject.scriptType == 'stata') {
//		// computationEngine = new aws.StataClient();
//	}

	this.resultDataSet = "";
};

aws.QueryHandler.prototype.launchWeaveWindow = function(){
    this.newWeaveWindow = window.open("SeparateWindow.html",
        "_blank","toolbar=yes, fullscreen = yes, scrollbars=yes, resizable=yes");
}
aws.QueryHandler.prototype.closeWeaveWindow = function(){
    // need code that will destroy the window we created earlier. while passing the

    this.newWeaveWindow = null;
}

aws.QueryHandler.prototype.getCurrentWeave = function(){
    if (false) {
        var weave1 = $('#weave');
        return new aws.WeaveClient(weave1);
    }else if (this.newWeaveWindow != null) {
        var weave2 = this.newWeaveWindow.document.getElementById("weave");
        return new aws.WeaveClient(weave2);
    }
}
//testing
//var newWeaveWindow;
//var weaveInstance;
//var client = aws.QueryHandler.weaveClient;
//testing
/**
 * This function is the golden evaluator of the query.
 * 1- run the scripts against the data
 * 2- send the results to weave
 * 3- call weave, create the visualizations and set the parameters
 */
aws.QueryHandler.prototype.runQuery = function() {
	
	//testing
//	newWeaveWindow = window.open("SeparateWindow.html",
//			"_blank","toolbar=yes, fullscreen = yes, scrollbars=yes, resizable=yes");
//
//	weaveInstance = newWeaveWindow.document.getElementById("weave");//getting the pointer to the weave instance in the separate browser window
//    client = new aws.WeaveClient(weaveInstance);
    //testing
    this.weaveClient = this.getCurrentWeave();

	// step 1
	var that = this;
	this.ComputationEngine.run("runScriptWithFilteredColumns", function(result) {	
		aws.timeLogString = "";
		that.resultDataSet = result[0].value;//get rid of hard coded (for later)
		console.log(that.resultDataSet);
		// aws.timeLogString = result[1].value;
		// console.log(result[1].value);
		$("#LogBox").append('<p>' + aws.timeLogString + '</p>');
		
		// step 2
		//var dataSourceName = that.weaveClient.addCSVDataSourceFromString(that.resultDataSet, "", that.keyType, "fips");
		var dataSourceName = that.weaveClient.addCSVDataSource(that.resultDataSet, "", that.keyType, "fips");
		
		// step 3
		for (var i in that.visualizations) {
			that.weaveClient.newVisualization(that.visualizations[i], dataSourceName);
			aws.timeLogString = aws.reportTime(that.visualizations[i].type + ' added');
			$("#LogBox").append('<p>' + aws.timeLogString + '</p>');
		}
		
		if (that.ColorColumn) {
			that.weaveClient.setColorAttribute(that.ColorColumn, dataSourceName);
			aws.timeLogString = aws.reportTime('color column added');
			$("#LogBox").append('<p>' + aws.timeLogString + '</p>');		
		}	
	});
};

aws.QueryHandler.prototype.clearWeave = function () {
	this.weaveClient.clearWeave();
};