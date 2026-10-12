defmodule MakeACalendar.ChronoForge.Formats do
  @moduledoc "HTML, CSV and JSON serializations for a generated month grid."

  @doc "Renders escaped month data as an HTML table."
  @spec html(map()) :: {:ok, binary()} | {:error, term()}
  def html(%{weeks: weeks, weekdays: weekdays, year: year, month: month}) do
    title = Calendar.strftime(Date.new!(year, month, 1), "%B %Y")
    headings = Enum.map_join(weekdays, "", &("<th scope=\"col\">#{escape(String.slice(Atom.to_string(&1), 0, 3))}</th>"))
    rows = Enum.map_join(weeks, "", fn week ->
      cells = Enum.map_join(week, "", fn
        %Date{} = date -> "<td><time datetime=\"#{Date.to_iso8601(date)}\">#{date.day}</time></td>"
        nil -> "<td aria-hidden=\"true\"></td>"
      end)
      "<tr>" <> cells <> "</tr>"
    end)
    {:ok, "<table class=\"chronoforge-calendar\"><caption>#{escape(title)}</caption><thead><tr>#{headings}</tr></thead><tbody>#{rows}</tbody></table>"}
  end
  def html(_), do: {:error, :invalid_calendar}

  @doc "Serializes the month matrix to CSV, with empty fields for dates outside the month."
  @spec csv(map()) :: {:ok, binary()} | {:error, term()}
  def csv(%{weeks: weeks, weekdays: weekdays}) do
    header = Enum.map_join(weekdays, ",", &(Atom.to_string(&1)))
    rows = Enum.map_join(weeks, "\r\n", fn week -> Enum.map_join(week, ",", fn
      %Date{} = date -> Date.to_iso8601(date)
      nil -> ""
    end) end)
    {:ok, header <> "\r\n" <> rows <> "\r\n"}
  end
  def csv(_), do: {:error, :invalid_calendar}

  @doc "Serializes a month grid as JSON without an external dependency."
  @spec json(map()) :: {:ok, binary()} | {:error, term()}
  def json(%{year: year, month: month, weekdays: weekdays, weeks: weeks}) do
    weekday_json = Enum.map_join(weekdays, ",", &json_string(Atom.to_string(&1)))
    week_json = Enum.map_join(weeks, ",", fn week ->
      "[" <> Enum.map_join(week, ",", fn
        %Date{} = date -> json_string(Date.to_iso8601(date))
        nil -> "null"
      end) <> "]"
    end)
    {:ok, "{\"year\":#{year},\"month\":#{month},\"weekdays\":[#{weekday_json}],\"weeks\":[#{week_json}]}"}
  end
  def json(_), do: {:error, :invalid_calendar}

  defp escape(value), do: value |> String.replace("&", "&amp;") |> String.replace("<", "&lt;") |> String.replace(">", "&gt;") |> String.replace("\"", "&quot;") |> String.replace("'", "&#39;")
  defp json_string(value) do
    escaped = value |> String.replace("\\", "\\\\") |> String.replace("\"", "\\\"") |> String.replace("\n", "\\n") |> String.replace("\r", "\\r") |> String.replace("\t", "\\t")
    "\"" <> escaped <> "\""
  end
end
