# Copyright (c) 2011 Key Curriculum Press
# All Rights Reserved

class Computer < ActiveRecord::Base
  belongs_to :first_activation, :class_name => "ActivationLog"
  belongs_to :last_activation, :class_name => "ActivationLog"
  belongs_to :authcodesid
  
  # Computer -> Computer
  # Finds an existing computer in the database matching the one given
  def Computer.same_computer(other)
      part = [""]
      #if new_log.sid && new_log.sid != ""
      #  part[0] = part[0] + " OR sid = ?"
      #  part = part + [new_log.sid]
      #end
      if other.hid1.blank? && other.hid2.blank? && other.mid1.blank? && other.mid2.blank?
        part = ["sid = ?", other.sid]
      else
        if other.hid1 && other.hid1 != ""
          part[0] = part[0] + " OR hid1 = ? OR hid2 = ?"
          part = part + [other.hid1, other.hid1]
        end
        if other.hid2 && other.hid2 != ""
          part[0] = part[0] + " OR hid1 = ? OR hid2 = ?"
          part = part + [other.hid2, other.hid2]
        end
        if other.mid1 && other.mid1 != ""
          part[0] = part[0] + " OR mid1 = ? OR mid2 = ?"
          part = part + [other.mid1, other.mid1]
        end
        if other.mid2 && other.mid2 != ""
          part[0] = part[0] + " OR mid1 = ? OR mid2 = ?"
          part = part + [other.mid2, other.mid2]
        end
        if part[0] == ""
          part[0] = "1 = 2" # Fail condition. All blank probably means spoofing anyway.
        else
          part[0] = part[0].slice(4..part[0].length)
        end
      end
      part[0] = "authorization_code = ? AND (#{part[0]})"
      part.insert(1, other.authorization_code)
      where_part = part
    # end
  #new_log.response_message = where_part;
  result = Computer.find(:first, :conditions => where_part)
  if result.nil?
    result
  else
    #logger.debug "same computer result: #{result}, #{result.license_name}"
    #logger.debug "Other license name #{other.license_name}: #{Authcode.same_license_name?(result.license_name, other.license_name)}"  
    Authcode.same_license_name?(result.license_name, other.license_name, other.authorization_code.length > 8) ? result : nil
  end
  end
  
  # authcode -> [[Computer], [Computer]]
  # Takes a license an returns of pair of active and non-active computers for that license
  def Computer.computers_for_ac(license)
    
    # If we store license server name in computer do this:
    # computers = Computer.find(:all, :conditions => ["license_name = ? AND authorization_code = ?", license.license_name, authorization_code])
    # If we store original name in computer, do this instead:

    logger.debug "license post-find: #{license}"

    computers = license.nil? ? [] : Computer.find(:all, :conditions => { :authcode_id => license.id }, :order => "last_activation_time DESC")
    #logger.debug "#{computers.length} Computers found"
    [computers.select { |comp| (comp.last_activation_time.nil? ? Time.now : comp.last_activation_time) + license.current_period.to_i.days > Time.now }, computers.reject { |comp| (comp.last_activation_time.nil? ? Time.now : comp.last_activation_time) + license.current_period.to_i.days > Time.now }]
  end
  
  # Computer -> Boolean
  # Compares two computers. Returns true if all entries are blank
  def ==(other)
    # If all hid and mid values are blank, compare on sid
    if self.hid1.blank? && self.hid2.blank? && self.mid1.blank? && self.mid2.blank? && other.hid1.blank? && other.hid2.blank? && other.mid1.blamk? && other.mid2.blank?
      (self.sid.blank? && other.sid.blank?) || (self.sid == other.sid)
    else
      ((!self.hid1.blank? && ((self.hid1 == other.hid1) ||
                               (self.hid1 == other.hid2))) ||
      (!self.hid2.blank? && ((self.hid2 == other.hid1) ||
                               (self.hid2 == other.hid2))) ||
      (!self.mid1.blank? && ((self.mid1 == other.mid1) ||
                               (self.mid1 == other.mid2))) ||
      (!self.mid2.blank? && ((self.mid2 == other.mid1) ||
                               (self.mid2 == other.mid2))))
    end # If mid and hid are blank
  end
  
  def Computer.test
    puts "test succeeded"
  end
  
  # Populates the computer table based on activation log entries
  # Should only be run from the console
  def Computer.populate_table
    
    authcode = Authcode.find(:all, :conditions => "current_active_registrations > 0")
    @count = 0
    @account = 0
    authcode.each do |ac|
      if !ac.nil?
        puts "Processing ac #{ac.license_name}, #{ac.code}"
        comps = ActivationLog.computers_for_ac(ac.code, ac.license_name)
        #puts "Current: #{comps[0].length}"
        #puts "Noncurrent: #{comps[1].length}"
        compproc = lambda do |thecomp|
          newcomp = thecomp[0].to_computer
          newcomp.first_activation_time = thecomp[1].request_at
          newcomp.first_activation = thecomp[1]
          newcomp.save()
          @count = @count + 1
        end
        comps[0].each(&compproc)
        comps[1].each(&compproc)
        @account = @account + 1
        if @account % 10 == 0 then puts "#{@account} License codes processed" end
        if @count % 20 == 0 then puts "#{@count} Computers created" end
      end
    end
    puts "#{@account} License codes processed"
    puts "#{@count} computers created"
  end
  
  # activation_log -> nil   
  # Accurately fixes and updates the number of active and non-active computers that match the given activation code
  # Should only be run from the console   
  def Computer.fix_counts(ac)
    comps = ActivationLog.computers_for_ac(ac.code, ac.license_name)
    #puts "Current: #{comps[0].length}"
    #puts "Noncurrent: #{comps[1].length}"
    compproc = lambda do |thecomp|
      newcomp = thecomp[0].to_computer
      newcomp.first_activation_time = thecomp[1].request_at
      newcomp.first_activation = thecomp[1]
      newcomp.save()
      
    end
    comps[0].each(&compproc)
    comps[1].each(&compproc)
  end
  
  # Updates this computer with its proper authcode
  # Helper method for console updates
  def populate_authcode_id
    self.authcode = Authcode.find_by_license_name_and_authorization_code(self.license_name, self.authorization_code)
    self.save()
    if self.id % 100 == 0 then puts "authcode_id added to computer #{self.id}" end
  end
  
end
