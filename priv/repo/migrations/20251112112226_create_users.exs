defmodule Nys.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :profile, :string, null: false
      add :service_number, :string, null: false
      add :id_number, :string, null: false
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :phone_number, :string, null: false
      add :email, :string, null: false
      add :role, :string, null: false
      add :rank, :string
      add :gender, :string
      add :barrack_id, references(:barracks, type: :binary_id, on_delete: :restrict)
      add :unit_id, references(:units, type: :binary_id, on_delete: :restrict)
      add :password_hash, :string, null: false
      add :status, :string, default: "active"
      add :last_login, :utc_datetime

      timestamps()
    end

    create unique_index(:users, [:service_number])
    create unique_index(:users, [:id_number])
    create unique_index(:users, [:email])
    create index(:users, [:barrack_id])
    create index(:users, [:unit_id])
    create index(:users, [:role])
  end
end
