// core/db/database_cache.dart

class DatabaseCache {
  final int maxSize;
  final _cache = <String, List<Map<String, dynamic>>>{};
  final _accessOrder = <String>[];
  
  int _hits = 0;
  int _misses = 0;
  
  DatabaseCache({required this.maxSize});
  
  List<Map<String, dynamic>>? get(String key) {
    if (_cache.containsKey(key)) {
      _hits++;
      _updateAccessOrder(key);
      return _cache[key];
    }
    
    _misses++;
    return null;
  }
  
  void put(String key, List<Map<String, dynamic>> value) {
    if (_cache.length >= maxSize) {
      _evictLRU();
    }
    
    _cache[key] = value;
    _updateAccessOrder(key);
  }
  
  void invalidateTable(String tableName) {
    _cache.removeWhere((key, _) => key.startsWith('$tableName:'));
    _accessOrder.removeWhere((key) => key.startsWith('$tableName:'));
  }
  
  void clear() {
    _cache.clear();
    _accessOrder.clear();
    _hits = 0;
    _misses = 0;
  }
  
  void _updateAccessOrder(String key) {
    _accessOrder.remove(key);
    _accessOrder.add(key);
  }
  
  void _evictLRU() {
    if (_accessOrder.isEmpty) return;
    
    final lruKey = _accessOrder.removeAt(0);
    _cache.remove(lruKey);
  }
  
  double get hitRate {
    final total = _hits + _misses;
    return total > 0 ? _hits / total : 0.0;
  }
  
  int get size => _cache.length;
}
