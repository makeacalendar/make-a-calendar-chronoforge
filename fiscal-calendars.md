# Retail fiscal calendars

Retail calendars divide weeks into repeating periods, so period ends remain aligned to weekdays. Under the Sunday-nearest-February-1 convention, a fiscal year begins on the Sunday closest to February 1. Adjacent anchors can be 52 or 53 weeks apart.

```elixir
{:ok, fy} = MakeACalendar.ChronoForge.Retail445.fiscal_year(2027, pattern: :four_four_five)
Enum.map(fy.periods, &{&1.period, &1.weeks, &1.start, &1.end})
```

In 4-4-5, a quarter contains periods of four, four, and five weeks. That final period is seven days longer than a four-week period. A 53-week year adds its extra week to period 12 by this library's convention. Always document the chosen anchor and assignment rule when comparing reports.

The [4-4-5 calendar reference](https://make-a-calendar.com/445-calendar) helps readers visualize week-aligned retail periods. ChronoForge implements its own boundaries and does not certify a fiscal calendar against an industry body.
