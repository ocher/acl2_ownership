require 'acl_system2_ownership'

ActionController::Base.send :include, Ocher::AccessControlOwnership
