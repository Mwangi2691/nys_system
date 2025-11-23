defmodule NysSystemWeb.PageController do
  use NysSystemWeb, :controller
  alias NysSystem.Accounts
  alias NysSystem.Passes
  alias NysSystem.Repo
  alias NysSystemWeb.Auth
  import Ecto.Query

  def index(conn, _params) do
    if Auth.authenticated?(conn) do
      redirect(conn, to: "/dashboard")
    else
      redirect(conn, to: "/login")
    end
  end

  def login(conn, _params) do
    if Auth.authenticated?(conn) do
      redirect(conn, to: "/dashboard")
    else
      render(conn, "login.html")
    end
  end

  def signup(conn, _params) do
    if Auth.authenticated?(conn) do
      redirect(conn, to: "/dashboard")
    else
      units = Accounts.list_units()
      barracks = Accounts.list_barracks()
      changeset = Accounts.change_user(%NysSystem.Accounts.User{})
      render(conn, "signup.html", changeset: changeset, units: units, barracks: barracks)
    end
  end

  def create_account(conn, %{"user" => user_params}) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        conn
        |> Auth.login(user)
        |> put_flash(:info, "Account created successfully! Welcome to NYS.")
        |> redirect(to: "/dashboard")

      {:error, changeset} ->
        conn
        |> put_flash(:error, "Failed to create account")
        |> then(fn conn ->
          units = Accounts.list_units()
          barracks = Accounts.list_barracks()
          render(conn, "signup.html", changeset: changeset, units: units, barracks: barracks)
        end)
    end
  end

  # UPDATED DASHBOARD FUNCTION - This is the key change!
  def dashboard(conn, _params) do
    user =
      Auth.current_user(conn)
      |> Repo.preload([:barrack, :unit])

    if user do
      case user.role do
        "company_commander" ->
          render_commander_dashboard(conn, user)

        _ ->
          render_serviceperson_dashboard(conn, user)
      end
    else
      redirect(conn, to: "/login")
    end
  end

  def verify(conn, _params) do
    render(conn, :verify)
  end

  # PRIVATE HELPER FUNCTIONS - Add these!
  defp render_serviceperson_dashboard(conn, user) do
    # Fetch user's passes
    user_passes = Passes.list_user_passes(user.id)

    # Calculate statistics
    stats = %{
      total_passes: length(user_passes),
      pending_passes: Enum.count(user_passes, &(&1.status == "pending")),
      approved_passes: Enum.count(user_passes, &(&1.status in ["approved", "commander_approved"]))
    }

    # Get recent passes (last 5)
    recent_passes = Enum.take(user_passes, 5)

    # Mock notifications (you can implement a real notifications system later)
    pending_notifications = []

    render(conn, "dashboard.html",
      user: user,
      stats: stats,
      recent_passes: recent_passes,
      pending_notifications: pending_notifications,
      layout: false
    )
  end

defp render_commander_dashboard(conn, user) do
  # Get barrack information
  barrack = user.barrack || %{name: "Not Assigned", id: nil}

  # Get all personnel in the commander's barrack only
  barrack_personnel = if barrack.id do
    Repo.all(
      from u in NysSystem.Accounts.User,
      where: u.barrack_id == ^barrack.id,
      preload: [:unit, :barrack],
      order_by: [asc: u.service_number]
    )
  else
    []
  end

  # Get pending pass requests ONLY for people in this barrack
  pending_pass_requests = if barrack.id do
    Passes.list_pending_passes_by_barrack(barrack.id)
  else
    []
  end

  # Get currently active passes (people on pass) from this barrack only
  active_passes = if barrack.id do
    today = Date.utc_today()
    Repo.all(
      from p in NysSystem.Passes.Pass,
      join: u in assoc(p, :user),
      where: u.barrack_id == ^barrack.id and
             p.status == "approved" and
             p.departure_date <= ^today and
             p.return_date >= ^today,
      preload: [user: [:unit, :barrack]],
      order_by: [asc: p.return_date]
    )
  else
    []
  end

  # Calculate barrack statistics
  barrack_stats = %{
    total_personnel: length(barrack_personnel),
    servicemen: Enum.count(barrack_personnel, &(&1.gender == "male")),
    servicewomen: Enum.count(barrack_personnel, &(&1.gender == "female")),
    on_pass: length(active_passes),
    on_duty: length(barrack_personnel) - length(active_passes),
    pending_passes: length(pending_pass_requests)
  }

  pending_pass_count = length(pending_pass_requests)

  render(conn, "commander_dashboard.html",
    user: user,
    barrack: barrack,
    barrack_stats: barrack_stats,
    barrack_personnel: barrack_personnel,
    pending_pass_requests: pending_pass_requests,
    active_passes: active_passes,
    pending_pass_count: pending_pass_count,
    layout: false
  )
end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end
end
