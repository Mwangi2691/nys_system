defmodule NysSystem.Inventory do
  alias NysSystem.Repo
  alias NysSystem.Inventory.Item
  import Ecto.Query

  # List all items in a barrack
  def list_by_barrack(barrack_id) do
    Item
    |> where([i], i.barrack_id == ^barrack_id)
    |> order_by([i], asc: i.item_name)
    |> preload(:last_checked_by)
    |> Repo.all()
  end

  # Get single item
  def get_item(id) do
    Item
    |> Repo.get(id)
    |> case do
      nil -> nil
      item -> Repo.preload(item, [:last_checked_by, :barrack])
    end
  end

  # Create item
  def create_item(attrs) do
    %Item{}
    |> Item.changeset(attrs)
    |> Repo.insert()
  end

  # Update item
  def update_item(%Item{} = item, attrs) do
    item
    |> Item.changeset(attrs)
    |> Repo.update()
  end

  # Delete item
  def delete_item(%Item{} = item) do
    Repo.delete(item)
  end

  # Get inventory statistics for a barrack
  def get_barrack_inventory_stats(barrack_id) do
    items = list_by_barrack(barrack_id)

    %{
      total_items: length(items),
      total_quantity: Enum.sum(Enum.map(items, & &1.quantity)),
      good_condition: Enum.count(items, &(&1.condition == "good")),
      fair_condition: Enum.count(items, &(&1.condition == "fair")),
      poor_condition: Enum.count(items, &(&1.condition == "poor")),
      needs_attention: Enum.count(items, &(&1.condition in ["fair", "poor"]))
    }
  end

  # Search inventory
  def search_inventory(barrack_id, search_term) do
    search = "%#{search_term}%"

    Item
    |> where([i], i.barrack_id == ^barrack_id)
    |> where([i], ilike(i.item_name, ^search) or ilike(i.item_code, ^search))
    |> order_by([i], asc: i.item_name)
    |> preload(:last_checked_by)
    |> Repo.all()
  end
end
