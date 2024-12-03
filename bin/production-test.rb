require 'norairrecord'

p Faraday::VERSION

Tea = Norairrecord.table(
  ENV["AIRTABLE_TOKEN"],
  "appZJC9q8TBYPDF7j",
  "Teas"
)

# p Tea.all
