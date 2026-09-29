enum YearRangeFilter {
  all('Tümü', null, null),
  twenties('2020+', 2020, null),
  tens("2010'lar", 2010, 2019),
  zeros("2000'ler", 2000, 2009),
  nineties("90'lar", 1990, 1999),
  classics('Klasikler (<1990)', null, 1989);

  final String label;
  final int? minYear;
  final int? maxYear;
  const YearRangeFilter(this.label, this.minYear, this.maxYear);
}

enum DiscoverSortOption {
  popularityDesc('🔥 Popülerlik', 'popularity.desc'),
  voteAverageDesc('⭐ TMDB Puanı (En Yüksek)', 'vote_average.desc'),
  releaseDateDesc('📅 Vizyon Tarihi (En Yeni)', 'primary_release_date.desc'),
  releaseDateAsc('⏳ Vizyon Tarihi (En Eski)', 'primary_release_date.asc'),
  revenueDesc('💰 Gişe / Hasılat', 'revenue.desc');

  final String label;
  final String apiValue;
  const DiscoverSortOption(this.label, this.apiValue);
}
