import 'dart:ui';
import '../models/warehouse_node.dart';
import '../models/warehouse_edge.dart';

class WarehouseGraphService {
  final Map<String, WarehouseNode> nodes = {};
  final Map<String, List<WarehouseEdge>> adjacencyList = {};

  WarehouseGraphService(List<dynamic> shelves) {
    _buildGraph(shelves);
  }

  void _buildGraph(List<dynamic> shelves) {
    _addNode("start", const Offset(80, 480));
    _addNode("end", const Offset(1200, 480));
    
    for (var shelf in shelves) {
      String code = shelf['shelfCode'];
      double cx = (shelf['coordinateX'] ?? 0).toDouble();
      double cy = (shelf['coordinateY'] ?? 0).toDouble();
      double shelfCenterX = cx + 70;
      double shelfCenterY = cy + 45;

      String shelfNodeId = "shelf_$code";
      _addNode(shelfNodeId, Offset(shelfCenterX, shelfCenterY));
      String lastPart = code.split('-').last;
      String numbersOnly = lastPart.replaceAll(RegExp(r'[^0-9]'), '');
      int shelfNumber = int.tryParse(numbersOnly) ?? 1;

      double accessX = shelfCenterX;

      if (shelfNumber % 3 == 1) {
        accessX = cx - 5;
      } else if (shelfNumber % 3 == 2) {
        accessX = cx - 5;
      } else if (shelfNumber % 3 == 0) {
        accessX = cx + 155;
      }

      String accessNodeId = "access_$code";
      String entryNodeId = "entry_$code";
      _addNode(accessNodeId, Offset(accessX, 480));
      _addNode(entryNodeId, Offset(accessX, shelfCenterY));
      _addEdge(accessNodeId, entryNodeId);
      _addEdge(entryNodeId, shelfNodeId);
    }

    List<String> spineNodes = nodes.keys.where((k) => k.startsWith("access_") || k == "start" || k == "end").toList();
    spineNodes.sort((a, b) => nodes[a]!.position.dx.compareTo(nodes[b]!.position.dx));

    for (int i = 0; i < spineNodes.length - 1; i++) {
      _addEdge(spineNodes[i], spineNodes[i + 1]);
    }
  }

  void _addNode(String id, Offset pos) {
    if (!nodes.containsKey(id)) {
      nodes[id] = WarehouseNode(id, pos);
      adjacencyList[id] = [];
    }
  }

  void _addEdge(String id1, String id2) {
    var n1 = nodes[id1]!;
    var n2 = nodes[id2]!;
    double distance = (n1.position - n2.position).distance;
    adjacencyList[id1]!.add(WarehouseEdge(n2, distance));
    adjacencyList[id2]!.add(WarehouseEdge(n1, distance));
  }

  List<Offset> findShortestPath(String startId, String targetShelfCode) {
    String targetId = "shelf_$targetShelfCode";
    if (!nodes.containsKey(startId) || !nodes.containsKey(targetId)) return [];

    var distances = <String, double>{};
    var previous = <String, String?>{};
    var unvisited = nodes.keys.toList();

    for (var key in nodes.keys) {
      distances[key] = double.infinity;
      previous[key] = null;
    }
    distances[startId] = 0;

    while (unvisited.isNotEmpty) {
      unvisited.sort((a, b) => (distances[a] ?? double.infinity).compareTo(distances[b] ?? double.infinity));
      String current = unvisited.removeAt(0);

      if (distances[current] == double.infinity) break;
      if (current == targetId) break;

      for (var edge in adjacencyList[current]!) {
        double newDist = distances[current]! + edge.weight;
        if (newDist < distances[edge.target.id]!) {
          distances[edge.target.id] = newDist;
          previous[edge.target.id] = current;
        }
      }
    }

    List<Offset> path = [];
    String? curr = targetId;
    while (curr != null) {
      path.add(nodes[curr]!.position);
      curr = previous[curr];
    }

    return path.reversed.toList();
  }
}