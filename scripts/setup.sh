#!/usr/bin/env bash
# Скрипт первоначальной настройки проекта GPS Трекер
set -e

echo "📦 Устанавливаем зависимости..."
flutter pub get

echo "🔧 Проверяем анализатор..."
flutter analyze --no-fatal-infos

echo "🧪 Запускаем тесты..."
flutter test

echo ""
echo "✅ Готово! Теперь подключите Android-устройство и запустите:"
echo "   flutter run"
echo ""
echo "⚠️  Для MP4-экспорта установите NDK 26.1.x:"
echo "   Android Studio → SDK Manager → SDK Tools → NDK (Side by side)"
