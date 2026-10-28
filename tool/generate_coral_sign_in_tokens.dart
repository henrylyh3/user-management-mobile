// Run from the mobile repository:
// dart run tool/generate_coral_sign_in_tokens.dart [canonical-json-path] [--check]
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

void main(List<String> args) {
  final source =
      args.where((arg) => arg != '--check').firstOrNull ??
      '../user-management-web/design-tokens/coral.tokens.json';
  final tokens =
      (jsonDecode(File(source).readAsStringSync()) as Map)['tokens'] as Map;
  dynamic value(String path) {
    final parts = path.split('.');
    final result = (tokens[parts[0]][parts[1]] as Map)[r'$value'];
    if (result is String && result.startsWith('{')) {
      return value(result.substring(1, result.length - 1));
    }
    return result;
  }

  String color(String path, [double alpha = 1]) {
    final match = RegExp(
      r'^oklch\(([\d.]+)% ([\d.]+) ([\d.]+)\)$',
    ).firstMatch(value(path) as String);
    if (match == null) throw FormatException('Unsupported OKLCH token: $path');
    final lightness = double.parse(match[1]!) / 100;
    final chroma = double.parse(match[2]!);
    final hue = double.parse(match[3]!) * math.pi / 180;
    final a = chroma * math.cos(hue), b = chroma * math.sin(hue);
    final l = math
        .pow(lightness + .3963377774 * a + .2158037573 * b, 3)
        .toDouble();
    final m = math
        .pow(lightness - .1055613458 * a - .0638541728 * b, 3)
        .toDouble();
    final s = math
        .pow(lightness - .0894841775 * a - 1.2914855480 * b, 3)
        .toDouble();
    int channel(double linear) {
      final encoded = linear <= .0031308
          ? 12.92 * linear
          : 1.055 * math.pow(linear, 1 / 2.4) - .055;
      return (encoded.clamp(0, 1) * 255).round();
    }

    final red = channel(4.0767416621 * l - 3.3077115913 * m + .2309699292 * s);
    final green = channel(
      -1.2684380046 * l + 2.6097574011 * m - .3413193965 * s,
    );
    final blue = channel(-.0041960863 * l - .7034186147 * m + 1.7076147010 * s);
    final argb =
        ((alpha * 255).round() << 24) | (red << 16) | (green << 8) | blue;
    return 'Color(0x${argb.toRadixString(16).padLeft(8, '0').toUpperCase()})';
  }

  double dimension(String path) {
    final token = value(path) as Map;
    return (token['value'] as num).toDouble() *
        switch (token['unit']) {
          'rem' => 16,
          'px' => 1,
          _ => throw FormatException('Unsupported dimension: $path'),
        };
  }

  final lines = <String>[
    '// Generated from the web canonical Coral tokens; do not edit.',
    '// Regenerate: dart run tool/generate_coral_sign_in_tokens.dart',
    '// OKLCH converted to 8-bit sRGB with channel clipping.',
    "import 'package:flutter/material.dart';",
    '',
    'abstract final class CoralSignInTokens {',
  ];
  for (final name in [
    'background',
    'surface',
    'surfaceSubtle',
    'surfaceHover',
    'primary',
    'primaryHover',
    'text',
    'textMuted',
    'border',
    'focus',
    'error',
    'success',
  ]) {
    lines.add('  static const $name = ${color('color.$name')};');
  }
  for (final entry in {
    'spaceXs': 'spacing.xs',
    'spaceSm': 'spacing.sm',
    'spaceMd': 'spacing.md',
    'spaceLg': 'spacing.lg',
    'spaceXl': 'spacing.xl',
    'space2xl': 'spacing.2xl',
    'cardRadius': 'radius.card',
    'inputRadius': 'radius.input',
    'controlHeight': 'control.height',
    'focusWidth': 'control.focusWidth',
    'bodySize': 'fontSize.md',
    'labelSize': 'fontSize.sm',
    'headingSize': 'fontSize.3xl',
    'phoneBreakpoint': 'breakpoint.phone',
  }.entries) {
    lines.add('  static const ${entry.key} = ${dimension(entry.value)};');
  }
  lines.add(
    '  static const font = ${jsonEncode((value('fontFamily.display') as List).first)};',
  );
  lines.add(
    '  static const disabledOpacity = ${value('control.disabledOpacity')};',
  );
  lines.add('  static const bodyHeight = ${value('lineHeight.body')};');
  lines.add('  static const headingHeight = ${value('lineHeight.heading')};');
  lines.add(
    '  static const headingTracking = ${((value('layout.tracking-display') as Map)['value'] as num) * dimension('fontSize.3xl')};',
  );
  for (final role in ['body', 'medium', 'heading']) {
    lines.add(
      '  static const ${role}Weight = FontWeight.w${(value('fontWeight.$role') as num).toInt()};',
    );
  }
  final shadow = (value('shadow.cast-stock') as List).single as Map;
  lines.add(
    '  static const paperShadow = BoxShadow(color: ${color('lighting.shade', (shadow['color']['alpha'] as num).toDouble())}, offset: Offset(${shadow['offsetX']}, ${shadow['offsetY']}), blurRadius: ${shadow['blur']}, spreadRadius: ${shadow['spread']});',
  );
  lines.add('}');
  final temporary = Directory.systemTemp.createTempSync('coral-tokens-');
  final formattedFile = File('${temporary.path}/tokens.dart');
  formattedFile.writeAsStringSync('${lines.join('\n')}\n');
  final formatted = Process.runSync(Platform.resolvedExecutable, [
    'format',
    formattedFile.path,
  ]);
  if (formatted.exitCode != 0) {
    throw StateError('Could not format generated tokens.');
  }
  final output = formattedFile.readAsStringSync();
  temporary.deleteSync(recursive: true);
  final file = File('lib/features/auth/coral_sign_in_tokens.dart');
  if (args.contains('--check')) {
    if (!file.existsSync() || file.readAsStringSync() != output) {
      stderr.writeln('Sign-in tokens are stale; run the generator.');
      exitCode = 1;
    } else {
      stdout.writeln('Mobile sign-in tokens match canonical Coral values.');
    }
  } else {
    file.writeAsStringSync(output);
    stdout.writeln('Generated mobile sign-in tokens.');
  }
}
