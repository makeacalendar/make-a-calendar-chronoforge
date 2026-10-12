# Date formats and calendar exports

External date numbers often embed an epoch and unit. Keep those inputs explicit instead of converting through floating point timestamps.

```elixir
 Conversions.excel(60, 1900)
# => {:error, :fictitious_excel_date}

Conversions.filetime(0)
# => {:ok, %{date: ~D[1601-01-01], seconds: 0, ticks: 0}}
```

Excel's 1900 date system reserves serial 60 for a fictional 29 February. FILETIME counts 100-nanosecond ticks from 1601-01-01. Ordinal dates use `YYYY-DDD`; Julian Day Number and Modified Julian Date are separate integer conventions.

`Formats.html/1`, `csv/1`, and `json/1` serialize month grids while retaining empty cells at month boundaries.

The ICS exporter writes all-day exclusive end dates and UTC timed events only. It escapes text and folds content lines by UTF-8 octets. It does not emit RRULE or VTIMEZONE. SVG text is escaped for XML; themes control the main fills and strokes.

For interactive conversion checks, see the [Excel date converter](https://make-a-calendar.com/excel-date-converter), [FILETIME converter](https://make-a-calendar.com/filetime-converter), and [Julian date guide](https://make-a-calendar.com/julian-calendar).
