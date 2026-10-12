alias MakeACalendar.ChronoForge
alias MakeACalendar.ChronoForge.{Batch, BusinessDays, Conversions, ICS, Payroll, Recurrence, Retail445, Shift, SVG}

{:ok, month} = ChronoForge.month(2027, 10, week_start: :monday, mode: :fixed_six)
IO.inspect(month.weeks, label: "October 2027 (Monday first)")

{:ok, workdays} = BusinessDays.count(~D[2027-01-01], ~D[2027-01-31], holidays: :us_federal)
{:ok, due_date} = BusinessDays.add(~D[2027-01-29], 2, holidays: :us_federal)
IO.inspect(%{january_business_days: workdays, two_days_after_jan_29: due_date}, label: "Business dates")

rule = %{frequency: :nth_weekday, interval: 1, weekday: 5, ordinal: 3}
{:ok, third_fridays} = Recurrence.occurrences(rule, ~D[2027-01-01], ~D[2027-12-31])
IO.inspect(third_fridays, label: "Third Fridays in 2027")

{:ok, paydays} = Payroll.schedule(~D[2027-01-01], ~D[2027-03-31], :biweekly, adjust: :next_business_day, holidays: :us_federal)
IO.inspect(paydays, label: "Biweekly nominal and payment dates")

{:ok, shifts} = Shift.dates(~D[2027-01-01], ~D[2027-01-01], ~D[2027-01-14], :two_two_three)
IO.inspect(shifts, label: "Two-two-three rotation")

{:ok, fiscal_year} = Retail445.fiscal_year(2027, pattern: :four_four_five)
IO.inspect(%{start: fiscal_year.start, finish: fiscal_year.end, weeks: fiscal_year.weeks}, label: "FY2027 4-4-5")

IO.inspect(Conversions.excel(45_000.5), label: "Excel serial")
IO.inspect(Conversions.filetime(0), label: "FILETIME epoch")
IO.inspect(Conversions.ordinal("2024-060"), label: "Ordinal date")
IO.inspect(Conversions.julian_day(~D[2000-01-01]), label: "Julian day")

event = %{uid: "planning-2027@example.test", summary: "Planning day", start: ~D[2027-01-04], end: ~D[2027-01-05]}
{:ok, ics} = ICS.export([event], dtstamp: ~U[2027-01-01 00:00:00Z])
IO.puts(ics)

{:ok, svg} = SVG.render(month, theme: :ink_saver)
IO.puts("Generated a standalone SVG calendar (#{byte_size(svg)} bytes).")

{:ok, parallel} = Batch.run(1..3, fn month_number -> ChronoForge.month(2027, month_number) end, max_concurrency: 2)
IO.puts("Rendered #{length(parallel)} month grids with bounded concurrency.")
