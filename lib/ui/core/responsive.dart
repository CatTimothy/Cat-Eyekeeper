import 'package:flutter/material.dart';

/// Below this window width, screens switch from side-by-side desktop
/// layouts to a single stacked column — covers common phone widths
/// (roughly 360-430 logical px) plus a margin, so a window resized all
/// the way down still reads as one continuous "compact" layout rather
/// than snapping awkwardly right at the phone-width edge.
const kCompactWidthBreakpoint = 640.0;

bool isCompactWidth(BuildContext context) => MediaQuery.sizeOf(context).width < kCompactWidthBreakpoint;
