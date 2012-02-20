module CommConsts
  
  # Strings for communication:
  LS_REQUEST_ACTIVATE = 'Activate'
  LS_REQUEST_DEACTIVATE = 'Deactivate'

  LS_RESPONSE_ALLOW = 'Allow'
  LS_RESPONSE_REJECT = 'Reject'
  LS_RESPONSE_ERROR = 'Error'

  LS_RESPONSEREASON_LIMITEXCEEDED = 'RegistrationLimitExceeded'
  LS_RESPONSEREASON_CANCELED = 'CanceledAC'
  LS_RESPONSEREASON_MISUSED = 'MisusedAC'
  LS_RESPONSEREASON_EXPIRED = 'ExpiredAC'
  LS_RESPONSEREASON_UNRECOGNIZED = 'UnrecognizedAC'
  LS_RESPONSEREASON_DEREGISTRERED = 'ComputerDeregisteredByLS'
  LS_RESPONSEREASON_UNSPECIFIED = 'UnspecifedReason'

  LS_RESPONSE_ARRAY = [ LS_RESPONSEREASON_UNSPECIFIED,
                        LS_RESPONSEREASON_UNRECOGNIZED,
                        LS_RESPONSEREASON_LIMITEXCEEDED,
                        LS_RESPONSEREASON_CANCELED,
                        LS_RESPONSEREASON_MISUSED,
                        LS_RESPONSEREASON_EXPIRED,
                        LS_RESPONSEREASON_UNRECOGNIZED,
                        LS_RESPONSEREASON_DEREGISTRERED
                        ]
                        
  

  LS_RESPONSEMESSAGE_SENDTODEVNULL = 'If you are responsible for this license and have questions, submit a license support request at http://www.dynamicgeometry.com/license_support.'
  LS_RESPONSEMESSAGE_LIMITEXCEEDED = 'All permitted registrations for this license have been used. If you are responsible for this license, you may want to deregister Sketchpad on some of the computers using this license in order to allow additional registrations.'
  LS_RESPONSEMESSAGE_CANCELED = 'The authorization code for this license has been canceled. ' + LS_RESPONSEMESSAGE_SENDTODEVNULL
  LS_RESPONSEMESSAGE_MISUSED = 'The authorization code for this license has been revoked due to apparent misuse. ' + LS_RESPONSEMESSAGE_SENDTODEVNULL
  LS_RESPONSEMESSAGE_EXPIRED = 'The authorization code for this license has expired. ' + LS_RESPONSEMESSAGE_SENDTODEVNULL
  LS_RESPONSEMESSAGE_UNRECOGNIZED = 'The authorization code for this license is not recognized. ' + LS_RESPONSEMESSAGE_SENDTODEVNULL
  LS_RESPONSEMESSAGE_DEREGISTRERED = 'This computer has been deregistered by the license server. ' + LS_RESPONSEMESSAGE_SENDTODEVNULL
  LS_RESPONSEMESSAGE_UNSPECIFIED = 'This license could not be registered on this computer. ' + LS_RESPONSEMESSAGE_SENDTODEVNULL

  LS_STATUS_ACTIVE = 'Active'
  LS_STATUS_CANCELED = 'Canceled'
  LS_STATUS_MISUSED = 'Canceled for Misuse'
  LS_STATUS_EXPIRED = 'Expired'
  
  LS_YES = 'Yes'
  LS_NO = 'No'
  LS_NA = 'N/A'
  
  def CommConsts.bool_to_s(theb)
    if theb
      'Yes'
    else
      'No'
    end
  end
  
  def CommConsts.s_to_bool?(thes)
    if thes == 'Yes'
      true
    else
      false
    end
  end
  
end #Module CommConsts