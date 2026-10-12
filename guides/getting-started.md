# Getting started

ChronoForge works with Gregorian `Date` values. A date has no time zone or time of day, which is the right model for month grids, business-day counts, payroll dates and all-day events.

## Generate a month

```elixir
alias MakeACalendar.ChronoForge

{:ok, month} = ChronoForge.month(2027, 10, week_start: :monday, mode: :fixed_six)
```

Each cell is either a `Date` in October or `nil` for padding. The weekday integer values follow ISO numbering: Monday is 1 and Sunday is 7. This means a caller can map business-week conventions without relying on locale settings.

## Render the data

```elixir
{:ok, svg} = MakeACalendar.ChronoForge.SVG.render(month, theme: :editorial)
```

Grid generation and rendering are separate. An application can reuse the same dates to build an HTML component, JSON response, or PDF pipeline of its own.

## Check boundaries

Month boundaries and invalid input are handled by `Date.new/3`; an invalid month returns an error. ISO week values use the ISO week-year, which can differ from the calendar year around New Year.

For print-oriented week-start and blank-grid examples, see the [monthly calendar pages](https://make-a-calendar.com/monthly-calendars) and [blank calendar templates](https://make-a-calendar.com/pages/blank-calendar).
