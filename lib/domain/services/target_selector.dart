import '../entities/combatant.dart';

/// Kriteria pemilihan target yang dapat dikonfigurasi (GDD 6.2 / TDD 7.2).
enum TargetPriorityCriterion { attackingPlayer, nearest, elite, lowestHp }

class TargetPriorityConfig {
  const TargetPriorityConfig({
    this.order = const [
      TargetPriorityCriterion.attackingPlayer,
      TargetPriorityCriterion.nearest,
      TargetPriorityCriterion.elite,
      TargetPriorityCriterion.lowestHp,
    ],
  });

  final List<TargetPriorityCriterion> order;
}

/// Memilih target berdasarkan urutan prioritas yang dapat dikonfigurasi,
/// diakhiri tie-break ID terkecil agar selalu deterministik.
class TargetSelector {
  const TargetSelector({this.priority = const TargetPriorityConfig()});

  final TargetPriorityConfig priority;

  Combatant? select({
    required Combatant seeker,
    required Iterable<Combatant> candidates,
  }) {
    Combatant? best;
    for (final candidate in candidates) {
      if (!candidate.isAlive) continue;
      if (best == null || _isBetter(seeker, candidate, best)) {
        best = candidate;
      }
    }
    return best;
  }

  bool _isBetter(Combatant seeker, Combatant a, Combatant b) {
    for (final criterion in priority.order) {
      final cmp = _compare(criterion, seeker, a, b);
      if (cmp != 0) return cmp < 0;
    }
    return a.id.compareTo(b.id) < 0;
  }

  int _compare(
    TargetPriorityCriterion criterion,
    Combatant seeker,
    Combatant a,
    Combatant b,
  ) {
    switch (criterion) {
      case TargetPriorityCriterion.attackingPlayer:
        final aEngaged = _isEngaged(seeker, a);
        final bEngaged = _isEngaged(seeker, b);
        if (aEngaged == bEngaged) return 0;
        return aEngaged ? -1 : 1;
      case TargetPriorityCriterion.nearest:
        final distA = seeker.distanceTo(a);
        final distB = seeker.distanceTo(b);
        return distA.compareTo(distB);
      case TargetPriorityCriterion.elite:
        if (a.isElite == b.isElite) return 0;
        return a.isElite ? -1 : 1;
      case TargetPriorityCriterion.lowestHp:
        return a.hp.compareTo(b.hp);
    }
  }

  bool _isEngaged(Combatant seeker, Combatant c) =>
      c.targetId == seeker.id && c.distanceTo(seeker) <= c.stats.attackRange;
}
