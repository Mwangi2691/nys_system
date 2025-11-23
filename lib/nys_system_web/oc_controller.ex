defmodule NysSystemWeb.OCController do
  use NysSystemWeb, :controller
  alias NysSystem.Accounts
  alias NysSystem.Passes
  alias NysSystem.Facilities
  alias NysSystem.Repo
  require Logger

  plug :require_oc_role

  def index(conn, _params) do
    user = NysSystemWeb.Auth.current_user(conn) |> Repo.preload([:unit, :barrack])

    if is_nil(user.unit_id) do
      conn
      |> put_flash(:error, "No unit assigned to your account. Please contact administration.")
      |> redirect(to: "/dashboard")
      |> halt()
    else
      barracks = Facilities.list_barracks_by_unit(user.unit_id)
      unit_personnel = Accounts.list_users_by_unit(user.unit_id) |> Repo.preload([:unit, :barrack])

      # Get passes awaiting OC approval (only commander_approved status)
      pending_oc_approval =
        Passes.list_passes_awaiting_oc_approval(user.unit_id)
        |> Repo.preload([user: [:barrack]])

      active_passes =
        Passes.list_active_passes_by_unit(user.unit_id)
        |> Repo.preload([user: [:barrack]])

      # Get current pass period
      pass_period = Passes.get_active_pass_period(user.unit_id)

      total_personnel = length(unit_personnel)
      on_pass = length(active_passes)
      pending_oc_count = length(pending_oc_approval)
      servicemen = Enum.count(unit_personnel, fn p -> p.gender == "male" end)
      servicewomen = Enum.count(unit_personnel, fn p -> p.gender == "female" end)
      on_duty = total_personnel - on_pass

      barrack_stats =
        Enum.map(barracks, fn barrack ->
          barrack_personnel = Enum.filter(unit_personnel, fn p -> p.barrack_id == barrack.id end)
          barrack_active_passes = Enum.filter(active_passes, fn p -> p.user.barrack_id == barrack.id end)

          %{
            barrack: barrack,
            total: length(barrack_personnel),
            on_duty: length(barrack_personnel) - length(barrack_active_passes),
            on_pass: length(barrack_active_passes)
          }
        end)

      unit_stats = %{
        total_personnel: total_personnel,
        on_duty: on_duty,
        on_pass: on_pass,
        pending_oc_approval: pending_oc_count,
        servicemen: servicemen,
        servicewomen: servicewomen
      }

      render(conn, :index,
        user: user,
        unit: user.unit,
        barracks: barracks,
        unit_personnel: unit_personnel,
        unit_stats: unit_stats,
        barrack_stats: barrack_stats,
        pending_oc_approval: pending_oc_approval,
        pending_oc_count: pending_oc_count,
        active_passes: active_passes,
        pass_period: pass_period
      )
    end
  end

  def activate_pass_period(conn, %{"unit_id" => unit_id, "start_date" => start_date, "end_date" => end_date}) do
    user = NysSystemWeb.Auth.current_user(conn)

    # Verify OC has permission for this unit
    if user.unit_id != unit_id do
      conn
      |> put_flash(:error, "Unauthorized: You can only manage pass periods for your unit")
      |> redirect(to: "/oc")
    else
      with {:ok, start} <- Date.from_iso8601(start_date),
           {:ok, end_d} <- Date.from_iso8601(end_date),
           {:ok, _period} <- Passes.activate_pass_period(unit_id, start, end_d, user.id) do
        Logger.info("Pass period activated by OC #{user.service_number} for unit #{unit_id}")

        conn
        |> put_flash(:info, "Pass period activated successfully. Personnel can now apply for passes.")
        |> redirect(to: "/oc")
      else
        {:error, :invalid_dates} ->
          conn
          |> put_flash(:error, "Invalid dates: End date must be after start date")
          |> redirect(to: "/oc")

        {:error, :overlapping_period} ->
          conn
          |> put_flash(:error, "Cannot activate: There is already an active pass period")
          |> redirect(to: "/oc")

        {:error, _} ->
          conn
          |> put_flash(:error, "Failed to activate pass period")
          |> redirect(to: "/oc")
      end
    end
  end

  def deactivate_pass_period(conn, _params) do
    user = NysSystemWeb.Auth.current_user(conn)

    case Passes.deactivate_pass_period(user.unit_id) do
      {:ok, _} ->
        Logger.info("Pass period deactivated by OC #{user.service_number} for unit #{user.unit_id}")

        conn
        |> put_flash(:info, "Pass period deactivated. Personnel can no longer apply for passes.")
        |> redirect(to: "/oc")

      {:error, :no_active_period} ->
        conn
        |> put_flash(:error, "No active pass period to deactivate")
        |> redirect(to: "/oc")

      {:error, _} ->
        conn
        |> put_flash(:error, "Failed to deactivate pass period")
        |> redirect(to: "/oc")
    end
  end

  def approve_pass(conn, %{"id" => pass_id}) do
    user = NysSystemWeb.Auth.current_user(conn)

    case Passes.verify_unit_authorization(pass_id, user.unit_id) do
      {:ok, pass} ->
        if pass.status == "commander_approved" do
          case Passes.approve_pass(pass, user.id, "oc") do
            {:ok, updated_pass} ->
              Logger.info("Pass #{pass.pass_number} approved by OC #{user.service_number}")

              # Send approval email
              send_oc_approval_email(updated_pass, user)

              conn
              |> put_flash(:info, "Pass approved successfully. Personnel may now proceed.")
              |> redirect(to: "/oc")

            {:error, changeset} ->
              Logger.error("Failed to approve pass: #{inspect(changeset.errors)}")
              conn
              |> put_flash(:error, "Failed to approve pass")
              |> redirect(to: "/oc")
          end
        else
          conn
          |> put_flash(:error, "Pass must be approved by commander first")
          |> redirect(to: "/oc")
        end

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Pass not found")
        |> redirect(to: "/oc")

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "Unauthorized: You can only approve passes for your unit personnel")
        |> redirect(to: "/oc")
    end
  end

  def reject_pass(conn, %{"id" => pass_id, "reason" => reason}) do
    user = NysSystemWeb.Auth.current_user(conn)

    case Passes.verify_unit_authorization(pass_id, user.unit_id) do
      {:ok, pass} ->
        if pass.status == "commander_approved" do
          case Passes.reject_pass(pass, reason) do
            {:ok, updated_pass} ->
              Logger.info("Pass #{pass.pass_number} rejected by OC #{user.service_number}")

              # Send rejection email
              send_oc_rejection_email(updated_pass, user, reason)

              conn
              |> put_flash(:info, "Pass rejected")
              |> redirect(to: "/oc")

            {:error, _changeset} ->
              conn
              |> put_flash(:error, "Failed to reject pass")
              |> redirect(to: "/oc")
          end
        else
          conn
          |> put_flash(:error, "Pass must be commander-approved before OC can reject")
          |> redirect(to: "/oc")
        end

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Pass not found")
        |> redirect(to: "/oc")

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "Unauthorized: You can only reject passes for your unit personnel")
        |> redirect(to: "/oc")
    end
  end

  defp require_oc_role(conn, _opts) do
    user = NysSystemWeb.Auth.current_user(conn)

    if user && user.role == "oc" do
      conn
    else
      conn
      |> put_flash(:error, "Access denied: OC role required")
      |> redirect(to: "/dashboard")
      |> halt()
    end
  end

  # Email notification functions
  defp send_oc_approval_email(pass, approver) do
    Task.start(fn ->
      pass = Repo.preload(pass, [:user])

      # TODO: Replace with actual email service (e.g., Bamboo, Swoosh)
      IO.puts("=" |> String.duplicate(60))
      IO.puts("📧 PASS APPROVED - EMAIL NOTIFICATION")
      IO.puts("=" |> String.duplicate(60))
      IO.puts("To: #{pass.user.email}")
      IO.puts("Subject: Pass Request APPROVED - #{pass.pass_number}")
      IO.puts("")
      IO.puts("Dear #{pass.user.rank} #{pass.user.first_name} #{pass.user.last_name},")
      IO.puts("")
      IO.puts("Your pass request has been APPROVED by the Officer Commanding.")
      IO.puts("")
      IO.puts("Pass Details:")
      IO.puts("  Pass Number: #{pass.pass_number}")
      IO.puts("  Departure: #{pass.departure_date} at #{pass.departure_time}")
      IO.puts("  Return: #{pass.return_date} at #{pass.return_time}")
      IO.puts("  Reason: #{pass.reason}")
      IO.puts("")
      IO.puts("Approved by: #{approver.rank} #{approver.first_name} #{approver.last_name} (OC)")
      IO.puts("")
      IO.puts("You may now proceed with your leave. Please ensure you return on time.")
      IO.puts("")
      IO.puts("Safe travels!")
      IO.puts("=" |> String.duplicate(60))
    end)
  end

  defp send_oc_rejection_email(pass, rejector, reason) do
    Task.start(fn ->
      pass = Repo.preload(pass, [:user])

      # TODO: Replace with actual email service
      IO.puts("=" |> String.duplicate(60))
      IO.puts("PASS REJECTED - EMAIL NOTIFICATION")
      IO.puts("=" |> String.duplicate(60))
      IO.puts("To: #{pass.user.email}")
      IO.puts("Subject: Pass Request REJECTED - #{pass.pass_number}")
      IO.puts("")
      IO.puts("Dear #{pass.user.rank} #{pass.user.first_name} #{pass.user.last_name},")
      IO.puts("")
      IO.puts("Your pass request has been REJECTED by the Officer Commanding.")
      IO.puts("")
      IO.puts("Pass Details:")
      IO.puts("  Pass Number: #{pass.pass_number}")
      IO.puts("  Requested Departure: #{pass.departure_date}")
      IO.puts("  Requested Return: #{pass.return_date}")
      IO.puts("")
      IO.puts("Rejected by: #{rejector.rank} #{rejector.first_name} #{rejector.last_name} (OC)")
      IO.puts("")
      IO.puts("Reason for Rejection:")
      IO.puts("  #{reason}")
      IO.puts("")
      IO.puts("If you have questions, please contact your chain of command.")
      IO.puts("=" |> String.duplicate(60))
    end)
  end
end
