# Copyright (c) 2011 Key Curriculum Press
# All Rights Reserved

class Precode < ActiveRecord::Base
  establish_connection "license_#{RAILS_ENV}"
end
