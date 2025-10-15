// lib/utils/url_helpers.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:meubcars/core/api/endpoints.dart';

/// Retourne une URL absolue utilisable sur web, Android ou desktop.
String absoluteFrom(String urlOrPath) {
  if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
    try {
      final u = Uri.parse(urlOrPath);
      var scheme = u.scheme;
      var host = u.host;
      final port = u.hasPort ? u.port : null;

      if (!kIsWeb && Platform.isAndroid && (host == 'localhost' || host == '127.0.0.1')) {
        host = '10.0.2.2';
        if (scheme == 'https') scheme = 'http';
      }

      return Uri(
        scheme: scheme,
        host: host,
        port: port,
        path: u.path,
        query: u.hasQuery ? u.query : null,
      ).toString();
    } catch (_) {
      return urlOrPath;
    }
  }

  var base = EndPoint.baseUrl;
  if (base.endsWith('/')) base = base.substring(0, base.length - 1);
  if (base.toLowerCase().endsWith('/api')) base = base.substring(0, base.length - 4);

  Uri u;
  try {
    u = Uri.parse(base);
  } catch (_) {
    return base;
  }

  var scheme = u.scheme.isEmpty ? 'http' : u.scheme;
  var host = u.host.isEmpty ? 'localhost' : u.host;
  final port = u.hasPort ? u.port : (scheme == 'https' ? 443 : 80);

  if (!kIsWeb && Platform.isAndroid && (host == 'localhost' || host == '127.0.0.1')) {
    host = '10.0.2.2';
    if (scheme == 'https') scheme = 'http';
  }

  final p = (port == 80 && scheme == 'http') || (port == 443 && scheme == 'https') ? '' : ':$port';
  final path = urlOrPath.startsWith('/') ? urlOrPath : '/$urlOrPath';
  return '$scheme://$host$p$path';
}

/// Si les fichiers sont doublés dans /uploads/uploads, corrige le chemin.
String uploadsFallback(String absUrl) {
  final i = absUrl.indexOf('://');
  if (i < 0) return absUrl;
  final hostEnd = absUrl.indexOf('/', i + 3);
  if (hostEnd < 0) return absUrl;
  final host = absUrl.substring(0, hostEnd);
  final path = absUrl.substring(hostEnd);

  if (RegExp(r'^/uploads/(?!uploads/)', caseSensitive: false).hasMatch(path)) {
    return '$host' + path.replaceFirst(RegExp(r'^/uploads/', caseSensitive: false), '/uploads/uploads/');
  }
  return absUrl;
}

/// Détecte si une URL pointe vers une image.
bool looksLikeImage(String? url) {
  final s = (url ?? '').toLowerCase();
  return s.endsWith('.png') ||
      s.endsWith('.jpg') ||
      s.endsWith('.jpeg') ||
      s.contains('.png?') ||
      s.contains('.jpg?') ||
      s.contains('.jpeg?');
}
