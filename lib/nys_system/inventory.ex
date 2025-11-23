defmodule NysSystem.Inventory do
  alias NysSystem.Repo
  alias NysSystem.Inventory.Item
  import Ecto.Query

  # O(n) where n = items in barrack (optimized with index)
  def list_by_barrack(barrack_id) do
    Item
    |> where([i], i.barrack_id == ^barrack_id)
    |> Repo.all()
  end

  # O(1) - Single insert operation
  def create_item(attrs) do
    %Item{}
    |> Item.changeset(attrs)
    |> Repo.insert()
  end

  # O(1) - Single update operation
  def update_item(%Item{} = item, attrs) do
    item
    |> Item.changeset(attrs)
    |> Repo.update()
  end
end
