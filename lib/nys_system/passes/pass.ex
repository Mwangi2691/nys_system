defmodule NysSystem.Passes.Pass do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # @statuses ~w(pending submitted_to_commander commander_approved approved rejected cancelled)

  schema "passes" do
    field :pass_number, :string
    field :departure_date, :date
    field :departure_time, :time
    field :return_date, :date
    field :return_time, :time
    field :reason, :string
    field :emergency_contact, :string
    field :emergency_phone, :string
    field :is_emergency, :boolean, default: false
    field :status, :string, default: "pending"
    field :rejection_reason, :string

    field :s1_approved_at, :utc_datetime
    field :commander_approved_at, :utc_datetime
    field :oc_approved_at, :utc_datetime

    belongs_to :user, NysSystem.Accounts.User
    belongs_to :s1_approved_by, NysSystem.Accounts.User
    belongs_to :commander_approved_by, NysSystem.Accounts.User
    belongs_to :oc_approved_by, NysSystem.Accounts.User

    timestamps()
  end

  def changeset(pass, attrs) do
    pass
    |> cast(attrs, [:user_id, :departure_date, :departure_time, :return_date,
                    :return_time, :reason, :emergency_contact, :emergency_phone,
                    :is_emergency])
    |> validate_required([:user_id, :departure_date, :departure_time,
                          :return_date, :return_time, :reason,
                          :emergency_contact, :emergency_phone])
    |> validate_dates()
    |> put_pass_number()
  end

  defp validate_dates(changeset) do
    changeset
    |> validate_change(:return_date, fn :return_date, return_date ->
      departure_date = get_field(changeset, :departure_date)
      if departure_date && Date.compare(return_date, departure_date) == :lt do
        [return_date: "must be after departure date"]
      else
        []
      end
    end)
  end

  defp put_pass_number(changeset) do
    if get_field(changeset, :pass_number) do
      changeset
    else
      put_change(changeset, :pass_number, generate_pass_number())
    end
  end

  defp generate_pass_number do
    "NYS-" <>
    (:crypto.strong_rand_bytes(4) |> Base.encode16()) <>
    "-" <>
    to_string(System.system_time(:second))
  end
end
