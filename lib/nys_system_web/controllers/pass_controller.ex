defmodule NysSystemWeb.PassController do
  use NysSystemWeb, :controller
  alias NysSystem.Passes
  alias NysSystemWeb.Auth
  alias NysSystem.Accounts
  alias NysSystem.Repo

  plug :authenticate when action in [:create, :index, :approve, :reject, :submit, :new]

  # Render the pass application form
  def new(conn, _params) do
    user = Auth.current_user(conn) |> Repo.preload([:unit, :barrack])

    # Check if user is assigned to a barrack
    if is_nil(user.barrack_id) do
      conn
      |> put_flash(:error, "You must be assigned to a barrack to apply for a pass. Please contact your administrator.")
      |> redirect(to: "/dashboard")
    else
      conn
      |> assign(:user, user)
      |> render(:new)
    end
  end

  def create(conn, %{"pass" => pass_params}) do
    user = Auth.current_user(conn) |> Repo.preload([:unit, :barrack])

    # Ensure user has a barrack assignment
    if is_nil(user.barrack_id) do
      conn
      |> put_flash(:error, "You must be assigned to a barrack to apply for a pass.")
      |> redirect(to: "/dashboard")
    else
      pass_params = Map.put(pass_params, "user_id", user.id)

      case Passes.create_pass(pass_params, user) do
        {:ok, pass} ->
          send_pass_notification(pass, user)

          conn
          |> put_flash(:info, "Pass application submitted successfully! Waiting for commander approval.")
          |> redirect(to: "/dashboard")

        {:error, :pass_period_inactive} ->
          conn
          |> put_flash(:error, "Pass period is not currently active. Please contact your unit administrator.")
          |> redirect(to: "/passes/new")

        {:error, :monthly_limit_exceeded} ->
          conn
          |> put_flash(:error, "You have already used your pass allocation for this month.")
          |> redirect(to: "/passes/new")

        {:error, changeset} ->
          conn
          |> put_flash(:error, "Failed to create pass. Please check the form and try again.")
          |> assign(:user, user)
          |> render(:new, changeset: changeset)
      end
    end
  end

  def index(conn, _params) do
    user = Auth.current_user(conn)

    passes =
      case user.role do
        role when role in ["serviceman", "s1", "s2"] ->
          Passes.list_user_passes(user.id)

        role when role in ["company_commander", "oc"] ->
          Passes.list_pending_passes(user.role, user.unit_id)

        _ ->
          []
      end

    json(conn, %{passes: Enum.map(passes, &format_pass/1)})
  end

  def show(conn, %{"pass_number" => pass_number}) do
    case Passes.get_by_pass_number(pass_number) do
      {:ok, pass} ->
        json(conn, %{pass: format_pass(pass)})

      {:error, :not_found} ->
        conn
        |> Plug.Conn.put_status(:not_found)
        |> json(%{error: "Pass not found"})
    end
  end

  # S1/S2 submit passes to commander (not approve)
  def submit(conn, %{"id" => id}) do
    user = Auth.current_user(conn)

    unless user.role in ["s1", "s2"] do
      conn
      |> Plug.Conn.put_status(:forbidden)
      |> json(%{error: "Only S1/S2 can submit passes"})
    end

    with {:ok, pass} <- get_pass_for_submission(id, user),
         {:ok, updated_pass} <- Passes.submit_pass(pass, user.id, user.role) do
      send_submission_notification(updated_pass, user)
      json(conn, %{success: true, pass: format_pass(updated_pass)})
    else
      {:error, :not_found} ->
        conn |> Plug.Conn.put_status(:not_found) |> json(%{error: "Pass not found"})

      {:error, :not_authorized} ->
        conn |> Plug.Conn.put_status(:forbidden) |> json(%{error: "Not authorized"})

      {:error, changeset} ->
        conn |> Plug.Conn.put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
    end
  end

  # Company Commander and OC approve passes
  def approve(conn, %{"id" => id}) do
    user = Auth.current_user(conn)

    unless user.role in ["company_commander", "oc"] do
      conn
      |> Plug.Conn.put_status(:forbidden)
      |> json(%{error: "Only Commander or OC can approve passes"})
    end

    with {:ok, pass} <- get_pass_for_approval(id, user),
         {:ok, updated_pass} <- Passes.approve_pass(pass, user.id, user.role) do
      send_approval_notification(updated_pass, user)
      json(conn, %{success: true, pass: format_pass(updated_pass)})
    else
      {:error, :not_found} ->
        conn |> Plug.Conn.put_status(:not_found) |> json(%{error: "Pass not found"})

      {:error, :not_authorized} ->
        conn |> Plug.Conn.put_status(:forbidden) |> json(%{error: "Not authorized"})

      {:error, changeset} ->
        conn |> Plug.Conn.put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
    end
  end

  def reject(conn, %{"id" => id, "reason" => reason}) do
    user = Auth.current_user(conn)

    unless user.role in ["company_commander", "oc"] do
      conn
      |> Plug.Conn.put_status(:forbidden)
      |> json(%{error: "Only Commander or OC can reject passes"})
    end

    with {:ok, pass} <- get_pass_for_approval(id, user),
         {:ok, updated_pass} <- Passes.reject_pass(pass, reason) do
      send_rejection_notification(updated_pass, user, reason)
      json(conn, %{success: true, pass: format_pass(updated_pass)})
    else
      {:error, :not_found} ->
        conn |> Plug.Conn.put_status(:not_found) |> json(%{error: "Pass not found"})

      {:error, :not_authorized} ->
        conn |> Plug.Conn.put_status(:forbidden) |> json(%{error: "Not authorized"})
    end
  end

  # Private functions
  defp authenticate(conn, _opts) do
    if Auth.authenticated?(conn) do
      conn
    else
      conn
      |> Plug.Conn.put_status(:unauthorized)
      |> json(%{error: "Authentication required"})
      |> halt()
    end
  end

  defp get_pass_for_submission(id, user) do
    case Passes.get_pass(id) do
      nil ->
        {:error, :not_found}

      pass ->
        if pass.status == "pending" && pass.user.unit_id == user.unit_id do
          {:ok, pass}
        else
          {:error, :not_authorized}
        end
    end
  end

  defp get_pass_for_approval(id, user) do
    case Passes.get_pass(id) do
      nil ->
        {:error, :not_found}

      pass ->
        if authorized_to_approve?(pass, user) do
          {:ok, pass}
        else
          {:error, :not_authorized}
        end
    end
  end

  defp authorized_to_approve?(pass, user) do
    case {pass.status, user.role} do
      {"submitted_to_commander", "company_commander"} -> true
      {"commander_approved", "oc"} -> true
      _ -> false
    end
  end

  defp format_pass(pass) do
    %{
      id: pass.id,
      pass_number: pass.pass_number,
      user: %{
        service_number: pass.user.service_number,
        first_name: pass.user.first_name,
        last_name: pass.user.last_name
      },
      departure_date: pass.departure_date,
      departure_time: pass.departure_time,
      return_date: pass.return_date,
      return_time: pass.return_time,
      reason: pass.reason,
      emergency_contact: pass.emergency_contact,
      emergency_phone: pass.emergency_phone,
      is_emergency: pass.is_emergency,
      status: pass.status,
      created_at: pass.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp send_pass_notification(pass, user) do
    Task.start(fn ->
      IO.puts("📧 Pass application notification")
      IO.puts("To: #{user.email}")
      IO.puts("Pass Number: #{pass.pass_number}")
      IO.puts("Status: Submitted to #{user.barrack.name} Commander for approval")
      IO.puts("Departure: #{pass.departure_date}")
      IO.puts("Return: #{pass.return_date}")
    end)
  end

  defp send_submission_notification(pass, submitter) do
    Task.start(fn ->
      user = Accounts.get_user(pass.user_id)
      IO.puts("📧 Pass submission notification")
      IO.puts("To: #{user.email}")
      IO.puts("Submitted by: #{submitter.first_name} #{submitter.last_name} (#{submitter.role})")
      IO.puts("Pass Number: #{pass.pass_number}")
      IO.puts("Status: Submitted to Company Commander")
    end)
  end

  defp send_approval_notification(pass, approver) do
    Task.start(fn ->
      user = Accounts.get_user(pass.user_id)
      IO.puts("📧 Pass approval notification")
      IO.puts("To: #{user.email}")
      IO.puts("Approved by: #{approver.first_name} #{approver.last_name} (#{approver.role})")
      IO.puts("Pass Number: #{pass.pass_number}")

      status_message =
        case pass.status do
          "commander_approved" -> "Commander approved, forwarded to OC"
          "approved" -> "Fully approved! You may proceed"
          _ -> "Status updated"
        end

      IO.puts("Status: #{status_message}")
    end)
  end

  defp send_rejection_notification(pass, rejector, reason) do
    Task.start(fn ->
      user = Accounts.get_user(pass.user_id)
      IO.puts("📧 Pass rejection notification")
      IO.puts("To: #{user.email}")
      IO.puts("Rejected by: #{rejector.first_name} #{rejector.last_name}")
      IO.puts("Reason: #{reason}")
    end)
  end
end
