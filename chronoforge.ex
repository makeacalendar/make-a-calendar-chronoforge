defmodule MakeACalendar.ChronoForge do
  @moduledoc """
  Pure Gregorian calendar calculations for schedules, fiscal periods and exports.

  Created by Ethan, founder of [Make a Calendar](https://make-a-calendar.com/).
  The library computes dates locally and does not call the website.
  """

  alias MakeACalendar.ChronoForge.Grid

  @type week_start :: :monday | :sunday | 1..7

  @doc "Builds a month grid. `:natural` uses four to six weeks; `:fixed_six` always has six."
  @spec month(integer(), integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def month(year, month, opts \\ []) do
    with {:ok, first} <- Date.new(year, month, 1),
         {:ok, start} <- week_start(Keyword.get(opts, :week_start, :sunday)),
         mode when mode in [:natural, :fixed_six] <- Keyword.get(opts, :mode, :natural) do
      Grid.month(first, start, mode)
    else
      false -> {:error, :invalid_mode}
      {:error, _} = error -> error
      _ -> {:error, :invalid_month_options}
    end
  end

  @doc "Returns the ISO week-year and week number for a date."
  @spec iso_week(Date.t()) :: {integer(), pos_integer()}
  def iso_week(%Date{} = date), do: Date.iso_week(date)

  @doc "Returns a date's one-based ordinal day within its Gregorian year."
  @spec ordinal(Date.t()) :: pos_integer()
  def ordinal(%Date{} = date), do: Date.day_of_year(date)

  defp week_start(:monday), do: {:ok, 1}
  defp week_start(:sunday), do: {:ok, 7}
  defp week_start(day) when is_integer(day) and day in 1..7, do: {:ok, day}
  defp week_start(_), do: {:error, :invalid_week_start}
end

defmodule MakeACalendar.ChronoForge.Grid do
  @moduledoc "Builds dated and undated Gregorian month matrices."

  @weekdays [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]

  @doc "Creates a month map with weekday headers, weeks and month boundaries."
  @spec month(Date.t(), 1..7, :natural | :fixed_six) :: {:ok, map()}
  def month(%Date{day: 1} = first, week_start, mode) do
    days = Date.days_in_month(first)
    offset = Integer.mod(Date.day_of_week(first) - week_start, 7)
    needed = div(offset + days + 6, 7)
    rows = if mode == :fixed_six, do: 6, else: needed
    start_date = Date.add(first, -offset)

    weeks =
      for row <- 0..(rows - 1) do
        for col <- 0..6 do
          date = Date.add(start_date, row * 7 + col)
          if date.month == first.month, do: date, else: nil
        end
      end

    weekdays = for index <- 0..6, do: Enum.at(@weekdays, rem(week_start - 1 + index, 7))
    {:ok, %{year: first.year, month: first.month, week_start: week_start, weekdays: weekdays, weeks: weeks, rows: rows, first: first, last: Date.add(first, days - 1)}}
  end

  @doc "Returns consecutive month maps starting from the given year and month."
  @spec span(integer(), integer(), pos_integer(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def span(year, month, count, opts) when count in 1..24 do
    Enum.reduce_while(0..(count - 1), {:ok, []}, fn offset, {:ok, acc} ->
      index = year * 12 + month - 1 + offset
      y = div(index, 12)
      m = rem(index, 12) + 1
      case MakeACalendar.ChronoForge.month(y, m, opts) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, months} -> {:ok, Enum.reverse(months)}
      error -> error
    end
  end
  def span(_, _, _, _), do: {:error, :invalid_span}

  @doc "Creates an undated grid of the requested number of rows."
  @spec blank(pos_integer(), 1..7) :: {:ok, map()} | {:error, term()}
  def blank(rows, week_start) when rows in 4..6 and week_start in 1..7 do
    weekdays = for index <- 0..6, do: Enum.at(@weekdays, rem(week_start - 1 + index, 7))
    {:ok, %{week_start: week_start, weekdays: weekdays, weeks: List.duplicate(List.duplicate(nil, 7), rows), rows: rows}}
  end
  def blank(_, _), do: {:error, :invalid_blank_grid}
end

defmodule MakeACalendar.ChronoForge.Holidays do
  @moduledoc "US federal holiday dates, separated into legal and observed dates."
  @doc "Returns federal holidays for a year as maps with `:actual` and `:observed` dates."
  @spec us_federal(integer()) :: [map()]
  def us_federal(year) when year >= 1776 do
    fixed = [
      {"New Year's Day", Date.new!(year, 1, 1), 1776},
      {"Independence Day", Date.new!(year, 7, 4), 1776},
      {"Veterans Day", Date.new!(year, 11, 11), 1938},
      {"Christmas Day", Date.new!(year, 12, 25), 1870}
    ]
    moving = [
      {"Birthday of Martin Luther King, Jr.", nth_weekday(year, 1, 1, 3), 1986},
      {"Washington's Birthday", nth_weekday(year, 2, 1, 3), 1879},
      {"Memorial Day", last_weekday(year, 5, 1), 1971},
      {"Labor Day", nth_weekday(year, 9, 1, 1), 1894},
      {"Columbus Day", nth_weekday(year, 10, 1, 2), 1971},
      {"Thanksgiving Day", nth_weekday(year, 11, 4, 4), 1863},
      {"Juneteenth National Independence Day", Date.new!(year, 6, 19), 2021}
    ]

    (fixed ++ moving)
    |> Enum.filter(fn {_, date, start_year} -> year >= start_year && date <= Date.new!(year, 12, 31) end)
    |> Enum.map(fn {name, actual, _} -> %{name: name, actual: actual, observed: observed(actual)} end)
  end
  def us_federal(_), do: []

  @doc "Moves Saturday holidays to Friday and Sunday holidays to Monday."
  @spec observed(Date.t()) :: Date.t()
  def observed(date) do
    case Date.day_of_week(date) do
      6 -> Date.add(date, -1)
      7 -> Date.add(date, 1)
      _ -> date
    end
  end

  defp nth_weekday(year, month, weekday, n) do
    first = Date.new!(year, month, 1)
    Date.add(first, Integer.mod(weekday - Date.day_of_week(first), 7) + 7 * (n - 1))
  end
  defp last_weekday(year, month, weekday) do
    last = Date.new!(year, month, Date.days_in_month(Date.new!(year, month, 1)))
    Date.add(last, -Integer.mod(Date.day_of_week(last) - weekday, 7))
  end
end

defmodule MakeACalendar.ChronoForge.BusinessDays do
  @moduledoc "Business-day counting and arithmetic with explicit endpoint rules."
  @weekdays MapSet.new([1, 2, 3, 4, 5])

  @doc "Counts business dates in an inclusive or exclusive range. Default includes both endpoints."
  @spec count(Date.t(), Date.t(), keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  def count(%Date{} = first, %Date{} = last, opts \\ []) do
    with :ok <- if(first <= last, do: :ok, else: {:error, :reversed_range}),
         {:ok, working} <- workweek(Keyword.get(opts, :workweek, MapSet.to_list(@weekdays))),
         {:ok, bounds} <- bounds(first, last, Keyword.get(opts, :include, :both)) do
      holidays = holiday_set(bounds, opts)
      {range_start, range_end} = bounds
      total = if range_start > range_end, do: 0, else: Enum.count(Date.range(range_start, range_end), fn date -> MapSet.member?(working, Date.day_of_week(date)) and not MapSet.member?(holidays, date) end)
      {:ok, total}
    else
      {:error, _} = error -> error
      false -> {:error, :invalid_options}
    end
  end
  def count(_, _, _), do: {:error, :invalid_date_range}

  @doc "Adds signed business days, counting from the day after the start (or before for negative values)."
  @spec add(Date.t(), integer(), keyword()) :: {:ok, Date.t()} | {:error, term()}
  def add(%Date{} = start, amount, opts \\ []) when is_integer(amount) do
    with {:ok, working} <- workweek(Keyword.get(opts, :workweek, MapSet.to_list(@weekdays))) do
      holidays = holiday_set(Date.add(start, -abs(amount) - 370), Date.add(start, abs(amount) + 370), opts)
      direction = if amount < 0, do: -1, else: 1
      walk(start, abs(amount), direction, working, holidays)
    end
  end
  def add(_, _, _), do: {:error, :invalid_business_day_request}

  @doc "Returns the next business date strictly after the supplied date."
  @spec next(Date.t(), keyword()) :: {:ok, Date.t()} | {:error, term()}
  def next(date, opts \\ []), do: add(date, 1, opts)
  @doc "Returns the previous business date strictly before the supplied date."
  @spec previous(Date.t(), keyword()) :: {:ok, Date.t()} | {:error, term()}
  def previous(date, opts \\ []), do: add(date, -1, opts)

  defp walk(date, 0, _dir, _working, _holidays), do: {:ok, date}
  defp walk(date, left, dir, working, holidays) do
    candidate = Date.add(date, dir)
    if MapSet.member?(working, Date.day_of_week(candidate)) and not MapSet.member?(holidays, candidate),
      do: walk(candidate, left - 1, dir, working, holidays),
      else: walk(candidate, left, dir, working, holidays)
  end
  defp workweek(days) when is_list(days) do
    set = MapSet.new(days)
    if Enum.all?(days, &(&1 in 1..7)) and MapSet.size(set) > 0, do: {:ok, set}, else: {:error, :invalid_workweek}
  end
  defp workweek(_), do: {:error, :invalid_workweek}
  defp bounds(first, last, inclusion) do
    {left, right} = case inclusion do
      :both -> {first, last}
      :left -> {first, Date.add(last, -1)}
      :right -> {Date.add(first, 1), last}
      :neither -> {Date.add(first, 1), Date.add(last, -1)}
      _ -> {nil, nil}
    end
    if left && left <= right, do: {:ok, {left, right}}, else: if(left, do: {:ok, {left, left |> Date.add(-1)}} , else: {:error, :invalid_inclusion})
  end
  defp holiday_set({first, last}, opts), do: holiday_set(first, last, opts)
  defp holiday_set(first, last, opts) do
    federal = Keyword.get(opts, :holidays) == :us_federal
    dates = if federal, do: Enum.flat_map((first.year - 1)..(last.year + 1), &Enum.map(Holidays.us_federal(&1), fn h -> h.observed end)), else: []
    custom = Keyword.get(opts, :exclude_dates, [])
    MapSet.new(dates ++ custom)
  end
end

defmodule MakeACalendar.ChronoForge.Recurrence do
  @moduledoc "Bounded date recurrence for intervals, weekdays and monthly weekday rules."
  @max_occurrences 10_000

  @doc "Generates occurrences between inclusive `from` and `until`, stopping at `count` or the hard safety limit."
  @spec occurrences(map(), Date.t(), Date.t(), keyword()) :: {:ok, [Date.t()]} | {:error, term()}
  def occurrences(rule, %Date{} = from, %Date{} = until, opts \\ []) when from <= until do
    limit = Keyword.get(opts, :limit, @max_occurrences)
    count = Keyword.get(opts, :count, limit)
    if not (is_integer(limit) and limit in 1..@max_occurrences and is_integer(count) and count > 0), do: {:error, :invalid_limit}, else:
      do_occurrences(rule, from, until, min(count, limit))
  end
  def occurrences(_, _, _, _), do: {:error, :invalid_range}

  defp do_occurrences(%{frequency: :day, interval: n}, from, until, limit) when is_integer(n) and n > 0,
    do: step_dates(Date.add(from, 0), until, n, limit, [])
  defp do_occurrences(%{frequency: :week, interval: n, weekdays: days}, from, until, limit) when is_integer(n) and n > 0 and is_list(days) do
    if Enum.all?(days, &(&1 in 1..7)) do
      dates = Date.range(from, until) |> Enum.filter(fn d -> rem(Date.diff(d, from), 7 * n) < 7 and Date.day_of_week(d) in days end)
      {:ok, Enum.take(dates, limit)}
    else
      {:error, :invalid_weekdays}
    end
  end
  defp do_occurrences(%{frequency: :month_day, interval: n, day: day}, from, until, limit) when is_integer(n) and n > 0 and day in 1..31 do
    month_dates(from, until, n, limit, fn year, month -> if day <= Date.days_in_month(Date.new!(year, month, 1)), do: Date.new!(year, month, day) end)
  end
  defp do_occurrences(%{frequency: :nth_weekday, interval: n, weekday: weekday, ordinal: ordinal}, from, until, limit)
       when is_integer(n) and n > 0 and weekday in 1..7 and ordinal in 1..5 do
    month_dates(from, until, n, limit, fn year, month ->
      first = Date.new!(year, month, 1)
      date = Date.add(first, Integer.mod(weekday - Date.day_of_week(first), 7) + (ordinal - 1) * 7)
      if date.month == month, do: date
    end)
  end
  defp do_occurrences(_, _, _, _), do: {:error, :invalid_rule}
  defp step_dates(date, until, _step, _limit, acc) when date > until, do: {:ok, Enum.reverse(acc)}
  defp step_dates(_date, _until, _step, 0, acc), do: {:ok, Enum.reverse(acc)}
  defp step_dates(date, until, step, limit, acc), do: step_dates(Date.add(date, step), until, step, limit - 1, [date | acc])
  defp month_dates(from, until, interval, limit, build) do
    start = from.year * 12 + from.month - 1
    stop = until.year * 12 + until.month - 1
    result = Stream.iterate(start, &(&1 + interval)) |> Stream.take_while(&(&1 <= stop)) |> Enum.map(fn i -> build.(div(i, 12), rem(i, 12) + 1) end) |> Enum.reject(&is_nil/1) |> Enum.filter(&(&1 >= from and &1 <= until)) |> Enum.take(limit)
    {:ok, result}
  end
end

defmodule MakeACalendar.ChronoForge.Payroll do
  @moduledoc "Nominal and adjusted pay dates for weekly, biweekly and semi-monthly plans."
  alias MakeACalendar.ChronoForge.BusinessDays

  @doc "Builds nominal dates from an anchor; `:semi_monthly` requires `days: {first, second}`."
  @spec schedule(Date.t(), Date.t(), atom(), keyword()) :: {:ok, [%{nominal: Date.t(), payment: Date.t()}]} | {:error, term()}
  def schedule(%Date{} = from, %Date{} = through, frequency, opts \\ []) when from <= through do
    nominal = case frequency do
      :weekly -> interval_dates(from, through, 7)
      :biweekly -> interval_dates(from, through, 14)
      :semi_monthly -> semi_monthly(from, through, Keyword.get(opts, :days, {1, 15}))
      :monthly -> monthly(from, through, Keyword.get(opts, :day, from.day), Keyword.get(opts, :missing_day, :last))
      _ -> {:error, :invalid_frequency}
    end
    with dates when is_list(dates) <- nominal do
      adjust = Keyword.get(opts, :adjust, :none)
      Enum.reduce_while(dates, {:ok, []}, fn date, {:ok, acc} ->
        result = case adjust do
          :none -> {:ok, date}
      :next_business_day -> then_adjust(date, 1, opts)
          :previous_business_day -> then_adjust(date, -1, opts)
          _ -> {:error, :invalid_adjustment}
        end
        case result do
          {:ok, payment} -> {:cont, {:ok, [%{nominal: date, payment: payment} | acc]}}
          error -> {:halt, error}
        end
      end) |> case do {:ok, rows} -> {:ok, Enum.reverse(rows)}; error -> error end
    else
      {:error, _} = error -> error
      _ -> {:error, :invalid_schedule}
    end
  end
  def schedule(_, _, _, _), do: {:error, :invalid_range}

  defp interval_dates(from, through, step), do: Stream.iterate(from, &Date.add(&1, step)) |> Enum.take_while(&(&1 <= through))
  defp semi_monthly(from, through, {a, b}) when a in 1..28 and b in 1..31 do
    months = (from.year * 12 + from.month - 1)..(through.year * 12 + through.month - 1)
    for index <- months, day <- [a, b], date = Date.new!(div(index, 12), rem(index, 12) + 1, min(day, Date.days_in_month(Date.new!(div(index, 12), rem(index, 12) + 1, 1)))), date >= from and date <= through, do: date
  end
  defp semi_monthly(_, _, _), do: {:error, :invalid_semi_monthly_days}
  defp monthly(from, through, day, policy) when day in 1..31 and policy in [:last, :skip] do
    months = (from.year * 12 + from.month - 1)..(through.year * 12 + through.month - 1)
    for index <- months,
        first = Date.new!(div(index, 12), rem(index, 12) + 1, 1),
        chosen = if day <= Date.days_in_month(first), do: day, else: if(policy == :last, do: Date.days_in_month(first), else: nil),
        not is_nil(chosen), date = Date.new!(first.year, first.month, chosen), date >= from and date <= through, do: date
  end
  defp monthly(_, _, _, _), do: {:error, :invalid_monthly_day}
  defp then_adjust(date, dir, opts) do
    valid = fn d -> Date.day_of_week(d) in Keyword.get(opts, :workweek, [1, 2, 3, 4, 5]) and d not in Keyword.get(opts, :exclude_dates, []) and not (Keyword.get(opts, :holidays) == :us_federal and d in Enum.flat_map((d.year - 1)..(d.year + 1), &Enum.map(MakeACalendar.ChronoForge.Holidays.us_federal(&1), fn h -> h.observed end))) end
    walk_adjust(date, dir, valid, 0)
  end
  defp walk_adjust(date, _dir, valid, 0), do: if(valid.(date), do: {:ok, date}, else: {:error, :adjustment_limit})
  defp walk_adjust(date, dir, valid, remaining) do
    if valid.(date), do: {:ok, date}, else: walk_adjust(Date.add(date, dir), dir, valid, remaining - 1)
  end
end

defmodule MakeACalendar.ChronoForge.Shift do
  @moduledoc "Date-based rotating on/off schedules. It does not calculate hours or labor rules."
  @patterns %{four_three: [1, 1, 1, 1, 0, 0, 0], five_two: [1, 1, 1, 1, 1, 0, 0], two_two_three: [1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 0, 0, 0]}

  @doc "Returns `{:ok, [date: :on | :off]}` for an inclusive range. The anchor is cycle day zero."
  @spec dates(Date.t(), Date.t(), Date.t(), atom() | [0 | 1], keyword()) :: {:ok, [{Date.t(), :on | :off}]} | {:error, term()}
  def dates(%Date{} = anchor, %Date{} = from, %Date{} = through, pattern, opts \\ []) when from <= through do
    mask = if is_atom(pattern), do: Map.get(@patterns, pattern), else: pattern
    phase = Keyword.get(opts, :phase, 0)
    if is_list(mask) and mask != [] and Enum.all?(mask, &(&1 in [0, 1])) and is_integer(phase) do
      result = Enum.map(Date.range(from, through), fn date ->
        index = Integer.mod(Date.diff(date, anchor) + phase, length(mask))
        {date, if(Enum.at(mask, index) == 1, do: :on, else: :off)}
      end)
      {:ok, result}
    else
      {:error, :invalid_pattern}
    end
  end
  def dates(_, _, _, _, _), do: {:error, :invalid_range}
end

defmodule MakeACalendar.ChronoForge.Retail445 do
  @moduledoc "Retail fiscal periods anchored to the Sunday nearest February 1."
  @pattern %{four_four_five: [4, 4, 5], four_five_four: [4, 5, 4], five_four_four: [5, 4, 4]}

  @doc "Builds a fiscal year labelled by its starting Gregorian year; the 53rd week extends period 12."
  @spec fiscal_year(integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def fiscal_year(label, opts \\ []) when is_integer(label) do
    pattern = Keyword.get(opts, :pattern, :four_four_five)
    weeks = @pattern[pattern]
    if is_nil(weeks) do
      {:error, :invalid_pattern}
    else
      start = sunday_nearest(Date.new!(label, 2, 1))
      next_start = sunday_nearest(Date.new!(label + 1, 2, 1))
      total_weeks = div(Date.diff(next_start, start), 7)
      extra = total_weeks == 53
      lengths = weeks ++ weeks ++ weeks ++ weeks
      lengths = if extra, do: List.update_at(lengths, 11, &(&1 + 1)), else: lengths
      {periods, _cursor} = Enum.map_reduce(Enum.with_index(lengths, 1), start, fn {period_weeks, number}, cursor ->
        finish = Date.add(cursor, period_weeks * 7 - 1)
        {%{period: number, quarter: div(number - 1, 3) + 1, weeks: period_weeks, start: cursor, end: finish}, Date.add(finish, 1)}
      end)
      {:ok, %{label: label, start: start, end: Date.add(next_start, -1), weeks: total_weeks, pattern: pattern, periods: periods}}
    end
  end
  def fiscal_year(_, _), do: {:error, :invalid_year}

  defp sunday_nearest(date) do
    back = rem(Date.day_of_week(date), 7)
    forward = 7 - back
    if back <= forward, do: Date.add(date, -back), else: Date.add(date, forward)
  end
end

defmodule MakeACalendar.ChronoForge.Conversions do
  @moduledoc "Date conversion helpers with explicit epochs and Excel's fictitious serial 60."
  @excel_1900 Date.new!(1899, 12, 31)
  @excel_1904 Date.new!(1904, 1, 1)
  @filetime_epoch Date.new!(1601, 1, 1)

  @doc "Converts an Excel serial in the 1900 or 1904 system to a date and fractional day."
  @spec excel(number(), 1900 | 1904) :: {:ok, %{date: Date.t(), fraction: float()}} | {:error, term()}
  def excel(serial, system \\ 1900) when is_number(serial) and serial >= 0 and system in [1900, 1904] do
    whole = trunc(serial)
    fraction = serial - whole
    cond do
      system == 1900 and whole == 60 -> {:error, :fictitious_excel_date}
      true ->
        days = if system == 1900 and whole > 60, do: whole - 1, else: whole
        base = if system == 1900, do: @excel_1900, else: @excel_1904
        {:ok, %{date: Date.add(base, days), fraction: fraction}}
    end
  end
  def excel(_, _), do: {:error, :invalid_excel_serial}

  @doc "Converts Windows FILETIME 100-nanosecond ticks since 1601-01-01 to a date and time remainder."
  @spec filetime(non_neg_integer()) :: {:ok, %{date: Date.t(), seconds: non_neg_integer(), ticks: 0..9_999_999}} | {:error, term()}
  def filetime(ticks) when is_integer(ticks) and ticks >= 0 do
    ticks_per_day = 864_000_000_000
    days = div(ticks, ticks_per_day)
    remainder = rem(ticks, ticks_per_day)
    {:ok, %{date: Date.add(@filetime_epoch, days), seconds: div(remainder, 10_000_000), ticks: rem(remainder, 10_000_000)}}
  end
  def filetime(_), do: {:error, :invalid_filetime}

  @doc "Converts a Gregorian date to its Julian Day Number using integer arithmetic."
  @spec julian_day(Date.t()) :: integer()
  def julian_day(%Date{} = date) do
    a = div(14 - date.month, 12)
    y = date.year + 4800 - a
    m = date.month + 12 * a - 3
    date.day + div(153 * m + 2, 5) + 365 * y + div(y, 4) - div(y, 100) + div(y, 400) - 32045
  end
  @doc "Returns Modified Julian Date (JDN minus 2,400,001 for midnight-based civil dates)."
  @spec modified_julian_day(Date.t()) :: integer()
  def modified_julian_day(%Date{} = date), do: julian_day(date) - 2_400_001

  @doc "Converts an integer Unix timestamp to UTC DateTime using an explicit unit."
  @spec unix(integer(), :seconds | :milliseconds | :microseconds | :nanoseconds) :: {:ok, DateTime.t()} | {:error, term()}
  def unix(value, unit) when is_integer(value) and unit in [:seconds, :milliseconds, :microseconds, :nanoseconds] do
    {microseconds, precision} = case unit do
      :seconds -> {value * 1_000_000, 0}
      :milliseconds -> {value * 1_000, 3}
      :microseconds -> {value, 6}
      :nanoseconds -> {div(value, 1_000), 6}
    end
    case DateTime.from_unix(microseconds, :microsecond) do
      {:ok, datetime} -> {:ok, %{datetime | microsecond: {elem(datetime.microsecond, 0), precision}}}
      error -> error
    end
  end
  def unix(_, _), do: {:error, :invalid_unix_timestamp}

  @doc "Parses a Gregorian ordinal date in `YYYY-DDD` form."
  @spec ordinal(binary()) :: {:ok, Date.t()} | {:error, term()}
  def ordinal(<<year::binary-size(4), "-", day_text::binary-size(3)>>) do
    with {year_num, ""} <- Integer.parse(year),
         {day_num, ""} <- Integer.parse(day_text),
         true <- day_num >= 1 and day_num <= if(Date.leap_year?(Date.new!(year_num, 1, 1)), do: 366, else: 365) do
      {:ok, Date.add(Date.new!(year_num, 1, 1), day_num - 1)}
    else
      _ -> {:error, :invalid_ordinal_date}
    end
  end
  def ordinal(_), do: {:error, :invalid_ordinal_date}
end

defmodule MakeACalendar.ChronoForge.ICS do
  @moduledoc "RFC 5545 subset serializer for all-day and UTC events."

  @doc "Serializes maps containing `:uid`, `:summary`, `:start` and optional `:end`, `:description`, `:dtstamp`."
  @spec export([map()], keyword()) :: {:ok, binary()} | {:error, term()}
  def export(events, opts \\ []) when is_list(events) do
    with {:ok, rows} <- normalize(events) do
      now = Keyword.get(opts, :dtstamp, DateTime.utc_now())
      lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Make a Calendar//ChronoForge 0.1.0//EN", "CALSCALE:GREGORIAN"] ++ Enum.flat_map(Enum.sort_by(rows, & &1.sort), &event_lines(&1, now)) ++ ["END:VCALENDAR"]
      {:ok, Enum.map_join(lines, "\r\n", &fold/1) <> "\r\n"}
    end
  end
  def export(_, _), do: {:error, :invalid_events}

  defp normalize(events) do
    Enum.reduce_while(events, {:ok, []}, fn event, {:ok, acc} ->
      case event do
        %{uid: uid, summary: summary, start: %Date{} = start} when is_binary(uid) and is_binary(summary) ->
          finish = Map.get(event, :end, Date.add(start, 1))
          if match?(%Date{}, finish) and finish >= start, do: {:cont, {:ok, [%{type: :date, uid: uid, summary: summary, start: start, finish: finish, description: Map.get(event, :description, ""), sort: start} | acc]}}, else: {:halt, {:error, :invalid_event_end}}
        %{uid: uid, summary: summary, start: %DateTime{} = start} when is_binary(uid) and is_binary(summary) ->
          finish = Map.get(event, :end, DateTime.add(start, 3600, :second))
          if match?(%DateTime{}, finish) and DateTime.compare(finish, start) != :lt, do: {:cont, {:ok, [%{type: :datetime, uid: uid, summary: summary, start: DateTime.shift_zone!(start, "Etc/UTC"), finish: DateTime.shift_zone!(finish, "Etc/UTC"), description: Map.get(event, :description, ""), sort: start} | acc]}}, else: {:halt, {:error, :invalid_event_end}}
        _ -> {:halt, {:error, :invalid_event}}
      end
    end)
  end
  defp event_lines(%{type: :date} = e, now) do
    ["BEGIN:VEVENT", "UID:" <> esc(e.uid), "DTSTAMP:" <> stamp(now), "DTSTART;VALUE=DATE:" <> Date.to_iso8601(e.start) |> String.replace("-", ""), "DTEND;VALUE=DATE:" <> Date.to_iso8601(e.finish) |> String.replace("-", ""), "SUMMARY:" <> esc(e.summary), "DESCRIPTION:" <> esc(e.description), "END:VEVENT"]
  end
  defp event_lines(%{type: :datetime} = e, now) do
    ["BEGIN:VEVENT", "UID:" <> esc(e.uid), "DTSTAMP:" <> stamp(now), "DTSTART:" <> DateTime.to_iso8601(e.start) |> String.replace(~r/[-:]/, "") |> String.replace("+0000", "Z"), "DTEND:" <> DateTime.to_iso8601(e.finish) |> String.replace(~r/[-:]/, "") |> String.replace("+0000", "Z"), "SUMMARY:" <> esc(e.summary), "DESCRIPTION:" <> esc(e.description), "END:VEVENT"]
  end
  defp stamp(%DateTime{} = dt), do: dt |> DateTime.shift_zone!("Etc/UTC") |> Calendar.strftime("%Y%m%dT%H%M%SZ")
  defp esc(value), do: value |> String.replace("\\", "\\\\") |> String.replace(";", "\\;") |> String.replace(",", "\\,") |> String.replace("\n", "\\n") |> String.replace("\r", "")
  defp fold(line) do
    line |> String.graphemes() |> Enum.reduce({[], "", 0}, fn grapheme, {lines, current, size} ->
      bytes = byte_size(grapheme)
      if size + bytes > 75, do: {[current | lines], " " <> grapheme, bytes + 1}, else: {lines, current <> grapheme, size + bytes}
    end) |> then(fn {lines, current, _} -> Enum.reverse([current | lines]) |> Enum.join("\r\n") end)
  end
end

defmodule MakeACalendar.ChronoForge.SVG do
  @moduledoc "Safe SVG rendering for month grids."
  @themes %{editorial: {"#fff", "#202124", "#d7dbe0"}, corporate: {"#f5f7fa", "#183153", "#b8c6d8"}, ink_saver: {"#fff", "#111", "#888"}}

  @doc "Renders a month map as an escaped, standalone SVG."
  @spec render(map(), keyword()) :: {:ok, binary()} | {:error, term()}
  def render(%{weeks: weeks, weekdays: weekdays, year: year, month: month}, opts \\ []) do
    theme = Map.get(@themes, Keyword.get(opts, :theme, :editorial))
    if is_nil(theme), do: {:error, :invalid_theme}, else:
      {background, foreground, stroke} = theme
      width = 700
      cell_w = div(width, 7)
      cell_h = 88
      title = Calendar.strftime(Date.new!(year, month, 1), "%B %Y")
      header = Enum.with_index(weekdays) |> Enum.map_join("", fn {day, i} -> text(i * cell_w + 8, 32, String.capitalize(String.slice(Atom.to_string(day), 0, 3)), foreground, 14) end)
      body = weeks |> Enum.with_index() |> Enum.map_join(fn {week, row} -> Enum.with_index(week) |> Enum.map_join(fn {date, col} ->
        x = col * cell_w
        y = 44 + row * cell_h
        rect = "<rect x=\"#{x}\" y=\"#{y}\" width=\"#{cell_w}\" height=\"#{cell_h}\" fill=\"#{background}\" stroke=\"#{stroke}\"/>"
        label = if date, do: Integer.to_string(date.day), else: ""
        rect <> text(x + 8, y + 23, label, foreground, 15)
      end) end)
      {:ok, "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 700 #{44 + length(weeks) * cell_h}\" role=\"img\" aria-label=\"#{escape(title)} calendar\"><rect width=\"100%\" height=\"100%\" fill=\"#{background}\"/><text x=\"8\" y=\"28\" font-family=\"sans-serif\" font-size=\"20\" fill=\"#{foreground}\">#{escape(title)}</text>#{header}#{body}</svg>"}
  end
  def render(_, _), do: {:error, :invalid_calendar}
  defp text(x, y, value, color, size), do: "<text x=\"#{x}\" y=\"#{y}\" font-family=\"sans-serif\" font-size=\"#{size}\" fill=\"#{color}\">#{escape(value)}</text>"
  defp escape(value), do: value |> String.replace("&", "&amp;") |> String.replace("<", "&lt;") |> String.replace(">", "&gt;") |> String.replace("\"", "&quot;") |> String.replace("'", "&apos;")
end

defmodule MakeACalendar.ChronoForge.Batch do
  @moduledoc "Bounded task execution for independent calendar jobs."

  @doc "Runs jobs with bounded concurrency and timeout; result order follows input order by default."
  @spec run(Enumerable.t(), (term() -> term()), keyword()) :: {:ok, [term()]} | {:error, term()}
  def run(enumerable, fun, opts \\ []) when is_function(fun, 1) do
    concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())
    timeout = Keyword.get(opts, :timeout, 5_000)
    ordered = Keyword.get(opts, :ordered, true)
    if is_integer(concurrency) and concurrency > 0 and is_integer(timeout) and timeout > 0 do
      enumerable
      |> Task.async_stream(fun, max_concurrency: concurrency, timeout: timeout, ordered: ordered, on_timeout: :kill_task)
      |> Enum.reduce_while({:ok, []}, fn result, {:ok, acc} ->
        case result do
          {:ok, value} -> {:cont, {:ok, [value | acc]}}
          {:exit, reason} -> {:halt, {:error, {:task_exit, reason}}}
        end
      end)
      |> case do {:ok, values} -> {:ok, if(ordered, do: Enum.reverse(values), else: Enum.reverse(values))}; error -> error end
    else
      {:error, :invalid_batch_options}
    end
  end
  def run(_, _, _), do: {:error, :invalid_batch}
end
