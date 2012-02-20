# Copyright (c) 2011 Key Curriculum Press
# All Rights Reserved

class Authcode < ActiveRecord::Base
  establish_connection "license_#{RAILS_ENV}"
  
  has_many :activation_logs
  has_many :computers

    # string, string -> authcode
    # Takes a license name and authorization code and finds the authcode that corresponds to it.
    # Returns nil if none found
    def Authcode.find_by_license_name_and_authorization_code(license_name, code)
      license = Authcode.find(:all, :conditions => { :code => code }).find { |curlicense| curlicense.same_license_name?(license_name) }
      if license.nil? then 
        logger.debug "No authcode found, looking at precodes"
        plicense = Precode.find(:first, :conditions => { :code => code })
        if !plicense.nil?
          logger.debug "Precode found: #{plicense}, looking for authcode with id #{plicense.authcode_id}"
          license = Authcode.find(plicense.authcode_id)
          if !license.nil? then license.code = plicense.code end
        end
      end
      license
    end
    
    # string -> bool
    # Takes a license name and determines whether this activation log shares that named based on format 0/1 whitespacing rules
    def same_license_name?(name)
      Authcode.same_license_name?(self.license_name, name, !self.code.nil? && self.code.length > 8)
    end

    # string, string, bool -> bool
    # Takes two strings and whether they are format 1 or not and determines whether they would be considered the same license name
    def Authcode.same_license_name?(name1, name2, format)
      if !name1.nil? && format
        logger.debug "Format 1 license name: #{name1}, #{name2}, #{name1.gsub(/\s/, '') == name2.gsub(/\s/, '')}"
        name1.gsub(/\s/, '') == name2.gsub(/\s/, '')
      else
        logger.debug "Format 0 license name: #{name1}, #{name2}, #{name1 == name2}"
        name1 == name2
      end
    end
    
end

