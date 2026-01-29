import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/credential.dart';
import '../repositories/credential_repository.dart';

class CredentialTransferService {
  CredentialTransferService(this._repository);

  final CredentialRepository _repository;

  // Standart header isimleri
  static const _headerUrl = 'url';
  static const _headerUsername = 'username';
  static const _headerPassword = 'password';
  static const _headerNotes = 'notes';
  static const _headerTags = 'tags';
  static const _headerFavorite = 'favorite';
  static const _headerCreatedAt = 'createdat';
  static const _headerUpdatedAt = 'updatedat';

  // Farklı şifre yöneticilerinden gelen alternatif header isimleri
  static const _passwordAliases = [
    'password',
    'login_password',
    'login password',
    'pass',
    'pwd',
    'secret',
  ];

  static const _usernameAliases = [
    'username',
    'login_username',
    'login username',
    'user name',
    'user',
    'login',
    'email',
    'e-mail',
    'login_uri', // some exports use this
  ];

  static const _titleAliases = [
    'title',
    'name',
    'entry',
    'site',
    'service',
    'account',
    'label',
  ];

  static const _urlAliases = [
    'url',
    'website',
    'web site',
    'site',
    'uri',
    'login_uri',
    'location',
    'link',
  ];

  static const _notesAliases = [
    'notes',
    'note',
    'comments',
    'comment',
    'extra',
    'additional info',
    'description',
  ];

  Future<File?> createExportFile() async {
    final credentials = await _repository.fetchAll();
    if (credentials.isEmpty) {
      return null;
    }

    final rows = <List<dynamic>>[
      [
        'title',
        _headerUrl,
        _headerUsername,
        _headerPassword,
        _headerNotes,
        _headerTags,
        _headerFavorite,
        _headerCreatedAt,
        _headerUpdatedAt,
      ],
      ...credentials.map((credential) {
        final tags = jsonEncode(credential.tags);
        return [
          credential.title,
          credential.website ?? '',
          credential.username,
          credential.password,
          credential.notes ?? '',
          tags,
          credential.isFavorite ? '1' : '0',
          credential.createdAt.toIso8601String(),
          credential.updatedAt.toIso8601String(),
        ];
      }),
    ];

    final csvString = const ListToCsvConverter().convert(rows);
    final directory = await getTemporaryDirectory();
    final fileName =
        'flupass_credentials_${DateTime.now().millisecondsSinceEpoch}.csv';
    final filePath = p.join(directory.path, fileName);
    final file = File(filePath);
    await file.writeAsString(csvString);
    return file;
  }

  Future<CredentialImportResult?> importFromFilePicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final path = result.files.single.path;
    if (path == null) {
      return CredentialImportResult.empty();
    }

    final file = File(path);
    if (!(await file.exists())) {
      return CredentialImportResult.empty();
    }

    try {
      final rows = await _readCsvRows(file);
      final credentials = _mapRowsToCredentials(rows);
      if (credentials.isEmpty) {
        return CredentialImportResult.empty();
      }

      final inserted = await _repository.bulkInsert(credentials);
      return CredentialImportResult(
        inserted: inserted,
        skipped: credentials.length - inserted,
      );
    } catch (error, stackTrace) {
      debugPrint('CSV import error: $error\n$stackTrace');
      return CredentialImportResult.error(error.toString());
    }
  }

  Future<List<List<dynamic>>> _readCsvRows(File file) async {
    final raw = await file.readAsString();
    final normalized = raw.replaceAll('\r\n', '\n');
    final converter = const CsvToListConverter(eol: '\n');
    try {
      return converter.convert(normalized);
    } on FormatException {
      return _manuallyParseCsv(normalized);
    }
  }

  List<Credential> _mapRowsToCredentials(List<List<dynamic>> rows) {
    if (rows.isEmpty) {
      return const [];
    }

    final headerRow = rows.first
        .map((cell) => cell.toString().trim().toLowerCase())
        .toList();
    final columnIndex = <String, int>{};
    for (var i = 0; i < headerRow.length; i++) {
      columnIndex[headerRow[i]] = i;
    }

    // Resolve column indices using aliases
    final passwordCol = _findColumnIndex(columnIndex, _passwordAliases);
    final usernameCol = _findColumnIndex(columnIndex, _usernameAliases);
    final titleCol = _findColumnIndex(columnIndex, _titleAliases);
    final urlCol = _findColumnIndex(columnIndex, _urlAliases);
    final notesCol = _findColumnIndex(columnIndex, _notesAliases);

    if (passwordCol == null) {
      throw const FormatException(
        'CSV dosyasında "password" sütunu bulunamadı.',
      );
    }

    final now = DateTime.now();
    final credentials = <Credential>[];

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) {
        continue;
      }

      final password = _readCellByIndex(row, passwordCol);
      if (password.isEmpty) {
        continue;
      }

      final title = _resolveTitleFromIndices(
        row,
        titleCol,
        urlCol,
        usernameCol,
        i,
      );
      final website = _readCellByIndex(row, urlCol);
      final username = _readCellByIndex(row, usernameCol);
      final notes = _readCellByIndex(row, notesCol);
      final tags = _readTags(row, columnIndex);
      final isFavorite = _readFavorite(row, columnIndex);
      final createdAt = _readDate(row, columnIndex, _headerCreatedAt) ?? now;
      final updatedAt = _readDate(row, columnIndex, _headerUpdatedAt) ?? now;

      credentials.add(
        Credential(
          id: null,
          title: title,
          username: username,
          password: password,
          website: website.isEmpty ? null : website,
          notes: notes.isEmpty ? null : notes,
          tags: tags,
          isFavorite: isFavorite,
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      );
    }

    return credentials;
  }

  int? _findColumnIndex(Map<String, int> columnIndex, List<String> aliases) {
    for (final alias in aliases) {
      if (columnIndex.containsKey(alias)) {
        return columnIndex[alias];
      }
    }
    return null;
  }

  String _readCellByIndex(List<dynamic> row, int? index) {
    if (index == null || index >= row.length) {
      return '';
    }
    return row[index].toString().trim();
  }

  String _resolveTitleFromIndices(
    List<dynamic> row,
    int? titleCol,
    int? urlCol,
    int? usernameCol,
    int rowIndex,
  ) {
    final explicitTitle = _readCellByIndex(row, titleCol);
    if (explicitTitle.isNotEmpty) {
      return explicitTitle;
    }

    final website = _readCellByIndex(row, urlCol);
    if (website.isNotEmpty) {
      // URL'den domain çıkar
      final domain = _extractDomain(website);
      if (domain.isNotEmpty) {
        return domain;
      }
      return website;
    }

    final username = _readCellByIndex(row, usernameCol);
    if (username.isNotEmpty) {
      return username;
    }

    return 'İçe Aktarılan Şifre $rowIndex';
  }

  String _extractDomain(String url) {
    try {
      var cleanUrl = url.trim();
      if (!cleanUrl.contains('://')) {
        cleanUrl = 'https://$cleanUrl';
      }
      final uri = Uri.parse(cleanUrl);
      var host = uri.host;
      // www. prefix'ini kaldır
      if (host.startsWith('www.')) {
        host = host.substring(4);
      }
      return host;
    } catch (_) {
      return '';
    }
  }

  List<String> _readTags(List<dynamic> row, Map<String, int> columnIndex) {
    final raw = _readCell(row, columnIndex, _headerTags);
    if (raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {
      // Fall back to manual split when JSON decode fails.
    }

    return raw
        .split(';')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  bool _readFavorite(List<dynamic> row, Map<String, int> columnIndex) {
    final raw = _readCell(row, columnIndex, _headerFavorite);
    if (raw.isEmpty) {
      return false;
    }

    final normalized = raw.toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }

  DateTime? _readDate(
    List<dynamic> row,
    Map<String, int> columnIndex,
    String column,
  ) {
    final raw = _readCell(row, columnIndex, column);
    if (raw.isEmpty) {
      return null;
    }

    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  String _readCell(
    List<dynamic> row,
    Map<String, int> columnIndex,
    String column, {
    String defaultValue = '',
  }) {
    final index = columnIndex[column];
    if (index == null || index >= row.length) {
      return defaultValue;
    }
    return row[index].toString().trim();
  }

  List<List<dynamic>> _manuallyParseCsv(String csv) {
    final lines = csv.split('\n');
    final rows = <List<dynamic>>[];
    for (final line in lines) {
      if (line.trim().isEmpty) {
        continue;
      }
      rows.add(_parseLine(line));
    }
    return rows;
  }

  List<dynamic> _parseLine(String line) {
    final values = <dynamic>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        values.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    values.add(buffer.toString());
    return values;
  }
}

class CredentialImportResult {
  const CredentialImportResult({
    required this.inserted,
    required this.skipped,
    this.error,
  });

  factory CredentialImportResult.empty() =>
      const CredentialImportResult(inserted: 0, skipped: 0);

  factory CredentialImportResult.error(String message) =>
      CredentialImportResult(inserted: 0, skipped: 0, error: message);

  final int inserted;
  final int skipped;
  final String? error;

  bool get hasError => error != null;
  bool get hasChanges => inserted > 0;
}
