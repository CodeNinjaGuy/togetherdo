import 'package:flutter/material.dart';

class ResponsiveScaffold extends StatelessWidget {
  final Widget leftChild;
  final Widget? rightChild;
  final double breakpoint;
  final double leftWidth;
  final double rightWidth;

  const ResponsiveScaffold({
    super.key,
    required this.leftChild,
    this.rightChild,
    this.breakpoint = 800,
    this.leftWidth = 350,
    this.rightWidth = 600,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= breakpoint && rightChild != null) {
      // Split-View für Tablet/Desktop
      return Row(
        children: [
          SizedBox(
            width: leftWidth,
            child: Material(elevation: 2, child: leftChild),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: rightChild!),
        ],
      );
    } else {
      // Einspaltig für Mobil
      return leftChild;
    }
  }
}
