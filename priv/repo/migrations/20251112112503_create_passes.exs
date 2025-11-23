defmodule Nys.Repo.Migrations.CreatePasses do
  use Ecto.Migration

  def change do
    create table(:passes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :pass_number, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :departure_date, :date, null: false
      add :departure_time, :time, null: false
      add :return_date, :date, null: false
      add :return_time, :time, null: false
      add :reason, :text, null: false
      add :emergency_contact, :string, null: false
      add :emergency_phone, :string, null: false
      add :is_emergency, :boolean, default: false
      add :status, :string, default: "pending"
      # add :s1_approved_by, references(:users, type: :binary_id)
      add :s1_approved_at, :utc_datetime
      # add :commander_approved_by, references(:users, type: :binary_id)
      add :commander_approved_at, :utc_datetime
      # add :oc_approved_by, references(:users, type: :binary_id)
      add :oc_approved_at, :utc_datetime
      add :rejection_reason, :text

      add :s1_approved_by_id, references(:users, type: :binary_id)
      add :commander_approved_by_id, references(:users, type: :binary_id)
      add :oc_approved_by_id, references(:users, type: :binary_id)

      timestamps()
    end

    create unique_index(:passes, [:pass_number])
    create index(:passes, [:user_id])
    create index(:passes, [:status])
    create index(:passes, [:departure_date])
  end
end
