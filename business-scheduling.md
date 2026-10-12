# Business scheduling

“Business day” is a policy choice. This guide uses Monday through Friday, excludes US federal observed holidays only when requested, and counts both range endpoints by default.

```elixir
alias MakeACalendar.ChronoForge.BusinessDays

BusinessDays.count(~D[2027-01-01], ~D[2027-01-31], holidays: :us_federal)
BusinessDays.add(~D[2027-01-04], 5, holidays: :us_federal)
```

Use `include: :left`, `:right`, or `:neither` when the contract or workflow excludes a boundary. `exclude_dates:` handles company shutdowns. A custom workweek takes ISO weekdays, such as `[1, 2, 3, 4, 5]`.

## Nominal dates and payment dates

Payroll plans retain both the nominal date and adjusted payment date. Choose `:next_business_day` or `:previous_business_day` explicitly; an agreement may require a different convention. Biweekly is an anchored sequence 14 days apart. Semi-monthly creates two dates in each month and does not drift through the year.

Federal legal dates and observed weekdays are distinct fields. Observed holidays can lie in the adjacent year. Federal dates are not a universal promise that a private employer or bank is closed.

The online [business-day calculator](https://make-a-calendar.com/business-days-calculator) is a useful manual comparison when its selected endpoint and holiday settings match your application.
