defmodule NysSystem.Passes do
  import Ecto.Query
  alias NysSystem.Repo
  alias NysSystem.Passes.{Pass, PassPeriod}
  alias NysSystem.Accounts.User

  # O(1) - Direct database lookup with index
  def get_pass(id), do: Repo.get(Pass, id) |> Repo.preload(:user)

  # O(1) - Indexed lookup by pass_number
  def get_by_pass_number(pass_number) do
    Pass
    |> where([p], p.pass_number == ^pass_number)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      pass -> {:ok, Repo.preload(pass, :user)}
    end
  end

  # O(1) - Check if pass period is active (indexed query)
  def pass_period_active?(unit_id) do
    today = Date.utc_today()

    PassPeriod
    |> where([pp], pp.unit_id == ^unit_id and pp.is_active == true)
    |> where([pp], pp.start_date <= ^today and pp.end_date >= ^today)
    |> Repo.exists?()
  end

  def list_user_passes(user_id) do
    Pass
    |> where([p], p.user_id == ^user_id)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
    |> Repo.preload(:user)
  end

  # List pending passes for a specific barrack (for company commanders)
  def list_pending_passes_by_barrack(barrack_id) do
    from(p in Pass,
      join: u in User,
      on: p.user_id == u.id,
      where: u.barrack_id == ^barrack_id and p.status in ["pending", "submitted_to_commander"],
      order_by: [desc: p.inserted_at],
      preload: [user: [:unit, :barrack]]
    )
    |> Repo.all()
  end

  # List active passes for a specific barrack (personnel currently on leave)
  def list_active_passes_by_barrack(barrack_id) do
    today = Date.utc_today()

    from(p in Pass,
      join: u in User,
      on: p.user_id == u.id,
      where: u.barrack_id == ^barrack_id,
      where: p.status == "approved",
      where: p.departure_date <= ^today,
      where: p.return_date >= ^today,
      order_by: [asc: p.return_date],
      preload: [user: [:unit, :barrack]]
    )
    |> Repo.all()
  end

  # Check if commander is authorized to approve a pass (member is in their barrack)
  def can_commander_approve_pass?(pass_id, commander_barrack_id) do
    from(p in Pass,
      join: u in User,
      on: p.user_id == u.id,
      where: p.id == ^pass_id and u.barrack_id == ^commander_barrack_id,
      select: count(p.id)
    )
    |> Repo.one()
    |> Kernel.>(0)
  end

  # O(1) - Count with indexed query
  def count_passes_this_month(user_id) do
    start_of_month = Date.utc_today() |> Date.beginning_of_month()
    end_of_month = Date.utc_today() |> Date.end_of_month()

    Pass
    |> where([p], p.user_id == ^user_id)
    |> where([p], p.status in ["approved", "submitted_to_commander", "commander_approved"])
    |> where([p], p.departure_date >= ^start_of_month and p.departure_date <= ^end_of_month)
    |> where([p], p.is_emergency == false)
    |> Repo.aggregate(:count)
  end

  # # O(1) - Single insert with validation
  # def create_pass(attrs, user) do
  #   unit_id = user.unit_id

  #   with true <- pass_period_active?(unit_id) || attrs[:is_emergency],
  #        false <- count_passes_this_month(user.id) >= 1 || attrs[:is_emergency] do
  #     %Pass{}
  #     |> Pass.changeset(attrs)
  #     |> Repo.insert()
  #   else
  #     false -> {:error, :pass_period_inactive}
  #     true -> {:error, :monthly_limit_exceeded}
  #   end
  # end'
  def create_pass(attrs, user) do
    unit_id = user.unit_id
    is_emergency = attrs[:is_emergency] || false

    cond do
      !is_emergency && !pass_period_active?(unit_id) ->
        {:error, :pass_period_inactive}

      !is_emergency && count_passes_this_month(user.id) >= 1 ->
        {:error, :monthly_limit_exceeded}

      true ->
        %Pass{}
        |> Pass.changeset(attrs)
        |> Repo.insert()
    end
  end

  # O(1) - Single update operation for submission/approval
  # def submit_pass(%Pass{} = pass, submitter_id, role) when role in ["s1", "s2"] do
  #   # S1/S2 only submit passes to commander, they don't approve
  #   pass
  #   |> Ecto.Changeset.change(%{
  #     status: "submitted_to_commander",
  #     s1_approved_by_id: submitter_id,
  #     s1_approved_at: DateTime.utc_now()
  #   })
  #   |> Repo.update()
  # end

  # def approve_pass(%Pass{} = pass, approver_id, role) do
  #   changes =
  #     case role do
  #       "company_commander" ->
  #         %{
  #           status: "commander_approved",
  #           commander_approved_by_id: approver_id,
  #           commander_approved_at: DateTime.utc_now()
  #         }

  #       "oc" ->
  #         %{
  #           status: "approved",
  #           oc_approved_by_id: approver_id,
  #           oc_approved_at: DateTime.utc_now()
  #         }
  #     end

  #   pass
  #   |> Ecto.Changeset.change(changes)
  #   |> Repo.update()
  # end

  def submit_pass(%Pass{} = pass, submitter_id, role) when role in ["s1", "s2"] do
  # S1/S2 only submit passes to commander, they don't approve
  pass
  |> Ecto.Changeset.change(%{
    status: "submitted_to_commander",
    s1_approved_by_id: submitter_id,
    s1_approved_at: DateTime.truncate(DateTime.utc_now(), :second)
  })
  |> Repo.update()
end

def approve_pass(%Pass{} = pass, approver_id, role) do
  now = DateTime.truncate(DateTime.utc_now(), :second)

  changes =
    case role do
      "company_commander" ->
        %{
          status: "commander_approved",
          commander_approved_by_id: approver_id,
          commander_approved_at: now
        }

      "oc" ->
        %{
          status: "approved",
          oc_approved_by_id: approver_id,
          oc_approved_at: now
        }
    end

  pass
  |> Ecto.Changeset.change(changes)
  |> Repo.update()
end
  # O(1) - Single update operation
  def reject_pass(%Pass{} = pass, reason) do
    pass
    |> Ecto.Changeset.change(%{status: "rejected", rejection_reason: reason})
    |> Repo.update()
  end

  # O(n) where n = pending passes for role (optimized with indexes)
  def list_pending_passes(user_role, unit_id) do
    query =
      case user_role do
        role when role in ["s1", "s2"] ->
          # S1/S2 see passes pending their submission
          from p in Pass,
            join: u in User,
            on: p.user_id == u.id,
            where: u.unit_id == ^unit_id and p.status == "pending"

        "company_commander" ->
          # Commander sees passes submitted by S1/S2
          from p in Pass,
            join: u in User,
            on: p.user_id == u.id,
            where: u.unit_id == ^unit_id and p.status == "submitted_to_commander"

        "oc" ->
          # OC sees passes approved by commander
          from p in Pass,
            join: u in User,
            on: p.user_id == u.id,
            where: u.unit_id == ^unit_id and p.status == "commander_approved"

        _ ->
          from p in Pass, where: false
      end

    query |> Repo.all() |> Repo.preload(:user)
  end

  # O(1) - Single insert operation
  # def activate_pass_period(unit_id, start_date, end_date, activated_by_id) do
  #   # Deactivate existing periods - O(k) where k = active periods
  #   PassPeriod
  #   |> where([pp], pp.unit_id == ^unit_id and pp.is_active == true)
  #   |> Repo.update_all(set: [is_active: false])

  #   %PassPeriod{}
  #   |> PassPeriod.changeset(%{
  #     unit_id: unit_id,
  #     start_date: start_date,
  #     end_date: end_date,
  #     is_active: true,
  #     activated_by_id: activated_by_id
  #   })
  #   |> Repo.insert()
  # end
  def activate_pass_period(unit_id, start_date, end_date, activated_by) do
  PassPeriod
  |> where([pp], pp.unit_id == ^unit_id and pp.is_active == true)
  |> Repo.update_all(set: [is_active: false])

  %PassPeriod{}
  |> PassPeriod.changeset(%{
    unit_id: unit_id,
    start_date: start_date,
    end_date: end_date,
    is_active: true,
    activated_by: activated_by  # CHANGED from activated_by_id: to activated_by:
  })
  |> Repo.insert()
end

  # Verify barrack authorization for pass approval
  def verify_barrack_authorization(pass_id, commander_barrack_id) do
    case get_pass(pass_id) do
      nil ->
        {:error, :not_found}

      pass ->
        pass = Repo.preload(pass, user: [:barrack])

        if pass.user.barrack_id == commander_barrack_id do
          {:ok, pass}
        else
          {:error, :unauthorized}
        end
    end
  end

  # Add these functions to your NysSystem.Passes module

  # List passes awaiting OC approval (commander_approved status)
  def list_passes_awaiting_oc_approval(unit_id) do
    from(p in Pass,
      join: u in User,
      on: p.user_id == u.id,
      where: u.unit_id == ^unit_id,
      where: p.status == "commander_approved",
      order_by: [desc: p.commander_approved_at],
      preload: [user: [:unit, :barrack]]
    )
    |> Repo.all()
  end

  # List all active passes in a unit (all barracks)
  def list_active_passes_by_unit(unit_id) do
    today = Date.utc_today()

    from(p in Pass,
      join: u in User,
      on: p.user_id == u.id,
      where: u.unit_id == ^unit_id,
      where: p.status == "approved",
      where: p.departure_date <= ^today,
      where: p.return_date >= ^today,
      order_by: [asc: p.return_date],
      preload: [user: [:unit, :barrack]]
    )
    |> Repo.all()
  end

  # Verify unit authorization for OC
  def verify_unit_authorization(pass_id, oc_unit_id) do
    case get_pass(pass_id) do
      nil ->
        {:error, :not_found}

      pass ->
        pass = Repo.preload(pass, user: [:unit])

        if pass.user.unit_id == oc_unit_id do
          {:ok, pass}
        else
          {:error, :unauthorized}
        end
    end
  end
  # Add these two functions to your lib/nys_system/passes.ex file
# Add them at the end, right before the final 'end'

  # Get the active pass period for a unit
  def get_active_pass_period(unit_id) do
    PassPeriod
    |> where([p], p.unit_id == ^unit_id and p.is_active == true)
    |> order_by([p], desc: p.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  # Deactivate the current active pass period
  def deactivate_pass_period(unit_id) do
    case get_active_pass_period(unit_id) do
      nil ->
        {:error, :no_active_period}

      period ->
        period
        |> PassPeriod.changeset(%{is_active: false})
        |> Repo.update()
    end
  end

  # <-- This is the end of the module

end
