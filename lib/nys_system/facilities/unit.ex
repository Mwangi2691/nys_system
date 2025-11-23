defmodule NysSystem.Facilities.Unit do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "units" do
    field :name, :string
    field :location, :string
    field :status, :string, default: "active"

    has_many :barracks, NysSystem.Facilities.Barrack
    has_many :users, NysSystem.Accounts.User
    has_many :pass_periods, NysSystem.Passes.PassPeriod

    timestamps()
  end

  def changeset(unit, attrs) do
    unit
    |> cast(attrs, [:name, :location, :status])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
