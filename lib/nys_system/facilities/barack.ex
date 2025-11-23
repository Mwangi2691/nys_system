defmodule NysSystem.Facilities.Barrack do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "barracks" do
    field :name, :string
    field :capacity, :integer
    field :current_occupancy, :integer, default: 0
    field :status, :string, default: "active"

    belongs_to :unit,NysSystem.Facilities.Unit

    has_many :users, NysSystem.Accounts.User
    has_many :inventory_items, NysSystem.Inventory.Item
    has_many :reports, NysSystem.Reports.Report

    timestamps()
  end

  def changeset(barrack, attrs) do
    barrack
    |> cast(attrs, [:name, :capacity, :current_occupancy, :unit_id, :status])
    |> validate_required([:name, :unit_id])
    |> validate_number(:capacity, greater_than: 0)
    |> validate_number(:current_occupancy, greater_than_or_equal_to: 0)
    |> unique_constraint(:name, name: :barracks_name_unit_id_index)
  end
end
