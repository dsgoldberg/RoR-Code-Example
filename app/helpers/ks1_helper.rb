# Copyright (c) 2011 Key Curriculum Press
# All Rights Reserved

module Ks1Helper
  #Helper format functions for displaying the extremem (max and min) elements, peak day, peak minute, peak activation code.
  
  
  def extreme_display(item)
    
    "<a href=\"/activation_logs/#{item.id}\">#{sprintf("%.4f", item.process_time)}</a>"
  end
  
  def peak_day_display(the_day)
    "#{h the_day.num } on #{h the_day.day }"
  end
  
  def peak_minute_display(the_minute)
    "#{h the_minute.num } at #{h the_minute.day } #{h the_minute.hour}:#{ the_minute.minute.to_i < 10 ? "0" : ""}#{h the_minute.minute}"
  end
  
  def peak_ac_display(the_ac)
    "#{h the_ac.num} from #{h the_ac.license_name }<br/> #{h the_ac.authorization_code }"
  end
  
  #nil becomes an html table cell with NA
  #othewise a table cell with its contents
  def nil_to_na(the_thing, the_lambda)
    the_thing.nil? ? "<td>NA</td>" : "<td>#{the_lambda.call(the_thing)}</td>"
  end
  
end
