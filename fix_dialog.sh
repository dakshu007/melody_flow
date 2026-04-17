#!/bin/bash
# Melody Flow — DialogTheme quick fix
# Run from project root: bash fix_dialog.sh

set -e

echo "🔧 Fixing DialogTheme → DialogThemeData..."

sed -i '' 's/dialogTheme: const DialogTheme(/dialogTheme: const DialogThemeData(/' lib/core/theme/app_theme.dart 2>/dev/null || \
  sed -i 's/dialogTheme: const DialogTheme(/dialogTheme: const DialogThemeData(/' lib/core/theme/app_theme.dart

grep 'dialogTheme' lib/core/theme/app_theme.dart

git add -A
git commit -m "Fix: DialogTheme → DialogThemeData for Flutter 3.41"
git push

echo ""
echo "🎉 Pushed. Build running."
echo "   Watch: https://github.com/dakshu007/melody_flow/actions"
