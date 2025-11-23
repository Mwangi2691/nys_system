defmodule NysSystem.Inventory.Item do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "inventory" do
    field :item_name, :string
    field :item_code, :string
    field :quantity, :integer, default: 0
    field :condition, :string
    field :last_checked_at, :utc_datetime

    belongs_to :barrack, NysSystem.Facilities.Barrack
    belongs_to :last_checked_by, NysSystem.Accounts.User

    timestamps()
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:item_name, :item_code, :quantity, :condition,
                    :barrack_id, :last_checked_by_id, :last_checked_at])
    |> validate_required([:item_name, :item_code, :barrack_id])
    |> validate_number(:quantity, greater_than_or_equal_to: 0)
    |> unique_constraint(:item_code, name: :inventory_item_code_barrack_id_index)
  end
end
