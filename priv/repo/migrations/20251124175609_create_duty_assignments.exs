defmodule NysSystem.Repo.Migrations.CreateDutyAssignments do
  use Ecto.Migration

  def change do
    create table(:duty_assignments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :duty_type, :string, null: false
      add :location, :string
      add :start_time, :utc_datetime, null: false
      add :end_time, :utc_datetime, null: false
      add :status, :string, default: "scheduled", null: false
      add :notes, :text

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :barrack_id, references(:barracks, type: :binary_id, on_delete: :delete_all),
        null: false

      add :assigned_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:duty_assignments, [:user_id])
    create index(:duty_assignments, [:barrack_id])
    create index(:duty_assignments, [:status])
    create index(:duty_assignments, [:start_time])
    create index(:duty_assignments, [:barrack_id, :status])
  end
end
