import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sio_connect/noor.dart';

void main() {
  testWidgets('render noor', (t) async {
    final dir = Platform.environment['NOOR_OUT'] ?? '/tmp/noor';
    Directory(dir).createSync(recursive: true);
    for (final m in NoorMood.values) {
      final key = GlobalKey();
      await t.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(width: 256, height: 256, child: Noor(mood: m, size: 256, animate: false)),
            ),
          ),
        ),
      );
      await t.pump();
      await t.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/noor_${m.name}.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }
  });
}
