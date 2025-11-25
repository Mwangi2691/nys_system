defmodule NysSystem.Accounts do
  import Ecto.Query
  alias NysSystem.Repo
  alias NysSystem.Accounts.User
  require Logger

  @doc """
  Authenticates a user by service number and ID number.
  Returns {:ok, user} if credentials are valid, {:error, reason} otherwise.
  O(1) - Indexed lookup
  """
  def authenticate(service_number, id_number)
      when is_binary(service_number) and is_binary(id_number) do
    Logger.debug("Attempting authentication for service_number: #{service_number}")

    user =
      User
      |> where([u], u.service_number == ^service_number)
      |> where([u], u.id_number == ^id_number)
      |> Repo.one()

    case user do
      nil ->
        Logger.warning(
          "Authentication failed: User not found for service_number: #{service_number}"
        )

        {:error, :invalid_credentials}

      %User{status: "inactive"} = user ->
        Logger.warning("Authentication failed: Account inactive for user: #{user.id}")
        {:error, :account_inactive}

      %User{} = user ->
        Logger.info("Authentication successful for user: #{user.id} (#{user.service_number})")

        # Update last login timestamp
        case update_last_login(user) do
          {:ok, updated_user} ->
            # Preload associations if needed
            updated_user = Repo.preload(updated_user, [:unit, :barrack])
            {:ok, updated_user}

          {:error, _changeset} ->
            Logger.error("Failed to update last_login for user: #{user.id}")
            # Still return success even if last_login update fails
            {:ok, user}
        end
    end
  end

  def authenticate(_service_number, _id_number) do
    Logger.error("Invalid authentication parameters - must be strings")
    {:error, :invalid_parameters}
  end

  # O(1) - Single update operation
  # defp update_last_login(user) do
  #   user
  #   |> Ecto.Changeset.change(%{last_login: DateTime.utc_now()})
  #   |> Repo.update()
  # end

  defp update_last_login(user) do
    timestamp =
      DateTime.utc_now()
      |> DateTime.truncate(:second)

    user
    |> Ecto.Changeset.change(%{last_login: timestamp})
    |> Repo.update()
  end

  @doc """
  Gets a single user by ID.
  O(1) - Direct database lookup with index
  """
  def get_user(id) when is_binary(id) do
    Repo.get(User, id)
  end

  def get_user(_id), do: nil

  @doc """
  Gets a single user by ID (raises if not found).
  O(1) - Direct database lookup with index
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a user by service number.
  O(1) - Indexed lookup by service_number
  """
  def get_by_service_number(service_number) do
    Repo.get_by(User, service_number: service_number)
  end

  @doc """
  Gets a user by service number (alternative name).
  O(1) - Indexed lookup
  """
  def get_user_by_service_number(service_number) do
    User
    |> where([u], u.service_number == ^service_number)
    |> Repo.one()
  end

  @doc """
  Creates a new user.
  O(1) - Single insert operation
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.
  O(1) - Single update operation
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns a changeset for tracking user changes.
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  @doc """
  Lists all users.
  O(n) where n = total users
  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Lists users by role.
  O(n) where n = users with role (optimized with index)
  """
  def list_users_by_role(role) do
    User
    |> where([u], u.role == ^role)
    |> Repo.all()
  end

  @doc """
  Lists users by barrack.
  O(n) where n = users in barrack (optimized with index)
  """
  def list_users_by_barrack(barrack_id) do
    User
    |> where([u], u.barrack_id == ^barrack_id)
    |> Repo.all()
  end

def list_users_by_barrack(barrack_id) do
  User
  |> where([u], u.barrack_id == ^barrack_id)
  |> order_by([u], asc: u.service_number)
  |> preload([:unit, :barrack])
  |> Repo.all()
end

  @doc """
  Activates a user account.
  O(1) - Single update operation
  """
  def activate_user(%User{} = user) do
    user
    |> Ecto.Changeset.change(%{status: "active"})
    |> Repo.update()
  end

  @doc """
  Deactivates a user account.
  O(1) - Single update operation
  """
  def deactivate_user(%User{} = user) do
    user
    |> Ecto.Changeset.change(%{status: "inactive"})
    |> Repo.update()
  end

  def list_units do
    NysSystem.Repo.all(NysSystem.Facilities.Unit)
  end

  def list_barracks do
    NysSystem.Repo.all(NysSystem.Facilities.Barrack)
  end
  # lib/nys_system/accounts/accounts.ex

def list_users_by_unit(unit_id, search_term \\ nil) do
  query = from u in User, where: u.unit_id == ^unit_id

  query =
    if search_term do
      search = "%#{search_term}%"
      from u in query,
        where: ilike(u.first_name, ^search) or
               ilike(u.last_name, ^search) or
               ilike(u.service_number, ^search)
    else
      query
    end

  Repo.all(query)
end
end
