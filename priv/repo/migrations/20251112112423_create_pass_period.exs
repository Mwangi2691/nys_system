defmodule Nys.Repo.Migrations.CreatePassPeriods do
  use Ecto.Migration

  def change do
    create table(:pass_periods, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :unit_id, references(:units, type: :binary_id, on_delete: :delete_all), null: false
      add :start_date, :date, null: false
      add :end_date, :date, null: false
      add :is_active, :boolean, default: false
      add :activated_by, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:pass_periods, [:unit_id])
    create index(:pass_periods, [:is_active])
  end
end
