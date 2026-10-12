defmodule MakeACalendar.ChronoForge.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :make_a_calendar_chronoforge,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      description: "An Elixir calendar engine for business schedules, payroll, fiscal periods, conversions, SVG and iCalendar exports.",
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  def application, do: [extra_applications: [:logger]]

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      name: "make_a_calendar_chronoforge",
      licenses: ["MIT"],
      links: %{
        "Make a Calendar" => "https://make-a-calendar.com/",
        "Printable Monthly Calendars" => "https://make-a-calendar.com/monthly-calendars",
        "Online Date Tools" => "https://make-a-calendar.com/date-tools",
        "Business-Day Calculator" => "https://make-a-calendar.com/business-days-calculator",
        "4-4-5 Fiscal Calendar" => "https://make-a-calendar.com/445-calendar",
        "Calendar Date Converters" => "https://make-a-calendar.com/converters",
        "GitHub Source Code" => "https://github.com/makeacalendar/make-a-calendar-chronoforge",
        "Documentation" => "https://make-a-calendar-chronoforge.hexdocs.pm",
        "Changelog" => "https://github.com/makeacalendar/make-a-calendar-chronoforge/blob/main/CHANGELOG.md"
      },
      files: ~w(lib guides README.md LICENSE CHANGELOG.md mix.exs .formatter.exs)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: "https://github.com/makeacalendar/make-a-calendar-chronoforge",
      homepage_url: "https://make-a-calendar.com/",
      extras: ["README.md" | Path.wildcard("guides/*.md")],
      groups_for_extras: [
        "Getting Started": ["README.md", "guides/getting-started.md"],
        "Business Scheduling": ["guides/business-scheduling.md"],
        "Fiscal Planning": ["guides/fiscal-calendars.md"],
        "Formats and Exports": ["guides/formats-and-exports.md"],
        "Developer Integration": ["guides/batch-processing.md"]
      ],
      groups_for_modules: [
        "Calendar Core": [MakeACalendar.ChronoForge, MakeACalendar.ChronoForge.Grid],
        "Business Scheduling": [MakeACalendar.ChronoForge.BusinessDays, MakeACalendar.ChronoForge.Holidays, MakeACalendar.ChronoForge.Recurrence, MakeACalendar.ChronoForge.Payroll, MakeACalendar.ChronoForge.Shift],
        "Fiscal Planning": [MakeACalendar.ChronoForge.Retail445],
        "Formats and Exports": [MakeACalendar.ChronoForge.Conversions, MakeACalendar.ChronoForge.Formats, MakeACalendar.ChronoForge.ICS, MakeACalendar.ChronoForge.SVG],
        "Developer Integration": [MakeACalendar.ChronoForge.Batch]
      ]
    ]
  end
end
