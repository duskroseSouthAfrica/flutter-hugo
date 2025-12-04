import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DriveBackup {
  static late drive.DriveApi driveApi;
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    final jsonString = await rootBundle.loadString('assets/service_account.json');
    final creds = ServiceAccountCredentials.fromJson(jsonDecode(jsonString));
    final client = await clientViaServiceAccount(creds, [drive.DriveApi.driveFileScope]);
    driveApi = drive.DriveApi(client);
    _ready = true;
  }

  static Future<void> upload(String localPath, String fileName) async {
    await init();
    final deviceId = (await DeviceInfoPlugin().androidInfo).id;
    final file = File(localPath);
    final media = drive.Media(file.openRead(), file.lengthSync());
    await driveApi.files.create(
      drive.File()..name = fileName..parents = ['Yebo_User_Backups/$deviceId'],
      uploadMedia: media,
    );
  }
}