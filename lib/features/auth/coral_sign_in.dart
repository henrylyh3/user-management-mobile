import 'package:flutter/material.dart';

import 'coral_sign_in_tokens.dart';

/// Sign-in-only Coral presentation. Shared theme and authentication stay external.
class CoralSignIn extends StatelessWidget {
  const CoralSignIn({
    super.key,
    required this.title,
    required this.form,
    required this.navigation,
  });

  final String title;
  final Widget form;
  final List<Widget> navigation;

  ThemeData _theme(ThemeData base) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(CoralSignInTokens.inputRadius),
      borderSide: const BorderSide(color: CoralSignInTokens.textMuted),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(CoralSignInTokens.cardRadius),
    );
    final buttons = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(CoralSignInTokens.controlHeight, CoralSignInTokens.controlHeight),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: CoralSignInTokens.spaceMd,
          vertical: CoralSignInTokens.spaceSm,
        ),
      ),
      shape: WidgetStatePropertyAll(shape),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: CoralSignInTokens.font,
          fontSize: CoralSignInTokens.labelSize,
          fontWeight: CoralSignInTokens.mediumWeight,
        ),
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.focused)
              ? CoralSignInTokens.focus
              : CoralSignInTokens.textMuted,
          width: states.contains(WidgetState.focused)
              ? CoralSignInTokens.focusWidth
              : 1,
        ),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? CoralSignInTokens.textMuted
            : CoralSignInTokens.text,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)
            ? CoralSignInTokens.surfaceSubtle
            : CoralSignInTokens.surface,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: CoralSignInTokens.background,
      colorScheme: base.colorScheme.copyWith(
        primary: CoralSignInTokens.primary,
        onPrimary: CoralSignInTokens.surface,
        surface: CoralSignInTokens.surface,
        onSurface: CoralSignInTokens.text,
        onSurfaceVariant: CoralSignInTokens.textMuted,
        error: CoralSignInTokens.error,
        outline: CoralSignInTokens.textMuted,
        outlineVariant: CoralSignInTokens.border,
      ),
      textTheme: base.textTheme
          .apply(
            fontFamily: CoralSignInTokens.font,
            bodyColor: CoralSignInTokens.text,
            displayColor: CoralSignInTokens.text,
          )
          .copyWith(
            bodyLarge: const TextStyle(
              fontFamily: CoralSignInTokens.font,
              fontSize: CoralSignInTokens.bodySize,
              height: CoralSignInTokens.bodyHeight,
              fontWeight: CoralSignInTokens.bodyWeight,
              color: CoralSignInTokens.text,
            ),
            bodyMedium: const TextStyle(
              fontFamily: CoralSignInTokens.font,
              fontSize: CoralSignInTokens.bodySize,
              height: CoralSignInTokens.bodyHeight,
              fontWeight: CoralSignInTokens.bodyWeight,
              color: CoralSignInTokens.text,
            ),
          ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: CoralSignInTokens.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CoralSignInTokens.spaceMd,
          vertical: CoralSignInTokens.spaceMd,
        ),
        enabledBorder: border,
        disabledBorder: border.copyWith(
          borderSide: const BorderSide(color: CoralSignInTokens.border),
        ),
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(
            color: CoralSignInTokens.focus,
            width: CoralSignInTokens.focusWidth,
          ),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: CoralSignInTokens.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(
            color: CoralSignInTokens.error,
            width: CoralSignInTokens.focusWidth,
          ),
        ),
        errorMaxLines: 4,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(style: buttons),
      filledButtonTheme: FilledButtonThemeData(
        style: buttons.copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.focused)
                  ? CoralSignInTokens.focus
                  : CoralSignInTokens.primary,
              width: states.contains(WidgetState.focused)
                  ? CoralSignInTokens.focusWidth
                  : 1,
            ),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? CoralSignInTokens.surface.withValues(
                    alpha: CoralSignInTokens.disabledOpacity,
                  )
                : CoralSignInTokens.surface,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.hovered)
                ? CoralSignInTokens.primaryHover
                : CoralSignInTokens.primary,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: CoralSignInTokens.border,
        thickness: 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: CoralSignInTokens.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth >= CoralSignInTokens.phoneBreakpoint;
              final padding = wide
                  ? CoralSignInTokens.spaceXl
                  : CoralSignInTokens.spaceLg;
              final heading = Semantics(
                header: true,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: CoralSignInTokens.font,
                    fontSize: CoralSignInTokens.headingSize,
                    height: CoralSignInTokens.headingHeight,
                    fontWeight: CoralSignInTokens.headingWeight,
                    letterSpacing: CoralSignInTokens.headingTracking,
                    color: CoralSignInTokens.text,
                  ),
                ),
              );
              final links = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: CoralSignInTokens.spaceXl),
                  for (var index = 0; index < navigation.length; index++) ...[
                    if (index > 0)
                      const SizedBox(height: CoralSignInTokens.spaceSm),
                    navigation[index],
                  ],
                ],
              );
              final formColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [form, links],
              );
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.all(
                  wide ? CoralSignInTokens.spaceXl : CoralSignInTokens.spaceMd,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: CoralSignInTokens.controlHeight * 19,
                    ),
                    padding: EdgeInsets.all(padding),
                    decoration: BoxDecoration(
                      color: CoralSignInTokens.surface,
                      borderRadius: BorderRadius.circular(
                        CoralSignInTokens.cardRadius,
                      ),
                      border: Border.all(color: CoralSignInTokens.border),
                      boxShadow: const [CoralSignInTokens.paperShadow],
                    ),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: heading),
                              const SizedBox(width: CoralSignInTokens.spaceXl),
                              Expanded(
                                flex: 5,
                                child: DecoratedBox(
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      left: BorderSide(
                                        color: CoralSignInTokens.border,
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      left: CoralSignInTokens.spaceXl,
                                    ),
                                    child: formColumn,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              heading,
                              const Divider(height: CoralSignInTokens.spaceXl),
                              formColumn,
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
