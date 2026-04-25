import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api.dart';
import '../theme.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  const CreateAnnouncementScreen({super.key});
  @override
  State<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _title = TextEditingController();
  final _body  = TextEditingController();
  final _location = TextEditingController();
  String _kind = 'general';
  String _scope = 'masjid';
  int? _masjidId;
  DateTime? _eventAt;
  bool _busy = false;
  List<Masjid> _masjids = [];
  bool _amSuper = false;

  static const _kinds = {
    'general':         ('Announcement',   Icons.campaign,         'General notice'),
    'eid':             ('Eid prayer',     Icons.celebration,      'Eid timing — needs verification, shows 2 days before'),
    'janaza':          ('Janaza',         Icons.priority_high,    'Funeral prayer — urgent, immediately visible'),
    'special_prayer':  ('Special prayer', Icons.mosque,           'Taraweeh, qiyam etc. — needs verification'),
  };

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final results = await Future.wait([
        Api.listMasjids(page: 0, size: 200),
        Api.me(),
      ]);
      if (!mounted) return;
      final me = results[1] as Map<String, dynamic>?;
      setState(() {
        _masjids = (results[0] as MasjidPage).items;
        _amSuper = me != null && me['is_super_admin'] == true;
      });
    } catch (_) {}
  }

  Future<void> _pickEventDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() => _eventAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and body are required')));
      return;
    }
    if (_masjidId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick the masjid this is from')));
      return;
    }
    if ((_kind == 'eid' || _kind == 'special_prayer') && _eventAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eid / special prayer needs an event time')));
      return;
    }

    setState(() => _busy = true);
    try {
      await Api.announcementCreate({
        'masjid_id': _masjidId,
        'title': _title.text.trim(),
        'body':  _body.text.trim(),
        'kind':  _kind,
        'scope': _scope,
        if (_eventAt != null)
          'event_at': _eventAt!.toIso8601String().substring(0, 19),
        if (_location.text.trim().isNotEmpty)
          'location_text': _location.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement posted')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsEvent = _kind == 'eid' || _kind == 'special_prayer' || _kind == 'janaza';
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('New Announcement'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _submit,
            child: Text('POST',
              style: GoogleFonts.inter(color: AppTheme.gold, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Kind picker
          _label('TYPE'),
          ..._kinds.entries.map((e) {
            final sel = _kind == e.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _kind = e.key),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: sel ? AppTheme.surfaceAlt : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: sel ? AppTheme.gold : AppTheme.line),
                    ),
                    child: Row(children: [
                      Icon(e.value.$2, color: sel ? AppTheme.gold : AppTheme.textMid),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.value.$1,
                            style: GoogleFonts.inter(
                              color: sel ? AppTheme.cream : AppTheme.textMid,
                              fontSize: 14, fontWeight: FontWeight.w700)),
                          Text(e.value.$3,
                            style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11)),
                        ],
                      )),
                      if (sel) const Icon(Icons.check_circle, color: AppTheme.gold, size: 18),
                    ]),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 14),

          // Scope
          _label('VISIBLE TO'),
          Row(children: [
            Expanded(child: ChoiceChip(
              label: const Text('This masjid only'),
              selected: _scope == 'masjid',
              onSelected: (_) => setState(() => _scope = 'masjid'),
              selectedColor: AppTheme.emerald,
              labelStyle: TextStyle(color: _scope == 'masjid' ? AppTheme.cream : AppTheme.textMid),
            )),
            const SizedBox(width: 8),
            Expanded(child: ChoiceChip(
              label: const Text('All Nellore'),
              selected: _scope == 'city',
              onSelected: _amSuper ? (_) => setState(() => _scope = 'city') : null,
              selectedColor: AppTheme.gold,
              labelStyle: TextStyle(
                color: _scope == 'city' ? AppTheme.bg : AppTheme.textMid),
            )),
          ]),
          if (!_amSuper)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('City-wide requires super admin',
                style: GoogleFonts.inter(color: AppTheme.textLo, fontSize: 11)),
            ),
          const SizedBox(height: 14),

          // From masjid
          _label('FROM MASJID'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.line),
            ),
            child: DropdownButtonFormField<int>(
              value: _masjidId,
              isExpanded: true,
              items: _masjids.map((m) => DropdownMenuItem(
                value: m.id,
                child: Text('${m.name} · ${m.area}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.cream)),
              )).toList(),
              onChanged: (v) => setState(() => _masjidId = v),
              dropdownColor: AppTheme.surface,
              decoration: const InputDecoration(
                hintText: 'Pick masjid', border: InputBorder.none),
            ),
          ),
          const SizedBox(height: 14),

          // Title
          _label('TITLE'),
          TextField(
            controller: _title,
            decoration: const InputDecoration(hintText: 'e.g. Janaza for Br. Ahmed'),
          ),
          const SizedBox(height: 14),

          // Body
          _label('DETAILS'),
          TextField(
            controller: _body, maxLines: 4,
            decoration: const InputDecoration(hintText: 'Full announcement text...'),
          ),
          const SizedBox(height: 14),

          // Event date
          if (needsEvent) ...[
            _label(_kind == 'janaza' ? 'JANAZA TIME' : 'EVENT TIME'),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickEventDateTime,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.line),
                ),
                child: Row(children: [
                  const Icon(Icons.event, color: AppTheme.gold),
                  const SizedBox(width: 10),
                  Text(
                    _eventAt == null ? 'Tap to pick date and time' :
                      '${_eventAt!.toLocal().toString().substring(0, 16)}',
                    style: GoogleFonts.inter(
                      color: _eventAt == null ? AppTheme.textLo : AppTheme.cream,
                      fontSize: 14, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            const SizedBox(height: 14),

            _label('LOCATION (OPTIONAL)'),
            TextField(
              controller: _location,
              decoration: const InputDecoration(
                hintText: 'e.g. Kalan Masjid, Nellore',
                prefixIcon: Icon(Icons.place_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 14),
          ],

          if (_kind == 'eid' || _kind == 'special_prayer')
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.gold.withOpacity(0.5)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, color: AppTheme.gold, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This will go live 2 days before the event time, '
                    'and only after a super admin verifies it.',
                    style: GoogleFonts.inter(color: AppTheme.gold, fontSize: 11.5, height: 1.3))),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _label(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 4),
    child: Text(s,
      style: GoogleFonts.inter(
        color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
  );
}
