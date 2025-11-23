defmodule NysSystemWeb.AuthController do
  use NysSystemWeb, :controller
  alias NysSystem.Accounts
  alias NysSystemWeb.Auth

  def login(conn, %{"service_number" => service_number, "id_number" => id_number}) do
    case Accounts.authenticate(service_number, id_number) do
      {:ok, user} ->
        conn
        |> Auth.login(user)
        |> put_status(:ok)
        |> json(%{
          success: true,
          user: %{
            id: user.id,
            service_number: user.service_number,
            first_name: user.first_name,
            last_name: user.last_name,
            role: user.role,
            unit_id: user.unit_id,
            profile: user.profile
          }
        })

      {:error, _} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "Invalid credentials"})
    end
  end

  def signup(conn, %{"user" => user_params}) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        conn
        |> Auth.login(user)
        |> put_status(:created)
        |> json(%{
          success: true,
          user: %{
            id: user.id,
            service_number: user.service_number,
            first_name: user.first_name,
            last_name: user.last_name,
            role: user.role
          }
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{success: false, errors: format_errors(changeset)})
    end
  end

def logout(conn, _params) do
  conn
  |> Auth.logout()
  |> put_flash(:info, "You have been logged out.")
  |> redirect(to: "/login")
end


  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
