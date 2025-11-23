defmodule NysSystem.Facilities do
  alias NysSystem.Repo
  alias NysSystem.Facilities.{Unit, Barrack}
  import Ecto.Query

  # O(1) - Direct database lookup
  def get_unit(id), do: Repo.get(Unit, id)
  def get_barrack(id), do: Repo.get(Barrack, id)

  # O(1) - Single insert operation
  def create_unit(attrs) do
    %Unit{}
    |> Unit.changeset(attrs)
    |> Repo.insert()
  end

  def list_units do
    Unit
    |> order_by(:name)
    |> Repo.all()
  end

  # O(1) - Single insert operation
  def create_barrack(attrs) do
    %Barrack{}
    |> Barrack.changeset(attrs)
    |> Repo.insert()
  end

  # O(n) where n = barracks in unit (optimized with index)
  def list_barracks_by_unit(unit_id) do
    Barrack
    |> where([b], b.unit_id == ^unit_id)
    |> Repo.all()
  end

  def get_unit_by_name(name), do: Repo.get_by(Unit, name: name)
  def get_barrack_by_name(name), do: Repo.get_by(Barrack, name: name)
end
