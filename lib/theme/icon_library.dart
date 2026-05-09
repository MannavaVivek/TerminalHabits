import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class IconEntry {
  final String key;
  final IconData data;
  const IconEntry(this.key, this.data);
}

const iconCategories = <String, List<IconEntry>>{
  'productivity': [
    IconEntry('target', LucideIcons.target),
    IconEntry('checkCircle2', LucideIcons.checkCircle2),
    IconEntry('briefcase', LucideIcons.briefcase),
    IconEntry('clock', LucideIcons.clock),
    IconEntry('calendar', LucideIcons.calendar),
    IconEntry('code2', LucideIcons.code2),
    IconEntry('listChecks', LucideIcons.listChecks),
    IconEntry('trophy', LucideIcons.trophy),
    IconEntry('rocket', LucideIcons.rocket),
    IconEntry('folder', LucideIcons.folder),
    IconEntry('file', LucideIcons.file),
    IconEntry('award', LucideIcons.award),
  ],
  'health': [
    IconEntry('heart', LucideIcons.heart),
    IconEntry('activity', LucideIcons.activity),
    IconEntry('dumbbell', LucideIcons.dumbbell),
    IconEntry('bike', LucideIcons.bike),
    IconEntry('footprints', LucideIcons.footprints),
    IconEntry('apple', LucideIcons.apple),
    IconEntry('pill', LucideIcons.pill),
    IconEntry('stethoscope', LucideIcons.stethoscope),
    IconEntry('heartPulse', LucideIcons.heartPulse),
    IconEntry('droplets', LucideIcons.droplets),
    IconEntry('flame', LucideIcons.flame),
    IconEntry('wind', LucideIcons.wind),
  ],
  'mind': [
    IconEntry('brain', LucideIcons.brain),
    IconEntry('bookOpen', LucideIcons.bookOpen),
    IconEntry('graduationCap', LucideIcons.graduationCap),
    IconEntry('lightbulb', LucideIcons.lightbulb),
    IconEntry('eye', LucideIcons.eye),
    IconEntry('pencil', LucideIcons.pencil),
    IconEntry('penTool', LucideIcons.penTool),
    IconEntry('sparkles', LucideIcons.sparkles),
    IconEntry('book', LucideIcons.book),
    IconEntry('compass', LucideIcons.compass),
    IconEntry('search', LucideIcons.search),
    IconEntry('aperture', LucideIcons.aperture),
  ],
  'creative': [
    IconEntry('palette', LucideIcons.palette),
    IconEntry('music', LucideIcons.music),
    IconEntry('camera', LucideIcons.camera),
    IconEntry('star', LucideIcons.star),
    IconEntry('zap', LucideIcons.zap),
    IconEntry('sparkle', LucideIcons.sparkle),
    IconEntry('diamond', LucideIcons.diamond),
    IconEntry('sun', LucideIcons.sun),
    IconEntry('moon', LucideIcons.moon),
    IconEntry('globe', LucideIcons.globe),
    IconEntry('flag', LucideIcons.flag),
    IconEntry('leaf', LucideIcons.leaf),
  ],
  'social': [
    IconEntry('users', LucideIcons.users),
    IconEntry('messageCircle', LucideIcons.messageCircle),
    IconEntry('heartHandshake', LucideIcons.heartHandshake),
    IconEntry('phone', LucideIcons.phone),
    IconEntry('smile', LucideIcons.smile),
    IconEntry('gift', LucideIcons.gift),
    IconEntry('mail', LucideIcons.mail),
    IconEntry('bell', LucideIcons.bell),
    IconEntry('map', LucideIcons.map),
    IconEntry('mapPin', LucideIcons.mapPin),
    IconEntry('hash', LucideIcons.hash),
    IconEntry('tag', LucideIcons.tag),
  ],
  'home': [
    IconEntry('home', LucideIcons.home),
    IconEntry('coffee', LucideIcons.coffee),
    IconEntry('utensils', LucideIcons.utensils),
    IconEntry('shoppingCart', LucideIcons.shoppingCart),
    IconEntry('wrench', LucideIcons.wrench),
    IconEntry('leaf', LucideIcons.leaf),
    IconEntry('treeDeciduous', LucideIcons.treeDeciduous),
    IconEntry('sun', LucideIcons.sun),
    IconEntry('cloud', LucideIcons.cloud),
    IconEntry('chefHat', LucideIcons.chefHat),
    IconEntry('shoppingBag', LucideIcons.shoppingBag),
    IconEntry('key', LucideIcons.key),
  ],
  'misc': [
    IconEntry('circle', LucideIcons.circle),
    IconEntry('circleDot', LucideIcons.circleDot),
    IconEntry('shield', LucideIcons.shield),
    IconEntry('lock', LucideIcons.lock),
    IconEntry('settings', LucideIcons.settings),
    IconEntry('filter', LucideIcons.filter),
    IconEntry('grid', LucideIcons.grid),
    IconEntry('layout', LucideIcons.layout),
    IconEntry('list', LucideIcons.list),
    IconEntry('bug', LucideIcons.bug),
    IconEntry('zap', LucideIcons.zap),
    IconEntry('x', LucideIcons.x),
  ],
};

final _flatMap = <String, IconData>{
  for (final entries in iconCategories.values)
    for (final e in entries) e.key: e.data,
};

IconData? lucideIconData(String? key) {
  if (key == null) return null;
  return _flatMap[key];
}

List<IconEntry> searchIcons(String query) {
  if (query.isEmpty) return [];
  final q = query.toLowerCase();
  return _flatMap.entries
      .where((e) => e.key.toLowerCase().contains(q))
      .map((e) => IconEntry(e.key, e.value))
      .toList();
}
