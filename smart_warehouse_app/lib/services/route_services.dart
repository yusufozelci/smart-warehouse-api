import 'dart:ui';
import 'warehouse_graph_service.dart';

class RouteData {
  final List<Offset> points;
  final List<int> segmentEnds;

  RouteData({required this.points, required this.segmentEnds});
}

class RouteService {
  static RouteData calculateRoute(List<dynamic> shelves, List<dynamic> taskItems, int currentFloor) {
    if (taskItems.isEmpty) return RouteData(points: [], segmentEnds: []);
    var floorShelves = shelves.where((s) => s['floor'] == currentFloor).toList();
    var graph = WarehouseGraphService(floorShelves);

    List<Offset> fullRoute = [];
    List<int> segmentEnds = [];
    String currentLocationId = "start";

    var currentFloorItems = taskItems.where((item) {
      var s = shelves.firstWhere((sh) => sh['shelfCode'] == item['shelfCode'], orElse: () => null);
      return s != null && s['floor'] == currentFloor;
    }).toList();

    for (var item in currentFloorItems) {
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
      segmentEnds.add(fullRoute.isEmpty ? 0 : fullRoute.length - 1);
    }

    return RouteData(points: fullRoute, segmentEnds: segmentEnds);
  }
}