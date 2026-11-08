local _, GC = ...

-- Points by difficulty, computed from the (completed) exercise totals.
-- Every client computes the points itself from the shared totals, so all
-- players in the ranking are rated with the same values.
GC.POINTS = {
  squats = 1,         -- per repetition
  situps = 1,
  pushups = 2,
  burpees = 3,
  plankPerMinute = 10, -- plank seconds / 60 * 10
}

-- Rank ladder (minimum points).
GC.RANKS = {
  { key = "bronze",     min = 0,     color = "ffcd7f32" },
  { key = "silver",     min = 250,   color = "ffc0c0c0" },
  { key = "gold",       min = 750,   color = "ffffd700" },
  { key = "platinum",   min = 1500,  color = "ff4ee2ec" },
  { key = "diamond",    min = 3000,  color = "ff6fa8ff" },
  { key = "master",     min = 6000,  color = "ffb45cff" },
  { key = "challenger", min = 12000, color = "ffff5a36" },
}

function GC.CalcPoints(e)
  if not e then return 0 end
  local p = GC.POINTS
  local total = (e.squats or 0) * p.squats + (e.situps or 0) * p.situps
    + (e.pushups or 0) * p.pushups + (e.burpees or 0) * p.burpees
    + (e.plank or 0) / 60 * p.plankPerMinute
  return math.floor(total + 0.5)
end

-- Returns rank, nextRank (nil at the top).
function GC.RankFor(points)
  local rank, nextRank = GC.RANKS[1], nil
  for i, r in ipairs(GC.RANKS) do
    if points >= r.min then
      rank, nextRank = r, GC.RANKS[i + 1]
    end
  end
  return rank, nextRank
end

function GC.RankName(rank, colored)
  local name = GC.L("rank_" .. rank.key)
  if colored then return "|c" .. rank.color .. name .. "|r" end
  return name
end

function GC.OwnPoints()
  return GC.CalcPoints(GC.cdb and GC.cdb.stats)
end
