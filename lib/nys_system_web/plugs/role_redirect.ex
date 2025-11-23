defmodule NysSystemWeb.Plugs.RoleRedirect do
  @moduledoc """
  Plug to automatically redirect users to their appropriate dashboard based on role.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    user = NysSystemWeb.Auth.current_user(conn)

    if user do
      redirect_based_on_role(conn, user)
    else
      conn
    end
  end

  defp redirect_based_on_role(conn, user) do
    # Only redirect if user is accessing the generic /dashboard route
    if conn.request_path == "/dashboard" do
      case user.role do
        "oc" ->
          conn
          |> redirect(to: "/oc")
          |> halt()

        "company_commander" ->
          conn
          |> redirect(to: "/commander")
          |> halt()

        "s1" ->
          conn
          |> redirect(to: "/s1")
          |> halt()

        "s2" ->
          conn
          |> redirect(to: "/s2")
          |> halt()

        "serviceman" ->
          # Servicemen stay on regular dashboard
          conn

        _ ->
          # Unknown role, stay on dashboard
          conn
      end
    else
      conn
    end
  end
end
