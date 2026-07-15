package com.example.sled

import android.app.Application

/**
 * Раньше здесь инициализировался Yandex MapKit через MapKitFactory.setApiKey().
 * После миграции на официальный плагин yandex_maps_mapkit init перенесён в Dart
 * (см. lib/main.dart → ymk_init.initMapkit). Класс оставлен только потому, что
 * на него ссылается AndroidManifest.xml (android:name=".MainApplication").
 */
class MainApplication : Application()
