import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/checklist_item.dart';
import '../models/flight_log.dart';
import '../models/flight_plan.dart';
import '../models/hira_row.dart';
import '../models/mission.dart';
import '../services/org_settings_service.dart';

/// Generates DUAS Operations Manual Annex A forms (A-1 through A-11) as PDFs.
/// Each static method accepts pre-loaded model data and returns [Uint8List] bytes
/// ready for sharing/saving via [Printing.sharePdf].
class PdfGeneratorService {
  // ── Brand palette ────────────────────────────────────────────────────────────
  static final _navy      = PdfColor.fromHex('#0B1A3D');
  static final _blue      = PdfColor.fromHex('#1E3A6E');
  static final _accent    = PdfColor.fromHex('#2563EB');
  static final _success   = PdfColor.fromHex('#16A34A');
  static final _danger    = PdfColor.fromHex('#DC2626');
  static final _warning   = PdfColor.fromHex('#D97706');
  static final _border    = PdfColor.fromHex('#CBD5E1');
  static final _txtDark   = PdfColor.fromHex('#0F172A');
  static final _txtMuted  = PdfColor.fromHex('#64748B');
  static final _rowAlt    = PdfColor.fromHex('#F8FAFC');
  static final _rowHdr    = PdfColor.fromHex('#EEF2FF');

  // ── Crew helpers ─────────────────────────────────────────────────────────────

  static String _roleNames(Mission m, String role) =>
      m.crew.where((c) => c.role == role).map((c) => c.name).join(', ');

  static String _rpic(Mission m) {
    final names = _roleNames(m, 'rpic');
    if (names.isNotEmpty) return names;
    return m.crew.isEmpty ? '—' : m.crew.first.name;
  }

  // ── Page header ──────────────────────────────────────────────────────────────

  static pw.Widget _pageHeader(
      OrgSettings org, String formRef, String formTitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(org.orgName,
                style: pw.TextStyle(fontSize: 8, color: _txtMuted)),
            pw.Text(formRef,
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _blue)),
            pw.Text('Rev. 2.0  ·  CAAP SARPs',
                style: pw.TextStyle(fontSize: 8, color: _txtMuted)),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 9, horizontal: 14),
          decoration: pw.BoxDecoration(
            color: _navy,
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(5)),
          ),
          child: pw.Center(
            child: pw.Text(
              formTitle,
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white),
            ),
          ),
        ),
        pw.SizedBox(height: 14),
      ],
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────

  static pw.Widget _section(String title) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 12, bottom: 5),
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: pw.BoxDecoration(
          color: _rowHdr,
          borderRadius:
              const pw.BorderRadius.all(pw.Radius.circular(3)),
          border: pw.Border(
              left: pw.BorderSide(color: _accent, width: 3)),
        ),
        child: pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _blue,
              letterSpacing: 0.8),
        ),
      );

  // ── Info row (label: value) ───────────────────────────────────────────────

  static pw.Widget _info(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 120,
              child: pw.Text('$label:',
                  style: pw.TextStyle(fontSize: 9, color: _txtMuted)),
            ),
            pw.Expanded(
              child: pw.Text(
                value.isEmpty ? '—' : value,
                style: pw.TextStyle(fontSize: 9, color: _txtDark),
              ),
            ),
          ],
        ),
      );

  // ── Text block ───────────────────────────────────────────────────────────

  static pw.Widget _textBlock(String text) => pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.symmetric(vertical: 3),
        padding: const pw.EdgeInsets.all(9),
        decoration: pw.BoxDecoration(
          color: _rowAlt,
          border: pw.Border.all(color: _border, width: 0.5),
          borderRadius:
              const pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
        child: pw.Text(
          text.trim().isEmpty ? '—' : text.trim(),
          style: pw.TextStyle(fontSize: 9, color: _txtDark, lineSpacing: 2),
        ),
      );

  // ── Signature block ──────────────────────────────────────────────────────

  static pw.Widget _sigBlock(List<String> roles) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 18),
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _border),
          borderRadius:
              const pw.BorderRadius.all(pw.Radius.circular(4))),
      child: pw.Row(
        children: List.generate(roles.length, (i) {
          final isLast = i == roles.length - 1;
          return pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: isLast
                  ? null
                  : pw.BoxDecoration(
                      border: pw.Border(
                          right: pw.BorderSide(color: _border))),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(roles[i],
                      style:
                          pw.TextStyle(fontSize: 8, color: _txtMuted)),
                  pw.SizedBox(height: 22),
                  pw.Container(height: 0.5, color: _txtMuted),
                  pw.SizedBox(height: 3),
                  pw.Text('Print Name / Signature / Date',
                      style:
                          pw.TextStyle(fontSize: 7, color: _txtMuted)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Page footer ──────────────────────────────────────────────────────────

  static pw.Widget _footer(pw.Context ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('DUAS Fleet Management System',
                style: pw.TextStyle(fontSize: 7, color: _txtMuted)),
            pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 7, color: _txtMuted)),
            pw.Text('CAAP SARPs / ICAO Annex 2',
                style: pw.TextStyle(fontSize: 7, color: _txtMuted)),
          ],
        ),
      );

  // ── Status badge (for checklist tables) ─────────────────────────────────

  static pw.Widget _statusBadge(int status) {
    final label = status == 1 ? 'PASS' : status == 2 ? 'FAIL' : 'N/A';
    final color = status == 1 ? _success : status == 2 ? _danger : _txtMuted;
    return pw.Center(
      child: pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius:
              const pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
        child: pw.Text(
          label,
          style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white),
        ),
      ),
    );
  }

  // ── Checklist table (shared by A-3, A-5, A-6, A-7) ─────────────────────

  static pw.Widget _checklistTable(List<ChecklistItem> items) {
    if (items.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(10),
        child: pw.Text('No checklist data recorded.',
            style: pw.TextStyle(fontSize: 9, color: _txtMuted)),
      );
    }

    // Group items by section (preserving insertion order)
    final sections = <String, List<ChecklistItem>>{};
    for (final item in items) {
      sections.putIfAbsent(item.section, () => []).add(item);
    }

    // Build rows
    final rows = <pw.Widget>[];

    // Header row
    rows.add(pw.Container(
      decoration: pw.BoxDecoration(color: _navy),
      child: pw.Row(children: [
        pw.Expanded(
          flex: 6,
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text('CHECKLIST ITEM',
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
          ),
        ),
        pw.SizedBox(
          width: 50,
          child: pw.Center(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('STATUS',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
            ),
          ),
        ),
        pw.Expanded(
          flex: 3,
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text('REMARKS',
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
          ),
        ),
      ]),
    ));

    int rowIdx = 0;
    for (final entry in sections.entries) {
      // Section sub-header
      rows.add(pw.Container(
        decoration: pw.BoxDecoration(color: _rowHdr),
        padding: const pw.EdgeInsets.symmetric(
            horizontal: 8, vertical: 4),
        child: pw.Text(
          entry.key,
          style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _blue),
        ),
      ));

      for (final item in entry.value) {
        final bg = rowIdx.isEven ? PdfColors.white : _rowAlt;
        rows.add(pw.Container(
          decoration: pw.BoxDecoration(
            color: bg,
            border: pw.Border(
                bottom: pw.BorderSide(color: _border, width: 0.5)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                flex: 6,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 5),
                  child: pw.Text(item.itemText,
                      style: pw.TextStyle(
                          fontSize: 8.5, color: _txtDark)),
                ),
              ),
              pw.SizedBox(
                width: 50,
                child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 5),
                    child: _statusBadge(item.status)),
              ),
              pw.Expanded(
                flex: 3,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 5),
                  child: pw.Text(
                    item.remark.isEmpty ? '' : item.remark,
                    style: pw.TextStyle(
                        fontSize: 8, color: _txtMuted),
                  ),
                ),
              ),
            ],
          ),
        ));
        rowIdx++;
      }
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 0.5),
        borderRadius:
            const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 3,
        verticalRadius: 3,
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: rows),
      ),
    );
  }

  // ── Risk legend ──────────────────────────────────────────────────────────

  static pw.Widget _riskLegend() => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Row(children: [
          pw.Text('Risk Score:  ',
              style: pw.TextStyle(fontSize: 8, color: _txtMuted)),
          _legendBadge('LOW  1–4', _success),
          pw.SizedBox(width: 6),
          _legendBadge('MEDIUM  5–8', _warning),
          pw.SizedBox(width: 6),
          _legendBadge('HIGH  9–25', _danger),
        ]),
      );

  static pw.Widget _legendBadge(String label, PdfColor color) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(
            horizontal: 7, vertical: 3),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius:
              const pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
        child: pw.Text(label,
            style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white)),
      );

  // ══════════════════════════════════════════════════════════════════════════
  //  FORM A-1 — FLIGHT PLAN RECORD
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> generateFlightPlan(
    Mission mission,
    FlightPlan? fp,
    List<HiraRow> hiraRows,
    OrgSettings org,
  ) async {
    final doc = pw.Document();

    // Overall risk from HIRA
    int maxRisk = 0;
    for (final r in hiraRows) {
      if (r.risk > maxRisk) maxRisk = r.risk;
    }
    final riskLabel =
        maxRisk == 0 ? 'NOT ASSESSED'
        : maxRisk <= 4 ? 'LOW'
        : maxRisk <= 8 ? 'MEDIUM'
        : 'HIGH';
    final riskColor = maxRisk == 0
        ? _txtMuted
        : maxRisk <= 4
            ? _success
            : maxRisk <= 8
                ? _warning
                : _danger;

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      footer: _footer,
      build: (ctx) => [
        _pageHeader(org, 'ANNEX A-1', 'FLIGHT PLAN RECORD'),

        _section('Mission Information'),
        _info('Mission ID', mission.missionId),
        _info('Mission Title', mission.title),
        _info('Date / Time',
            '${mission.date}   ${mission.timeStr}'),
        _info('Location', mission.location),
        if (mission.latitude != null && mission.longitude != null)
          _info('Coordinates',
              '${mission.latitude!.toStringAsFixed(6)}°N,  ${mission.longitude!.toStringAsFixed(6)}°E'),
        _info('Environment', mission.environment),
        pw.SizedBox(height: 5),
        pw.Text('Mission Objective:',
            style: pw.TextStyle(fontSize: 9, color: _txtMuted)),
        pw.SizedBox(height: 2),
        _textBlock(mission.objective),

        _section('Aircraft & Crew'),
        _info('Platform', mission.aircraftName),
        _info('Type',
            mission.aircraftType == 'vtol' ? 'VTOL Fixed-Wing' : 'Multi-rotor'),
        _info('RPIC', _rpic(mission)),
        if (_roleNames(mission, 'vo').isNotEmpty)
          _info('Visual Observer (VO)', _roleNames(mission, 'vo')),
        if (_roleNames(mission, 'tech').isNotEmpty)
          _info('Technical Crew', _roleNames(mission, 'tech')),

        if (fp != null) ...[
          _section('Operational Parameters'),
          _info('Area of Operation', fp.areaOfOperation),
          _info('Wind Speed',
              fp.windSpeed != null ? '${fp.windSpeed!.toStringAsFixed(1)} m/s' : '—'),
          _info('Visibility',
              fp.visibility != null ? '${fp.visibility!.toStringAsFixed(1)} km' : '—'),
          _info('Weather Forecast', fp.weatherForecast),
          _info('Airspace Class', fp.airspaceClass),
          _info('NOTAMs', fp.notams),
          _info('Airspace Restrictions', fp.airspaceRestrictions),
          pw.SizedBox(height: 5),
          pw.Text('Contingency Plan:',
              style: pw.TextStyle(fontSize: 9, color: _txtMuted)),
          pw.SizedBox(height: 2),
          _textBlock(fp.contingencyPlan),
        ],

        _section('Risk Summary'),
        pw.Row(children: [
          pw.Text('Overall Risk Level: ',
              style: pw.TextStyle(fontSize: 9, color: _txtMuted)),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 10, vertical: 3),
            decoration: pw.BoxDecoration(
              color: riskColor,
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(riskLabel,
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
          ),
          if (hiraRows.isNotEmpty) ...[
            pw.SizedBox(width: 10),
            pw.Text('${hiraRows.length} hazard(s) identified',
                style: pw.TextStyle(fontSize: 9, color: _txtMuted)),
          ],
        ]),
        if (mission.crpAdvisoryNotes.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#FFFBEB'),
              border: pw.Border.all(color: _warning),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('CRP ADVISORY NOTES',
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: _warning)),
                  pw.SizedBox(height: 4),
                  pw.Text(mission.crpAdvisoryNotes,
                      style: pw.TextStyle(
                          fontSize: 9,
                          color: _txtDark,
                          lineSpacing: 2)),
                ]),
          ),
        ],

        _sigBlock(['RPIC', 'Chief Remote Pilot (CRP) / Safety Officer']),
      ],
    ));
    return doc.save();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FORM A-2 — HIRA
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> generateHira(
    Mission mission,
    List<HiraRow> rows,
    OrgSettings org,
  ) async {
    final doc = pw.Document();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      footer: _footer,
      build: (ctx) => [
        _pageHeader(org, 'ANNEX A-2',
            'HAZARD IDENTIFICATION & RISK ASSESSMENT (HIRA)'),

        _section('Mission & Platform Information'),
        _info('Mission ID', mission.missionId),
        _info('Platform', mission.aircraftName),
        _info('Location', mission.location),
        _info('Date', mission.date),
        _info('RPIC', _rpic(mission)),
        if (_roleNames(mission, 'vo').isNotEmpty)
          _info('Visual Observer', _roleNames(mission, 'vo')),
        if (_roleNames(mission, 'tech').isNotEmpty)
          _info('Technical Crew', _roleNames(mission, 'tech')),

        _section('Hazard Risk Assessment Matrix'),
        rows.isEmpty
            ? pw.Padding(
                padding: const pw.EdgeInsets.all(10),
                child: pw.Text('No HIRA data recorded.',
                    style: pw.TextStyle(
                        fontSize: 9, color: _txtMuted)))
            : _hiraTable(rows),
        _riskLegend(),

        _sigBlock(['RPIC', 'CRP / Safety Officer']),
      ],
    ));
    return doc.save();
  }

  static pw.Widget _hiraTable(List<HiraRow> rows) {
    final headerRow = pw.Container(
      decoration: pw.BoxDecoration(color: _navy),
      child: pw.Row(children: [
        pw.Expanded(flex: 5,
            child: _th('HAZARD DESCRIPTION')),
        pw.SizedBox(width: 28, child: _th('L', center: true)),
        pw.SizedBox(width: 28, child: _th('I', center: true)),
        pw.SizedBox(width: 36, child: _th('RISK', center: true)),
        pw.SizedBox(width: 52, child: _th('CATEGORY', center: true)),
        pw.Expanded(flex: 5,
            child: _th('MITIGATION MEASURES')),
        pw.SizedBox(
            width: 48, child: _th('RESIDUAL', center: true)),
      ]),
    );

    final dataRows = rows.asMap().entries.map((e) {
      final row = e.value;
      final idx = e.key;
      final riskColor = row.risk <= 4
          ? _success
          : row.risk <= 8
              ? _warning
              : _danger;
      return pw.Container(
        decoration: pw.BoxDecoration(
          color: idx.isEven ? PdfColors.white : _rowAlt,
          border: pw.Border(
              bottom: pw.BorderSide(color: _border, width: 0.5)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
                flex: 5,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6, vertical: 5),
                  child: pw.Text(row.hazard,
                      style: pw.TextStyle(
                          fontSize: 8.5, color: _txtDark)),
                )),
            pw.SizedBox(
              width: 28,
              child: pw.Center(
                child: pw.Text('${row.likelihood}',
                    style: pw.TextStyle(
                        fontSize: 9, color: _txtDark)),
              ),
            ),
            pw.SizedBox(
              width: 28,
              child: pw.Center(
                child: pw.Text('${row.impact}',
                    style: pw.TextStyle(
                        fontSize: 9, color: _txtDark)),
              ),
            ),
            pw.SizedBox(
              width: 36,
              child: pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: riskColor,
                    borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(3)),
                  ),
                  child: pw.Text('${row.risk}',
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white)),
                ),
              ),
            ),
            pw.SizedBox(
              width: 52,
              child: pw.Center(
                child: pw.Text(row.riskCategory,
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: riskColor)),
              ),
            ),
            pw.Expanded(
                flex: 5,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6, vertical: 5),
                  child: pw.Text(row.mitigation,
                      style: pw.TextStyle(
                          fontSize: 8.5, color: _txtDark)),
                )),
            pw.SizedBox(
              width: 48,
              child: pw.Center(
                child: pw.Text('${row.residualRisk}',
                    style: pw.TextStyle(
                        fontSize: 9, color: _txtDark)),
              ),
            ),
          ],
        ),
      );
    }).toList();

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 0.5),
        borderRadius:
            const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 3,
        verticalRadius: 3,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [headerRow, ...dataRows],
        ),
      ),
    );
  }

  static pw.Widget _th(String text, {bool center = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(
            horizontal: 6, vertical: 6),
        child: pw.Text(
          text,
          textAlign:
              center ? pw.TextAlign.center : pw.TextAlign.left,
          style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white),
        ),
      );

  // ══════════════════════════════════════════════════════════════════════════
  //  FORM A-3 — EQUIPMENT HANDLING CHECKLIST
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> generateEquipmentChecklist(
    Mission mission,
    List<ChecklistItem> items,
    OrgSettings org,
  ) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      footer: _footer,
      build: (ctx) => [
        _pageHeader(
            org, 'ANNEX A-3', 'EQUIPMENT HANDLING CHECKLIST'),
        _section('Mission Information'),
        _info('Mission ID', mission.missionId),
        _info('Mission Title', mission.title),
        _info('Aircraft', mission.aircraftName),
        _info('Date', mission.date),
        _section('Equipment Checklist'),
        _checklistTable(items),
        _sigBlock(['Inspector / Technician']),
      ],
    ));
    return doc.save();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FORM A-4 — FIT-TO-FLY DECLARATION
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> generateFitToFly(
    Mission mission,
    Map<String, dynamic>? record,
    OrgSettings org,
  ) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      footer: _footer,
      build: (ctx) => [
        _pageHeader(org, 'ANNEX A-4', 'FIT-TO-FLY DECLARATION'),
        _section('Mission Information'),
        _info('Mission ID', mission.missionId),
        _info('Date', record?['record_date'] ?? mission.date),
        _info('Time', record?['record_time'] ?? mission.timeStr),
        _info('Location',
            record?['location'] ?? mission.location),
        _info('Mission Type', record?['mission_type'] ?? ''),
        _info('RPA Model',
            record?['rpa_model'] ?? mission.aircraftName),
        _info('Serial Number', record?['serial_number'] ?? ''),
        _info('Payload', record?['payload'] ?? ''),
        _info('PIC', record?['pic'] ?? _rpic(mission)),
        _section('Airworthiness Declaration'),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F0FDF4'),
            border: pw.Border.all(color: _success, width: 0.5),
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('AIRWORTHY — FIT FOR OPERATION',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _success)),
                pw.SizedBox(height: 5),
                pw.Text(
                  'All equipment handling checks have been completed '
                  'satisfactorily. The aircraft, payloads, GCS, and '
                  'communication systems have been inspected and are '
                  'declared airworthy and fit for the mission described above. '
                  'Pre-deployment (Annex A-3) and pre-flight (Annex A-5) '
                  'checklists have been completed.',
                  style: pw.TextStyle(
                      fontSize: 9,
                      color: _txtDark,
                      lineSpacing: 2),
                ),
              ]),
        ),
        _section('Inspection Categories'),
        _infoBox([
          'Li-Ion Battery handling and storage (voltage / cycle count verified)',
          'Propeller inspection (no chips, warping; torque confirmed)',
          'GCS & Radio calibration (RSSI ≥70%, RTH altitude set)',
          'UAS / RPAS airframe inspection (no cracks, motor/ESC check)',
          'Payload mounting and gimbal freedom of movement',
          'Communication link test (latency <100 ms, CSL encrypted)',
        ]),
        _sigBlock([
          'Released By (Maintenance Head)',
          'Accepted By (RPIC)',
        ]),
      ],
    ));
    return doc.save();
  }

  static pw.Widget _infoBox(List<String> items) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _border, width: 0.5),
          borderRadius:
              const pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: items
              .map((t) => pw.Padding(
                    padding:
                        const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                        crossAxisAlignment:
                            pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('• ',
                              style: pw.TextStyle(
                                  fontSize: 9, color: _accent)),
                          pw.Expanded(
                            child: pw.Text(t,
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    color: _txtDark,
                                    lineSpacing: 1)),
                          ),
                        ]),
                  ))
              .toList(),
        ),
      );

  // ══════════════════════════════════════════════════════════════════════════
  //  FORM A-5 — PRE-FLIGHT CHECKLIST
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> generatePreflightChecklist(
    Mission mission,
    List<ChecklistItem> items,
    OrgSettings org,
  ) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      footer: _footer,
      build: (ctx) => [
        _pageHeader(org, 'ANNEX A-5', 'PRE-FLIGHT CHECKLIST'),
        _section('Mission Information'),
        _info('Mission ID', mission.missionId),
        _info('Mission Title', mission.title),
        _info('Date / Time',
            '${mission.date}   ${mission.timeStr}'),
        _info('Location', mission.location),
        _info('Aircraft', mission.aircraftName),
        _info('RPIC', _rpic(mission)),
        if (_roleNames(mission, 'vo').isNotEmpty)
          _info('Visual Observer', _roleNames(mission, 'vo')),
        _section('Pre-Flight Checklist (Sections A–D)'),
        _checklistTable(items),
        _sigBlock(['RPIC', 'Visual Observer (VO)']),
      ],
    ));
    return doc.save();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FORM A-6 — IN-FLIGHT CHECKLIST
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> generateInflightChecklist(
    Mission mission,
    List<ChecklistItem> items,
    OrgSettings org,
  ) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      footer: _footer,
      build: (ctx) => [
        _pageHeader(org, 'ANNEX A-6', 'IN-FLIGHT CHECKLIST'),
        _section('Mission Information'),
        _info('Mission ID', mission.missionId),
        _info('Mission Title', mission.title),
        _info('Date / Time',
            '${mission.date}   ${mission.timeStr}'),
        _info('Location', mission.location),
        _info('Aircraft', mission.aircraftName),
        _info('RPIC', _rpic(mission)),
        if (_roleNames(mission, 'vo').isNotEmpty)
          _info('Visual Observer', _roleNames(mission, 'vo')),
        _section(
            'In-Flight Checklist (Launch / En Route / Contingency)'),
        _checklistTable(items),
        _sigBlock([
          'RPIC',
          'Visual Observer (VO) / Time: ___________',
        ]),
      ],
    ));
    return doc.save();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FORM A-7 — POST-FLIGHT CHECKLIST
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> generatePostflightChecklist(
    Mission mission,
    List<ChecklistItem> items,
    OrgSettings org,
  ) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      footer: _footer,
      build: (ctx) => [
        _pageHeader(org, 'ANNEX A-7', 'POST-FLIGHT CHECKLIST'),
        _section('Mission Information'),
        _info('Mission ID', mission.missionId),
        _info('Mission Title', mission.title),
        _info('Date / Time',
            '${mission.date}   ${mission.timeStr}'),
        _info('Location', mission.location),
        _info('Aircraft', mission.aircraftName),
        _info('RPIC', _rpic(mission)),
        if (_roleNames(mission, 'vo').isNotEmpty)
          _info('Visual Observer', _roleNames(mission, 'vo')),
        _section(
            'Post-Flight Checklist (Aircraft / Documentation / Maintenance)'),
        _checklistTable(items),
        _sigBlock([
          'RPIC',
          'Visual Observer / Technical Personnel',
        ]),
      ],
    ));
    return doc.save();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FORM A-8 — FLIGHT LOG
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> generateFlightLog(
    Mission mission,
    FlightLog? log,
    OrgSettings org,
  ) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      footer: _footer,
      build: (ctx) => [
        _pageHeader(org, 'ANNEX A-8', 'FLIGHT LOG'),
        if (log == null) ...[
          pw.Padding(
            padding: const pw.EdgeInsets.all(14),
            child: pw.Text(
                'No flight log data recorded for this mission.',
                style:
                    pw.TextStyle(fontSize: 10, color: _txtMuted)),
          ),
        ] else ...[
          _section('Mission & Flight Information'),
          _info('Mission ID', mission.missionId),
          _info('Mission Title', mission.title),
          _info('Date / Time', log.dateTime),
          _info('Location', log.location),
          if (log.latitude != null && log.longitude != null)
            _info('Coordinates',
                '${log.latitude!.toStringAsFixed(6)}°N,  ${log.longitude!.toStringAsFixed(6)}°E'),
          _info('AGL Altitude',
              log.altitudeAgl != null ? '${log.altitudeAgl!.toStringAsFixed(1)} m AGL' : '—'),
          _info('Highest Point',
              log.highestPoint != null ? '${log.highestPoint!.toStringAsFixed(1)} m' : '—'),
          _info('Landing Zone', log.landingZone),

          _section('Platform & Crew'),
          _info('Platform Type',
              log.platformType == 'vtol' ? 'VTOL Fixed-Wing' : 'Multi-rotor'),
          _info('Model', log.model),
          _info('MTOW',
              log.mtow != null ? '${log.mtow!.toStringAsFixed(2)} kg' : '—'),
          if (log.payload.isNotEmpty)
            _info('Payload', log.payload.join(', ')),
          _info('Mission Type', log.missionType),
          _info('RPIC', log.rpic),
          if (log.vo.isNotEmpty) _info('Visual Observer', log.vo),
          if (log.tech.isNotEmpty)
            _info('Technical Crew', log.tech),

          if (log.flights.isNotEmpty) ...[
            _section('Flight Durations'),
            _flightDurTable(log.flights),
            pw.SizedBox(height: 5),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(
                color: _rowHdr,
                borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(3)),
              ),
              child: pw.Row(children: [
                pw.Text('Total Flight Time:  ',
                    style: pw.TextStyle(
                        fontSize: 9, color: _txtMuted)),
                pw.Text(
                  '${log.totalFlightMinutes} min'
                  '  (${(log.totalFlightMinutes / 60.0).toStringAsFixed(1)} hrs)',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _txtDark),
                ),
              ]),
            ),
          ],

          _section('Weather & Environment'),
          _info('Wind Speed',
              log.weatherWind != null ? '${log.weatherWind!.toStringAsFixed(1)} m/s' : '—'),
          _info('Visibility',
              log.weatherVisibility != null ? '${log.weatherVisibility!.toStringAsFixed(1)} km' : '—'),
          _info('Cloud Cover', log.weatherCloud),
          _info('NOTAMs', log.notams),

          _section('Data Captured'),
          _info('GeoTIFF Coverage',
              log.dataCapturedGeotiff != null ? '${log.dataCapturedGeotiff} ha' : '—'),
          _info('Photos',
              log.dataCapturedPhotos ?? '—'),
          _info('Video Clips',
              log.dataCapturedVideo != null ? log.dataCapturedVideo! : '—'),
          _info('LiDAR Data',
              log.dataCapturedLidar ? 'Yes — LiDAR payload active' : 'No'),

          if (log.anomalies
              .any((a) => a.isNotEmpty && a != 'None')) ...[
            _section('Anomalies & Observations'),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#FFFBEB'),
                border:
                    pw.Border.all(color: _warning, width: 0.5),
                borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(3)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: log.anomalies
                    .where(
                        (a) => a.isNotEmpty && a != 'None')
                    .map((a) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              vertical: 2),
                          child: pw.Text('• $a',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  color: _txtDark,
                                  lineSpacing: 1)),
                        ))
                    .toList(),
              ),
            ),
          ],

          _section('Maintenance Notes'),
          _info('Next Scheduled Maintenance',
              log.nextMaintenance),

          _sigBlock([
            'RPIC',
            'CRP / Safety Officer',
          ]),
        ],
      ],
    ));
    return doc.save();
  }

  static pw.Widget _flightDurTable(List<FlightDuration> flights) {
    final header = pw.Container(
      decoration: pw.BoxDecoration(color: _navy),
      child: pw.Row(children: [
        pw.SizedBox(width: 65, child: _th('FLIGHT #')),
        pw.SizedBox(width: 85, child: _th('TAKEOFF', center: true)),
        pw.SizedBox(width: 85, child: _th('LANDING', center: true)),
        pw.Expanded(child: _th('DURATION', center: true)),
      ]),
    );

    final rows = flights.asMap().entries.map((e) {
      final i = e.key;
      final f = e.value;
      return pw.Container(
        decoration: pw.BoxDecoration(
          color: i.isEven ? PdfColors.white : _rowAlt,
          border: pw.Border(
              bottom: pw.BorderSide(color: _border, width: 0.5)),
        ),
        child: pw.Row(children: [
          pw.SizedBox(
            width: 65,
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              child: pw.Text('Flight ${f.flightNum}',
                  style:
                      pw.TextStyle(fontSize: 9, color: _txtDark)),
            ),
          ),
          pw.SizedBox(
            width: 85,
            child: pw.Center(
              child: pw.Text(f.takeoff,
                  style:
                      pw.TextStyle(fontSize: 9, color: _txtDark)),
            ),
          ),
          pw.SizedBox(
            width: 85,
            child: pw.Center(
              child: pw.Text(f.landing,
                  style:
                      pw.TextStyle(fontSize: 9, color: _txtDark)),
            ),
          ),
          pw.Expanded(
            child: pw.Center(
              child: pw.Text('${f.totalMin} min',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _txtDark)),
            ),
          ),
        ]),
      );
    }).toList();

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 0.5),
        borderRadius:
            const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 3,
        verticalRadius: 3,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [header, ...rows],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FORM A-9 — MAINTENANCE LOG
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> generateMaintenanceLog(
    String aircraftName,
    String? serialNumber,
    List<Map<String, dynamic>> logs,
    OrgSettings org,
  ) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      footer: _footer,
      build: (ctx) => [
        _pageHeader(org, 'ANNEX A-9', 'MAINTENANCE LOG'),
        _section('Aircraft Information'),
        _info('Aircraft / Model', aircraftName),
        if (serialNumber != null && serialNumber.isNotEmpty)
          _info('Serial Number', serialNumber),
        _info('Report Generated',
            DateTime.now().toString().split('.').first),
        _section('Maintenance History'),
        logs.isEmpty
            ? pw.Padding(
                padding: const pw.EdgeInsets.all(10),
                child: pw.Text('No maintenance records found.',
                    style: pw.TextStyle(
                        fontSize: 9, color: _txtMuted)))
            : _maintenanceTable(logs),
        _sigBlock(['Technician / Maintenance Head']),
      ],
    ));
    return doc.save();
  }

  static pw.Widget _maintenanceTable(
      List<Map<String, dynamic>> logs) {
    final header = pw.Container(
      decoration: pw.BoxDecoration(color: _navy),
      child: pw.Row(children: [
        pw.SizedBox(width: 68, child: _th('DATE')),
        pw.Expanded(flex: 3, child: _th('TASK PERFORMED')),
        pw.Expanded(flex: 2, child: _th('PARTS REPLACED')),
        pw.SizedBox(
            width: 52, child: _th('FLT HRS', center: true)),
        pw.SizedBox(
            width: 70, child: _th('STATUS', center: true)),
      ]),
    );

    final rows = logs.asMap().entries.map((e) {
      final i = e.key;
      final log = e.value;
      final status =
          (log['airworthiness_status'] as String? ?? '').toLowerCase();
      final statusColor =
          status == 'serviceable' ? _success : _danger;
      return pw.Container(
        decoration: pw.BoxDecoration(
          color: i.isEven ? PdfColors.white : _rowAlt,
          border: pw.Border(
              bottom: pw.BorderSide(color: _border, width: 0.5)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 68,
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(log['maintenance_date'] ?? '',
                    style: pw.TextStyle(
                        fontSize: 8.5, color: _txtDark)),
              ),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(log['description'] ?? '',
                    style: pw.TextStyle(
                        fontSize: 8.5, color: _txtDark)),
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(log['parts_replaced'] ?? '',
                    style: pw.TextStyle(
                        fontSize: 8.5, color: _txtDark)),
              ),
            ),
            pw.SizedBox(
              width: 52,
              child: pw.Center(
                child: pw.Padding(
                  padding:
                      const pw.EdgeInsets.symmetric(vertical: 6),
                  child: pw.Text(
                    log['flight_hours']?.toString() ?? '—',
                    style:
                        pw.TextStyle(fontSize: 9, color: _txtDark),
                  ),
                ),
              ),
            ),
            pw.SizedBox(
              width: 70,
              child: pw.Center(
                child: pw.Padding(
                  padding:
                      const pw.EdgeInsets.symmetric(vertical: 6),
                  child: pw.Text(
                    status.toUpperCase(),
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: statusColor),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 0.5),
        borderRadius:
            const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 3,
        verticalRadius: 3,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [header, ...rows],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FORM A-10 — BATTERY LOG
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> generateBatteryLog(
    String batteryId,
    List<Map<String, dynamic>> logs,
    OrgSettings org,
  ) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      footer: _footer,
      build: (ctx) => [
        _pageHeader(org, 'ANNEX A-10', 'BATTERY LOG'),
        _section('Battery Information'),
        _info('Battery ID', batteryId),
        _info('Report Generated',
            DateTime.now().toString().split('.').first),
        _section('Charge & Voltage History'),
        logs.isEmpty
            ? pw.Padding(
                padding: const pw.EdgeInsets.all(10),
                child: pw.Text('No battery records found.',
                    style: pw.TextStyle(
                        fontSize: 9, color: _txtMuted)))
            : _batteryTable(logs),
        _sigBlock(['Technician']),
      ],
    ));
    return doc.save();
  }

  static pw.Widget _batteryTable(
      List<Map<String, dynamic>> logs) {
    final header = pw.Container(
      decoration: pw.BoxDecoration(color: _navy),
      child: pw.Row(children: [
        pw.SizedBox(width: 68, child: _th('DATE')),
        pw.SizedBox(
            width: 44, child: _th('CYCLES', center: true)),
        pw.SizedBox(
            width: 52, child: _th('V BEFORE', center: true)),
        pw.SizedBox(
            width: 52, child: _th('V AFTER', center: true)),
        pw.SizedBox(
            width: 48, child: _th('CHG MIN', center: true)),
        pw.Expanded(flex: 2, child: _th('REMARKS')),
        pw.SizedBox(width: 55, child: _th('STATUS', center: true)),
      ]),
    );

    final rows = logs.asMap().entries.map((e) {
      final i = e.key;
      final log = e.value;
      final status =
          (log['status'] as String? ?? 'good').toLowerCase();
      final statusColor = status == 'good'
          ? _success
          : status == 'warning'
              ? _warning
              : _danger;
      return pw.Container(
        decoration: pw.BoxDecoration(
          color: i.isEven ? PdfColors.white : _rowAlt,
          border: pw.Border(
              bottom: pw.BorderSide(color: _border, width: 0.5)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(
              width: 68,
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(log['log_date'] ?? '',
                    style: pw.TextStyle(
                        fontSize: 8.5, color: _txtDark)),
              ),
            ),
            pw.SizedBox(
              width: 44,
              child: pw.Center(
                child: pw.Text('${log['charge_cycles'] ?? '—'}',
                    style: pw.TextStyle(
                        fontSize: 9, color: _txtDark)),
              ),
            ),
            pw.SizedBox(
              width: 52,
              child: pw.Center(
                child: pw.Text(
                  log['voltage_before'] != null
                      ? '${(log['voltage_before'] as num).toStringAsFixed(2)}V'
                      : '—',
                  style:
                      pw.TextStyle(fontSize: 9, color: _txtDark),
                ),
              ),
            ),
            pw.SizedBox(
              width: 52,
              child: pw.Center(
                child: pw.Text(
                  log['voltage_after'] != null
                      ? '${(log['voltage_after'] as num).toStringAsFixed(2)}V'
                      : '—',
                  style:
                      pw.TextStyle(fontSize: 9, color: _txtDark),
                ),
              ),
            ),
            pw.SizedBox(
              width: 48,
              child: pw.Center(
                child: pw.Text('${log['charge_time_min'] ?? '—'}',
                    style: pw.TextStyle(
                        fontSize: 9, color: _txtDark)),
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(log['remarks'] ?? '',
                    style: pw.TextStyle(
                        fontSize: 8.5, color: _txtDark)),
              ),
            ),
            pw.SizedBox(
              width: 55,
              child: pw.Center(
                child: pw.Text(
                  status.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: statusColor),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 0.5),
        borderRadius:
            const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 3,
        verticalRadius: 3,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [header, ...rows],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FORM A-11 — INCIDENT / OCCURRENCE REPORT
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> generateIncidentReport(
    Mission? mission,
    Map<String, dynamic> report,
    OrgSettings org,
  ) async {
    final doc = pw.Document();
    final severity =
        (report['severity'] as String? ?? 'minor').toUpperCase();
    final sevColor = severity == 'CRITICAL'
        ? _danger
        : severity == 'SERIOUS'
            ? _warning
            : _accent;
    final reportedToCaap =
        (report['reported_to_caap'] as int? ?? 0) == 1;

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      footer: _footer,
      build: (ctx) => [
        _pageHeader(
            org, 'ANNEX A-11', 'INCIDENT / OCCURRENCE REPORT'),
        _section('Incident Classification'),
        _info('Incident Type', report['incident_type'] ?? ''),
        pw.Row(children: [
          pw.Text('Severity:  ',
              style: pw.TextStyle(fontSize: 9, color: _txtMuted)),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 8, vertical: 2),
            decoration: pw.BoxDecoration(
              color: sevColor,
              borderRadius: const pw.BorderRadius.all(
                  pw.Radius.circular(3)),
            ),
            child: pw.Text(severity,
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
          ),
        ]),
        pw.SizedBox(height: 4),
        _info('Reported to CAAP',
            reportedToCaap ? 'Yes' : 'No'),
        if ((report['caap_reference'] as String?)
                ?.isNotEmpty ==
            true)
          _info('CAAP Reference', report['caap_reference']!),

        _section('Incident Details'),
        _info('Date', report['incident_date'] ?? ''),
        _info('Time', report['incident_time'] ?? ''),
        _info('Location', report['location'] ?? ''),
        if (mission != null) ...[
          _info('Mission ID', mission.missionId),
          _info('Aircraft', mission.aircraftName),
        ],

        pw.SizedBox(height: 6),
        pw.Text('Incident Description:',
            style: pw.TextStyle(fontSize: 9, color: _txtMuted)),
        pw.SizedBox(height: 2),
        _textBlock(report['description'] ?? ''),

        _section('Root Cause Analysis (5 Whys)'),
        _textBlock(report['five_whys'] ?? ''),

        _section('Immediate Actions Taken'),
        _textBlock(report['immediate_actions'] ?? ''),

        _section('Corrective Actions & Follow-Up'),
        _textBlock(report['corrective_actions'] ?? ''),

        _sigBlock(['Reporter / RPIC', 'CRP / Safety Officer']),
      ],
    ));
    return doc.save();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SHARE HELPER
  // ── Fleet Summary Report ─────────────────────────────────────────────────

  /// Generates a one-page fleet summary PDF covering [missions] and basic stats.
  ///
  /// Parameters:
  ///   [org]          – organisation settings (name, address, etc.)
  ///   [rangeLabel]   – human-readable date range, e.g. "Jan 2026 – May 2026"
  ///   [missions]     – all missions to summarise
  ///   [flightLogs]   – raw flight log maps from the database
  ///   [maintenance]  – raw maintenance log maps
  ///   [batteryLogs]  – raw battery log maps
  ///   [incidents]    – raw incident report maps
  static Future<Uint8List> generateFleetSummary({
    required OrgSettings org,
    required String rangeLabel,
    required List<Mission> missions,
    required List<Map<String, dynamic>> flightLogs,
    required List<Map<String, dynamic>> maintenance,
    required List<Map<String, dynamic>> batteryLogs,
    required List<Map<String, dynamic>> incidents,
  }) async {
    final pdf = pw.Document();

    // ── compute aggregate stats ──────────────────────────────────────────
    final total        = missions.length;
    final completed    = missions.where((m) => m.status == 'completed').length;
    final inProgress   = missions.where((m) => m.status == 'in_progress').length;
    final cancelled    = missions.where((m) => m.status == 'cancelled').length;
    final planning     = missions.where((m) => m.status == 'planning').length;
    final totalMinutes = missions.fold<int>(0, (s, m) => s + (m.duration ?? 0));
    final flightHours  = totalMinutes / 60.0;
    final highRisk     = missions.where((m) => m.crpConcurrenceRequired).length;
    final degradedBat  = batteryLogs
        .where((b) =>
            b['status'] == 'degraded' ||
            b['status'] == 'retired' ||
            b['status'] == 'replace')
        .length;
    final openIncidents = incidents
        .where((i) => (i['corrective_actions'] as String? ?? '').isEmpty)
        .length;

    // ── local helpers ────────────────────────────────────────────────────

    pw.Widget statRow(String label, String value, {PdfColor? color}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(children: [
          pw.Expanded(
              child: pw.Text(label,
                  style: pw.TextStyle(color: _txtMuted, fontSize: 10))),
          pw.Text(value,
              style: pw.TextStyle(
                  color: color ?? _txtDark,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold)),
        ]),
      );
    }

    pw.Widget summaryCard(String title, List<pw.Widget> rows) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _border),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title,
                style: pw.TextStyle(
                    color: _blue,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.8)),
            pw.SizedBox(height: 8),
            pw.Divider(color: _border, height: 1),
            pw.SizedBox(height: 6),
            ...rows,
          ],
        ),
      );
    }

    pw.Widget fth(String t) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(t,
              style: pw.TextStyle(
                  color: _navy, fontSize: 8, fontWeight: pw.FontWeight.bold)),
        );

    pw.Widget ftd(String t, {bool mono = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(t,
              style: pw.TextStyle(
                  color: _txtDark,
                  fontSize: 8,
                  font: mono ? pw.Font.courier() : null)),
        );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => _pageHeader(org, 'FLEET-SUM', 'Fleet Summary Report'),
        footer: _footer,
        build: (ctx) => [
          // Report meta
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _rowHdr,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Period: $rangeLabel',
                    style: pw.TextStyle(
                        color: _txtDark,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text('Generated: $_todayStr',
                    style: pw.TextStyle(color: _txtMuted, fontSize: 10)),
              ],
            ),
          ),

          // Mission stats
          summaryCard('MISSION STATISTICS', [
            statRow('Total Missions', '$total'),
            statRow('Completed', '$completed', color: _success),
            statRow('In Progress', '$inProgress', color: _accent),
            statRow('Planning', '$planning'),
            statRow('Cancelled', '$cancelled', color: _danger),
            statRow('High-Risk (CRP Required)', '$highRisk', color: _warning),
            statRow('Total Flight Time', '${flightHours.toStringAsFixed(1)} hrs'),
          ]),

          // Maintenance
          summaryCard('MAINTENANCE', [
            statRow('Maintenance Records', '${maintenance.length}'),
          ]),

          // Battery
          summaryCard('BATTERY HEALTH', [
            statRow('Battery Log Entries', '${batteryLogs.length}'),
            statRow('Degraded / For Replacement', '$degradedBat',
                color: degradedBat > 0 ? _danger : _txtDark),
          ]),

          // Safety
          summaryCard('SAFETY & INCIDENTS', [
            statRow('Incident Reports', '${incidents.length}'),
            statRow('Open (no corrective action)', '$openIncidents',
                color: openIncidents > 0 ? _danger : _success),
          ]),

          // Mission breakdown table
          if (missions.isNotEmpty) ...[
            pw.Text('MISSION BREAKDOWN',
                style: pw.TextStyle(
                    color: _blue,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.8)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: _border, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.5),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(1.2),
                3: pw.FlexColumnWidth(1.2),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: _rowHdr),
                  children: [
                    fth('Mission Ref'),
                    fth('Title'),
                    fth('Status'),
                    fth('Duration'),
                  ],
                ),
                ...missions.map((m) {
                  final mins = m.duration ?? 0;
                  final dur = mins > 0
                      ? '${(mins / 60).toStringAsFixed(1)} hr'
                      : '—';
                  return pw.TableRow(children: [
                    ftd(m.missionId, mono: true),
                    ftd(m.title),
                    ftd(m.statusLabel),
                    ftd(dur),
                  ]);
                }),
              ],
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  static String get _todayStr {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  // ══════════════════════════════════════════════════════════════════════════

  /// Invokes the platform share/save sheet for the given [bytes].
  static Future<void> share(Uint8List bytes, String filename) async {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
