import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:logger/logger.dart';
import 'package:podd_app/locator.dart';
import 'package:podd_app/models/entities/observation_report_monitoring_record.dart';
import 'package:podd_app/models/entities/observation_report_subject.dart';
import 'package:podd_app/models/entities/observation_subject.dart';
import 'package:podd_app/models/entities/observation_subject_monitoring.dart';
import 'package:podd_app/models/entities/observation_subject_report.dart';
import 'package:podd_app/models/file_submit_result.dart';
import 'package:podd_app/models/image_submit_result.dart';
import 'package:podd_app/models/observation_monitoring_record_submit_result.dart';
import 'package:podd_app/models/observation_subject_submit_result.dart';
import 'package:podd_app/services/api/observation_api.dart';
import 'package:podd_app/services/db_service.dart';
import 'package:podd_app/services/file_service.dart';
import 'package:podd_app/services/image_service.dart';
import 'package:stacked/stacked.dart';

abstract class IObservationRecordService with ListenableServiceMixin {
  final _logger = locator<Logger>();

  List<SubjectRecord> get pendingSubjectRecords;

  List<ObservationSubjectRecord> get subjectRecords;

  List<MonitoringRecord> get pendingMonitoringRecords;

  List<ObservationMonitoringRecord> get monitoringRecords;

  List<ObservationSubjectReport> get observationSubjectReports;

  Future<void> fetchAllSubjectRecords(bool resetFlag, int definitionId,
      [String? q]);

  Future<ObservationSubjectRecord> getSubject(String id);

  Future<void> fetchAllMonitoringRecords(String subjectId);

  Future<ObservationMonitoringRecord> getMonitoringRecord(String id);

  Future<void> fetchAllObservationSubjectReports(int subjectId);

  Future<SubjectRecordSubmitResult> submitSubjectRecord(SubjectRecord record);

  Future<MonitoringRecordSubmitResult> submitMonitoringRecord(
      MonitoringRecord record);

  fetchAllSubjectRecordsInBounded(int definitionId, double topLeftX,
      double topLeftY, double bottomRightX, double bottomRightY);

  Future<void> removePendingSubjectRecord(String id);

  Future<void> removePendingMonitoringRecord(String id);

  Future<void> removeAllPendingRecords();
}

class ObservationRecordService extends IObservationRecordService {
  final _dbService = locator<IDbService>();
  final _imageService = locator<IImageService>();
  final _fileService = locator<IFileService>();
  final _observationApi = locator<ObservationApi>();

  final ReactiveList<SubjectRecord> _pendingSubjectRecords =
      ReactiveList<SubjectRecord>();
  final ReactiveList<ObservationSubjectRecord> _subjectRecords =
      ReactiveList<ObservationSubjectRecord>();

  final ReactiveList<MonitoringRecord> _pendingMonitoringRecords =
      ReactiveList<MonitoringRecord>();
  final ReactiveList<ObservationMonitoringRecord> _monitoringRecords =
      ReactiveList<ObservationMonitoringRecord>();

  final ReactiveList<ObservationSubjectReport> _observationSubjectReports =
      ReactiveList<ObservationSubjectReport>();

  bool hasMoreSubjectRecords = false;
  int currentSubjectRecordNextOffset = 0;
  int subjectRecordLimit = 20;

  ObservationRecordService() {
    listenToReactiveValues([
      _pendingSubjectRecords,
      _subjectRecords,
      _pendingMonitoringRecords,
      _monitoringRecords,
      _observationSubjectReports,
    ]);
  }

  init() async {
    var subjectRows = await _dbService.db.query("subject_record");
    subjectRows.map((row) => SubjectRecord.fromMap(row)).forEach((record) {
      _pendingSubjectRecords.add(record);
    });

    var monitoringRows = await _dbService.db.query("monitoring_record");
    monitoringRows
        .map((row) => MonitoringRecord.fromMap(row))
        .forEach((record) {
      _pendingMonitoringRecords.add(record);
    });
  }

  @override
  List<SubjectRecord> get pendingSubjectRecords => _pendingSubjectRecords;

  @override
  List<ObservationSubjectRecord> get subjectRecords => _subjectRecords;

  @override
  List<MonitoringRecord> get pendingMonitoringRecords =>
      _pendingMonitoringRecords;

  @override
  List<ObservationMonitoringRecord> get monitoringRecords => _monitoringRecords;

  @override
  List<ObservationSubjectReport> get observationSubjectReports =>
      _observationSubjectReports;

  @override
  Future<void> fetchAllSubjectRecords(bool resetFlag, int definitionId,
      [String? q]) async {
    if (resetFlag) {
      currentSubjectRecordNextOffset = 0;
    }
    var result = await _observationApi.fetchSubjectRecords(definitionId, q: q);

    if (resetFlag) {
      _subjectRecords.clear();
    }

    _subjectRecords.addAll(result.data);
    hasMoreSubjectRecords = result.hasNextPage;
    currentSubjectRecordNextOffset =
        currentSubjectRecordNextOffset + subjectRecordLimit;
  }

  @override
  Future<ObservationSubjectRecord> getSubject(String id) async {
    var result = await _observationApi.getSubjectRecord(id);
    var monitoringRecords = result.data.monitoringRecords;

    _monitoringRecords.clear();
    _monitoringRecords.addAll(monitoringRecords);

    return result.data;
  }

  @override
  Future<void> fetchAllMonitoringRecords(String subjectId) async {
    var result = await _observationApi.fetchMonitoringRecords(subjectId);
    _monitoringRecords.clear();
    _monitoringRecords.addAll(result.data);
  }

  @override
  Future<ObservationMonitoringRecord> getMonitoringRecord(String id) async {
    var result = await _observationApi.getMonitoringRecord(id);
    return result.data;
  }

  /// Umimplemented future feature
  @override
  Future<void> fetchAllObservationSubjectReports(int subjectId) async {}

  @override
  Future<SubjectRecordSubmitResult> submitSubjectRecord(
      SubjectRecord record) async {
    try {
      var result = await _observationApi.submitSubjectRecord(record);

      if (result is SubjectRecordSubmitSuccess) {
        await _deleteSubjectRecordFromLocalDB(record);
        result.subject.images = List.of([]);

        // submit images
        var localImages = await _imageService.findByReportId(record.id);
        for (var img in localImages) {
          var submitImageResult = await _imageService
              .submitObservationRecordImage(img, result.subject.id, "subject");
          if (submitImageResult is ImageSubmitSuccess) {
            result.subject.images!
                .add(submitImageResult.image as ObservationRecordImage);
          }

          if (submitImageResult is ImageSubmitFailure) {
            _logger.e("Submit image error: ${submitImageResult.messages}");
          }
        }

        // submit files
        var localFiles =
            await _fileService.findAllReportFilesByReportId(record.id);
        for (var file in localFiles) {
          var submitFileResult = await _fileService.submitObservationRecordFile(
              file, result.subject.id);
          if (submitFileResult is FileSubmitSuccess) {
            result.subject.files!
                .add(submitFileResult.file as ObservationRecordFile);
          }

          if (submitFileResult is FileSubmitFailure) {
            _logger.e("Submit file error: ${submitFileResult.messages}");
          }
        }
        _subjectRecords.insert(0, result.subject);
      }

      if (result is SubjectRecordSubmitFailure) {
        _logger.e("Submit subject record error: ${result.messages}");
        _saveSubjectRecordToLocalDB(record);
        return SubjectRecordSubmitPending();
      }
      return result;
    } on LinkException catch (e) {
      _logger.e(e);
      _saveSubjectRecordToLocalDB(record);
      return SubjectRecordSubmitPending();
    }
  }

  @override
  Future<MonitoringRecordSubmitResult> submitMonitoringRecord(
      MonitoringRecord record) async {
    try {
      var result = await _observationApi.submitMonitoringRecord(record);

      if (result is MonitoringRecordSubmitSuccess) {
        await _deleteMonitoringRecordFromLocalDB(record);
        result.monitoringRecord.images = List.of([]);

        // submit images
        var localImages = await _imageService.findByReportId(record.id);
        for (var img in localImages) {
          var submitImageResult =
              await _imageService.submitObservationRecordImage(
                  img, result.monitoringRecord.id, "monitoring");
          if (submitImageResult is ImageSubmitSuccess) {
            result.monitoringRecord.images!
                .add(submitImageResult.image as ObservationRecordImage);
          }

          if (submitImageResult is ImageSubmitFailure) {
            _logger.e("Submit image error: ${submitImageResult.messages}");
          }
        }

        // submit files
        var localFiles =
            await _fileService.findAllReportFilesByReportId(record.id);
        for (var file in localFiles) {
          var submitFileResult = await _fileService.submitObservationRecordFile(
              file, result.monitoringRecord.id);
          if (submitFileResult is FileSubmitSuccess) {
            result.monitoringRecord.files!
                .add(submitFileResult.file as ObservationRecordFile);
          }

          if (submitFileResult is FileSubmitFailure) {
            _logger.e("Submit file error: ${submitFileResult.messages}");
          }
        }
        _monitoringRecords.insert(0, result.monitoringRecord);
      }

      if (result is MonitoringRecordSubmitFailure) {
        _logger.e("Submit monitoring record error: ${result.messages}");
        _saveMonitoringRecordToLocalDB(record);
        return MonitoringRecordSubmitPending();
      }
      return result;
    } on LinkException catch (e) {
      _logger.e(e);
      _saveMonitoringRecordToLocalDB(record);
      return MonitoringRecordSubmitPending();
    }
  }

  @override
  Future<List<ObservationSubjectRecord>> fetchAllSubjectRecordsInBounded(
      int definitionId,
      double topLeftX,
      double topLeftY,
      double bottomRightX,
      double bottomRightY) async {
    var result = await _observationApi.fetchSubjectRecordsInBounded(
        definitionId, topLeftX, topLeftY, bottomRightX, bottomRightY);
    return result;
  }

  _deleteSubjectRecordFromLocalDB(SubjectRecord record) async {
    var db = _dbService.db;
    db.delete(
      "subject_record",
      where: "id = ?",
      whereArgs: [record.id],
    );

    _pendingSubjectRecords.remove(record);
  }

  Future<bool> _isSubjectRecordInLocalDB(String id) async {
    var db = _dbService.db;
    var results = await db.query(
      "subject_record",
      where: 'id = ?',
      whereArgs: [
        id,
      ],
    );
    return results.isNotEmpty;
  }

  _saveSubjectRecordToLocalDB(SubjectRecord record) async {
    var db = _dbService.db;
    var isInDB = await _isSubjectRecordInLocalDB(record.id);
    if (isInDB) {
      db.update(
        "subject_record",
        record.toMap(),
        where: "id = ?",
        whereArgs: [
          record.id,
        ],
      );
    } else {
      db.insert("subject_record", record.toMap());
      _pendingSubjectRecords.add(record);
    }
  }

  @override
  Future<void> removePendingSubjectRecord(String id) async {
    var db = _dbService.db;
    await db.delete("subject_record", where: "id = ?", whereArgs: [id]);
    await _imageService.remove(id);
    _pendingSubjectRecords.removeWhere((r) => r.id == id);
  }

  _deleteMonitoringRecordFromLocalDB(MonitoringRecord record) async {
    var db = _dbService.db;
    db.delete(
      "monitoring_record",
      where: "id = ?",
      whereArgs: [record.id],
    );

    _pendingMonitoringRecords.remove(record);
  }

  Future<bool> _isMonitoringRecordInLocalDB(String id) async {
    var db = _dbService.db;
    var results = await db.query(
      "monitoring_record",
      where: 'id = ?',
      whereArgs: [
        id,
      ],
    );
    return results.isNotEmpty;
  }

  _saveMonitoringRecordToLocalDB(MonitoringRecord record) async {
    var db = _dbService.db;
    var isInDB = await _isMonitoringRecordInLocalDB(record.id);
    if (isInDB) {
      db.update(
        "monitoring_record",
        record.toMap(),
        where: "id = ?",
        whereArgs: [
          record.id,
        ],
      );
    } else {
      db.insert("monitoring_record", record.toMap());
      _pendingMonitoringRecords.add(record);
    }
  }

  @override
  Future<void> removePendingMonitoringRecord(String id) async {
    var db = _dbService.db;
    await db.delete("monitoring_record", where: "id = ?", whereArgs: [id]);
    await _imageService.remove(id);
    _pendingMonitoringRecords.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> removeAllPendingRecords() async {
    var db = _dbService.db;
    await db.delete("subject_record");
    await db.delete("monitoring_record");

    _pendingSubjectRecords.clear();
    _pendingMonitoringRecords.clear();
    await _imageService.removeAll();
  }
}
