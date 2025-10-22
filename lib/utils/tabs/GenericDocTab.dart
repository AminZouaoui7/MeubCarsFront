import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:meubcars/core/api/endpoints.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
import 'package:meubcars/utils/AppSideMenu.dart';

class GenericDocTab extends StatefulWidget {
  final int voitureId;
  final String endpoint;
  final String title;
  final IconData icon;

  const GenericDocTab({
    super.key,
    required this.voitureId,
    required this.endpoint,
    required this.title,
    required this.icon,
  });

  @override
  State<GenericDocTab> createState() => _GenericDocTabState();
}

class _GenericDocTabState extends State<GenericDocTab> {
  final Dio _dio = Dio(BaseOptions(baseUrl: EndPoint.baseUrl));
  List<dynamic> docs = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  String _fixUrl(String path) {
    if (path.isEmpty) return '';
    var base = EndPoint.baseUrl;
    base = base.replaceFirst(RegExp(r'/api/?$'), '/');
    if (path.startsWith('/')) path = path.substring(1);
    return '$base$path';
  }

  Future<void> _loadDocs() async {
    try {
      final res = await _dio.get("${widget.endpoint}/${widget.voitureId}");
      final list = List<Map<String, dynamic>>.from(res.data ?? []);

      list.sort((a, b) {
        final aActive = a['estActive'] == true || a['estActive'] == 1;
        final bActive = b['estActive'] == true || b['estActive'] == 1;
        if (aActive && !bActive) return -1;
        if (!aActive && bActive) return 1;
        return (b['version'] ?? 0).compareTo(a['version'] ?? 0);
      });

      setState(() {
        docs = list;
        loading = false;
      });
    } catch (e) {
      debugPrint("❌ Erreur chargement ${widget.title}: $e");
      setState(() => loading = false);
    }
  }

  void _showDocPopup(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16)),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70))
                ],
              ),
            ),
            SizedBox(
              width: 700,
              height: 500,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) =>
                progress == null
                    ? child
                    : const Center(
                    child: CircularProgressIndicator(
                        color: Colors.orangeAccent)),
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.image_not_supported,
                      color: Colors.white38, size: 60),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade700),
              onPressed: () async {
                final pdf = pw.Document();
                final image = await networkImage(url);
                pdf.addPage(
                    pw.Page(build: (_) => pw.Center(child: pw.Image(image))));
                await Printing.layoutPdf(
                    onLayout: (format) async => pdf.save());
              },
              icon: const Icon(Icons.print, color: Colors.white),
              label: const Text("Imprimer", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.orangeAccent),
              onPressed: () async =>
              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new),
              label: const Text("Ouvrir dans le navigateur",
                  style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white70));
    }

    if (docs.isEmpty) {
      return Center(
        child: Text("Aucun(e) ${widget.title.toLowerCase()} trouvé(e)",
            style: const TextStyle(color: Colors.white70)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final d = docs[i];
        final url = _fixUrl(d['fichierUrl'] ?? '');
        final estActive = d['estActive'] == true || d['estActive'] == 1;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 10),
          color: Colors.grey[900],
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (url.isNotEmpty)
                ClipRRect(
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    url,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: Colors.black26,
                      child: const Center(
                        child: Icon(Icons.image_not_supported,
                            color: Colors.white38, size: 50),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(widget.icon, color: Colors.orangeAccent),
                      const SizedBox(width: 8),
                      Text(
                        "Version ${d['version'] ?? '-'}",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16),
                      ),
                      if (estActive)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text("Active",
                              style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                        "📅 Du ${d['dateDebut']?.toString().split('T').first ?? '-'} → ${d['dateFin']?.toString().split('T').first ?? '-'}",
                        style: const TextStyle(color: Colors.white70)),
                    Text("💰 Montant: ${d['montant'] ?? '--'} TND",
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                        ),
                        onPressed: () {
                          if (url.isEmpty) return;
                          _showDocPopup(url);
                        },
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text("Ouvrir le document"),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
//fghj