defmodule NysSystem.Repo do
  use Ecto.Repo,
    otp_app: :nys_system,
    adapter: Ecto.Adapters.Postgres
end
