import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/user_profile_provider.dart';
import '../../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  LicenseVerificationScreen
//
//  3-step wizard:
//    1. Scan ID Card  → OCR → extract license number + expiry date
//    2. Face Check    → crop face from ID → take selfie → visual comparison
//    3. Confirm & Save → sets licenseVerified=true, auto-assigns role='pic'
// ═══════════════════════════════════════════════════════════════════════════════

class LicenseVerificationScreen extends StatefulWidget {
  const LicenseVerificationScreen({super.key});

  @override
  State<LicenseVerificationScreen> createState() =>
      _LicenseVerificationScreenState();
}

class _LicenseVerificationScreenState
    extends State<LicenseVerificationScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  int _step = 0; // 0=intro, 1=scan, 2=face, 3=confirm

  // Step 1 — ID scan
  File? _idImage;
  bool _isScanning = false;
  String _extractedLicenseNumber = '';
  String? _extractedExpiryDate; // ISO 'YYYY-MM-DD'
  String? _scanError;
  bool _ocrDone = false;

  // Step 2 — face
  Uint8List? _idFaceCrop;
  File? _selfieImage;
  bool _isDetectingFace = false;
  bool _faceConfirmed = false;
  bool _faceStepSkipped = false;

  // ── OCR regex patterns ─────────────────────────────────────────────────────

  // CAAP RPA / UAS license number patterns (case-insensitive)
  static final _licensePatterns = [
    // Most specific first: explicit CAAP/RPA prefix
    RegExp(r'RPA[-\s]?[A-Z0-9]{4,12}', caseSensitive: false),
    RegExp(r'CAAP[-\s][A-Z]{2,4}[-\s][A-Z0-9]{4,12}', caseSensitive: false),
    // "License No." or "Cert. No." followed by alphanumeric
    RegExp(r'(?:licen[sc]e|cert(?:ificate)?|no\.?)\s*[:#]?\s*([A-Z0-9][-A-Z0-9]{5,})',
        caseSensitive: false),
    // Fallback: any all-caps/digit sequence 6-16 chars with at least one dash
    RegExp(r'\b([A-Z]{2,6}-[A-Z0-9]{2,10}(?:-[A-Z0-9]{2,10})*)\b'),
  ];

  // Expiry date keywords + date capture
  static final _expiryPatterns = [
    // "valid until", "expiry date", "expires", "exp."
    RegExp(
        r'(?:valid\s*(?:until|thru)|expir(?:y|es?|ation)|exp\.?)\s*[:#]?\s*'
        r'(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})',
        caseSensitive: false),
    RegExp(
        r'(?:valid\s*(?:until|thru)|expir(?:y|es?|ation)|exp\.?)\s*[:#]?\s*'
        r'(\w+ \d{1,2},?\s*\d{4})',
        caseSensitive: false),
    RegExp(
        r'(?:valid\s*(?:until|thru)|expir(?:y|es?|ation)|exp\.?)\s*[:#]?\s*'
        r'(\d{1,2}\s+\w+\s+\d{4})',
        caseSensitive: false),
    // Bare date after known keyword (e.g. "VALIDITY: 12/31/2026")
    RegExp(r'VALIDITY[:\s]+(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})',
        caseSensitive: false),
  ];

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('License Verification'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: _stepIndicator(),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: KeyedSubtree(
          key: ValueKey(_step),
          child: _stepBody(),
        ),
      ),
    );
  }

  Widget _stepIndicator() {
    final labels = ['Intro', 'Scan ID', 'Face Check', 'Confirm'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == _step;
          final done = i < _step;
          return Expanded(
            child: Row(children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: done
                      ? AppColors.success
                      : active
                          ? AppColors.primary
                          : context.colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: done
                        ? AppColors.success
                        : active
                            ? AppColors.primary
                            : context.colors.border,
                  ),
                ),
                child: Center(
                  child: done
                      ? const Icon(Icons.check, size: 11, color: Colors.white)
                      : Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? Colors.white
                                  : context.colors.textMuted)),
                ),
              ),
              if (i < labels.length - 1)
                Expanded(
                  child: Container(
                    height: 1,
                    color: i < _step
                        ? AppColors.success
                        : context.colors.border,
                  ),
                ),
            ]),
          );
        }),
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _introStep();
      case 1:
        return _scanStep();
      case 2:
        return _faceStep();
      case 3:
        return _confirmStep();
      default:
        return const SizedBox();
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // STEP 0 — Intro
  // ════════════════════════════════════════════════════════════════════════════

  Widget _introStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.badge_outlined,
                color: AppColors.primary, size: 44),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'License Verification',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(
          'Scan your CAAP Remote Pilot Certificate to verify your identity and '
          'receive Pilot in Command (PIC) status.',
          textAlign: TextAlign.center,
          style:
              TextStyle(color: context.colors.textSecondary, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 32),
        _infoCard(
            Icons.document_scanner_outlined,
            'ID Card Scan',
            'Point your camera at your CAAP license card. The app will '
                'automatically extract your license number and expiry date.'),
        const SizedBox(height: 12),
        _infoCard(
            Icons.face_outlined,
            'Face Verification (Optional)',
            'A selfie is compared with the photo on your ID card to confirm '
                'your identity. This step can be skipped.'),
        const SizedBox(height: 12),
        _infoCard(
            Icons.security_outlined,
            'PIC Status',
            'Once verified, your profile is updated with PIC (Pilot in Command) '
                'status, allowing you to be assigned as RPIC on missions.'),
        const SizedBox(height: 36),
        _primaryButton(
          label: 'Start Verification',
          icon: Icons.arrow_forward,
          onPressed: () => setState(() => _step = 1),
        ),
      ],
    );
  }

  Widget _infoCard(IconData icon, String title, String body) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(title,
                style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(body,
                style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                    height: 1.4)),
          ]),
        ),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // STEP 1 — Scan ID Card
  // ════════════════════════════════════════════════════════════════════════════

  Widget _scanStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        _stepHeader(
          icon: Icons.document_scanner_outlined,
          title: 'Scan License Card',
          subtitle: 'Take a clear photo of the front of your CAAP license card.',
        ),
        const SizedBox(height: 20),

        // ── ID image preview / capture button ─────────────────────────────
        GestureDetector(
          onTap: _isScanning ? null : _captureIdImage,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _idImage != null
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : context.colors.border,
                width: _idImage != null ? 1.5 : 1,
              ),
            ),
            child: _idImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.file(_idImage!, fit: BoxFit.cover))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined,
                          color: context.colors.textMuted, size: 40),
                      const SizedBox(height: 10),
                      Text('Tap to scan ID card',
                          style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Camera or gallery',
                          style: TextStyle(
                              color: context.colors.textMuted, fontSize: 12)),
                    ],
                  ),
          ),
        ),

        if (_idImage != null && !_ocrDone) ...[
          const SizedBox(height: 14),
          _primaryButton(
            label: _isScanning ? 'Scanning…' : 'Scan This Image',
            icon: Icons.document_scanner_outlined,
            onPressed: _isScanning ? null : _runOcr,
            loading: _isScanning,
          ),
        ],

        if (_idImage != null) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _isScanning ? null : _captureIdImage,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retake / Choose Different Image'),
            style: TextButton.styleFrom(
                foregroundColor: context.colors.textSecondary),
          ),
        ],

        // ── OCR results ───────────────────────────────────────────────────
        if (_scanError != null) ...[
          const SizedBox(height: 16),
          _alertCard(_scanError!, AppColors.danger),
        ],

        if (_ocrDone) ...[
          const SizedBox(height: 20),
          _extractedDataCard(),
          const SizedBox(height: 20),
          if (_extractedLicenseNumber.isNotEmpty) ...[
            _primaryButton(
              label: 'Continue to Face Check',
              icon: Icons.arrow_forward,
              onPressed: () => setState(() => _step = 2),
            ),
            const SizedBox(height: 10),
            _secondaryButton(
              label: 'Skip Face Check — Go to Confirm',
              onPressed: () => setState(() {
                _faceStepSkipped = true;
                _step = 3;
              }),
            ),
          ] else ...[
            _alertCard(
                'License number could not be extracted automatically. '
                'Please ensure the card is well-lit, in focus, and the '
                'full front side is visible.',
                AppColors.warning),
          ],
        ],
      ],
    );
  }

  Widget _extractedDataCard() {
    final hasNumber = _extractedLicenseNumber.isNotEmpty;
    final hasExpiry = _extractedExpiryDate != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasNumber
            ? AppColors.success.withValues(alpha: 0.06)
            : AppColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasNumber
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            hasNumber ? Icons.check_circle_outline : Icons.warning_amber_outlined,
            color: hasNumber ? AppColors.success : AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            hasNumber ? 'Data Extracted Successfully' : 'Partial Extraction',
            style: TextStyle(
                color: hasNumber ? AppColors.success : AppColors.warning,
                fontSize: 13,
                fontWeight: FontWeight.w700),
          ),
        ]),
        const SizedBox(height: 14),
        _dataRow(
          Icons.badge_outlined,
          'License Number',
          hasNumber ? _extractedLicenseNumber : '(not found)',
          hasNumber ? AppColors.primary : AppColors.warning,
        ),
        const SizedBox(height: 8),
        _dataRow(
          Icons.event_outlined,
          'Valid Until',
          hasExpiry ? _formatExpiryDisplay(_extractedExpiryDate!) : '(not found)',
          hasExpiry ? context.colors.textPrimary : AppColors.warning,
        ),
        if (_extractedExpiryDate != null) ...[
          const SizedBox(height: 8),
          _expiryBadge(_extractedExpiryDate!),
        ],
      ]),
    );
  }

  Widget _dataRow(IconData icon, String label, String value, Color valueColor) {
    return Row(children: [
      Icon(icon, size: 14, color: context.colors.textMuted),
      const SizedBox(width: 8),
      SizedBox(
          width: 110,
          child: Text('$label:',
              style: TextStyle(
                  color: context.colors.textSecondary, fontSize: 12))),
      Expanded(
        child: Text(
          value,
          style: TextStyle(
              color: valueColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: label == 'License Number' ? 'monospace' : null),
        ),
      ),
    ]);
  }

  Widget _expiryBadge(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final daysLeft = dt.difference(DateTime.now()).inDays;
      String label;
      Color color;
      if (daysLeft < 0) {
        label = 'EXPIRED';
        color = AppColors.danger;
      } else if (daysLeft <= 30) {
        label = 'Expiring in ${daysLeft}d';
        color = AppColors.warning;
      } else {
        label = 'Valid (${daysLeft}d remaining)';
        color = AppColors.success;
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );
    } catch (_) {
      return const SizedBox();
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // STEP 2 — Face Check
  // ════════════════════════════════════════════════════════════════════════════

  Widget _faceStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        _stepHeader(
          icon: Icons.face_outlined,
          title: 'Face Verification',
          subtitle:
              'Take a selfie to compare with the photo on your license card.',
        ),
        const SizedBox(height: 20),

        // ── Side-by-side comparison ────────────────────────────────────────
        Row(children: [
          Expanded(child: _facePanel('ID Card Face', _idFaceCrop, isId: true)),
          const SizedBox(width: 12),
          Expanded(child: _selfiePanel()),
        ]),

        const SizedBox(height: 20),

        if (_idFaceCrop == null) ...[
          _alertCard(
              'No face was detected in the ID image. '
              'You can skip this step or retake the ID scan.',
              AppColors.warning),
          const SizedBox(height: 16),
        ],

        if (_selfieImage != null && !_isDetectingFace) ...[
          const SizedBox(height: 8),
          Text(
            'Do the two faces match?',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _outlineButton(
                label: 'Not a Match',
                icon: Icons.close,
                color: AppColors.danger,
                onPressed: () => setState(() {
                  _selfieImage = null;
                  _faceConfirmed = false;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _primaryButton(
                label: 'Faces Match',
                icon: Icons.check,
                color: AppColors.success,
                onPressed: () => setState(() {
                  _faceConfirmed = true;
                  _step = 3;
                }),
              ),
            ),
          ]),
        ] else if (_selfieImage == null) ...[
          _primaryButton(
            label: _isDetectingFace ? 'Detecting…' : 'Take Selfie',
            icon: Icons.camera_front_outlined,
            onPressed: _isDetectingFace ? null : _takeSelfie,
            loading: _isDetectingFace,
          ),
        ],

        const SizedBox(height: 16),
        _secondaryButton(
          label: 'Skip Face Check — Continue',
          onPressed: () => setState(() {
            _faceStepSkipped = true;
            _faceConfirmed = false;
            _step = 3;
          }),
        ),
        const SizedBox(height: 8),
        Text(
          'Face verification is optional but recommended for identity assurance.',
          textAlign: TextAlign.center,
          style:
              TextStyle(color: context.colors.textMuted, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  Widget _facePanel(String label, Uint8List? imageBytes, {bool isId = false}) {
    return Column(children: [
      Text(label,
          style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Container(
        height: 140,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: imageBytes != null
                ? AppColors.primary.withValues(alpha: 0.4)
                : context.colors.border,
          ),
        ),
        child: imageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.memory(imageBytes, fit: BoxFit.cover,
                    width: double.infinity))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isId
                        ? Icons.badge_outlined
                        : Icons.face_outlined,
                    color: context.colors.textMuted,
                    size: 32,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isId ? 'From ID' : 'Selfie',
                    style: TextStyle(
                        color: context.colors.textMuted, fontSize: 11),
                  ),
                ],
              ),
      ),
    ]);
  }

  Widget _selfiePanel() {
    Uint8List? bytes;
    if (_selfieImage != null) {
      bytes = _selfieImage!.readAsBytesSync();
    }
    return Column(children: [
      Text('Your Selfie',
          style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: _isDetectingFace ? null : _takeSelfie,
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: bytes != null
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : context.colors.border,
            ),
          ),
          child: bytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.memory(bytes,
                      fit: BoxFit.cover, width: double.infinity))
              : _isDetectingFace
                  ? const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_front_outlined,
                            color: context.colors.textMuted, size: 32),
                        const SizedBox(height: 6),
                        Text('Tap to take selfie',
                            style: TextStyle(
                                color: context.colors.textMuted,
                                fontSize: 11)),
                      ],
                    ),
        ),
      ),
    ]);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // STEP 3 — Confirm & Save
  // ════════════════════════════════════════════════════════════════════════════

  Widget _confirmStep() {
    final provider = context.read<UserProfileProvider>();
    final existing = provider.profile;
    final expiryParsed = _extractedExpiryDate != null
        ? DateTime.tryParse(_extractedExpiryDate!)
        : null;
    final isExpired =
        expiryParsed != null && expiryParsed.isBefore(DateTime.now());
    final grantsPic = !isExpired &&
        _extractedLicenseNumber.isNotEmpty &&
        existing.role != 'crp';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        _stepHeader(
          icon: Icons.check_circle_outline,
          title: 'Confirm Verification',
          subtitle: 'Review the extracted data before saving to your profile.',
        ),
        const SizedBox(height: 20),

        // ── Summary card ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _summaryRow(Icons.badge_outlined, 'License Number',
                _extractedLicenseNumber.isNotEmpty
                    ? _extractedLicenseNumber
                    : '—'),
            const SizedBox(height: 10),
            _summaryRow(
                Icons.event_outlined,
                'Valid Until',
                _extractedExpiryDate != null
                    ? _formatExpiryDisplay(_extractedExpiryDate!)
                    : '—'),
            if (_extractedExpiryDate != null) ...[
              const SizedBox(height: 4),
              _expiryBadge(_extractedExpiryDate!),
            ],
            const Divider(height: 24),
            _summaryRow(
                Icons.face_outlined,
                'Face Verified',
                _faceConfirmed
                    ? 'Yes — faces confirmed match'
                    : _faceStepSkipped
                        ? 'Skipped'
                        : 'Not completed'),
            const Divider(height: 24),
            _summaryRow(
              Icons.shield_outlined,
              'PIC Status',
              grantsPic
                  ? 'Will be granted (role → PIC)'
                  : isExpired
                      ? 'Not granted — license is expired'
                      : existing.role == 'crp'
                          ? 'Not applicable (CRP account)'
                          : 'Not granted — no valid license number',
            ),
          ]),
        ),

        const SizedBox(height: 16),

        if (grantsPic)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle,
                  color: AppColors.success, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your profile will be updated with PIC (Pilot in Command) status, '
                  'enabling you to be assigned as RPIC on missions.',
                  style: TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                      height: 1.4),
                ),
              ),
            ]),
          ),

        if (isExpired)
          _alertCard(
              'Your license has expired. License data will be saved but PIC '
              'status will not be granted until the license is renewed and '
              're-verified.',
              AppColors.danger),

        const SizedBox(height: 24),
        _primaryButton(
          label: 'Save Verification',
          icon: Icons.save_outlined,
          onPressed: _extractedLicenseNumber.isNotEmpty ? _saveVerification : null,
        ),
        const SizedBox(height: 10),
        _secondaryButton(
          label: '← Back to Face Check',
          onPressed: () => setState(() => _step = 2),
        ),
      ],
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: context.colors.textMuted),
      const SizedBox(width: 8),
      SizedBox(
          width: 110,
          child: Text('$label:',
              style: TextStyle(
                  color: context.colors.textSecondary, fontSize: 12))),
      Expanded(
        child: Text(value,
            style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
    ]);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Actions
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> _captureIdImage() async {
    final source = await _chooseSource();
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 95,
      maxWidth: 2000,
    );
    if (picked == null) return;

    setState(() {
      _idImage = File(picked.path);
      _ocrDone = false;
      _extractedLicenseNumber = '';
      _extractedExpiryDate = null;
      _scanError = null;
      _idFaceCrop = null;
    });
  }

  Future<ImageSource?> _chooseSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: ctx.colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: _sheetIcon(Icons.camera_alt_outlined, AppColors.primary),
            title: Text('Camera',
                style: TextStyle(
                    color: ctx.colors.textPrimary,
                    fontWeight: FontWeight.w500)),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: _sheetIcon(Icons.photo_library_outlined, AppColors.primary),
            title: Text('Choose from Gallery',
                style: TextStyle(
                    color: ctx.colors.textPrimary,
                    fontWeight: FontWeight.w500)),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _runOcr() async {
    if (_idImage == null) return;
    setState(() {
      _isScanning = true;
      _scanError = null;
    });

    try {
      // ── Text Recognition ────────────────────────────────────────────────
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFilePath(_idImage!.path);
      final recognized = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final fullText = recognized.text;

      // ── Extract license number ───────────────────────────────────────────
      String licenseNumber = '';
      for (final pattern in _licensePatterns) {
        final match = pattern.firstMatch(fullText);
        if (match != null) {
          licenseNumber = (match.groupCount > 0 ? match.group(1) : match.group(0))
                  ?.trim()
                  .toUpperCase() ??
              '';
          if (licenseNumber.isNotEmpty) break;
        }
      }

      // ── Extract expiry date ──────────────────────────────────────────────
      String? expiryIso;
      for (final pattern in _expiryPatterns) {
        final match = pattern.firstMatch(fullText);
        if (match != null) {
          final raw = (match.groupCount > 0 ? match.group(1) : match.group(0))
                  ?.trim() ??
              '';
          expiryIso = _parseToIso(raw);
          if (expiryIso != null) break;
        }
      }

      // ── Face detection ───────────────────────────────────────────────────
      Uint8List? faceCrop;
      try {
        faceCrop = await _detectAndCropFace(_idImage!.path);
      } catch (_) {
        // Face detection failure is non-fatal
      }

      setState(() {
        _extractedLicenseNumber = licenseNumber;
        _extractedExpiryDate = expiryIso;
        _idFaceCrop = faceCrop;
        _ocrDone = true;
        _isScanning = false;
        if (licenseNumber.isEmpty) {
          _scanError =
              'No license number pattern found. Ensure the card is fully '
              'visible and try again.';
        }
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _scanError = 'Scan failed: $e';
      });
    }
  }

  Future<Uint8List?> _detectAndCropFace(String imagePath) async {
    final options = FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
      performanceMode: FaceDetectorMode.accurate,
    );
    final detector = FaceDetector(options: options);
    final inputImage = InputImage.fromFilePath(imagePath);
    final faces = await detector.processImage(inputImage);
    await detector.close();

    if (faces.isEmpty) return null;

    // Pick the largest face (likely the ID photo)
    final face = faces.reduce((a, b) =>
        a.boundingBox.width * a.boundingBox.height >
                b.boundingBox.width * b.boundingBox.height
            ? a
            : b);

    final bytes = await File(imagePath).readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) return null;

    final bb = face.boundingBox;
    // Add 15 % padding around the face crop
    final padX = bb.width * 0.15;
    final padY = bb.height * 0.15;

    final x = (bb.left - padX).clamp(0.0, original.width.toDouble()).toInt();
    final y = (bb.top - padY).clamp(0.0, original.height.toDouble()).toInt();
    final w =
        (bb.width + padX * 2).clamp(1.0, (original.width - x).toDouble()).toInt();
    final h = (bb.height + padY * 2)
        .clamp(1.0, (original.height - y).toDouble())
        .toInt();

    final cropped = img.copyCrop(original, x: x, y: y, width: w, height: h);
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 88));
  }

  Future<void> _takeSelfie() async {
    setState(() => _isDetectingFace = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 90,
      );
      if (picked == null) {
        setState(() => _isDetectingFace = false);
        return;
      }
      setState(() {
        _selfieImage = File(picked.path);
        _isDetectingFace = false;
      });
    } catch (e) {
      setState(() => _isDetectingFace = false);
    }
  }

  Future<void> _saveVerification() async {
    final provider = context.read<UserProfileProvider>();
    final existing = provider.profile;

    final expiryParsed = _extractedExpiryDate != null
        ? DateTime.tryParse(_extractedExpiryDate!)
        : null;
    final isExpired =
        expiryParsed != null && expiryParsed.isBefore(DateTime.now());

    // Auto-assign 'pic' role if license is valid and user is not CRP
    final newRole = (!isExpired &&
            _extractedLicenseNumber.isNotEmpty &&
            existing.role != 'crp')
        ? 'pic'
        : existing.role;

    final updated = existing.copyWith(
      licenseNumber: _extractedLicenseNumber,
      licenseExpiryDate: _extractedExpiryDate,
      licenseVerified: true,
      faceVerified: _faceConfirmed,
      role: newRole,
    );

    await provider.update(updated);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newRole == 'pic'
            ? '✅ License verified — PIC status granted!'
            : '✅ License data saved.'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );

    Navigator.pop(context);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Helpers — date parsing
  // ════════════════════════════════════════════════════════════════════════════

  String? _parseToIso(String raw) {
    if (raw.isEmpty) return null;
    raw = raw.trim();

    // MM/DD/YYYY or MM-DD-YYYY or MM.DD.YYYY
    final slashDmy = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})$');
    var m = slashDmy.firstMatch(raw);
    if (m != null) {
      final a = int.tryParse(m.group(1)!) ?? 0;
      final b = int.tryParse(m.group(2)!) ?? 0;
      var year = int.tryParse(m.group(3)!) ?? 0;
      if (year < 100) year += 2000;
      // Assume MM/DD/YYYY (US format common on CAAP IDs)
      if (a <= 12) {
        return _isoDate(year, a, b) ?? _isoDate(year, b, a);
      }
      return _isoDate(year, b, a);
    }

    // "15 March 2026" or "March 15, 2026" or "15 Mar 2026"
    final formats = [
      'dd MMMM yyyy',
      'dd MMM yyyy',
      'MMMM dd, yyyy',
      'MMM dd, yyyy',
      'MMMM d, yyyy',
    ];
    for (final fmt in formats) {
      try {
        final dt = DateFormat(fmt, 'en_US').parse(raw);
        return DateFormat('yyyy-MM-dd').format(dt);
      } catch (_) {}
    }

    return null;
  }

  String? _isoDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  String _formatExpiryDisplay(String isoDate) {
    try {
      return DateFormat('dd MMMM yyyy').format(DateTime.parse(isoDate));
    } catch (_) {
      return isoDate;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Reusable widget helpers
  // ════════════════════════════════════════════════════════════════════════════

  Widget _stepHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(title,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                    height: 1.4)),
          ]),
        ),
      ]),
    );
  }

  Widget _alertCard(String message, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.warning_amber_outlined, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(message,
                style: TextStyle(color: color, fontSize: 12, height: 1.4))),
      ]),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    VoidCallback? onPressed,
    bool loading = false,
    Color? color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 18),
        label: Text(label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: (color ?? AppColors.primary).withValues(alpha: 0.4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _secondaryButton(
      {required String label, required VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: context.colors.textSecondary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _outlineButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label,
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.6)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _sheetIcon(IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      );
}
