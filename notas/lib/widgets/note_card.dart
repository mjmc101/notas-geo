import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../theme.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onToggleDone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const NoteCard({
    super.key,
    required this.note,
    required this.onToggleDone,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final done = note.isDone;
    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: onToggleDone,
                    child: Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(right: 12, top: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: done ? AppTheme.accent : AppTheme.textSecondary,
                          width: 2,
                        ),
                        color: done ? AppTheme.accent : Colors.transparent,
                      ),
                      child: done
                          ? const Icon(Icons.check, size: 13, color: AppTheme.background)
                          : null,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      note.title,
                      style: TextStyle(
                        color: done ? AppTheme.textSecondary : AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationColor: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        color: AppTheme.textSecondary, size: 20),
                    color: AppTheme.surface,
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit, color: AppTheme.accent, size: 18),
                          SizedBox(width: 8),
                          Text('Editar',
                              style: TextStyle(color: AppTheme.textPrimary)),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete, color: AppTheme.error, size: 18),
                          SizedBox(width: 8),
                          Text('Apagar',
                              style: TextStyle(color: AppTheme.error)),
                        ]),
                      ),
                    ],
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                  ),
                ],
              ),
              if (note.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 34),
                  child: Text(
                    note.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: done
                          ? AppTheme.textSecondary.withAlpha(150)
                          : AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              if (note.timeAlert != null || note.locationAlert != null) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 34),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (note.timeAlert != null)
                        _Chip(
                          icon: note.timeAlert!.isRecurring
                              ? Icons.repeat
                              : Icons.alarm,
                          label: note.timeAlert!.isRecurring
                              ? _recurringLabel(note.timeAlert!.recurringType)
                              : DateFormat('dd/MM HH:mm')
                                  .format(note.timeAlert!.dateTime),
                        ),
                      if (note.locationAlert != null)
                        _Chip(
                          icon: Icons.location_on,
                          label: note.locationAlert!.locationName ??
                              '${note.locationAlert!.radiusMeters.toInt()}m',
                        ),
                      if (note.locationAlert?.timeRestriction != null)
                        const _Chip(icon: Icons.link, label: 'GPS+Hora'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _recurringLabel(String? type) {
    switch (type) {
      case 'daily':
        return 'Diário';
      case 'weekly':
        return 'Semanal';
      case 'monthly':
        return 'Mensal';
      default:
        return 'Recorrente';
    }
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x1AC8F060),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x4DC8F060)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.accent),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: AppTheme.accent, fontSize: 11)),
        ],
      ),
    );
  }
}
