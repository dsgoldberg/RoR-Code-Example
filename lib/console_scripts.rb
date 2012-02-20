def populate_all_authcode_ids
  ActivationLog.all.each { |al| al.populate_authcode_id }
  puts "Finished populating Activation Logs"
  Computer.all.each { |c| c.populate_authcode_id }
  puts "Finished populating Computers"
end