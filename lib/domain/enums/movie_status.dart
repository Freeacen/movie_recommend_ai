enum MovieStatus {
  none,
  watchlist,
  recommended,
  watched;

  String toDbString() => name;

  static MovieStatus fromDbString(String? value) {
    if (value == null) return MovieStatus.none;
    for (final status in MovieStatus.values) {
      if (status.name == value) return status;
    }
    return MovieStatus.none;
  }
}
