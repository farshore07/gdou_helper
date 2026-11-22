import 'package:flutter/material.dart';

import '../config/legal_documents.dart';

class LegalDocumentPage extends StatelessWidget {
  final LegalDocumentType type;

  const LegalDocumentPage({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final doc = getLegalDocument(type);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(doc.title)),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withAlpha(110),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        type == LegalDocumentType.privacy
                            ? Icons.privacy_tip_outlined
                            : Icons.description_outlined,
                        size: 18,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '更新日期：${doc.updatedAt}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    doc.summary,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            for (final section in doc.sections) ...[
              Text(
                section.heading,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              for (final paragraph in section.paragraphs) ...[
                Text(
                  paragraph,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.65,
                    color: cs.onSurface.withAlpha(220),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
