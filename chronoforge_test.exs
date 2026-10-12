defmodule MakeACalendar.ChronoForgeTest do
  use ExUnit.Case, async: true

  alias MakeACalendar.ChronoForge
  alias MakeACalendar.ChronoForge.{BusinessDays, Conversions, Formats, Grid, Holidays, ICS, Payroll, Recurrence, Retail445, Shift, SVG}

  test "Gregorian dates include leap century rules and ordinal conversion" do
    assert Date.leap_year?(~D[2000-01-01])
    refute Date.leap_year?(~D[2100-01-01])
    assert ChronoForge.ordinal(~D[2024-02-29]) == 60
    assert Conversions.ordinal("2024-060") == {:ok, ~D[2024-02-29]}
    assert {:error, :invalid_ordinal_date} = Conversions.ordinal("2023-366")
  end

  test "month grid respects Monday start and fixed six rows" do
    assert {:ok, grid} = ChronoForge.month(2027, 10, week_start: :monday, mode: :fixed_six)
    assert grid.rows == 6
    assert hd(grid.weekdays) == :monday
    assert Enum.at(Enum.at(grid.weeks, 0), 4) == ~D[2027-10-01]
  end

  test "month grid rejects invalid dates and blank grid is undated" do
    assert {:error, _} = ChronoForge.month(2027, 13)
    assert {:ok, blank} = Grid.blank(5, 1)
    assert blank.weeks == List.duplicate(List.duplicate(nil, 7), 5)
  end

  test "ISO week-year transitions are preserved" do
    assert ChronoForge.iso_week(~D[2021-01-01]) == {2020, 53}
    assert ChronoForge.iso_week(~D[2027-01-01]) == {2026, 53}
  end

  test "observed holiday can fall in a different Gregorian year" do
    [new_year] = Enum.filter(Holidays.us_federal(2022), &(&1.name == "New Year's Day"))
    assert new_year.actual == ~D[2022-01-01]
    assert new_year.observed == ~D[2021-12-31]
  end

  test "federal holiday history gates MLK and Juneteenth" do
    refute Enum.any?(Holidays.us_federal(1985), &(&1.name == "Birthday of Martin Luther King, Jr."))
    refute Enum.any?(Holidays.us_federal(2020), &(&1.name == "Juneteenth National Independence Day"))
    assert Enum.any?(Holidays.us_federal(2021), &(&1.name == "Juneteenth National Independence Day"))
  end

  test "business counts have explicit endpoint inclusion and holiday handling" do
    assert BusinessDays.count(~D[2027-01-01], ~D[2027-01-05]) == {:ok, 3}
    assert BusinessDays.count(~D[2027-01-01], ~D[2027-01-05], include: :neither) == {:ok, 2}
    assert BusinessDays.count(~D[2027-01-01], ~D[2027-01-05], holidays: :us_federal) == {:ok, 2}
  end

  test "business addition walks both directions and skips observed holidays" do
    assert BusinessDays.add(~D[2027-01-01], 1) == {:ok, ~D[2027-01-04]}
    assert BusinessDays.add(~D[2027-01-05], -1) == {:ok, ~D[2027-01-04]}
    assert BusinessDays.add(~D[2027-12-30], 1, holidays: :us_federal) == {:ok, ~D[2028-01-03]}
  end

  test "custom workweek and excluded dates are honored" do
    assert BusinessDays.count(~D[2027-01-01], ~D[2027-01-03], workweek: [5, 6, 7]) == {:ok, 3}
    assert BusinessDays.count(~D[2027-01-01], ~D[2027-01-03], exclude_dates: [~D[2027-01-02]]) == {:ok, 1}
  end

  test "daily and nth weekday recurrence stay in a finite range" do
    assert Recurrence.occurrences(%{frequency: :day, interval: 3}, ~D[2027-01-01], ~D[2027-01-10]) ==
             {:ok, [~D[2027-01-01], ~D[2027-01-04], ~D[2027-01-07], ~D[2027-01-10]]}
    assert {:ok, third_fridays} = Recurrence.occurrences(%{frequency: :nth_weekday, interval: 1, weekday: 5, ordinal: 3}, ~D[2027-01-01], ~D[2027-03-31])
    assert third_fridays == [~D[2027-01-15], ~D[2027-02-19], ~D[2027-03-19]]
  end

  test "recurrence requires positive finite limits" do
    assert {:error, :invalid_limit} = Recurrence.occurrences(%{frequency: :day, interval: 1}, ~D[2027-01-01], ~D[2027-12-31], limit: 0)
    assert {:error, :invalid_rule} = Recurrence.occurrences(%{frequency: :unknown}, ~D[2027-01-01], ~D[2027-02-01])
  end

  test "biweekly and semi-monthly payroll schedules differ" do
    assert {:ok, biweekly} = Payroll.schedule(~D[2027-01-01], ~D[2027-02-28], :biweekly)
    assert Enum.map(biweekly, & &1.nominal) == [~D[2027-01-01], ~D[2027-01-15], ~D[2027-01-29], ~D[2027-02-12], ~D[2027-02-26]]
    assert {:ok, semimonthly} = Payroll.schedule(~D[2027-01-01], ~D[2027-02-28], :semi_monthly)
    assert Enum.map(semimonthly, & &1.nominal) == [~D[2027-01-01], ~D[2027-01-15], ~D[2027-02-01], ~D[2027-02-15]]
  end

  test "monthly payroll handles missing dates explicitly" do
    assert {:ok, clipped} = Payroll.schedule(~D[2027-01-31], ~D[2027-03-31], :monthly, day: 31, missing_day: :last)
    assert Enum.map(clipped, & &1.nominal) == [~D[2027-01-31], ~D[2027-02-28], ~D[2027-03-31]]
    assert {:ok, skipped} = Payroll.schedule(~D[2027-01-31], ~D[2027-03-31], :monthly, day: 31, missing_day: :skip)
    assert Enum.map(skipped, & &1.nominal) == [~D[2027-01-31], ~D[2027-03-31]]
  end

  test "shift mask phase does not reset at month boundaries" do
    assert {:ok, first} = Shift.dates(~D[2027-01-29], ~D[2027-01-31], ~D[2027-02-03], :four_three)
    assert Enum.map(first, &elem(&1, 1)) == [:on, :on, :on, :on, :off, :off]
  end

  test "retail year boundaries map 52 or 53 weeks with 12 periods" do
    assert {:ok, fy} = Retail445.fiscal_year(2027)
    assert length(fy.periods) == 12
    assert fy.weeks in [52, 53]
    assert hd(fy.periods).start == fy.start
    assert List.last(fy.periods).end == fy.end
    assert Enum.at(fy.periods, 2).weeks == 5
  end

  test "Excel serial 60 is not accepted as a Gregorian date" do
    assert {:ok, %{date: ~D[1900-01-01], fraction: 0.5}} = Conversions.excel(1.5)
    assert {:error, :fictitious_excel_date} = Conversions.excel(60)
    assert {:ok, %{date: ~D[1900-03-01]}} = Conversions.excel(61)
    assert {:ok, %{date: ~D[1904-01-02]}} = Conversions.excel(1, 1904)
  end

  test "FILETIME epoch and Unix units convert without timestamp floats" do
    assert {:ok, %{date: ~D[1601-01-01], seconds: 0, ticks: 0}} = Conversions.filetime(0)
    assert {:ok, dt} = Conversions.unix(1_500, :milliseconds)
    assert DateTime.to_unix(dt) == 1
    assert elem(dt.microsecond, 0) == 500_000
  end

  test "Julian day and modified Julian day use distinct offsets" do
    assert Conversions.julian_day(~D[2000-01-01]) == 2_451_545
    assert Conversions.modified_julian_day(~D[2000-01-01]) == 51_544
  end

  test "ICS emits CRLF, exclusive all-day end, escaping and folded lines" do
    event = %{uid: "one@example.test", summary: "Planning, review", start: ~D[2027-01-04], end: ~D[2027-01-05], description: String.duplicate("é", 60)}
    assert {:ok, ics} = ICS.export([event], dtstamp: ~U[2027-01-01 00:00:00Z])
    assert String.contains?(ics, "DTEND;VALUE=DATE:20270105")
    assert String.contains?(ics, "SUMMARY:Planning\\, review")
    assert String.contains?(ics, "\r\n ")
    assert String.ends_with?(ics, "END:VCALENDAR\r\n")
  end

  test "SVG escapes title and event-free calendar renders" do
    assert {:ok, calendar} = ChronoForge.month(2027, 10)
    assert {:ok, svg} = SVG.render(calendar, theme: :ink_saver)
    assert String.contains?(svg, "October 2027")
    assert {:error, :invalid_theme} = SVG.render(calendar, theme: :missing)
  end

  test "HTML, CSV and JSON preserve month dates and blank cells" do
    assert {:ok, calendar} = ChronoForge.month(2027, 10)
    assert {:ok, html} = Formats.html(calendar)
    assert String.contains?(html, "datetime=\"2027-10-01\"")
    assert {:ok, csv} = Formats.csv(calendar)
    assert String.contains?(csv, "2027-10-01")
    assert {:ok, json} = Formats.json(calendar)
    assert String.contains?(json, "\"month\":10")
    assert String.contains?(json, "null")
  end

  test "bad business ranges and schedules return errors" do
    assert {:error, :reversed_range} = BusinessDays.count(~D[2027-02-01], ~D[2027-01-01])
    assert {:error, :invalid_frequency} = Payroll.schedule(~D[2027-01-01], ~D[2027-02-01], :daily)
  end
end
