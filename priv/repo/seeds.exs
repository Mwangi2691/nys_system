# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     NysSystem.Repo.insert!(%NysSystem.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
alias NysSystem.Facilities
alias NysSystem.Repo

# Create units
{:ok, nairobi_unit} = Facilities.create_unit(%{name: "Nairobi Holding Unit"})
{:ok, mombasa_unit} = Facilities.create_unit(%{name: "Mombasa Unit"})

# Create barracks
Facilities.create_barrack(%{name: "Alpha Barrack", unit_id: nairobi_unit.id})
Facilities.create_barrack(%{name: "Bravo Barrack", unit_id: nairobi_unit.id})
Facilities.create_barrack(%{name: "Charlie Barrack", unit_id: mombasa_unit.id})
