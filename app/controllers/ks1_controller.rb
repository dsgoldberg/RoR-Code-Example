# Copyright (c) 2011 Key Curriculum Press
# All Rights Reserved


require 'comm_consts'
#require 'fastercsv'

class Ks1Controller < ApplicationController

  include CommConsts
  
  before_filter :set_default_response, :only => [:achistory, :activecomputers]

  # GET /ks1
  # Main DRM response handler - Gets called with the following parameters
  # command - LS_REQUEST_ACTIVATE or LS_REQUEST_DEACTIVATE
  # licenseName, licenseCode, localRegistrationTimeStamp - string
  # sysconfig - ;-separated string of pairs of type,value
  # localIP, licenseFamily, product, version, variant, build, os - string
  def index
    # TODO: Eventually split this out so it can be used by potentially multiple log requests
    if params[:command] == LS_REQUEST_ACTIVATE or params[:command] == LS_REQUEST_DEACTIVATE
      entry = ActivationLog.new()
      request_at = Time.now()
      entry.request_at = request_at
      entry.license_name = params[:licenseName]
      entry.authorization_code = params[:licenseCode]
      entry.request = params[:command]
      entry.local_registration = params[:localRegistrationTimeStamp]
      sysconfig = params[:sysConfig].split(";")
      sysconfig.each do |sysparam|
        values = sysparam.split(",")
        if values[0] == "MID1"
          entry.mid1 = values[1]
        elsif values[0] == "MID2"
          entry.mid2 = values[1]
        elsif values[0] == "HID1"
          entry.hid1 = values[1]
        elsif values[0] == "HID2"
          entry.hid2 = values[1]
        elsif values[0] == "SID"
          entry.sid = values[1]
        end # values check
      end # sysconfig do
      entry.ip_address = params[:localIP]
      entry.license_family = params[:licenseFamily]
      entry.product = params[:product]
      entry.version = params[:version]
      entry.variant = params[:variant]
      entry.build = params[:build]
      entry.os = params[:os]

      # Allow all by default
      entry.response = LS_RESPONSE_ALLOW
      entry.response_reason = ''
      entry.response_message = ''
      entry.number_of_computers = 0
      entry.server_contact_suppression = 0

      # Checks:
      # If activate?
      # => If exists?
      # => => If active?
      # => => => Has expired since last time?
      # => => => => Reject - Expired
      # => => => => If limit exceeded and enforced?
      # => => => => => Reject - RegistrationLimitExceeded
      # => => => Reject - Cancel/Misuse/Etc.
      # => => Reject - Unrecognized Code

        authcodes_found = Authcode.find(:all, :conditions => { :code => params[:licenseCode] })
        
        #logger.debug "#{authcodes_found.length} codes found for code #{params[:licenseCode]}"
        # Find a corresponding authorization code
        # Code is exact match.
        # If format 0, License name is exact match
        # If format 1, License name ignores white space
        
        
        authcode = authcodes_found.find { |curcode| curcode.same_license_name?( params[:licenseName] )}
        
        #logger.debug "AuthCode found for name #{params[:licenseName]}: #{authcode}"
        
        if authcode.nil? #|| !authcode.same_license_name?( params[:licenseName] )
          precode = Precode.find(:first, :conditions => { :code => params[:licenseCode] } )

          # If not authcode or precode found for the code then send a reject on activate (deactivates always succeed)
          if precode.nil?
            if params[:command] == LS_REQUEST_ACTIVATE
              
              
            
              entry.response = LS_RESPONSE_REJECT
              entry.response_reason = LS_RESPONSEREASON_UNRECOGNIZED
              entry.response_message = entry.get_response_message(LS_RESPONSE_ARRAY.index(LS_RESPONSEREASON_UNRECOGNIZED))
            end # if it is an activate requst  
          else
            # Precode exists - find out why and encode response
            last_computer = Computer.same_computer(entry.to_computer)
            if !last_computer.nil?
              Precode.update_counters(precode.id, :active_registrations => -1, :current_active_registrations => -1)
              last_computer.destroy()
            end
#            if !(last_activation.nil? || last_activation.request == LS_REQUEST_DEACTIVATE || last_activation.response == LS_RESPONSE_REJECT) then Precode.update_counters(precode.id, :active_registrations => -1, :current_active_registrations => -1) end
            if params[:command] == LS_REQUEST_ACTIVATE
              if precode.status == LS_STATUS_CANCELED
                entry.response = LS_RESPONSE_REJECT
                entry.response_reason = LS_RESPONSEREASON_CANCELED
                entry.response_message = entry.get_response_message(LS_RESPONSE_ARRAY.index(LS_RESPONSEREASON_CANCELED))
              elsif precode.status == LS_STATUS_MISUSED
                entry.response = LS_RESPONSE_REJECT
                entry.response_reason = LS_RESPONSEREASON_MISUSED
                entry.response_message = entry.get_response_message(LS_RESPONSE_ARRAY.index(LS_RESPONSEREASON_MISUSED))           
              elsif precode.status == LS_STATUS_EXPIRED
                entry.response = LS_RESPONSE_REJECT
                entry.response_reason = LS_RESPONSEREASON_EXPIRED
                entry.response_message = entry.get_response_message(LS_RESPONSE_ARRAY.index(LS_RESPONSEREASON_EXPIRED))
              else
                # Unknown status message
                entry.response_message = entry.get_response_message(LS_RESPONSE_ARRAY.index(LS_RESPONSEREASON_UNSPECIFIED)) #THIS_IS_AN_ERROR
              end # Check precode status
            end # if it is an activate request
          end # if precode.nil?
        else # authcode found
          entry.authcode = authcode
          entry.server_contact_suppression = authcode.server_contact_suppression
          #entry.license_name = authcode.license_name - No, logs should have license name the person used (or tried to)
          if authcode.suppress_number_computers == LS_NO
             entry.number_of_computers = authcode.number_computers.to_i + authcode.extra_computers.to_i + authcode.additional_computers.to_i
          end
          
          if authcode.expiration_date && (Date.today > authcode.expiration_date)
            authcode.status = LS_STATUS_EXPIRED
            entry.response = LS_RESPONSE_REJECT
            entry.response_reason = LS_RESPONSEREASON_EXPIRED
            entry.response_message = entry.get_response_message(LS_RESPONSE_ARRAY.index(LS_RESPONSEREASON_EXPIRED))
          else
            ucomputer = Computer.same_computer(entry.to_computer)
            last_activation = ucomputer.nil? ? nil : ActivationLog.find(ucomputer.last_activation_id)
             
            if last_activation.nil? || last_activation.request == LS_REQUEST_DEACTIVATE || last_activation.response == LS_RESPONSE_REJECT
              if params[:command] == LS_REQUEST_ACTIVATE              
                # New activation - see if it's allowed
                if CommConsts.s_to_bool?(authcode.registration_limit_enforced) && (authcode.licensed_registrations.to_i + authcode.additional_registrations.to_i < authcode.current_active_registrations.to_i + 1)
                  entry.response = LS_RESPONSE_REJECT
                  entry.response_reason = LS_RESPONSEREASON_LIMITEXCEEDED
                  entry.response_message = entry.get_response_message(LS_RESPONSE_ARRAY.index(LS_RESPONSEREASON_LIMITEXCEEDED))
                else
                  # Allowed - update registration count and create a new computer entry
                  Authcode.update_counters(authcode.id, :active_registrations => 1, :current_active_registrations => 1)
                  #logger.debug("Entry's id: #{entry.id}")
                  entry.to_computer.save()
                  
                end # authcode.registration_limit_enforced && number of computers < number of registrations                
              end # if response is activate
            else
              # Computer already exists. Update the last activation time (and last local time in case things changed on the local side) and decrement from the license server if it's a deactivate
              ucomputer.last_activation_time = entry.request_at
              ucomputer.last_activation = entry
              ucomputer.version = entry.version
              ucomputer.build = entry.build
              ucomputer.os = entry.os
              
              # If the local registration time has changed, make this the first activation
              if ucomputer.local_registration < entry.local_registration
                ucomputer.first_activation_time = entry.request_at
                ucomputer.first_activation = entry
                ucomputer.local_registration = entry.local_registration
              end
              
              if params[:command] == LS_REQUEST_DEACTIVATE
                if authcode.current_active_registrations.to_i > 0 || authcode.active_registrations.to_i > 0
                  #if last_activation.request_at + authcode.current_period.to_i.days < Time.now
                  #  Authcode.update_counters(authcode.id, :active_registrations => -1)
                  #else
                    Authcode.update_counters(authcode.id, :active_registrations => -1, :current_active_registrations => -1)
                    ucomputer.destroy()
                  #end # if last request + current period is before today
                end # if current_active_registrations > 0
              else
                #  if last_activation.request_at + authcode.current_period.to_i.days < Time.now
                #    Authcode.update_counters(authcode.id, :current_active_registrations => 1)
                #  end
                ucomputer.save()
              end # if command is deactivate
              
            end # if last_activation.nil?
          end # Check date
         
          # Unnecessary - number of computers update is done atomically
          # authcode.save()

        end # authcode.nil?





      # Update timestamp and send
      response_at = Time.now()
      entry.process_time = response_at - request_at
      entry.response_at = response_at
      entry.save()
      
      render :json => {:response => entry.response, 
                       :responseReason => entry.response_reason, 
                       :responseMessage => entry.response_message, 
                       :numComputers => entry.number_of_computers.to_i,
                       :serverContactSuppression => entry.server_contact_suppression } and return
    else
      
      render :json => {:response => LS_RESPONSE_ERROR, 
                       :responseReason => LS_RESPONSE_UNSPECIFIED, 
                       :responseMessage => "Received non Activate/Deactivate message", 
                       :numComputers => nil,
                       :serverContactSuppression => nil } and return                   
    end # if activate or deactivate

      


                     
    
  end

  # GET /ks1/activecomputers?code=XXX&license_name=YYY&current=#
  # Returns json or csv list of all active computers for the given code and license name and whether they are current or not
  def activecomputers

    #activecomputers = ActivationLog.computers_for_ac(params[:code], params[:license_name])
    license = 
      if params[:id].nil?
        Authcode.find_by_license_name_and_authorization_code(params[:license_name], params[:code])
      else
        Authcode.find(params[:id])
      end
    computer = Computer.computers_for_ac(license)
    @complist = params[:current].to_i != 0 ? computer[0] : computer[1]
    
    
    respond_to do |format|
      
      
      format.csv do
        #filename = "#{params[:license_name]}.csv"
        filename = 'activecomputers.csv'
        if request.env['HTTP_USER_AGENT'] =~ /msie/i
          header['Pragma'] = 'public'
          headers["Content-type"] = "text/plain" 
          headers['Cache-Control'] = 'no-cache, must-revalidate, post-check=0, pre-check=0'
          headers['Content-Disposition'] = "attachment; filename=\"#{filename}\"" 
          headers['Expires'] = "0" 
        else
          headers["Content-Type"] ||= 'text/csv'
          headers["Content-Disposition"] = "attachment; filename=\"#{filename}\"" 
        end

        render :layout => false
        
      end # format.csv
    
      format.json {
       render :json => #{
#        :status => 0,
#        :totalRows => @complist.length,
#      :activecomputers => activecomputers,
#        :data => 
          @complist.map { |comp| {
#        :active => comp[0].request_at + 365.days,
        :first_activation => comp.first_activation_time,
        :last_activation => comp.last_activation_time,
        :local_registration => comp.local_registration,
        :mid1 => comp.mid1,
        :mid2 => comp.mid2,
        :hid1 => comp.hid1,
        :hid2 => comp.hid2,
        :sid => comp.sid,
        :ip_address => comp.ip_address,
        :version => comp.version,
        :build => comp.build,
        :os => comp.os        
        }}
#      }
    }
    end # respond_to
  end #activecomputers 

  # GET /ks1/achistory?code=XXX&license_name=YYY
  # Returns json or csv list of all events for the given code and license name
  def achistory
    
    @logs = 
      if params[:id].nil? 
        ActivationLog.find(:all, :conditions => { :authorization_code => params[:code] }, :order => "request_at DESC").select {
          |curlog| Authcode.new(:code => params[:code], :license_name => params[:license_name]).same_license_name?(curlog.license_name)
        }
      else
        ActivationLog.find(:all, :conditions => { :authcode_id => params[:id] }, :order => "request_at DESC")
      end
      
    respond_to do |format|
      
      
      format.csv do
        filename = "#{params[:license_name]}.csv"
        if request.env['HTTP_USER_AGENT'] =~ /msie/i
          header['Pragma'] = 'public'
          headers["Content-type"] = "text/plain" 
          headers['Cache-Control'] = 'no-cache, must-revalidate, post-check=0, pre-check=0'
          headers['Content-Disposition'] = "attachment; filename=\"#{filename}\"" 
          headers['Expires'] = "0" 
        else
          headers["Content-Type"] ||= 'text/csv'
          headers["Content-Disposition"] = "attachment; filename=\"#{filename}\"" 
        end

        render :layout => false
        
      end # format.csv
                                                
      format.json {
        render :json => #{ #:status => 0,
#                      :totalRows => @logs.length,
#                      :data => 
                      @logs.map { |log| { :request_at => log.request_at, 
                                                    :response_at => log.response_at, 
                                                    :request => log.request,
                                                    :response => log.response,
                                                    :response_reason => log.response_reason,
                                                    :response_message => log.response_message,
                                                    :product => log.product,
                                                    :variant => log.variant,
                                                    :version => log.version,
                                                    :build => log.build,
                                                    :mid1 => log.mid1,
                                                    :mid2 => log.mid2,
                                                    :hid1 => log.hid1,
                                                    :hid2 => log.hid2,
                                                    :sid => log.sid,
                                                    :ip_address => log.ip_address,
                                                    :os => log.os,
                                                    :local_registration => log.local_registration } } 
                                                    #}
                                                  }
      
    end # respond_to
  end # def achistory

  

  # For customer service to run if counts get askew
  def updatecounts
    #als = ActivationLog.all
    authcode = Authcode.all
    #als.map { |al| Authcode.find(:first, :conditions => { :license_name => al.license_name, :code => al.authorization_code }) }
    @updated = []
    authcode.each do |ac|
      if !ac.nil?
        comps = ActivationLog.computers_for_ac(ac.code, ac.license_name)
        num_active_comps = comps[0].length
        num_unactive_comps = comps[1].length
        if ac.current_active_registrations != num_active_comps || ac.active_registrations != num_active_comps + num_unactive_comps
          ac_record = [ac, ac.active_registrations, ac.current_active_registrations]
          ac.current_active_registrations = num_active_comps
          ac.active_registrations = num_active_comps + num_unactive_comps
          ac.save
          @updated << ac_record
        end
      end
    end
  end

  # GET /activation_logs/list
  # Web page showing list of all requests
  def list
    
    
    
    order = params[:sort_column].blank? ? "request_at DESC" : "#{params[:sort_column]} #{params[:order]}".gsub(/\\/, '\&\&').gsub(/'/, "''")
    range = params[:start_range].blank? ? '' : [ "request_at BETWEEN ? AND ?", params[:start_range].to_date, params[:end_range].to_date + 1]
    @exact_search = params[:search_type].blank? || params[:search_type] == "is"
    search_conditions = params[:search_text].blank? ? '' : [ "#{params[:search_column]} #{@exact_search ? "=" : "LIKE"} ?".gsub(/\\/, '\&\&').gsub(/'/, "''"), @exact_search ? params[:search_text] : "%#{params[:search_text]}%" ]
    conditions = range.blank? ? search_conditions : search_conditions.blank? ? range : [ range[0] + ' AND ' + search_conditions[0], range[1], range[2], search_conditions[1] ]
    
    @default_search_column = params[:search_column].blank? ? "license_name" : params[:search_column]
    @default_sort_column = params[:sort_column].blank? ? "request_at" : params[:sort_column]
    @default_order = params[:order].blank? ? "DESC" : params[:order]
    
    @start_at = params[:start_at].blank? ? 1 : params[:start_at].to_i
    
    @total = ActivationLog.count(:conditions => conditions)
    
    @activation_logs = ActivationLog.all(:limit => 100, :offset => @start_at - 1, :conditions => conditions, :order => order)
    
    
    if @activation_logs == nil then @activation_logs = [] end
      
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @activation_logs }
    end
  end  

  # Debugging web page for customer service
  def showauthcodes
    @authcodes = Authcode.all
  end

  def test
    @license_name_in = params[:licenseName]
    @authorization_code_in = params[:licenseCode]
    @os = params[:os]
    @sysconfig = params[:sysConfig].split(";")
     @sysconfig.each do |sysparam|
       values = sysparam.split(",")
       if values[0] == "MID1"
         @mid1 = values[1]
       elsif values[0] == "MID2"
         @mid2 = values[1]
       elsif values[0] == "HID1"
         @hid1 = values[1]
       elsif values[0] == "HID2"
         @hid2 = values[1]
       elsif values[0] == "SID"
         @sid = values[1]
       end
     end
    #@thecode = nil
    #@thecode = Authcode.find(:first, :conditions => { :license_name => params[:license_name], :code => params[:authorization_code] })
    @thecode = Authcode.find(:first, :conditions => {  :code => params[:licenseCode] })
    @thecomp = ActivationLog.same_computer(ActivationLog.new(:license_name => @license_name_in,
                                                             :authorization_code => @authorization_code_in,
                                                             :os => @os,
                                                             :mid1 => @mid1,
                                                             :mid2 => @mid2,
                                                             :hid1 => @hid1,
                                                             :hid2 => @hid2,
                                                             :sid => @sid))
    #@thecode = Authcode.find(:first, :conditions => {  :license_name => "webtest1 YUJKZV", :code => "0AEEFF8D" })
    #@thecode = Authcode.find(:first, :conditions => {  :license_name => "webtest1 YUJKZV" })
    #@thecode = Authcode.find(:first, :conditions => {  :code => "0AEEFF8D" })
        
    # test.html.erb
  end
  
  # GET /ks1/metrics
  # Web page showing usage metrics of DRM server
  def metrics
    @date = Date.today
    @range_present = !params[:begin_date].blank?
    @range = [ Date.civil(params[:begin_date][:year].to_i, params[:begin_date][:month].to_i, params[:begin_date][:day].to_i), Date.civil(params[:end_date][:year].to_i, params[:end_date][:month].to_i, params[:end_date][:day].to_i) ] if @range_present
    null_to_zero = lambda { |num_or_nil| num_or_nil.nil? ? "NA" : sprintf("%.4f", num_or_nil) }
    request_text = "request_at BETWEEN ? AND ?"
    and_request_text = " AND #{request_text}"
    family = (!params[:license_family].blank? && params[:license_family] != "All") ? ["license_family = ?", params[:license_family]] : nil
    day_condition = [request_text, @date, @date + 1]
    week_condition = [request_text, @date - 6, @date + 1]
    month_condition = [request_text, @date - 29, @date + 1]
    six_month_condition = [request_text, @date - 182, @date + 1]
    range_condition = [request_text, @range[0], @range[1] + 1 ] if !params[:begin_date].blank?
    rcondition = lambda { |interval| interval.nil? ? family : family.nil? ? interval : [family[0] + ' AND ' + interval[0]] + [family[1]] + interval[1..-1] }
    
    @new_params = {}
    if family
      @new_params[:search_column] = "license_family"
      @new_params[:search_type] = "is"
      @new_params[:search_text] = params[:license_family]
    end
    if @range_present
      @new_params[:start_range] = @range[0].to_s
      @new_params[:end_range] = @range[1].to_s
    end
    
    @range_values = {}
    
    average_time = lambda { |interval| null_to_zero.call(ActivationLog.average(:process_time, :conditions => rcondition.call(interval))) }
    extreme_time = lambda do |interval, max|
      # conditions = ["process_time = (SELECT MAX(process_time) FROM activation_logs)"]
      # if !interval.nil?
      #   conditions[0] += " AND #{interval[0]}"
      #   conditions << interval[1] << interval[2]
      # end
      conditions = ["process_time IS NOT NULL"]
      if !interval.nil?
        conditions[0] += " AND #{interval[0]}"
        conditions << interval[1] << interval[2]
      end
      ActivationLog.find(:first, :conditions => rcondition.call(conditions), :order => "process_time #{max ? "DESC" : "ASC"}")
    end
    max_time = lambda { |interval| extreme_time.call(interval, true)}
    min_time = lambda { |interval| extreme_time.call(interval, false)}
    @total_days = @range_present ? range_condition[2] - range_condition[1] : (Date.today - ActivationLog.minimum(:request_at).to_date )
    
    per_day = lambda { |interval| ActivationLog.count(:conditions => rcondition.call(interval)) / (interval.nil? ? @total_days.to_f : interval[2] - interval[1]) }
    
    
    peak_day = lambda { |interval| 
      ainterval = rcondition.call(interval)
      ActivationLog.find_by_sql(["SELECT COUNT(request_at) AS num, DATE(request_at) AS day FROM activation_logs #{ainterval.nil? ? "" : "WHERE #{ainterval[0]} "}GROUP BY day ORDER BY num DESC"] + (ainterval.nil? ? [] : ainterval[1..-1]))[0] }
    peak_minute = lambda { |interval|
      ainterval = rcondition.call(interval)
       ActivationLog.find_by_sql(["SELECT COUNT(request_at) AS num, DATE(request_at) AS day, HOUR(request_at) AS hour, MINUTE(request_at) AS minute FROM activation_logs #{ainterval.nil? ? "" : "WHERE #{ainterval[0]} "}GROUP BY day, hour, minute ORDER BY num DESC"] + (ainterval.nil? ? [] : ainterval[1..-1]))[0] }
    peak_ac = lambda { |interval|
      ainterval = rcondition.call(interval)
       ActivationLog.find_by_sql(["SELECT COUNT(authcode_id) AS num, authcode_id, license_name, authorization_code FROM activation_logs #{ainterval.nil? ? "" : "WHERE #{ainterval[0]} "}GROUP BY authcode_id ORDER BY num DESC"] + (ainterval.nil? ? [] : ainterval[1..-1]))[0] }
    
    if @range_present
      @range_values[:average] = average_time.call(range_condition) 
      @range_values[:max] = max_time.call(range_condition) 
      @range_values[:min] = min_time.call(range_condition) 
      @range_values[:per_day] = per_day.call(range_condition) 
      @range_values[:peak_day] = peak_day.call(range_condition) 
      @range_values[:peak_minute] = peak_minute.call(range_condition)
      @range_values[:peak_ac] = peak_ac.call(range_condition)
      
    else
      @overall_average_time = average_time.call(nil)
      @day_average_time = average_time.call(day_condition)
      @week_average_time = average_time.call(week_condition)
      @month_average_time = average_time.call(month_condition)
      @six_month_average_time = average_time.call(six_month_condition)
      
      @overall_max = max_time.call(nil)
      @day_max = max_time.call(day_condition)
      @week_max = max_time.call(week_condition)
      @month_max = max_time.call(month_condition)
      @six_month_max = max_time.call(six_month_condition)

      @overall_min = min_time.call(nil)
      @day_min = min_time.call(day_condition)
      @week_min = min_time.call(week_condition)
      @month_min = min_time.call(month_condition)
      @six_month_min = min_time.call(six_month_condition)
      
      @overall_requests_per_day = per_day.call(nil)
      @day_requests_per_day       = per_day.call(day_condition)
      @week_requests_per_day      = per_day.call(week_condition)
      @month_requests_per_day     = per_day.call(month_condition)
      @six_month_requests_per_day = per_day.call(six_month_condition)
      
      @overall_peak_day = peak_day.call(nil)
      @day_peak_day = peak_day.call(day_condition)
      @week_peak_day = peak_day.call(week_condition)
      @month_peak_day = peak_day.call(month_condition)
      @six_month_peak_day = peak_day.call(six_month_condition)
      
      @overall_peak_minute = peak_minute.call(nil)
      @day_peak_minute = peak_minute.call(day_condition)
      @week_peak_minute = peak_minute.call(week_condition)
      @month_peak_minute = peak_minute.call(month_condition)
      @six_month_peak_minute = peak_minute.call(six_month_condition)

      @overall_peak_ac = peak_ac.call(nil)
      @day_peak_ac = peak_ac.call(day_condition)
      @week_peak_ac = peak_ac.call(week_condition)
      @month_peak_ac = peak_ac.call(month_condition)
      @six_month_peak_ac = peak_ac.call(six_month_condition)
      
    end
    
#    @overall_min = ActivationLog.find_by_sql("SELECT * FROM activation_logs WHERE process_time = (SELECT MIN(process_time) FROM activation_logs)")[0]    

    #@overall_peak_day = ActiveRecord::Base.connection.select_one("SELECT COUNT(request_at) AS num, DATE(request_at) AS day FROM activation_logs GROUP BY day ORDER BY num DESC")
    
    
    
    #@peak_minute = ActiveRecord::Base.connection.select_one("SELECT COUNT(request_at) AS num, DATE(request_at) AS day, HOUR(request_at) AS hour, MINUTE(request_at) AS minute FROM activation_logs GROUP BY day, hour, minute ORDER BY num DESC")
    @byhour = []
    (0..23).each do |cur_hour|
      curdate = DateTime.new(y = @date.year, m = @date.month, d = @date.day, h = cur_hour)
      
      nextdate = curdate.advance(:hours => 1)
      #@byhour << ActivationLog.count(:conditions => {:request_at => (curdate..nextdate)})
      bh_conditions = ["SELECT * FROM activation_logs WHERE HOUR(request_at) = ?", cur_hour]
      bh_conditions[0] = bh_conditions[0] + " AND " + range_condition[0] if !params[:begin_date].blank?
      bh_conditions << range_condition[1] if !params[:begin_date].blank?
      bh_conditions << range_condition[2] if !params[:begin_date].blank?
      bh_conditions[0] = bh_conditions[0] + " AND " + family[0] if family
      bh_conditions << family[1] if family
      @byhour << ActivationLog.find_by_sql(bh_conditions)
    end
  end
  
  protected
  
  def set_default_response
    request.format = :json if params[:format].nil?
  end
  
end
