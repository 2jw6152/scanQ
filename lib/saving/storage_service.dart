import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/csat_question.dart';

class StorageService {
  Future<File> saveQuestion(CSATQuestion question) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/question_${question.number ?? DateTime.now().millisecondsSinceEpoch}.txt');
    return file.writeAsString(question.body);
  }
}
