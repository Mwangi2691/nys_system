defmodule NysSystem.Passes.PassPeriod do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pass_periods" do
    field :start_date, :date
    field :end_date, :date
    field :is_active, :boolean, default: true
    field :activated_by, :binary_id  # Define as a regular field instead

    belongs_to :unit, NysSystem.Facilities.Unit

    timestamps()
  end

  def changeset(pass_period, attrs) do
    pass_period
    |> cast(attrs, [:unit_id, :start_date, :end_date, :is_active, :activated_by])
    |> validate_required([:unit_id, :start_date, :end_date])
    |> validate_date_range()
    |> foreign_key_constraint(:unit_id)
    |> foreign_key_constraint(:activated_by)
  end

  defp validate_date_range(changeset) do
    changeset
    |> validate_change(:end_date, fn :end_date, end_date ->
      start_date = get_field(changeset, :start_date)
      if start_date && Date.compare(end_date, start_date) == :lt do
        [end_date: "must be after start date"]
      else
        []
      end
    end)
  end
end
