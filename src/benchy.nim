import std/monotimes, strformat, math, strutils

proc nowMs(): float64 =
  ## Gets current milliseconds.
  getMonoTime().ticks.float64 / 1000000.0

proc total(s: seq[SomeNumber]): float =
  ## Computes total of a sequence.
  for v in s:
    result += v.float

proc min(s: seq[SomeNumber]): float =
  ## Computes mean (average) of a sequence.
  result = s[0].float
  for i in 1..s.high:
    result = min(s[i].float, result)

proc mean(s: seq[SomeNumber]): float =
  ## Computes mean (average) of a sequence.
  if s.len == 0: return NaN
  s.total / s.len.float

proc variance(s: seq[SomeNumber]): float =
  ## Computes the sample variance of a sequence.
  if s.len <= 1:
    return
  let a = s.mean()
  for v in s:
    result += (v.float - a) ^ 2
  result /= (s.len.float - 1)

proc stddev(s: seq[SomeNumber]): float =
  ## Computes the sample standard deviation of a sequence.
  sqrt(s.variance)

proc removeOutliers(s: var seq[SomeNumber]) =
  ## Remove numbers that are above 2 standard deviation.
  let avg = mean(s)
  let std = stddev(s)
  var i = 0
  while i < s.len:
    if abs(s[i] - avg) > std*2:
      s.delete(i)
    else:
      inc i

var
  shownHeader = false # Only show the header once.
  keepInt: int        # Results of keep template goes to this global.

template keep*(value: untyped) =
  ## Pass results of your computation here to keep the compiler from optimizing
  ## your computation to nothing.
  keepInt += 1
  {.emit: [keepInt, "+= (void*)&", value, ";"].}
  keepInt = keepInt and 0xFFFF
  #keepInt = cast[int](value)

template timeIt*(tag: string, iterations: untyped, body: untyped) =
  ## Template to time block of code.
  if not shownHeader:
    shownHeader = true
    echo "   min time    avg time  std dv   runs  name"
  var
    num = 0
    total: float64
    deltas: seq[float64]

  block:
    proc test() {.gensym.} =
      body

    while true:
      let start = nowMs()

      test()

      let finish = nowMs()

      let delta = finish - start
      total += delta
      deltas.add(delta)

      when iterations != 0:
        if num >= iterations:
          break
      else:
        if total > 5_000.0 or num >= 1000:
          break
      inc num

  let minDelta = min(deltas)
  removeOutliers(deltas)
  let avgDelta = mean(deltas)
  let stdDev = stddev(deltas)

  var
    m, s, d: string
  formatValue(m, minDelta, "0.3f")
  formatValue(s, avgDelta, "0.3f")
  formatValue(d, stdDev, "0.3f")
  echo align(m, 8) & " ms " & align(s, 8) & " ms " & align("±" & d, 8) & "  " &
      align("x" & $num, 5) & "  " & tag

template timeIt*(tag: string, body: untyped) =
  ## Template to time block of code.
  timeIt(tag, 0, body)

template timeIt*(deltas: var openArray[float64],
    iterations: untyped, body: untyped) =
  ## Template to time block of code.

  var
    num = 0
    total: float64
    actualIterations = when deltas is array:
        min(iterations, deltas.len)
      else: # deltas is seq
        iterations

  block:
    proc test() {.gensym.} =
      body

    while true:
      let start = nowMs()

      test()

      let finish = nowMs()

      let delta = finish - start
      total += delta

      when deltas is array:
        deltas[num] = delta

        if num >= actualIterations-1:
          break
        inc num
      else: # deltas is seq
        deltas.add(delta)
        inc num

        when iterations != 0:
          if num >= iterations:
            break
        else:
          if total > 5_000.0 or num >= 1_000:
            break

template timeIt*(deltas: var openArray[float64], body: untyped) =
  ## Template to time block of code.
  timeIt(
    deltas,
    when deltas is array: deltas.len
    else: 0,
    body
  )

