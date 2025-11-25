defmodule NysSystem.Duties do
  alias NysSystem.Repo
  alias NysSystem.Duties.Assignment
  import Ecto.Query

  # List all assignments for a barrack
  def list_by_barrack(barrack_id) do
    Assignment
    |> where([a], a.barrack_id == ^barrack_id)
    |> order_by([a], [desc: a.start_time])
    |> preload([:user, :assigned_by])
    |> Repo.all()
  end

  # List current/active assignments for a barrack
  def list_active_by_barrack(barrack_id) do
    now = DateTime.utc_now()

    Assignment
    |> where([a], a.barrack_id == ^barrack_id)
    |> where([a], a.status in ["scheduled", "active"])
    |> where([a], a.start_time <= ^now and a.end_time >= ^now)
    |> order_by([a], [asc: a.start_time])
    |> preload([:user, :assigned_by])
    |> Repo.all()
  end

  # List upcoming assignments for a barrack
  def list_upcoming_by_barrack(barrack_id, days \\ 7) do
    now = DateTime.utc_now()
    future = DateTime.add(now, days * 24 * 60 * 60, :second)

    Assignment
    |> where([a], a.barrack_id == ^barrack_id)
    |> where([a], a.status == "scheduled")
    |> where([a], a.start_time > ^now and a.start_time <= ^future)
    |> order_by([a], [asc: a.start_time])
    |> preload([:user, :assigned_by])
    |> Repo.all()
  end

  # List assignments for a specific user
  def list_user_assignments(user_id) do
    Assignment
    |> where([a], a.user_id == ^user_id)
    |> order_by([a], [desc: a.start_time])
    |> preload([:assigned_by, :barrack])
    |> Repo.all()
  end

  # Get current duty for a user
  def get_current_duty(user_id) do
    now = DateTime.utc_now()

    Assignment
    |> where([a], a.user_id == ^user_id)
    |> where([a], a.status in ["scheduled", "active"])
    |> where([a], a.start_time <= ^now and a.end_time >= ^now)
    |> order_by([a], [desc: a.start_time])
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> nil
      assignment -> Repo.preload(assignment, [:assigned_by, :barrack])
    end
  end

  # Create a new duty assignment
  def create_assignment(attrs) do
    %Assignment{}
    |> Assignment.changeset(attrs)
    |> Repo.insert()
  end

  # Update assignment
  def update_assignment(%Assignment{} = assignment, attrs) do
    assignment
    |> Assignment.changeset(attrs)
    |> Repo.update()
  end

  # Delete assignment
  def delete_assignment(%Assignment{} = assignment) do
    Repo.delete(assignment)
  end

  # Get assignment by ID
  def get_assignment(id) do
    Assignment
    |> Repo.get(id)
    |> case do
      nil -> nil
      assignment -> Repo.preload(assignment, [:user, :assigned_by, :barrack])
    end
  end

  # Count active duties in barrack
  def count_active_duties(barrack_id) do
    now = DateTime.utc_now()

    Assignment
    |> where([a], a.barrack_id == ^barrack_id)
    |> where([a], a.status in ["scheduled", "active"])
    |> where([a], a.start_time <= ^now and a.end_time >= ^now)
    |> Repo.aggregate(:count)
  end
end
