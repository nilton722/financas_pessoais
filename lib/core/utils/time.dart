String utcNowIsoString({DateTime? now}) =>
    (now ?? DateTime.now()).toUtc().toIso8601String();
