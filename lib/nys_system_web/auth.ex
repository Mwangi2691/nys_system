defmodule NysSystemWeb.Auth do
  import Plug.Conn
  alias NysSystem.Accounts

  @session_key "user_id"

  def login(conn, user) do
    conn
    |> put_session(@session_key, user.id)
    |> configure_session(renew: true)
  end

  def logout(conn) do
    configure_session(conn, drop: true)
  end

  def authenticated?(conn) do
    !!get_session(conn, @session_key)
  end

  def current_user(conn) do
    user_id = get_session(conn, @session_key)
    user_id && Accounts.get_user(user_id)
  end
end
