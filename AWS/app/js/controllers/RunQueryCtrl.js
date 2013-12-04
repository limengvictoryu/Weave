/**
 * RunQueryCtrl. This controller manages the run of queries.
 */
angular.module("aws.RunQuery", []).controller("RunQueryCtrl", function($scope, queryService) {
			
		var queryHandler = undefined;
		
		$scope.runQuery = function(){
			queryHandler = new aws.QueryHandler(queryService.queryObject);
          
            // doesn't work to remove weave instance -> $scope.weaveInstancePanel = "";
            // Probably need to put a broadcast event here? to tell weave instance panel to die.

			queryHandler.runQuery();
		};
		
		
		$scope.updateVisualizations = function(){
			queryHandler = new aws.QueryHandler(queryService.queryObject);
			if(queryHandler) {
				queryHandler.updateVisualizations(queryHandler.visualizations,queryHandler.keyType);
				
			}
		};
		
		$scope.clearWeave = function(){
			if (queryHandler) {
				queryHandler.clearWeave();
				queryHandler = undefined;
			}
		};
});