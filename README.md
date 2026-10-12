# ChronoForge Calendar Engine

ChronoForge is a pure Elixir toolkit for civil calendar grids, business-day arithmetic, recurring dates, pay schedules, rotating shifts, retail fiscal periods, date conversions, SVG calendars, and iCalendar output. It is independently implemented and does not call or scrape [Make a Calendar](https://make-a-calendar.com/), whose creator Ethan also created this project.

## Contents

- [Installation](#installation)
- [Quick start](#quick-start)
- [Calendar grids and ISO weeks](#calendar-grids-and-iso-weeks)
- [Business days and holidays](#business-days-and-holidays)
- [Recurrence and payroll](#recurrence-and-payroll)
- [Rotating shifts and fiscal periods](#rotating-shifts-and-fiscal-periods)
- [Conversions and exports](#conversions-and-exports)
- [Batch processing](#batch-processing)
- [Accuracy and limitations](#accuracy-and-limitations)
- [Development](#development)
- [Technical guides](#technical-guides)
- [Related online resources](#related-online-resources)
- [Contributing, security, license, and about](#contributing-security-license-and-about)

## Installation

```elixir
def deps do
  [{:make_a_calendar_chronoforge, "~> 0.1.0"}]
end
```

## Quick start

```elixir
alias MakeACalendar.ChronoForge

{:ok, october} = ChronoForge.month(2027, 10, week_start: :monday, mode: :fixed_six)
{:ok, {2026, 53}} = ChronoForge.iso_week(~D[2027-01-01])
```

All core calculations use `Date`, not local midnight timestamps. Most functions return `{:ok, value}` or `{:error, reason}`.

## Calendar grids and ISO weeks

`ChronoForge.month/3` returns weekday labels, a matrix of `Date.t()` values, and `nil` for cells outside the selected month. `mode: :natural` returns four to six rows; `:fixed_six` always returns six. Weekday starts accept `:monday`, `:sunday`, or ISO weekday integers 1 through 7.

```elixir
{:ok, grid} = ChronoForge.month(2027, 10, week_start: :sunday)
grid.weeks
```

`ChronoForge.iso_week/1` returns `{week_year, week_number}`. The ISO week-year can differ from the Gregorian year around New Year. The date `2027-01-01` belongs to ISO week 53 of 2026.

## Business days and holidays

`BusinessDays.count/3` includes both endpoints by default; set `include: :left | :right | :neither`. Workweeks are ISO weekday numbers. `holidays: :us_federal` excludes observed federal dates. `exclude_dates:` adds company or custom closures. This count is date arithmetic, not a statement about a bank, employer, contract, or jurisdiction.

```elixir
alias MakeACalendar.ChronoForge.BusinessDays

{:ok, workdays} = BusinessDays.count(~D[2027-01-01], ~D[2027-03-31], holidays: :us_federal)
{:ok, due} = BusinessDays.add(~D[2027-01-04], 10, holidays: :us_federal)
```

Holiday results preserve both `actual` and `observed` dates. An observed date can fall in the previous or next Gregorian year. The included federal rules cover modern fixed and weekday-based dates; they do not model every historical statutory naming or observance change.

## Recurrence and payroll

`Recurrence.occurrences/4` supports daily intervals, weekly weekday selections, monthly day numbers, and nth weekdays. The requested date range is inclusive and generation has a hard limit of 10,000 occurrences. It does not claim full RFC 5545 RRULE support.

```elixir
alias MakeACalendar.ChronoForge.Recurrence

{:ok, fridays} = Recurrence.occurrences(
  %{frequency: :nth_weekday, interval: 1, weekday: 5, ordinal: 3},
  ~D[2027-01-01], ~D[2027-12-31]
)
```

`Payroll.schedule/4` distinguishes an anchored 14-day biweekly sequence from two monthly dates. It returns nominal and payment dates. Monthly day 31 behavior is explicit (`missing_day: :last | :skip`). `adjust: :next_business_day` and `:previous_business_day` make direction explicit.

## Rotating shifts and fiscal periods

Shift patterns are repeatable binary masks. The anchor remains the same across month views, so phase continues through month and leap-day boundaries. Built-ins are `:four_three`, `:five_two`, and `:two_two_three`; custom masks are lists of `0` and `1`.

```elixir
alias MakeACalendar.ChronoForge.Shift

{:ok, roster} = Shift.dates(~D[2027-01-01], ~D[2027-10-01], ~D[2027-10-31], :two_two_three)
```

`Retail445.fiscal_year/2` uses the Sunday nearest February 1 and labels a year with its starting Gregorian year. It supports 4-4-5, 4-5-4, and 5-4-4. A 53rd week extends period 12. These are configurable retail conventions, not NRF certification.

```elixir
{:ok, fiscal} = MakeACalendar.ChronoForge.Retail445.fiscal_year(2027, pattern: :four_four_five)
```

## Conversions and exports

`Conversions` supports Excel 1900/1904 serials, Windows FILETIME, integer Unix units, ordinal dates, Julian Day Number, and Modified Julian Date. Excel serial 60 is returned as `:fictitious_excel_date`. Fractional Excel days are returned separately. `Formats.html/1`, `csv/1`, and `json/1` serialize month grids.

`SVG.render/2` emits standalone themed SVG with escaped text. `ICS.export/2` supports all-day `Date` events and explicitly UTC-normalized `DateTime` events, CRLF endings, escaping, deterministic ordering, and 75-octet line folding. All-day `end` values are exclusive, as required by the iCalendar date interval convention.

```elixir
alias MakeACalendar.ChronoForge.{ICS, SVG}

{:ok, svg} = SVG.render(october, theme: :editorial)
{:ok, ics} = ICS.export([%{uid: "review-2027@example.test", summary: "Review", start: ~D[2027-10-15]}])
```

The ICS implementation is a focused subset and does not emit recurrence rules or time-zone definitions. The project does not generate PDF files.

## Batch processing

`Batch.run/3` uses `Task.async_stream` with bounded concurrency and configurable timeout. It returns input order by default and reports task exits as errors. Calendar arithmetic itself stays process-free.

```elixir
alias MakeACalendar.ChronoForge.Batch

{:ok, exports} = Batch.run(1..12, fn month ->
  {:ok, calendar} = ChronoForge.month(2027, month)
  MakeACalendar.ChronoForge.SVG.render(calendar)
end, max_concurrency: 4, timeout: 5_000)
```

The work per month is small; sequential execution may be faster. Benchmark the actual workload before raising concurrency.

## Phoenix integration

Call these pure functions from contexts or supervised tasks. Validate HTTP input and cap requested date spans at the application boundary. The core package has no Phoenix dependency, web server, database, or network requirement.

## Supported Elixir/OTP versions

The package targets Elixir `~> 1.14`. CI compiles the project, runs ExUnit, builds the documentation, and builds the Hex archive on Elixir 1.14 / OTP 25 and Elixir 1.18 / OTP 27.

## Examples

The [runnable example script](examples/chronoforge_examples.exs) demonstrates monthly grids, business days, recurrence, payroll, rotating shifts, 4-4-5 periods, date conversions, iCalendar and SVG output, and bounded batch execution. CI runs it with `mix run`.

## Accuracy and limitations

The Gregorian date engine delegates civil-date validity and ISO week calculations to Elixir's `Date`. Federal holiday rules are provided for common modern observances, not as a legal source or universal closure calendar. Pay schedules are calendar plans only; they do not calculate pay, taxes, overtime, or labor-law compliance. Shift rotations describe on/off civil dates only. Fiscal mapping is an explicit retail convention.

## Development

```sh
mix deps.get
mix test
mix format --check-formatted
mix compile --warnings-as-errors
mix docs
mix hex.build
```

## Technical guides

- [Getting started](guides/getting-started.md)
- [Business scheduling](guides/business-scheduling.md)
- [Fiscal calendars](guides/fiscal-calendars.md)
- [Formats and exports](guides/formats-and-exports.md)
- [Batch processing](guides/batch-processing.md)

## Related online resources

- [Printable monthly calendars](https://make-a-calendar.com/monthly-calendars) show practical week-start and print-layout choices.
- [Business-day calculator](https://make-a-calendar.com/business-days-calculator) is useful for checking an explicitly selected inclusion and holiday policy.
- [4-4-5 retail calendar reference](https://make-a-calendar.com/445-calendar) illustrates Sunday-nearest-February 1 period boundaries.
- [Date converters](https://make-a-calendar.com/converters) provide browser-based tools for common external date formats.

## Contributing, security, license, and about

Contributions should include focused tests and documentation for behavior changes. Report security issues privately to the maintainer before public disclosure; do not include credentials in bug reports. The project is MIT licensed. Created by Ethan, founder of Make a Calendar.
