defmodule Nys.Repo.Migrations.CreateUnits do
  use Ecto.Migration

  def change do
    create table(:units, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :location, :string
      add :status, :string, default: "active"

      timestamps()
    end

    create unique_index(:units, [:name])
  end
end
