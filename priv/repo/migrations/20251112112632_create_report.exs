defmodule Nys.Repo.Migrations.CreateReports do
  use Ecto.Migration

  def change do
    create table(:reports, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :report_type, :string, null: false
      add :content, :text, null: false
      add :barrack_id, references(:barracks, type: :binary_id, on_delete: :delete_all), null: false
      add :submitted_by, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :submitted_to, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :report_date, :date, null: false

      timestamps()
    end

    create index(:reports, [:barrack_id])
    create index(:reports, [:submitted_by])
    create index(:reports, [:report_date])
  end
end
