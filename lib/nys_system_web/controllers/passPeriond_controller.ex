defmodule NysSystemWeb.PassPeriodController do
  use NysSystemWeb, :controller
  alias NysSystem.Passes
  alias NysSystemWeb.Auth

  plug :authenticate
  plug :require_oc when action in [:activate]

  def activate(conn, %{"unit_id" => unit_id, "start_date" => start_date, "end_date" => end_date}) do
    user = Auth.current_user(conn)

    with {:ok, start} <- Date.from_iso8601(start_date),
         {:ok, end_d} <- Date.from_iso8601(end_date),
         {:ok, period} <- Passes.activate_pass_period(unit_id, start, end_d, user.id) do
      json(conn, %{success: true, pass_period: format_period(period)})
    else
      {:error, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid dates or unable to activate period"})
    end
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

  defp require_oc(conn, _opts) do
    user = Auth.current_user(conn)
    if user && user.role == "oc" do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "OC access required"})
      |> halt()
    end
  end

  defp format_period(period) do
    %{
      id: period.id,
      unit_id: period.unit_id,
      start_date: period.start_date,
      end_date: period.end_date,
      is_active: period.is_active
    }
  end
end
