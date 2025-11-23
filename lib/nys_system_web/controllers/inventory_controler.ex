defmodule NysSystemWeb.InventoryController do
  use NysSystemWeb, :controller
  alias NysSystem.Inventory
  alias NysSystemWeb.Auth

  plug :authenticate
  plug :require_commander when action in [:create, :update, :delete]

  def index(conn, %{"barrack_id" => barrack_id}) do
    items = Inventory.list_by_barrack(barrack_id)
    json(conn, %{items: Enum.map(items, &format_item/1)})
  end

  def create(conn, %{"item" => item_params}) do
    case Inventory.create_item(item_params) do
      {:ok, item} ->
        conn
        |> put_status(:created)
        |> json(%{success: true, item: format_item(item)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
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

  defp require_commander(conn, _opts) do
    user = Auth.current_user(conn)
    if user && user.role == "company_commander" do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Commander access required"})
      |> halt()
    end
  end

  defp format_item(item) do
    %{
      id: item.id,
      item_name: item.item_name,
      item_code: item.item_code,
      quantity: item.quantity,
      condition: item.condition,
      barrack_id: item.barrack_id
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
