import 'dart:ui';
import 'warehouse_graph_service.dart';

class RouteService {
  static List<Offset> calculateRoute(List<dynamic> shelves, List<dynamic> taskItems, int currentFloor) {
    if (taskItems.isEmpty) return [];
    var floorShelves = shelves.where((s) => s['floor'] == currentFloor).toList();
    var graph = WarehouseGraphService(floorShelves);

    List<Offset> fullRoute = [];
    String currentLocationId = "start";

    for (var item in taskItems) {
      String targetShelf = item['shelfCode'];
      List<Offset> pathSegment = graph.findShortestPath(currentLocationId, targetShelf);

      if (pathSegment.isNotEmpty) {
        if (fullRoute.isEmpty) {
          fullRoute.addAll(pathSegment);
        } else {
          fullRoute.addAll(pathSegment.skip(1));
        }
        currentLocationId = "shelf_$targetShelf";
      }
    }

    return fullRoute;
  }
}