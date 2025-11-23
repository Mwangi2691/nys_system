defmodule NysSystemWeb.CommanderController do
  use NysSystemWeb, :controller
  alias NysSystem.Accounts
  alias NysSystem.Passes
  alias NysSystem.Repo
  require Logger

  plug :require_commander_role

  def index(conn, _params) do
    user = NysSystemWeb.Auth.current_user(conn) |> Repo.preload([:unit, :barrack])

    # Ensure commander has a barrack assigned
    if is_nil(user.barrack_id) do
      conn
      |> put_flash(:error, "No barrack assigned to your account. Please contact administration.")
      |> redirect(to: "/dashboard")
      |> halt()
    else
      # Get all personnel from commander's barrack
      barrack_personnel =
        Accounts.list_users_by_barrack(user.barrack_id)
        |> Repo.preload([:unit])

      # Get pending pass requests for the barrack
      pending_pass_requests =
        Passes.list_pending_passes_by_barrack(user.barrack_id)
        |> Repo.preload([:user])

      # Get active/approved passes for the barrack
      active_passes =
        Passes.list_active_passes_by_barrack(user.barrack_id)
        |> Repo.preload([:user])

      # Calculate statistics
      total_personnel = length(barrack_personnel)
      on_pass = length(active_passes)
      pending_passes_count = length(pending_pass_requests)

      # Count servicemen and servicewomen
      servicemen = Enum.count(barrack_personnel, fn p -> p.gender == "male" end)
      servicewomen = Enum.count(barrack_personnel, fn p -> p.gender == "female" end)

      # On duty = total - on pass
      on_duty = total_personnel - on_pass

      barrack_stats = %{
        total_personnel: total_personnel,
        on_duty: on_duty,
        on_pass: on_pass,
        pending_passes: pending_passes_count,
        servicemen: servicemen,
        servicewomen: servicewomen
      }

      render(conn, :index,
        user: user,
        barrack: user.barrack,
        barrack_personnel: barrack_personnel,
        barrack_stats: barrack_stats,
        pending_pass_requests: pending_pass_requests,
        pending_pass_count: pending_passes_count,
        active_passes: active_passes
      )
    end
  end

  def member_details(conn, %{"id" => member_id}) do
    user = NysSystemWeb.Auth.current_user(conn)
    member = Accounts.get_user(member_id) |> Repo.preload([:unit, :barrack])

    # Verify member is in commander's barrack
    if member && member.barrack_id == user.barrack_id do
      member_passes = Passes.list_user_passes(member_id)
      month_pass_count = Passes.count_passes_this_month(member_id)

      render(conn, :member_details,
        member: member,
        member_passes: member_passes,
        month_pass_count: month_pass_count,
        current_user: user
      )
    else
      conn
      |> put_flash(:error, "Unauthorized: You can only view personnel in your barrack")
      |> redirect(to: "/commander")
    end
  end

  def show_pass(conn, %{"id" => pass_id}) do
    user = NysSystemWeb.Auth.current_user(conn)

    # Fetch the pass with preloaded user and relationships
    pass =
      Passes.get_pass(pass_id)
      |> Repo.preload(user: [:barrack, :unit])

    # Verify the pass belongs to the commander's barrack
    if pass.user.barrack_id != user.barrack_id do
      conn
      |> put_flash(:error, "You are not authorized to view this pass.")
      |> redirect(to: "/commander")
    else
      render(conn, "show_pass.html",
        pass: pass,
        user: user,
        barrack: user.barrack
      )
    end
  end

  def approve_pass(conn, %{"id" => pass_id}) do
    user = NysSystemWeb.Auth.current_user(conn)

    # Verify pass belongs to commander's barrack
    case Passes.verify_barrack_authorization(pass_id, user.barrack_id) do
      {:ok, pass} ->
        if pass.status in ["pending", "submitted_to_commander"] do
          case Passes.approve_pass(pass, user.id, "company_commander") do
            {:ok, _updated_pass} ->
              Logger.info(
                "Pass #{pass.pass_number} approved by commander #{user.service_number} for barrack #{user.barrack_id}"
              )

              conn
              |> put_flash(:info, "Pass approved successfully and forwarded to OC")
              |> redirect(to: "/commander")

            {:error, changeset} ->
              Logger.error("Failed to approve pass: #{inspect(changeset.errors)}")

              conn
              |> put_flash(:error, "Failed to approve pass")
              |> redirect(to: "/commander")
          end
        else
          conn
          |> put_flash(:error, "Pass cannot be approved in its current status")
          |> redirect(to: "/commander")
        end

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Pass not found")
        |> redirect(to: "/commander")

      {:error, :unauthorized} ->
        conn
        |> put_flash(
          :error,
          "Unauthorized: You can only approve passes for your barrack personnel"
        )
        |> redirect(to: "/commander")
    end
  end

  def reject_pass(conn, %{"id" => pass_id, "reason" => reason}) do
    user = NysSystemWeb.Auth.current_user(conn)

    # Verify pass belongs to commander's barrack
    case Passes.verify_barrack_authorization(pass_id, user.barrack_id) do
      {:ok, pass} ->
        if pass.status in ["pending", "submitted_to_commander"] do
          case Passes.reject_pass(pass, reason) do
            {:ok, _updated_pass} ->
              Logger.info(
                "Pass #{pass.pass_number} rejected by commander #{user.service_number} from barrack #{user.barrack_id}"
              )

              conn
              |> put_flash(:info, "Pass rejected")
              |> redirect(to: "/commander")

            {:error, _changeset} ->
              conn
              |> put_flash(:error, "Failed to reject pass")
              |> redirect(to: "/commander")
          end
        else
          conn
          |> put_flash(:error, "Pass cannot be rejected in its current status")
          |> redirect(to: "/commander")
        end

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Pass not found")
        |> redirect(to: "/commander")

      {:error, :unauthorized} ->
        conn
        |> put_flash(
          :error,
          "Unauthorized: You can only reject passes for your barrack personnel"
        )
        |> redirect(to: "/commander")
    end
  end

  defp require_commander_role(conn, _opts) do
    user = NysSystemWeb.Auth.current_user(conn)

    if user && user.role == "company_commander" do
      conn
    else
      conn
      |> put_flash(:error, "Access denied: Company Commander role required")
      |> redirect(to: "/dashboard")
      |> halt()
    end
  end
end
