defmodule  Nys.Repo.Migrations.RenameLastCheckedByColumn do
  use Ecto.Migration

def change do
  alter table(:inventory) do
    add :last_checked_by_id, references(:users, type: :binary_id)
  end
end

end
