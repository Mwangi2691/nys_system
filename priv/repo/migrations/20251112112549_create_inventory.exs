defmodule Nys.Repo.Migrations.CreateInventory do
  use Ecto.Migration

  def change do
    create table(:inventory, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :item_name, :string, null: false
      add :item_code, :string, null: false
      add :quantity, :integer, default: 0
      add :condition, :string
      add :barrack_id, references(:barracks, type: :binary_id, on_delete: :delete_all), null: false
      add :last_checked_by, references(:users, type: :binary_id)
      add :last_checked_at, :utc_datetime

      timestamps()
    end

    create unique_index(:inventory, [:item_code, :barrack_id])
    create index(:inventory, [:barrack_id])
  end
end
