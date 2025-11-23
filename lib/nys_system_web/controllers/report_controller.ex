defmodule NysSystemWeb.ReportController do
  use NysSystemWeb, :controller
  alias NysSystem.Reports
  alias NysSystemWeb.Auth

  plug :authenticate
  plug :require_s1_or_above when action in [:create]

  def create(conn, %{"report" => report_params}) do
    user = Auth.current_user(conn)
    report_params = Map.put(report_params, "submitted_by_id", user.id)

    case Reports.create_report(report_params) do
      {:ok, report} ->
        conn
        |> put_status(:created)
        |> json(%{success: true, report: format_report(report)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def index(conn, %{"barrack_id" => barrack_id}) do
    reports = Reports.list_by_barrack(barrack_id)
    json(conn, %{reports: Enum.map(reports, &format_report/1)})
  end

  defp authenticate(conn, _opts) do
    if Auth.authenticated?(conn) do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Authentication required"})
      |> halt()
    end
  end

  defp require_s1_or_above(conn, _opts) do
    user = Auth.current_user(conn)
    if user && user.role in ["s1", "s2", "company_commander", "oc"] do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "S1 or above access required"})
      |> halt()
    end
  end

  defp format_report(report) do
    %{
      id: report.id,
      report_type: report.report_type,
      content: report.content,
      report_date: report.report_date,
      barrack_id: report.barrack_id,
      submitted_by_id: report.submitted_by_id
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
