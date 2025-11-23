defmodule NysSystemWeb.UserController do
  use NysSystemWeb, :controller
  alias NysSystem.Accounts
  alias NysSystemWeb.Auth

  plug :authenticate when action in [:index, :show, :profile]
  plug :require_admin when action in [:create, :update, :new, :edit]

  def new(conn, _params) do
    changeset = Accounts.change_user(%Accounts.User{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User created successfully!")
        |> redirect(to: "/users/#{user}")

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def profile(conn, _params) do
    user = Auth.current_user(conn)
    render(conn, "profile.html", user: user)
  end

  def show(conn, %{"id" => id}) do
    case Accounts.get_user(id) do
      nil ->
        conn
        |> put_flash(:error, "User not found")
        |> redirect(to: ~p"/users")

      user ->
        render(conn, "show.html", user: user)
    end
  end

  def index(conn, params) do
    users = cond do
      Map.has_key?(params, "barrack_id") ->
        Accounts.list_users_by_barrack(params["barrack_id"])
      Map.has_key?(params, "unit_id") ->
        Accounts.list_users_by_unit(params["unit_id"])
      true ->
        Accounts.list_users()
    end

    render(conn, "index.html", users: users)
  end

  def edit(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    changeset = Accounts.change_user(user)
    render(conn, "edit.html", user: user, changeset: changeset)
  end

  def update(conn, %{"id" => id, "user" => user_params}) do
    user = Accounts.get_user!(id)

    case Accounts.update_user(user, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User updated successfully!")
        |> redirect(to: ~p"/users/#{user}")

      {:error, changeset} ->
        render(conn, "edit.html", user: user, changeset: changeset)
    end
  end

  defp authenticate(conn, _opts) do
    if Auth.authenticated?(conn) do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to view that page.")
      |> redirect(to: "/login")
      |> halt()
    end
  end

  defp require_admin(conn, _opts) do
    user = Auth.current_user(conn)

    if user && user.role in ["company_commander", "oc"] do
      conn
    else
      conn
      |> put_flash(:error, "Admin access required")
      |> redirect(to: "/profile")
      |> halt()
    end
  end
end
