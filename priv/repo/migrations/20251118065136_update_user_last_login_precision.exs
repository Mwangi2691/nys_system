defmodule NysSystem.Repo.Migrations.UpdateUserLastLoginPrecision do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :last_login, :utc_datetime_usec
    end
  end
end
