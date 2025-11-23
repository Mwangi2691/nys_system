defmodule NysSystem.Reports.Report do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @report_types ~w(daily_status incident personnel inventory)

  schema "reports" do
    field :report_type, :string
    field :content, :string
    field :report_date, :date

    belongs_to :barrack, NysSystem.Facilities.Barrack
    belongs_to :submitted_by, NysSystem.Accounts.User
    belongs_to :submitted_to, NysSystem.Accounts.User

    timestamps()
  end

  def changeset(report, attrs) do
    report
    |> cast(attrs, [:report_type, :content, :barrack_id, :submitted_by_id,
                    :submitted_to_id, :report_date])
    |> validate_required([:report_type, :content, :barrack_id, :submitted_by_id, :report_date])
    |> validate_inclusion(:report_type, @report_types)
  end
end
