import 'dart:async';
import 'dart:html';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:studio/app_state.dart';
import 'package:studio/data_explorer.dart';

class FileUpload extends StatefulWidget {
  @override
  _FileUploadState createState() => _FileUploadState();
}

class _FileUploadState extends State<FileUpload> {
  late StreamSubscription _dragOverSubscription;
  late StreamSubscription _dropSubscription;

  @override
  void initState() {
    super.initState();

    if (document.body != null) {
      _dropSubscription = document.body!.onDragOver.listen(_onDragOver);
      _dropSubscription = document.body!.onDrop.listen(_onDrop);
    }
  }

  void _onDragOver(MouseEvent event) {
    event.stopPropagation();
    event.preventDefault();
  }

  void _onDrop(MouseEvent event) {
    event.stopPropagation();
    event.preventDefault();

    var files = event.dataTransfer.files;
    if (files != null && files.isEmpty) return;

    if (files != null) {
      var file = files.first;
      var reader = FileReader();
      reader.onLoadEnd.listen((e) {
        _process(file.name, reader.result as Uint8List);
      });
      reader.readAsArrayBuffer(file);
    }

    var appState = Provider.of<AppState>(context);
    appState.status = UploadStatus.processing;
  }

  void _process(String name, Uint8List bytes) {
    var appState = Provider.of<AppState>(context, listen: false);
    scheduleMicrotask(() async {
      try {
        var box = await Hive.openBox('box', bytes: bytes);
        var map = box.toMap();
        appState.boxName = name;
        appState.entries = map;
        appState.status = UploadStatus.success;
      } catch (e) {
        appState.status = UploadStatus.failed;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var app = Provider.of<AppState>(context);
    switch (app.status) {
      case UploadStatus.none:
        return Center(
          child: Text('Drop a .hive file to begin\n\n(This is a preview version)'),
        );
      case UploadStatus.processing:
        return Center(
          child: Text('Processing file'),
        );

      case UploadStatus.failed:
        return Center(
          child: Text('Invalid file'),
        );
      case UploadStatus.success:
        return DataExplorer();
    }
  }

  @override
  void dispose() {
    _dragOverSubscription.cancel();
    _dropSubscription.cancel();
    super.dispose();
  }
}

enum UploadStatus {
  none,
  processing,
  success,
  failed,
}
