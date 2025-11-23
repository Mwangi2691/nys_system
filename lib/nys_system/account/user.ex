defmodule NysSystem.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @roles ~w(serviceman s1 s2 company_commander oc)
  @statuses ~w(active inactive on_leave)
  @genders ~w(male female other)

  schema "users" do
    field :service_number, :string
    field :id_number, :string
    field :first_name, :string
    field :last_name, :string
    field :phone_number, :string
    field :email, :string
    field :role, :string
    field :rank, :string
    field :gender, :string
    field :profile, :string
    field :password_hash, :string
    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true
    field :status, :string, default: "active"
    field :last_login, :utc_datetime

    belongs_to :barrack, NysSystem.Facilities.Barrack
    belongs_to :unit, NysSystem.Facilities.Unit

    has_many :passes, NysSystem.Passes.Pass
    has_many :submitted_reports, NysSystem.Reports.Report, foreign_key: :submitted_by

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :service_number,
      :id_number,
      :first_name,
      :last_name,
      :phone_number,
      :email,
      :role,
      :rank,
      :barrack_id,
      :unit_id,
      :password,
      :password_confirmation,
      :status,
      :gender,
      :profile
    ])
    |> validate_required([
      :service_number,
      :id_number,
      :first_name,
      :last_name,
      :phone_number,
      :email,
      :role,
      :password,
      :gender,
      :profile
    ])
    |> validate_inclusion(:role, @roles)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:gender, @genders)
    |> validate_format(:email, ~r/@/)
    |> validate_length(:password, min: 8)
    |> validate_confirmation(:password, message: "passwords do not match")
    |> unique_constraint(:service_number)
    |> unique_constraint(:id_number)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  defp put_password_hash(
         %Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset
       ) do
    put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset

  def full_names(user) do
    "#{user.first_name} #{user.last_name}"
  end
end
