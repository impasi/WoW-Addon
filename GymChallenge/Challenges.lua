local _, GC = ...

-- Configurable challenges: each can be switched on/off and gets an exercise
-- and an amount. Units:
--  * squats / push-ups / burpees / sit-ups: repetitions
--  * plank: 1 repetition = 1 minute
--  * flight: the amount is given per 20 seconds of flight time, except for
--    "flightplank" (plank for the whole flight, the original rule)
--  * paladin challenges: amount per paladin
GC.PLANK_SECONDS = 60
GC.FLIGHT_STEP = 20

GC.CHALLENGE_ORDER = { "death", "paladin_crowded", "paladin_open", "level", "flight", "dungeon", "elite", "taxinode" }

GC.CHALLENGE_DEFAULTS = {
  death           = { enabled = true, ex = "squats",      amount = 10 },
  paladin_crowded = { enabled = true, ex = "pushups",     amount = 1 },
  paladin_open    = { enabled = true, ex = "pushups",     amount = 5 },
  level           = { enabled = true, ex = "burpees",     amount = 5 },
  flight          = { enabled = true, ex = "flightplank", amount = 1 },
  dungeon         = { enabled = true, ex = "situps",      amount = 20 },
  elite           = { enabled = true, ex = "plank",       amount = 1 },
  taxinode        = { enabled = true, ex = "squats",      amount = 15 },
}

GC.EXERCISES = { "squats", "pushups", "burpees", "situps", "plank" }

-- Exercise choices for a challenge (flight also offers "plank for the whole flight").
function GC.ExerciseChoices(key)
  if key == "flight" then
    return { "flightplank", "squats", "pushups", "burpees", "situps", "plank" }
  end
  return GC.EXERCISES
end

-- Current settings of a challenge (saved account-wide, defaults filled in).
function GC.Challenge(key)
  GC.db.challenges = GC.db.challenges or {}
  local cfg = GC.db.challenges[key]
  local def = GC.CHALLENGE_DEFAULTS[key]
  if not cfg then
    cfg = { enabled = def.enabled, ex = def.ex, amount = def.amount }
    GC.db.challenges[key] = cfg
  end
  if cfg.enabled == nil then cfg.enabled = def.enabled end
  if not cfg.ex then cfg.ex = def.ex end
  if not cfg.amount then cfg.amount = def.amount end
  return cfg
end

function GC.ChallengeEnabled(key)
  return GC.Challenge(key).enabled and true or false
end

function GC.ResetChallenges()
  GC.db.challenges = {}
end

-- Converts a challenge result into a task. multiplier: number of paladins,
-- number of 20 s flight steps, ... Returns the task or nil.
function GC.Assign(key, multiplier, reason, reasonArg, opts)
  local cfg = GC.Challenge(key)
  if not cfg.enabled then return nil end
  local ex = cfg.ex
  if ex == "flightplank" then ex = "plank" end
  local count = (cfg.amount or 0) * (multiplier or 1)
  if count <= 0 then return nil end
  if ex == "plank" then
    return GC.AddTask("plank", count * GC.PLANK_SECONDS, reason, reasonArg, opts)
  end
  return GC.AddTask(ex, count, reason, reasonArg, opts)
end

-- "3 Squats" style text for an amount of a challenge (for messages).
function GC.AssignText(key, multiplier)
  local cfg = GC.Challenge(key)
  local ex = cfg.ex == "flightplank" and "plank" or cfg.ex
  local count = (cfg.amount or 0) * (multiplier or 1)
  if ex == "plank" then count = count * GC.PLANK_SECONDS end
  return GC.TaskText({ kind = ex, amount = count })
end
