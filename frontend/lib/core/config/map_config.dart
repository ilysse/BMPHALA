class MapConfig {
  static const tileUrlTemplate = String.fromEnvironment(
    'BMP_MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const attribution = String.fromEnvironment(
    'BMP_MAP_ATTRIBUTION',
    defaultValue: 'OpenStreetMap contributors',
  );

  static const userAgentPackageName = String.fromEnvironment(
    'BMP_MAP_USER_AGENT',
    defaultValue: 'com.bmp.frontend',
  );
}
