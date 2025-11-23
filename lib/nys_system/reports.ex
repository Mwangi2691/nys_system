defmodule NysSystem.Reports do
  alias NysSystem.Repo
  alias NysSystem.Reports.Report
  import Ecto.Query

  # O(n) where n = reports for barrack (optimized with index)
  def list_by_barrack(barrack_id) do
    Report
    |> where([r], r.barrack_id == ^barrack_id)
    |> order_by([r], desc: r.report_date)
    |> Repo.all()
  end

  # O(1) - Single insert operation
  def create_report(attrs) do
    %Report{}
    |> Report.changeset(attrs)
    |> Repo.insert()
  end
end
