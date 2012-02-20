# Copyright (c) 2011 Key Curriculum Press
# All Rights Reservedrequire 'comm_consts'

class ActivationLog < ActiveRecord::Base
  
  include CommConsts
  
  has_one :first_activation_for, :class_name => "Computer", :foreign_key => "first_activation_id"
  has_one :last_activation_for, :class_name => "Computer", :foreign_key => "last_activation_id"
  belongs_to :authcode
  
  # ActivationLog -> ActivationLog
  # Given an ActivationLog, checks to see if the same computer has registered before
  # Returns the ActivationLog of that computer's last registration
  def ActivationLog.same_computer(new_log)
    ActivationLog.find(Computer.same_computer(new_log.to_computer).last_activation_id)

  end
  
  # string -> [[[activation_log, datetime]], [[activation_log, datetime]]
  # Takes an activation code an returns of pair of active and non-active computers (last activation record, first activation date) for that activation code
  def ActivationLog.computers_for_ac(authorization_code, license_name)
    #Wiggitywump
    license = Authcode.find(:all, :conditions => ["code = ?", authorization_code])
    if license.nil? then 
      plicense = Precode.find(:all, :conditions => { :code => authorization_code })
      if !plicense.nil?
        license = Authcode.find(plicense.authcode_id) 
      end
    end
    license = license.find { |curlicense| curlicense.same_license_name?(license_name) }
    acs = ActivationLog.all(:conditions => { :authorization_code => authorization_code }, :order => "request_at DESC").select { |curac| license.same_license_name?(curac.license_name) }

    # Create list of unique computers
    computers = ActivationLog.computer_sort(acs, [])
    # Split into active/non-active computers
    current_computers = computers.select do |comp| 
      (comp[0].request_at.nil? ? Time.now : comp[0].request_at) + license.current_period.to_i.days > Time.now
    end
    non_current_computers = computers.reject { |comp| (comp[0].request_at.nil? ? Time.now : comp[0].request_at) + license.current_period.to_i.days > Time.now }
    [current_computers, non_current_computers]
  end
  
  # [activation_log], [computer] -> [computer]
  # Turns all activation logs into a list of valid computers representing them
  # Should only be run from the console
  def ActivationLog.computer_sort(aclist, computers)

    if aclist.empty?
      computers
    else
      current_ac, *rest_ac = *aclist
      #if the last request was deactivate or reject, it's not an active computer - remove all instances and continue
      if (current_ac.request == LS_REQUEST_DEACTIVATE || current_ac.response == LS_RESPONSE_REJECT )
        ActivationLog.computer_sort(rest_ac.reject{ |cac| ActivationLog.same_computer?(current_ac, cac) }, computers )
      else
        # find first valid activation
        first_valid = current_ac
        #rest_ac.select{ |cac| ActivationLog.same_computer?(current_ac, cac) }.each{ |cac| if (cac.request == LS_REQUEST_ACTIVATE && cac.response == LS_RESPONSE_ALLOW && cac.local_registration == current_ac.local_registration) then first_valid = cac end }
        query = "license_name = ? AND authorization_code = '#{current_ac.authorization_code}' AND local_registration = '#{current_ac.local_registration.to_formatted_s(:db)}' AND request = '#{LS_REQUEST_ACTIVATE}' AND response = '#{LS_RESPONSE_ALLOW}'"
        #logger.debug "Query: #{query}"
        found = ActivationLog.find(:first, :conditions => [query, current_ac.license_name], :order => "request_at")
        if !found.nil? then first_valid = found end
        
        # Can remove all other instances of this computer from the list  
        ActivationLog.computer_sort( rest_ac.reject{ |cac| ActivationLog.same_computer?(current_ac, cac) }, computers << [current_ac, first_valid])
      end
#      computers_removed = rest_ac.reject{ |cac| ActivationLog.same_computer?(current_ac, cac) }
#      ActivationLog.computer_sort(computers_removed, computers)
    end      
  end
  
  # activation_log -> activation_log
  # Takes two activation logs and returns true if they represent log events for the same computer
  def ActivationLog.same_computer?(alog1, alog2)
    #logger.debug "Comparing: #{alog1.hid1} #{alog1.hid2} #{alog1.mid1} #{alog1.mid2} #{alog1.sid}"
    #logger.debug "           #{alog2.hid1} #{alog2.hid2} #{alog2.mid1} #{alog2.mid2} #{alog2.sid}"
    #result = 
    (alog1.hid1.blank? && alog1.hid2.blank? && alog1.mid1.blank? && alog1.mid2.blank? && 
     alog2.hid1.blank? && alog2.hid2.blank? && alog2.mid1.blank? && alog2.mid2.blank? &&
     alog1.sid == alog2.sid) ||
    (!alog1.hid1.blank? && ((alog1.hid1 == alog2.hid1) ||
                            (alog1.hid1 == alog2.hid2))) ||
    (!alog1.hid2.blank? && ((alog1.hid2 == alog2.hid1) ||
                            (alog1.hid2 == alog2.hid2))) ||
    (!alog1.mid1.blank? && ((alog1.mid1 == alog2.mid1) ||
                            (alog1.mid1 == alog2.mid2))) ||
    (!alog1.mid2.blank? && ((alog1.mid2 == alog2.mid1) ||
                            (alog1.mid2 == alog2.mid2)))
    #logger.debug "Result: #{result}"
    #result                       
  end
  
  # nil -> Computer
  # Returns the computer this activation log represents
  def to_computer
    Computer.new(
      :first_activation_time => self.request_at,
      :first_activation => self,
      :last_activation_time => self.request_at,
      :last_activation => self,
      :local_registration => self.local_registration,
      :license_name => self.license_name,
      :authorization_code => self.authorization_code,
      :mid1 => self.mid1,
      :mid2 => self.mid2,
      :hid1 => self.hid1,
      :hid2 => self.hid2,
      :sid => self.sid,
      :ip_address => self.ip_address,
      :version => self.version,
      :build => self.build,
      :os => self.os,
      :authcode => self.authcode
      )
  end
  
  # Updates this activation_log with its proper authcode
  # Helper method for console updates
  def populate_authcode_id
    self.authcode = Authcode.find_by_license_name_and_authorization_code(self.license_name, self.authorization_code)
    self.save()
    if self.id % 100 == 0 then puts "authcode_id added to activation_log #{self.id}" end
  end
  
  # number -> string
  # Returns the appropriate server response for this activation record
  def get_response_message(response_id)
    response = ServerResponse.find(:first, :conditions => {:product => self.product, :variant => self.variant, :license_family => self.license_family, :response_number => response_id})
    (response.nil? ? ServerResponse.find(:first, :conditions => {:product => "DEFAULT", :response_number => response_id}) : response).response_message
  end
end
