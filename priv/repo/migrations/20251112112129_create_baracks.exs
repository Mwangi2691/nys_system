defmodule Nys.Repo.Migrations.CreateBarracks do
  use Ecto.Migration

  def change do
    create table(:barracks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :capacity, :integer
      add :current_occupancy, :integer, default: 0
      add :unit_id, references(:units, type: :binary_id, on_delete: :restrict), null: false
      add :status, :string, default: "active"

      timestamps()
    end

    create index(:barracks, [:unit_id])
    create unique_index(:barracks, [:name, :unit_id])
  end
end
