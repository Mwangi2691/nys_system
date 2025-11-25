defmodule NysSystem.Duties.Assignment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "duty_assignments" do
    field :duty_type, :string  # "guard", "patrol", "admin", "maintenance", "training"
    field :location, :string
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime
    field :status, :string, default: "scheduled"  # "scheduled", "active", "completed", "missed"
    field :notes, :string

    belongs_to :user, NysSystem.Accounts.User
    belongs_to :barrack, NysSystem.Facilities.Barrack
    belongs_to :assigned_by, NysSystem.Accounts.User

    timestamps()
  end

  def changeset(assignment, attrs) do
    assignment
    |> cast(attrs, [
      :duty_type, :location, :start_time, :end_time,
      :status, :notes, :user_id, :barrack_id, :assigned_by_id
    ])
    |> validate_required([:duty_type, :start_time, :end_time, :user_id, :barrack_id])
    |> validate_inclusion(:duty_type, ["guard", "patrol", "admin", "maintenance", "training", "other"])
    |> validate_inclusion(:status, ["scheduled", "active", "completed", "missed", "cancelled"])
    |> validate_time_order()
  end

  defp validate_time_order(changeset) do
    start_time = get_field(changeset, :start_time)
    end_time = get_field(changeset, :end_time)

    if start_time && end_time && DateTime.compare(start_time, end_time) != :lt do
      add_error(changeset, :end_time, "must be after start time")
    else
      changeset
    end
  end
end
