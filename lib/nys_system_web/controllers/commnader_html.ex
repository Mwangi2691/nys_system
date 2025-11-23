defmodule NysSystemWeb.CommanderHTML do
  use NysSystemWeb, :html

  embed_templates "commander_html/*"

  def format_date(nil), do: "N/A"
  def format_date(date) do
    Calendar.strftime(date, "%B %d, %Y")
  end

  def format_datetime(nil), do: "N/A"
  def format_datetime(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end

  def status_badge_class(status) do
    case status do
      "approved" -> "bg-green-100 text-green-800"
      "submitted_to_commander" -> "bg-yellow-100 text-yellow-800"
      "commander_approved" -> "bg-blue-100 text-blue-800"
      "rejected" -> "bg-red-100 text-red-800"
      "pending" -> "bg-gray-100 text-gray-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  def role_badge_class(role) do
    case role do
      "company_commander" -> "bg-purple-100 text-purple-800"
      "oc" -> "bg-indigo-100 text-indigo-800"
      "s1" -> "bg-blue-100 text-blue-800"
      "s2" -> "bg-cyan-100 text-cyan-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end
end
