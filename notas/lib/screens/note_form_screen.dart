import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../services/location_service.dart';
import '../theme.dart';
import 'location_picker_screen.dart';

// ── Restriction type chosen in the UI ────────────────────────────────────────
enum _RestrictionType { timeRange, date, dateRange }

class NoteFormScreen extends StatefulWidget {
  final Note? note;
  const NoteFormScreen({super.key, this.note});

  @override
  State<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends State<NoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locNameCtrl = TextEditingController();

  // ── Time alert ──────────────────────────────────────────────────────────────
  bool _hasTimeAlert = false;
  DateTime? _alertDt;
  bool _isRecurring = false;
  String _recurringType = 'daily';

  // ── Location alert ──────────────────────────────────────────────────────────
  bool _hasLocationAlert = false;
  double? _locLat;
  double? _locLng;
  double _locRadius = 200;

  // ── Location restriction (combined) ─────────────────────────────────────────
  bool _hasCombined = false;
  _RestrictionType _restrictionType = _RestrictionType.timeRange;

  // Time-of-day window (used by timeRange, and optionally by date/dateRange)
  TimeOfDay? _combinedStartTime;
  TimeOfDay? _combinedEndTime;
  bool _combinedHasTimeWindow = false; // only relevant for date/dateRange types

  // Date restriction
  DateTime? _combineDate;     // start date (or single date)
  DateTime? _combineDateEnd;  // end date (dateRange only)

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    if (note == null) return;

    _titleCtrl.text = note.title;
    _descCtrl.text = note.description;

    if (note.timeAlert != null) {
      _hasTimeAlert = true;
      _alertDt = note.timeAlert!.dateTime;
      _isRecurring = note.timeAlert!.isRecurring;
      _recurringType = note.timeAlert!.recurringType ?? 'daily';
    }

    if (note.locationAlert != null) {
      final loc = note.locationAlert!;
      _hasLocationAlert = true;
      _locLat = loc.latitude;
      _locLng = loc.longitude;
      _locRadius = loc.radiusMeters;
      _locNameCtrl.text = loc.locationName ?? '';

      if (loc.hasRestriction) {
        _hasCombined = true;

        if (loc.dateRangeStart != null) {
          _combineDate = loc.dateRangeStart;
          _combineDateEnd = loc.dateRangeEnd;
          _restrictionType = loc.dateRangeEnd != null
              ? _RestrictionType.dateRange
              : _RestrictionType.date;
          if (loc.hasTimeWindow) {
            _combinedHasTimeWindow = true;
            _combinedStartTime = _toTimeOfDay(loc.timeWindowStartMinutes!);
            _combinedEndTime = _toTimeOfDay(loc.timeWindowEndMinutes!);
          }
        } else if (loc.hasTimeWindow) {
          _restrictionType = _RestrictionType.timeRange;
          _combinedStartTime = _toTimeOfDay(loc.timeWindowStartMinutes!);
          _combinedEndTime = _toTimeOfDay(loc.timeWindowEndMinutes!);
        }
      }
    }
  }

  TimeOfDay _toTimeOfDay(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locNameCtrl.dispose();
    super.dispose();
  }

  // ── Pickers ──────────────────────────────────────────────────────────────────

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _alertDt ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
      builder: _darkPicker,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_alertDt ?? now),
      builder: _darkPicker,
    );
    if (time == null || !mounted) return;
    setState(() => _alertDt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _pickCombinedTime(bool isStart) async {
    final initial = isStart
        ? (_combinedStartTime ?? const TimeOfDay(hour: 9, minute: 0))
        : (_combinedEndTime ?? const TimeOfDay(hour: 18, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: _darkPicker,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _combinedStartTime = picked;
      } else {
        _combinedEndTime = picked;
      }
    });
  }

  Future<void> _pickCombineDate(bool isEnd) async {
    final now = DateTime.now();
    final initial = isEnd
        ? (_combineDateEnd ?? (_combineDate ?? now))
        : (_combineDate ?? now);
    final firstDate = isEnd ? (_combineDate ?? now) : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 3650)),
      builder: _darkPicker,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isEnd) {
        _combineDateEnd = picked;
      } else {
        _combineDate = picked;
        if (_combineDateEnd != null && _combineDateEnd!.isBefore(picked)) {
          _combineDateEnd = null;
        }
      }
    });
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLat: _locLat,
          initialLng: _locLng,
          initialRadius: _locRadius,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _locLat = result['lat'] as double;
        _locLng = result['lng'] as double;
        _locRadius = result['radius'] as double;
      });
    }
  }

  Widget _darkPicker(BuildContext ctx, Widget? child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.accent,
            surface: AppTheme.surface,
            onSurface: AppTheme.textPrimary,
          ),
        ),
        child: child!,
      );

  // ── Save ─────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    TimeAlert? timeAlert;
    LocationAlert? locationAlert;

    if (_hasTimeAlert) {
      if (_alertDt == null && !_isRecurring) {
        _showSnack('Escolha uma data/hora para o aviso');
        return;
      }
      timeAlert = TimeAlert(
        dateTime: _alertDt ?? DateTime.now().add(const Duration(hours: 1)),
        isRecurring: _isRecurring,
        recurringType: _isRecurring ? _recurringType : null,
      );
    }

    if (_hasLocationAlert) {
      if (_locLat == null || _locLng == null) {
        _showSnack('Escolha um ponto no mapa');
        return;
      }

      int? startMin, endMin;
      DateTime? dateStart, dateEnd;

      if (_hasCombined) {
        switch (_restrictionType) {
          case _RestrictionType.timeRange:
            if (_combinedStartTime == null || _combinedEndTime == null) {
              _showSnack('Escolha as horas de início e fim do intervalo');
              return;
            }
            startMin = _toMinutes(_combinedStartTime!);
            endMin = _toMinutes(_combinedEndTime!);

          case _RestrictionType.date:
            if (_combineDate == null) {
              _showSnack('Escolha uma data');
              return;
            }
            dateStart = _combineDate;
            if (_combinedHasTimeWindow) {
              if (_combinedStartTime == null || _combinedEndTime == null) {
                _showSnack('Escolha as horas de início e fim');
                return;
              }
              startMin = _toMinutes(_combinedStartTime!);
              endMin = _toMinutes(_combinedEndTime!);
            }

          case _RestrictionType.dateRange:
            if (_combineDate == null || _combineDateEnd == null) {
              _showSnack('Escolha as datas de início e fim');
              return;
            }
            dateStart = _combineDate;
            dateEnd = _combineDateEnd;
            if (_combinedHasTimeWindow) {
              if (_combinedStartTime == null || _combinedEndTime == null) {
                _showSnack('Escolha as horas de início e fim');
                return;
              }
              startMin = _toMinutes(_combinedStartTime!);
              endMin = _toMinutes(_combinedEndTime!);
            }
        }
      }

      locationAlert = LocationAlert(
        latitude: _locLat!,
        longitude: _locLng!,
        radiusMeters: _locRadius,
        locationName:
            _locNameCtrl.text.trim().isEmpty ? null : _locNameCtrl.text.trim(),
        triggered: false,
        timeWindowStartMinutes: startMin,
        timeWindowEndMinutes: endMin,
        dateRangeStart: dateStart,
        dateRangeEnd: dateEnd,
      );
    }

    final note = Note(
      id: widget.note?.id,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      isDone: widget.note?.isDone ?? false,
      createdAt: widget.note?.createdAt,
      timeAlert: timeAlert,
      locationAlert: locationAlert,
    );

    await HiveService.saveNote(note);

    if (timeAlert != null) {
      await NotificationService.scheduleTimeAlert(note);
    }

    if (locationAlert != null) {
      LocationService.instance.resetTrigger(note.id);
      await LocationService.instance.startMonitoring();
    }

    if (mounted) Navigator.pop(context, true);
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'Nova Nota' : 'Editar Nota'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
            tooltip: 'Guardar',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              style:
                  const TextStyle(color: AppTheme.textPrimary, fontSize: 17),
              decoration: const InputDecoration(
                labelText: 'Título *',
                prefixIcon: Icon(Icons.title, color: AppTheme.accent),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.notes, color: AppTheme.accent),
                ),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // ── Time Alert ────────────────────────────────────────────────
            _SectionToggle(
              icon: Icons.alarm,
              title: 'Aviso por Hora',
              enabled: _hasTimeAlert,
              onToggle: (v) => setState(() => _hasTimeAlert = v),
            ),
            if (_hasTimeAlert) ...[
              const SizedBox(height: 10),
              _TimeAlertPanel(
                alertDt: _alertDt,
                isRecurring: _isRecurring,
                recurringType: _recurringType,
                onPickDt: _pickDateTime,
                onToggleRecurring: (v) => setState(() => _isRecurring = v),
                onChangeRecurringType: (v) =>
                    setState(() => _recurringType = v!),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(color: AppTheme.cardBorder),
            const SizedBox(height: 16),

            // ── Location Alert ────────────────────────────────────────────
            _SectionToggle(
              icon: Icons.location_on,
              title: 'Aviso por Localização',
              enabled: _hasLocationAlert,
              onToggle: (v) => setState(() => _hasLocationAlert = v),
            ),
            if (_hasLocationAlert) ...[
              const SizedBox(height: 10),
              _LocationAlertPanel(
                locLat: _locLat,
                locLng: _locLng,
                locRadius: _locRadius,
                locNameCtrl: _locNameCtrl,
                hasCombined: _hasCombined,
                restrictionType: _restrictionType,
                combinedStartTime: _combinedStartTime,
                combinedEndTime: _combinedEndTime,
                combinedHasTimeWindow: _combinedHasTimeWindow,
                combineDate: _combineDate,
                combineDateEnd: _combineDateEnd,
                onPickLocation: _pickLocation,
                onToggleCombined: (v) => setState(() {
                  _hasCombined = v;
                  if (!v) {
                    _combineDate = null;
                    _combineDateEnd = null;
                    _combinedStartTime = null;
                    _combinedEndTime = null;
                    _combinedHasTimeWindow = false;
                  }
                }),
                onChangeRestrictionType: (t) =>
                    setState(() => _restrictionType = t),
                onPickStartTime: () => _pickCombinedTime(true),
                onPickEndTime: () => _pickCombinedTime(false),
                onToggleTimeWindow: (v) =>
                    setState(() => _combinedHasTimeWindow = v),
                onPickDate: () => _pickCombineDate(false),
                onPickDateEnd: () => _pickCombineDate(true),
              ),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  const _SectionToggle({
    required this.icon,
    required this.title,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = enabled ? AppTheme.accent : AppTheme.textSecondary;
    return Row(
      children: [
        Icon(icon, color: c, size: 22),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                color: c, fontSize: 16, fontWeight: FontWeight.w600)),
        const Spacer(),
        Switch(value: enabled, onChanged: onToggle),
      ],
    );
  }
}

class _TimeAlertPanel extends StatelessWidget {
  final DateTime? alertDt;
  final bool isRecurring;
  final String recurringType;
  final VoidCallback onPickDt;
  final ValueChanged<bool> onToggleRecurring;
  final ValueChanged<String?> onChangeRecurringType;

  const _TimeAlertPanel({
    required this.alertDt,
    required this.isRecurring,
    required this.recurringType,
    required this.onPickDt,
    required this.onToggleRecurring,
    required this.onChangeRecurringType,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Recorrente',
                style: TextStyle(color: AppTheme.textPrimary)),
            value: isRecurring,
            onChanged: onToggleRecurring,
          ),
          if (isRecurring) ...[
            const SizedBox(height: 8),
            _RecurringDropdown(
                value: recurringType, onChanged: onChangeRecurringType),
          ],
          const SizedBox(height: 10),
          _DateTimeButton(dt: alertDt, onTap: onPickDt),
        ],
      ),
    );
  }
}

class _LocationAlertPanel extends StatelessWidget {
  final double? locLat;
  final double? locLng;
  final double locRadius;
  final TextEditingController locNameCtrl;
  final bool hasCombined;
  final _RestrictionType restrictionType;
  final TimeOfDay? combinedStartTime;
  final TimeOfDay? combinedEndTime;
  final bool combinedHasTimeWindow;
  final DateTime? combineDate;
  final DateTime? combineDateEnd;
  final VoidCallback onPickLocation;
  final ValueChanged<bool> onToggleCombined;
  final ValueChanged<_RestrictionType> onChangeRestrictionType;
  final VoidCallback onPickStartTime;
  final VoidCallback onPickEndTime;
  final ValueChanged<bool> onToggleTimeWindow;
  final VoidCallback onPickDate;
  final VoidCallback onPickDateEnd;

  const _LocationAlertPanel({
    required this.locLat,
    required this.locLng,
    required this.locRadius,
    required this.locNameCtrl,
    required this.hasCombined,
    required this.restrictionType,
    required this.combinedStartTime,
    required this.combinedEndTime,
    required this.combinedHasTimeWindow,
    required this.combineDate,
    required this.combineDateEnd,
    required this.onPickLocation,
    required this.onToggleCombined,
    required this.onChangeRestrictionType,
    required this.onPickStartTime,
    required this.onPickEndTime,
    required this.onToggleTimeWindow,
    required this.onPickDate,
    required this.onPickDateEnd,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: locNameCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Nome do local (opcional)',
              prefixIcon: Icon(Icons.place, color: AppTheme.accent),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    locLat != null ? const Color(0x1AC8F060) : AppTheme.accent,
                foregroundColor:
                    locLat != null ? AppTheme.accent : AppTheme.background,
                side: locLat != null
                    ? const BorderSide(color: AppTheme.accent)
                    : BorderSide.none,
              ),
              icon: const Icon(Icons.map),
              label: Text(locLat != null
                  ? 'Alterar ponto no mapa'
                  : 'Escolher ponto no mapa'),
              onPressed: onPickLocation,
            ),
          ),
          if (locLat != null) ...[
            const SizedBox(height: 8),
            _LocationInfo(lat: locLat!, lng: locLng!, radius: locRadius),
            const SizedBox(height: 10),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Combinar com hora / data',
                  style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: const Text(
                'Avisar só dentro de um intervalo de horas ou datas',
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              value: hasCombined,
              onChanged: onToggleCombined,
            ),
            if (hasCombined) ...[
              const SizedBox(height: 4),
              // ── Restriction type selector ───────────────────────────────
              SegmentedButton<_RestrictionType>(
                style: SegmentedButton.styleFrom(
                  backgroundColor: AppTheme.background,
                  selectedBackgroundColor: const Color(0x1AC8F060),
                  selectedForegroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.cardBorder),
                ),
                segments: const [
                  ButtonSegment(
                    value: _RestrictionType.timeRange,
                    label: Text('Horas'),
                    icon: Icon(Icons.schedule, size: 16),
                  ),
                  ButtonSegment(
                    value: _RestrictionType.date,
                    label: Text('Data'),
                    icon: Icon(Icons.today, size: 16),
                  ),
                  ButtonSegment(
                    value: _RestrictionType.dateRange,
                    label: Text('Período'),
                    icon: Icon(Icons.date_range, size: 16),
                  ),
                ],
                selected: {restrictionType},
                onSelectionChanged: (s) => onChangeRestrictionType(s.first),
              ),
              const SizedBox(height: 12),

              // ── Content per type ─────────────────────────────────────────
              if (restrictionType == _RestrictionType.timeRange) ...[
                _TimeRangePicker(
                  startTime: combinedStartTime,
                  endTime: combinedEndTime,
                  onPickStart: onPickStartTime,
                  onPickEnd: onPickEndTime,
                ),
              ],

              if (restrictionType == _RestrictionType.date) ...[
                _DateButton(
                  label: 'Data',
                  date: combineDate,
                  onTap: onPickDate,
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Também restringir por hora',
                      style: TextStyle(
                          color: AppTheme.textPrimary, fontSize: 14)),
                  value: combinedHasTimeWindow,
                  onChanged: onToggleTimeWindow,
                ),
                if (combinedHasTimeWindow) ...[
                  const SizedBox(height: 6),
                  _TimeRangePicker(
                    startTime: combinedStartTime,
                    endTime: combinedEndTime,
                    onPickStart: onPickStartTime,
                    onPickEnd: onPickEndTime,
                  ),
                ],
              ],

              if (restrictionType == _RestrictionType.dateRange) ...[
                Row(
                  children: [
                    Expanded(
                      child: _DateButton(
                        label: 'Início',
                        date: combineDate,
                        onTap: onPickDate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateButton(
                        label: 'Fim',
                        date: combineDateEnd,
                        onTap: onPickDateEnd,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Também restringir por hora',
                      style: TextStyle(
                          color: AppTheme.textPrimary, fontSize: 14)),
                  value: combinedHasTimeWindow,
                  onChanged: onToggleTimeWindow,
                ),
                if (combinedHasTimeWindow) ...[
                  const SizedBox(height: 6),
                  _TimeRangePicker(
                    startTime: combinedStartTime,
                    endTime: combinedEndTime,
                    onPickStart: onPickStartTime,
                    onPickEnd: onPickEndTime,
                  ),
                ],
              ],

              // ── Summary chip ─────────────────────────────────────────────
              const SizedBox(height: 10),
              _RestrictionSummary(
                restrictionType: restrictionType,
                startTime: combinedStartTime,
                endTime: combinedEndTime,
                combineDate: combineDate,
                combineDateEnd: combineDateEnd,
                hasTimeWindow: combinedHasTimeWindow,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Leaf widgets ──────────────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: child,
    );
  }
}

class _LocationInfo extends StatelessWidget {
  final double lat, lng, radius;
  const _LocationInfo(
      {required this.lat, required this.lng, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0x1AC8F060),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppTheme.accent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
              '\nRaio: ${radius.toInt()} m',
              style: const TextStyle(color: AppTheme.accent, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeRangePicker extends StatelessWidget {
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _TimeRangePicker({
    required this.startTime,
    required this.endTime,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TimeButton(
              label: 'Início', time: startTime, onTap: onPickStart),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              _TimeButton(label: 'Fim', time: endTime, onTap: onPickEnd),
        ),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final VoidCallback onTap;

  const _TimeButton(
      {required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasTime = time != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: hasTime ? AppTheme.accent : AppTheme.cardBorder),
          color: hasTime ? const Color(0x1AC8F060) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time,
                    color:
                        hasTime ? AppTheme.accent : AppTheme.textSecondary,
                    size: 15),
                const SizedBox(width: 6),
                Text(
                  hasTime
                      ? '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}'
                      : '--:--',
                  style: TextStyle(
                    color: hasTime
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateButton(
      {required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: hasDate ? AppTheme.accent : AppTheme.cardBorder),
          color: hasDate ? const Color(0x1AC8F060) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    color:
                        hasDate ? AppTheme.accent : AppTheme.textSecondary,
                    size: 15),
                const SizedBox(width: 6),
                Text(
                  hasDate
                      ? DateFormat('dd/MM/yyyy').format(date!)
                      : '-- / -- / ----',
                  style: TextStyle(
                    color: hasDate
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RestrictionSummary extends StatelessWidget {
  final _RestrictionType restrictionType;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final DateTime? combineDate;
  final DateTime? combineDateEnd;
  final bool hasTimeWindow;

  const _RestrictionSummary({
    required this.restrictionType,
    required this.startTime,
    required this.endTime,
    required this.combineDate,
    required this.combineDateEnd,
    required this.hasTimeWindow,
  });

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  bool get _overnight =>
      startTime != null &&
      endTime != null &&
      (startTime!.hour * 60 + startTime!.minute) >
          (endTime!.hour * 60 + endTime!.minute);

  @override
  Widget build(BuildContext context) {
    String? summary;

    switch (restrictionType) {
      case _RestrictionType.timeRange:
        if (startTime != null && endTime != null) {
          summary =
              'Avisar entre ${_fmtTime(startTime!)} e ${_fmtTime(endTime!)}${_overnight ? ' (passa meia-noite)' : ''}';
        }
      case _RestrictionType.date:
        if (combineDate != null) {
          final timePart = hasTimeWindow &&
                  startTime != null &&
                  endTime != null
              ? ', entre ${_fmtTime(startTime!)} e ${_fmtTime(endTime!)}'
              : '';
          summary = 'Avisar em ${_fmtDate(combineDate!)}$timePart';
        }
      case _RestrictionType.dateRange:
        if (combineDate != null && combineDateEnd != null) {
          final timePart = hasTimeWindow &&
                  startTime != null &&
                  endTime != null
              ? ', entre ${_fmtTime(startTime!)} e ${_fmtTime(endTime!)}'
              : '';
          summary =
              'Avisar de ${_fmtDate(combineDate!)} a ${_fmtDate(combineDateEnd!)}$timePart';
        }
    }

    if (summary == null) return const SizedBox.shrink();

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x1AC8F060),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: AppTheme.accent, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              summary,
              style: const TextStyle(
                  color: AppTheme.accent, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecurringDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const _RecurringDropdown(
      {required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: AppTheme.surface,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: const InputDecoration(
        labelText: 'Frequência',
        contentPadding:
            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: const [
        DropdownMenuItem(value: 'daily', child: Text('Diário')),
        DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
        DropdownMenuItem(value: 'monthly', child: Text('Mensal')),
      ],
      onChanged: onChanged,
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  final DateTime? dt;
  final VoidCallback onTap;

  const _DateTimeButton({required this.dt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                color: AppTheme.accent, size: 18),
            const SizedBox(width: 8),
            Text(
              dt != null
                  ? DateFormat('dd/MM/yyyy HH:mm').format(dt!)
                  : 'Escolher data e hora',
              style: TextStyle(
                color: dt != null
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
